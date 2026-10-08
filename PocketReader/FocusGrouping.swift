import Foundation

/// Token indices are local to a reveal unit; the end is exclusive.
struct FocusGroup: Equatable {
    let tokenStart: Int
    let tokenEnd: Int
    var tokenRange: Range<Int> { tokenStart..<tokenEnd }
}

/// A deterministic layer above immutable eojeol/reveal segmentation.
enum FocusGrouping {
    static let maximumTokens = 3

    static func meaningfulLength(_ text: String) -> Int {
        text.reduce(0) { count, character in
            let excluded = character.unicodeScalars.allSatisfy {
                CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.punctuationCharacters.contains($0)
            }
            return count + (excluded ? 0 : 1)
        }
    }

    static func build(tokens: [ReadingToken], minimum: Int, hardBreaks: Set<Int> = []) -> [FocusGroup] {
        guard !tokens.isEmpty else { return [] }
        let minimum = min(4, max(1, minimum))
        // Baseline includes punctuation-only tokens exactly as the original navigation did.
        if minimum == 1 { return tokens.indices.map { FocusGroup(tokenStart: $0, tokenEnd: $0 + 1) } }
        let boundaries = [0] + hardBreaks.filter { $0 > 0 && $0 < tokens.count }.sorted() + [tokens.count]
        let lengths = tokens.map { meaningfulLength($0.text) }
        var result: [FocusGroup] = []
        for section in 0..<(boundaries.count - 1) {
            let lower = boundaries[section], upper = boundaries[section + 1]
            let firstGroup = result.count
            var start = lower
            while start < upper {
                var end = start + 1, count = lengths[start]
                while count < minimum && end < upper && end - start < maximumTokens {
                    count += lengths[end]
                    end += 1
                }
                let candidate = FocusGroup(tokenStart: start, tokenEnd: end)
                if end == upper && count < minimum && result.count > firstGroup,
                   let previous = result.last, end - previous.tokenStart <= maximumTokens {
                    result[result.count - 1] = FocusGroup(tokenStart: previous.tokenStart, tokenEnd: end)
                } else { result.append(candidate) }
                start = end
            }
        }
        return result
    }
}
