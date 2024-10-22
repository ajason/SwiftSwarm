//
//  Response.swift
//
//
//  Created by James Rochabrun on 10/18/24.
//

import SwiftOpenAI

struct Response {
   var messages: [ChatCompletionParameters.Message]
   var agent: Agent
   var contextVariables: [String: String]
}
