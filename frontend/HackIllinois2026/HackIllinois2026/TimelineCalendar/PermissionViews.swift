import SwiftUI

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
