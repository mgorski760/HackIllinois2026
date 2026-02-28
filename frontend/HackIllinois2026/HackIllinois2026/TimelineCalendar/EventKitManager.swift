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
                if ek.isAllDay {
                    return CalendarEvent(ek: ek, clampStart: dayStart, clampEnd: dayEnd)
                } else {
                    guard cal.isDate(ek.startDate, inSameDayAs: day) else { return nil }
                    return CalendarEvent(ek: ek, clampStart: dayStart, clampEnd: dayEnd)
                }
            }
            .sorted { $0.startDate < $1.startDate }
    }
}
