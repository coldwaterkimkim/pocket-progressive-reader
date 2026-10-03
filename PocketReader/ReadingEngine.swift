import Foundation
import NaturalLanguage
import UIKit

/// Segmentation uses the same native font and panel-pixel coordinate system as the display.
/// Source ranges always refer to the untouched imported text, including Unicode UTF-16 offsets.
enum ReadingEngine {
    static func font(_ settings: ReaderSettings) -> UIFont {
        UIFont.systemFont(ofSize: max(1, settings.fontSize))
    }
    static func width(_ text: String, settings: ReaderSettings) -> Double {
        Double((text as NSString).size(withAttributes: [.font: font(settings)]).width)
    }
    static func usableWidth(_ settings: ReaderSettings) -> Double {
        max(1, settings.panel.pixels.width - 2 * settings.padding)
    }
    static func capacity(_ settings: ReaderSettings) -> Int {
        let line = Double(font(settings).lineHeight) + max(0, settings.lineGap)
        return max(0, Int(floor(max(0, settings.panel.pixels.height - 2 * settings.padding - 8) / line)) - 1)
    }

    private struct Atom {
        let text: String
        let range: NSRange
    }
    static func build(text: String, settings: ReaderSettings) -> [ReadingUnit] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        let source = text as NSString
        let regex = try! NSRegularExpression(pattern: "\\S+")
        var result: [ReadingUnit] = []
        var sentence = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentenceRange = NSRange(range, in: text)
            let raw = regex.matches(in: text, range: sentenceRange).map {
                Atom(text: source.substring(with: $0.range), range: $0.range)
            }
            guard !raw.isEmpty else { return true }
            let maxWidth = usableWidth(settings)
            let makeUnit: ([Atom]) -> ReadingUnit = { group in
                let first = group.first!, last = group.last!
                let span = NSRange(location: first.range.location, length: NSMaxRange(last.range) - first.range.location)
                let displayed = join(group[...])
                return ReadingUnit(text: displayed, sentenceIndex: sentence, sourceRange: span, width: width(displayed, settings: settings))
            }
            let groups: [[Atom]]
            switch settings.segmentation {
            case .eojeol:
                // Original 3–5 eojeol scoring (12/6 punctuation bonuses), then visual refit.
                groups = eojeol(raw).flatMap { greedy($0.flatMap { split($0, maxWidth: maxWidth, settings: settings) }, maxWidth: maxWidth, settings: settings) }
            case .greedy:
                groups = greedy(raw.flatMap { split($0, maxWidth: maxWidth, settings: settings) }, maxWidth: maxWidth, settings: settings)
            case .balanced:
                groups = balanced(raw.flatMap { split($0, maxWidth: maxWidth, settings: settings) }, maxWidth: maxWidth, settings: settings)
            }
            result.append(contentsOf: groups.map(makeUnit))
            sentence += 1
            return true
        }
        return result
    }

    private static func join(_ atoms: ArraySlice<Atom>) -> String {
        // Adjacent fragments of the same long token must not acquire artificial spaces.
        var text = "", previousEnd: Int?
        for atom in atoms {
            if !text.isEmpty && previousEnd != atom.range.location { text += " " }
            text += atom.text
            previousEnd = NSMaxRange(atom.range)
        }
        return text
    }
    private static func split(_ atom: Atom, maxWidth: Double, settings: ReaderSettings) -> [Atom] {
        guard width(atom.text, settings: settings) > maxWidth else { return [atom] }
        var parts: [Atom] = [], fragment = "", offset = atom.range.location
        for character in atom.text {
            let next = fragment + String(character)
            if !fragment.isEmpty && width(next, settings: settings) > maxWidth {
                parts.append(Atom(text: fragment, range: NSRange(location: offset, length: fragment.utf16.count)))
                offset += fragment.utf16.count
                fragment = ""
            }
            fragment.append(character)
        }
        if !fragment.isEmpty { parts.append(Atom(text: fragment, range: NSRange(location: offset, length: fragment.utf16.count))) }
        // A single grapheme wider than the lane cannot be divided without corrupting Unicode.
        return parts
    }
    private static func greedy(_ atoms: [Atom], maxWidth: Double, settings: ReaderSettings) -> [[Atom]] {
        var groups: [[Atom]] = [], start = 0
        for end in atoms.indices {
            if end > start && width(join(atoms[start...end]), settings: settings) > maxWidth {
                groups.append(Array(atoms[start..<end])); start = end
            }
        }
        if start < atoms.count { groups.append(Array(atoms[start...])) }
        return groups
    }
    private static func bonus(_ text: String, terminal: Double, intermediate: Double) -> Double {
        let closing = CharacterSet(charactersIn: "\"'’”»》〉」』】)]}）")
        let stripped = text.trimmingCharacters(in: closing)
        guard let last = stripped.last else { return 0 }
        if ".!?。！？‼⁉…".contains(last) { return terminal }
        if ",，:：;；".contains(last) { return intermediate }
        return 0
    }
    private static func eojeol(_ atoms: [Atom]) -> [[Atom]] {
        guard !atoms.isEmpty else { return [] }
        let n = atoms.count
        var scores = Array(repeating: -Double.infinity, count: n + 1)
        var ends = Array(repeating: 0, count: n)
        scores[n] = 0
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in (i + 1)...min(n, i + 5) {
                let text = join(atoms[i..<j]), count = j - i
                let chars = text.filter { !$0.isWhitespace }.count
                let desired = count == 4 ? (chars >= 30 ? 3 : chars <= 8 ? 5 : 4) : 4
                let score = scores[j] + bonus(text, terminal: 12, intermediate: 6) - Double(abs(count - desired) * 2) - (count < 3 && n > 1 ? 30 : 0)
                if score > scores[i] { scores[i] = score; ends[i] = j }
            }
        }
        return reconstruct(atoms, ends: ends)
    }
    private static func balanced(_ atoms: [Atom], maxWidth: Double, settings: ReaderSettings) -> [[Atom]] {
        guard !atoms.isEmpty else { return [] }
        let full = width(join(atoms[...]), settings: settings)
        if full <= maxWidth { return [atoms] }
        let ideal = min(maxWidth * 0.92, full / max(2, ceil(full / maxWidth)))
        let n = atoms.count
        var costs = Array(repeating: Double.infinity, count: n + 1)
        var ends = Array(repeating: 0, count: n)
        costs[n] = 0
        for i in stride(from: n - 1, through: 0, by: -1) {
            // Bound lookahead so pathological text cannot trigger quadratic candidate growth.
            for j in (i + 1)...min(n, i + 128) {
                let text = join(atoms[i..<j]), w = width(text, settings: settings)
                if w > maxWidth && j > i + 1 { break }
                let deviation = (w - ideal) / max(1, ideal)
                let cost = costs[j] + deviation * deviation * 100 + (w < ideal * 0.48 ? 24 : 0) - bonus(text, terminal: 42, intermediate: 18) + Double(max(0, j - i - 7) * 5)
                if cost < costs[i] { costs[i] = cost; ends[i] = j }
            }
        }
        return reconstruct(atoms, ends: ends)
    }
    private static func reconstruct(_ atoms: [Atom], ends: [Int]) -> [[Atom]] {
        var result: [[Atom]] = [], start = 0
        while start < atoms.count {
            let end = max(start + 1, ends[start])
            result.append(Array(atoms[start..<end])); start = end
        }
        return result
    }
}
