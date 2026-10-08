import XCTest
@testable import PocketReader

final class FocusGroupingTests: XCTestCase {
    private func tokens(_ text: String) -> [ReadingToken] {
        var offset = 0
        return text.split(separator: " ").map { value in
            let text = String(value), range = NSRange(location: offset, length: text.utf16.count)
            offset += text.utf16.count + 1
            return ReadingToken(text: text, sourceRange: range, displayRange: range, x: 0, width: 0)
        }
    }
    private func texts(_ text: String, minimum: Int = 3, breaks: Set<Int> = []) -> [String] {
        let atoms = tokens(text)
        return FocusGrouping.build(tokens: atoms, minimum: minimum, hardBreaks: breaks)
            .map { atoms[$0.tokenRange].map(\.text).joined(separator: " ") }
    }
    func testForwardGroupingAndOriginalBaseline() {
        let text = "오늘이 어제보다 더 많이 배고프다."
        XCTAssertEqual(texts(text), ["오늘이", "어제보다", "더 많이", "배고프다."])
        XCTAssertEqual(texts(text, minimum: 1), text.split(separator: " ").map(String.init))
        XCTAssertEqual(texts("오늘은 더 많이 먹었다."), ["오늘은", "더 많이", "먹었다."])
    }
    func testTailMergesBackwardWithoutCrossingBoundary() {
        XCTAssertEqual(texts("나는 행복하다. 왜?", breaks: [2]), ["나는 행복하다.", "왜?"])
        XCTAssertEqual(texts("행복하다 왜?"), ["행복하다 왜?"])
        XCTAssertEqual(texts("그 때 왜 나한테 안 온 거야?"), ["그 때 왜", "나한테", "안 온 거야?"])
        XCTAssertEqual(texts("더 많이", breaks: [1]), ["더", "많이"])
    }
    func testUnicodePunctuationAndSymbols() {
        for (text, expected) in [("더,", 1), ("왜?", 1), ("나도.", 2), ("정말?", 2), ("(나)", 1), ("!!!", 0), ("👨‍👩‍👧‍👦", 1), ("é", 1), ("🇰🇷", 1), ("5kg", 3), (" ", 0)] {
            XCTAssertEqual(FocusGrouping.meaningfulLength(text), expected, text)
        }
        XCTAssertEqual(texts("!!! ?", minimum: 1), ["!!!", "?"])
        XCTAssertEqual(texts("A 한 2 kg 👨‍👩‍👧‍👦 끝"), ["A 한 2", "kg 👨‍👩‍👧‍👦 끝"])
    }
    func testCoverageAndMaximumForEveryMinimum() {
        let atoms = tokens("그 때 왜 나한테 안 온 거야? !!! hello 3 kg 한글은길다 끝")
        for minimum in 1...4 {
            let groups = FocusGrouping.build(tokens: atoms, minimum: minimum, hardBreaks: [7, 10])
            XCTAssertEqual(groups.flatMap { Array($0.tokenRange) }, Array(atoms.indices))
            XCTAssertTrue(groups.allSatisfy { $0.tokenEnd - $0.tokenStart <= 3 })
            XCTAssertFalse(groups.contains { $0.tokenStart < 7 && $0.tokenEnd > 7 })
            XCTAssertFalse(groups.contains { $0.tokenStart < 10 && $0.tokenEnd > 10 })
            XCTAssertEqual(groups, FocusGrouping.build(tokens: atoms, minimum: minimum, hardBreaks: [7, 10]))
        }
        XCTAssertEqual(texts(String(repeating: "아", count: 100)), [String(repeating: "아", count: 100)])
        XCTAssertEqual(FocusGrouping.build(tokens: [], minimum: 3), [])
    }
    @MainActor func testNavigationIsReversibleAndRegroupPreservesPosition() {
        let store = ReaderStore(persistenceURL: nil)
        store.settings.segmentation = .full
        store.settings.minimumFocusLength = 3
        store.updateText("오늘이 어제보다 더 많이 배고프다.")
        var forward: [Range<Int>] = []
        for _ in 0..<4 { store.moveFocus(1); forward.append(store.globalFocusedTokenRange!) }
        XCTAssertEqual(forward, [0..<1, 1..<2, 2..<4, 4..<5])
        for expected in forward.dropLast().reversed() {
            store.moveFocus(-1)
            XCTAssertEqual(store.globalFocusedTokenRange, expected)
        }
        store.moveFocus(2)
        let index = store.index, window = store.viewportEndIndex
        store.settings.minimumFocusLength = 1
        store.regroupFocus()
        XCTAssertEqual(store.globalFocusedTokenRange, 2..<3)
        store.moveFocus(1)
        XCTAssertEqual(store.globalFocusedTokenRange, 3..<4)
        store.settings.minimumFocusLength = 3
        store.regroupFocus()
        XCTAssertEqual(store.globalFocusedTokenRange, 2..<4)
        XCTAssertEqual(store.index, index)
        XCTAssertEqual(store.viewportEndIndex, window)
        store.move(1)
        XCTAssertNil(store.focusedGroup)
    }
    @MainActor func testWholeSentenceStructuralAndRevealBoundaries() {
        let store = ReaderStore(persistenceURL: nil)
        store.settings.segmentation = .full
        store.settings.minimumFocusLength = 3
        store.updateText("나는 행복하다. 왜?")
        XCTAssertEqual(store.focusGroups[0].last, FocusGroup(tokenStart: 2, tokenEnd: 3))
        store.updateText("더 많이 배고프다")
        store.acceptRenderedDocumentText("더 많이 배고프다", hardBreaks: [1])
        XCTAssertEqual(store.focusGroups[0].first, FocusGroup(tokenStart: 0, tokenEnd: 1))
        store.settings.segmentation = .greedy
        store.settings.panel = .bar225
        store.settings.fontSize = 34
        store.updateText("오늘은 어제보다 더 많이 배고프다 정말 그렇다.")
        for (unit, groups) in zip(store.units, store.focusGroups) {
            XCTAssertEqual(groups.flatMap { Array($0.tokenRange) }, Array(unit.tokens.indices))
        }
        let sequence = store.focusGroups.enumerated().flatMap { unit, groups in groups.map { (unit, $0.tokenStart) } }
        for expected in sequence { store.moveFocus(1); XCTAssertEqual(store.index, expected.0); XCTAssertEqual(store.focusedTokenIndex, expected.1) }
        for expected in sequence.dropLast().reversed() { store.moveFocus(-1); XCTAssertEqual(store.index, expected.0); XCTAssertEqual(store.focusedTokenIndex, expected.1) }
    }
}
