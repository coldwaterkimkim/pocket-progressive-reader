import XCTest
@testable import PocketReader

final class ReadingEngineTests: XCTestCase {
    func testAllModesPreserveContentAndFitNativeWidth() {
        let text = "지금 읽는 부분은 같은 위치에 머문다. 이미 읽은 내용은 위에 남는다.\n\nLong English text should preserve every word, with natural boundaries."
        for mode in SegmentationMode.allCases {
            var settings = ReaderSettings()
            settings.segmentation = mode
            settings.panel = .bar225
            let units = ReadingEngine.build(text: text, settings: settings)
            XCTAssertEqual(compact(units.map(\.text).joined()), compact(text), "\(mode)")
            for unit in units {
                XCTAssertLessThanOrEqual(unit.width, ReadingEngine.usableWidth(settings) + 0.01)
                XCTAssertEqual(compact(unit.text), compact((text as NSString).substring(with: unit.sourceRange)))
            }
        }
    }
    func testLongUnicodeTokensPreserveGraphemesAndSourceRanges() {
        let text = String(repeating: "가족👨‍👩‍👧‍👦é", count: 35)
        for mode in SegmentationMode.allCases {
            var settings = ReaderSettings()
            settings.segmentation = mode
            settings.panel = .bar225
            let units = ReadingEngine.build(text: text, settings: settings)
            XCTAssertGreaterThan(units.count, 1)
            XCTAssertEqual(units.map(\.text).joined(), text)
            var offset = 0
            for unit in units {
                XCTAssertEqual(unit.sourceRange.location, offset)
                XCTAssertEqual((text as NSString).substring(with: unit.sourceRange), unit.text)
                XCTAssertLessThanOrEqual(unit.width, ReadingEngine.usableWidth(settings) + 0.01)
                offset = NSMaxRange(unit.sourceRange)
            }
            XCTAssertEqual(offset, text.utf16.count)
        }
    }
    func testWhitespaceAndEmptyInputAreSafe() {
        XCTAssertTrue(ReadingEngine.build(text: " \n\t", settings: ReaderSettings()).isEmpty)
        let units = ReadingEngine.build(text: "  첫째\t내용.\n\n둘째   내용.  ", settings: ReaderSettings())
        XCTAssertEqual(compact(units.map(\.text).joined()), "첫째내용.둘째내용.")
    }
    private func compact(_ value: String) -> String { value.filter { !$0.isWhitespace } }
}

@MainActor
final class ReaderStoreTests: XCTestCase {
    func testNavigationBoundsAndNoFutureHistoryAfterRegression() {
        let store = ReaderStore(persistenceURL: nil)
        store.move(Int.min)
        XCTAssertEqual(store.index, 0)
        store.move(Int.max)
        XCTAssertEqual(store.index, store.units.count - 1)
        store.move(-2)
        XCTAssertTrue(store.visiblePast.allSatisfy { $0.sourceRange.location < store.current!.sourceRange.location })
        store.settings.presentation = .current
        XCTAssertTrue(store.visiblePast.isEmpty)
        store.updateText("")
        store.move(1); store.moveSentence(1)
        XCTAssertNil(store.current)
        XCTAssertEqual(store.progress, 0)
    }
    func testSentenceNavigationAndHistoryReset() {
        let store = ReaderStore(persistenceURL: nil)
        store.updateText("첫 문장에는 충분히 여러 단어가 있어서 조각을 나눌 수 있다. 두 번째 문장도 충분히 길어서 나눠진다.")
        store.settings.panel = .bar225
        store.settings.presentation = .sentence
        store.rebuild()
        store.move(1)
        let previous = store.index
        store.moveSentence(-1)
        XCTAssertEqual(store.index, previous, "At first sentence, navigation is a no-op.")
        store.moveSentence(1)
        XCTAssertEqual(store.current?.sentenceIndex, 1)
        XCTAssertTrue(store.visiblePast.isEmpty)
        let nextStart = store.index
        store.moveSentence(1)
        XCTAssertEqual(store.index, nextStart)
        store.moveSentence(-1)
        XCTAssertEqual(store.index, 0)
    }
    func testReflowKeepsOriginalOffsetWithDuplicateText() {
        let store = ReaderStore(persistenceURL: nil)
        store.updateText(String(repeating: "같은 문장 같은 단어를 다시 읽는다. ", count: 20))
        store.move(store.units.count / 2)
        let offset = store.current!.sourceRange.location
        store.settings.fontSize = 30
        store.settings.panel = .bar225
        store.rebuild()
        XCTAssertLessThanOrEqual(store.current!.sourceRange.location, offset)
        XCTAssertGreaterThan(NSMaxRange(store.current!.sourceRange), offset)
        XCTAssertGreaterThan(store.index, 0)
    }
    func testPersistenceRestoresTextSettingsAndOffset() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("state.json")
        let store = ReaderStore(persistenceURL: url)
        store.settings.segmentation = .greedy
        store.rebuild()
        store.move(4)
        let restored = ReaderStore(persistenceURL: url)
        XCTAssertEqual(restored.text, store.text)
        XCTAssertEqual(restored.settings, store.settings)
        XCTAssertEqual(restored.current, store.current)
        XCTAssertNil(restored.persistenceError)
        try Data("broken".utf8).write(to: url)
        let corrupt = ReaderStore(persistenceURL: url)
        XCTAssertNotNil(corrupt.persistenceError)
        XCTAssertFalse(corrupt.units.isEmpty)
    }
    func testSampleModeNeverWritesPersistence() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ReaderStore(persistenceURL: url, sample: true)
        store.move(1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}
