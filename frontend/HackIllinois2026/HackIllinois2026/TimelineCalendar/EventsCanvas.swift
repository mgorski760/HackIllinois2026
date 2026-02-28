import SwiftUI

// MARK: - Events Canvas

struct EventsCanvas: View {
    let slots: [LayoutSlot]
    let date: Date
    let hourHeight: CGFloat
    let timeColWidth: CGFloat

    var body: some View {
        GeometryReader { geo in
            let eventWidth = geo.size.width - timeColWidth - 6
            ForEach(slots) { slot in
                EventBlock(
                    slot: slot,
                    hourHeight: hourHeight,
                    containerWidth: eventWidth
                )
                .offset(x: timeColWidth + 4)
            }
        }
    }
}
