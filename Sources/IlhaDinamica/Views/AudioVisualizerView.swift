import SwiftUI

struct AudioVisualizerView: View {
    let isPlaying: Bool
    let accentColor: Color
    var barCount: Int = 4
    var barWidth: CGFloat = 2.6
    var maxHeight: CGFloat = 15
    var spacing: CGFloat = 2.2

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05, paused: !isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(isPlaying ? accentColor : Color.white.opacity(0.45))
                        .frame(width: barWidth, height: barHeight(for: index, time: t))
                        .animation(.easeOut(duration: 0.14), value: isPlaying)
                }
            }
            .frame(height: maxHeight)
        }
    }

    private func barHeight(for index: Int, time: TimeInterval) -> CGFloat {
        guard isPlaying else {
            return 3.5
        }
        let speeds: [Double] = [6.8, 9.2, 7.7, 10.4, 8.1]
        let phases: [Double] = [0.0, 1.4, 2.7, 0.8, 2.1]
        let speed = speeds[index % speeds.count]
        let phase = phases[index % phases.count]

        let wave = (sin(time * speed + phase) + 1.0) * 0.5
        let harmonic = (cos(time * (speed * 0.63) + phase * 1.7) + 1.0) * 0.5
        let factor = 0.25 + 0.75 * (wave * 0.65 + harmonic * 0.35)
        return max(3.5, CGFloat(factor) * maxHeight)
    }
}
