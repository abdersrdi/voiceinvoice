import XCTest
import UIKit
@testable import VoiceInvoice

final class StampProcessorTests: XCTestCase {
    /// White 20x20 image with a red 6x6 square in the middle.
    private func syntheticPixels() -> [UInt8] {
        var rgba = [UInt8](repeating: 255, count: 20 * 20 * 4)
        for y in 7..<13 {
            for x in 7..<13 {
                let i = (y * 20 + x) * 4
                rgba[i] = 200
                rgba[i + 1] = 30
                rgba[i + 2] = 40
                rgba[i + 3] = 255
            }
        }
        return rgba
    }

    func testPaperLuminanceIsBright() {
        XCTAssertGreaterThan(StampProcessor.paperLuminance(rgba: syntheticPixels()), 240)
    }

    func testPaperBecomesTransparentAndInkStays() {
        let rgba = syntheticPixels()
        let paper = StampProcessor.paperLuminance(rgba: rgba)
        let out = StampProcessor.makeTransparent(rgba: rgba, paper: paper, sensitivity: 0.6)

        XCTAssertEqual(out[3], 0)                       // corner (paper)
        let center = (10 * 20 + 10) * 4
        XCTAssertGreaterThan(out[center + 3], 200)      // ink
        XCTAssertGreaterThan(out[center], out[center + 1]) // still reddish
    }

    func testInkBounds() throws {
        let rgba = syntheticPixels()
        let paper = StampProcessor.paperLuminance(rgba: rgba)
        let out = StampProcessor.makeTransparent(rgba: rgba, paper: paper, sensitivity: 0.6)
        let bounds = try XCTUnwrap(StampProcessor.inkBounds(rgba: out, width: 20, height: 20))
        XCTAssertEqual(bounds, CGRect(x: 7, y: 7, width: 6, height: 6))
    }

    func testBlankPaperHasNoInk() {
        let rgba = [UInt8](repeating: 255, count: 10 * 10 * 4)
        let out = StampProcessor.makeTransparent(rgba: rgba, paper: 255, sensitivity: 0.9)
        XCTAssertNil(StampProcessor.inkBounds(rgba: out, width: 10, height: 10))
    }

    func testSmoothstepEdges() {
        XCTAssertEqual(StampProcessor.smoothstep(0.2, 0.4, 0.1), 0, accuracy: 0.0001)
        XCTAssertEqual(StampProcessor.smoothstep(0.2, 0.4, 0.5), 1, accuracy: 0.0001)
        XCTAssertEqual(StampProcessor.smoothstep(0.2, 0.4, 0.3), 0.5, accuracy: 0.0001)
    }

    func testRenderFromUIImageCropsToStamp() throws {
        let size = CGSize(width: 200, height: 200)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.1, green: 0.2, blue: 0.7, alpha: 1).setFill()
            context.fill(CGRect(x: 70, y: 80, width: 60, height: 40))
        }
        let processor = try XCTUnwrap(StampProcessor(image: image))
        let result = try XCTUnwrap(processor.render(sensitivity: 0.6))
        XCTAssertLessThan(result.size.width, 120)
        XCTAssertLessThan(result.size.height, 100)
        XCTAssertGreaterThan(result.size.width, 50)
    }
}
