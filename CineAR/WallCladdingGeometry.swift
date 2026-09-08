import Foundation

/// Metre coordinates relative to the wall-centred AR anchor, independent of the
/// current room.json. Optional in PlacementRecord for older saved scenes.
struct WallCladdingLayout: Codable {
    struct Cutout: Codable {
        var minX: Float
        var maxX: Float
        var minY: Float
        var maxY: Float
    }

    let wallID: UUID
    let width: Float
    let height: Float
    let outline: [SIMD2<Float>]
    let cutouts: [Cutout]

    var isValid: Bool {
        (0.1...20).contains(width) && (0.1...10).contains(height)
            && (3...256).contains(outline.count) && cutouts.count <= 72
            && outline.allSatisfy {
                $0.x.isFinite && $0.y.isFinite
                    && abs($0.x) <= width * 0.5 + 0.02
                    && abs($0.y) <= height * 0.5 + 0.02
            }
            && cutouts.allSatisfy {
                [$0.minX, $0.maxX, $0.minY, $0.maxY].allSatisfy(\.isFinite)
                    && $0.maxX > $0.minX && $0.maxY > $0.minY
                    && max(abs($0.minX), abs($0.maxX)) <= width * 0.5 + 0.02
                    && max(abs($0.minY), abs($0.maxY)) <= height * 0.5 + 0.02
            }
    }
}

enum WallCladdingGeometryError: Error {
    case invalidLayout
    case invalidPolygon
    case geometryBudgetExceeded
    case emptySurface
}

/// Pure geometry, also exercised by Tools/test_wall_cladding_geometry.swift.
/// Triangulate the wall, then subtract each aperture from the convex pieces.
/// No bounding box spanning a door/window is ever used as a visible fallback.
enum WallCladdingGeometry {
    static let maximumPieces = 512
    static let epsilon: Float = 0.000_001

    static func cross(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        a.x * b.y - a.y * b.x
    }

    static func signedArea(_ polygon: [SIMD2<Float>]) -> Float {
        guard polygon.count >= 3 else { return 0 }
        return polygon.indices.reduce(Float(0)) {
            $0 + cross(polygon[$1], polygon[($1 + 1) % polygon.count]) * 0.5
        }
    }

    static func contains(_ point: SIMD2<Float>, polygon: [SIMD2<Float>]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        for index in polygon.indices {
            let a = polygon[index]
            let b = polygon[(index + 1) % polygon.count]
            let edge = b - a
            let toPoint = point - a
            if abs(cross(edge, toPoint)) < epsilon,
               point.x >= min(a.x, b.x) - epsilon, point.x <= max(a.x, b.x) + epsilon,
               point.y >= min(a.y, b.y) - epsilon, point.y <= max(a.y, b.y) + epsilon {
                return true
            }
            if (a.y > point.y) != (b.y > point.y),
               point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x {
                inside.toggle()
            }
        }
        return inside
    }

    static func textureCoordinate(_ point: SIMD2<Float>, tileMeters: Float) -> SIMD2<Float> {
        // Same origin for every cut piece: no stretching or seams at aperture edges.
        point / tileMeters
    }

    static func pieces(for layout: WallCladdingLayout) throws -> [[SIMD2<Float>]] {
        guard layout.isValid else { throw WallCladdingGeometryError.invalidLayout }
        var pieces = try triangulate(layout.outline)
        for cutout in layout.cutouts {
            var remaining: [[SIMD2<Float>]] = []
            for piece in pieces {
                var inside = piece
                // At each boundary retain the outside, then process only the inside.
                // Thus overlapping cutouts never double-count visible area.
                for (axis, value, keepGreater) in [
                    (0, cutout.minX, true), (0, cutout.maxX, false),
                    (1, cutout.minY, true), (1, cutout.maxY, false)
                ] {
                    let outside = clip(inside, axis: axis, value: value, keepGreater: !keepGreater)
                    if abs(signedArea(outside)) > epsilon { remaining.append(outside) }
                    inside = clip(inside, axis: axis, value: value, keepGreater: keepGreater)
                    if inside.count < 3 { break }
                }
                guard remaining.count <= maximumPieces else {
                    throw WallCladdingGeometryError.geometryBudgetExceeded
                }
            }
            pieces = remaining
        }
        guard !pieces.isEmpty else { throw WallCladdingGeometryError.emptySurface }
        return pieces
    }

    private static func clip(
        _ polygon: [SIMD2<Float>], axis: Int, value: Float, keepGreater: Bool
    ) -> [SIMD2<Float>] {
        guard let last = polygon.last else { return [] }
        var output: [SIMD2<Float>] = []
        var previous = last
        var previousInside = keepGreater ? previous[axis] >= value : previous[axis] <= value
        for current in polygon {
            let currentInside = keepGreater ? current[axis] >= value : current[axis] <= value
            if currentInside != previousInside {
                let t = (value - previous[axis]) / (current[axis] - previous[axis])
                output.append(previous + (current - previous) * t)
            }
            if currentInside { output.append(current) }
            previous = current
            previousInside = currentInside
        }
        return cleaned(output)
    }

    private static func cleaned(_ polygon: [SIMD2<Float>]) -> [SIMD2<Float>] {
        var result: [SIMD2<Float>] = []
        for point in polygon {
            if let last = result.last, abs(point.x - last.x) + abs(point.y - last.y) < epsilon { continue }
            result.append(point)
        }
        if let first = result.first, let last = result.last, result.count > 1,
           abs(first.x - last.x) + abs(first.y - last.y) < epsilon { result.removeLast() }
        // RoomPlan often includes collinear corners; removing them avoids stalled ears.
        var changed = true
        while changed && result.count > 3 {
            changed = false
            for i in result.indices {
                let a = result[(i + result.count - 1) % result.count]
                let b = result[i]
                let c = result[(i + 1) % result.count]
                if abs(cross(b - a, c - b)) < epsilon {
                    result.remove(at: i)
                    changed = true
                    break
                }
            }
        }
        return result
    }

    private static func triangulate(_ outline: [SIMD2<Float>]) throws -> [[SIMD2<Float>]] {
        var polygon = cleaned(outline)
        guard abs(signedArea(polygon)) > epsilon else { throw WallCladdingGeometryError.invalidPolygon }
        // Reject self-crossing outlines instead of producing overlapping fill.
        for i in polygon.indices {
            let a = polygon[i]
            let b = polygon[(i + 1) % polygon.count]
            for j in polygon.indices where j > i {
                if j == (i + 1) % polygon.count || (j + 1) % polygon.count == i { continue }
                let c = polygon[j]
                let d = polygon[(j + 1) % polygon.count]
                let denominator = cross(b - a, d - c)
                if abs(denominator) <= epsilon { continue }
                let t = cross(c - a, d - c) / denominator
                let u = cross(c - a, b - a) / denominator
                if t >= 0 && t <= 1 && u >= 0 && u <= 1 {
                    throw WallCladdingGeometryError.invalidPolygon
                }
            }
        }
        if signedArea(polygon) < 0 { polygon.reverse() }
        var result: [[SIMD2<Float>]] = []
        while polygon.count > 3 {
            var found = false
            for i in polygon.indices {
                let previous = (i + polygon.count - 1) % polygon.count
                let next = (i + 1) % polygon.count
                let triangle = [polygon[previous], polygon[i], polygon[next]]
                guard cross(triangle[1] - triangle[0], triangle[2] - triangle[1]) > epsilon else { continue }
                let containsCorner = polygon.indices.contains {
                    $0 != previous && $0 != i && $0 != next && contains(polygon[$0], polygon: triangle)
                }
                if containsCorner { continue }
                result.append(triangle)
                polygon.remove(at: i)
                found = true
                break
            }
            guard found else { throw WallCladdingGeometryError.invalidPolygon }
        }
        if abs(signedArea(polygon)) > epsilon { result.append(polygon) }
        return result
    }
}

#if canImport(RealityKit) && !WALL_GEOMETRY_TESTS
import RealityKit
import simd

@MainActor
enum WallCladdingMeshFactory {
    static func make(
        layout: WallCladdingLayout, tileMeters: Float, materialSource: Entity
    ) throws -> ModelEntity {
        let pieces = try WallCladdingGeometry.pieces(for: layout)
        guard let material = firstMaterial(in: materialSource), tileMeters > 0 else {
            throw WallCladdingGeometryError.invalidLayout
        }
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uv: [SIMD2<Float>] = []
        var indices: [UInt32] = []
        var shapes: [ShapeResource] = []
        let front: Float = 0.006
        let back: Float = -0.054

        func appendFace(_ points: [SIMD3<Float>], normal: SIMD3<Float>, coordinates: [SIMD2<Float>]) {
            let start = UInt32(positions.count)
            positions.append(contentsOf: points)
            normals.append(contentsOf: Array(repeating: normal, count: points.count))
            uv.append(contentsOf: coordinates)
            for i in 1..<(points.count - 1) {
                indices.append(contentsOf: [start, start + UInt32(i), start + UInt32(i + 1)])
            }
        }

        for piece in pieces {
            // Convex CCW pieces share one material and mesh for the entire wall.
            let face = piece.map { SIMD3<Float>($0.x, $0.y, front) }
            let coordinates = piece.map { WallCladdingGeometry.textureCoordinate($0, tileMeters: tileMeters) }
            appendFace(face, normal: [0, 0, 1], coordinates: coordinates)
            appendFace(piece.reversed().map { [$0.x, $0.y, back] }, normal: [0, 0, -1],
                       coordinates: Array(coordinates.reversed()))
            for i in piece.indices {
                let a = piece[i]
                let b = piece[(i + 1) % piece.count]
                let edge = b - a
                guard simd_length_squared(edge) > 0.000_000_01 else { continue }
                let normal = simd_normalize(SIMD3<Float>(edge.y, -edge.x, 0))
                appendFace([
                    [a.x, a.y, front], [a.x, a.y, back],
                    [b.x, b.y, back], [b.x, b.y, front]
                ], normal: normal, coordinates: [
                    [0, front / tileMeters], [0, back / tileMeters],
                    [simd_length(edge) / tileMeters, back / tileMeters],
                    [simd_length(edge) / tileMeters, front / tileMeters]
                ])
            }
            // Separate collision hulls keep touches through windows/doors open.
            let hitPoints = piece.flatMap { point in
                [SIMD3<Float>(point.x, point.y, front), SIMD3<Float>(point.x, point.y, front + 0.004)]
            }
            shapes.append(ShapeResource.generateConvex(from: hitPoints))
        }
        var descriptor = MeshDescriptor(name: "cinear.fitted-wall")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uv)
        descriptor.primitives = .triangles(indices)
        let mesh = try MeshResource.generate(from: [descriptor])
        let root = ModelEntity(mesh: mesh, materials: [material])
        root.name = "cinear.contact-pivot.fitted-wall"
        root.collision = CollisionComponent(shapes: shapes)
        return root
    }

    private static func firstMaterial(in entity: Entity) -> (any Material)? {
        if let material = entity.components[ModelComponent.self]?.materials.first { return material }
        for child in entity.children {
            if let material = firstMaterial(in: child) { return material }
        }
        return nil
    }
}
#endif
