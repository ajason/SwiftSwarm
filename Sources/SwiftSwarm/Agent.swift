//
//  Agent.swift
//
//
//  Created by James Rochabrun on 10/18/24.
//

import SwiftOpenAI

/// A structure representing an agent in the system.
///
/// The `Agent` structure contains the essential properties required to define
/// an agent, including the model it uses, its instructions, and its available tools.
public struct Agent {
   
   /// The name of the agent.
   public var name: String
   
   /// The model associated with the agent.
   ///
   /// This defines the language model the agent is using for generating responses,
   /// such as `gpt-4` or another variant.
   public var model: Model
   
   /// The instructions provided to the agent.
   ///
   /// These are typically guidelines or system messages that define the behavior
   /// or scope of the agent when it generates responses.
   public var instructions: String
   
   /// The list of tools available to the agent.
   ///
   /// Each tool is a callable function that the agent can use to assist in generating
   /// responses or executing actions as part of its workflow.
   public var tools: [ChatCompletionParameters.Tool]
   
   /// The tool choice preference for the agent.
   ///
   /// This indicates the agent's preferred method for selecting tools, if specified.
   public var toolChoice: ToolChoice?
   
   /// A flag indicating whether the agent can perform parallel tool calls.
   ///
   /// When set to `true`, the agent can execute multiple tools simultaneously
   /// if needed during its response generation process.
   public var parallelToolCalls: Bool
   
   public init(
      name: String,
      model: Model,
      instructions: String,
      tools: [ChatCompletionParameters.Tool],
      toolChoice: ToolChoice? = nil,
      parallelToolCalls: Bool = false)
   {
      self.name = name
      self.model = model
      self.instructions = instructions
      self.tools = tools
      self.toolChoice = toolChoice
      self.parallelToolCalls = parallelToolCalls
   }
}
