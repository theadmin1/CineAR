import Foundation
import simd

@main
struct CustomARGeometryTests {
    static func main() throws {
        let snapped = CustomARGeometry.snappedBaseSurface(
            position: [0.2, 0.09, -0.4], normal: simd_normalize([0.03, 1, 0.01]),
            stableFloorY: 0
        )
        precondition(snapped != nil)
        precondition(abs(snapped!.position.y) < 0.000_1)
        precondition(simd_distance(snapped!.normal, [0, 1, 0]) < 0.000_1)
        let inclinedNormal = simd_normalize(SIMD3<Float>(0, 1, 0.35))
        let inclined = CustomARGeometry.snappedBaseSurface(
            position: [0, 0.09, 0], normal: inclinedNormal, stableFloorY: 0
        )
        precondition(inclined != nil)
        precondition(abs(inclined!.position.y - 0.09) < 0.000_1)
        precondition(simd_distance(inclined!.normal, inclinedNormal) < 0.000_1)
        let distantFloor = CustomARGeometry.snappedBaseSurface(
            position: [0, 0.42, 0], normal: [0, 1, 0], stableFloorY: 0
        )
        precondition(abs(distantFloor!.position.y - 0.42) < 0.000_1)

        let boundary: [SIMD3<Float>] = [
            [0, 0, 0], [3, 0, 0], [3, 0, 2], [0, 0, 2]
        ]
        let design = try CustomARGeometry.makeDesign(
            name: "Test Alanı",
            boundary: boundary,
            normal: [0, 1, 0],
            wallHeight: 2.5,
            wallThickness: 0.10,
            style: .studioWhite,
            ceilingEnabled: true
        )
        precondition(design.isValid)
        precondition(design.walls.count == 4)
        precondition(design.ceiling?.height == 2.5)
        precondition(CustomARGeometry.triangulatedIndices(
            for: boundary, normal: [0, 1, 0]
        ).count == 6)
        precondition(abs(CustomARGeometry.area(of: boundary, normal: [0, 1, 0]) - 6) < 0.001)
        precondition(CustomARGeometry.contains([1.5, 0, 1], in: boundary, normal: [0, 1, 0]))
        precondition(!CustomARGeometry.contains([4, 0, 1], in: boundary, normal: [0, 1, 0]))

        let backrooms = try CustomARGeometry.makeDesign(
            name: "Backrooms", boundary: boundary, normal: [0, 1, 0],
            wallHeight: 2.55, wallThickness: 0.10, style: .backrooms,
            ceilingEnabled: true
        )
        precondition(backrooms.isValid)
        precondition(backrooms.walls.allSatisfy { $0.style == .backrooms })
        precondition(backrooms.ceiling?.style == .backrooms)
        let backroomsData = try JSONEncoder().encode(backrooms)
        let restoredBackrooms = try JSONDecoder().decode(
            CustomARDesignRecord.self,
            from: backroomsData
        )
        precondition(restoredBackrooms == backrooms)
        precondition(CustomARWallStyle.allCases.filter(\.isBackrooms).count == 10)
        precondition(CustomARWallStyle.backrooms02.backroomsWallpaperAssetName == "backrooms_yasu_wall_02")
        precondition(CustomARWallStyle.backrooms04.backroomsCeilingAssetName == "backrooms_yasu_ceiling_04")
        precondition(CustomARWallStyle.backroomsClassic.backroomsWallpaperAssetName == "wall_cladding_backrooms_001")

        let interior = try CustomARGeometry.makeInteriorWall(
            start: [0.5, 0.03, 1], end: [2.5, -0.02, 1], in: design,
            height: 2.4, thickness: 0.08, style: .concrete
        )
        precondition(interior.isValid && abs(interior.length - 2) < 0.001)

        let firstWall = design.walls[0]
        let door = try CustomARGeometry.door(
            on: firstWall, at: [1.5, 0, 0], width: 0.9, height: 2.05
        )
        precondition(door.isValid && abs(door.centerRatio - 0.5) < 0.001)
        var occupiedWall = firstWall
        occupiedWall.doors = [door]
        do {
            _ = try CustomARGeometry.door(
                on: occupiedWall, at: [1.55, 0, 0], width: 0.8, height: 2
            )
            preconditionFailure("Overlapping doors must be rejected")
        } catch CustomARGeometryError.doorOverlap {
            // Expected.
        }

        let slopeNormal = simd_normalize(SIMD3<Float>(0, 1, 0.35))
        let axes = CustomARGeometry.basis(for: slopeNormal)
        let slopeOrigin = SIMD3<Float>(-1, 0.2, 0.5)
        let slopeBoundary = [
            slopeOrigin,
            slopeOrigin + axes.u * 2,
            slopeOrigin + axes.u * 2 + axes.v * 1.5,
            slopeOrigin + axes.v * 1.5,
        ]
        let slope = try CustomARGeometry.makeDesign(
            name: "Eğimli Alan", boundary: slopeBoundary, normal: slopeNormal,
            wallHeight: 2, wallThickness: 0.08, style: .brick
        )
        precondition(slope.isValid)
        precondition(abs(CustomARGeometry.area(of: slopeBoundary, normal: slopeNormal) - 3) < 0.001)

        let concave: [SIMD3<Float>] = [
            [0, 0, 0], [2, 0, 0], [2, 0, 1], [1, 0, 0.5], [0, 0, 1]
        ]
        precondition(CustomARGeometry.triangulatedIndices(
            for: concave, normal: [0, 1, 0]
        ).count == 9)
        let concaveDesign = try CustomARGeometry.makeDesign(
            name: "İçbükey", boundary: concave, normal: [0, 1, 0],
            wallHeight: 2.4, wallThickness: 0.08, style: .studioWhite
        )
        for wall in concaveDesign.walls {
            guard let side = CustomARGeometry.interiorSide(
                of: wall,
                in: concave,
                normal: [0, 1, 0]
            ) else {
                preconditionFailure("Every perimeter wall needs an interior side")
            }
            let direction = simd_normalize(wall.end.simd - wall.start.simd)
            let forward = simd_normalize(simd_cross(direction, SIMD3<Float>(0, 1, 0)))
            let probe = (wall.start.simd + wall.end.simd) * 0.5 + forward * side * 0.075
            precondition(CustomARGeometry.contains(probe, in: concave, normal: [0, 1, 0]))
            let angle = CustomARGeometry.inwardDoorOpenAngle(interiorSide: side)
            precondition(angle * side < 0)
        }
        let reversedConcave = Array(concave.reversed())
        let reversedDesign = try CustomARGeometry.makeDesign(
            name: "Ters İçbükey", boundary: reversedConcave, normal: [0, 1, 0],
            wallHeight: 2.4, wallThickness: 0.08, style: .studioWhite
        )
        for wall in reversedDesign.walls {
            let side = CustomARGeometry.interiorSide(
                of: wall,
                in: reversedConcave,
                normal: [0, 1, 0]
            )!
            let direction = simd_normalize(wall.end.simd - wall.start.simd)
            let forward = simd_normalize(simd_cross(direction, SIMD3<Float>(0, 1, 0)))
            let probe = (wall.start.simd + wall.end.simd) * 0.5 + forward * side * 0.075
            precondition(CustomARGeometry.contains(
                probe,
                in: reversedConcave,
                normal: [0, 1, 0]
            ))
            let angle = CustomARGeometry.inwardDoorOpenAngle(interiorSide: side)
            precondition(angle * side < 0)
        }
        do {
            _ = try CustomARGeometry.makeInteriorWall(
                start: [0.2, 0, 0.8], end: [1.8, 0, 0.8], in: concaveDesign,
                height: 2.4, thickness: 0.08, style: .studioWhite
            )
            preconditionFailure("An interior wall may not leave a concave boundary")
        } catch CustomARGeometryError.outsideArea {
            // Expected.
        }

        let crossed: [SIMD3<Float>] = [
            [0, 0, 0], [2, 0, 2], [0, 0, 2], [2, 0, 0]
        ]
        precondition(CustomARGeometry.hasSelfIntersection(crossed, normal: [0, 1, 0]))
        do {
            _ = try CustomARGeometry.makeDesign(
                name: "Bozuk", boundary: crossed, normal: [0, 1, 0],
                wallHeight: 2.5, wallThickness: 0.1, style: .studioWhite
            )
            preconditionFailure("Self-intersecting areas must be rejected")
        } catch CustomARGeometryError.areaTooSmall {
            // Bow-tie signed area cancels to zero before intersection validation.
        } catch CustomARGeometryError.selfIntersection {
            // Also acceptable if validation ordering changes.
        }

        var translation = matrix_identity_float4x4
        translation.columns.3 = [4, 1, -2, 1]
        let moved = design.applying(translation)
        precondition(moved.isValid)
        precondition(simd_distance(moved.boundary[0].simd, [4, 1, -2]) < 0.001)

        print("Custom AR geometry tests passed")
    }
}
