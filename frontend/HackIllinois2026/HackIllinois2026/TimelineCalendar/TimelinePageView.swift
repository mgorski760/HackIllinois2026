import SwiftUI

// MARK: - Horizontal paging between days

struct TimelinePageView: View {
    @Binding var selectedDate: Date
    @EnvironmentObject var manager: EventKitManager

    // We keep a separate anchor so we can silently shift it without jarring the UI.
    @State private var anchor: Date = Date()
    // 5-page window: indices 0…4, centre = 2. Gives two buffer pages on each side
    // so the swipe animation finishes inside the existing TabView before we re-centre.
    @State private var tab: Int = 2
    private let centre = 2
    @State private var isResetting = false

    // Zoom state — shared across all day pages so pinch feels global
    @State private var hourHeight: CGFloat = 20
    @State private var pinchBaseHeight: CGFloat = 64
    private let minHourHeight: CGFloat = 10
    private let maxHourHeight: CGFloat = 160

    private func dateForIndex(_ index: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: index - centre, to: anchor)!
    }

    var body: some View {
        TabView(selection: $tab) {
            ForEach(0..<5, id: \.self) { index in
                TimelineDayView(date: dateForIndex(index), hourHeight: hourHeight)
                    .environmentObject(manager)
                    .tag(index)
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { scale in
                                let clamped = (pinchBaseHeight * scale).clamped(to: minHourHeight...maxHourHeight)
                                hourHeight = clamped
                            }
                            .onEnded { scale in
                                pinchBaseHeight = (pinchBaseHeight * scale).clamped(to: minHourHeight...maxHourHeight)
                                hourHeight = pinchBaseHeight
                            }
                    )
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .contentShape(Rectangle())
        .onChange(of: tab) { _, newTab in
            guard !isResetting else { return }
            // Update selectedDate to match the page the user swiped to
            selectedDate = dateForIndex(newTab)

            // If we're still near the centre, no need to re-anchor yet
            guard newTab != centre else { return }
            isResetting = true
            // Wait for the page-turn animation to fully settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                // Shift anchor so the current page becomes the centre again
                let offset = newTab - centre
                anchor = Calendar.current.date(byAdding: .day, value: offset, to: anchor)!
                tab = centre
                isResetting = false
            }
        }
        .onChange(of: selectedDate) { _, newDate in
            // External date change (e.g. from the header picker) — re-anchor immediately
            let diff = Calendar.current.dateComponents([.day], from: anchor, to: newDate).day ?? 0
            guard diff != tab - centre else { return }
            anchor = newDate
            tab = centre
        }
        .onAppear {
            anchor = selectedDate
            tab = centre
        }
    }
}
