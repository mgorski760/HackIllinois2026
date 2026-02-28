//
//  ContentView.swift
//  HackIllinois2026
//
//  Created by Om Chachad on 27/02/26.
//

import SwiftUI
import FoundationModels

struct ContentView: View {
    @State private var viewModel = CalendarViewModel()
    @State private var currentPrompt: String = ""
    
    var body: some View {
        NavigationStack {
            CalendarToolView(viewModel: viewModel)
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
            TextField("Ask whatever you'd like", text: $currentPrompt, axis: .vertical)
                .disabled(viewModel.isRunning)
                .textFieldStyle(.glass)
                .padding()
                .onSubmit {
                    Task {
                        await viewModel.send(prompt: currentPrompt)
                        currentPrompt = ""
                    }
                }
        }
    }
}

#Preview {
    ContentView()
}
