import SwiftUI

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
