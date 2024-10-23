//
//  TeamDemoResponseHandler.swift
//  SwiftSwarmExample
//
//  Created by James Rochabrun on 10/22/24.
//

import Foundation
import SwiftSwarm

struct TeamDemoResponseHandler: ToolResponseHandler {
   
   typealias AgentType = Team
   
   func handleToolResponseContent(
      parameters: [String: Any])
      async throws -> String?
   {
      var content: String?
      if let id = parameters["designTool"] as? String {
         content = info(id)
      }
      return content
   }
   
   private func info(_ id: String) -> String {
      """
      PRODUCT: ID = \(id)
      This product is fragile be careful.
      """
   }
}
