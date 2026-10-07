import Foundation
import Observation

@MainActor @Observable
final class ReaderStore {
    var text: String
    private(set) var sourceFormat: SourceFormat = .plain
    private(set) var document = SourceDocument(source: "", format: .plain)
    var settings: ReaderSettings
    private(set) var units: [ReadingUnit] = []
    private(set) var index = 0
    private(set) var focusedTokenIndex: Int?
    @ObservationIgnored private var tokenStarts: [Int] = []
    @ObservationIgnored private var totalTokens = 0
    var focusedToken: ReadingToken? {
        guard let current, let focus = focusedTokenIndex, current.tokens.indices.contains(focus) else { return nil }
        return current.tokens[focus]
    }
    private(set) var persistenceError: String?
    @ObservationIgnored private let persistenceURL: URL?
    @ObservationIgnored private var pendingSave: Task<Void, Never>?

    var current: ReadingUnit? { units.indices.contains(index) ? units[index] : nil }
    var progress: Double { units.isEmpty ? 0 : Double(index + 1) / Double(units.count) }
    var capacity: Int { ReadingEngine.capacity(settings) }
    var canGoBack: Bool { index > 0 }
    var canGoForward: Bool { index + 1 < units.count }
    private(set) var viewportEndIndex = 0
    private(set) var coarseTokenIndex: Int?
    var isWholeDocument: Bool { settings.segmentation == .full || settings.presentation == .horizontal }
    var globalFocusedTokenIndex: Int? {
        focusedTokenIndex.map { tokenStarts[index] + $0 }
    }
    var displayedUnits: [ReadingUnit] {
        guard !units.isEmpty else { return [] }
        if settings.presentation == .current || isWholeDocument { return current.map { [$0] } ?? [] }
        let end = min(viewportEndIndex, units.count - 1)
        let past = min(settings.pastLines, capacity)
        return Array(units[max(0, end - past)...end])
    }
    var visiblePast: [ReadingUnit] { displayedUnits.filter { $0.sourceRange.location < (current?.sourceRange.location ?? 0) } }

    nonisolated static var defaultPersistenceURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("PocketReader", isDirectory: true).appendingPathComponent("reading-state.json")
    }
    private struct Snapshot: Codable {
        var version: Int = 1
        let text: String
        let settings: ReaderSettings
        let sourceOffset: Int
        var sourceFormat: SourceFormat? = nil
    }
    init(persistenceURL: URL? = ReaderStore.defaultPersistenceURL, sample: Bool = false) {
        self.persistenceURL = sample ? nil : persistenceURL
        text = ReaderSample.text
        settings = ReaderSettings()
        var offset = 0
        if let url = self.persistenceURL, FileManager.default.fileExists(atPath: url.path) {
            do {
                let snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
                guard snapshot.version == 1,
                      (10...34).contains(snapshot.settings.fontSize),
                      (0...18).contains(snapshot.settings.lineGap),
                      (2...30).contains(snapshot.settings.padding),
                      (0...6).contains(snapshot.settings.pastLines),
                      (3...8).contains(snapshot.settings.pointsPerMM) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                text = snapshot.text
                sourceFormat = snapshot.sourceFormat ?? .plain
                settings = snapshot.settings
                offset = max(0, snapshot.sourceOffset)
            } catch { persistenceError = "저장된 읽기 상태를 불러오지 못했어. 새로 읽기를 시작할 수 있어." }
        }
        document = SourceDocument(source: text, format: sourceFormat)
        units = ReadingEngine.build(document: document, settings: settings)
        index = restoredIndex(offset)
        reindexTokens()
        viewportEndIndex = index
        if isWholeDocument { coarseTokenIndex = units.first?.tokens.lastIndex(where: { $0.sourceRange.location <= offset }) }
    }
    private func restoredIndex(_ offset: Int) -> Int {
        guard !units.isEmpty else { return 0 }
        // A changed line may begin before the previous focus. Keep its original text visible.
        return units.lastIndex(where: { $0.sourceRange.location <= offset }) ?? 0
    }
    func rebuild() {
        focusedTokenIndex = nil
        let offset = current?.sourceRange.location ?? 0
        units = ReadingEngine.build(document: document, settings: settings)
        index = restoredIndex(offset)
        reindexTokens()
        viewportEndIndex = index
        coarseTokenIndex = nil
        save()
    }
    func updateText(_ text: String, format: SourceFormat = .plain) {
        focusedTokenIndex = nil
        self.text = text
        sourceFormat = format
        document = SourceDocument(source: text, format: format)
        units = ReadingEngine.build(document: document, settings: settings)
        index = 0
        reindexTokens()
        viewportEndIndex = index
        coarseTokenIndex = nil
        save()
    }
    func move(_ delta: Int) {
        if isWholeDocument {
            let position = focusedTokenIndex ?? coarseTokenIndex ?? 0
            focusedTokenIndex = nil
            guard let current, !current.tokens.isEmpty, delta != 0 else { return }
            coarseTokenIndex = max(0, min(current.tokens.count - 1, position + (delta > 0 ? 1 : -1)))
            scheduleSave()
            return
        }
        focusedTokenIndex = nil
        guard !units.isEmpty else { return }
        // Saturating bounds avoid integer overflow for arbitrary navigation input.
        if delta > 0 { index += min(delta, units.count - 1 - index) }
        if delta < 0 { index += max(delta, -index) }
        viewportEndIndex = index
        coarseTokenIndex = nil
        scheduleSave()
    }
    func moveSentence(_ delta: Int) {
        let focusedOffset = focusedToken?.sourceRange.location
        focusedTokenIndex = nil
        guard let current, delta != 0 else { return }
        if isWholeDocument {
            let spans = ReadingEngine.sentences(in: document)
            let tokens = current.tokens
            let offset = focusedOffset ?? (tokens.indices.contains(coarseTokenIndex ?? -1) ? tokens[coarseTokenIndex!].sourceRange.location : 0)
            let currentSentence = spans.lastIndex(where: { $0.range.location <= offset }) ?? 0
            let nextSentence = max(0, min(spans.count - 1, currentSentence + (delta > 0 ? 1 : -1)))
            guard spans.indices.contains(nextSentence) else { return }
            coarseTokenIndex = tokens.firstIndex(where: { $0.sourceRange.location >= spans[nextSentence].range.location })
            scheduleSave()
            return
        }
        let target = current.sentenceIndex + (delta > 0 ? 1 : -1)
        guard let destination = units.firstIndex(where: { $0.sentenceIndex == target }) else { return }
        index = destination
        viewportEndIndex = index
        coarseTokenIndex = nil
        scheduleSave()
    }
    private func reindexTokens() {
        var offset = 0
        tokenStarts = units.map { unit in
            defer { offset += unit.tokens.count }
            return offset
        }
        totalTokens = offset
    }
    /// Encoder steps only. First step activates this unit's first/last token; thereafter
    /// steps walk the document's token sequence. Coarse navigation deliberately clears it.
    func moveFocus(_ delta: Int) {
        guard delta != 0, let current, !current.tokens.isEmpty, totalTokens > 0 else { return }
        let base: Int, step: Int
        if let focus = focusedTokenIndex {
            base = tokenStarts[index] + focus; step = delta
        } else {
            base = tokenStarts[index] + (coarseTokenIndex ?? (delta > 0 ? 0 : current.tokens.count - 1))
            step = delta > 0 ? delta - 1 : delta + 1
        }
        let target = base + min(totalTokens - 1 - base, max(-base, step))
        let previousIndex = index
        var low = 0, high = units.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if tokenStarts[mid] <= target { low = mid } else { high = mid - 1 }
        }
        index = low
        focusedTokenIndex = target - tokenStarts[index]
        coarseTokenIndex = nil
        if settings.presentation == .past && !isWholeDocument {
            let slots = min(settings.pastLines, capacity)
            if index > viewportEndIndex { viewportEndIndex = index }
            if index < max(0, viewportEndIndex - slots) { viewportEndIndex = min(units.count - 1, index + slots) }
        } else { viewportEndIndex = index }
        // Fine focus is transient; only crossing a reveal changes saved reading position.
        if index != previousIndex { scheduleSave() }
    }
    func acceptRenderedDocumentText(_ text: String) {
        guard isWholeDocument else { return }
        let rendered = SourceDocument(source: text, format: .plain)
        guard rendered.normalizedText != document.normalizedText else { return }
        let offset = current?.sourceRange.location ?? 0
        document = rendered
        units = ReadingEngine.build(document: document, settings: settings)
        index = restoredIndex(offset)
        focusedTokenIndex = nil
        reindexTokens()
        viewportEndIndex = index
    }
    private func scheduleSave() {
        guard persistenceURL != nil else { return }
        pendingSave?.cancel()
        // Let a wheel gesture update the screen immediately; persist once it settles.
        pendingSave = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)) }
            catch { return }
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }
    /// Flushes any pending navigation immediately, including on scene backgrounding.
    func save() {
        pendingSave?.cancel()
        pendingSave = nil
        guard let url = persistenceURL else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let snapshot = Snapshot(text: text, settings: settings, sourceOffset: focusedToken?.sourceRange.location ?? (coarseTokenIndex.flatMap { current?.tokens.indices.contains($0) == true ? current?.tokens[$0].sourceRange.location : nil } ?? current?.sourceRange.location ?? 0), sourceFormat: sourceFormat)
            try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
            persistenceError = nil
        } catch { persistenceError = "읽던 위치를 저장하지 못했어. 저장 공간을 확인해줘." }
    }
}
