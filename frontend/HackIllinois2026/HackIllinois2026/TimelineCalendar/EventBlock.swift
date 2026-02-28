import SwiftUI

// MARK: - Event Block

struct EventBlock: View {
    let slot: LayoutSlot
    let hourHeight: CGFloat
    let containerWidth: CGFloat

    @State private var pressed = false
    @State private var showingDetails = false

    private var geometry: (x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        let cal = Calendar.current
        let e = slot.event

        func minutesFromMidnight(_ d: Date) -> CGFloat {
            let h = CGFloat(cal.component(.hour, from: d))
            let m = CGFloat(cal.component(.minute, from: d))
            return h * 60 + m
        }

        let startMin = minutesFromMidnight(e.startDate)
        let endMin   = minutesFromMidnight(e.endDate)
        let pixPerMin = hourHeight / 60.0

        let y = startMin * pixPerMin
        let h = max((endMin - startMin) * pixPerMin, 22)
        let colW = containerWidth / CGFloat(slot.totalColumns)
        let x = colW * CGFloat(slot.column)
        let w = colW - 2
        return (x, y, w, h)
    }

    var body: some View {
        let g = geometry
        let e = slot.event
        let isShort = g.h < 34

        Button {
            showingDetails = true
        } label: {
            ZStack(alignment: .topLeading) {
                // Background fill
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(e.color.opacity(0.12))

                // Left accent bar
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(e.color)
                        .frame(width: 3)
                    Spacer()
                }

                // Text content
                VStack(alignment: .leading, spacing: 1) {
                    Text(e.title)
                        .font(.system(size: isShort ? 11 : 12, weight: .semibold))
                        .foregroundStyle(e.color)
                        .lineLimit(isShort ? 1 : 3)

                    if !isShort {
                        if let loc = e.location, !loc.isEmpty {
                            Label(loc, systemImage: "mappin")
                                .font(.system(size: 10))
                                .foregroundStyle(e.color.opacity(0.75))
                                .lineLimit(1)
                        }
                        Text(timeLabel(e))
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(e.color.opacity(0.65))
                    }
                }
                .padding(.leading, 6)
                .padding(.vertical, 3)
                .padding(.trailing, 4)
            }
            .frame(width: g.w, height: g.h)
            .scaleEffect(pressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2), value: pressed)
        }
        .buttonStyle(.plain)
        .offset(x: g.x, y: g.y)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded   { _ in pressed = false }
        )
//        .popover(isPresented: $showingDetails) {
//            EventDetailSheet(event: slot.event)
//                .presentationCompactAdaptation(.popover)
//        }
    }

    private func timeLabel(_ e: CalendarEvent) -> String {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
        return "\(f.string(from: e.startDate)) – \(f.string(from: e.endDate))"
    }
}
