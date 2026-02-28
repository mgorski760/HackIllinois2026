//
//  MessageBubble.swift
//  HackIllinois2026
//
//  Created by Om Chachad on 28/02/26.
//


import SwiftUI
import FoundationModels

struct MessageBubble: View {
    let message: CalendarMessage
    private var isUser: Bool { message.role == .user }
    
    var formattedContent: AttributedString {
        (try? AttributedString(markdown: message.content)) ?? AttributedString(message.content)
    }
    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 48) }

            Group {
                if let attachment = message.attachment {
                    attachmentView(attachment)
                } else {
                    Text(formattedContent)
                        .font(.system(size: 15))
                        .foregroundStyle(isUser ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .glassEffect(.regular.tint(isUser ? Color(.systemBlue) : Color(.secondarySystemGroupedBackground)), in: .rect(cornerRadius: 18, style: .continuous))
                }
            }

            if !isUser { Spacer(minLength: 48) }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func attachmentView(_ attachment: CalendarMessage.Attachment) -> some View {
        switch attachment {
        case .image(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: 200, maxHeight: 260)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .glassEffect(.regular.tint(Color(.systemBlue).opacity(0.3)), in: .rect(cornerRadius: 18, style: .continuous))

        case .pdf(_, let filename):
            HStack(spacing: 10) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                Text(filename)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassEffect(.regular.tint(Color(.systemBlue)), in: .rect(cornerRadius: 18, style: .continuous))
        }
    }
}