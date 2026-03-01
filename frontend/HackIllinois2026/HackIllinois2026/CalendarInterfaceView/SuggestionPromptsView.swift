//
//  SuggestionPromptsView.swift
//  HackIllinois2026
//
//  Created by Om Chachad on 28/02/26.
//

import SwiftUI

struct SuggestionPromptsView: View {
    let onPromptTapped: (String) -> Void
    @State private var animatedIndices: Set<Int> = []
    @State private var selectedSuggestions: [SuggestionPrompt] = []
    
    // Carefully crafted prompts that are direct and unambiguous for the on-device model
    private let allSuggestions = [
        SuggestionPrompt(
            icon: "clock.arrow.circlepath",
            displayText: "Move events 1hr forward",
            prompt: "Move all my events today forward by 1 hour because I'm running late"
        ),
        SuggestionPrompt(
            icon: "calendar.badge.plus",
            displayText: "Team meeting tomorrow 2 PM",
            prompt: "Create a team meeting tomorrow at 2 PM for 1 hour"
        ),
        SuggestionPrompt(
            icon: "list.bullet.clipboard",
            displayText: "Show today's schedule",
            prompt: "Show me all my events for today"
        ),
        SuggestionPrompt(
            icon: "calendar.badge.minus",
            displayText: "Cancel all meetings tomorrow",
            prompt: "Delete all my meetings scheduled for tomorrow"
        ),
        SuggestionPrompt(
            icon: "clock.badge.checkmark",
            displayText: "Free time this afternoon?",
            prompt: "Do I have any free time this afternoon?"
        ),
        SuggestionPrompt(
            icon: "calendar",
            displayText: "What's next on my calendar?",
            prompt: "What is my next scheduled event?"
        ),
        SuggestionPrompt(
            icon: "arrow.right.circle",
            displayText: "Move 3pm meeting to 4pm",
            prompt: "Reschedule my 3 PM meeting to 4 PM today"
        ),
        SuggestionPrompt(
            icon: "clock.arrow.2.circlepath",
            displayText: "Push back all events 30min",
            prompt: "Move all my events today forward by 30 minutes"
        ),
        SuggestionPrompt(
            icon: "calendar.badge.clock",
            displayText: "Add lunch break at noon",
            prompt: "Create a lunch break event tomorrow at 12 PM for 1 hour"
        ),
        SuggestionPrompt(
            icon: "calendar.badge.exclamationmark",
            displayText: "Show this week's meetings",
            prompt: "Show me all my meetings for this week"
        )
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(selectedSuggestions.enumerated()), id: \.element.id) { index, suggestion in
                SuggestionBubble(suggestion: suggestion, isAnimated: animatedIndices.contains(index)) {
                    onPromptTapped(suggestion.prompt)
                }
            }
        }
        .onAppear {
            // Randomly select 3 suggestions
            selectedSuggestions = Array(allSuggestions.shuffled().prefix(3))
            
            // Staggered animation with 0.5s initial delay
            for index in selectedSuggestions.indices {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(index) * 0.1) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        _ = animatedIndices.insert(index)
                    }
                }
            }
        }
    }
}

struct SuggestionPrompt: Identifiable {
    let id = UUID()
    let icon: String
    let displayText: String
    let prompt: String
}

struct SuggestionBubble: View {
    let suggestion: SuggestionPrompt
    let isAnimated: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: suggestion.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.blue)
                
                Text(suggestion.displayText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule()
                            .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                    }
            }
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .opacity(isAnimated ? 1 : 0)
        .scaleEffect(isAnimated ? 1 : 0.8)
        .offset(x: isAnimated ? 0 : -20)
    }
}

#Preview {
    ZStack(alignment: .bottomLeading) {
        LinearGradient(
            colors: [Color.clear, Color(uiColor: .blue).opacity(0.1)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        
        VStack {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 100))
                .foregroundStyle(
                    LinearGradient(colors: [
                        Color(.systemRed),
                        Color(.systemOrange),
                        Color(.systemYellow),
                        Color(.systemGreen),
                        Color(.systemTeal),
                        Color(.systemBlue),
                        Color(.systemIndigo),
                        Color(.systemPurple)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            Spacer()
        }
        
        SuggestionPromptsView { prompt in
            print("Tapped: \(prompt)")
        }
        .padding(.leading, 16)
        .padding(.bottom, 90)
    }
}
