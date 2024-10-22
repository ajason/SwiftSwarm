//
//  AgentRepresentable.swift
//  
//
//  Created by James Rochabrun on 10/22/24.
//

import Foundation

/// A protocol that defines the requirements for an agent to be representable.
///
/// `AgentRepresentable` ensures that conforming types can be iterated over (via `CaseIterable`),
/// represented by a raw value (via `RawRepresentable`), and associated with an `Agent` instance.
///
/// This is useful for creating enums or other structures that represent different agents in the system.
protocol AgentRepresentable: CaseIterable, RawRepresentable where RawValue == String {
   
   /// The `Agent` instance associated with the conforming type.
   ///
   /// This property allows each conforming type to provide its corresponding `Agent`
   /// with specific properties such as model, instructions, and tools.
   var agent: Agent { get }
}
