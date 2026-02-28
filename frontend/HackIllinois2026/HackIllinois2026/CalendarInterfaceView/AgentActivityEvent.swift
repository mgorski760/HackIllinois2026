//
//  AgentActivityEvent.swift
//  HackIllinois2026
//
//  Created by Om Chachad on 28/02/26.
//


import SwiftUI
import FoundationModels

struct AgentActivityEvent: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
}