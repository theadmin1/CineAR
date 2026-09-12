import Foundation
import simd

struct CustomARVector3: Codable, Equatable, Sendable {
    var x: Float
    var y: Float
    var z: Float

    init(_ value: SIMD3<Float>) {
        x = value.x
        y = value.y
        z = value.z
    }

    var simd: SIMD3<Float> { [x, y, z] }

    var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }

    func applying(_ transform: simd_float4x4, direction: Bool = false) -> CustomARVector3 {
        let transformed = transform * SIMD4<Float>(simd, direction ? 0 : 1)
        return CustomARVector3([transformed.x, transformed.y, transformed.z])
    }
}

enum CustomARWallStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case studioWhite
    case concrete
    case brick
    case wood
    case backrooms
    case backrooms02
    case backrooms03
    case backrooms04
    case backrooms05
    case backrooms06
    case backrooms07
    case backrooms08
    case backrooms09
    case backroomsClassic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .studioWhite: "Stüdyo Beyazı"
        case .concrete: "Beton"
        case .brick: "Dokulu Tuğla"
        case .wood: "Dokulu Ahşap"
        case .backrooms: "Backrooms Yasu 01"
        case .backrooms02: "Backrooms Yasu 02"
        case .backrooms03: "Backrooms Yasu 03"
        case .backrooms04: "Backrooms Yasu 04"
        case .backrooms05: "Backrooms Yasu 05"
        case .backrooms06: "Backrooms Yasu 06"
        case .backrooms07: "Backrooms Yasu 07"
        case .backrooms08: "Backrooms Yasu 08"
        case .backrooms09: "Backrooms Yasu 09"
        case .backroomsClassic: "Backrooms Klasik CC0"
        }
    }

    var isBackrooms: Bool {
        switch self {
        case .studioWhite, .concrete, .brick, .wood: false
        default: true
        }
    }

    var backroomsWallpaperAssetName: String? {
        switch self {
        case .backrooms: "backrooms_yasu_wall_01"
        case .backrooms02: "backrooms_yasu_wall_02"
        case .backrooms03: "backrooms_yasu_wall_03"
        case .backrooms04: "backrooms_yasu_wall_04"
        case .backrooms05: "backrooms_yasu_wall_05"
        case .backrooms06: "backrooms_yasu_wall_06"
        case .backrooms07: "backrooms_yasu_wall_07"
        case .backrooms08: "backrooms_yasu_wall_08"
        case .backrooms09: "backrooms_yasu_wall_09"
        case .backroomsClassic: "wall_cladding_backrooms_001"
        case .studioWhite, .concrete, .brick, .wood: nil
        }
    }

    var wallpaperAssetName: String? {
        switch self {
        case .brick: "wall_cladding_brick"
        case .wood: "wall_cladding_wood"
        default: backroomsWallpaperAssetName
        }
    }

    var backroomsCeilingAssetName: String? {
        switch self {
        case .backrooms, .backrooms05, .backrooms09, .backroomsClassic:
            "backrooms_yasu_ceiling_01"
        case .backrooms02, .backrooms06:
            "backrooms_yasu_ceiling_02"
        case .backrooms03, .backrooms07:
            "backrooms_yasu_ceiling_03"
        case .backrooms04, .backrooms08:
            "backrooms_yasu_ceiling_04"
        case .studioWhite, .concrete, .brick, .wood:
            nil
        }
    }
}

struct CustomARDoorRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    /// Door centre measured as a fraction of the wall length.
    var centerRatio: Float
    var width: Float
    var height: Float
    var isOpen: Bool

    var isValid: Bool {
        centerRatio.isFinite && (0...1).contains(centerRatio)
            && width.isFinite && (0.55...2.40).contains(width)
            && height.isFinite && (1.20...3.20).contains(height)
    }
}

struct CustomARCeilingRecord: Codable, Equatable, Sendable {
    var height: Float
    var thickness: Float
    var style: CustomARWallStyle

    var isValid: Bool {
        height.isFinite && (0.60...6).contains(height)
            && thickness.isFinite && (0.025...0.40).contains(thickness)
    }
}

struct CustomARWallRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var start: CustomARVector3
    var end: CustomARVector3
    var height: Float
    var thickness: Float
    var style: CustomARWallStyle
    var doors: [CustomARDoorRecord]

    var length: Float { simd_distance(start.simd, end.simd) }

    var isValid: Bool {
        start.isFinite && end.isFinite
            && length.isFinite && (0.30...20).contains(length)
            && height.isFinite && (0.60...6).contains(height)
            && thickness.isFinite && (0.025...0.40).contains(thickness)
            && doors.count <= 8
            && Set(doors.map(\.id)).count == doors.count
            && doors.allSatisfy { door in
                door.isValid && door.height <= height - 0.08 && door.width <= length - 0.10
            }
            && CustomARGeometry.doorsDoNotOverlap(doors, wallLength: length)
    }
}

struct CustomARDesignRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var boundary: [CustomARVector3]
    var surfaceNormal: CustomARVector3
    var walls: [CustomARWallRecord]
    var ceiling: CustomARCeilingRecord?

    var normal: SIMD3<Float> {
        let value = surfaceNormal.simd
        return simd_length_squared(value) > 0.000_001 ? simd_normalize(value) : [0, 1, 0]
    }

    var isValid: Bool {
        let doorIDs = walls.flatMap { $0.doors.map(\.id) }
        guard (3...24).contains(boundary.count), boundary.allSatisfy(\.isFinite),
              surfaceNormal.isFinite, simd_length_squared(surfaceNormal.simd) > 0.80,
              simd_length_squared(surfaceNormal.simd) < 1.20,
              (0.20...400).contains(CustomARGeometry.area(of: boundary.map(\.simd), normal: normal)),
              (boundary.count...64).contains(walls.count),
              Set(walls.map(\.id)).count == walls.count,
              Set(doorIDs).count == doorIDs.count,
              walls.allSatisfy(\.isValid),
              ceiling.map({ $0.isValid }) ?? true,
              !CustomARGeometry.hasSelfIntersection(boundary.map(\.simd), normal: normal)
        else { return false }

        let origin = boundary[0].simd
        let allOnSurface = boundary.allSatisfy {
            abs(simd_dot($0.simd - origin, normal)) <= 0.025
        }
        let wallBasesOnSurface = walls.allSatisfy {
            abs(simd_dot($0.start.simd - origin, normal)) <= 0.035
                && abs(simd_dot($0.end.simd - origin, normal)) <= 0.035
        }
        let boundaryPoints = boundary.map(\.simd)
        let wallBasesInsideArea = walls.allSatisfy {
            CustomARGeometry.segmentIsInside(
                start: $0.start.simd,
                end: $0.end.simd,
                boundary: boundaryPoints,
                normal: normal
            )
        }
        let perimeterMatchesBoundary = boundary.indices.allSatisfy { index in
            let wall = walls[index]
            return simd_distance(wall.start.simd, boundary[index].simd) <= 0.015
                && simd_distance(
                    wall.end.simd,
                    boundary[(index + 1) % boundary.count].simd
                ) <= 0.015
        }
        let ceilingCanRender = ceiling == nil
            || !CustomARGeometry.triangulatedIndices(for: boundaryPoints, normal: normal).isEmpty
        return allOnSurface && wallBasesOnSurface && wallBasesInsideArea
            && perimeterMatchesBoundary && ceilingCanRender
    }

    func applying(_ transform: simd_float4x4) -> CustomARDesignRecord {
        var copy = self
        copy.boundary = boundary.map { $0.applying(transform) }
        let transformedNormal = surfaceNormal.applying(transform, direction: true).simd
        copy.surfaceNormal = CustomARVector3(
            simd_length_squared(transformedNormal) > 0.000_001
                ? simd_normalize(transformedNormal)
                : normal
        )
        copy.walls = walls.map { wall in
            var corrected = wall
            corrected.start = wall.start.applying(transform)
            corrected.end = wall.end.applying(transform)
            return corrected
        }
        return copy
    }
}

enum CustomARGeometryError: LocalizedError {
    case tooFewPoints
    case invalidSurface
    case areaTooSmall
    case selfIntersection
    case wallTooShort
    case outsideArea
    case wallNotFound
    case doorDoesNotFit
    case doorOverlap

    var errorDescription: String? {
        switch self {
        case .tooFewPoints: "Alan için en az üç köşe gerekli"
        case .invalidSurface: "Noktalar aynı düz veya eğimli yüzeyde değil"
        case .areaTooSmall: "Çizilen alan çok küçük"
        case .selfIntersection: "Alan kenarları birbiriyle kesişemez"
        case .wallTooShort: "Duvar en az 30 cm uzunluğunda olmalı"
        case .outsideArea: "Duvar başlangıcı ve bitişi çizilen alanın içinde olmalı"
        case .wallNotFound: "Kapı için bir özel AR duvarına dokun"
        case .doorDoesNotFit: "Bu duvar seçilen kapı için yeterince geniş değil"
        case .doorOverlap: "Yeni kapı mevcut bir kapıyla çakışıyor"
        }
    }
}

enum CustomARGeometry {
    /// Flat floor samples can wander by several centimetres when the phone is very
    /// close to the ground. Reuse an already stable room/ARKit floor level only for
    /// nearly horizontal bases; genuinely inclined drawing surfaces stay inclined.
    static func snappedBaseSurface(
        position: SIMD3<Float>,
        normal: SIMD3<Float>,
        stableFloorY: Float?
    ) -> (position: SIMD3<Float>, normal: SIMD3<Float>)? {
        guard let normalized = normalizedUpFacing(normal),
              [position.x, position.y, position.z].allSatisfy(\.isFinite) else {
            return nil
        }
        guard let stableFloorY,
              stableFloorY.isFinite,
              abs(normalized.y) >= 0.985,
              abs(position.y - stableFloorY) <= 0.30 else {
            return (position, normalized)
        }
        return ([position.x, stableFloorY, position.z], [0, 1, 0])
    }

    static func normalizedUpFacing(_ normal: SIMD3<Float>) -> SIMD3<Float>? {
        guard [normal.x, normal.y, normal.z].allSatisfy(\.isFinite),
              simd_length_squared(normal) > 0.000_001 else { return nil }
        var result = simd_normalize(normal)
        if simd_dot(result, [0, 1, 0]) < 0 { result = -result }
        // A design floor may be inclined, but a near-vertical base is not usable.
        return simd_dot(result, [0, 1, 0]) >= 0.20 ? result : nil
    }

    static func project(_ point: SIMD3<Float>, onto origin: SIMD3<Float>, normal: SIMD3<Float>) -> SIMD3<Float> {
        point - normal * simd_dot(point - origin, normal)
    }

    static func basis(for normal: SIMD3<Float>) -> (u: SIMD3<Float>, v: SIMD3<Float>) {
        let reference: SIMD3<Float> = abs(normal.y) < 0.90 ? [0, 1, 0] : [1, 0, 0]
        let u = simd_normalize(simd_cross(reference, normal))
        return (u, simd_normalize(simd_cross(normal, u)))
    }

    static func localPoints(_ points: [SIMD3<Float>], normal: SIMD3<Float>) -> [SIMD2<Float>] {
        guard let origin = points.first else { return [] }
        let axes = basis(for: normal)
        return points.map {
            let delta = $0 - origin
            return [simd_dot(delta, axes.u), simd_dot(delta, axes.v)]
        }
    }

    static func area(of points: [SIMD3<Float>], normal: SIMD3<Float>) -> Float {
        let local = localPoints(points, normal: normal)
        guard local.count >= 3 else { return 0 }
        var doubled: Float = 0
        for index in local.indices {
            let next = local[(index + 1) % local.count]
            doubled += local[index].x * next.y - next.x * local[index].y
        }
        return abs(doubled) * 0.5
    }

    static func hasSelfIntersection(_ points: [SIMD3<Float>], normal: SIMD3<Float>) -> Bool {
        let polygon = localPoints(points, normal: normal)
        guard polygon.count >= 4 else { return false }
        for first in polygon.indices {
            let firstNext = (first + 1) % polygon.count
            for second in polygon.indices {
                let secondNext = (second + 1) % polygon.count
                if first == second || firstNext == second || secondNext == first { continue }
                if first == 0 && secondNext == 0 { continue }
                if segmentsIntersect(
                    polygon[first], polygon[firstNext], polygon[second], polygon[secondNext]
                ) { return true }
            }
        }
        return false
    }

    static func contains(_ point: SIMD3<Float>, in boundary: [SIMD3<Float>], normal: SIMD3<Float>) -> Bool {
        guard boundary.count >= 3 else { return false }
        let axes = basis(for: normal)
        let origin = boundary[0]
        func local(_ value: SIMD3<Float>) -> SIMD2<Float> {
            let delta = value - origin
            return [simd_dot(delta, axes.u), simd_dot(delta, axes.v)]
        }
        let polygon = boundary.map(local)
        let target = local(project(point, onto: origin, normal: normal))
        var inside = false
        var previous = polygon.count - 1
        for current in polygon.indices {
            let a = polygon[current]
            let b = polygon[previous]
            if pointToSegmentDistance(target, a, b) <= 0.04 { return true }
            let crosses = (a.y > target.y) != (b.y > target.y)
                && target.x < (b.x - a.x) * (target.y - a.y) / (b.y - a.y) + a.x
            if crosses { inside.toggle() }
            previous = current
        }
        return inside
    }

    /// Returns +1 when the polygon interior is on the edge's local forward side and
    /// -1 when it is on the opposite side. Polygon winding stays correct for every
    /// edge of a valid concave area, unlike an arithmetic-centre guess.
    static func interiorSide(
        of wall: CustomARWallRecord,
        in boundary: [SIMD3<Float>],
        normal rawNormal: SIMD3<Float>
    ) -> Float? {
        guard boundary.count >= 3,
              let up = normalizedUpFacing(rawNormal) else { return nil }
        let vector = wall.end.simd - wall.start.simd
        let length = simd_length(vector)
        guard length > 0.001 else { return nil }
        let direction = vector / length
        let face = simd_cross(direction, up)
        guard simd_length_squared(face) > 0.000_001 else { return nil }
        let local = localPoints(boundary, normal: up)
        var doubledSignedArea: Float = 0
        for index in local.indices {
            let next = local[(index + 1) % local.count]
            doubledSignedArea += local[index].x * next.y - next.x * local[index].y
        }
        guard abs(doubledSignedArea) > 0.000_001 else { return nil }

        // With u × v = up, a positive winding has its interior on up × direction.
        // Local forward is direction × up, the opposite side.
        return doubledSignedArea > 0 ? -1 : 1
    }

    static func inwardDoorOpenAngle(interiorSide: Float) -> Float {
        let side: Float = interiorSide >= 0 ? 1 : -1
        return -.pi * 0.52 * side
    }

    static func makeDesign(
        id: UUID = UUID(),
        name: String,
        boundary rawBoundary: [SIMD3<Float>],
        normal rawNormal: SIMD3<Float>,
        wallHeight: Float,
        wallThickness: Float,
        style: CustomARWallStyle,
        ceilingEnabled: Bool = false
    ) throws -> CustomARDesignRecord {
        guard rawBoundary.count >= 3 else { throw CustomARGeometryError.tooFewPoints }
        guard rawBoundary.count <= 24, let normal = normalizedUpFacing(rawNormal) else {
            throw CustomARGeometryError.invalidSurface
        }
        let origin = rawBoundary[0]
        guard rawBoundary.allSatisfy({ abs(simd_dot($0 - origin, normal)) <= 0.12 }) else {
            throw CustomARGeometryError.invalidSurface
        }
        let boundary = rawBoundary.map { project($0, onto: origin, normal: normal) }
        guard area(of: boundary, normal: normal) >= 0.20 else {
            throw CustomARGeometryError.areaTooSmall
        }
        guard !hasSelfIntersection(boundary, normal: normal) else {
            throw CustomARGeometryError.selfIntersection
        }
        let height = min(max(wallHeight, 0.60), 6)
        let thickness = min(max(wallThickness, 0.025), 0.40)
        var walls: [CustomARWallRecord] = []
        for index in boundary.indices {
            let next = boundary[(index + 1) % boundary.count]
            guard simd_distance(boundary[index], next) >= 0.30 else {
                throw CustomARGeometryError.wallTooShort
            }
            walls.append(CustomARWallRecord(
                id: UUID(), start: CustomARVector3(boundary[index]), end: CustomARVector3(next),
                height: height, thickness: thickness, style: style, doors: []
            ))
        }
        let design = CustomARDesignRecord(
            id: id,
            name: name,
            boundary: boundary.map { CustomARVector3($0) },
            surfaceNormal: CustomARVector3(normal),
            walls: walls,
            ceiling: ceilingEnabled
                ? CustomARCeilingRecord(height: height, thickness: thickness, style: style)
                : nil
        )
        guard design.isValid else { throw CustomARGeometryError.invalidSurface }
        return design
    }

    static func makeInteriorWall(
        start rawStart: SIMD3<Float>,
        end rawEnd: SIMD3<Float>,
        in design: CustomARDesignRecord,
        height: Float,
        thickness: Float,
        style: CustomARWallStyle
    ) throws -> CustomARWallRecord {
        let origin = design.boundary[0].simd
        let start = project(rawStart, onto: origin, normal: design.normal)
        let end = project(rawEnd, onto: origin, normal: design.normal)
        guard segmentIsInside(
            start: start,
            end: end,
            boundary: design.boundary.map(\.simd),
            normal: design.normal
        ) else {
            throw CustomARGeometryError.outsideArea
        }
        guard simd_distance(start, end) >= 0.30 else { throw CustomARGeometryError.wallTooShort }
        let wall = CustomARWallRecord(
            id: UUID(), start: CustomARVector3(start), end: CustomARVector3(end),
            height: min(max(height, 0.60), 6),
            thickness: min(max(thickness, 0.025), 0.40),
            style: style,
            doors: []
        )
        guard wall.isValid else { throw CustomARGeometryError.invalidSurface }
        return wall
    }

    static func door(
        id: UUID = UUID(),
        on wall: CustomARWallRecord,
        at point: SIMD3<Float>,
        width requestedWidth: Float = 0.90,
        height requestedHeight: Float = 2.05
    ) throws -> CustomARDoorRecord {
        let direction = simd_normalize(wall.end.simd - wall.start.simd)
        let distance = simd_dot(point - wall.start.simd, direction)
        let width = min(max(requestedWidth, 0.55), 2.40)
        let height = min(max(requestedHeight, 1.20), min(3.20, wall.height - 0.08))
        guard wall.length >= width + 0.20, height >= 1.20 else {
            throw CustomARGeometryError.doorDoesNotFit
        }
        let margin = width * 0.5 + 0.05
        let center = min(max(distance, margin), wall.length - margin)
        let candidate = CustomARDoorRecord(
            id: id, centerRatio: center / wall.length,
            width: width, height: height, isOpen: false
        )
        guard candidate.isValid else { throw CustomARGeometryError.doorDoesNotFit }
        guard doorsDoNotOverlap(wall.doors + [candidate], wallLength: wall.length) else {
            throw CustomARGeometryError.doorOverlap
        }
        return candidate
    }

    static func doorsDoNotOverlap(_ doors: [CustomARDoorRecord], wallLength: Float) -> Bool {
        guard wallLength.isFinite, wallLength > 0 else { return false }
        let intervals = doors.map {
            let center = $0.centerRatio * wallLength
            return (center - $0.width * 0.5, center + $0.width * 0.5)
        }.sorted { $0.0 < $1.0 }
        guard intervals.allSatisfy({ interval in
            interval.0 >= 0.049 && interval.1 <= wallLength - 0.049
        }) else { return false }
        guard intervals.count >= 2 else { return true }
        for index in 1..<intervals.count where intervals[index].0 < intervals[index - 1].1 + 0.05 {
            return false
        }
        return true
    }

    static func segmentIsInside(
        start: SIMD3<Float>,
        end: SIMD3<Float>,
        boundary: [SIMD3<Float>],
        normal: SIMD3<Float>
    ) -> Bool {
        let length = simd_distance(start, end)
        guard length.isFinite else { return false }
        let steps = max(2, Int((length / 0.08).rounded(.up)))
        for step in 0...steps {
            let ratio = Float(step) / Float(steps)
            if !contains(start + (end - start) * ratio, in: boundary, normal: normal) {
                return false
            }
        }
        return true
    }

    /// Returns triangles with winding toward `normal`. Ear clipping keeps the ceiling
    /// inside concave user-drawn boundaries instead of covering their bounding box.
    static func triangulatedIndices(
        for points: [SIMD3<Float>],
        normal: SIMD3<Float>
    ) -> [UInt32] {
        let polygon = localPoints(points, normal: normal)
        guard polygon.count >= 3 else { return [] }

        func cross(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>) -> Float {
            let ab = b - a, ac = c - a
            return ab.x * ac.y - ab.y * ac.x
        }
        var signedArea: Float = 0
        for index in polygon.indices {
            let next = polygon[(index + 1) % polygon.count]
            signedArea += polygon[index].x * next.y - next.x * polygon[index].y
        }
        guard abs(signedArea) > 0.000_001 else { return [] }
        let winding: Float = signedArea > 0 ? 1 : -1

        func isInsideTriangle(
            _ point: SIMD2<Float>,
            _ a: SIMD2<Float>,
            _ b: SIMD2<Float>,
            _ c: SIMD2<Float>
        ) -> Bool {
            let epsilon: Float = 0.000_001
            return cross(a, b, point) * winding >= -epsilon
                && cross(b, c, point) * winding >= -epsilon
                && cross(c, a, point) * winding >= -epsilon
        }

        var remaining = Array(polygon.indices)
        var result: [UInt32] = []
        result.reserveCapacity((polygon.count - 2) * 3)
        while remaining.count > 3 {
            var clippedEar = false
            for position in remaining.indices {
                let previous = remaining[(position + remaining.count - 1) % remaining.count]
                let current = remaining[position]
                let next = remaining[(position + 1) % remaining.count]
                guard cross(polygon[previous], polygon[current], polygon[next]) * winding
                        > 0.000_001 else { continue }
                let containsVertex = remaining.contains { candidate in
                    guard candidate != previous, candidate != current, candidate != next else {
                        return false
                    }
                    return isInsideTriangle(
                        polygon[candidate], polygon[previous], polygon[current], polygon[next]
                    )
                }
                guard !containsVertex else { continue }
                if winding > 0 {
                    result.append(contentsOf: [UInt32(previous), UInt32(current), UInt32(next)])
                } else {
                    result.append(contentsOf: [UInt32(previous), UInt32(next), UInt32(current)])
                }
                remaining.remove(at: position)
                clippedEar = true
                break
            }
            guard clippedEar else { return [] }
        }
        if winding > 0 {
            result.append(contentsOf: remaining.map { UInt32($0) })
        } else {
            result.append(contentsOf: [UInt32(remaining[0]), UInt32(remaining[2]), UInt32(remaining[1])])
        }
        return result
    }

    private static func segmentsIntersect(
        _ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>, _ d: SIMD2<Float>
    ) -> Bool {
        func cross(_ p: SIMD2<Float>, _ q: SIMD2<Float>, _ r: SIMD2<Float>) -> Float {
            let pq = q - p, pr = r - p
            return pq.x * pr.y - pq.y * pr.x
        }
        func liesOnSegment(_ point: SIMD2<Float>, _ start: SIMD2<Float>, _ end: SIMD2<Float>) -> Bool {
            let epsilon: Float = 0.000_1
            return point.x >= min(start.x, end.x) - epsilon
                && point.x <= max(start.x, end.x) + epsilon
                && point.y >= min(start.y, end.y) - epsilon
                && point.y <= max(start.y, end.y) + epsilon
        }

        let epsilon: Float = 0.000_001
        let abC = cross(a, b, c), abD = cross(a, b, d)
        let cdA = cross(c, d, a), cdB = cross(c, d, b)
        if abC * abD < -epsilon && cdA * cdB < -epsilon { return true }
        if abs(abC) <= epsilon, liesOnSegment(c, a, b) { return true }
        if abs(abD) <= epsilon, liesOnSegment(d, a, b) { return true }
        if abs(cdA) <= epsilon, liesOnSegment(a, c, d) { return true }
        if abs(cdB) <= epsilon, liesOnSegment(b, c, d) { return true }
        return false
    }

    private static func pointToSegmentDistance(
        _ point: SIMD2<Float>, _ start: SIMD2<Float>, _ end: SIMD2<Float>
    ) -> Float {
        let segment = end - start
        let lengthSquared = simd_length_squared(segment)
        guard lengthSquared > 0.000_001 else { return simd_distance(point, start) }
        let t = min(max(simd_dot(point - start, segment) / lengthSquared, 0), 1)
        return simd_distance(point, start + segment * t)
    }
}
