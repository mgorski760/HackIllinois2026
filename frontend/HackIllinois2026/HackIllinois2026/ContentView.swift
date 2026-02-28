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
    
    var body: some View {
        NavigationStack {
            CalendarInterfaceView(viewModel: viewModel)
        }
        .safeAreaBar(edge: .top) {
            TimelineCalendarView()
                .foregroundStyle(.tertiary.opacity(0.5))
                .frame(height: 240)
                .clipShape(.rect(cornerRadius: 40))
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 40))
                .padding()
        }
        .safeAreaBar(edge: .bottom) {
            HStack {
                Menu {
                    Button("Photo Library", systemImage: "photo.on.rectangle") {
                        isShowingImagePicker = true
                    }
                    .task(id: photosPickerItem) {
                        if let photosPickerItem {             // Process the selected photo
                            Task {
                                if let data = try? await photosPickerItem.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                                    await viewModel.send(image: image)
                                } else {
                                    print("Failed to load photo data.")
                                }
                            }
                        }
                    }
                    
                    Button("Camera", systemImage: "camera") {
                        isShowingCamera = true
                    }
                    
                    Button("Upload from files", systemImage: "folder") {
                        isFileImporterPresented = true
                    }
                } label: {
                    Label("Attach File", systemImage: "plus")
                        .labelStyle(.iconOnly)
                        .padding()
                }
                .glassEffect(.regular.tint(Color(uiColor: .tertiaryLabel).opacity(0.5)))
                .buttonBorderShape(.circle)
                .clipShape(.circle)
                
                TextField("Ask whatever you'd like", text: $currentPrompt, axis: .vertical)
                    .disabled(viewModel.isRunning)
                    .textFieldStyle(.glass)
                    .onSubmit {
                        Task {
                            await viewModel.send(prompt: currentPrompt)
                            currentPrompt = ""
                        }
                    }
                
                LiveTranscriptionButton(text: $currentPrompt, isRecording: $isTranscribing)
                
                Button {
                    Task {
                        await viewModel.send(prompt: currentPrompt)
                        currentPrompt = ""
                    }
                } label: {
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
            .padding()
        }
        .photosPicker(isPresented: $isShowingImagePicker, selection: $photosPickerItem, matching: .images)
        .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.image, .pdf]) { result in
            switch result {
            case .success(let url):
                Task {
                    guard url.startAccessingSecurityScopedResource() else {
                        print("Couldn't access the file.")
                        return
                    }
                    
                    if let data = try? Data(contentsOf: url) {
                        if url.pathExtension.lowercased() == "pdf" {
                            await viewModel.send(pdfURL: url)
                        } else if let image = UIImage(data: data) {
                            await viewModel.send(image: image)
                        }
                    } else {
                        print("Failed to load file data.")
                    }
                }
            case .failure(let error):
                print("File import failed with error: \(error.localizedDescription)")
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraCaptureView { image in
                Task {
                    await viewModel.send(image: image)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
