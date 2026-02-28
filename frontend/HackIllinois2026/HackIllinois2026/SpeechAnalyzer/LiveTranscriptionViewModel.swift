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
/// Falls back to SFSpeechRecognizer-based dictation when the on-device
/// SpeechAnalyzer model is unavailable or not yet downloaded.
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

    // Audio engine (shared between both paths)
    private let audioEngine = AVAudioEngine()

    // ── SpeechAnalyzer path ──────────────────────────────────────────────────
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var feedTask: Task<Void, Never>?
    private var resultsTask: Task<Void, Never>?
    private var analyzeTask: Task<Void, Never>?

    // ── SFSpeechRecognizer (fallback) path ───────────────────────────────────
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var usingFallback = false

    // Tracks where the current utterance starts inside the bound text
    private var segmentStart: String.Index?

    // MARK: Public interface

    /// Start capturing microphone audio and appending transcriptions to `text`.
    func start(appendingTo text: Binding<String>) async {
        guard case .idle = state else { return }
        state = .preparing

        // Try the modern SpeechAnalyzer path first; fall back on any failure.
        let usedModernAPI = await startWithSpeechAnalyzer(appendingTo: text)
        if !usedModernAPI {
            await startWithSFSpeechRecognizer(appendingTo: text)
        }
    }

    // MARK: - SpeechAnalyzer path

    private func startWithSpeechAnalyzer(appendingTo text: Binding<String>) async -> Bool {
        do {
            // 1. Locale / module
            guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else {
                return false   // locale unsupported → fall back
            }
            let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
            self.transcriber = transcriber

            // 2. Assets – if the model needs downloading and the request exists,
            //    attempt a download; bail out to fallback if it fails.
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

            let inputNode = audioEngine.inputNode
            let nativeFormat = inputNode.outputFormat(forBus: 0)

            guard let converter = AVAudioConverter(from: nativeFormat, to: targetFormat ?? AVAudioFormat()) else {
                return false
            }

            // Request microphone permission
            let granted = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
            }
            guard granted else {
                state = .error("Microphone permission denied.")
                return true
            }

            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)

            inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] buffer, _ in
                guard let self, let inputBuilder = self.inputBuilder else { return }

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
            usingFallback = false
            state = .recording

            // Consume results
            resultsTask = Task { @MainActor in
                do {
                    for try await result in transcriber.results {
                        let plain = String(result.text.characters)
                        guard !plain.isEmpty else { continue }

                        if let start = self.segmentStart {
                            text.wrappedValue.replaceSubrange(start..., with: plain)
                        } else {
                            if !text.wrappedValue.isEmpty, !text.wrappedValue.hasSuffix(" ") {
                                text.wrappedValue += " "
                            }
                            self.segmentStart = text.wrappedValue.endIndex
                            text.wrappedValue += plain
                        }

                        if result.isFinal {
                            self.segmentStart = nil
                        }
                    }
                } catch {
                    // Stream ended or cancelled – normal on stop
                }
            }

            // Run analysis (drives the whole session)
            analyzeTask = Task {
                do {
                    _ = try await analyzer.analyzeSequence(inputSequence)
                } catch {
                    await MainActor.run { self.state = .error(error.localizedDescription) }
                }
            }

            return true

        } catch {
            // Clean up any partial state before we try the fallback
            self.transcriber = nil
            self.analyzer = nil
            self.inputBuilder?.finish()
            self.inputBuilder = nil
            if audioEngine.isRunning {
                audioEngine.inputNode.removeTap(onBus: 0)
                audioEngine.stop()
            }
            return false
        }
    }

    // MARK: - SFSpeechRecognizer fallback path

    private func startWithSFSpeechRecognizer(appendingTo text: Binding<String>) async {
        // 1. Authorization
        let authStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard authStatus == .authorized else {
            state = .error("Speech recognition permission denied.")
            return
        }

        let micGranted = await withCheckedContinuation { cont in
            AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
        }
        guard micGranted else {
            state = .error("Microphone permission denied.")
            return
        }

        // 2. Set up recognizer
        let recognizer = SFSpeechRecognizer(locale: Locale.current)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

        guard let recognizer, recognizer.isAvailable else {
            state = .error("Speech recognizer is not available on this device.")
            return
        }
        self.speechRecognizer = recognizer

        // 3. Recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false   // allow server if needed
        self.recognitionRequest = request

        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            state = .error("Audio session error: \(error.localizedDescription)")
            return
        }

        // 4. Start recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    let plain = result.bestTranscription.formattedString
                    guard !plain.isEmpty else { return }

                    if let start = self.segmentStart {
                        text.wrappedValue.replaceSubrange(start..., with: plain)
                    } else {
                        if !text.wrappedValue.isEmpty, !text.wrappedValue.hasSuffix(" ") {
                            text.wrappedValue += " "
                        }
                        self.segmentStart = text.wrappedValue.endIndex
                        text.wrappedValue += plain
                    }

                    // SFSpeechRecognizer accumulates text across the whole session, so
                    // we never reset segmentStart on isFinal — every subsequent callback
                    // still contains the full cumulative transcript and must overwrite
                    // from the same position. segmentStart is only cleared on stop().
                }

                if let error {
                    let nsErr = error as NSError
                    // Code 1110 = no speech detected; code 216 = session cancelled – both are normal.
                    let silentCodes: Set<Int> = [1110, 216, 203]
                    if !silentCodes.contains(nsErr.code) {
                        self.state = .error(error.localizedDescription)
                    }
                }
            }
        }

        // 5. Tap microphone and feed buffers into the request
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            try audioEngine.start()
        } catch {
            state = .error("Could not start audio engine: \(error.localizedDescription)")
            return
        }

        usingFallback = true
        state = .recording
    }

    // MARK: - Stop

    /// Stop capturing and finalize the current analysis session.
    func stop() async {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        if usingFallback {
            // Tear down SFSpeechRecognizer session
            recognitionRequest?.endAudio()
            recognitionTask?.cancel()
            recognitionRequest = nil
            recognitionTask = nil
            speechRecognizer = nil
        } else {
            // Tear down SpeechAnalyzer session
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
        }

        usingFallback = false
        segmentStart = nil

        try? AVAudioSession.sharedInstance().setActive(false)
        state = .idle
    }
}
