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

    func testRingDragMovesInBothDirectionsWithoutMovingCurrentBaseline() {
        let wheel = element("wheel")
        XCTAssertTrue(wheel.exists)
        let baseline = current.frame.midY
        let initial = position()
        let top = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
        let right = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.5))
        top.press(forDuration: 0.6, thenDragTo: right)
        let advanced = position()
        XCTAssertGreaterThan(advanced, initial)
        XCTAssertLessThanOrEqual(advanced, total())
        XCTAssertEqual(current.frame.midY, baseline, accuracy: 0.5)
        right.press(forDuration: 0.6, thenDragTo: top)
        XCTAssertLessThan(position(), advanced)
        XCTAssertGreaterThanOrEqual(position(), 1)
        XCTAssertEqual(current.frame.midY, baseline, accuracy: 0.5)
    }

    func testAllPresentationModesKeepCurrentAndHideFuture() {
        openSettings()
        replaceDraft(with: "처음 조각. 다음 조각. 아직 안 읽은 미래.")
        app.buttons["settings.applyText"].tap()
        closeSettings()
        app.buttons["wheel.right"].tap()
        let focused = current.label
        let value = current.value as? String
        for title in ["현재 조각만", "현재 문장 안의 맥락", "과거 맥락 누적"] {
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
