//
//  LiveTranscriptionViewModel.swift
//  HackIllinois2026
//
//  Created by Om Chachad on 28/02/26.
//


import SwiftUI
import Speech
import AVFoundation

// MARK: - ViewModel

/// Manages the SpeechAnalyzer session and microphone capture.
@MainActor
@Observable
final class LiveTranscriptionViewModel {

    enum State {
        case idle
        case preparing
        case recording
        case error(String)

        var isRecording: Bool { if case .recording = self { true } else { false } }
        var isPreparing: Bool { if case .preparing = self { true } else { false } }
    }

    private(set) var state: State = .idle

    // Audio engine
    private let audioEngine = AVAudioEngine()

    // Analyzer objects – held strongly for the session lifetime
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?

    // Tasks we need to cancel on stop
    private var feedTask: Task<Void, Never>?
    private var resultsTask: Task<Void, Never>?
    private var analyzeTask: Task<Void, Never>?

    // Tracks where the current utterance starts inside the bound text
    private var segmentStart: String.Index?

    // MARK: Public interface

    /// Start capturing microphone audio and appending transcriptions to `text`.
    func start(appendingTo text: Binding<String>) async {
        guard case .idle = state else { return }

        do {
            state = .preparing

            // 1. Locale / module
            guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else {
                state = .error("Locale not supported by SpeechTranscriber.")
                return
            }
            let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
            self.transcriber = transcriber

            // 2. Assets
            if let req = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await req.downloadAndInstall()
            }

            // 3. Input stream
            let (inputSequence, inputBuilder) = AsyncStream.makeStream(of: AnalyzerInput.self)
            self.inputBuilder = inputBuilder

            // 4. Analyzer
            let analyzer = SpeechAnalyzer(modules: [transcriber])
            self.analyzer = analyzer

            // 5. Determine best audio format
            let targetFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])

            // Configure AVAudioEngine tap
            let inputNode = audioEngine.inputNode
            let nativeFormat = inputNode.outputFormat(forBus: 0)

            // We convert from the mic's native format to targetFormat on the fly.
            guard let converter = AVAudioConverter(from: nativeFormat, to: targetFormat ?? AVAudioFormat()) else { state = .error("Could not create audio converter.")
                return
            }

            // Request microphone permission
            let granted = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
            }
            guard granted else {
                state = .error("Microphone permission denied.")
                return
            }

            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)

            inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] buffer, _ in
                guard let self, let inputBuilder = self.inputBuilder else { return }

                // Convert and yield
                let frameCapacity = AVAudioFrameCount(
                    Double(buffer.frameLength) * (targetFormat?.sampleRate ?? nativeFormat.sampleRate) / nativeFormat.sampleRate
                )
                guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat ?? nativeFormat, frameCapacity: frameCapacity) else { return }

                var error: NSError?
                converter.convert(to: converted, error: &error) { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }

                if error == nil, converted.frameLength > 0 {
                    inputBuilder.yield(AnalyzerInput(buffer: converted))
                }
            }

            try audioEngine.start()
            state = .recording

            // 7. Consume results
            // progressiveTranscription emits cumulative partial results for each utterance.
            // We overwrite the in-progress segment each time, then commit when final.
            resultsTask = Task { @MainActor in
                do {
                    for try await result in transcriber.results {
                        let plain = String(result.text.characters)
                        guard !plain.isEmpty else { continue }

                        if let start = self.segmentStart {
                            // Replace everything from the segment start with the latest text
                            text.wrappedValue.replaceSubrange(start..., with: plain)
                        } else {
                            // First result of this utterance – append a separator if needed
                            if !text.wrappedValue.isEmpty, !text.wrappedValue.hasSuffix(" ") {
                                text.wrappedValue += " "
                            }
                            self.segmentStart = text.wrappedValue.endIndex
                            text.wrappedValue += plain
                        }

                        // When the result is final, commit it and reset for the next utterance
                        if result.isFinal {
                            self.segmentStart = nil
                        }
                    }
                } catch {
                    // Stream ended or was cancelled – normal on stop
                }
            }

            // 6. Run analysis (drives the whole session)
            analyzeTask = Task {
                do {
                    _ = try await analyzer.analyzeSequence(inputSequence)
                } catch {
                    await MainActor.run { self.state = .error(error.localizedDescription) }
                }
            }

        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Stop capturing and finalize the current analysis session.
    func stop() async {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        // Finish the input stream so the analyzer can finalize
        inputBuilder?.finish()
        inputBuilder = nil

        if let analyzer {
            try? await analyzer.finalizeAndFinishThroughEndOfInput()
        }

        analyzeTask?.cancel()
        resultsTask?.cancel()
        analyzeTask = nil
        resultsTask = nil
        analyzer = nil
        transcriber = nil
        segmentStart = nil

        try? AVAudioSession.sharedInstance().setActive(false)
        state = .idle
    }
}
