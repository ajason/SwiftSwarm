//
//  Swarm.swift
//  
//
//  Created by James Rochabrun on 10/18/24.
//

import Foundation
import SwiftOpenAI

actor Swarm {
   
   private let client: OpenAIService
   private let toolResponseHandler: ToolResponseHandler
   
   init(client: OpenAIService, toolResponseHandler: ToolResponseHandler) {
      self.client = client
      self.toolResponseHandler = toolResponseHandler
   }
   
   func runStream(
      agent: Agent,
      messages: [ChatCompletionParameters.Message],
      contextVariables: [String: String] = [:],
      modelOverride: Model? = nil,
      debug: Bool = false,
      maxTurns: Int = Int.max,
      executeTools: Bool = true)
   -> AsyncThrowingStream<StreamChunk, Error>
   {
      AsyncThrowingStream { continuation in
         Task {
            do {
               var activeAgent = agent
               var currentContextVariables = contextVariables
               var history = messages
               let initialMessageCount = messages.count
               
               while history.count - initialMessageCount < maxTurns {
                  continuation.yield(StreamChunk(delim: "start"))
                  
                  let completionStream = try await getChatCompletionStream(
                     agent: activeAgent,
                     history: history,
                     contextVariables: currentContextVariables,
                     modelOverride: modelOverride,
                     debug: debug
                  )
                  
                  let (content, toolCalls) = try await accumulateStreamContent(completionStream, continuation: continuation)
                  
                  let currentMessage = ChatCompletionParameters.Message(
                     role: .assistant,
                     content: .text(content),
                     toolCalls: toolCalls
                  )
                  history.append(currentMessage)
                  
                  continuation.yield(StreamChunk(delim: "end"))
                  
                  guard let availableToolCalls = toolCalls, !availableToolCalls.isEmpty && executeTools else {
                     if debug {
                        print("Ending turn.")
                     }
                     break
                  }
                  
                  let partialResponse = try await handleToolCalls(
                     availableToolCalls,
                     agent: activeAgent,
                     contextVariables: currentContextVariables,
                     debug: debug
                  )
                  
                  history.append(contentsOf: partialResponse.messages)
                  currentContextVariables.merge(partialResponse.contextVariables) { _, new in new }
                  
                  activeAgent = partialResponse.agent
                  
                  for message in partialResponse.messages {
                     if case .text(let text) = message.content {
                        continuation.yield(StreamChunk(content: text))
                     }
                  }
               }
               
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
   
   private func accumulateStreamContent(
      _ stream: AsyncThrowingStream<ChatCompletionChunkObject, Error>,
      continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation)
   async throws -> (String, [ToolCall]?)
   {
      var content = ""
      var accumulatedTools: [String: (ToolCall, String)] = [:]
      
      for try await chunk in stream {
         if let chunkContent = chunk.choices.first?.delta.content {
            content += chunkContent
            continuation.yield(StreamChunk(content: chunkContent))
         }
         
         if let toolCalls = chunk.choices.first?.delta.toolCalls {
            for toolCall in toolCalls {
               if let id = toolCall.id {
                  accumulatedTools[id] = (toolCall, toolCall.function.arguments)
               } else if let index = toolCall.index, let existingTool = accumulatedTools.values.first(where: { $0.0.index == index }) {
                  let updatedArguments = existingTool.1 + (toolCall.function.arguments)
                  accumulatedTools[existingTool.0.id ?? ""] = (existingTool.0, updatedArguments)
               }
            }
            continuation.yield(StreamChunk(toolCalls: toolCalls))
         }
         
         if chunk.choices.first?.finishReason != nil {
            break
         }
      }
      
      let finalToolCalls = accumulatedTools.isEmpty ? nil : accumulatedTools.map { (_, value) in
         let (toolCall, arguments) = value
         return ToolCall(
            id: toolCall.id,
            type: toolCall.type ?? "function",
            function: FunctionCall(arguments: arguments, name: toolCall.function.name ?? "")
         )
      }
      
      return (content, finalToolCalls)
   }
   
   private func getChatCompletionStream(
       agent: Agent,
       history: [ChatCompletionParameters.Message],
       contextVariables: [String: String],
       modelOverride: Model?,
       debug: Bool)
      async throws -> AsyncThrowingStream<ChatCompletionChunkObject, Error> {
       
       // Add a system message for agent's instructions
       var updatedHistory = history
       
       // Check if a system message with instructions is already present
       if let lastSystemMessageIndex = updatedHistory.lastIndex(where: { $0.role == "system" }) {
           // Update the existing system message with the current agent's instructions
           updatedHistory[lastSystemMessageIndex] = ChatCompletionParameters.Message(
               role: .system,
               content: .text(agent.instructions)
           )
       } else {
           // Add a new system message if it doesn't exist
           let systemMessage = ChatCompletionParameters.Message(
               role: .system,
               content: .text(agent.instructions)
           )
           updatedHistory.insert(systemMessage, at: 0)
       }
       
       let parameters = ChatCompletionParameters(
           messages: updatedHistory,
           model: modelOverride ?? agent.model,
           toolChoice: agent.toolChoice,
           tools: agent.tools,
           parallelToolCalls: agent.parallelToolCalls
       )
       
       return try await client.startStreamedChat(parameters: parameters)
   }

   
   private func handleToolCalls(
      _ toolCalls: [ToolCall],
      agent: Agent,
      contextVariables: [String: String],
      debug: Bool)
   async throws -> Response
   {
      var partialResponse = Response(messages: [], agent: agent, contextVariables: contextVariables)
      
      for toolCall in toolCalls {
         guard let tool = agent.tools.first(where: { $0.function.name == toolCall.function.name }) else {
            if debug {
               print("Tool not found:", toolCall.function.name ?? "no name")
            }
            continue
         }
         
         let parameters = execute(arguments: toolCall.function.arguments).toDictionary() ?? [:]
         let (newAgent, content) = try await toolResponseHandler.handleToolResponse(parameters: parameters)
         
         if let newAgent = newAgent {
            partialResponse.agent = newAgent
         }
         let toolMessage = ChatCompletionParameters.Message(
            role: .tool,
            content: .text(content ?? ""),
          //  content: .text(content ?? "\(toolCall.function.arguments) \n"),
            name: tool.function.name,
            toolCallID: toolCall.id
         )
         partialResponse.messages.append(toolMessage)
      }
      
      return partialResponse
   }
   
   private func execute(
      arguments: String)
   -> String
   {
      print(arguments)
      return arguments
   }
}

struct StreamChunk {
   var content: String?
   var toolCalls: [ToolCall]?
   var delim: String?
   var response: Response?
}


extension ChatCompletionParameters.Message.ContentType {
   
   var text: String? {
      switch self {
      case .text(let string):
         return string
      default:
         return nil
      }
   }
}
