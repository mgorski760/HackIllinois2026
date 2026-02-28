import SwiftUI
import EventKit

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
        self.startDate = clampStart.map { max(ek.startDate, $0) } ?? ek.startDate
        self.endDate   = clampEnd.map   { min(ek.endDate,   $0) } ?? ek.endDate
    }
}
