//
//  GlassTextFieldStyle.swift
//  HackIllinois2026
//
//  Created by Om Chachad on 27/02/26.
//

import SwiftUI

struct GlassTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .foregroundStyle(.tertiary.opacity(0.5))
                    .glassEffect(.regular, in: .rect(cornerRadius: 40))
            )
    }
}


extension TextFieldStyle where Self == GlassTextFieldStyle {
    static var glass: some TextFieldStyle {
        GlassTextFieldStyle()
    }
}
