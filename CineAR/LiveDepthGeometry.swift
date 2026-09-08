import Foundation

struct LiveDepthMeshData: Sendable {
    let positions: [SIMD3<Float>]
    let indices: [UInt32]
    let validFraction: Float
}

/// Camera-space geometry in metres: +X right, +Y up, camera looks down -Z.
/// This kernel uses no RoomPlan classes or object categories.
enum LiveDepthGeometry {
    static let maximumSampleCount = 256 * 192
    static let maximumAge: TimeInterval = 0.10

    static func isFresh(capturedAt: TimeInterval, now: TimeInterval) -> Bool {
        let age = now - capturedAt
        return age.isFinite && age >= 0 && age <= maximumAge
    }

    static func depthBias(_ depth: Float) -> Float {
        // Avoid cutting a clock attached to the very surface that supplied depth.
        min(0.008 + depth * 0.004, 0.025)
    }

    static func build(
        width: Int, height: Int, step: Int,
        fx: Float, fy: Float, cx: Float, cy: Float,
        sample: (Int, Int) -> (depth: Float, confidence: UInt8)
    ) -> LiveDepthMeshData? {
        guard (2...1024).contains(width), (2...1024).contains(height),
              (1...16).contains(step),
              [fx, fy, cx, cy].allSatisfy(\.isFinite), fx > 0, fy > 0 else { return nil }
        var xs = Array(stride(from: 0, to: width, by: step))
        var ys = Array(stride(from: 0, to: height, by: step))
        if xs.last != width - 1 { xs.append(width - 1) }
        if ys.last != height - 1 { ys.append(height - 1) }
        let count = xs.count * ys.count
        guard count <= maximumSampleCount else { return nil }
        var positions = [SIMD3<Float>](repeating: .zero, count: count)
        var depths = [Float](repeating: 0, count: count)
        var validCount = 0
        for (row, y) in ys.enumerated() {
            for (column, x) in xs.enumerated() {
                let value = sample(x, y)
                // 0 = low, 1 = medium, 2 = high. Never invent unknown depth.
                guard value.confidence == 1 || value.confidence == 2,
                      value.depth.isFinite, (0.15...6).contains(value.depth) else { continue }
                let i = row * xs.count + column
                depths[i] = value.depth
                let z = value.depth + depthBias(value.depth)
                positions[i] = [(Float(x) - cx) * z / fx, -(Float(y) - cy) * z / fy, -z]
                validCount += 1
            }
        }
        var indices: [UInt32] = []
        indices.reserveCapacity((xs.count - 1) * (ys.count - 1) * 6)
        func accepts(_ a: Int, _ b: Int, _ c: Int) -> Bool {
            let minimum = min(depths[a], depths[b], depths[c])
            let maximum = max(depths[a], depths[b], depths[c])
            // Do not bridge kettle -> wall or clothing -> table across a depth edge.
            return minimum > 0 && maximum - minimum <= max(0.025, minimum * 0.025)
        }
        func append(_ a: Int, _ b: Int, _ c: Int, if accepted: Bool) {
            if accepted { indices.append(contentsOf: [UInt32(a), UInt32(b), UInt32(c)]) }
        }
        for row in 0..<(ys.count - 1) {
            for column in 0..<(xs.count - 1) {
                let a = row * xs.count + column
                let b = a + 1
                let c = a + xs.count
                let d = c + 1
                let firstA = accepts(a, c, b)
                let firstB = accepts(b, c, d)
                let secondA = accepts(a, d, b)
                let secondB = accepts(a, c, d)
                let firstScore = (firstA ? 1 : 0) + (firstB ? 1 : 0)
                let secondScore = (secondA ? 1 : 0) + (secondB ? 1 : 0)
                if secondScore > firstScore {
                    append(a, d, b, if: secondA)
                    append(a, c, d, if: secondB)
                } else {
                    append(a, c, b, if: firstA)
                    append(b, c, d, if: firstB)
                }
            }
        }
        guard !indices.isEmpty else { return nil }
        return .init(positions: positions, indices: indices, validFraction: Float(validCount) / Float(count))
    }
}
