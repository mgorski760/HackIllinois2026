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

    // EventKit initializer (legacy support)
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
    
    // Google Calendar API initializer
    init?(from event: EventResponse, clampStart: Date? = nil, clampEnd: Date? = nil) {
        guard let start = event.start, let end = event.end else {
            return nil
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        
        guard let startDate = formatter.date(from: start.dateTime),
              let endDate = formatter.date(from: end.dateTime) else {
            return nil
        }
        
        self.id = event.id
        self.title = event.summary ?? "Untitled"
        self.startDate = clampStart.map { max(startDate, $0) } ?? startDate
        self.endDate = clampEnd.map { min(endDate, $0) } ?? endDate
        
        // Check if event is all-day (start and end times are at midnight and span full days)
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute, .second], from: startDate)
        let endComponents = calendar.dateComponents([.hour, .minute, .second], from: endDate)
        self.isAllDay = (startComponents.hour == 0 && startComponents.minute == 0 && startComponents.second == 0 &&
                        endComponents.hour == 0 && endComponents.minute == 0 && endComponents.second == 0)
        
        // Use a default color for Google Calendar events (could be enhanced with calendar-specific colors)
        self.color = .blue
        self.calendarTitle = "Google Calendar"
        self.location = event.location
        self.notes = event.description
    }
}
