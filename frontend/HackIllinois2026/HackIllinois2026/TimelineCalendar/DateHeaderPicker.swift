import SwiftUI

// MARK: - Date Header Picker (inline nav strip)

struct DateHeaderPicker: View {
    @Binding var date: Date
    private let cal = Calendar.current

    private var weekDates: [Date] {
        let wd = cal.component(.weekday, from: date)
        let diff = (wd - cal.firstWeekday + 7) % 7
        guard let start = cal.date(byAdding: .day, value: -diff, to: date) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDates, id: \.self) { d in
                VStack(spacing: 2) {
                    Text(dayLetter(d))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    ZStack {
                        Circle()
                            .fill(circleColor(d))
                            .frame(width: 28, height: 28)
                        Text("\(cal.component(.day, from: d))")
                            .font(.system(size: 14, weight: labelWeight(d)))
                            .foregroundStyle(labelColor(d))
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.spring(response: 0.3)) { date = d } }
            }
        }
        .frame(width: 280)
    }

    private func dayLetter(_ d: Date) -> String {
        cal.veryShortWeekdaySymbols[cal.component(.weekday, from: d) - 1]
    }

    private func circleColor(_ d: Date) -> Color {
        if cal.isDate(d, inSameDayAs: date) {
            return cal.isDateInToday(d) ? .red : .primary
        }
        return .clear
    }

    private func labelColor(_ d: Date) -> Color {
        if cal.isDate(d, inSameDayAs: date) { return Color(uiColor: .systemBackground) }
        if cal.isDateInToday(d) { return .red }
        return .primary
    }

    private func labelWeight(_ d: Date) -> Font.Weight {
        cal.isDate(d, inSameDayAs: date) || cal.isDateInToday(d) ? .semibold : .regular
    }
}
