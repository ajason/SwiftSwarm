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
      if let id = parameters["id"] as? String {
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
   
   private func fetchContentForPrompt(_ prompt: String, count: Int) async throws -> String {
      // Simulating an async operation, e.g., an API call or complex computation
      try await Task.sleep(nanoseconds: 2_000_000_000) // Sleep for 2 seconds
      let response = "A cell is the basic structural and functional unit of all known living organisms. "
      return String(repeating: response, count: count)
   }
}
