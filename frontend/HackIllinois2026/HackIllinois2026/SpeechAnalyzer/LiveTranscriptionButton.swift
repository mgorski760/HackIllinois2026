//
//  LiveTranscriptionButton.swift
//  HackIllinois2026
//
//  Created by Om Chachad on 28/02/26.
//


import SwiftUI
import Speech
import AVFoundation

/// A self-contained button that streams live speech-to-text into `text`.
///
/// Usage:
/// ```swift
/// @State private var transcript = ""
/// @State private var isRecording = false
/// var body: some View {
///     LiveTranscriptionButton(text: $transcript, isRecording: $isRecording)
/// }
/// ```
public struct LiveTranscriptionButton: View {

    @Binding var text: String
    @Binding var isRecording: Bool
    @State private var vm = LiveTranscriptionViewModel()

    public init(text: Binding<String>, isRecording: Binding<Bool> = .constant(false)) {
        self._text = text
        self._isRecording = isRecording
    }

    public var body: some View {
        Button {
            Task {
                if vm.state.isRecording {
                    await vm.stop()
                } else {
                    await vm.start(appendingTo: $text)
                }
            }
        } label: {
            label
        }
        .buttonStyle(.glassProminent)
        .tint(background)
        .disabled(vm.state.isPreparing)
        .animation(.easeInOut(duration: 0.2), value: vm.state.isRecording)
        .onChange(of: vm.state.isRecording) { _, newValue in
            isRecording = newValue
        }
        .overlay(errorOverlay, alignment: .bottom)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var label: some View {
        Group {
            if vm.state.isPreparing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label("Transcribe", systemImage: vm.state.isRecording ? "microphone.slash" : "microphone.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(vm.state.isRecording ? .red : .accentColor)
                    .symbolEffect(.pulse, isActive: vm.state.isRecording)
            }
        }
        .padding(10)
    }

    private var buttonTitle: String {
        switch vm.state {
        case .idle:        return "Transcribe"
        case .preparing:   return "Preparing…"
        case .recording:   return "Stop"
        case .error:       return "Error – Tap to retry"
        }
    }

    private var background: Color {
        if vm.state.isRecording {
            .red.opacity(0.12)
        } else {
            .blue.opacity(0.12)
        }
    }

    @ViewBuilder
    private var errorOverlay: some View {
        if case .error(let msg) = vm.state {
            Text(msg)
                .font(.caption)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(.top, 4)
                .offset(y: 44)
        }
    }
}
