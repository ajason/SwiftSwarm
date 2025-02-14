//
//  Response.swift
//
//
//  Created by James Rochabrun on 10/18/24.
//

import SwiftOpenAI

/// A structure that represents the response generated by an agent.
///
/// The `Response` structure encapsulates the messages, agent, and context variables
/// resulting from an agent's execution. It is used to capture the outcome of a session
/// or a series of interactions with an agent.
public struct Response {
   
   /// The list of messages generated during the interaction.
   ///
   /// These messages include all the content exchanged between the agent and the user
   /// or other systems during the response generation.
   public var messages: [ChatCompletionParameters.Message]
   
   /// The agent responsible for generating the response.
   ///
   /// This property holds the agent that was active during the generation of the response.
   public var agent: Agent
   
   /// A dictionary of context variables that were used or updated during the interaction.
   ///
   /// These variables can store additional context or state information relevant to the agent's responses.
   public var contextVariables: [String: String]
}
