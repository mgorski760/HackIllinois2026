//
//  CalendarViewModel.swift
//  HackIllinois2026
//
//  Created by Om Chachad on 28/02/26.
//

import SwiftUI
import PDFKit
import Vision

@Observable
final class CalendarViewModel {

    // MARK: - Public State (observed by views)

    private(set) var messages: [CalendarMessage] = []
    private(set) var agentActivity: [AgentActivityEvent] = []
    private(set) var isRunning = false
    private(set) var streamingContent: String = ""

    // MARK: - Private

    private let apiService: APIService
    private let authManager: AuthManager
    private let calendarManager: GoogleCalendarManager
    
    // Chat history for the API
    private var chatHistory: [ChatMessageInput] = []

    // MARK: - Initialization
    
    init(apiService: APIService, authManager: AuthManager, calendarManager: GoogleCalendarManager) {
        self.apiService = apiService
        self.authManager = authManager
        self.calendarManager = calendarManager
    }

    // MARK: - Prewarm

    func prewarm() {
        // No prewarming needed for API-based agent
    }

    // MARK: - Send

    func send(prompt: String) async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(CalendarMessage(role: .user, content: trimmed))
        await respondToPrompt(trimmed)
    }
    
    func send(image: UIImage) async {
        guard let cgImage = image.cgImage else { return }

        let recognizedText: String
        do {
            recognizedText = try await recognizeText(in: cgImage)
        } catch {
            messages.append(CalendarMessage(
                role: .assistant,
                content: "Sorry, I couldn't read text from that image: \(error.localizedDescription)"
            ))
            return
        }

        guard !recognizedText.isEmpty else {
            messages.append(CalendarMessage(
                role: .assistant,
                content: "I couldn't find any text in that image."
            ))
            return
        }

        let prompt = """
        The following is text from an image I scanned, add all relevant dated events to my calendar and ignore the rest:
        \(recognizedText)
        """
        messages.append(CalendarMessage(role: .user, content: prompt, attachment: .image(image)))
        await respondToPrompt(prompt)
    }

    func send(pdfURL: URL) async {
        guard let pdf = PDFDocument(url: pdfURL) else {
            messages.append(CalendarMessage(
                role: .assistant,
                content: "Sorry, I couldn't open that PDF."
            ))
            return
        }

        let documentContent = NSMutableAttributedString()
        for i in 0..<pdf.pageCount {
            guard let page = pdf.page(at: i),
                  let pageContent = page.attributedString else { continue }
            documentContent.append(pageContent)
        }

        let text = documentContent.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            messages.append(CalendarMessage(
                role: .assistant,
                content: "The PDF appears to be empty or contains no readable text."
            ))
            return
        }

        let prompt = """
        The following is text extracted from a PDF document. Add all relevant dated events to my calendar and ignore the rest:
        \(text)
        """
        
        messages.append(CalendarMessage(role: .user, content: prompt, attachment: .pdf(url: pdfURL, filename: pdfURL.lastPathComponent)))
        await respondToPrompt(prompt)
    }

    // MARK: - Private Helpers

    /// Sends prompt to the Modal API agent and processes the response
    private func respondToPrompt(_ userPrompt: String) async {
        agentActivity = []
        isRunning = true
        streamingContent = ""

        // Add user message to chat history
        chatHistory.append(ChatMessageInput(role: "user", content: userPrompt))

        do {
            // Refresh token if needed
            try await authManager.refreshTokenIfNeeded()
            
            // Show activity indicator
            agentActivity.append(AgentActivityEvent(
                icon: "sparkles",
                label: "Thinking..."
            ))

            // Create agent request
            let request = AgentRequest(
                prompt: userPrompt,
                timezone: TimeZone.current.identifier,
                current_datetime: formattedCurrentDate(),
                chat_history: chatHistory.count > 10 ? Array(chatHistory.suffix(10)) : chatHistory
            )

            // Call the agent
            let response = try await apiService.chat(request: request)
            
            // Process results and show activity
            for result in response.results {
                let icon = result.success ? "checkmark.circle.fill" : "xmark.circle.fill"
                let actionName = result.action.capitalized
                agentActivity.append(AgentActivityEvent(
                    icon: icon,
                    label: "\(actionName) \(result.success ? "completed" : "failed")"
                ))
                
                // Brief delay to show each activity
                try? await Task.sleep(for: .milliseconds(200))
            }

            // Add assistant response to messages and chat history
            let assistantMessage = response.message
            messages.append(CalendarMessage(role: .assistant, content: assistantMessage))
            chatHistory.append(ChatMessageInput(role: "assistant", content: assistantMessage))
            
            // Trigger calendar refresh after AI actions with a small delay to ensure backend sync
            try? await Task.sleep(for: .milliseconds(300))
            calendarManager.triggerRefresh()

        } catch APIError.unauthorized {
            messages.append(CalendarMessage(
                role: .assistant,
                content: "Your session has expired. Please sign in again."
            ))
        } catch {
            messages.append(CalendarMessage(
                role: .assistant,
                content: "Sorry, something went wrong: \(error.localizedDescription)"
            ))
        }

        agentActivity = []
        isRunning = false
    }

    /// Performs OCR on a CGImage using the Vision framework and returns the recognized text.
    private func recognizeText(in cgImage: CGImage) async throws -> String {
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest()
        try requestHandler.perform([request])

        let observations = request.results ?? []
        let recognizedStrings = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }
        return recognizedStrings.joined(separator: "\n")
    }

    // MARK: - Helpers

    private func formattedCurrentDate() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }
}
