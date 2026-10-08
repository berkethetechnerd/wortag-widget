import SwiftUI

enum WortagTheme {
    static let paper = Color(red: 0.97, green: 0.95, blue: 0.90)
    static let ink = Color(red: 0.16, green: 0.22, blue: 0.19)
    static let muted = Color(red: 0.40, green: 0.45, blue: 0.39)
    static let accent = Color(red: 0.79, green: 0.31, blue: 0.20)
    static let sage = Color(red: 0.88, green: 0.91, blue: 0.84)
}

func highlighted(_ sentence: String, word: String, accent: Color? = WortagTheme.accent) -> AttributedString {
    var result = AttributedString(sentence)
    let pattern = "(?i)(?<![\\p{L}])" + NSRegularExpression.escapedPattern(for: word) + "(?![\\p{L}])"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
    for match in regex.matches(in: sentence, range: NSRange(sentence.startIndex..., in: sentence)) {
        if let range = Range(match.range, in: sentence),
           let start = AttributedString.Index(range.lowerBound, within: result),
           let end = AttributedString.Index(range.upperBound, within: result) {
            if let accent { result[start..<end].foregroundColor = accent }
            result[start..<end].inlinePresentationIntent = .stronglyEmphasized
        }
    }
    return result
}
