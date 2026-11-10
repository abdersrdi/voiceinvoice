import XCTest

/// Walks through the app with demo data and saves a screenshot of every main screen.
/// Run by the "Screenshots" GitHub workflow on several simulators.
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private var folder: URL?
    private var counter = 0

    override func setUpWithError() throws {
        continueAfterFailure = true

        let host = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] ?? NSHomeDirectory()
        let device = UIDevice.current.name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        let url = URL(fileURLWithPath: host).appendingPathComponent("ui-screenshots/\(device)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        folder = url

        app = XCUIApplication()
        app.launchArguments = ["-UITestSeed", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    // MARK: Helpers

    private func shot(_ name: String) {
        counter += 1
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let folder {
            let file = folder.appendingPathComponent(String(format: "%02d-%@.png", counter, name))
            try? screenshot.pngRepresentation.write(to: file)
        }
    }

    private func settle(_ seconds: TimeInterval = 1.0) {
        Thread.sleep(forTimeInterval: seconds)
    }

    @discardableResult
    private func tap(_ element: XCUIElement, timeout: TimeInterval = 10, _ what: String) -> Bool {
        guard element.waitForExistence(timeout: timeout) else {
            XCTFail("Could not find \(what)")
            return false
        }
        element.tap()
        return true
    }

    /// Goes back one screen. Tries the navigation bar button, then a button called Back, then an edge swipe.
    private func goBack() {
        let bar = app.navigationBars.buttons.element(boundBy: 0)
        if bar.exists && bar.isHittable {
            bar.tap()
        } else if app.buttons["Back"].exists {
            app.buttons["Back"].tap()
        } else {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        settle()
    }

    private func button(containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    // MARK: Tour

    func testTour() throws {
        // 1. Invoice list
        XCTAssertTrue(app.staticTexts["This month"].waitForExistence(timeout: 20), "invoice list did not appear")
        settle(1.5)
        shot("invoices")

        // 2. Invoice PDF preview
        if tap(app.staticTexts["Boulangerie Martin"].firstMatch, "first invoice row") {
            settle(4)
            shot("invoice-pdf")
            app.swipeUp()
            settle()
            shot("invoice-pdf-bottom")
            goBack()
        }

        // 3. Dictation with typed text (no microphone needed)
        if tap(app.buttons["Dictate an invoice"], "dictate button") {
            let field = app.textFields["Tap the mic, or type here"]
            if field.waitForExistence(timeout: 10) {
                field.tap()
                field.typeText("Two shirts at 20 each and a pair of pants for 40")
                app.staticTexts["What I heard"].tap()
                settle(1.5)
                shot("dictation")
            } else {
                XCTFail("dictation text field not found")
            }
            if tap(app.buttons["Use these items"], "Use these items") {
                settle(2)
                shot("editor")
                if app.buttons["Cancel"].waitForExistence(timeout: 5) { app.buttons["Cancel"].tap() }
                settle()
            }
        }

        // 4. Filter chips
        if app.buttons["Paid"].waitForExistence(timeout: 5) {
            app.buttons["Paid"].tap()
            settle()
            shot("invoices-paid")
            if app.buttons["All"].exists { app.buttons["All"].tap() }
            settle()
        }

        // 5. Paywall from the free-invoices pill
        let pill = button(containing: "free invoices left")
        if pill.waitForExistence(timeout: 5) {
            pill.tap()
            settle(2)
            shot("paywall")
            if app.buttons["Close"].waitForExistence(timeout: 5) { app.buttons["Close"].tap() }
            settle()
        }

        // 6. Counter mode
        if tap(app.buttons["Counter mode"], "counter mode button") {
            settle(2)
            shot("counter-mode")
            if app.buttons["Close"].waitForExistence(timeout: 5) { app.buttons["Close"].tap() }
            settle()
        }

        // 7. Shop settings
        if tap(app.buttons["Shop"].firstMatch, "Shop tab") {
            settle(1.5)
            shot("shop")
            app.swipeUp()
            settle()
            shot("shop-branding")
        }

        // 8. Team and voices
        app.swipeDown()
        if tap(app.buttons["Team & voices"].firstMatch, "Team & voices row") {
            settle(1.5)
            shot("team")
        }
    }
}
