//
//  ChatScreen.swift
//  SwiftSwarmExample
//
//  Created by James Rochabrun on 10/22/24.
//

import Foundation
import SwiftOpenAI
import SwiftUI

struct ChatScreen: View {
   
   var viewModel = TeamDemoViewModel()
   
   @State private var isProcessing = false

   @State private var prompt: String = ""
    var body: some View {
        VStack {
           HStack {
              TextField(text: $prompt) {
                 Text("placeholder")
              }
              Button {
                 Task {
                    let message = ChatCompletionParameters.Message(role: .user, content: .text(prompt))
                    try await viewModel.handleConversation(
                    newMessages: [message],
                    initialAgent: Team.engineer.agent)
                    prompt = ""
                 }

              } label: {
                 Text("Send")
              }
              .disabled(isProcessing)
              
              Button {
                 viewModel.startOver()
                 prompt = ""
              } label: {
                 Text("Clear")
              }
              
           }
           List(viewModel.cells) { cell in
              VStack(alignment: .leading, spacing: 4) {
                     if cell.role == .agent {
                        Text(cell.agentName)
                             .font(.caption)
                             .foregroundColor(.blue)
                     }
                     Text(cell.content)
                 }
                 .padding()
           }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}


