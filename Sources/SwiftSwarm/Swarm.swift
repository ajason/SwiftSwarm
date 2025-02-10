//
//  Swarm.swift
//
//
//  Created by James Rochabrun on 10/18/24.
//

import Foundation
import SwiftOpenAI

/// 一个管理代理交互和工具响应流的 actor。
///
/// `Swarm` actor 协调代理和工具之间的通信，处理响应流、
/// 执行工具调用，并在对话过程中更新上下文变量。
public actor Swarm<Handler: ToolResponseHandler> {

  private let client: OpenAIService
  private let toolResponseHandler: Handler

  /// 初始化一个新的 `Swarm` actor 实例。
  ///
  /// - Parameters:
  ///   - client: 用于发送请求的 `OpenAIService` 实例。
  ///   - toolResponseHandler: 一个遵循 `ToolResponseHandler` 协议的处理器，负责处理工具响应。
  public init(client: OpenAIService, toolResponseHandler: Handler) {
    self.client = client
    self.toolResponseHandler = toolResponseHandler
  }

  /// 运行代理和提供的消息之间的交互流。
  ///
  /// 此函数处理聊天完成的流式传输，管理工具调用，并更新代理和上下文变量。
  ///
  /// - Parameters:
  ///   - agent: 负责处理消息的代理。
  ///   - messages: 要包含在交互中的聊天消息列表。
  ///   - contextVariables: 在对话中使用的可选上下文变量。
  ///   - modelOverride: 可选的模型，用于覆盖代理的默认模型。
  ///   - maxTurns: 代理允许采取的最大回合数。
  ///   - executeTools: 一个布尔值，用于确定代理是否应在过程中执行工具。
  /// - Returns: 一个 `AsyncThrowingStream<StreamChunk, Error>` 对象，表示流式交互数据。
  public func runStream(
    agent: Agent,
    messages: [ChatCompletionParameters.Message],
    contextVariables: [String: String] = [:],
    modelOverride: Model? = nil,
    executeTools: Bool = true
  )
    -> AsyncThrowingStream<StreamChunk, Error>
  {
    AsyncThrowingStream { continuation in
      Task {
        do {
          var activeAgent = agent
          var currentContextVariables = contextVariables
          var history = messages
          let initialMessageCount = messages.count

          continuation.yield(StreamChunk(delim: "start"))

          // 替换或添加 System prompt
          let completionStream = try await getChatCompletionStream(
            agent: activeAgent,
            history: history,
            contextVariables: currentContextVariables,
            modelOverride: modelOverride)

          // 累积内容和工具调用
          let (content, toolCalls) = try await accumulateStreamContent(completionStream, continuation: continuation)

          // 将 AI 回答 构建成 assistant 消息
          let assistantMessage = ChatCompletionParameters.Message(
            role: .assistant,
            content: .text(content),
            toolCalls: toolCalls
          )
          history.append(assistantMessage)

          // 检查是否存在可用的工具
          if let availableToolCalls = toolCalls, !availableToolCalls.isEmpty && executeTools {
            // 处理工具调用,返回一个 Response
            let partialResponse = try await handleToolCalls(
              availableToolCalls,
              agent: activeAgent,
              contextVariables: currentContextVariables)

            // 更新历史记录
            history.append(contentsOf: partialResponse.messages)
            // 更新上下文变量
            currentContextVariables.merge(partialResponse.contextVariables) { _, new in new }

            // 更新代理
            activeAgent = partialResponse.agent

            for message in partialResponse.messages {
              if case .text(_) = message.content {
                // We only need to stream the `availableToolCalls` at this point.
                continuation.yield(StreamChunk(content: "", toolCalls: availableToolCalls))
              }
            }

            // 获取最终响应
            let finalStream = try await getChatCompletionStream(
              agent: activeAgent,
              history: history,
              contextVariables: currentContextVariables,
              modelOverride: modelOverride)

            // 累积内容和工具调用
            let (finalContent, tools) = try await accumulateStreamContent(finalStream, continuation: continuation)

            if !finalContent.isEmpty {
              let finalAssistantMessage = ChatCompletionParameters.Message(
                role: .assistant,
                content: .text(finalContent)
              )
              history.append(finalAssistantMessage)
            }
          }

          continuation.yield(StreamChunk(delim: "end"))

          let finalResponse = Response(
            messages: Array(history.dropFirst(initialMessageCount)),
            agent: activeAgent,
            contextVariables: currentContextVariables
          )
          continuation.yield(StreamChunk(response: finalResponse))
          continuation.finish()

        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }

  /// 从流式响应中累积内容。
  ///
  /// 此函数从流式块中收集内容和工具调用，并通过提供的 continuation 发送更新。
  ///
  /// - Parameters:
  ///   - stream: 要处理的 `AsyncThrowingStream<ChatCompletionChunkObject, Error>`。
  ///   - continuation: 用于生成累积的内容和工具调用作为 `StreamChunk` 对象的 continuation。
  /// - Returns: 包含累积内容和工具调用的元组。
  private func accumulateStreamContent(
    _ stream: AsyncThrowingStream<ChatCompletionChunkObject, Error>,
    continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation
  )
    async throws -> (String, [ToolCall]?)
  {
    var content = ""
    // id: (toolCall, arguments)
    var accumulatedTools: [String: (ToolCall, String)] = [:]

    for try await chunk in stream {
      // yield delta 内容， 积累 content
      if let chunkContent = chunk.choices.first?.delta.content, !chunkContent.isEmpty {
        content += chunkContent
        continuation.yield(StreamChunk(content: chunkContent))
      }

      if let toolCalls = chunk.choices.first?.delta.toolCalls, !toolCalls.isEmpty {
        for toolCall in toolCalls {
          // toolCall.id 和 function.name 只会在流中返回一次，后面的chunk 只会返回 function.arguments delta
          if let id = toolCall.id {
            accumulatedTools[id] = (toolCall, toolCall.function.arguments)
          } else if let index = toolCall.index, let existingTool = accumulatedTools.values.first(where: { $0.0.index == index }) {
            // 如果 toolCall 没有 id，则使用 index 来匹配已有的 toolCall
            let updatedArguments = existingTool.1 + (toolCall.function.arguments)
            accumulatedTools[existingTool.0.id ?? ""] = (existingTool.0, updatedArguments)
          }
        }
        // 在流中返回 toolCalls
        continuation.yield(StreamChunk(toolCalls: toolCalls))
      }

      // 如果流结束，则退出循环
      if chunk.choices.first?.finishReason != nil {
        break
      }
    }
    let finalToolCalls =
      accumulatedTools.isEmpty
      ? nil
      : accumulatedTools.map { (_, value) in
        let (toolCall, arguments) = value
        return ToolCall(
          id: toolCall.id,
          type: toolCall.type ?? "function",
          function: FunctionCall(arguments: arguments, name: toolCall.function.name ?? "")
        )
      }

    // 返回累积的内容和工具调用
    return (content, finalToolCalls)
  }

  /// 从代理获取流式聊天完成。
  ///
  /// 此函数发送代理的历史记录和上下文变量以获取流式响应。
  ///
  /// - Parameters:
  ///   - agent: 用于生成响应的代理。
  ///   - history: 代理用于生成响应的聊天历史。
  ///   - contextVariables: 传递给代理的上下文变量。
  ///   - modelOverride: 可选的模型，用于覆盖代理的默认模型。
  /// - Returns: 表示流式响应的 `AsyncThrowingStream<ChatCompletionChunkObject, Error>`。
  private func getChatCompletionStream(
    agent: Agent,
    history: [ChatCompletionParameters.Message],
    contextVariables: [String: String],
    modelOverride: Model?
  )
    async throws -> AsyncThrowingStream<ChatCompletionChunkObject, Error>
  {

    // 为代理的指令添加系统消息
    var updatedHistory = history

    // 检查是否已存在带有指令的系统消息
    if let lastSystemMessageIndex = updatedHistory.lastIndex(where: { $0.role == "system" }) {
      // 使用当前代理的指令更新现有的系统消息
      updatedHistory[lastSystemMessageIndex] = ChatCompletionParameters.Message(
        role: .system,
        content: .text(agent.instructions)
      )
    } else {
      // 如果系统消息不存在则添加一个新的
      let systemMessage = ChatCompletionParameters.Message(
        role: .system,
        content: .text(agent.instructions)
      )
      updatedHistory.insert(systemMessage, at: 0)
    }

    let parameters = ChatCompletionParameters(
      messages: updatedHistory,
      model: modelOverride ?? agent.model,
      tools: agent.tools,
      parallelToolCalls: false)

    return try await client.startStreamedChat(parameters: parameters)
  }

  /// 处理响应中的工具调用，传输上下文并更新代理。
  ///
  /// 此函数处理工具调用，执行必要的工具，并更新代理和上下文变量。
  ///
  /// - Parameters:
  ///   - toolCalls: 代理在交互过程中进行的工具调用列表。
  ///   - agent: 当前管理对话的代理。
  ///   - contextVariables: 与对话相关的上下文变量。
  /// - Returns: 包含更新后的消息、代理和上下文变量的 `Response` 对象。
  private func handleToolCalls(
    _ toolCalls: [ToolCall],
    agent: Agent,
    contextVariables: [String: String]
  )
    async throws -> Response
  {
    var partialResponse = Response(messages: [], agent: agent, contextVariables: contextVariables)

    debugPrint("Handling Tool Call for agent \(agent.name)")

    for toolCall in toolCalls {
      debugPrint("Handling Tool Call \(toolCall.function.name ?? "No name")")
      guard agent.tools.first(where: { $0.function.name == toolCall.function.name }) != nil else {
        debugPrint("Tool not found:", toolCall.function.name ?? "no name")
        continue
      }

      let parameters = toolCall.function.arguments.toDictionary() ?? [:]
      // 尝试根据工具键将工具参数转移到合适的代理，如果找到则返回代理，否则返回 nil
      let newAgent = toolResponseHandler.transferToAgent(parameters)
      // 工具执行结果
      let content = try await toolResponseHandler.handleToolResponseContent(parameters: parameters)

      // 如果找到新的代理，则更新代理
      if let newAgent = newAgent {
        partialResponse.agent = newAgent
        debugPrint("Handling Tool Call transferring to \(newAgent.name)")
      }
      // 构建工具消息
      let toolMessage = ChatCompletionParameters.Message(
        role: .tool,
        content: .text(content ?? ""),
        toolCallID: toolCall.id
      )
      partialResponse.messages.append(toolMessage)
    }

    return partialResponse
  }
}
