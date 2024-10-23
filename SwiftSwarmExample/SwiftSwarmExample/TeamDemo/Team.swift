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
      
      switch self {
      case .engineer:
         Agent(
            name: self.rawValue,
            model: .gpt4o,
            instructions: "You are a technical engineer,if user asks about you, you answer with your name \(self.rawValue)",
            tools: teamTools,
            toolChoice: nil)
      case .designer:
         Agent(
            name: self.rawValue,
            model: .gpt4o,
            instructions: "You are a UX/UI designer, if user asks about you, you answer with your name \(self.rawValue)",
            tools: teamTools,
            toolChoice: nil)
      case .product:
         Agent(
            name: self.rawValue,
            model: .gpt4o,
            instructions: "You are a product manager, if user asks about you, you answer with your name \(self.rawValue)",
            tools: teamTools,
            toolChoice: nil)
      }
   }
   
   var teamTools: [ChatCompletionParameters.Tool] {
      var tools: [ChatCompletionParameters.Tool] = []
      let transitions = [
         ("EngineerMode", Team.engineer),
         ("DesignMode", Team.designer),
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
      return tools
   }
}
