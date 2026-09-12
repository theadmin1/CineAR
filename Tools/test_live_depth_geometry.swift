import Foundation

@main
struct LiveDepthGeometryTests {
    static func mesh(
        width: Int = 4, height: Int = 4, step: Int = 1,
        sample: (Int, Int) -> (depth: Float, confidence: UInt8) = { _, _ in (1, 2) }
    ) -> LiveDepthMeshData? {
        LiveDepthGeometry.build(width: width, height: height, step: step,
                                fx: 100, fy: 100, cx: 1, cy: 1, sample: sample)
    }

    static func main() {
        let flat = mesh()!
        precondition(flat.indices.count == 54 && flat.positions.count == 16)
        precondition(flat.validFraction == 1)
        precondition(flat.positions[5].x == 0 && flat.positions[5].y == 0)
        precondition(flat.positions[0].x < 0 && flat.positions[0].y > 0)
        precondition(abs(flat.positions[0].z + 1.0014) < 0.00001)
        precondition(abs(LiveDepthGeometry.depthBias(1) - 0.0014) < 0.00001)
        precondition(abs(LiveDepthGeometry.depthBias(3) - 0.0026) < 0.00001)
        precondition(abs(LiveDepthGeometry.depthBias(6) - 0.003) < 0.00001)
        for i in stride(from: 0, to: flat.indices.count, by: 3) {
            let a = flat.positions[Int(flat.indices[i])]
            let b = flat.positions[Int(flat.indices[i + 1])]
            let c = flat.positions[Int(flat.indices[i + 2])]
            let ab = b - a, ac = c - a
            precondition(ab.x * ac.y - ab.y * ac.x > 0, "Winding must face camera")
        }

        let edge = mesh { x, _ in (x < 2 ? 1 : 2, 2) }!
        precondition(edge.indices.count == 36)
        for i in stride(from: 0, to: edge.indices.count, by: 3) {
            let depths = edge.indices[i..<(i + 3)].map { edge.positions[Int($0)].z }
            precondition(depths.max()! - depths.min()! < 0.001, "Must not bridge kettle and wall")
        }
        // Every missing corner must still leave the other three as one triangle.
        for missing in 0..<4 {
            let partial = mesh(width: 2, height: 2) { x, y in
                (1, x + y * 2 == missing ? 0 : 2)
            }!
            precondition(partial.indices.count == 3 && partial.validFraction == 0.75)
            precondition(!partial.indices.contains(UInt32(missing)))
        }
        precondition(mesh(sample: { _, _ in (1, 0) }) == nil)
        precondition(mesh(sample: { _, _ in (1, 3) }) == nil)
        precondition(mesh(sample: { _, _ in (1, 1) }) != nil)
        let invalidDepths: [Float] = [.nan, .infinity, -1, 0.1, 7]
        for invalid in invalidDepths {
            precondition(mesh(sample: { _, _ in (invalid, 2) }) == nil)
        }
        let cloth = mesh(width: 20, height: 20) { x, y in
            (1 + 0.015 * sin(Float(x) * 0.4) * cos(Float(y) * 0.4), 2)
        }!
        precondition(cloth.indices.count == 19 * 19 * 6, "Curved surfaces need no object classification")
        precondition(mesh(width: 256, height: 192)!.positions.count == 49_152)
        precondition(mesh(width: 512, height: 384) == nil)
        let reduced = mesh(width: 256, height: 192, step: 2)!
        precondition(reduced.positions.count == 129 * 97)
        precondition(mesh(width: 1) == nil && mesh(step: 0) == nil && mesh(step: 17) == nil)
        precondition(mesh(width: 1025) == nil && mesh(height: 0) == nil)
        let invalidFocalLengths: [Float] = [0, -1, .nan, .infinity]
        for invalidFocalLength in invalidFocalLengths {
            precondition(LiveDepthGeometry.build(
                width: 4, height: 4, step: 1, fx: invalidFocalLength, fy: 100, cx: 1, cy: 1,
                sample: { _, _ in preconditionFailure("Invalid intrinsics must not sample buffers") }
            ) == nil)
        }
        precondition(LiveDepthGeometry.isFresh(capturedAt: 1, now: 1.05))
        precondition(!LiveDepthGeometry.isFresh(capturedAt: 1, now: 1.101))
        precondition(!LiveDepthGeometry.isFresh(capturedAt: 2, now: 1))
        precondition(!LiveDepthGeometry.isFresh(capturedAt: .nan, now: 1))
        print("Live depth geometry tests passed")
    }
}
