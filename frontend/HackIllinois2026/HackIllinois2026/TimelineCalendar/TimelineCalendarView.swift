import SwiftUI

// MARK: - Timeline Calendar View (main entry point)

/// Drop-in SwiftUI calendar timeline using Google Calendar API
public struct TimelineCalendarView: View {
    @StateObject private var manager: GoogleCalendarManager
    @State private var selectedDate  = Date()

    /// Optional binding that the parent can drive to expand/collapse the calendar into full-screen.
    /// When `nil` the expand button is hidden (backward-compatible).
    var isExpanded: Binding<Bool>?

    init(manager: GoogleCalendarManager) {
        _manager = StateObject(wrappedValue: manager)
        self.isExpanded = nil
    }

    /// Designated init used by ContentView to wire up the full-screen expansion.
    init(manager: GoogleCalendarManager, isExpanded: Binding<Bool>) {
        _manager = StateObject(wrappedValue: manager)
        self.isExpanded = isExpanded
    }

    public var body: some View {
        NavigationStack {
            Group {
                if manager.isAuthorized {
                    TimelinePageView(selectedDate: $selectedDate)
                        .environmentObject(manager)
                } else {
                    PermissionDeniedView()
                }
            }
            .navigationTitle(headerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    DateHeaderPicker(date: $selectedDate)
                }
                if let isExpanded {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                isExpanded.wrappedValue.toggle()
                            }
                        } label: {
                            Image(systemName: isExpanded.wrappedValue
                                  ? "arrow.down.right.and.arrow.up.left"
                                  : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 13, weight: .semibold))
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .tint(.primary)
                    }
                }
            }
        }
    }

    private var headerTitle: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"
        return f.string(from: selectedDate)
    }
}

// MARK: - Preview

#Preview {
    // Preview requires proper initialization with dependencies
    Text("Preview requires GoogleCalendarManager setup")
}
