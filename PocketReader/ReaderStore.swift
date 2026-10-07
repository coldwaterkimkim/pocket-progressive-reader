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
    private(set) var persistenceError: String?
    @ObservationIgnored private let persistenceURL: URL?
    @ObservationIgnored private var pendingSave: Task<Void, Never>?

    var current: ReadingUnit? { units.indices.contains(index) ? units[index] : nil }
    var progress: Double { units.isEmpty ? 0 : Double(index + 1) / Double(units.count) }
    var capacity: Int { ReadingEngine.capacity(settings) }
    var canGoBack: Bool { index > 0 }
    var canGoForward: Bool { index + 1 < units.count }
    var visiblePast: [ReadingUnit] {
        guard let current, settings.presentation != .current, index > 0 else { return [] }
        let limit = max(0, min(settings.pastLines, capacity))
        var history = Array(units[max(0, index - limit)..<index])
        if settings.presentation == .sentence { history = history.filter { $0.sentenceIndex == current.sentenceIndex } }
        return history
    }

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
                      (3...8).contains(snapshot.settings.pointsPerMM),
                      (0.2...0.5).contains(snapshot.settings.anchorFraction) else {
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
    }
    private func restoredIndex(_ offset: Int) -> Int {
        guard !units.isEmpty else { return 0 }
        // A changed line may begin before the previous focus. Keep its original text visible.
        return units.lastIndex(where: { $0.sourceRange.location <= offset }) ?? 0
    }
    func rebuild() {
        let offset = current?.sourceRange.location ?? 0
        units = ReadingEngine.build(document: document, settings: settings)
        index = restoredIndex(offset)
        save()
    }
    func updateText(_ text: String, format: SourceFormat = .plain) {
        self.text = text
        sourceFormat = format
        document = SourceDocument(source: text, format: format)
        units = ReadingEngine.build(document: document, settings: settings)
        index = 0
        save()
    }
    func move(_ delta: Int) {
        guard !units.isEmpty else { return }
        // Saturating bounds avoid integer overflow for arbitrary navigation input.
        if delta > 0 { index += min(delta, units.count - 1 - index) }
        if delta < 0 { index += max(delta, -index) }
        scheduleSave()
    }
    func moveSentence(_ delta: Int) {
        guard let current, delta != 0 else { return }
        let target = current.sentenceIndex + (delta > 0 ? 1 : -1)
        guard let destination = units.firstIndex(where: { $0.sentenceIndex == target }) else { return }
        index = destination
        scheduleSave()
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
            let snapshot = Snapshot(text: text, settings: settings, sourceOffset: current?.sourceRange.location ?? 0, sourceFormat: sourceFormat)
            try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
            persistenceError = nil
        } catch { persistenceError = "읽던 위치를 저장하지 못했어. 저장 공간을 확인해줘." }
    }
}
