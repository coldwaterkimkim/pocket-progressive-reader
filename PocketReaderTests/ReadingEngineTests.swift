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
    func testLongUnicodeEojeolRemainsAtomicAndFits() {
        let text = String(repeating: "가족👨‍👩‍👧‍👦é", count: 35)
        for mode in SegmentationMode.allCases {
            var settings = ReaderSettings()
            settings.segmentation = mode
            settings.panel = .bar225
            let units = ReadingEngine.build(text: text, settings: settings)
            XCTAssertEqual(units.count, 1)
            XCTAssertLessThan(units[0].fontScale, 1)
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
    func testLeftAlignedTokensAndBoundsAcrossPanelsAndChunkers() {
        let text = "가나다라마바사아자차카타파하 아주 짧은 글, 그리고 다양한 어절의 길이를 비교한다. English extraordinarilylongword and 한글👨‍👩‍👧‍👦도 유지한다."
        let document = SourceDocument(source: text, format: .plain)
        for panel in PanelPreset.allCases {
            for mode in SegmentationMode.allCases {
                for size in [10.0, 26.0, 34.0] {
                    var settings = ReaderSettings()
                    settings.panel = panel; settings.segmentation = mode; settings.fontSize = size
                    let units = ReadingEngine.build(document: document, settings: settings)
                    XCTAssertEqual(compact(units.map(\.text).joined()), compact(text))
                    for unit in units {
                        XCTAssertLessThanOrEqual(unit.width + max(0, -unit.inkLeft), ReadingEngine.usableWidth(settings) + 0.01)
                        XCTAssertEqual(unit.tokens.map(\.text).joined(separator: " "), unit.text)
                        var previousEnd = 0.0
                        for token in unit.tokens {
                            XCTAssertEqual((unit.text as NSString).substring(with: token.displayRange), token.text)
                            XCTAssertEqual((document.normalizedText as NSString).substring(with: token.sourceRange), token.text)
                            XCTAssertGreaterThanOrEqual(token.x, previousEnd - 0.01)
                            XCTAssertGreaterThan(token.width, 0)
                            XCTAssertLessThanOrEqual(token.x + token.width, unit.width + 0.01)
                            previousEnd = token.x + token.width
                        }
                    }
                }
            }
        }
    }
    func testHighlightStyleDoesNotAffectChunkOrTokenGeometry() {
        var settings = ReaderSettings()
        let original = ReadingEngine.build(text: ReaderSample.text, settings: settings)
        for style in WordFocusStyle.allCases {
            settings.wordFocusStyle = style
            XCTAssertEqual(ReadingEngine.build(text: ReaderSample.text, settings: settings), original)
        }
    }
    func testCurrentOnlyCenteredAndTypewriterBaselineStable() {
        for panel in PanelPreset.allCases {
            var settings = ReaderSettings(); settings.panel = panel
            settings.presentation = .current
            let line = Double(ReadingEngine.font(settings).lineHeight)
            XCTAssertEqual(PresentationGeometry.currentTop(settings: settings) + line / 2, panel.pixels.height / 2, accuracy: 0.001)
            settings.presentation = .past
            let top = PresentationGeometry.currentTop(settings: settings)
            settings.showProgress.toggle()
            XCTAssertEqual(PresentationGeometry.currentTop(settings: settings), top)
            settings.presentation = .sentence
            XCTAssertEqual(PresentationGeometry.currentTop(settings: settings), top)
        }
    }
    func testLargeDocumentHasNoApplicationSizeRejection() {
        let text = String(repeating: "문서의 내용을 천천히 읽는다.\n\n", count: 12_000)
        XCTAssertGreaterThan(text.utf16.count, 200_000)
        let units = ReadingEngine.build(text: text, settings: ReaderSettings())
        XCTAssertEqual(compact(units.map(\.text).joined()), compact(text))
        XCTAssertGreaterThanOrEqual(units.count, 12_000)
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
        store.save()
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
    func testExplicitSaveFlushesLatestPendingMovement() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("state.json")
        let store = ReaderStore(persistenceURL: url)
        store.save()
        let initial = try Data(contentsOf: url)
        store.move(3)
        store.move(-1)
        XCTAssertEqual(try Data(contentsOf: url), initial, "Detents do not synchronously rewrite the full document.")
        store.save()
        let restored = ReaderStore(persistenceURL: url)
        XCTAssertEqual(restored.current, store.current)
        XCTAssertEqual(restored.index, 2)
        XCTAssertTrue(restored.visiblePast.allSatisfy { $0.sourceRange.location < restored.current!.sourceRange.location })
    }
    func testDelayedSavePersistsLatestMovement() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("state.json")
        let store = ReaderStore(persistenceURL: url)
        store.move(3)
        store.move(-1)
        try await Task.sleep(for: .milliseconds(600))
        let restored = ReaderStore(persistenceURL: url)
        XCTAssertEqual(restored.current, store.current)
        XCTAssertEqual(restored.index, 2)
    }
    func testOldSavedSettingsMigrateWithoutLosingTextOrPosition() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let original = ReaderStore(persistenceURL: url)
        original.move(2); original.save()
        var json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        var settings = json["settings"] as! [String: Any]
        // Retired settings from the previously installed build must be ignored, then dropped.
        settings["alignment"] = "gazeAnchor"; settings["anchorFraction"] = 0.33
        settings.removeValue(forKey: "wordFocusStyle")
        json["settings"] = settings; json.removeValue(forKey: "sourceFormat")
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        let restored = ReaderStore(persistenceURL: url)
        XCTAssertNil(restored.persistenceError)
        XCTAssertEqual(restored.text, original.text)
        XCTAssertEqual(restored.current, original.current)
        XCTAssertEqual(restored.settings.wordFocusStyle, .yellow)
        restored.save()
        let saved = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        let savedSettings = saved["settings"] as! [String: Any]
        XCTAssertNil(savedSettings["alignment"])
        XCTAssertNil(savedSettings["anchorFraction"])
    }
    func testMarkdownSourceFormatAndNormalizedPositionPersist() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ReaderStore(persistenceURL: url)
        store.updateText("## 제목\n\n- **첫 항목**\n- [둘째](https://example.com)", format: .markdown)
        store.move(1); store.save()
        let restored = ReaderStore(persistenceURL: url)
        XCTAssertEqual(restored.sourceFormat, .markdown)
        XCTAssertEqual(restored.text, store.text)
        XCTAssertEqual(restored.current, store.current)
        XCTAssertFalse(restored.units.map(\.text).joined().contains("https"))
        XCTAssertEqual(Set(restored.units.map(\.sentenceIndex)).count, 3)
    }
    func testFineTraversalActivatesThenCrossesBothWaysWithoutSkippingTokens() {
        let store = ReaderStore(persistenceURL: nil)
        store.settings.panel = .bar225; store.settings.fontSize = 34
        store.updateText("나는 오늘 작은 리더기를 직접 만들어 보기로 했다. 다음 문장도 천천히 읽는다.")
        XCTAssertNil(store.focusedTokenIndex)
        let expected = store.units.flatMap(\.tokens).map(\.text)
        var visited: [String] = []
        for _ in expected.indices { store.moveFocus(1); visited.append(store.focusedToken!.text) }
        XCTAssertEqual(visited, expected)
        let lastIndex = store.index, lastFocus = store.focusedTokenIndex
        store.moveFocus(1)
        XCTAssertEqual(store.index, lastIndex); XCTAssertEqual(store.focusedTokenIndex, lastFocus)
        for expectedWord in expected.dropLast().reversed() {
            store.moveFocus(-1); XCTAssertEqual(store.focusedToken?.text, expectedWord)
        }
        XCTAssertEqual(store.index, 0); XCTAssertEqual(store.focusedTokenIndex, 0)
        store.moveFocus(-1)
        XCTAssertEqual(store.focusedTokenIndex, 0)
        store.move(0); store.moveFocus(-1)
        XCTAssertEqual(store.focusedTokenIndex, store.current!.tokens.count - 1)
    }
    func testEveryCoarseActionClearsFocusIncludingBoundaryNoOp() {
        let store = ReaderStore(persistenceURL: nil)
        store.updateText("처음 문장을 천천히 읽는다. 다음 문장을 읽는다.")
        store.moveFocus(1); store.move(-1); XCTAssertNil(store.focusedTokenIndex)
        store.moveFocus(1); store.moveSentence(-1); XCTAssertNil(store.focusedTokenIndex)
        store.moveFocus(1); store.move(1); XCTAssertNil(store.focusedTokenIndex)
        store.moveFocus(1); store.moveSentence(1); XCTAssertNil(store.focusedTokenIndex)
        store.moveFocus(1); store.moveSentence(1); XCTAssertNil(store.focusedTokenIndex)
        store.moveFocus(1); store.rebuild(); XCTAssertNil(store.focusedTokenIndex)
        store.moveFocus(1); store.updateText(""); store.moveFocus(Int.max); XCTAssertNil(store.focusedTokenIndex)
    }
    func testFocusStaysTransientAndSurvivesHighlightStyleChanges() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ReaderStore(persistenceURL: url)
        store.moveFocus(2)
        let originalFocus = store.focusedTokenIndex
        for style in WordFocusStyle.allCases {
            store.settings.wordFocusStyle = style
            XCTAssertEqual(store.focusedTokenIndex, originalFocus)
        }
        store.save()
        let restored = ReaderStore(persistenceURL: url)
        XCTAssertNil(restored.focusedTokenIndex)
        XCTAssertEqual(restored.settings.wordFocusStyle, .highContrast)
        store.moveFocus(Int.max)
        XCTAssertEqual(store.index, store.units.count - 1)
        store.moveFocus(Int.min)
        XCTAssertEqual(store.index, 0); XCTAssertEqual(store.focusedTokenIndex, 0)
    }
    func testFineCrossSentenceUsesExistingSentenceBoundedHistory() {
        let store = ReaderStore(persistenceURL: nil)
        store.settings.presentation = .sentence
        store.updateText("첫 문장을 천천히 읽는다. 둘째 문장도 천천히 읽는다.")
        store.moveFocus(store.units.filter { $0.sentenceIndex == 0 }.flatMap(\.tokens).count)
        store.moveFocus(1)
        XCTAssertEqual(store.current?.sentenceIndex, 1)
        XCTAssertEqual(store.focusedTokenIndex, 0)
        XCTAssertTrue(store.visiblePast.isEmpty)
        store.moveFocus(-1)
        XCTAssertEqual(store.current?.sentenceIndex, 0)
        XCTAssertEqual(store.focusedTokenIndex, store.current!.tokens.count - 1)
    }
    func testSampleModeNeverWritesPersistence() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ReaderStore(persistenceURL: url, sample: true)
        store.move(1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}
