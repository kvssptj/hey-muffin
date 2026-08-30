import SwiftUI

/// Vector guilloché field — drawn in Canvas so lines stay sharp at any window size / Retina scale.
/// Matches the sky-blue security-paper look of the reference (dense waves, corner rosettes, soft center waveform).
struct GuillocheBackground: View {
    /// Keep low so texture stays decorative (Orion DS: opt-in, never compete with content).
    var intensity: Double = 0.18

    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(OrionColor.background)
            )

            drawWaveField(context: context, size: size)
            // Corners only — skip dense center waveform ornament per DS guidance.
            drawCornerRosette(context: context, size: size, origin: CGPoint(x: size.width * 0.1, y: size.height * 0.14), scale: 0.16)
            drawCornerRosette(context: context, size: size, origin: CGPoint(x: size.width * 0.9, y: size.height * 0.86), scale: 0.14)
            drawPaperGrain(context: context, size: size)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Field

    private func drawWaveField(context: GraphicsContext, size: CGSize) {
        let cols = max(28, Int(size.width / 28))
        let rows = max(22, Int(size.height / 24))
        let hair: CGFloat = 0.45

        for i in 0..<cols {
            var path = Path()
            let u = Double(i) / Double(max(cols - 1, 1))
            for j in 0...rows {
                let v = Double(j) / Double(rows)
                let wave = sin(v * .pi * 4.2 + u * 5.5) * 8
                    + sin(v * .pi * 8.5 - u * 3.0) * 3.0
                let x = u * size.width + wave * 0.12
                let y = v * size.height + wave
                if j == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(
                path,
                with: .color(OrionColor.borderGuilloche.opacity(intensity * 0.9)),
                lineWidth: hair
            )
        }
    }

    // MARK: - Corner ornaments

    private func drawCornerRosette(context: GraphicsContext, size: CGSize, origin: CGPoint, scale: Double) {
        let maxR = min(size.width, size.height) * scale
        let rings = 22
        let steps = 240

        for ring in 1...rings {
            let r = maxR * (Double(ring) / Double(rings))
            var path = Path()
            for s in 0...steps {
                let a = (Double(s) / Double(steps)) * .pi * 2
                let petal = sin(a * 8) * (r * 0.035) + sin(a * 16) * (r * 0.012)
                let rr = r + petal
                let p = CGPoint(x: origin.x + cos(a) * rr, y: origin.y + sin(a) * rr)
                if s == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            context.stroke(
                path,
                with: .color(OrionColor.mutedOlive.opacity(intensity * (ring.isMultiple(of: 2) ? 0.42 : 0.26))),
                lineWidth: 0.5
            )
        }

        for k in 0..<32 {
            var path = Path()
            let base = (Double(k) / 32.0) * .pi * 2
            for s in 0...48 {
                let t = Double(s) / 48.0
                let a = base + sin(t * .pi * 3) * 0.28
                let r = maxR * 0.08 + t * maxR * 0.92
                let p = CGPoint(x: origin.x + cos(a) * r, y: origin.y + sin(a) * r)
                if s == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            context.stroke(
                path,
                with: .color(OrionColor.mutedOlive.opacity(intensity * 0.22)),
                lineWidth: 0.45
            )
        }
    }

    private func drawRibbonCorner(context: GraphicsContext, size: CGSize, topTrailing: Bool) {
        let bands = 14
        for b in 0..<bands {
            var path = Path()
            let offset = Double(b) * 3.2
            for i in 0...80 {
                let t = Double(i) / 80.0
                let localX: Double
                let localY: Double
                if topTrailing {
                    localX = size.width * (0.62 + t * 0.40)
                    localY = size.height * (0.02 + sin(t * .pi * 2.4 + Double(b) * 0.2) * 0.06)
                        + offset
                        + t * size.height * 0.28
                } else {
                    localX = size.width * (0.02 + t * 0.38)
                    localY = size.height * (0.72 + sin(t * .pi * 2.4 + Double(b) * 0.2) * 0.06)
                        + offset
                        + t * size.height * 0.22
                }
                let p = CGPoint(x: localX, y: localY)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            let olive = b.isMultiple(of: 2)
            context.stroke(
                path,
                with: .color(
                    (olive ? OrionColor.mutedOlive : OrionColor.skyBlue)
                        .opacity(intensity * (olive ? 0.32 : 0.28))
                ),
                lineWidth: 0.5
            )
        }
    }

    // MARK: - Center motif

    private func drawCenterWaveform(context: GraphicsContext, size: CGSize) {
        let midY = size.height * 0.48
        let midX = size.width * 0.5
        let halfW = size.width * 0.22
        let barCount = 48

        for i in 0..<barCount {
            let u = Double(i) / Double(barCount - 1)
            let x = midX - halfW + u * halfW * 2
            let envelope = sin(u * .pi)
            let h = (4.0 + abs(sin(u * .pi * 9)) * 18 + abs(sin(u * .pi * 3.5)) * 10) * envelope
            var path = Path()
            path.move(to: CGPoint(x: x, y: midY - h))
            path.addLine(to: CGPoint(x: x, y: midY + h))
            context.stroke(
                path,
                with: .color(OrionColor.warmIvory.opacity(intensity * 0.35)),
                lineWidth: 1.1
            )
        }

        for side in [-1.0, 1.0] {
            for lane in 0..<3 {
                var path = Path()
                let yOff = Double(lane - 1) * 5.5
                for i in 0...60 {
                    let t = Double(i) / 60.0
                    let x = midX + side * (halfW * 0.15 + t * halfW * 0.95)
                    let y = midY + yOff + sin(t * .pi * 4 + Double(lane)) * 6
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(
                    path,
                    with: .color(OrionColor.warmIvory.opacity(intensity * 0.22)),
                    style: StrokeStyle(lineWidth: 0.7, dash: [1.5, 2.5])
                )
            }
        }
    }

    private func drawPaperGrain(context: GraphicsContext, size: CGSize) {
        // Sparse 1px dots — subtle paper tooth without softening line work
        var rng = SeededGenerator(seed: 42)
        let count = Int((size.width * size.height) / 2200)
        for _ in 0..<count {
            let x = CGFloat.random(in: 0...size.width, using: &rng)
            let y = CGFloat.random(in: 0...size.height, using: &rng)
            let r = CGFloat.random(in: 0.3...0.7, using: &rng)
            let rect = CGRect(x: x, y: y, width: r, height: r)
            context.fill(
                Path(ellipseIn: rect),
                with: .color(OrionColor.ink.opacity(0.015))
            )
        }
    }
}

/// Compact engraved ring motif for headers / dividers.
struct GuillocheDivider: View {
    var body: some View {
        Canvas { context, size in
            let midY = size.height * 0.5
            for i in 0..<3 {
                var path = Path()
                let amp = 3.0 + Double(i)
                for x in stride(from: 0.0, through: size.width, by: 2) {
                    let u = x / size.width
                    let y = midY + sin(u * .pi * 8 + Double(i)) * amp
                    if x == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(
                    path,
                    with: .color(i == 1 ? OrionColor.mutedOlive.opacity(0.35) : OrionColor.skyBlue.opacity(0.28)),
                    lineWidth: 0.6
                )
            }
        }
        .frame(height: 14)
        .allowsHitTesting(false)
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
