//
//  CalendarToolView.swift
//  HackIllinois2026
//
//  Created by Om Chachad on 28/02/26.
//

import SwiftUI
import FoundationModels

// MARK: - Chat Message Model

struct CalendarMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String

    enum Role {
        case user, assistant
    }
}

// MARK: - Main View

struct CalendarToolView: View {

    // Injected from the parent — the parent owns the view model's lifetime.
    var viewModel: CalendarViewModel

    var body: some View {
        messageList
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.prewarm()
            }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            Group {
                if viewModel.messages.isEmpty && !viewModel.isRunning {
                    VStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 100))
                            .foregroundStyle(.secondary)
                            .foregroundStyle(
                                // A gradient of all colors but bolder and not rainbow.w
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
                            .padding()
                    }
                    .padding(.top, 250)
                    .padding(.bottom, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            if viewModel.isRunning {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(viewModel.agentActivity) { event in
                                        AgentActivityRow(event: event)
                                            .transition(.move(edge: .bottom).combined(with: .opacity))
                                    }
                                    TypingIndicator()
                                }
                                .id("typing")
                                .animation(.easeOut(duration: 0.2), value: viewModel.agentActivity.count)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                    }
                    .contentMargins(.top, 300, for: .scrollContent)
                    .contentMargins(.bottom, 40, for: .scrollContent)
                }
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isRunning) { _, running in
                if running {
                    withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                }
            }
        }
    }

}

// MARK: - Preview

#Preview {
    NavigationStack {
        CalendarToolView(viewModel: CalendarViewModel())
    }
}

// MARK: - Agent Activity

struct AgentActivityEvent: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
}

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

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: CalendarMessage
    private var isUser: Bool { message.role == .user }
    
    var formattedContent: AttributedString {
        (try? AttributedString(markdown: message.content)) ?? AttributedString(message.content)
    }
    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 48) }

            Text(formattedContent)
                .font(.system(size: 15))
                .foregroundStyle(isUser ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular.tint(isUser ? Color(.systemBlue) : Color(.secondarySystemGroupedBackground)), in: .rect(cornerRadius: 18, style: .continuous))
            if !isUser { Spacer(minLength: 48) }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color(.tertiaryLabel))
                        .frame(width: 7, height: 7)
                        .scaleEffect(phase == i ? 1.3 : 0.8)
                        .animation(
                            .easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15),
                            value: phase
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )

            Spacer(minLength: 48)
        }
        .padding(.vertical, 2)
        .onAppear { phase = 1 }
    }
}
