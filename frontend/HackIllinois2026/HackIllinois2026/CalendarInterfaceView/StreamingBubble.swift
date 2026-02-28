//
//  StreamingBubble.swift
//  HackIllinois2026
//
//  Created by Om Chachad on 28/02/26.
//


import SwiftUI
import FoundationModels

struct StreamingBubble: View {
    let text: String

    var formattedContent: AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }

    var body: some View {
        HStack {
            Text(formattedContent)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular.tint(Color(.secondarySystemGroupedBackground)), in: .rect(cornerRadius: 18, style: .continuous))

            Spacer(minLength: 48)
        }
        .padding(.vertical, 2)
    }
}