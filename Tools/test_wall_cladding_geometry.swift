// Run on a Swift host (no iPhone or RealityKit required):
// swiftc -D WALL_GEOMETRY_TESTS CineAR/WallCladdingGeometry.swift \
//   Tools/test_wall_cladding_geometry.swift -o /tmp/cinear-wall-tests
// /tmp/cinear-wall-tests
import Foundation

@main
struct WallCladdingGeometryTests {
    static let wallID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static var checks = 0

    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
        checks += 1
    }

    static func rectangle(_ width: Float, _ height: Float) -> [SIMD2<Float>] {
        [[-width / 2, -height / 2], [width / 2, -height / 2],
         [width / 2, height / 2], [-width / 2, height / 2]]
    }

    static func layout(
        width: Float = 4, height: Float = 3, outline: [SIMD2<Float>]? = nil,
        cutouts: [WallCladdingLayout.Cutout] = []
    ) -> WallCladdingLayout {
        .init(wallID: wallID, width: width, height: height,
              outline: outline ?? rectangle(width, height), cutouts: cutouts)
    }

    static func verify(_ layout: WallCladdingLayout, area expected: Float) throws {
        let pieces = try WallCladdingGeometry.pieces(for: layout)
        let area = pieces.reduce(Float(0)) { $0 + WallCladdingGeometry.signedArea($1) }
        check(abs(area - expected) < 0.0001, "Incorrect visible area: \(area), expected \(expected)")
        check(pieces.count <= WallCladdingGeometry.maximumPieces, "Unbounded geometry")
        // Sample interiors throughout the wall: prove holes are empty and no valid
        // wall area is lost. Offset samples avoid diagonal and aperture boundaries.
        for x in 0..<67 {
            for y in 0..<53 {
                let point = SIMD2<Float>(
                    -layout.width / 2 + layout.width * (Float(x) + 0.371) / 67,
                    -layout.height / 2 + layout.height * (Float(y) + 0.613) / 53
                )
                let inCutout = layout.cutouts.contains {
                    point.x > $0.minX && point.x < $0.maxX && point.y > $0.minY && point.y < $0.maxY
                }
                let expectedVisible = WallCladdingGeometry.contains(point, polygon: layout.outline) && !inCutout
                let visible = pieces.contains { WallCladdingGeometry.contains(point, polygon: $0) }
                check(visible == expectedVisible, "Opening or outline leak at \(point)")
            }
        }
        for piece in pieces {
            check(WallCladdingGeometry.signedArea(piece) > 0, "Reversed face winding")
        }
    }

    static func main() throws {
        try verify(layout(), area: 12)
        let door = WallCladdingLayout.Cutout(minX: -0.5, maxX: 0.5, minY: -1.5, maxY: 0.5)
        let window = WallCladdingLayout.Cutout(minX: 0.8, maxX: 1.8, minY: 0, maxY: 1)
        try verify(layout(cutouts: [door]), area: 10)
        try verify(layout(cutouts: [door, window]), area: 9)
        try verify(layout(cutouts: [door, door, window]), area: 9)
        let overlap = WallCladdingLayout.Cutout(minX: 0, maxX: 1, minY: -1, maxY: 1)
        try verify(layout(cutouts: [door, overlap]), area: 8.75)
        let fullHeight = WallCladdingLayout.Cutout(minX: -0.5, maxX: 0.5, minY: -1.5, maxY: 1.5)
        try verify(layout(cutouts: [fullHeight]), area: 9)

        // Concave wall, clockwise/mirrored orientation and sloped upper edge.
        let concave: [SIMD2<Float>] = [[-2, -1.5], [2, -1.5], [2, 0], [0, 0], [0, 1.5], [-2, 1.5]]
        try verify(layout(outline: concave), area: 9)
        try verify(layout(outline: Array(concave.reversed())), area: 9)
        let sloped: [SIMD2<Float>] = [[-2, -1.5], [2, -1.5], [2, 0.5], [-2, 1.5]]
        try verify(layout(outline: sloped, cutouts: [door]), area: 8)
        let original = layout(cutouts: [door, window])
        let mirrored = layout(outline: original.outline.map { [-$0.x, $0.y] }, cutouts: original.cutouts.map {
            .init(minX: -$0.maxX, maxX: -$0.minX, minY: $0.minY, maxY: $0.maxY)
        })
        try verify(mirrored, area: 9)
        let restored = try JSONDecoder().decode(WallCladdingLayout.self, from: JSONEncoder().encode(original))
        check(restored.wallID == original.wallID, "Wall identity lost on reload")
        try verify(restored, area: 9)

        // A larger wall adds repeats instead of stretching the same texture.
        for tile in [Float(1.5), Float(2)] {
            let delta = WallCladdingGeometry.textureCoordinate([1, 0], tileMeters: tile)
                - WallCladdingGeometry.textureCoordinate([0, 0], tileMeters: tile)
            check(abs(delta.x - 1 / tile) < 0.00001, "Metre-based UV scale changed")
            let repeatDelta = WallCladdingGeometry.textureCoordinate([tile, tile], tileMeters: tile)
            check(repeatDelta == SIMD2<Float>(1, 1), "Texture does not repeat at tile size")
        }
        try verify(layout(width: 8, height: 3, cutouts: [door]), area: 22)
        check(!layout(width: .nan).isValid, "NaN accepted")
        check(!layout(cutouts: [.init(minX: 1, maxX: -1, minY: 0, maxY: 1)]).isValid, "Inverted opening accepted")
        do {
            _ = try WallCladdingGeometry.pieces(for: layout(cutouts: [
                .init(minX: -2, maxX: 2, minY: -1.5, maxY: 1.5)
            ]))
            preconditionFailure("A fully open wall must not produce a solid fallback")
        } catch WallCladdingGeometryError.emptySurface { checks += 1 }
        do {
            _ = try WallCladdingGeometry.pieces(for: layout(outline: [[-2, -1.5], [2, 1.5], [-2, 1.5], [2, -1.5]]))
            preconditionFailure("Self-crossing wall accepted")
        } catch WallCladdingGeometryError.invalidPolygon { checks += 1 }
        print("WALL_CLADDING_GEOMETRY_OK: \(checks) checks")
    }
}
