//
//  AgentActivityRow.swift
//  HackIllinois2026
//
//  Created by Om Chachad on 28/02/26.
//


import SwiftUI
import FoundationModels

struct AgentActivityRow: View {
    let event: AgentActivityEvent

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: event.icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text(event.label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }
}