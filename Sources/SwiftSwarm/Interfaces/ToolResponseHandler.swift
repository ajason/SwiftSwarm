//
//  ToolResponseHandler.swift
//
//
//  Created by James Rochabrun on 10/21/24.
//

import Foundation

/// 定义处理工具响应所需行为的协议。
///
/// `ToolResponseHandler` 旨在管理工具和代理在系统中的交互方式，
/// 允许基于参数选择代理并处理工具响应内容。
public protocol ToolResponseHandler {

  /// 此处理器使用的代理类型。
  ///
  /// `AgentType` 必须遵循 `AgentRepresentable` 协议，确保
  /// 它可以转换为代理或从代理转换。
  associatedtype AgentType: AgentRepresentable

  /// 尝试将工具参数转移到匹配的代理。
  ///
  /// 此方法检查提供的参数以找到合适的代理
  /// 匹配给定的工具键和值，如果找到则返回相应的代理。
  ///
  /// - Parameter parameters: 可能包含选择代理信息的参数字典。
  /// - Returns: 匹配参数的可选 `Agent`，如果未找到匹配项则返回 `nil`。
  func transferToAgent(_ parameters: [String: Any]) -> Agent?

  /// 异步处理工具响应内容。
  ///
  /// 给定一组参数，此方法处理工具生成的内容
  /// 并异步返回结果字符串。
  ///
  /// - Parameter parameters: 包含工具输入的参数字典。
  /// - Returns: 表示工具响应内容的字符串。
  /// - Throws: 内容处理过程中可能发生的任何错误。
  func handleToolResponseContent(parameters: [String: Any]) async throws -> String?
}

extension ToolResponseHandler {

  /// 尝试根据工具键将工具参数转移到合适的代理。
  ///
  /// 此方法遍历可用代理，检查它们的工具键是否与
  /// 提供的参数匹配。如果找到匹配的代理，则返回该代理。
  ///
  /// - Parameter parameters: 用于与代理工具匹配的参数字典。
  /// - Returns: 匹配提供参数的可选 `Agent`，如果未找到匹配项则返回 `nil`。
  public func transferToAgent(_ parameters: [String: Any]) -> Agent? {
    for agent in agents {
      let toolKeys = Set(
        agent.agent.tools.compactMap { tool -> [String]? in
          tool.function.parameters?.properties?.keys.map { $0 }
        }.flatMap { $0 })

      // 检查此代理的任何工具键是否与参数匹配
      for key in toolKeys {
        if let value = parameters[key] as? String,
          agent.rawValue == value
        {
          return agent.agent
        }
      }
    }
    return nil
  }

  /// 遵循 `AgentType` 的代理列表，确保处理器可以访问所有情况。
  ///
  /// 此计算属性检索所有遵循 `AgentType` 的代理并使其可供使用。
  private var agents: [AgentType] {
    (AgentType.allCases as? [AgentType]) ?? []
  }
}
