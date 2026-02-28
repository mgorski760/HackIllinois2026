import SwiftUI
import Combine

// MARK: - Current Time Indicator

struct NowLine: View {
    let hourHeight: CGFloat
    let timeColWidth: CGFloat

    @State private var now = Date()
    let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var yOffset: CGFloat {
        let cal = Calendar.current
        let h = CGFloat(cal.component(.hour, from: now))
        let m = CGFloat(cal.component(.minute, from: now))
        return (h * 60 + m) / 60 * hourHeight
    }

    var body: some View {
        HStack(spacing: 0) {
            // Dot sitting on the time column edge
            Circle()
                .fill(Color.red)
                .frame(width: 9, height: 9)
                .padding(.leading, timeColWidth - 4.5)

            // Line extending across
            Rectangle()
                .fill(Color.red)
                .frame(height: 1.5)
        }
        .offset(y: yOffset - 4.5)
        .allowsHitTesting(false)
        .onReceive(timer) { now = $0 }
    }
}
