//
//  CalendarInterfaceView.swift
//  HackIllinois2026
//
//  Created by Om Chachad on 28/02/26.
//

import SwiftUI
import FoundationModels

struct CalendarInterfaceView: View {

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
                                    if !viewModel.streamingContent.isEmpty {
                                        StreamingBubble(text: viewModel.streamingContent)
                                    } else {
                                        TypingIndicator()
                                    }
                                }
                                .id("typing")
                                .animation(.easeOut(duration: 0.2), value: viewModel.agentActivity.count)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                    }
                    .contentMargins(.top, 300, for: .scrollContent)
                    .contentMargins(.bottom, 70, for: .scrollContent)
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
            .onChange(of: viewModel.streamingContent) { _, _ in
                proxy.scrollTo("typing", anchor: .bottom)
            }
        }
    }

}
