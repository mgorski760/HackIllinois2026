//
//  EventKitManager.swift
//  HackIllinois2026
//
//  Created by Om Chachad on 28/02/26.
//


import SwiftUI
import EventKit
import Combine

// MARK: - EventKit Manager

@MainActor
class EventKitManager: ObservableObject {
    let store = EKEventStore()

    @Published var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    func requestAccess() async {
        do {
            try await store.requestFullAccessToEvents()
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        } catch {
            print("Calendar access error: \(error)")
        }
    }

    var isAuthorized: Bool {
        return authorizationStatus == .fullAccess
    }

    func fetchEvents(for day: Date) -> [CalendarEvent] {
        guard isAuthorized else { return [] }
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        let dayEnd   = cal.date(byAdding: .day, value: 1, to: dayStart)!

        let predicate = store.predicateForEvents(withStart: dayStart, end: dayEnd, calendars: nil)
        return store.events(matching: predicate)
            .compactMap { ek -> CalendarEvent? in
                // All-day events: only show if they *start* on this day or span it.
                // Timed events: only show if they genuinely start on this day.
                // This prevents multi-day timed events from bleeding into subsequent days.
                if ek.isAllDay {
                    // Show all-day events that cover this day (EK already filters these correctly)
                    return CalendarEvent(ek: ek, clampStart: dayStart, clampEnd: dayEnd)
                } else {
                    // Only include if the event starts on this day
                    guard cal.isDate(ek.startDate, inSameDayAs: day) else { return nil }
                    // Clamp endDate to midnight so it doesn't spill into tomorrow's pixels
                    return CalendarEvent(ek: ek, clampStart: dayStart, clampEnd: dayEnd)
                }
            }
            .sorted { $0.startDate < $1.startDate }
    }
}

// MARK: - Calendar Event Model

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let color: Color
    let calendarTitle: String
    let location: String?
    let notes: String?

    init(ek: EKEvent, clampStart: Date? = nil, clampEnd: Date? = nil) {
        self.id            = ek.eventIdentifier ?? UUID().uuidString
        self.title         = ek.title ?? "Untitled"
        self.isAllDay      = ek.isAllDay
        self.color         = Color(cgColor: ek.calendar.cgColor)
        self.calendarTitle = ek.calendar.title
        self.location      = ek.location
        self.notes         = ek.notes
        // Clamp to day boundary so events don't render outside their day's pixel range
        self.startDate = clampStart.map { max(ek.startDate, $0) } ?? ek.startDate
        self.endDate   = clampEnd.map   { min(ek.endDate,   $0) } ?? ek.endDate
    }
}

// MARK: - Layout Engine

struct LayoutSlot: Identifiable {
    let id: String
    let event: CalendarEvent
    var column: Int
    var totalColumns: Int
}

enum TimelineLayout {
    /// Returns slots with column + totalColumns filled in.
    static func compute(_ events: [CalendarEvent]) -> [LayoutSlot] {
        let timed = events
            .filter { !$0.isAllDay }
            .sorted { $0.startDate == $1.startDate ? $0.endDate > $1.endDate : $0.startDate < $1.startDate }

        // Assign columns greedily
        var columns: [Date] = []          // stores the endDate of last event in each column
        var slots: [LayoutSlot] = timed.map { event in
            var col = columns.firstIndex(where: { $0 <= event.startDate }) ?? columns.count
            if col == columns.count { columns.append(event.endDate) }
            else { columns[col] = event.endDate }
            return LayoutSlot(id: event.id, event: event, column: col, totalColumns: 0)
        }

        // Compute totalColumns per overlap group
        for i in slots.indices {
            var maxCol = slots[i].column
            for j in slots.indices {
                let a = slots[i].event, b = slots[j].event
                if a.startDate < b.endDate && a.endDate > b.startDate {
                    maxCol = max(maxCol, slots[j].column)
                }
            }
            slots[i].totalColumns = maxCol + 1
        }
        return slots
    }
}

// MARK: - Timeline Calendar View (main entry point)

/// Drop-in SwiftUI calendar timeline. Add NSCalendarsUsageDescription to Info.plist.
public struct TimelineCalendarView: View {
    @StateObject private var manager = EventKitManager()
    @State private var selectedDate  = Date()

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if manager.isAuthorized {
                    TimelinePageView(selectedDate: $selectedDate)
                        .environmentObject(manager)
                } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
                    PermissionDeniedView()
                } else {
                    PermissionRequestView { Task { await manager.requestAccess() } }
                }
            }
            .navigationTitle(headerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    DateHeaderPicker(date: $selectedDate)
                }
            }
        }
        .task {
            if !manager.isAuthorized { await manager.requestAccess() }
        }
    }

    private var headerTitle: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"
        return f.string(from: selectedDate)
    }
}

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

// MARK: - Single Day Timeline

struct TimelineDayView: View {
    let date: Date
    let hourHeight: CGFloat
    @EnvironmentObject var manager: EventKitManager

    private let timeColWidth: CGFloat = 50
    private let hours = Array(0..<24)

    private var events: [CalendarEvent] { manager.fetchEvents(for: date) }
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
                            timeColWidth: timeColWidth                        )
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
                }
                .onAppear { scrollToNow(proxy: proxy) }
                .onChange(of: date) { _, _ in scrollToNow(proxy: proxy) }
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

// MARK: - Hour Grid

struct HourGrid: View {
    let hours: [Int]
    let hourHeight: CGFloat
    let timeColWidth: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                HStack(alignment: .top, spacing: 0) {
                    // Time label
                    Group {
                        if hour == 0 {
                            Text("").frame(width: timeColWidth)
                        } else {
                            Text(hourString(hour))
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundStyle(.secondary)
                                .frame(width: timeColWidth, alignment: .trailing)
                                .padding(.trailing, 8)
                                .offset(y: -7)
                        }
                    }
                    // Separator line
                    VStack(spacing: 0) {
                        Divider()
                        Spacer()
                    }
                    .frame(height: hourHeight)
                }
                .frame(height: hourHeight)
                .id("hour-\(hour)")
            }
        }
    }

    private func hourString(_ h: Int) -> String {
        var c = DateComponents(); c.hour = h; c.minute = 0
        let d = Calendar.current.date(from: c) ?? Date()
        let f = DateFormatter(); f.dateFormat = "h a"
        return f.string(from: d)
    }
}

// MARK: - Events Canvas

struct EventsCanvas: View {
    let slots: [LayoutSlot]
    let date: Date
    let hourHeight: CGFloat
    let timeColWidth: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            let eventWidth = geo.size.width - timeColWidth - 6
            ForEach(slots) { slot in
                EventBlock(
                    slot: slot,
                    hourHeight: hourHeight,
                    containerWidth: eventWidth
                )
                .offset(x: timeColWidth + 4)
            }
        }
    }
}

// MARK: - Event Block

struct EventBlock: View {
    let slot: LayoutSlot
    let hourHeight: CGFloat
    let containerWidth: CGFloat

    @State private var pressed = false
    
    @State private var showingDetails = false

    private var geometry: (x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        let cal = Calendar.current
        let e = slot.event

        func minutesFromMidnight(_ d: Date) -> CGFloat {
            let h = CGFloat(cal.component(.hour, from: d))
            let m = CGFloat(cal.component(.minute, from: d))
            return h * 60 + m
        }

        let startMin = minutesFromMidnight(e.startDate)
        let endMin   = minutesFromMidnight(e.endDate)
        let pixPerMin = hourHeight / 60.0

        let y = startMin * pixPerMin
        let h = max((endMin - startMin) * pixPerMin, 22)
        let colW = containerWidth / CGFloat(slot.totalColumns)
        let x = colW * CGFloat(slot.column)
        let w = colW - 2
        return (x, y, w, h)
    }

    var body: some View {
        let g = geometry
        let e = slot.event
        let isShort = g.h < 34

        Button {
            showingDetails = true
        } label: {
            ZStack(alignment: .topLeading) {
                // Background fill
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(e.color.opacity(0.12))

                // Left accent bar
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(e.color)
                        .frame(width: 3)
                    Spacer()
                }

                // Text content
                VStack(alignment: .leading, spacing: 1) {
                    Text(e.title)
                        .font(.system(size: isShort ? 11 : 12, weight: .semibold))
                        .foregroundStyle(e.color)
                        .lineLimit(isShort ? 1 : 3)

                    if !isShort {
                        if let loc = e.location, !loc.isEmpty {
                            Label(loc, systemImage: "mappin")
                                .font(.system(size: 10))
                                .foregroundStyle(e.color.opacity(0.75))
                                .lineLimit(1)
                        }
                        Text(timeLabel(e))
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(e.color.opacity(0.65))
                    }
                }
                .padding(.leading, 6)
                .padding(.vertical, 3)
                .padding(.trailing, 4)
            }
            .frame(width: g.w, height: g.h)
            .scaleEffect(pressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2), value: pressed)
        }
        .buttonStyle(.plain)
        .offset(x: g.x, y: g.y)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded   { _ in pressed = false }
        )
//        .popover(isPresented: $showingDetails) {
//            EventDetailSheet(event: slot.event)
//                .presentationCompactAdaptation(.popover)
//        }
    }

    private func timeLabel(_ e: CalendarEvent) -> String {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
        return "\(f.string(from: e.startDate)) – \(f.string(from: e.endDate))"
    }
}

// MARK: - Current Time Indicator

struct NowLine: View {
    let hourHeight: CGFloat
    let timeColWidth: CGFloat

    @State private var now = Date()
    let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var yOffset: CGFloat {
        let cal = Calendar.current
        let h = CGFloat(cal.component(.hour, from: now))
        let m = CGFloat(cal.component(.minute, from: now))
        return (h * 60 + m) / 60 * hourHeight
    }

    var body: some View {
        HStack(spacing: 0) {
            // Dot sitting on the time column edge
            Circle()
                .fill(Color.red)
                .frame(width: 9, height: 9)
                .padding(.leading, timeColWidth - 4.5)

            // Line extending across
            Rectangle()
                .fill(Color.red)
                .frame(height: 1.5)
        }
        .offset(y: yOffset - 4.5)           // centre the dot vertically
        .allowsHitTesting(false)
        .onReceive(timer) { now = $0 }
    }
}

// MARK: - All Day Strip

struct AllDayStrip: View {
    let events: [CalendarEvent]

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("ALL‑DAY")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .trailing)
                .padding(.top, 5)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(events) { event in
                        AllDaySingleStrip(event: event)
                    }
                }
                .padding(.vertical, 4)
                .padding(.trailing, 8)
            }
        }
        .padding(.leading, 4)
    }
}

struct AllDaySingleStrip: View {
    @State private var showingDetails = false
    
    let event: CalendarEvent
    
    var body: some View {
        Button { showingDetails = true } label: {
            Text(event.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(event.color, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
//        .popover(isPresented: $showingDetails) {
//            EventDetailSheet(event: event)
//                .presentationCompactAdaptation(.popover)
//        }
    }
}

// MARK: - Date Header Picker (inline nav strip)

struct DateHeaderPicker: View {
    @Binding var date: Date
    private let cal = Calendar.current

    private var weekDates: [Date] {
        let wd = cal.component(.weekday, from: date)
        let diff = (wd - cal.firstWeekday + 7) % 7
        guard let start = cal.date(byAdding: .day, value: -diff, to: date) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDates, id: \.self) { d in
                VStack(spacing: 2) {
                    Text(dayLetter(d))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    ZStack {
                        Circle()
                            .fill(circleColor(d))
                            .frame(width: 28, height: 28)
                        Text("\(cal.component(.day, from: d))")
                            .font(.system(size: 14, weight: labelWeight(d)))
                            .foregroundStyle(labelColor(d))
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.spring(response: 0.3)) { date = d } }
            }
        }
        .frame(width: 280)
    }

    private func dayLetter(_ d: Date) -> String {
        cal.veryShortWeekdaySymbols[cal.component(.weekday, from: d) - 1]
    }

    private func circleColor(_ d: Date) -> Color {
        if cal.isDate(d, inSameDayAs: date) {
            return cal.isDateInToday(d) ? .red : .primary
        }
        return .clear
    }

    private func labelColor(_ d: Date) -> Color {
        if cal.isDate(d, inSameDayAs: date) { return Color(uiColor: .systemBackground) }
        if cal.isDateInToday(d) { return .red }
        return .primary
    }

    private func labelWeight(_ d: Date) -> Font.Weight {
        cal.isDate(d, inSameDayAs: date) || cal.isDateInToday(d) ? .semibold : .regular
    }
}

// MARK: - Event Detail Sheet

struct EventDetailSheet: View {
    let event: CalendarEvent
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // Calendar color + name
                    Label {
                        Text(event.calendarTitle)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Circle().fill(event.color).frame(width: 10, height: 10)
                    }
                    .font(.subheadline)

                    // Date/time
                    Label(formattedDate, systemImage: "clock")
                        .font(.subheadline)

                    if let loc = event.location, !loc.isEmpty {
                        Label(loc, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                    }
                }

                if let notes = event.notes, !notes.isEmpty {
                    Section("Notes") {
                        Text(notes).font(.body)
                    }
                }
            }
            .navigationTitle(event.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var formattedDate: String {
        if event.isAllDay {
            let f = DateFormatter(); f.dateStyle = .long; f.timeStyle = .none
            return f.string(from: event.startDate)
        }
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
        return "\(event.startDate.formatted(date: .abbreviated, time: .omitted))  ·  \(f.string(from: event.startDate)) – \(f.string(from: event.endDate))"
    }
}

// MARK: - Permission Views

struct PermissionRequestView: View {
    let onRequest: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(.red)
                
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Calendar Access")
                        .font(.title2.weight(.semibold))
                    Text("Allow access to display your events in the timeline.")
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 230)
            }
            Button("Allow Access", action: onRequest)
                .buttonStyle(.borderedProminent)
                .tint(.red)
        }
    }
}

struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.minus")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                Text("Access Denied")
                    .font(.title2.weight(.semibold))
                Text("Enable calendar access in Settings > Privacy > Calendars.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)
            }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}


// MARK: - Comparable clamped helper

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview

#Preview {
    TimelineCalendarView()
}
