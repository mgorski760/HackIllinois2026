import SwiftUI

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
