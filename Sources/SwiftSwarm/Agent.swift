//
//  Agent.swift
//
//
//  Created by James Rochabrun on 10/18/24.
//

import SwiftOpenAI

struct Agent {
   
   var name: String
   var model: Model
   var instructions: String
   var tools: [ChatCompletionParameters.Tool]
   var toolChoice: ToolChoice?
   var parallelToolCalls: Bool
}
