import XCTest

final class ReaderFlowTests: XCTestCase {
    private var app: XCUIApplication!
    private var current: XCUIElement { element("reader.current") }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(current.waitForExistence(timeout: 8))
    }

    func testDirectionalNavigationAndNoFutureLeak() {
        let initialText = current.label
        XCTAssertEqual(position(), 1)
        XCTAssertFalse(app.staticTexts["This reader keeps the current focus in one stable place."].exists)
        app.buttons["wheel.right"].tap()
        XCTAssertEqual(position(), 2)
        XCTAssertNotEqual(current.label, initialText)
        app.buttons["wheel.left"].tap()
        XCTAssertEqual(position(), 1)
        XCTAssertEqual(current.label, initialText)
        app.buttons["wheel.down"].tap()
        XCTAssertGreaterThan(position(), 1)
        XCTAssertNotEqual(current.label, initialText)
        app.buttons["wheel.up"].tap()
        XCTAssertEqual(position(), 1)
        XCTAssertEqual(current.label, initialText)
    }

    func testRingActivatesWordFocusAndCoarseNavigationClearsIt() {
        openSettings()
        replaceDraft(with: "하나 둘 셋 넷 다섯 여섯 일곱. 다음 문장입니다.")
        app.buttons["settings.applyText"].tap()
        closeSettings()
        let wheel = element("wheel")
        XCTAssertEqual(wheel.value as? String, "어절 포커스 없음")
        let frame = current.frame
        let initialText = current.label
        rotateWheel(clockwise: true)
        XCTAssertNotEqual(wheel.value as? String, "어절 포커스 없음")
        XCTAssertEqual(current.label, initialText)
        assertFrame(current.frame, equals: frame)
        rotateWheel(clockwise: false)
        XCTAssertNotEqual(wheel.value as? String, "어절 포커스 없음")
        assertFrame(current.frame, equals: frame)
        app.buttons["wheel.right"].tap()
        XCTAssertEqual(wheel.value as? String, "어절 포커스 없음")
        app.buttons["wheel.left"].tap()
        XCTAssertEqual(current.label, initialText)
        XCTAssertEqual(wheel.value as? String, "어절 포커스 없음")
        rotateWheel(clockwise: true)
        app.buttons["wheel.down"].tap()
        XCTAssertEqual(wheel.value as? String, "어절 포커스 없음")
        rotateWheel(clockwise: false)
        app.buttons["wheel.up"].tap()
        XCTAssertEqual(wheel.value as? String, "어절 포커스 없음")
    }

    func testAllWordFocusStylesPreserveLineLayout() {
        openSettings()
        replaceDraft(with: "하나 둘 셋 넷 다섯.")
        app.buttons["settings.applyText"].tap()
        closeSettings()
        let frame = current.frame
        let text = current.label
        rotateWheel(clockwise: true)
        for title in ["노란 배경", "글자 색상", "밑줄", "다른 어절 흐리게", "검은 배경"] {
            openSettings()
            choose("settings.wordFocusStyle", title: title)
            XCTAssertFalse(element("settings.alignment").exists)
            XCTAssertFalse(app.sliders["settings.anchorX"].exists)
            closeSettings()
            rotateWheel(clockwise: true)
            XCTAssertNotEqual(element("wheel").value as? String, "어절 포커스 없음")
            XCTAssertEqual(current.label, text)
            assertFrame(current.frame, equals: frame)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Word focus style: \(title)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testAllPresentationModesKeepCurrentAndHideFuture() {
        openSettings()
        replaceDraft(with: "처음 조각. 다음 조각. 아직 안 읽은 미래.")
        app.buttons["settings.applyText"].tap()
        closeSettings()
        app.buttons["wheel.right"].tap()
        let focused = current.label
        let value = current.value as? String
        for title in ["현재 조각만", "과거 맥락 누적"] {
            openSettings()
            choose("settings.presentation", title: title)
            closeSettings()
            XCTAssertEqual(current.label, focused)
            XCTAssertEqual(current.value as? String, value)
            XCTAssertFalse(app.staticTexts["아직 안 읽은 미래."].exists)
        }
    }

    func testProgressDoesNotMoveCurrentBaselineAndPanelChangesShape() {
        let originalY = current.frame.midY
        let originalDisplay = element("reader.display").frame
        openSettings()
        let progress = element("settings.progress")
        reveal(progress)
        progress.tap()
        closeSettings()
        XCTAssertEqual(current.frame.midY, originalY, accuracy: 0.5)

        openSettings()
        choose("settings.panel", title: "2.25″ · 284 × 76")
        closeSettings()
        let narrowDisplay = element("reader.display").frame
        XCTAssertLessThan(narrowDisplay.height, originalDisplay.height)
        XCTAssertEqual(narrowDisplay.width, originalDisplay.width, accuracy: 1)
    }

    func testFontReflowAndHomeControlsFitScreen() {
        let initialTotal = total()
        openSettings()
        let fontStepper = app.steppers["settings.fontSize"]
        reveal(fontStepper)
        XCTAssertTrue(fontStepper.exists)
        let namedIncrement = fontStepper.buttons.matching(NSPredicate(
            format: "label == 'Increment' OR label == 'Increase' OR label == '증가'"
        )).firstMatch
        let increment = namedIncrement.exists ? namedIncrement : fontStepper.buttons.element(boundBy: 1)
        for _ in 0..<8 { increment.tap() }
        closeSettings()
        XCTAssertGreaterThan(total(), initialTotal)
        XCTAssertEqual(position(), 1)
        let screen = app.frame
        for identifier in ["wheel.left", "wheel.right", "wheel.up", "wheel.down", "home.settings"] {
            let control = app.buttons[identifier]
            XCTAssertTrue(control.isHittable, identifier)
            XCTAssertTrue(screen.contains(control.frame), identifier)
        }
    }

    func testEditedTextRequiresApplyAndCanBeDiscarded() {
        let original = current.label
        openSettings()
        replaceDraft(with: "첫 문장입니다. 다음 문장은 미래입니다.")
        app.buttons["settings.close"].tap()
        XCTAssertTrue(app.buttons["글 적용하고 닫기"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["변경한 글 버리고 닫기"].exists)
        let keepEditing = app.buttons["계속 편집"]
        XCTAssertTrue(keepEditing.waitForExistence(timeout: 3))
        keepEditing.tap()
        app.buttons["settings.applyText"].tap()
        XCTAssertTrue(app.staticTexts["글을 적용했어"].waitForExistence(timeout: 3))
        closeSettings()
        XCTAssertNotEqual(current.label, original)
        XCTAssertEqual(current.label, "첫 문장입니다.")
        XCTAssertEqual(position(), 1)
        XCTAssertFalse(app.staticTexts["다음 문장은 미래입니다."].exists)
        app.buttons["wheel.down"].tap()
        XCTAssertEqual(current.label, "다음 문장은 미래입니다.")

        openSettings()
        replaceDraft(with: "버릴 글입니다.")
        app.buttons["settings.close"].tap()
        app.buttons["변경한 글 버리고 닫기"].tap()
        XCTAssertTrue(current.waitForExistence(timeout: 3))
        XCTAssertEqual(current.label, "다음 문장은 미래입니다.")
    }

    func testImportsTXTThroughSystemFilesPicker() {
        openSettings()
        app.buttons["settings.import"].tap()

        // Navigate the real document picker; the debug fixture lives in the app's Documents folder.
        let fileLabels = ["Reader-Import-Test.txt", "Reader-Import-Test"]
        if !filesItemExists(fileLabels, timeout: 2) {
            _ = tapFilesItem(["Browse", "둘러보기", "탐색"], timeout: 3)
            if !filesItemExists(["On My iPhone", "나의 iPhone"], timeout: 2) {
                _ = tapFilesItem(["Browse", "둘러보기", "탐색"], timeout: 2)
            }
            XCTAssertTrue(tapFilesItem(["On My iPhone", "나의 iPhone"], timeout: 5),
                          "The app Documents folder must be exposed in On My iPhone")
            XCTAssertTrue(tapFilesItem(["Pocket Reader", "PocketReader"], timeout: 5))
        }
        let fileCell = fileLabels.map {
            app.cells.containing(.staticText, identifier: $0).firstMatch
        }.first(where: { $0.exists && $0.isHittable })
        if let fileCell { fileCell.tap() }
        else {
            XCTAssertTrue(tapFilesItem(fileLabels, timeout: 5), "The seeded TXT fixture must be selectable")
        }
        let pickerScreenshot = XCTAttachment(screenshot: app.screenshot())
        pickerScreenshot.name = "TXT picker immediately after file selection"
        pickerScreenshot.lifetime = .keepAlways
        add(pickerScreenshot)
        let pickerHierarchy = XCTAttachment(string: app.debugDescription)
        pickerHierarchy.name = "TXT picker selection hierarchy"
        pickerHierarchy.lifetime = .keepAlways
        add(pickerHierarchy)
        let editor = app.textViews["settings.text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        let imported = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "파일에서 온 첫 문장. 파일에서 온 다음 문장."),
            object: editor
        )
        let importResult = XCTWaiter.wait(for: [imported], timeout: 5)
        if importResult != .completed {
            let failureScreenshot = XCTAttachment(screenshot: app.screenshot())
            failureScreenshot.name = "TXT import not reflected after callback wait"
            failureScreenshot.lifetime = .keepAlways
            add(failureScreenshot)
            let failureHierarchy = XCTAttachment(string: app.debugDescription)
            failureHierarchy.name = "TXT import failure hierarchy"
            failureHierarchy.lifetime = .keepAlways
            add(failureHierarchy)
            let relevantLines = app.debugDescription.split(separator: "\n").filter {
                $0.contains("Reader-Import") || $0.contains("settings.text") ||
                $0.contains("Alert") || $0.contains("파일") || $0.contains("Browse") ||
                $0.contains("On My") || $0.contains("NavigationBar")
            }
            print("TXT import state: \(relevantLines.joined(separator: "\n").prefix(4_000))")
        }
        XCTAssertEqual(importResult, .completed)
        XCTAssertEqual(editor.value as? String, "파일에서 온 첫 문장. 파일에서 온 다음 문장.")
        app.buttons["settings.applyText"].tap()
        closeSettings()
        XCTAssertEqual(current.label, "파일에서 온 첫 문장.")
        XCTAssertEqual(position(), 1)
        XCTAssertFalse(app.staticTexts["파일에서 온 다음 문장."].exists)
        app.buttons["wheel.down"].tap()
        XCTAssertEqual(current.label, "파일에서 온 다음 문장.")
    }

    func testImportsMarkdownThroughSystemFilesPicker() {
        openSettings()
        let button = app.buttons["settings.importMD"]
        reveal(button); button.tap()
        // Navigate the real document picker; the debug fixture lives in the app's Documents folder.
        let fileLabels = ["Reader-Markdown-Test.md", "Reader-Markdown-Test"]
        if !filesItemExists(fileLabels, timeout: 2) {
            _ = tapFilesItem(["Browse", "둘러보기", "탐색"], timeout: 3)
            if !filesItemExists(["On My iPhone", "나의 iPhone"], timeout: 2) {
                _ = tapFilesItem(["Browse", "둘러보기", "탐색"], timeout: 2)
            }
            XCTAssertTrue(tapFilesItem(["On My iPhone", "나의 iPhone"], timeout: 5),
                          "The app Documents folder must be exposed in On My iPhone")
            XCTAssertTrue(tapFilesItem(["Pocket Reader", "PocketReader"], timeout: 5))
        }
        let fileCell = fileLabels.map {
            app.cells.containing(.staticText, identifier: $0).firstMatch
        }.first(where: { $0.exists && $0.isHittable })
        if let fileCell { fileCell.tap() }
        else {
            XCTAssertTrue(tapFilesItem(fileLabels, timeout: 5), "The seeded TXT fixture must be selectable")
        }
        let editor = app.textViews["settings.text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        let imported = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "## **마크다운 제목**"), object: editor)
        XCTAssertEqual(XCTWaiter.wait(for: [imported], timeout: 5), .completed)
        app.buttons["settings.applyText"].tap(); closeSettings()
        XCTAssertEqual(current.label, "마크다운 제목")
        app.buttons["wheel.down"].tap()
        XCTAssertEqual(current.label, "첫 항목")
        app.buttons["wheel.down"].tap()
        XCTAssertEqual(current.label, "둘째 항목")
    }

    func testCurrentOnlyCentersAndPastUsesBottomPosition() {
        let bottom = current.frame.midY
        openSettings(); choose("settings.presentation", title: "현재 조각만"); closeSettings()
        let display = element("reader.display").frame
        XCTAssertEqual(current.frame.midY, display.midY, accuracy: 1)
        XCTAssertLessThan(current.frame.midY, bottom)
        openSettings(); choose("settings.presentation", title: "과거 맥락 누적"); closeSettings()
        XCTAssertEqual(current.frame.midY, bottom, accuracy: 1)
        app.buttons["wheel.down"].tap()
        XCTAssertEqual(current.frame.midY, bottom, accuracy: 1)
    }
    func testMarkdownPastePreservesMinimalLeftAlignedHome() {
        openSettings()
        choose("settings.sourceFormat", title: "Markdown")
        replaceDraft(with: "## **짧게**\n\n### [조금더길게](https://example.com/a_(b))\n\n- 끝")
        let editor = app.textViews["settings.text"]
        XCTAssertLessThanOrEqual(editor.frame.height, 185)
        app.buttons["settings.applyText"].tap()
        choose("settings.presentation", title: "현재 조각만")
        closeSettings()
        XCTAssertEqual(current.label, "짧게")
        let screen = element("reader.display").frame
        XCTAssertTrue(screen.contains(current.frame))
        let left = current.frame.minX
        app.buttons["wheel.down"].tap()
        XCTAssertEqual(current.label, "조금더길게")
        XCTAssertTrue(screen.contains(current.frame))
        XCTAssertEqual(current.frame.minX, left, accuracy: 1)
        XCTAssertEqual(element("wheel").value as? String, "어절 포커스 없음")
        app.buttons["wheel.up"].tap()
        XCTAssertEqual(current.label, "짧게")
    }

    func testFullMarkdownAndHorizontalDocumentViews() {
        openSettings()
        choose("settings.sourceFormat", title: "Markdown")
        replaceDraft(with: "# 제목\n\n첫 **강조** 문단.\n\n- 목록 항목\n\n> 인용 내용\n\n```swift\nlet value = 1\n```\n\n| 열 | 값 |\n| --- | --- |\n| A | B |\n\n" + String(repeating: "긴 본문 내용입니다. ", count: 20))
        app.buttons["settings.applyText"].tap()
        choose("settings.segmentation", title: "Full · 전체 본문")
        choose("settings.wordFocusStyle", title: "검은 배경")
        choose("settings.scrollMarginLines", title: "1줄")
        closeSettings()
        let document = element("reader.document")
        XCTAssertTrue(document.waitForExistence(timeout: 8))
        XCTAssertTrue(element("reader.display").frame.contains(document.frame))
        XCTAssertFalse(current.label.contains("**"))
        XCTAssertFalse(current.label.contains("```"))
        XCTAssertTrue(app.staticTexts["제목"].waitForExistence(timeout: 5))
        rotateWheel(clockwise: true)
        let initial = XCTAttachment(screenshot: app.screenshot())
        initial.name = "Full Markdown formatted document"
        initial.lifetime = .keepAlways
        add(initial)
        app.buttons["wheel.down"].tap()
        document.swipeUp()
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Full Markdown after vertical scroll"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertTrue(app.buttons["home.settings"].isHittable)
        openSettings()
        choose("settings.presentation", title: "한 줄 가로 스크롤")
        closeSettings()
        let horizontal = element("reader.horizontal")
        XCTAssertTrue(horizontal.waitForExistence(timeout: 8))
        XCTAssertTrue(element("reader.display").frame.contains(horizontal.frame))
        horizontal.swipeLeft()
        XCTAssertTrue(app.buttons["home.settings"].isHittable)
        rotateWheel(clockwise: true)
        XCTAssertNotEqual(element("wheel").value as? String, "어절 포커스 없음")
        let rail = XCTAttachment(screenshot: app.screenshot())
        rail.name = "Horizontal rail stationary centered black focus"
        rail.lifetime = .keepAlways
        add(rail)
    }

    func testAdaptiveFocusGroupingAcrossChunkMarkdownAndRail() {
        openSettings()
        replaceDraft(with: "오늘이 어제보다 더 많이 배고프다.")
        app.buttons["settings.applyText"].tap()
        choose("settings.minimumFocusLength", title: "3자")
        choose("settings.wordFocusStyle", title: "검은 배경")
        closeSettings()
        let wheel = element("wheel"), frame = current.frame
        for _ in 0..<3 { rotateOneDetent(clockwise: true) }
        XCTAssertEqual(wheel.value as? String, "더 많이")
        assertFrame(current.frame, equals: frame)
        rotateOneDetent(clockwise: false)
        XCTAssertEqual(wheel.value as? String, "어제보다")
        rotateOneDetent(clockwise: true)
        XCTAssertEqual(wheel.value as? String, "더 많이")
        for style in ["노란 배경", "글자 색상", "밑줄", "다른 어절 흐리게", "검은 배경"] {
            openSettings(); choose("settings.wordFocusStyle", title: style); closeSettings()
            XCTAssertEqual(wheel.value as? String, "더 많이")
            assertFrame(current.frame, equals: frame)
        }
        let chunk = XCTAttachment(screenshot: app.screenshot())
        chunk.name = "Adaptive group coherent native highlight"
        chunk.lifetime = .keepAlways; add(chunk)
        openSettings(); choose("settings.minimumFocusLength", title: "1자 · 기존 어절"); closeSettings()
        XCTAssertEqual(wheel.value as? String, "더")
        rotateOneDetent(clockwise: true)
        XCTAssertEqual(wheel.value as? String, "많이")
        openSettings()
        choose("settings.sourceFormat", title: "Markdown")
        replaceDraft(with: "# 테스트\n\n오늘이 어제보다 더 **많이** 배고프다.")
        app.buttons["settings.applyText"].tap()
        choose("settings.segmentation", title: "Full · 전체 본문")
        choose("settings.minimumFocusLength", title: "3자")
        closeSettings()
        XCTAssertTrue(element("reader.document").waitForExistence(timeout: 8))
        for _ in 0..<4 { rotateOneDetent(clockwise: true) }
        XCTAssertEqual(wheel.value as? String, "더 많이")
        openSettings(); choose("settings.presentation", title: "한 줄 가로 스크롤"); closeSettings()
        for _ in 0..<4 { rotateOneDetent(clockwise: true) }
        XCTAssertEqual(wheel.value as? String, "더 많이")
        let rail = XCTAttachment(screenshot: app.screenshot())
        rail.name = "Adaptive group centered across Markdown runs"
        rail.lifetime = .keepAlways; add(rail)
    }

    private func rotateOneDetent(clockwise: Bool) {
        let wheel = element("wheel")
        let top = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
        let next = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.63, dy: 0.143))
        if clockwise { top.press(forDuration: 0.3, thenDragTo: next) }
        else { next.press(forDuration: 0.3, thenDragTo: top) }
    }

    func testContextMarginSettingsAndStableForwardBackwardWindow() {
        openSettings()
        replaceDraft(with: (0..<24).map { "줄\($0)." }.joined(separator: " "))
        app.buttons["settings.applyText"].tap()
        choose("settings.scrollMarginLines", title: "1줄")
        closeSettings()
        for _ in 0..<8 { app.buttons["wheel.right"].tap() }
        let display = element("reader.display").frame
        XCTAssertGreaterThan(current.frame.minY, display.minY)
        XCTAssertLessThan(current.frame.maxY, display.maxY)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Context Margin real adjacent lines"
        shot.lifetime = .keepAlways
        add(shot)
        app.buttons["wheel.left"].tap()
        XCTAssertGreaterThan(current.frame.minY, display.minY)
        XCTAssertLessThan(current.frame.maxY, display.maxY)
        openSettings()
        choose("settings.scrollMarginLines", title: "2줄")
        choose("settings.scrollMarginLines", title: "0줄")
        closeSettings()
        XCTAssertTrue(app.buttons["home.settings"].isHittable)
    }

    func testCounterclockwiseMovesUpWithinVisibleViewport() {
        openSettings()
        replaceDraft(with: "첫줄. 둘째줄. 셋째줄. 넷째줄. 다섯째줄. 여섯째줄.")
        app.buttons["settings.applyText"].tap()
        choose("settings.presentation", title: "과거 맥락 누적")
        closeSettings()
        for _ in 0..<4 { app.buttons["wheel.right"].tap() }
        let bottomY = current.frame.minY
        rotateWheel(clockwise: false)
        let previousY = current.frame.minY
        XCTAssertLessThan(previousY, bottomY)
        XCTAssertGreaterThanOrEqual(previousY, element("reader.display").frame.minY)
        rotateWheel(clockwise: false)
        XCTAssertLessThanOrEqual(current.frame.minY, previousY)
        XCTAssertGreaterThanOrEqual(current.frame.minY, element("reader.display").frame.minY)
    }

    private func rotateWheel(clockwise: Bool) {
        let wheel = element("wheel")
        let top = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
        let right = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.5))
        if clockwise { top.press(forDuration: 0.6, thenDragTo: right) }
        else { right.press(forDuration: 0.6, thenDragTo: top) }
    }

    private func assertFrame(_ actual: CGRect, equals expected: CGRect) {
        XCTAssertEqual(actual.minX, expected.minX, accuracy: 0.5)
        XCTAssertEqual(actual.minY, expected.minY, accuracy: 0.5)
        XCTAssertEqual(actual.width, expected.width, accuracy: 0.5)
        XCTAssertEqual(actual.height, expected.height, accuracy: 0.5)
    }

    private func filesItemExists(_ labels: [String], timeout: TimeInterval) -> Bool {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label IN %@", labels))
            .firstMatch.waitForExistence(timeout: timeout)
    }

    @discardableResult
    private func tapFilesItem(_ labels: [String], timeout: TimeInterval) -> Bool {
        let query = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label IN %@", labels))
        guard query.firstMatch.waitForExistence(timeout: timeout) else { return false }
        for _ in 0..<4 {
            if let visible = query.allElementsBoundByIndex.first(where: { $0.isHittable }) {
                visible.tap()
                return true
            }
            app.swipeUp()
        }
        return false
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func position() -> Int {
        Int((current.value as? String ?? "").split(separator: "/").first?
            .trimmingCharacters(in: .whitespaces) ?? "") ?? -1
    }

    private func total() -> Int {
        Int((current.value as? String ?? "").split(separator: "/").last?
            .trimmingCharacters(in: .whitespaces) ?? "") ?? -1
    }

    private func openSettings() {
        app.buttons["home.settings"].tap()
        XCTAssertTrue(app.buttons["settings.close"].waitForExistence(timeout: 3))
    }

    private func closeSettings() {
        app.buttons["settings.close"].tap()
        XCTAssertTrue(current.waitForExistence(timeout: 3))
    }

    private func reveal(_ target: XCUIElement) {
        for _ in 0..<7 {
            if target.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(target.isHittable)
    }

    private func choose(_ id: String, title: String) {
        let picker = element(id)
        reveal(picker)
        picker.tap()
        if id == "settings.presentation" {
            XCTAssertFalse(app.buttons["현재 문장 안의 맥락"].exists)
        }
        let option = app.buttons[title]
        if option.waitForExistence(timeout: 2) { option.tap() }
        else {
            let row = app.staticTexts[title].firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 2))
            row.tap()
        }
    }

    private func replaceDraft(with text: String) {
        let editor = app.textViews["settings.text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        let clear = app.buttons["settings.clearText"]
        reveal(clear)
        clear.tap()
        XCTAssertEqual(editor.value as? String, "")
        editor.tap()
        editor.typeText(text)
    }
}
