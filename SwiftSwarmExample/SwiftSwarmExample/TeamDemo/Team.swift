//
//  Team.swift
//  SwiftSwarmExample
//
//  Created by James Rochabrun on 10/22/24.
//

import Foundation
import SwiftOpenAI
import SwiftSwarm

enum Team: String, AgentRepresentable  {
   
   case engineer = "Engineer"
   case designer = "Designer"
   case product = "Product"
   
   var agent: Agent {
      Agent(
         name: self.rawValue,
         model: .gpt4o,
         instructions: instructions,
         tools: functionTools,
         toolChoice: nil)
   }
   
   var instructions: String {
      switch self {
      case .engineer:
            """
            You are a technical engineer. ALWAYS:
            Keep responses focused on technical implementation.
            If query asks about you, you answer mentioning your role.
            """
         
      case .designer:
            """
            You are a UX/UI designer. ALWAYS:
            Focus on user experience and interface specifications.
            If query asks about you, you answer mentioning your role.
            """
         
      case .product:
            """
            You are a product manager. ALWAYS:
            Focus on business value and user needs.
            If query asks about you, you answer mentioning your role.
            """
      }
   }
   
   var functionTools: [ChatCompletionParameters.Tool] {
      var tools: [ChatCompletionParameters.Tool] = []
      
      // Common tools for all roles
      let transitions = [
         ("DesignMode", Team.designer),
         ("EngineerMode", Team.engineer),
         ("ProductMode", Team.product),
      ]
      
      for (name, team) in transitions {
         tools.append(.init(function: .init(
            name: name,
            strict: nil,
            description: "Transfer to \(team.rawValue) for \(team.rawValue.lowercased()) perspective",
            parameters: .init(
               type: .object,
               properties: [
                  "agentID": .init(type: .string, description: "Returns \(team.rawValue)")
               ],
               required: ["agentID"]))))
      }
      
      // Example: Add ProductInfo tool only for Designer
      if self == .designer {
         tools.append(.init(function: .init(
            name: "ProductInfo",
            strict: nil,
            description: "Get product information",
            parameters: .init(
               type: .object,
               properties: [
                  "id": .init(type: .string, description: "Product ID")
               ],
               required: ["id"]))))
      }
      
      return tools
   }
}
