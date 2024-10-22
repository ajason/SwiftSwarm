//
//  ToolResponseHandler.swift
//  
//
//  Created by James Rochabrun on 10/21/24.
//

import Foundation

protocol ToolResponseHandler {
   func handleToolResponse(parameters: [String: Any]) async throws -> (agent: Agent?, content: String?)
}
