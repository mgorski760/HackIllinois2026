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
            CalendarInterfaceView(viewModel: viewModel)
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
            Button("Photo Library", systemImage: "photo.on.rectangle") { isShowingImagePicker = true }
            Button("Camera",        systemImage: "camera")              { isShowingCamera = true }
            Button("Files",         systemImage: "folder")              { isFileImporterPresented = true }
        } label: {
            Label("Attach", systemImage: "plus").labelStyle(.iconOnly).padding()
        }
        .glassEffect(.regular.tint(Color(uiColor: .tertiaryLabel).opacity(0.5)))
        .buttonBorderShape(.circle)
        .clipShape(.circle)
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

// MARK: - Calendar widget modifier

/// Overlays the TimelineCalendarView as a persistent floating widget that expands
/// to fill the screen. The view is never removed from the tree, so the animation
/// is a simple frame/corner-radius interpolation with zero recreation overhead.
private struct CalendarWidgetModifier: ViewModifier {
    @Binding var isExpanded: Bool
    let animation: Animation

    private let padding: CGFloat       = 16
    private let compactHeight: CGFloat = 240
    private let compactCorner: CGFloat = 40
    private let expandedCorner: CGFloat = 20

    func body(content: Content) -> some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top

            ZStack(alignment: .topLeading) {
                content
                    .safeAreaPadding(.top, isExpanded ? 0 : compactHeight + padding * 2)
                    .animation(animation, value: isExpanded)

                calendarView(geo: geo, safeTop: safeTop)
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }

    private func calendarView(geo: GeometryProxy, safeTop: CGFloat) -> some View {
        let width  = isExpanded ? geo.size.width              : geo.size.width - padding * 2
        let height = isExpanded ? geo.size.height + safeTop   : compactHeight
        let x      = isExpanded ? 0                           : padding
        let y      = isExpanded ? -safeTop                    : safeTop
        let corner = isExpanded ? expandedCorner              : compactCorner

        return TimelineCalendarView(isExpanded: $isExpanded)
            .frame(width: width, height: height)
            .clipShape(.rect(cornerRadius: corner))
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: corner))
            .shadow(color: .black.opacity(isExpanded ? 0 : 0.12),
                    radius: isExpanded ? 0 : 12, y: 4)
            .offset(x: x, y: y)
            .padding(.top, isExpanded ? 0 : 50)
            .animation(animation, value: isExpanded)
            .zIndex(1)
            .onTapGesture {
                guard !isExpanded else { return }
                withAnimation(animation) { isExpanded = true }
            }
    }
}

private extension View {
    func calendarWidget(isExpanded: Binding<Bool>, animation: Animation) -> some View {
        modifier(CalendarWidgetModifier(isExpanded: isExpanded, animation: animation))
    }
}

#Preview {
    ContentView()
}
