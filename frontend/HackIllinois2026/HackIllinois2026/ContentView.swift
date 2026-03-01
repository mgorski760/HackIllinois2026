//
//  ContentView.swift
//  HackIllinois2026
//
//  Created by Om Chachad on 27/02/26.
//

import SwiftUI
import FoundationModels
import PhotosUI

struct ContentView: View {
    @State private var viewModel = CalendarViewModel()
    @State private var currentPrompt: String = ""
    @State private var isShowingImagePicker: Bool = false
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var isFileImporterPresented: Bool = false
    @State private var isShowingCamera: Bool = false
    @State private var isTranscribing: Bool = false
    @State private var isCalendarExpanded: Bool = false

    private let expandAnimation = Animation.spring(response: 0.45, dampingFraction: 0.85)

    var body: some View {
        NavigationStack {
            CalendarInterfaceView(
                viewModel: viewModel,
                currentPrompt: currentPrompt,
                onSuggestionTapped: { prompt in
                    currentPrompt = prompt
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                LinearGradient(colors: [Color.clear, Color(uiColor: .blue).opacity(0.1)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }
        }
        .safeAreaBar(edge: .bottom) { toolbar }
        .calendarWidget(isExpanded: $isCalendarExpanded, animation: expandAnimation)
        .photosPicker(isPresented: $isShowingImagePicker, selection: $photosPickerItem, matching: .images)
        .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.image, .pdf], onCompletion: handleFileImport)
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraCaptureView { image in Task { await viewModel.send(image: image) } }
        }
    }

    // MARK: - Bottom toolbar

    private var toolbar: some View {
        HStack {
            attachMenu
            TextField("Ask whatever you'd like", text: $currentPrompt, axis: .vertical)
                .disabled(viewModel.isRunning)
                .textFieldStyle(.glass)
                .onSubmit { sendPrompt() }
            LiveTranscriptionButton(text: $currentPrompt, isRecording: $isTranscribing)
            sendButton
        }
        .padding()
    }

    private var attachMenu: some View {
        Menu {
            Button("Camera",        systemImage: "camera")              { isShowingCamera = true }
            Button("Photo Library", systemImage: "photo.on.rectangle") { isShowingImagePicker = true }
            Button("Files",         systemImage: "folder")              { isFileImporterPresented = true }
        } label: {
            Label("Attach", systemImage: "plus").labelStyle(.iconOnly).padding()
        }
        .glassEffect(.regular)
        .buttonBorderShape(.circle)
        .padding(2)
        .clipShape(.circle)
        .padding(-2)
        .task(id: photosPickerItem) {
            guard let item = photosPickerItem,
                  let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            await viewModel.send(image: image)
        }
    }

    private var sendButton: some View {
        Button(action: sendPrompt) {
            Label("Send", systemImage: "arrow.up")
                .labelStyle(.iconOnly)
                .bold()
                .foregroundStyle(.white)
                .padding()
        }
        .glassEffect(.regular.tint(.blue))
        .buttonBorderShape(.circle)
        .clipShape(.circle)
        .disabled(viewModel.isRunning || isTranscribing)
    }

    // MARK: - Helpers

    private func sendPrompt() {
        Task { await viewModel.send(prompt: currentPrompt); currentPrompt = "" }
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result,
              url.startAccessingSecurityScopedResource(),
              let data = try? Data(contentsOf: url) else { return }
        Task {
            if url.pathExtension.lowercased() == "pdf" {
                await viewModel.send(pdfURL: url)
            } else if let image = UIImage(data: data) {
                await viewModel.send(image: image)
            }
        }
    }
}
