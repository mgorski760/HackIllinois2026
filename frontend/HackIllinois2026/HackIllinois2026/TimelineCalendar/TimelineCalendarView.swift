import SwiftUI
import EventKit
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

// MARK: - Preview

#Preview {
    TimelineCalendarView()
}
