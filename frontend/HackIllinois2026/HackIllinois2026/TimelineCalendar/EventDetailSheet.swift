import SwiftUI

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
