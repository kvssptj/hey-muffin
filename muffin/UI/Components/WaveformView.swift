import SwiftUI

/// Magic Patterns `Waveform` — 1px bars, idle collapses to a hairline, quiet drift while recording.
struct WaveformView: View {
    enum State {
        case idle
        case recording
        case paused
        case playing
    }

    var state: State = .idle
    var level: CGFloat = 0.35
    var bars: Int = 48
    var height: CGFloat = 40
    var progress: CGFloat = 0

    private var baseAmplitudes: [CGFloat] {
        (0..<bars).map { i in
            let u = CGFloat(i) / CGFloat(max(bars - 1, 1))
            let envelope = 0.55 + 0.45 * sin(u * .pi)
            let noise = 0.35 + 0.65 * seeded(i, seed: 1)
            return min(1, max(0.08, envelope * noise))
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12, paused: state != .recording)) { timeline in
            let tick = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<bars, id: \.self) { i in
                    Capsule()
                        .fill(barColor(index: i))
                        .frame(width: 1)
                        .frame(maxWidth: .infinity)
                        .frame(height: barHeight(index: i, tick: tick))
                }
            }
            .frame(height: height)
        }
        .accessibilityLabel("Audio waveform")
    }

    private func barHeight(index: Int, tick: TimeInterval) -> CGFloat {
        if state == .idle { return 2 }
        var amp = baseAmplitudes[index]
        if state == .recording {
            let drift = 0.5 + 0.5 * sin(tick / 0.48 + Double(index) * 0.45)
            amp = min(1, max(0.06, amp * CGFloat(0.35 + 0.65 * drift) * (0.45 + level * 0.55)))
        } else if state == .paused {
            amp *= 0.55
        }
        return max(2, amp * height)
    }

    private func barColor(index: Int) -> Color {
        let playedIndex = Int((min(1, max(0, progress)) * CGFloat(bars)).rounded())
        let isPlayed = (state == .playing || state == .paused) && index < playedIndex
        if isPlayed { return OrionColor.textInk.opacity(0.75) }
        switch state {
        case .idle, .paused:
            return OrionColor.border.opacity(0.85)
        case .recording, .playing:
            return OrionColor.borderStrong.opacity(0.55)
        }
    }

    private func seeded(_ index: Int, seed: Int) -> CGFloat {
        let value = sin((Double(index) + 1) * 12.9898 + Double(seed) * 78.233) * 43758.5453
        return CGFloat(value - floor(value))
    }
}

struct LevelMeter: View {
    var level: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(OrionColor.border.opacity(0.45))
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(OrionColor.primary.opacity(0.65))
                    .frame(width: max(3, geo.size.width * min(max(level, 0), 1)))
            }
        }
        .frame(height: 3)
    }
}
