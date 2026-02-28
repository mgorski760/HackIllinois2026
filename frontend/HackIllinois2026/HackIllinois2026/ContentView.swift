//
//  ContentView.swift
//  HackIllinois2026
//
//  Created by Om Chachad on 27/02/26.
//

import SwiftUI

struct ContentView: View {
    @State private var currentPrompt: String = ""
    
    var body: some View {
        ScrollView {
            
        }
        .safeAreaBar(edge: .top) {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .foregroundStyle(.tertiary.opacity(0.5))
                .frame(height: 240)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 40))
        }
        .safeAreaBar(edge: .bottom) {
            TextField("Ask whatever you'd like", text: $currentPrompt, axis: .vertical)
                .textFieldStyle(.glass)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
