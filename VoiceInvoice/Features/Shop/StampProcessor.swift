import UIKit

/// Turns a photo of an ink stamp on paper into a transparent PNG:
/// paper becomes see-through, ink keeps its colour. A sensitivity value (0...1) lets the user
/// clean up faint or noisy scans.
final class StampProcessor {
    let width: Int
    let height: Int
    private let rgba: [UInt8]
    private let paper: Double

    init?(image: UIImage, maxDimension: CGFloat = 1000) {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxDimension / longest)
        let target = CGSize(width: max(1, (size.width * scale).rounded()),
                            height: max(1, (size.height * scale).rounded()))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let flattened = UIGraphicsImageRenderer(size: target, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let cgImage = flattened.cgImage else { return nil }

        let w = cgImage.width
        let h = cgImage.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let drawn: Bool = data.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: w,
                height: h,
                bitsPerComponent: 8,
                bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }

        width = w
        height = h
        rgba = data
        paper = Self.paperLuminance(rgba: data)
    }

    // MARK: Pure steps (unit-tested)

    /// The brightness of the paper: the 90th percentile of pixel luminance.
    static func paperLuminance(rgba: [UInt8]) -> Double {
        var histogram = [Int](repeating: 0, count: 256)
        var total = 0
        var i = 0
        while i + 3 < rgba.count {
            let lum = 0.299 * Double(rgba[i]) + 0.587 * Double(rgba[i + 1]) + 0.114 * Double(rgba[i + 2])
            histogram[min(255, Int(lum))] += 1
            total += 1
            i += 4
        }
        guard total > 0 else { return 255 }
        let target = Int(Double(total) * 0.90)
        var running = 0
        for (value, count) in histogram.enumerated() {
            running += count
            if running >= target { return Double(max(value, 1)) }
        }
        return 255
    }

    static func smoothstep(_ low: Double, _ high: Double, _ x: Double) -> Double {
        guard high > low else { return x >= high ? 1 : 0 }
        let t = min(1, max(0, (x - low) / (high - low)))
        return t * t * (3 - 2 * t)
    }

    /// Returns premultiplied RGBA where paper is transparent and ink is opaque.
    static func makeTransparent(rgba: [UInt8], paper: Double, sensitivity: Double) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: rgba.count)
        let clamped = min(1, max(0, sensitivity))
        let low = 0.06 + (1 - clamped) * 0.30
        let high = low + 0.22
        var i = 0
        while i + 3 < rgba.count {
            let r = Double(rgba[i])
            let g = Double(rgba[i + 1])
            let b = Double(rgba[i + 2])
            let lum = 0.299 * r + 0.587 * g + 0.114 * b
            let ink = max(0, (paper - lum) / max(paper, 1))
            let alpha = smoothstep(low, high, ink)
            out[i] = UInt8(min(255, r * alpha))
            out[i + 1] = UInt8(min(255, g * alpha))
            out[i + 2] = UInt8(min(255, b * alpha))
            out[i + 3] = UInt8(min(255, alpha * 255))
            i += 4
        }
        return out
    }

    /// Bounding box of pixels that are visible enough to matter, or nil if the image is empty.
    static func inkBounds(rgba: [UInt8], width: Int, height: Int, minimumAlpha: UInt8 = 16) -> CGRect? {
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where rgba[(y * width + x) * 4 + 3] >= minimumAlpha {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    // MARK: Rendering

    func render(sensitivity: Double) -> UIImage? {
        var out = Self.makeTransparent(rgba: rgba, paper: paper, sensitivity: sensitivity)
        guard let bounds = Self.inkBounds(rgba: out, width: width, height: height) else { return nil }

        let w = width
        let h = height
        let cgImage: CGImage? = out.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: w,
                height: h,
                bitsPerComponent: 8,
                bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            return context.makeImage()
        }
        guard let full = cgImage else { return nil }

        let padding: CGFloat = 8
        let padded = bounds
            .insetBy(dx: -padding, dy: -padding)
            .intersection(CGRect(x: 0, y: 0, width: w, height: h))
        guard let cropped = full.cropping(to: padded) else { return nil }
        return UIImage(cgImage: cropped)
    }
}
