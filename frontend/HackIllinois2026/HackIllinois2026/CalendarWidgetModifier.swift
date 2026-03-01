import SwiftUI
import PhotosUI

struct CalendarWidgetModifier: ViewModifier {
    @Binding var isExpanded: Bool
    let animation: Animation
    let calendarManager: GoogleCalendarManager

    private let padding: CGFloat       = 16
    private let compactHeight: CGFloat = 240
    private let compactCorner: CGFloat = 40
    private let expandedCorner: CGFloat = 0 // Fully square when expanded for edge-to-edge

    func body(content: Content) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                content
                    .safeAreaPadding(.top, isExpanded ? 0 : compactHeight + padding * 2)
                    .animation(animation, value: isExpanded)

                calendarView(geo: geo)
            }
        }
        .ignoresSafeArea(.all, edges: isExpanded ? .all : [])
    }

    private func calendarView(geo: GeometryProxy) -> some View {
        // Calculate dimensions for smooth animation
        let safeTop = geo.safeAreaInsets.top
        let safeBottom = geo.safeAreaInsets.bottom
        
        let width  = isExpanded ? geo.size.width : geo.size.width - padding * 2
        let height = isExpanded ? geo.size.height + safeTop + safeBottom : compactHeight
        let x      = isExpanded ? 0 : padding
        let y      = isExpanded ? -safeTop : padding
        let corner = isExpanded ? expandedCorner : compactCorner
        let shadowOpacity = isExpanded ? 0.0 : 0.12
        let shadowRadius: CGFloat = isExpanded ? 0 : 12

        return TimelineCalendarView(manager: calendarManager, isExpanded: $isExpanded)
            .frame(width: width, height: height)
            .background(Color(uiColor: .systemBackground))
            .clipShape(.rect(cornerRadius: corner))
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: corner))
            .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, y: 4)
            .offset(x: x, y: y)
            .zIndex(isExpanded ? 999 : 1)
            .onTapGesture {
                guard !isExpanded else { return }
                withAnimation(animation) { isExpanded = true }
            }
            .animation(animation, value: isExpanded)
    }
}

extension View {
    func calendarWidget(isExpanded: Binding<Bool>, animation: Animation, calendarManager: GoogleCalendarManager) -> some View {
        modifier(CalendarWidgetModifier(isExpanded: isExpanded, animation: animation, calendarManager: calendarManager))
    }
}
