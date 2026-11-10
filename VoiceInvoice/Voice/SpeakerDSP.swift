import Foundation

/// Radix-2 FFT (in place). Size must be a power of two.
struct FFT {
    let size: Int
    private let cosTable: [Float]
    private let sinTable: [Float]
    private let bitReversed: [Int]

    init(size: Int) {
        precondition(size > 1 && (size & (size - 1)) == 0, "FFT size must be a power of two")
        self.size = size
        var cosines = [Float](repeating: 0, count: size / 2)
        var sines = [Float](repeating: 0, count: size / 2)
        for k in 0..<(size / 2) {
            let angle = -2 * Float.pi * Float(k) / Float(size)
            cosines[k] = cos(angle)
            sines[k] = sin(angle)
        }
        cosTable = cosines
        sinTable = sines

        var bits = 0
        while (1 << bits) < size { bits += 1 }
        var reversed = [Int](repeating: 0, count: size)
        for i in 0..<size {
            var x = i
            var r = 0
            for _ in 0..<bits {
                r = (r << 1) | (x & 1)
                x >>= 1
            }
            reversed[i] = r
        }
        bitReversed = reversed
    }

    func transform(re: inout [Float], im: inout [Float]) {
        let n = size
        for i in 0..<n {
            let j = bitReversed[i]
            if j > i {
                re.swapAt(i, j)
                im.swapAt(i, j)
            }
        }
        var length = 2
        while length <= n {
            let half = length / 2
            let step = n / length
            var start = 0
            while start < n {
                for k in 0..<half {
                    let wr = cosTable[k * step]
                    let wi = sinTable[k * step]
                    let a = start + k
                    let b = a + half
                    let tr = wr * re[b] - wi * im[b]
                    let ti = wr * im[b] + wi * re[b]
                    re[b] = re[a] - tr
                    im[b] = im[a] - ti
                    re[a] += tr
                    im[a] += ti
                }
                start += length
            }
            length <<= 1
        }
    }
}

/// Mel-frequency cepstral coefficients (c1...c12) per 25 ms frame, hop 10 ms.
struct MFCCExtractor {
    static let numFilters = 26
    static let numCoefficients = 12

    struct Frame {
        var coefficients: [Float]
        var energy: Float          // natural log of frame energy
    }

    let sampleRate: Double
    let frameLength: Int
    let hop: Int
    let fftSize: Int
    private let fft: FFT
    private let window: [Float]
    private let filters: [[Float]]
    private let dct: [[Float]]

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        let frame = max(64, Int(sampleRate * 0.025))
        frameLength = frame
        hop = max(32, Int(sampleRate * 0.010))
        var size = 64
        while size < frame { size <<= 1 }
        fftSize = size
        fft = FFT(size: size)
        window = (0..<frame).map { 0.54 - 0.46 * cos(2 * Float.pi * Float($0) / Float(frame - 1)) }
        filters = Self.melFilterbank(fftSize: size, sampleRate: sampleRate)

        let m = Float(Self.numFilters)
        var table: [[Float]] = []
        for k in 1...Self.numCoefficients {
            var row = [Float](repeating: 0, count: Self.numFilters)
            for j in 0..<Self.numFilters {
                row[j] = (2 / m).squareRoot() * cos(Float.pi * Float(k) * (Float(j) + 0.5) / m)
            }
            table.append(row)
        }
        dct = table
    }

    static func hzToMel(_ hz: Double) -> Double { 2595 * log10(1 + hz / 700) }
    static func melToHz(_ mel: Double) -> Double { 700 * (pow(10, mel / 2595) - 1) }

    static func melFilterbank(fftSize: Int, sampleRate: Double) -> [[Float]] {
        let bins = fftSize / 2 + 1
        let low = 100.0
        let high = min(7600.0, sampleRate / 2 * 0.98)
        let lowMel = hzToMel(low)
        let highMel = hzToMel(high)
        let points = (0..<(numFilters + 2)).map { i -> Int in
            let mel = lowMel + (highMel - lowMel) * Double(i) / Double(numFilters + 1)
            let hz = melToHz(mel)
            return min(bins - 1, Int((Double(fftSize) + 1) * hz / sampleRate))
        }
        var filters: [[Float]] = []
        for m in 1...numFilters {
            var row = [Float](repeating: 0, count: bins)
            let left = points[m - 1]
            let center = points[m]
            let right = points[m + 1]
            if center > left {
                for k in left..<center { row[k] = Float(k - left) / Float(center - left) }
            }
            if right > center {
                for k in center...right { row[k] = Float(right - k) / Float(right - center) }
            } else if center < bins {
                row[center] = 1
            }
            filters.append(row)
        }
        return filters
    }

    func frames(_ samples: [Float]) -> [Frame] {
        guard samples.count >= frameLength else { return [] }
        var x = samples
        var i = x.count - 1
        while i > 0 {
            x[i] -= 0.97 * x[i - 1]
            i -= 1
        }

        let count = (x.count - frameLength) / hop + 1
        var re = [Float](repeating: 0, count: fftSize)
        var im = [Float](repeating: 0, count: fftSize)
        var power = [Float](repeating: 0, count: fftSize / 2 + 1)
        var logMel = [Float](repeating: 0, count: Self.numFilters)
        var result: [Frame] = []
        result.reserveCapacity(count)

        for f in 0..<count {
            let start = f * hop
            var energy: Float = 0
            for k in 0..<fftSize {
                re[k] = 0
                im[k] = 0
            }
            for k in 0..<frameLength {
                let v = x[start + k]
                energy += v * v
                re[k] = v * window[k]
            }
            fft.transform(re: &re, im: &im)
            for k in 0...(fftSize / 2) {
                power[k] = re[k] * re[k] + im[k] * im[k]
            }
            for m in 0..<Self.numFilters {
                var sum: Float = 0
                let row = filters[m]
                for k in 0..<power.count { sum += row[k] * power[k] }
                logMel[m] = log(max(sum, 1e-10))
            }
            var coefficients = [Float](repeating: 0, count: Self.numCoefficients)
            for k in 0..<Self.numCoefficients {
                var sum: Float = 0
                let row = dct[k]
                for m in 0..<Self.numFilters { sum += logMel[m] * row[m] }
                coefficients[k] = sum
            }
            result.append(Frame(coefficients: coefficients, energy: log(energy + 1e-10)))
        }
        return result
    }
}
