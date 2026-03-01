//
//  ContentView.swift
//  HackIllinois2026
//
//  Created by Om Chachad on 27/02/26.
//

import SwiftUI
import PhotosUI

// Wrapper view that sets up dependencies for the authenticated content
struct AuthenticatedContentView: View {
    let authManager: AuthManager
    let apiBaseURL: String
    
    @State private var apiService: APIService
    @StateObject private var calendarManager: GoogleCalendarManager
    @State private var viewModel: CalendarViewModel
    
    init(authManager: AuthManager, apiBaseURL: String) {
        self.authManager = authManager
        self.apiBaseURL = apiBaseURL
        
        // Initialize API service
        let api = APIService(baseURL: apiBaseURL, authManager: authManager)
        _apiService = State(initialValue: api)
        
        // Initialize calendar manager
        let calendar = GoogleCalendarManager(apiService: api, authManager: authManager)
        _calendarManager = StateObject(wrappedValue: calendar)
        
        // Initialize view model with calendar manager
        _viewModel = State(initialValue: CalendarViewModel(apiService: api, authManager: authManager, calendarManager: calendar))
    }
    
    var body: some View {
        ContentView(
            viewModel: viewModel,
            calendarManager: calendarManager,
            authManager: authManager
        )
    }
}

struct ContentView: View {
    @Bindable var viewModel: CalendarViewModel
    @ObservedObject var calendarManager: GoogleCalendarManager
    @ObservedObject var authManager: AuthManager
    
    @State private var currentPrompt: String = ""
    @State private var isShowingImagePicker: Bool = false
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var isFileImporterPresented: Bool = false
    @State private var isShowingCamera: Bool = false
    @State private var isTranscribing: Bool = false
    @State private var isCalendarExpanded: Bool = false
    @FocusState private var isTextFieldFocused: Bool

    private let expandAnimation = Animation.spring(response: 0.45, dampingFraction: 0.85)

    var body: some View {
        NavigationStack {
            VStack {
                CalendarInterfaceView(
                    viewModel: viewModel,
                    currentPrompt: currentPrompt,
                    onSuggestionTapped: { prompt in
                        currentPrompt = prompt
                    }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                LinearGradient(colors: [Color.clear, Color(uiColor: .blue).opacity(0.1)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }
        }
        .safeAreaBar(edge: .bottom) { toolbar }
        .calendarWidget(isExpanded: $isCalendarExpanded, animation: expandAnimation, calendarManager: calendarManager)
        .photosPicker(isPresented: $isShowingImagePicker, selection: $photosPickerItem, matching: .images)
        .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.image, .pdf], onCompletion: handleFileImport)
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraCaptureView { image in Task { await viewModel.send(image: image) } }
        }
    }

    // MARK: - Bottom toolbar

    private var toolbar: some View {
        HStack {
            if !isTranscribing {
                attachMenu
            }
            
            TextField("Ask whatever you'd like", text: $currentPrompt, axis: .vertical)
                .disabled(viewModel.isRunning)
                .textFieldStyle(.glass)
                .focused($isTextFieldFocused)
                .onSubmit { sendPrompt() }
            
            LiveTranscriptionButton(text: $currentPrompt, isRecording: $isTranscribing)
            
            if !isTranscribing {
                sendButton
            }
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
        let isEmpty = currentPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let showDismissButton = isEmpty && isTextFieldFocused
        let iconName = showDismissButton ? "checkmark" : "arrow.up"
        let label = showDismissButton ? "Done" : "Send"
        
        return Button(action: {
            if showDismissButton {
                // Dismiss keyboard when empty and focused
                isTextFieldFocused = false
            } else {
                // Send message when not empty
                sendPrompt()
            }
        }) {
            Label(label, systemImage: iconName)
                .labelStyle(.iconOnly)
                .bold()
                .foregroundStyle(.white)
                .padding()
                .contentTransition(.symbolEffect(.replace))
        }
        .glassEffect(.regular.tint(viewModel.isRunning || isTranscribing ? .gray : .blue))
        .buttonBorderShape(.circle)
        .clipShape(.circle)
        .disabled(viewModel.isRunning || isTranscribing)
        .opacity(isTranscribing ? 0 : 1)
        .animation(.easeInOut(duration: 0.2), value: showDismissButton)
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

// MARK: - Safe Area Bar Extension

extension View {
    func safeAreaBar<Content: View>(edge: VerticalEdge, @ViewBuilder content: () -> Content) -> some View {
        safeAreaInset(edge: edge, spacing: 0) {
            content()
        }
    }
}
