//
//  CalendarViewModel.swift
//  HackIllinois2026
//
//  Created by Om Chachad on 28/02/26.
//

import SwiftUI
import FoundationModels

@Observable
final class CalendarViewModel {

    // MARK: - Public State (observed by views)

    private(set) var messages: [CalendarMessage] = []
    private(set) var agentActivity: [AgentActivityEvent] = []
    private(set) var isRunning = false

    // MARK: - Private

    private var session = LanguageModelSession(
        tools: [CalendarTool()],
        instructions: "You are a helpful calendar assistant. Help the user manage and query their calendar events."
    )

    // MARK: - Prewarm

    func prewarm() {
        session.prewarm()
    }

    // MARK: - Send

    func send(prompt: String) async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(CalendarMessage(role: .user, content: trimmed))
        agentActivity = []
        isRunning = true

        let contextualPrompt = """
        The user's current time zone is \(TimeZone.current.identifier).
        The user's current locale identifier is \(Locale.current.identifier).
        The current local date and time is \(formattedCurrentDate()).
        Use this information when interpreting relative dates like "today" or "tomorrow".

        \(trimmed)
        """

        let transcriptTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var seenCount = 0
            while !Task.isCancelled {
                let entries = session.transcript
                if entries.count > seenCount {
                    for entry in entries[seenCount...] {
                        switch entry {
                        case .toolCalls(let calls):
                            for call in calls {
                                agentActivity.append(AgentActivityEvent(
                                    icon: "hammer.fill",
                                    label: "Calling \(call.toolName)…"
                                ))
                            }
                        case .toolOutput:
                            agentActivity.append(AgentActivityEvent(
                                icon: "checkmark.circle.fill",
                                label: "Tool returned results"
                            ))
                        default:
                            break
                        }
                    }
                    seenCount = entries.count
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }

        do {
            let response = try await session.respond(to: Prompt(contextualPrompt))
            transcriptTask.cancel()
            messages.append(CalendarMessage(role: .assistant, content: response.content))
        } catch {
            transcriptTask.cancel()
            messages.append(CalendarMessage(
                role: .assistant,
                content: "Sorry, something went wrong: \(error.localizedDescription)"
            ))
        }

        agentActivity = []
        isRunning = false
    }

    // MARK: - Helpers

    private func formattedCurrentDate() -> String {
        let formatter = Date.ISO8601FormatStyle(
            includingFractionalSeconds: false,
            timeZone: TimeZone.current
        )
        return Date.now.formatted(formatter)
    }
}
