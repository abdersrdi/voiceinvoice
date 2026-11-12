import XCTest

/// Launches the app in Arabic, Hindi and Urdu with the demo shop and saves screenshots of the main screens.
/// Run by the "Localized screenshots" GitHub workflow.
final class LocalizedScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private func folder(_ code: String) -> URL {
        let host = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] ?? NSHomeDirectory()
        let url = URL(fileURLWithPath: host).appendingPathComponent("ui-screenshots/app-\(code)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func tour(code: String, locale: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestSeed", "-AppleLanguages", "(\(code))", "-AppleLocale", locale]
        app.launch()
        let dir = folder(code)
        var counter = 0

        func shot(_ name: String) {
            counter += 1
            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "\(code)-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
            try? screenshot.pngRepresentation.write(to: dir.appendingPathComponent(String(format: "%02d-%@.png", counter, name)))
        }

        // the demo customers are not translated, so this row exists in every language
        let row = app.staticTexts["Boulangerie Martin"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 25), "invoice list did not appear in \(code)")
        Thread.sleep(forTimeInterval: 2)
        shot("invoices")

        if row.exists {
            row.tap()
            Thread.sleep(forTimeInterval: 5)
            shot("invoice-pdf")
            app.swipeUp()
            Thread.sleep(forTimeInterval: 1)
            shot("invoice-pdf-bottom")
        }
        app.terminate()
    }

    func testArabic() { tour(code: "ar", locale: "ar_SA") }
    func testHindi() { tour(code: "hi", locale: "hi_IN") }
    func testUrdu() { tour(code: "ur", locale: "ur_PK") }
}
