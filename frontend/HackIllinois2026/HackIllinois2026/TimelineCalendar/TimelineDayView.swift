import SwiftUI

// MARK: - Single Day Timeline

struct TimelineDayView: View {
    let date: Date
    let hourHeight: CGFloat
    @EnvironmentObject var manager: GoogleCalendarManager
    
    @State private var events: [CalendarEvent] = []
    @State private var isLoading = false

    private let timeColWidth: CGFloat = 50
    private let hours = Array(0..<24)

    private var allDayEvents: [CalendarEvent] { events.filter(\.isAllDay) }
    private var timedEvents:  [CalendarEvent] { events.filter { !$0.isAllDay } }

    var body: some View {
        VStack(spacing: 0) {
            // All-day strip
            if !allDayEvents.isEmpty {
                AllDayStrip(events: allDayEvents)
                Divider()
            }

            // Scrollable timeline
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        HourGrid(hours: hours, hourHeight: hourHeight, timeColWidth: timeColWidth)
                        EventsCanvas(
                            slots: TimelineLayout.compute(timedEvents),
                            date: date,
                            hourHeight: hourHeight,
                            timeColWidth: timeColWidth
                        )
                        if Calendar.current.isDateInToday(date) {
                            NowLine(hourHeight: hourHeight, timeColWidth: timeColWidth)
                        }
                    }
                    .frame(height: hourHeight * 24)
                    .padding(.bottom, 32)
                    .background(
                        Color(uiColor: .systemBackground)
                            .ignoresSafeArea()
                    )
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color(uiColor: .systemBackground).opacity(0.5))
                        }
                    }
                }
                .onAppear {
                    scrollToNow(proxy: proxy)
                    loadEvents()
                }
                .onChange(of: date) { _, _ in
                    scrollToNow(proxy: proxy)
                    loadEvents()
                }
                .onChange(of: manager.lastRefreshDate) { _, _ in
                    // Refresh events when triggered by AI actions
                    loadEvents()
                }
            }
        }
    }
    
    private func loadEvents() {
        isLoading = true
        Task {
            let fetchedEvents = await manager.fetchEvents(for: date)
            await MainActor.run {
                events = fetchedEvents
                isLoading = false
            }
        }
    }

    private func scrollToNow(proxy: ScrollViewProxy) {
        let hour = max(Calendar.current.component(.hour, from: Date()) - 1, 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.4)) {
                proxy.scrollTo("hour-\(hour)", anchor: .top)
            }
        }
    }
}
