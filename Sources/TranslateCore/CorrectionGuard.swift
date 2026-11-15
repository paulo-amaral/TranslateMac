import Foundation

/// Decides whether text returned by a language model may be offered as a spelling
/// and grammar correction. A model can explain, translate or invent instead of
/// correcting, so its answer is never trusted as it comes.
public enum CorrectionGuard {
    public static func accepted(_ candidate: String, original: String) -> String? {
        let candidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        let original = original.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, candidate != original else { return nil }
        // A correction changes a few letters or words. A much longer or shorter answer is something else.
        let ratio = Double(candidate.count) / Double(original.count)
        guard (0.7...1.3).contains(ratio) else { return nil }
        // An answer that adds lines is usually commentary around the text.
        let lineCount = { (text: String) in text.split(whereSeparator: \.isNewline).count }
        guard lineCount(candidate) <= lineCount(original) else { return nil }
        return candidate
    }
}
