import Foundation
import NaturalLanguage
import UIKit

/// Eojeol atoms and normalized UTF-16 source offsets; no semantic/syntactic parsing.
enum ReadingEngine {
    static func font(_ settings: ReaderSettings) -> UIFont { UIFont.systemFont(ofSize: max(1, settings.fontSize)) }
    static func width(_ text: String, settings: ReaderSettings) -> Double {
        NativeTextMetrics.measure(text, font: font(settings)).width
    }
    static func usableWidth(_ settings: ReaderSettings) -> Double { max(1, settings.panel.pixels.width - 2 * settings.padding) }
    static func capacity(_ settings: ReaderSettings) -> Int {
        let line = Double(font(settings).lineHeight) + max(0, settings.lineGap)
        return max(0, Int(floor(max(0, settings.panel.pixels.height - 2 * settings.padding - 8) / line)) - 1)
    }
    struct SentenceSpan { let range: NSRange }
    static func sentences(in document: SourceDocument) -> [SentenceSpan] {
        let text = document.normalizedText
        guard !text.isEmpty else { return [] }
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var spans: [SentenceSpan] = []
        // Blocks constrain sentence tokenization: heading/list/quote boundaries cannot merge.
        for block in document.blocks {
            guard let range = Range(block, in: text) else { continue }
            tokenizer.enumerateTokens(in: range) { token, _ in
                spans.append(SentenceSpan(range: NSRange(token, in: text))); return true
            }
        }
        return spans
    }
    private struct Atom { let text: String; let range: NSRange; let width: Double; let inkLeft: Double }
    static func build(text: String, settings: ReaderSettings) -> [ReadingUnit] {
        build(document: SourceDocument(source: text, format: .plain), settings: settings)
    }
    static func build(document: SourceDocument, settings: ReaderSettings) -> [ReadingUnit] {
        if settings.segmentation == .full || settings.presentation == .horizontal {
            return wholeDocument(document)
        }
        let source = document.normalizedText as NSString
        let regex = try! NSRegularExpression(pattern: "\\S+")
        let nativeFont = font(settings)
        var result: [ReadingUnit] = []
        for (sentenceIndex, sentence) in sentences(in: document).enumerated() {
            let atoms = regex.matches(in: document.normalizedText, range: sentence.range).map { match -> Atom in
                let text = source.substring(with: match.range)
                let metrics = NativeTextMetrics.measure(text, font: nativeFont)
                return Atom(text: text, range: match.range, width: metrics.width, inkLeft: metrics.inkLeft)
            }
            let groups: [[Atom]]
            switch settings.segmentation {
            case .balanced: groups = balanced(atoms, settings: settings, font: nativeFont)
            case .full: groups = [atoms]
            case .greedy: groups = greedy(atoms, settings: settings, font: nativeFont)
            case .eojeol: groups = eojeol(atoms).flatMap { greedy($0, settings: settings, font: nativeFont) }
            }
            for group in groups {
                guard let first = group.first, let last = group.last else { continue }
                let text = join(group[...])
                let scale = group.count == 1 ? fittingSingleScale(first, settings: settings) : 1
                // Measure with the exact font ultimately used for rendering, including fallback shrink.
                let renderedFont = UIFont.systemFont(ofSize: settings.fontSize * scale)
                let metrics = NativeTextMetrics.measure(text, font: renderedFont)
                var offset = 0
                let displayRanges = group.map { atom -> NSRange in
                    defer { offset += atom.text.utf16.count + 1 }
                    return NSRange(location: offset, length: atom.text.utf16.count)
                }
                let positions = NativeTextMetrics.tokenPositions(text: text, ranges: displayRanges, font: renderedFont)
                let tokens = group.indices.map { i in
                    ReadingToken(text: group[i].text, sourceRange: group[i].range, displayRange: displayRanges[i], x: positions[i].x, width: positions[i].width)
                }
                result.append(ReadingUnit(text: text, sentenceIndex: sentenceIndex,
                    sourceRange: NSRange(location: first.range.location, length: NSMaxRange(last.range) - first.range.location),
                    width: metrics.width, tokens: tokens, inkLeft: metrics.inkLeft, fontScale: scale))
            }
        }
        return result
    }
    private static func wholeDocument(_ document: SourceDocument) -> [ReadingUnit] {
        let ns = document.normalizedText as NSString
        let regex = try! NSRegularExpression(pattern: "\\S+")
        let tokens = regex.matches(in: document.normalizedText, range: NSRange(location: 0, length: ns.length)).map { match in
            ReadingToken(text: ns.substring(with: match.range), sourceRange: match.range, displayRange: match.range, x: 0, width: 0)
        }
        guard !tokens.isEmpty else { return [] }
        // DOM lays out whole-document tokens. Do not create a giant shaped CoreText line here.
        return [ReadingUnit(text: document.normalizedText, sentenceIndex: 0, sourceRange: NSRange(location: 0, length: ns.length), width: 0, tokens: tokens, inkLeft: 0, fontScale: 1)]
    }
    private static func fittingSingleScale(_ atom: Atom, settings: ReaderSettings) -> Double {
        if fits(width: atom.width, first: atom, settings: settings) { return 1 }
        // SF optical sizing and emoji fallback are not linear with font size.
        // Re-measure the final font instead of trusting a width-ratio approximation.
        var low = 0.0, high = 1.0
        for _ in 0..<32 {
            let scale = (low + high) / 2
            let m = NativeTextMetrics.measure(atom.text, font: UIFont.systemFont(ofSize: settings.fontSize * scale))
            if m.width + max(0, -m.inkLeft) <= usableWidth(settings) { low = scale }
            else { high = scale }
        }
        return low
    }
    private static func join(_ atoms: ArraySlice<Atom>) -> String { atoms.map(\.text).joined(separator: " ") }
    private static func measured(_ text: String, font: UIFont) -> Double { NativeTextMetrics.measure(text, font: font).width }
    private static func fits(width: Double, first: Atom, settings: ReaderSettings) -> Bool {
        width + max(0, -first.inkLeft) <= usableWidth(settings) + 0.001
    }
    private static func greedy(_ atoms: [Atom], settings: ReaderSettings, font: UIFont) -> [[Atom]] {
        var groups: [[Atom]] = [], start = 0, candidate = ""
        for end in atoms.indices {
            let next = candidate.isEmpty ? atoms[end].text : candidate + " " + atoms[end].text
            if end > start && !fits(width: measured(next, font: font), first: atoms[start], settings: settings) {
                groups.append(Array(atoms[start..<end])); start = end; candidate = atoms[end].text
            } else { candidate = next }
        }
        if start < atoms.count { groups.append(Array(atoms[start...])) }
        return groups
    }
    private static func bonus(_ text: String, terminal: Double, intermediate: Double) -> Double {
        let stripped = text.trimmingCharacters(in: CharacterSet(charactersIn: "\"'’”»》〉」』】)]}）"))
        guard let last = stripped.last else { return 0 }
        if ".!?。！？‼⁉…".contains(last) { return terminal }
        if ",，:：;；".contains(last) { return intermediate }
        return 0
    }
    private static func eojeol(_ atoms: [Atom]) -> [[Atom]] {
        guard !atoms.isEmpty else { return [] }
        let n = atoms.count
        var costs = Array(repeating: Double.infinity, count: n + 1), ends = Array(repeating: 0, count: n)
        costs[n] = 0
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in (i + 1)...min(n, i + 5) {
                let count = j - i
                let cost = costs[j] + Double(abs(count - 4) * 2) + (count < 3 && n > 1 ? 30 : 0) - bonus(atoms[j - 1].text, terminal: 12, intermediate: 6)
                if cost < costs[i] { costs[i] = cost; ends[i] = j }
            }
        }
        return reconstruct(atoms, ends: ends)
    }
    private static func balanced(_ atoms: [Atom], settings: ReaderSettings, font: UIFont) -> [[Atom]] {
        guard !atoms.isEmpty else { return [] }
        let n = atoms.count
        let full = measured(join(atoms[...]), font: font)
        if fits(width: full, first: atoms[0], settings: settings) { return [atoms] }
        let lane = usableWidth(settings)
        let ideal = min(lane * 0.88, full / max(2, ceil(full / lane)))
        var costs = Array(repeating: Double.infinity, count: n + 1), ends = Array(repeating: 0, count: n)
        costs[n] = 0
        for i in stride(from: n - 1, through: 0, by: -1) {
            var candidate = ""
            // Bounded lookahead is a compute bound, not a document or eojeol-count rule.
            for j in (i + 1)...min(n, i + 128) {
                candidate += (j == i + 1 ? "" : " ") + atoms[j - 1].text
                let w = measured(candidate, font: font)
                if !fits(width: w, first: atoms[i], settings: settings) {
                    if j == i + 1 { costs[i] = costs[j] + 150; ends[i] = j }
                    break
                }
                let deviation = (w - ideal) / max(1, ideal)
                let cost = costs[j] + 8 + deviation * deviation * 100 + (w < ideal * 0.45 ? 30 : 0) - bonus(atoms[j - 1].text, terminal: 4, intermediate: 2)
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
