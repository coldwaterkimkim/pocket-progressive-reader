import Foundation

enum SourceFormat: String, Codable, CaseIterable, Identifiable {
    case plain, markdown
    var id: String { rawValue }
    var title: String { self == .plain ? "일반 텍스트" : "Markdown" }
}

/// Reading text and UTF-16 structural ranges. This is an ingestion layer, not a Markdown renderer.
struct SourceDocument {
    let source: String
    let format: SourceFormat
    let normalizedText: String
    let blocks: [NSRange]

    init(source: String, format: SourceFormat) {
        self.source = source
        self.format = format
        let chunks = format == .markdown
            ? MarkdownNormalizer.blocks(source)
            : Self.plainBlocks(source)
        normalizedText = chunks.joined(separator: "\n\n")
        var offset = 0
        blocks = chunks.map { chunk in
            defer { offset += chunk.utf16.count + 2 }
            return NSRange(location: offset, length: chunk.utf16.count)
        }
    }

    private static func plainBlocks(_ source: String) -> [String] {
        // A line without punctuation still defines an explicit reading boundary.
        canonicalLines(source).split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

enum SourceIngestion {
    enum ReadError: LocalizedError {
        case unsupportedEncoding
        var errorDescription: String? { "UTF-8 또는 UTF-16 텍스트 파일을 선택해줘." }
    }

    static func read(url: URL) throws -> String {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        if data.starts(with: [0xFF, 0xFE]) {
            guard let text = String(data: data.dropFirst(2), encoding: .utf16LittleEndian) else {
                throw ReadError.unsupportedEncoding
            }
            return text
        }
        if data.starts(with: [0xFE, 0xFF]) {
            guard let text = String(data: data.dropFirst(2), encoding: .utf16BigEndian) else {
                throw ReadError.unsupportedEncoding
            }
            return text
        }
        let bytes = data.starts(with: [0xEF, 0xBB, 0xBF]) ? data.dropFirst(3) : data[...]
        guard let text = String(data: bytes, encoding: .utf8) else { throw ReadError.unsupportedEncoding }
        return text
    }
}

/// MVP normalization: structural blocks and readable inline text, without styling or URL output.
/// It deliberately does not implement CommonMark tables, nested HTML parsing, or a full AST.
enum MarkdownNormalizer {
    static func normalize(_ source: String) -> String { blocks(source).joined(separator: "\n\n") }

    static func blocks(_ source: String) -> [String] {
        var text = canonicalLines(source)
        text = replacing(text, pattern: "(?is)<!--.*?-->", with: "")
        text = replacing(text, pattern: "(?is)<(script|style)\\b[^>]*>.*?</\\1\\s*>", with: "")
        var references: [String: String] = [:]
        var lines = text.components(separatedBy: "\n")
        var referenceFence: Character?
        // Only collect definitions outside fenced code; code remains literal.
        for index in lines.indices {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let marker = trimmed.first!
                if referenceFence == marker { referenceFence = nil }
                else if referenceFence == nil { referenceFence = marker }
                continue
            }
            guard referenceFence == nil else { continue }
            if let match = captures(trimmed, pattern: "^\\[([^]]+)\\]:\\s*(?:<([^>]+)>|(\\S+))(?:\\s+.*)?$") {
                references[match[0].lowercased()] = match[1].isEmpty ? match[2] : match[1]
                lines[index] = ""
            }
        }
        var result: [String] = []
        var paragraph: [String] = []
        var code: [String] = []
        var fence: Character?
        func flush() {
            let value = inline(paragraph.joined(separator: " "), references: references)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { result.append(value) }
            paragraph.removeAll(keepingCapacity: true)
        }
        func flushCode() {
            let value = code.joined(separator: "\n").trimmingCharacters(in: .newlines)
            if !value.isEmpty { result.append(value) }
            code.removeAll(keepingCapacity: true)
        }
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let active = fence {
                if (active == "`" && trimmed.hasPrefix("```")) || (active == "~" && trimmed.hasPrefix("~~~")) {
                    flushCode(); fence = nil
                } else { code.append(line) }
                continue
            }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                flush(); fence = trimmed.first; continue
            }
            if trimmed.isEmpty { flush(); continue }
            // A setext underline terminates the preceding heading block.
            if captures(trimmed, pattern: "^(?:=+|-{2,})$") != nil { flush(); continue }
            if captures(trimmed, pattern: "^(?:\\*\\s*){3,}$|^(?:_\\s*){3,}$|^(?:-\\s*){3,}$") != nil { flush(); continue }
            var structural: String?
            if let match = captures(trimmed, pattern: "^#{1,6}\\s+(.+?)(?:\\s+#+)?$") { structural = match[0] }
            else if let match = captures(trimmed, pattern: "^(?:[-+*]|[0-9]+[.)])\\s+(?:\\[[ xX]\\]\\s+)?(.*)$") { structural = match[0] }
            else if let match = captures(trimmed, pattern: "^(?:>\\s*)+(.*)$") { structural = match[0] }
            if let structural {
                flush()
                let value = inline(structural, references: references).trimmingCharacters(in: .whitespaces)
                if !value.isEmpty { result.append(value) }
            } else { paragraph.append(trimmed) }
        }
        flush(); flushCode()
        return result
    }

    private static func inline(_ source: String, references: [String: String]) -> String {
        var protected: [String] = []
        func protect(_ value: String) -> String {
            protected.append(value)
            return "\u{E000}\(protected.count - 1)\u{E001}"
        }
        var value = transform(source, pattern: "\\\\([\\\\`*_{}\\[\\]()#+.!>~|-])") { protect($0[0]) }
        value = transform(value, pattern: "(`+)(.*?)\\1") { protect($0[1]) }
        value = replacing(value, pattern: "(?i)</?[a-z][a-z0-9-]*(?:\\s+[^>]*)?\\s*/?>|<(?:https?://|mailto:)[^>]+>", with: "")
        value = stripLinks(value, references: references)
        value = decodeEntities(value)
        for marker in ["\\*\\*\\*", "___", "\\*\\*", "__", "\\*", "_"] {
            // Word-internal underscores such as file_name must stay literal.
            let boundaryBefore = marker.contains("_") ? "(?<![\\p{L}\\p{N}_])" : ""
            let boundaryAfter = marker.contains("_") ? "(?![\\p{L}\\p{N}_])" : ""
            value = transform(value, pattern: "\(boundaryBefore)\(marker)(?=\\S)(.+?)(?<=\\S)\(marker)\(boundaryAfter)") { $0[0] }
        }
        value = transform(value, pattern: "~~(?=\\S)(.+?)(?<=\\S)~~") { $0[0] }
        for (index, text) in protected.enumerated() {
            value = value.replacingOccurrences(of: "\u{E000}\(index)\u{E001}", with: text)
        }
        return value
    }

    /// Pair delimiters once, then consume links in one forward pass. Unmatched syntax stays literal.
    private static func stripLinks(_ source: String, references: [String: String]) -> String {
        let chars = Array(source)
        var brackets: [Int] = []
        var parentheses: [Int] = []
        var pairs: [Int: Int] = [:]
        for (index, char) in chars.enumerated() {
            switch char {
            case "[": brackets.append(index)
            case "]": if let start = brackets.popLast() { pairs[start] = index }
            case "(": parentheses.append(index)
            case ")": if let start = parentheses.popLast() { pairs[start] = index }
            default: break
            }
        }
        var result = ""
        result.reserveCapacity(source.utf8.count)
        var index = 0
        while index < chars.count {
            let image = chars[index] == "!" && index + 1 < chars.count && chars[index + 1] == "["
            let start = image ? index + 1 : index
            guard chars[start] == "[", let end = pairs[start] else {
                result.append(chars[index]); index += 1; continue
            }
            let next = end + 1
            if next < chars.count, chars[next] == "(", let destinationEnd = pairs[next] {
                result.append(contentsOf: chars[(start + 1)..<end])
                index = destinationEnd + 1
                continue
            }
            let label = String(chars[(start + 1)..<end])
            if next < chars.count, chars[next] == "[", let referenceEnd = pairs[next] {
                let reference = String(chars[(next + 1)..<referenceEnd])
                let key = (reference.isEmpty ? label : reference).lowercased()
                if references[key] != nil { result += label }
                else { result.append(contentsOf: chars[index...referenceEnd]) }
                index = referenceEnd + 1
            } else {
                if references[label.lowercased()] != nil { result += label }
                else { result.append(contentsOf: chars[index...end]) }
                index = end + 1
            }
        }
        return result
    }

    private static func decodeEntities(_ source: String) -> String {
        let named = ["nbsp": " ", "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'"]
        return transform(source, pattern: "&(#(?:[xX][0-9a-fA-F]{1,8}|[0-9]{1,10})|[a-zA-Z]{2,8});") { groups in
            let entity = groups[0]
            if let value = named[entity] { return value }
            if entity.hasPrefix("#") {
                let hex = entity.hasPrefix("#x") || entity.hasPrefix("#X")
                let digits = entity.dropFirst(hex ? 2 : 1)
                if let number = UInt32(digits, radix: hex ? 16 : 10),
                   let scalar = UnicodeScalar(number), number != 0 {
                    return String(scalar)
                }
            }
            return "&\(entity);"
        }
    }

    private static func captures(_ source: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)) else { return nil }
        let ns = source as NSString
        return (1..<match.numberOfRanges).map { index in
            let range = match.range(at: index)
            return range.location == NSNotFound ? "" : ns.substring(with: range)
        }
    }

    private static func replacing(_ source: String, pattern: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return source }
        return regex.stringByReplacingMatches(in: source, range: NSRange(source.startIndex..., in: source), withTemplate: replacement)
    }

    private static func transform(_ source: String, pattern: String, replacement: ([String]) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return source }
        let ns = source as NSString
        var result = source
        for match in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)).reversed() {
            let groups = (1..<match.numberOfRanges).map { index -> String in
                let range = match.range(at: index)
                return range.location == NSNotFound ? "" : ns.substring(with: range)
            }
            guard let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: replacement(groups))
        }
        return result
    }
}

private func canonicalLines(_ source: String) -> String {
    source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
}
