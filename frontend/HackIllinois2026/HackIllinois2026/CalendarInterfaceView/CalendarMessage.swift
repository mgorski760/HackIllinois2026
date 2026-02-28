//
//  CalendarToolView.swift
//  HackIllinois2026
//
//  Created by Om Chachad on 28/02/26.
//

import SwiftUI
import FoundationModels


struct CalendarMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    let attachment: Attachment?

    enum Role {
        case user, assistant
    }

    enum Attachment {
        case image(UIImage)
        case pdf(url: URL, filename: String)
    }

    init(role: Role, content: String, attachment: Attachment? = nil) {
        self.role = role
        self.content = content
        self.attachment = attachment
    }
}
