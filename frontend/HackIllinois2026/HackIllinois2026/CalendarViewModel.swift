//
//  CalendarViewModel.swift
//  HackIllinois2026
//
//  Created by Om Chachad on 28/02/26.
//

import SwiftUI
import FoundationModels
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

    private var session = LanguageModelSession(
        tools: [CalendarTool()],
        instructions: """
        You are a helpful calendar assistant. Help the user manage and query their calendar events. \
        Break down the user's requests into steps and call the appropriate tools to get the information needed to fulfill the request. \
        Always use the provided tools for any calendar-related operations. \
        IMPORTANT: When the user asks you to create multiple events, you MUST make a separate 'create' tool call for EACH individual event. \
        Do NOT try to combine multiple events into a single tool call. Call the tool once per event, one after another.
        """
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
        The user's current time zone is \(TimeZone.current.identifier).
        The user's current locale identifier is \(Locale.current.identifier).
        The current local date and time is \(formattedCurrentDate()).
        Use this information when interpreting relative dates like "today" or "tomorrow".
        
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
        The user's current time zone is \(TimeZone.current.identifier).
        The user's current locale identifier is \(Locale.current.identifier).
        The current local date and time is \(formattedCurrentDate()).
        Use this information when interpreting relative dates like "today" or "tomorrow".
        
        The following is text extracted from a PDF document. Add all relevant dated events to my calendar and ignore the rest:
        \(text)
        """
        
        messages.append(CalendarMessage(role: .user, content: prompt, attachment: .pdf(url: pdfURL, filename: pdfURL.lastPathComponent)))
        await respondToPrompt(prompt)
    }

    // MARK: - Private Helpers

    /// Shared helper: wraps a prompt with contextual date info, monitors the
    /// session transcript for tool activity, sends the prompt, and handles errors.
    /// Uses the streaming API to support multiple sequential tool calls.
    private func respondToPrompt(_ userPrompt: String) async {
        agentActivity = []
        isRunning = true

        let contextualPrompt = """
        The user's current time zone is \(TimeZone.current.identifier).
        The user's current locale identifier is \(Locale.current.identifier).
        The current local date and time is \(formattedCurrentDate()).
        Use this information when interpreting relative dates like "today" or "tomorrow".

        \(userPrompt)
        """

        let initialTranscriptCount = session.transcript.count

        // Monitor the transcript for tool-call activity in the background.
        let transcriptTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var seenCount = initialTranscriptCount
            while !Task.isCancelled {
                let entries = session.transcript
                if entries.count > seenCount {
                    for entry in entries[seenCount..<entries.count] {
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
                try await Task.sleep(for: .milliseconds(200))
            }
        }

        do {
            var finalText = ""
            streamingContent = ""
            let stream = session.streamResponse(to: contextualPrompt)
            for try await partial in stream {
                finalText = partial.content
                let trimmed = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && trimmed != "null" {
                    streamingContent = finalText
                }
            }
            streamingContent = ""
            messages.append(CalendarMessage(role: .assistant, content: finalText))
        } catch {
            streamingContent = ""
            messages.append(CalendarMessage(
                role: .assistant,
                content: "Sorry, something went wrong: \(error.localizedDescription)"
            ))
        }

        transcriptTask.cancel()
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
        let formatter = Date.ISO8601FormatStyle(
            includingFractionalSeconds: false,
            timeZone: TimeZone.current
        )
        return Date.now.formatted(formatter)
    }
}
