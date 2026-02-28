//
//  CalendarWidgetModifier.swift
//  HackIllinois2026
//
//  Created by Om Chachad on 28/02/26.
//


import SwiftUI
import FoundationModels
import PhotosUI

struct CalendarWidgetModifier: ViewModifier {
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

extension View {
    func calendarWidget(isExpanded: Binding<Bool>, animation: Animation) -> some View {
        modifier(CalendarWidgetModifier(isExpanded: isExpanded, animation: animation))
    }
}
