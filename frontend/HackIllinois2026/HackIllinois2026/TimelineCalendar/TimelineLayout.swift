import Foundation

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

        var columns: [Date] = []
        var slots: [LayoutSlot] = timed.map { event in
            var col = columns.firstIndex(where: { $0 <= event.startDate }) ?? columns.count
            if col == columns.count { columns.append(event.endDate) }
            else { columns[col] = event.endDate }
            return LayoutSlot(id: event.id, event: event, column: col, totalColumns: 0)
        }

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
