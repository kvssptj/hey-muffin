import Speech
import SwiftUI

extension AttributedString {
    /// Returns a copy with low-confidence words styled in amber.
    /// Words with confidence below the threshold get an amber foreground color
    /// and a dotted underline so they're easy to spot and review.
    func confidenceStyled(threshold: Float = 0.65) -> AttributedString {
        var result = self
        for run in runs {
            guard let confidence = run[AttributeScopes.SpeechAttributes.ConfidenceAttribute.self],
                  confidence < threshold else { continue }
            result[run.range].foregroundColor = Color.orange.opacity(0.85)
            result[run.range].underlineStyle = Text.LineStyle(pattern: .dot, color: .orange.opacity(0.6))
        }
        return result
    }
}
