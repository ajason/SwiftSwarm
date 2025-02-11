//
//  AgentRepresentable.swift
//
//
//  Created by James Rochabrun on 10/22/24.
//

import Foundation
import SwiftOpenAI

/// 定义代理可表示性要求的协议。
///
/// `AgentRepresentable` 确保符合的类型可以被迭代（通过 `CaseIterable`），
/// 由原始值表示（通过 `RawRepresentable`），并与 `Agent` 实例关联。
///
/// 这对于创建枚举或其他结构以表示系统中的不同代理非常有用。
public protocol AgentRepresentable: CaseIterable, RawRepresentable where RawValue == String {

  /// 包含所有用于代理编排工具的 `Agent`。
  var agent: Agent { get }

  /// 此代理类型的基本定义。
  ///
  /// 此属性允许每个符合类型提供其基本配置，
  /// 如模型、指令和自定义工具。
  /// 这应仅在内部使用 - 消费者在进行运行请求时应始终使用 `agent` 属性。
  var agentDefinition: AgentDefinition { get }

  /// 一个工具集合,用于实现代理之间的通信和任务委派。
  ///
  /// 该属性会为系统中的每个代理类型自动生成工具,支持:
  /// - 在不同代理角色之间无缝切换
  /// - 代理之间的动态任务交接
  ///
  /// 每个生成的工具:
  /// - 以其对应的代理类型命名
  /// - 可以将控制权转移给指定的代理
  var orchestrationTools: [ChatCompletionParameters.Tool] { get }
}

/// 包含代理基本配置的包装结构。
///
/// 此结构作为原始代理配置与其最终形式（带有编排工具）之间的中间层。
/// 它有助于将基本代理设置与其运行时功能分开。
public struct AgentDefinition {

  /// 没有编排工具的基本代理配置。
  public var agent: Agent

  /// 使用指定的基本配置创建新的代理定义。
  ///
  /// - Parameter agent: 要使用的基本代理配置。
  public init(agent: Agent) {
    self.agent = agent
  }
}

extension AgentRepresentable {

  public var agent: Agent {
    let base = agentDefinition.agent
    return Agent(
      name: base.name,
      model: base.model,
      instructions: base.instructions,
      tools: base.tools + orchestrationTools)
  }

  /// 一个工具集合,用于实现代理之间的通信和任务委派。
  ///
  /// 该属性会为系统中的每个代理类型自动生成工具,支持:
  /// - 在不同代理角色之间无缝切换
  /// - 代理之间的动态任务交接
  ///
  /// 每个生成的工具:
  /// - 以其对应的代理类型命名
  /// - 可以将控制权转移给指定的代理
  public var orchestrationTools: [ChatCompletionParameters.Tool] {
    var tools: [ChatCompletionParameters.Tool] = []
    for item in Self.allCases {
      tools.append(
        .init(
          function: .init(
            name: "\(item.rawValue)",
            strict: nil,
            description: "Transfer to \(item.rawValue) agent, for agent \(item.rawValue) perspective",
            parameters: .init(
              type: .object,
              properties: [
                "agent": .init(type: .string, description: "Returns \(item.rawValue)")
              ],
              required: ["agent"]))))
    }
    return tools
  }
}
