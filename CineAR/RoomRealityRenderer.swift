import Foundation
import RealityKit
import RoomPlan
import simd

struct RoomPlanPlacementHit {
    let position: SIMD3<Float>
    let normal: SIMD3<Float>
    let distanceMeters: Float
}

/// Gerçek USDZ kataloğu eklendiğinde prosedürel mobilyaların yerini alacak uzantı noktası.
/// Sağlanan entity kendi merkezinde olmalı ve `targetDimensions` sınırına sığmalıdır.
@MainActor
protocol RoomRealityAssetProviding: AnyObject {
    func makeEntity(
        for role: RealityObjectRole,
        theme: RealityTheme,
        targetDimensions: SIMD3<Float>
    ) -> Entity?
}

struct RoomRealityRenderReport: Sendable {
    let wallCount: Int
    let floorCount: Int
    let ceilingCount: Int
    let portalCount: Int
    let objectCount: Int
    let skippedElementCount: Int
    /// Düzensiz poligonlar, compile-safe ince kutu şeritleriyle yaklaşıklandı.
    let polygonApproximationCount: Int
    let inferredPortalAssociationCount: Int
    let unmatchedPortalCount: Int
    let suppressedNestedObjectCount: Int

    var renderedElementCount: Int {
        wallCount + floorCount + ceilingCount + portalCount + objectCount
    }

    var usesPolygonApproximation: Bool {
        polygonApproximationCount > 0
    }

    var geometryNotice: String? {
        guard usesPolygonApproximation else { return nil }
        return "\(polygonApproximationCount) düzensiz yüzey ince kutu şeritleriyle yaklaşıklandı; eğri yüzeyler düzlemselleştirildi"
    }
}

enum RoomRealityRendererError: LocalizedError {
    case invalidAlignmentTransform
    case emptyRoom
    case roomFileIsNotLocal

    var errorDescription: String? {
        switch self {
        case .invalidAlignmentTransform:
            "Tarama ile AR sahnesi arasındaki hizalama matrisi geçersiz"
        case .emptyRoom:
            "Taramada dönüştürülebilecek bir oda öğesi bulunamadı"
        case .roomFileIsNotLocal:
            "room.json yerel bir dosya olmalıdır"
        }
    }
}

/// RoomPlan'in parametrik sonucunu tek bir RealityKit kökü altında sanal sete çevirir.
/// Bu kök manuel eklenen dekor anchor'larından bağımsızdır.
@MainActor
final class RoomRealityRenderer {
    let rootEntity: AnchorEntity

    private var contentEntity = Entity()
    private let physicalOcclusionRootEntity: AnchorEntity
    private var physicalOcclusionContentEntity = Entity()
    private let assetProvider: (any RoomRealityAssetProviding)?
    private weak var installedARView: ARView?
    private var lastRoom: CapturedRoom?
    private var lastAlignmentTransform = matrix_identity_float4x4
    private var generatedBoxCount = 0

    /// RoomPlan can return very dense polygons and duplicate classifications. Keeping a
    /// hard upper bound prevents a malformed or unusually detailed scan from exhausting
    /// the device while RealityKit is creating the replacement room.
    private static let maximumGeneratedBoxCount = 600
    private static let maximumWalls = 24
    private static let maximumFloors = 8
    private static let maximumPortalsPerKind = 24
    private static let maximumObjects = 48
    private static let maximumSurfaceSegments = 16
    private static let maximumIrregularBands = 12
    private static let unitBoxMesh = MeshResource.generateBox(size: 1)
    private static let roundedUnitBoxMesh = MeshResource.generateBox(
        size: SIMD3<Float>(repeating: 1),
        cornerRadius: 0.02
    )
    private static let unitBoxCollisionShape = ShapeResource.generateBox(
        size: SIMD3<Float>(repeating: 1)
    )

    private(set) var selectedThemeID: RealityThemeID = .modern
    private(set) var lastReport: RoomRealityRenderReport?
    private(set) var hasPreparedOutline = false
    private(set) var hasPreparedPhysicalOcclusion = false

    init(assetProvider: (any RoomRealityAssetProviding)? = nil) {
        self.assetProvider = assetProvider
        rootEntity = AnchorEntity(world: .zero)
        physicalOcclusionRootEntity = AnchorEntity(world: .zero)
        rootEntity.name = "cinear.reality.room.root"
        contentEntity.name = "cinear.reality.room.content"
        rootEntity.addChild(contentEntity)
        physicalOcclusionRootEntity.name = "cinear.reality.physical-occlusion.root"
        physicalOcclusionContentEntity.name = "cinear.reality.physical-occlusion.content"
        physicalOcclusionRootEntity.addChild(physicalOcclusionContentEntity)
        physicalOcclusionRootEntity.isEnabled = false
    }

    var isVisible: Bool {
        get { rootEntity.isEnabled }
        set { rootEntity.isEnabled = newValue }
    }

    var isPhysicalOcclusionVisible: Bool {
        get { physicalOcclusionRootEntity.isEnabled }
        set {
            physicalOcclusionRootEntity.isEnabled = newValue && hasPreparedPhysicalOcclusion
        }
    }

    /// Renderer kökünü ARView'a yalnız bir kez takar; mevcut manuel dekorlara dokunmaz.
    func install(in arView: ARView) {
        if installedARView !== arView {
            installedARView?.scene.removeAnchor(rootEntity)
            installedARView?.scene.removeAnchor(physicalOcclusionRootEntity)
        }
        if rootEntity.scene !== arView.scene {
            rootEntity.scene?.removeAnchor(rootEntity)
            arView.scene.addAnchor(rootEntity)
        }
        if physicalOcclusionRootEntity.scene !== arView.scene {
            physicalOcclusionRootEntity.scene?.removeAnchor(physicalOcclusionRootEntity)
            arView.scene.addAnchor(physicalOcclusionRootEntity)
        }
        installedARView = arView
    }

    func removeFromScene() {
        installedARView?.scene.removeAnchor(rootEntity)
        installedARView?.scene.removeAnchor(physicalOcclusionRootEntity)
        installedARView = nil
    }

    /// Returns the closest visible RoomPlan replacement surface below a screen point.
    /// ARKit raycasts only know about live planes/mesh; they cannot hit this renderer's
    /// virtual floor, walls, or reconstructed furniture.
    func placementHit(in arView: ARView, at point: CGPoint) -> CollisionCastHit? {
        guard installedARView === arView, isVisible else { return nil }
        return arView.hitTest(point, query: .all, mask: .all).first {
            belongsToRenderedRoom($0.entity)
        }
    }

    /// RoomPlan duvarlarını, beyaz çizgi/oda teması görünür olmasa da dokunulabilir
    /// tutar. Bu test kaydedilmiş sonlu duvar poligonuyla çalışır; sonsuz, kameraya
    /// göre uydurulmuş bir düzlem üretmez.
    func scannedWallHit(in arView: ARView, at point: CGPoint) -> RoomPlanPlacementHit? {
        guard installedARView === arView,
              let room = lastRoom,
              let ray = arView.ray(through: point) else { return nil }
        let direction = simd_normalize(ray.direction)
        guard simd_length_squared(direction) > 0.000_001 else { return nil }

        var closest: RoomPlanPlacementHit?
        for wall in room.walls.prefix(Self.maximumWalls) {
            guard let bounds = Self.surfaceBounds(wall),
                  Self.isValidAffineTransform(wall.transform) else { continue }
            let finiteWallBounds: PlanarBounds
            if let dimensions = Self.planarDimensions(wall.dimensions) {
                // polygonCorners can initially cover only the confidently observed
                // patch. dimensions is RoomPlan's finite metric envelope for the same
                // wall, so unioning both keeps every scanned portion selectable.
                finiteWallBounds = PlanarBounds(
                    minX: min(bounds.minX, -dimensions.x * 0.5),
                    maxX: max(bounds.maxX, dimensions.x * 0.5),
                    minY: min(bounds.minY, -dimensions.y * 0.5),
                    maxY: max(bounds.maxY, dimensions.y * 0.5)
                )
            } else {
                finiteWallBounds = bounds
            }
            let transform = lastAlignmentTransform * wall.transform
            let planeOrigin = SIMD3<Float>(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )
            var normal = SIMD3<Float>(
                transform.columns.2.x,
                transform.columns.2.y,
                transform.columns.2.z
            )
            guard simd_length_squared(normal) > 0.000_001 else { continue }
            normal = simd_normalize(normal)
            guard abs(normal.y) <= 0.45 else { continue }

            let denominator = simd_dot(direction, normal)
            guard abs(denominator) >= 0.025 else { continue }
            let distance = simd_dot(planeOrigin - ray.origin, normal) / denominator
            guard distance.isFinite, (0.15...8.0).contains(distance),
                  closest.map({ distance < $0.distanceMeters }) ?? true else { continue }

            let position = ray.origin + direction * distance
            let local = simd_inverse(transform) * SIMD4<Float>(position, 1)
            guard local.x.isFinite, local.y.isFinite, local.z.isFinite,
                  abs(local.z) <= 0.08 else { continue }
            let polygon = Self.localPolygon(for: wall) ?? Self.rectanglePolygon(bounds)
            let intervals = Self.verticalIntervals(in: polygon, atX: local.x)
            let isInsideExactPolygon = intervals.contains(where: {
                local.y >= $0.lower - 0.015 && local.y <= $0.upper + 0.015
            })
            // RoomPlan can return a sparse/nonuniform polygon while its metric wall
            // extent is already stable. Keep the precise polygon as the first test,
            // then accept the finite reported wall bounds so the entire scanned wall
            // remains tappable. This is still a bounded wall, never an infinite plane.
            let boundsMargin: Float = 0.03
            let isInsideFiniteWallBounds =
                local.x >= finiteWallBounds.minX - boundsMargin
                && local.x <= finiteWallBounds.maxX + boundsMargin
                && local.y >= finiteWallBounds.minY - boundsMargin
                && local.y <= finiteWallBounds.maxY + boundsMargin
            guard isInsideExactPolygon || isInsideFiniteWallBounds else { continue }

            if simd_dot(normal, direction) > 0 { normal = -normal }
            closest = RoomPlanPlacementHit(
                position: position,
                normal: normal,
                distanceMeters: distance
            )
        }
        return closest
    }

    func cachePlacementSurfaces(
        from room: CapturedRoom,
        alignmentTransform: simd_float4x4 = matrix_identity_float4x4
    ) {
        guard Self.isValidAffineTransform(alignmentTransform) else { return }
        lastRoom = room
        lastAlignmentTransform = alignmentTransform
    }

    func clear() {
        contentEntity.removeFromParent()
        contentEntity = Entity()
        contentEntity.name = "cinear.reality.room.content"
        rootEntity.addChild(contentEntity)
        physicalOcclusionContentEntity.removeFromParent()
        physicalOcclusionContentEntity = Entity()
        physicalOcclusionContentEntity.name = "cinear.reality.physical-occlusion.content"
        physicalOcclusionRootEntity.addChild(physicalOcclusionContentEntity)
        physicalOcclusionRootEntity.isEnabled = false
        lastRoom = nil
        lastReport = nil
        hasPreparedOutline = false
        hasPreparedPhysicalOcclusion = false
        lastAlignmentTransform = matrix_identity_float4x4
        contentEntity.transform = .identity
    }

    /// Gerçek kamera görünümünde RoomPlan'ın tanıdığı mobilyaları görünmez derinlik
    /// yazıcılarına çevirir. Böylece örneğin gerçek bir masa, arkasındaki sanal
    /// dekoru canlı LiDAR mesh'i kısa süreli kaçırsa bile doğru biçimde örter.
    @discardableResult
    func preparePhysicalOcclusion(
        roomJSONURL: URL,
        alignmentTransform: simd_float4x4 = matrix_identity_float4x4
    ) throws -> Int {
        let room = try Self.loadRoomJSON(from: roomJSONURL)
        guard Self.isValidAffineTransform(alignmentTransform) else {
            throw RoomRealityRendererError.invalidAlignmentTransform
        }
        cachePlacementSurfaces(from: room, alignmentTransform: alignmentTransform)

        let stagingEntity = Entity()
        stagingEntity.name = "cinear.reality.physical-occlusion.content"
        stagingEntity.transform = Transform(matrix: alignmentTransform)

        let objects = Array(room.objects.prefix(Self.maximumObjects))
        var objectsByID: [UUID: CapturedRoom.Object] = [:]
        for object in objects where objectsByID[object.identifier] == nil {
            objectsByID[object.identifier] = object
        }
        let suppressedIDs = nestedObjectIDsToSuppress(objectsByID: objectsByID)
        var count = 0
        for object in objects where !suppressedIDs.contains(object.identifier) {
            guard let occluder = makePhysicalOcclusionEntity(object) else { continue }
            stagingEntity.addChild(occluder)
            count += 1
        }

        physicalOcclusionContentEntity.removeFromParent()
        physicalOcclusionContentEntity = stagingEntity
        physicalOcclusionRootEntity.addChild(physicalOcclusionContentEntity)
        hasPreparedPhysicalOcclusion = count > 0
        physicalOcclusionRootEntity.isEnabled = count > 0
        return count
    }

    /// `alignmentTransform`, taramadaki dünya koordinatlarını etkin ARSession koordinatlarına taşır.
    /// Aynı ARSession sürdürüldüğünde identity matrisi yeterlidir.
    @discardableResult
    func render(
        room: CapturedRoom,
        theme: RealityTheme,
        alignmentTransform: simd_float4x4 = matrix_identity_float4x4
    ) throws -> RoomRealityRenderReport {
        guard Self.isValidAffineTransform(alignmentTransform) else {
            throw RoomRealityRendererError.invalidAlignmentTransform
        }

        generatedBoxCount = 0

        let stagingEntity = Entity()
        stagingEntity.name = "cinear.reality.room.content"
        stagingEntity.transform = Transform(matrix: alignmentTransform)

        let walls = Array(room.walls.prefix(Self.maximumWalls))
        let floors = Array(room.floors.prefix(Self.maximumFloors))
        let doors = Array(room.doors.prefix(Self.maximumPortalsPerKind))
        let windows = Array(room.windows.prefix(Self.maximumPortalsPerKind))
        let openings = Array(room.openings.prefix(Self.maximumPortalsPerKind))
        let objects = Array(room.objects.prefix(Self.maximumObjects))
        let apertures = doors + windows + openings
        let portalAssociations = associate(apertures: apertures, with: walls)
        var wallCount = 0
        var floorCount = 0
        var ceilingCount = 0
        var portalCount = 0
        var objectCount = 0
        var skippedCount =
            (room.walls.count - walls.count)
            + (room.floors.count - floors.count)
            + (room.doors.count - doors.count)
            + (room.windows.count - windows.count)
            + (room.openings.count - openings.count)
            + (room.objects.count - objects.count)
        var polygonApproximationCount = 0
        var suppressedNestedObjectCount = 0

        for wall in walls {
            let children = portalAssociations.aperturesByWallID[wall.identifier] ?? []
            if let entity = makeWallEntity(wall, apertures: children, theme: theme) {
                stagingEntity.addChild(entity)
                wallCount += 1
                if Self.requiresPolygonApproximation(wall) {
                    polygonApproximationCount += 1
                }
            } else {
                skippedCount += 1
            }
        }

        for floor in floors {
            if let entity = makePlanarSurfaceEntity(floor, role: .floor, theme: theme) {
                stagingEntity.addChild(entity)
                floorCount += 1
                if Self.requiresPolygonApproximation(floor) {
                    polygonApproximationCount += 1
                }
            } else {
                skippedCount += 1
            }
        }

        if let ceilingY = inferredCeilingY(walls: walls, floors: floors) {
            if floors.isEmpty {
                if let ceiling = makeFallbackCeilingEntity(
                    from: walls,
                    ceilingY: ceilingY,
                    theme: theme
                ) {
                    stagingEntity.addChild(ceiling)
                    ceilingCount = 1
                    polygonApproximationCount += 1
                }
            } else {
                for floor in floors {
                    if let ceiling = makeCeilingEntity(
                        from: floor,
                        ceilingY: ceilingY,
                        theme: theme
                    ) {
                        stagingEntity.addChild(ceiling)
                        ceilingCount += 1
                        if Self.requiresPolygonApproximation(floor) {
                            polygonApproximationCount += 1
                        }
                    }
                }
            }
        }

        for door in doors {
            let role: RealitySurfaceRole
            if case .door(let isOpen) = door.category, isOpen {
                role = .opening
            } else {
                role = .door
            }
            if let entity = makePortalEntity(door, role: role, theme: theme) {
                stagingEntity.addChild(entity)
                portalCount += 1
                if Self.requiresPolygonApproximation(door) {
                    polygonApproximationCount += 1
                }
            } else {
                skippedCount += 1
            }
        }

        for window in windows {
            if let entity = makePortalEntity(window, role: .window, theme: theme) {
                stagingEntity.addChild(entity)
                portalCount += 1
                if Self.requiresPolygonApproximation(window) {
                    polygonApproximationCount += 1
                }
            } else {
                skippedCount += 1
            }
        }

        for opening in openings {
            if let entity = makePortalEntity(opening, role: .opening, theme: theme) {
                stagingEntity.addChild(entity)
                portalCount += 1
                if Self.requiresPolygonApproximation(opening) {
                    polygonApproximationCount += 1
                }
            } else {
                skippedCount += 1
            }
        }

        var objectsByID: [UUID: CapturedRoom.Object] = [:]
        for object in objects where objectsByID[object.identifier] == nil {
            objectsByID[object.identifier] = object
        }
        let suppressedObjectIDs = nestedObjectIDsToSuppress(objectsByID: objectsByID)
        suppressedNestedObjectCount = suppressedObjectIDs.count
        for object in objects {
            if suppressedObjectIDs.contains(object.identifier) { continue }
            if let entity = makeObjectEntity(object, theme: theme) {
                stagingEntity.addChild(entity)
                objectCount += 1
            } else {
                skippedCount += 1
            }
        }

        let report = RoomRealityRenderReport(
            wallCount: wallCount,
            floorCount: floorCount,
            ceilingCount: ceilingCount,
            portalCount: portalCount,
            objectCount: objectCount,
            skippedElementCount: skippedCount,
            polygonApproximationCount: polygonApproximationCount,
            inferredPortalAssociationCount: portalAssociations.inferredCount,
            unmatchedPortalCount: portalAssociations.unmatchedCount,
            suppressedNestedObjectCount: suppressedNestedObjectCount
        )
        guard report.renderedElementCount > 0 else {
            throw RoomRealityRendererError.emptyRoom
        }

        contentEntity.removeFromParent()
        contentEntity = stagingEntity
        rootEntity.addChild(contentEntity)
        selectedThemeID = theme.id
        hasPreparedOutline = false
        lastRoom = room
        lastAlignmentTransform = alignmentTransform
        lastReport = report
        return report
    }

    /// Aynı taramayı bozmadan yalnız materyal/şekil temasını değiştirir.
    @discardableResult
    func apply(theme: RealityTheme) throws -> RoomRealityRenderReport {
        guard let lastRoom else { throw RoomRealityRendererError.emptyRoom }
        return try render(
            room: lastRoom,
            theme: theme,
            alignmentTransform: lastAlignmentTransform
        )
    }

    @discardableResult
    func render(
        roomJSONURL: URL,
        theme: RealityTheme,
        alignmentTransform: simd_float4x4 = matrix_identity_float4x4
    ) throws -> RoomRealityRenderReport {
        let room = try Self.loadRoomJSON(from: roomJSONURL)
        return try render(
            room: room,
            theme: theme,
            alignmentTransform: alignmentTransform
        )
    }

    /// Kamerayı kapatmadan RoomPlan sonucunu ince beyaz hatlar halinde gösterir.
    /// Görsel parçalar collision üretmez; yüzey başına tek görünmez collider kullanılır.
    /// Böylece hem çizim maliyeti düşük kalır hem de kullanıcı taranmış zeminin tamamına
    /// dekor yerleştirebilir.
    @discardableResult
    func renderOutline(
        roomJSONURL: URL,
        alignmentTransform: simd_float4x4 = matrix_identity_float4x4
    ) throws -> RoomRealityRenderReport {
        let room = try Self.loadRoomJSON(from: roomJSONURL)
        return try renderOutline(room: room, alignmentTransform: alignmentTransform)
    }

    @discardableResult
    func renderOutline(
        room: CapturedRoom,
        alignmentTransform: simd_float4x4 = matrix_identity_float4x4
    ) throws -> RoomRealityRenderReport {
        guard Self.isValidAffineTransform(alignmentTransform) else {
            throw RoomRealityRendererError.invalidAlignmentTransform
        }

        generatedBoxCount = 0
        let stagingEntity = Entity()
        stagingEntity.name = "cinear.reality.room.content"
        stagingEntity.transform = Transform(matrix: alignmentTransform)

        let walls = Array(room.walls.prefix(Self.maximumWalls))
        let floors = Array(room.floors.prefix(Self.maximumFloors))
        let doors = Array(room.doors.prefix(Self.maximumPortalsPerKind))
        let windows = Array(room.windows.prefix(Self.maximumPortalsPerKind))
        let openings = Array(room.openings.prefix(Self.maximumPortalsPerKind))
        let objects = Array(room.objects.prefix(Self.maximumObjects))

        let whiteLine = RealityMaterialRecipe(
            1, 1, 1,
            alpha: 0.72,
            roughness: 0.18
        ).makeMaterial()
        let objectLine = RealityMaterialRecipe(
            0.82, 0.94, 1,
            alpha: 0.58,
            roughness: 0.18
        ).makeMaterial()

        var wallCount = 0
        var floorCount = 0
        var portalCount = 0
        var objectCount = 0
        var skippedCount =
            (room.walls.count - walls.count)
            + (room.floors.count - floors.count)
            + (room.doors.count - doors.count)
            + (room.windows.count - windows.count)
            + (room.openings.count - openings.count)
            + (room.objects.count - objects.count)

        for surface in walls {
            if let entity = makeSurfaceOutlineEntity(surface, material: whiteLine) {
                stagingEntity.addChild(entity)
                wallCount += 1
            } else {
                skippedCount += 1
            }
        }
        for surface in floors {
            if let entity = makeSurfaceOutlineEntity(surface, material: whiteLine) {
                stagingEntity.addChild(entity)
                floorCount += 1
            } else {
                skippedCount += 1
            }
        }
        for surface in doors + windows + openings {
            if let entity = makeSurfaceOutlineEntity(surface, material: whiteLine) {
                stagingEntity.addChild(entity)
                portalCount += 1
            } else {
                skippedCount += 1
            }
        }

        var objectsByID: [UUID: CapturedRoom.Object] = [:]
        for object in objects where objectsByID[object.identifier] == nil {
            objectsByID[object.identifier] = object
        }
        let suppressedObjectIDs = nestedObjectIDsToSuppress(objectsByID: objectsByID)
        for object in objects where !suppressedObjectIDs.contains(object.identifier) {
            if let entity = makeObjectOutlineEntity(object, material: objectLine) {
                stagingEntity.addChild(entity)
                objectCount += 1
            } else {
                skippedCount += 1
            }
        }

        let report = RoomRealityRenderReport(
            wallCount: wallCount,
            floorCount: floorCount,
            ceilingCount: 0,
            portalCount: portalCount,
            objectCount: objectCount,
            skippedElementCount: skippedCount,
            polygonApproximationCount: 0,
            inferredPortalAssociationCount: 0,
            unmatchedPortalCount: 0,
            suppressedNestedObjectCount: suppressedObjectIDs.count
        )
        guard report.renderedElementCount > 0 else {
            throw RoomRealityRendererError.emptyRoom
        }

        contentEntity.removeFromParent()
        contentEntity = stagingEntity
        rootEntity.addChild(contentEntity)
        hasPreparedOutline = true
        lastRoom = room
        lastAlignmentTransform = alignmentTransform
        lastReport = report
        return report
    }

    static func loadRoomJSON(from url: URL) throws -> CapturedRoom {
        guard url.isFileURL else { throw RoomRealityRendererError.roomFileIsNotLocal }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return try JSONDecoder().decode(CapturedRoom.self, from: data)
    }

    func inferredCeilingLevel(roomJSONURL: URL) throws -> Float? {
        let room = try Self.loadRoomJSON(from: roomJSONURL)
        return inferredCeilingY(walls: room.walls, floors: room.floors)
    }

    static func saveRoomJSON(_ room: CapturedRoom, to url: URL) throws {
        guard url.isFileURL else { throw RoomRealityRendererError.roomFileIsNotLocal }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(room)
        try data.write(to: url, options: [.atomic])
    }
}

// MARK: - Room surfaces

private extension RoomRealityRenderer {
    struct ApertureRect {
        let minX: Float
        let maxX: Float
        let minY: Float
        let maxY: Float
    }

    struct PlanarBounds {
        let minX: Float
        let maxX: Float
        let minY: Float
        let maxY: Float

        var width: Float { maxX - minX }
        var height: Float { maxY - minY }
        var center: SIMD2<Float> {
            [(minX + maxX) * 0.5, (minY + maxY) * 0.5]
        }
    }

    struct PortalAssociations {
        var aperturesByWallID: [UUID: [CapturedRoom.Surface]] = [:]
        var inferredCount = 0
        var unmatchedCount = 0
    }

    func makeSurfaceOutlineEntity(
        _ surface: CapturedRoom.Surface,
        material: PhysicallyBasedMaterial
    ) -> Entity? {
        guard let bounds = Self.surfaceBounds(surface),
              Self.isValidAffineTransform(surface.transform) else { return nil }

        let root = Entity()
        root.name = "cinear.reality.outline.surface.\(surface.identifier.uuidString)"
        root.transform = Transform(matrix: surface.transform)
        let lineWidth: Float = 0.018
        let lineDepth: Float = 0.035
        let center = bounds.center
        let countBefore = generatedBoxCount

        addBox(
            to: root,
            size: [bounds.width, lineWidth, lineDepth],
            position: [center.x, bounds.minY, 0],
            material: material,
            includeCollision: false
        )
        addBox(
            to: root,
            size: [bounds.width, lineWidth, lineDepth],
            position: [center.x, bounds.maxY, 0],
            material: material,
            includeCollision: false
        )
        addBox(
            to: root,
            size: [lineWidth, bounds.height, lineDepth],
            position: [bounds.minX, center.y, 0],
            material: material,
            includeCollision: false
        )
        addBox(
            to: root,
            size: [lineWidth, bounds.height, lineDepth],
            position: [bounds.maxX, center.y, 0],
            material: material,
            includeCollision: false
        )

        let collider = Entity()
        collider.name = "cinear.reality.outline.surface.collider"
        collider.position = [center.x, center.y, 0]
        collider.scale = [bounds.width, bounds.height, 0.04]
        collider.components.set(
            CollisionComponent(shapes: [Self.unitBoxCollisionShape])
        )
        root.addChild(collider)
        return generatedBoxCount > countBefore ? root : nil
    }

    func makeWallEntity(
        _ wall: CapturedRoom.Surface,
        apertures: [CapturedRoom.Surface],
        theme: RealityTheme
    ) -> Entity? {
        guard let bounds = Self.surfaceBounds(wall),
              Self.isValidAffineTransform(wall.transform) else { return nil }

        let root = Entity()
        root.name = "cinear.reality.wall.\(wall.identifier.uuidString)"
        root.transform = Transform(matrix: wall.transform)

        let wallMaterial = theme.materialRecipe(for: .wall).makeMaterial()
        let cutouts = apertures.compactMap {
            apertureRect($0, relativeTo: wall, wallBounds: bounds)
        }
        let polygon = Self.localPolygon(for: wall) ?? Self.rectanglePolygon(bounds)
        let wallSegmentCount = addPlanarFill(
            to: root,
            polygon: polygon,
            bounds: bounds,
            cutouts: cutouts,
            thickness: theme.surfaceThickness,
            material: wallMaterial
        )

        if generatedBoxCount < 320 {
            let baseboardHeight = min(max(bounds.height * 0.025, 0.035), 0.09)
            _ = addPlanarFill(
                to: root,
                polygon: polygon,
                bounds: bounds,
                cutouts: cutouts,
                thickness: theme.surfaceThickness * 1.45,
                material: theme.materialRecipe(for: .trim).makeMaterial(),
                yClip: (lower: bounds.minY, upper: bounds.minY + baseboardHeight),
                zOffset: theme.surfaceThickness * 0.18,
                cornerRadius: 0.006
            )
        }
        guard wallSegmentCount > 0 else { return nil }
        return root
    }

    func makePlanarSurfaceEntity(
        _ surface: CapturedRoom.Surface,
        role: RealitySurfaceRole,
        theme: RealityTheme
    ) -> Entity? {
        guard let bounds = Self.surfaceBounds(surface),
              Self.isValidAffineTransform(surface.transform) else { return nil }

        let root = Entity()
        root.name = "cinear.reality.surface.\(surface.identifier.uuidString)"
        root.transform = Transform(matrix: surface.transform)
        let polygon = Self.localPolygon(for: surface) ?? Self.rectanglePolygon(bounds)
        let segmentCount = addPlanarFill(
            to: root,
            polygon: polygon,
            bounds: bounds,
            cutouts: [],
            thickness: theme.surfaceThickness,
            material: theme.materialRecipe(for: role).makeMaterial()
        )
        return segmentCount > 0 ? root : nil
    }

    func inferredCeilingY(
        walls: [CapturedRoom.Surface],
        floors: [CapturedRoom.Surface]
    ) -> Float? {
        let wallTops = walls.compactMap { wall -> Float? in
            guard let bounds = Self.surfaceBounds(wall),
                  Self.isValidAffineTransform(wall.transform) else { return nil }
            let top = wall.transform * SIMD4<Float>(bounds.center.x, bounds.maxY, 0, 1)
            return top.y.isFinite ? top.y : nil
        }.sorted()
        guard !wallTops.isEmpty else { return nil }

        let medianTop = wallTops[wallTops.count / 2]
        let floorLevels = floors.compactMap { floor -> Float? in
            guard Self.isValidAffineTransform(floor.transform) else { return nil }
            let y = floor.transform.columns.3.y
            return y.isFinite ? y : nil
        }.sorted()

        let floorY: Float
        if floorLevels.isEmpty {
            let wallBottoms = walls.compactMap { wall -> Float? in
                guard let bounds = Self.surfaceBounds(wall),
                      Self.isValidAffineTransform(wall.transform) else { return nil }
                let bottom = wall.transform * SIMD4<Float>(bounds.center.x, bounds.minY, 0, 1)
                return bottom.y.isFinite ? bottom.y : nil
            }.sorted()
            guard !wallBottoms.isEmpty else { return nil }
            floorY = wallBottoms[wallBottoms.count / 2]
        } else {
            floorY = floorLevels[floorLevels.count / 2]
        }

        let roomHeight = medianTop - floorY
        guard roomHeight >= 1.7, roomHeight <= 6.5 else { return nil }
        return medianTop
    }

    func makeCeilingEntity(
        from floor: CapturedRoom.Surface,
        ceilingY: Float,
        theme: RealityTheme
    ) -> Entity? {
        guard let bounds = Self.surfaceBounds(floor),
              Self.isValidAffineTransform(floor.transform), ceilingY.isFinite else { return nil }
        var transform = floor.transform
        transform.columns.3.y = ceilingY

        let root = Entity()
        root.name = "cinear.reality.ceiling.\(floor.identifier.uuidString)"
        root.transform = Transform(matrix: transform)
        let polygon = Self.localPolygon(for: floor) ?? Self.rectanglePolygon(bounds)
        let segmentCount = addPlanarFill(
            to: root,
            polygon: polygon,
            bounds: bounds,
            cutouts: [],
            thickness: theme.surfaceThickness,
            material: theme.materialRecipe(for: .ceiling).makeMaterial()
        )
        return segmentCount > 0 ? root : nil
    }

    func makeFallbackCeilingEntity(
        from walls: [CapturedRoom.Surface],
        ceilingY: Float,
        theme: RealityTheme
    ) -> Entity? {
        var points: [SIMD3<Float>] = []
        for wall in walls {
            guard let bounds = Self.surfaceBounds(wall),
                  Self.isValidAffineTransform(wall.transform) else { continue }
            let polygon = Self.localPolygon(for: wall) ?? Self.rectanglePolygon(bounds)
            for corner in polygon {
                let point = wall.transform * SIMD4<Float>(corner.x, corner.y, 0, 1)
                guard point.x.isFinite, point.z.isFinite else { continue }
                points.append([point.x, ceilingY, point.z])
            }
        }
        guard let first = points.first else { return nil }

        var minX = first.x
        var maxX = first.x
        var minZ = first.z
        var maxZ = first.z
        for point in points.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minZ = min(minZ, point.z)
            maxZ = max(maxZ, point.z)
        }
        let width = maxX - minX
        let depth = maxZ - minZ
        guard width >= 0.5, depth >= 0.5, width <= 15, depth <= 15 else { return nil }

        let root = Entity()
        root.name = "cinear.reality.ceiling.inferred"
        root.position = [(minX + maxX) * 0.5, ceilingY, (minZ + maxZ) * 0.5]
        guard addBox(
            to: root,
            size: [width, theme.surfaceThickness, depth],
            position: .zero,
            material: theme.materialRecipe(for: .ceiling).makeMaterial()
        ) else { return nil }
        return root
    }

    func makePortalEntity(
        _ surface: CapturedRoom.Surface,
        role: RealitySurfaceRole,
        theme: RealityTheme
    ) -> Entity? {
        guard let bounds = Self.surfaceBounds(surface),
              Self.isValidAffineTransform(surface.transform) else { return nil }

        let width = bounds.width
        let height = bounds.height
        let center = bounds.center
        let root = Entity()
        root.name = "cinear.reality.portal.\(surface.identifier.uuidString)"
        root.transform = Transform(matrix: surface.transform)
        var didAddGeometry = false

        let panelThickness = theme.surfaceThickness * 0.62
        if role != .opening {
            let polygon = Self.localPolygon(for: surface) ?? Self.rectanglePolygon(bounds)
            let panelCornerRadius: Float = Self.isAxisAlignedRectangle(polygon)
                ? (role == .door ? 0.012 : 0.004)
                : 0
            didAddGeometry = addPlanarFill(
                to: root,
                polygon: polygon,
                bounds: bounds,
                cutouts: [],
                thickness: panelThickness,
                material: theme.materialRecipe(for: role).makeMaterial(),
                zOffset: theme.surfaceThickness * 0.62,
                cornerRadius: panelCornerRadius
            ) > 0
        }

        let trimWidth = min(max(min(width, height) * 0.035, 0.025), 0.075)
        let trimDepth = theme.surfaceThickness * 1.35
        let trimMaterial = theme.materialRecipe(for: .trim).makeMaterial()
        let z = theme.surfaceThickness * 0.78

        if addBox(
            to: root,
            size: [trimWidth, height + trimWidth, trimDepth],
            position: [bounds.minX - trimWidth * 0.5, center.y, z],
            material: trimMaterial,
            cornerRadius: 0.005
        ) { didAddGeometry = true }
        if addBox(
            to: root,
            size: [trimWidth, height + trimWidth, trimDepth],
            position: [bounds.maxX + trimWidth * 0.5, center.y, z],
            material: trimMaterial,
            cornerRadius: 0.005
        ) { didAddGeometry = true }
        if addBox(
            to: root,
            size: [width + trimWidth * 2, trimWidth, trimDepth],
            position: [center.x, bounds.maxY + trimWidth * 0.5, z],
            material: trimMaterial,
            cornerRadius: 0.005
        ) { didAddGeometry = true }
        if role == .window || role == .opening {
            if addBox(
                to: root,
                size: [width + trimWidth * 2, trimWidth, trimDepth],
                position: [center.x, bounds.minY - trimWidth * 0.5, z],
                material: trimMaterial,
                cornerRadius: 0.005
            ) { didAddGeometry = true }
        }
        return didAddGeometry ? root : nil
    }

    func apertureRect(
        _ aperture: CapturedRoom.Surface,
        relativeTo wall: CapturedRoom.Surface,
        wallBounds: PlanarBounds
    ) -> ApertureRect? {
        guard let apertureBounds = Self.surfaceBounds(aperture),
              Self.isValidAffineTransform(aperture.transform),
              Self.isValidAffineTransform(wall.transform) else { return nil }

        let relativeTransform = simd_inverse(wall.transform) * aperture.transform
        guard Self.isValidAffineTransform(relativeTransform) else { return nil }
        let aperturePolygon = Self.localPolygon(for: aperture)
            ?? Self.rectanglePolygon(apertureBounds)
        let transformedCorners = aperturePolygon.compactMap { corner -> SIMD2<Float>? in
            let point = relativeTransform * SIMD4<Float>(corner.x, corner.y, 0, 1)
            guard point.x.isFinite, point.y.isFinite else { return nil }
            return [point.x, point.y]
        }
        guard let first = transformedCorners.first,
              transformedCorners.count == aperturePolygon.count else { return nil }

        var apertureMinX = first.x
        var apertureMaxX = first.x
        var apertureMinY = first.y
        var apertureMaxY = first.y
        for point in transformedCorners.dropFirst() {
            apertureMinX = min(apertureMinX, point.x)
            apertureMaxX = max(apertureMaxX, point.x)
            apertureMinY = min(apertureMinY, point.y)
            apertureMaxY = max(apertureMaxY, point.y)
        }
        let margin: Float = 0.012

        let minX = max(apertureMinX - margin, wallBounds.minX)
        let maxX = min(apertureMaxX + margin, wallBounds.maxX)
        let minY = max(apertureMinY - margin, wallBounds.minY)
        let maxY = min(apertureMaxY + margin, wallBounds.maxY)
        guard maxX - minX > 0.015, maxY - minY > 0.015 else { return nil }
        return ApertureRect(minX: minX, maxX: maxX, minY: minY, maxY: maxY)
    }

    @discardableResult
    func addPlanarFill(
        to root: Entity,
        polygon: [SIMD2<Float>],
        bounds: PlanarBounds,
        cutouts: [ApertureRect],
        thickness: Float,
        material: PhysicallyBasedMaterial,
        yClip: (lower: Float, upper: Float)? = nil,
        zOffset: Float = 0,
        cornerRadius: Float = 0
    ) -> Int {
        guard generatedBoxCount < Self.maximumGeneratedBoxCount else { return 0 }
        var xBoundaries = [bounds.minX, bounds.maxX]
        for cutout in cutouts {
            xBoundaries.append(cutout.minX)
            xBoundaries.append(cutout.maxX)
        }

        if !Self.isAxisAlignedRectangle(polygon) {
            let stripCount = min(
                max(Int((bounds.width / 0.18).rounded(.up)), 1),
                Self.maximumIrregularBands
            )
            if stripCount > 1 {
                for index in 1..<stripCount {
                    xBoundaries.append(
                        bounds.minX + bounds.width * Float(index) / Float(stripCount)
                    )
                }
            }
        }
        xBoundaries.sort()
        xBoundaries = xBoundaries.reduce(into: []) { result, value in
            if let last = result.last, abs(last - value) < 0.004 { return }
            result.append(value)
        }

        guard xBoundaries.count >= 2 else { return 0 }
        var segmentCount = 0
        for index in 0..<(xBoundaries.count - 1) {
            guard segmentCount < Self.maximumSurfaceSegments,
                  generatedBoxCount < Self.maximumGeneratedBoxCount else {
                return segmentCount
            }
            let bandMinX = xBoundaries[index]
            let bandMaxX = xBoundaries[index + 1]
            let bandWidth = bandMaxX - bandMinX
            guard bandWidth > 0.012 else { continue }

            let midpoint = (bandMinX + bandMaxX) * 0.5
            let polygonIntervals = Self.verticalIntervals(in: polygon, atX: midpoint)
            let blocked = cutouts
                .filter { midpoint > $0.minX && midpoint < $0.maxX }
                .map { (lower: $0.minY, upper: $0.maxY) }
                .sorted { $0.lower < $1.lower }
            let merged = Self.mergeIntervals(blocked)

            for polygonInterval in polygonIntervals {
                let allowedLower = max(
                    polygonInterval.lower,
                    yClip?.lower ?? polygonInterval.lower
                )
                let allowedUpper = min(
                    polygonInterval.upper,
                    yClip?.upper ?? polygonInterval.upper
                )
                guard allowedUpper - allowedLower > 0.012 else { continue }

                var cursor = allowedLower
                for interval in merged {
                    guard interval.upper > allowedLower,
                          interval.lower < allowedUpper else { continue }
                    let blockLower = max(interval.lower, allowedLower)
                    let blockUpper = min(interval.upper, allowedUpper)
                    if blockLower > cursor {
                        guard segmentCount < Self.maximumSurfaceSegments else {
                            return segmentCount
                        }
                        if addPlanarSegment(
                            to: root,
                            minX: bandMinX,
                            maxX: bandMaxX,
                            minY: cursor,
                            maxY: blockLower,
                            thickness: thickness,
                            material: material,
                            zOffset: zOffset,
                            cornerRadius: cornerRadius
                        ) {
                            segmentCount += 1
                        }
                    }
                    cursor = max(cursor, blockUpper)
                }
                if cursor < allowedUpper {
                    guard segmentCount < Self.maximumSurfaceSegments else {
                        return segmentCount
                    }
                    if addPlanarSegment(
                        to: root,
                        minX: bandMinX,
                        maxX: bandMaxX,
                        minY: cursor,
                        maxY: allowedUpper,
                        thickness: thickness,
                        material: material,
                        zOffset: zOffset,
                        cornerRadius: cornerRadius
                    ) {
                        segmentCount += 1
                    }
                }
            }
        }
        return segmentCount
    }

    func addPlanarSegment(
        to root: Entity,
        minX: Float,
        maxX: Float,
        minY: Float,
        maxY: Float,
        thickness: Float,
        material: PhysicallyBasedMaterial,
        zOffset: Float,
        cornerRadius: Float
    ) -> Bool {
        let width = maxX - minX
        let height = maxY - minY
        guard width > 0.012, height > 0.012 else { return false }
        return addBox(
            to: root,
            size: [width, height, thickness],
            position: [(minX + maxX) * 0.5, (minY + maxY) * 0.5, zOffset],
            material: material,
            cornerRadius: cornerRadius
        )
    }

    static func verticalIntervals(
        in polygon: [SIMD2<Float>],
        atX x: Float
    ) -> [(lower: Float, upper: Float)] {
        guard polygon.count >= 3 else { return [] }
        var intersections: [Float] = []
        for index in polygon.indices {
            let start = polygon[index]
            let end = polygon[(index + 1) % polygon.count]
            let crossesForward = start.x <= x && end.x > x
            let crossesBackward = end.x <= x && start.x > x
            guard crossesForward || crossesBackward else { continue }
            let deltaX = end.x - start.x
            guard abs(deltaX) > 0.000_001 else { continue }
            let t = (x - start.x) / deltaX
            let y = start.y + (end.y - start.y) * t
            if y.isFinite { intersections.append(y) }
        }
        intersections.sort()
        intersections = intersections.reduce(into: []) { result, value in
            if let last = result.last, abs(last - value) < 0.002 { return }
            result.append(value)
        }

        var intervals: [(lower: Float, upper: Float)] = []
        var index = 0
        while index + 1 < intersections.count {
            let lower = intersections[index]
            let upper = intersections[index + 1]
            if upper - lower > 0.012 {
                intervals.append((lower: lower, upper: upper))
            }
            index += 2
        }
        return intervals
    }

    func associate(
        apertures: [CapturedRoom.Surface],
        with walls: [CapturedRoom.Surface]
    ) -> PortalAssociations {
        var result = PortalAssociations()
        var wallsByID: [UUID: CapturedRoom.Surface] = [:]
        for wall in walls where wallsByID[wall.identifier] == nil {
            wallsByID[wall.identifier] = wall
        }

        for aperture in apertures {
            if let parentID = aperture.parentIdentifier, wallsByID[parentID] != nil {
                result.aperturesByWallID[parentID, default: []].append(aperture)
                continue
            }

            guard let wall = closestCoplanarWall(to: aperture, walls: walls) else {
                result.unmatchedCount += 1
                continue
            }
            result.aperturesByWallID[wall.identifier, default: []].append(aperture)
            result.inferredCount += 1
        }
        return result
    }

    func closestCoplanarWall(
        to aperture: CapturedRoom.Surface,
        walls: [CapturedRoom.Surface]
    ) -> CapturedRoom.Surface? {
        guard let apertureBounds = Self.surfaceBounds(aperture),
              Self.isValidAffineTransform(aperture.transform) else { return nil }
        let apertureCenterLocal = SIMD4<Float>(
            apertureBounds.center.x,
            apertureBounds.center.y,
            0,
            1
        )
        let apertureCenterWorld = aperture.transform * apertureCenterLocal
        let apertureNormal = SIMD3<Float>(
            aperture.transform.columns.2.x,
            aperture.transform.columns.2.y,
            aperture.transform.columns.2.z
        )
        let apertureNormalLength = simd_length(apertureNormal)
        guard apertureNormalLength > 0.000_1 else { return nil }

        var best: (wall: CapturedRoom.Surface, score: Float)?
        for wall in walls where wall.story == aperture.story {
            guard let wallBounds = Self.surfaceBounds(wall),
                  Self.isValidAffineTransform(wall.transform) else { continue }
            let wallNormal = SIMD3<Float>(
                wall.transform.columns.2.x,
                wall.transform.columns.2.y,
                wall.transform.columns.2.z
            )
            let wallNormalLength = simd_length(wallNormal)
            guard wallNormalLength > 0.000_1 else { continue }
            let normalAlignment = abs(simd_dot(
                apertureNormal / apertureNormalLength,
                wallNormal / wallNormalLength
            ))
            guard normalAlignment >= 0.96 else { continue }

            let localCenter = simd_inverse(wall.transform) * apertureCenterWorld
            guard localCenter.x.isFinite, localCenter.y.isFinite, localCenter.z.isFinite,
                  abs(localCenter.z) <= 0.18,
                  localCenter.x >= wallBounds.minX - 0.15,
                  localCenter.x <= wallBounds.maxX + 0.15,
                  localCenter.y >= wallBounds.minY - 0.15,
                  localCenter.y <= wallBounds.maxY + 0.15,
                  apertureRect(
                    aperture,
                    relativeTo: wall,
                    wallBounds: wallBounds
                  ) != nil else { continue }

            let score = abs(localCenter.z) + (1 - normalAlignment) * 0.5
            if let currentBest = best {
                if score < currentBest.score { best = (wall, score) }
            } else {
                best = (wall, score)
            }
        }
        return best?.wall
    }

    static func surfaceBounds(_ surface: CapturedRoom.Surface) -> PlanarBounds? {
        if let polygon = localPolygon(for: surface), let first = polygon.first {
            var minX = first.x
            var maxX = first.x
            var minY = first.y
            var maxY = first.y
            for point in polygon.dropFirst() {
                minX = min(minX, point.x)
                maxX = max(maxX, point.x)
                minY = min(minY, point.y)
                maxY = max(maxY, point.y)
            }
            guard maxX - minX >= 0.02, maxY - minY >= 0.02,
                  maxX - minX <= 30, maxY - minY <= 30 else { return nil }
            return PlanarBounds(minX: minX, maxX: maxX, minY: minY, maxY: maxY)
        }

        guard let dimensions = planarDimensions(surface.dimensions) else { return nil }
        return PlanarBounds(
            minX: -dimensions.x * 0.5,
            maxX: dimensions.x * 0.5,
            minY: -dimensions.y * 0.5,
            maxY: dimensions.y * 0.5
        )
    }

    static func localPolygon(
        for surface: CapturedRoom.Surface
    ) -> [SIMD2<Float>]? {
        guard surface.polygonCorners.count >= 3,
              surface.polygonCorners.count <= 256 else { return nil }
        var polygon: [SIMD2<Float>] = []
        for corner in surface.polygonCorners {
            guard corner.x.isFinite, corner.y.isFinite, corner.z.isFinite,
                  abs(corner.x) <= 50, abs(corner.y) <= 50, abs(corner.z) <= 5 else {
                return nil
            }
            let point = SIMD2<Float>(corner.x, corner.y)
            if let last = polygon.last, simd_distance(last, point) < 0.002 { continue }
            polygon.append(point)
        }
        if polygon.count >= 2,
           let first = polygon.first,
           let last = polygon.last,
           simd_distance(first, last) < 0.002 {
            polygon.removeLast()
        }
        guard polygon.count >= 3 else { return nil }

        var doubledArea: Float = 0
        for index in polygon.indices {
            let start = polygon[index]
            let end = polygon[(index + 1) % polygon.count]
            doubledArea += start.x * end.y - end.x * start.y
        }
        guard abs(doubledArea) >= 0.000_8 else { return nil }
        return polygon
    }

    static func rectanglePolygon(_ bounds: PlanarBounds) -> [SIMD2<Float>] {
        [
            [bounds.minX, bounds.minY],
            [bounds.maxX, bounds.minY],
            [bounds.maxX, bounds.maxY],
            [bounds.minX, bounds.maxY]
        ]
    }

    static func isAxisAlignedRectangle(_ polygon: [SIMD2<Float>]) -> Bool {
        guard polygon.count == 4 else { return false }
        for index in polygon.indices {
            let start = polygon[index]
            let end = polygon[(index + 1) % polygon.count]
            let delta = end - start
            guard abs(delta.x) < 0.004 || abs(delta.y) < 0.004 else { return false }
        }
        return true
    }

    static func requiresPolygonApproximation(_ surface: CapturedRoom.Surface) -> Bool {
        if surface.curve != nil { return true }
        guard !surface.polygonCorners.isEmpty else { return false }
        guard let polygon = localPolygon(for: surface) else { return true }
        return !isAxisAlignedRectangle(polygon)
    }

    static func mergeIntervals(
        _ intervals: [(lower: Float, upper: Float)]
    ) -> [(lower: Float, upper: Float)] {
        var merged: [(lower: Float, upper: Float)] = []
        for interval in intervals {
            guard let last = merged.last else {
                merged.append(interval)
                continue
            }
            if interval.lower <= last.upper + 0.004 {
                merged[merged.count - 1].upper = max(last.upper, interval.upper)
            } else {
                merged.append(interval)
            }
        }
        return merged
    }
}

// MARK: - Recognized room objects

private extension RoomRealityRenderer {
    func makePhysicalOcclusionEntity(_ object: CapturedRoom.Object) -> Entity? {
        guard let size = Self.objectDimensions(object.dimensions),
              Self.isValidAffineTransform(object.transform) else { return nil }

        let root = Entity()
        root.name = "cinear.reality.physical-occlusion.object.\(object.identifier.uuidString)"
        root.transform = Transform(matrix: object.transform)

        switch Self.role(for: object.category) {
        case .table:
            let topHeight = min(max(size.y * 0.10, 0.035), 0.12)
            let legWidth = min(max(min(size.x, size.z) * 0.09, 0.025), 0.10)
            let legHeight = max(size.y - topHeight, 0.03)
            addPhysicalOcclusionBox(
                to: root,
                size: [size.x, topHeight, size.z],
                position: [0, size.y * 0.5 - topHeight * 0.5, 0]
            )
            let insetX = max(size.x * 0.5 - legWidth, 0)
            let insetZ = max(size.z * 0.5 - legWidth, 0)
            for x in [-insetX, insetX] {
                for z in [-insetZ, insetZ] {
                    addPhysicalOcclusionBox(
                        to: root,
                        size: [legWidth, legHeight, legWidth],
                        position: [x, -topHeight * 0.5, z]
                    )
                }
            }
        case .chair:
            let seatHeight = size.y * 0.48
            let seatThickness = min(max(size.y * 0.10, 0.035), 0.10)
            let legWidth = min(max(min(size.x, size.z) * 0.09, 0.018), 0.055)
            addPhysicalOcclusionBox(
                to: root,
                size: [size.x * 0.92, seatThickness, size.z * 0.86],
                position: [0, -size.y * 0.5 + seatHeight, 0]
            )
            addPhysicalOcclusionBox(
                to: root,
                size: [size.x * 0.92, size.y * 0.48, max(size.z * 0.10, 0.035)],
                position: [0, size.y * 0.25, -size.z * 0.40]
            )
            let insetX = max(size.x * 0.40, 0)
            let insetZ = max(size.z * 0.34, 0)
            for x in [-insetX, insetX] {
                for z in [-insetZ, insetZ] {
                    addPhysicalOcclusionBox(
                        to: root,
                        size: [legWidth, seatHeight, legWidth],
                        position: [x, -size.y * 0.5 + seatHeight * 0.5, z]
                    )
                }
            }
        case .unknown:
            return nil
        case .bathtub, .bed, .dishwasher, .fireplace, .oven, .refrigerator,
             .sink, .sofa, .stairs, .storage, .stove, .television, .toilet,
             .washerDryer:
            addPhysicalOcclusionBox(to: root, size: size, position: .zero)
        }
        return root.children.isEmpty ? nil : root
    }

    func addPhysicalOcclusionBox(
        to root: Entity,
        size: SIMD3<Float>,
        position: SIMD3<Float>
    ) {
        // RoomPlan dimensions are semantic envelopes, not millimeter-accurate meshes.
        // A small inward bias prevents the envelope from cutting a virtual prop that
        // is resting exactly on a table/seat edge. Live ARKit or AI depth still owns
        // the precise foreground boundary.
        let inset: Float = 0.05
        let biasedSize = SIMD3<Float>(
            max(size.x - inset, 0.015),
            max(size.y - inset, 0.015),
            max(size.z - inset, 0.015)
        )
        let box = ModelEntity(
            mesh: Self.unitBoxMesh,
            materials: [OcclusionMaterial()]
        )
        box.name = "cinear.reality.physical-occlusion.box"
        box.scale = biasedSize
        box.position = position
        root.addChild(box)
    }

    func makeObjectOutlineEntity(
        _ object: CapturedRoom.Object,
        material: PhysicallyBasedMaterial
    ) -> Entity? {
        guard let size = Self.objectDimensions(object.dimensions),
              Self.isValidAffineTransform(object.transform) else { return nil }

        let root = Entity()
        root.name = "cinear.reality.outline.object.\(object.identifier.uuidString)"
        root.transform = Transform(matrix: object.transform)
        let half = size * 0.5
        let lineWidth: Float = 0.018
        let countBefore = generatedBoxCount

        for y in [-half.y, half.y] {
            for z in [-half.z, half.z] {
                addBox(
                    to: root,
                    size: [size.x, lineWidth, lineWidth],
                    position: [0, y, z],
                    material: material,
                    includeCollision: false
                )
            }
        }
        for x in [-half.x, half.x] {
            for z in [-half.z, half.z] {
                addBox(
                    to: root,
                    size: [lineWidth, size.y, lineWidth],
                    position: [x, 0, z],
                    material: material,
                    includeCollision: false
                )
            }
        }
        for x in [-half.x, half.x] {
            for y in [-half.y, half.y] {
                addBox(
                    to: root,
                    size: [lineWidth, lineWidth, size.z],
                    position: [x, y, 0],
                    material: material,
                    includeCollision: false
                )
            }
        }

        let collider = Entity()
        collider.name = "cinear.reality.outline.object.collider"
        collider.scale = size
        collider.components.set(
            CollisionComponent(shapes: [Self.unitBoxCollisionShape])
        )
        root.addChild(collider)
        return generatedBoxCount > countBefore ? root : nil
    }

    func nestedObjectIDsToSuppress(
        objectsByID: [UUID: CapturedRoom.Object]
    ) -> Set<UUID> {
        var suppressed: Set<UUID> = []
        for child in objectsByID.values {
            guard let parentID = child.parentIdentifier,
                  let parent = objectsByID[parentID],
                  parent.identifier != child.identifier,
                  let childSize = Self.objectDimensions(child.dimensions),
                  let parentSize = Self.objectDimensions(parent.dimensions),
                  Self.isValidAffineTransform(child.transform),
                  Self.isValidAffineTransform(parent.transform) else { continue }

            let childToParent = simd_inverse(parent.transform) * child.transform
            guard Self.isValidAffineTransform(childToParent) else { continue }
            let parentHalfSize = parentSize * 0.5
            let tolerance: Float = 0.035
            var isContained = true
            for x in [-childSize.x * 0.5, childSize.x * 0.5] {
                for y in [-childSize.y * 0.5, childSize.y * 0.5] {
                    for z in [-childSize.z * 0.5, childSize.z * 0.5] {
                        let point = childToParent * SIMD4<Float>(x, y, z, 1)
                        let outsideX = abs(point.x) > parentHalfSize.x + tolerance
                        let outsideY = abs(point.y) > parentHalfSize.y + tolerance
                        let outsideZ = abs(point.z) > parentHalfSize.z + tolerance
                        if outsideX || outsideY || outsideZ {
                            isContained = false
                            break
                        }
                    }
                    if !isContained { break }
                }
                if !isContained { break }
            }
            guard isContained else { continue }

            let childVolume = childSize.x * childSize.y * childSize.z
            let parentVolume = parentSize.x * parentSize.y * parentSize.z
            guard parentVolume > 0.000_001 else { continue }
            let volumeRatio = childVolume / parentVolume
            if child.category == parent.category {
                suppressed.insert(child.identifier)
            } else if volumeRatio >= 0.72 {
                // Daha özgül çocuk modeli, neredeyse aynı hacimdeki genel ebeveyn kutusunun yerini alır.
                suppressed.insert(parent.identifier)
            }
        }
        return suppressed
    }

    func makeObjectEntity(
        _ object: CapturedRoom.Object,
        theme: RealityTheme
    ) -> Entity? {
        guard let dimensions = Self.objectDimensions(object.dimensions),
              Self.isValidAffineTransform(object.transform) else { return nil }

        let role = Self.role(for: object.category)
        let root = Entity()
        root.name = "cinear.reality.object.\(object.identifier.uuidString)"
        root.transform = Transform(matrix: object.transform)

        if let suppliedEntity = assetProvider?.makeEntity(
            for: role,
            theme: theme,
            targetDimensions: dimensions
        ) {
            suppliedEntity.name = "cinear.reality.asset.\(object.identifier.uuidString)"
            root.addChild(suppliedEntity)
            let placementCollider = Entity()
            placementCollider.name = "cinear.reality.asset.collider.\(object.identifier.uuidString)"
            placementCollider.scale = dimensions
            placementCollider.components.set(
                CollisionComponent(shapes: [Self.unitBoxCollisionShape])
            )
            root.addChild(placementCollider)
            return root
        }

        let recipes = theme.objectRecipes(for: role)
        let primary = recipes.primary.makeMaterial()
        let secondary = recipes.secondary.makeMaterial()
        let detail = recipes.detail.makeMaterial()
        let generatedBoxCountBeforeObject = generatedBoxCount

        switch role {
        case .table:
            buildTable(root, dimensions, primary, detail)
        case .chair:
            buildChair(root, dimensions, primary, detail)
        case .sofa:
            buildSofa(root, dimensions, primary, secondary)
        case .bed:
            buildBed(root, dimensions, primary, secondary, detail)
        case .storage:
            buildStorage(root, dimensions, primary, detail)
        case .television:
            buildTelevision(root, dimensions, secondary, primary, detail)
        case .fireplace:
            buildFireplace(root, dimensions, primary, secondary, detail)
        case .stairs:
            buildStairs(root, dimensions, primary)
        case .bathtub:
            buildBathtub(root, dimensions, primary, secondary)
        case .sink:
            buildSink(root, dimensions, primary, secondary, detail)
        case .toilet:
            buildToilet(root, dimensions, primary, secondary)
        case .refrigerator, .dishwasher, .oven, .stove, .washerDryer:
            buildAppliance(root, dimensions, primary, secondary, detail, role: role)
        case .unknown:
            addBox(
                to: root,
                size: dimensions,
                position: .zero,
                material: primary,
                cornerRadius: min(dimensions.x, dimensions.z) * 0.035
            )
        }
        return generatedBoxCount > generatedBoxCountBeforeObject ? root : nil
    }

    func buildTable(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ primary: PhysicallyBasedMaterial,
        _ detail: PhysicallyBasedMaterial
    ) {
        let topHeight = min(max(size.y * 0.09, 0.035), 0.12)
        let legWidth = min(max(min(size.x, size.z) * 0.09, 0.025), 0.10)
        let legHeight = max(size.y - topHeight, 0.03)
        addBox(
            to: root,
            size: [size.x, topHeight, size.z],
            position: [0, size.y * 0.5 - topHeight * 0.5, 0],
            material: primary,
            cornerRadius: 0.018
        )
        let insetX = max(size.x * 0.5 - legWidth, 0)
        let insetZ = max(size.z * 0.5 - legWidth, 0)
        for x in [-insetX, insetX] {
            for z in [-insetZ, insetZ] {
                addBox(
                    to: root,
                    size: [legWidth, legHeight, legWidth],
                    position: [x, -topHeight * 0.5, z],
                    material: detail,
                    cornerRadius: 0.008
                )
            }
        }
    }

    func buildChair(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ primary: PhysicallyBasedMaterial,
        _ detail: PhysicallyBasedMaterial
    ) {
        let seatHeight = size.y * 0.48
        let seatThickness = min(max(size.y * 0.10, 0.035), 0.10)
        let legWidth = min(max(min(size.x, size.z) * 0.09, 0.018), 0.055)
        addBox(
            to: root,
            size: [size.x * 0.88, seatThickness, size.z * 0.82],
            position: [0, -size.y * 0.5 + seatHeight, 0],
            material: primary,
            cornerRadius: 0.025
        )
        let backHeight = max(size.y - seatHeight, 0.04)
        addBox(
            to: root,
            size: [size.x * 0.88, backHeight, max(size.z * 0.09, 0.025)],
            position: [0, size.y * 0.5 - backHeight * 0.5, -size.z * 0.41],
            material: primary,
            cornerRadius: 0.025
        )
        let legHeight = max(seatHeight - seatThickness * 0.5, 0.025)
        for x in [-size.x * 0.34, size.x * 0.34] {
            for z in [-size.z * 0.31, size.z * 0.31] {
                addBox(
                    to: root,
                    size: [legWidth, legHeight, legWidth],
                    position: [x, -size.y * 0.5 + legHeight * 0.5, z],
                    material: detail,
                    cornerRadius: 0.005
                )
            }
        }
    }

    func buildSofa(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ primary: PhysicallyBasedMaterial,
        _ secondary: PhysicallyBasedMaterial
    ) {
        addBox(
            to: root,
            size: [size.x, size.y * 0.32, size.z * 0.82],
            position: [0, -size.y * 0.34, 0],
            material: primary,
            cornerRadius: min(size.x, size.z) * 0.04
        )
        addBox(
            to: root,
            size: [size.x * 0.78, size.y * 0.20, size.z * 0.66],
            position: [0, -size.y * 0.10, size.z * 0.06],
            material: secondary,
            cornerRadius: min(size.x, size.z) * 0.045
        )
        addBox(
            to: root,
            size: [size.x * 0.82, size.y * 0.52, size.z * 0.20],
            position: [0, size.y * 0.20, -size.z * 0.39],
            material: secondary,
            cornerRadius: 0.04
        )
        for x in [-size.x * 0.455, size.x * 0.455] {
            addBox(
                to: root,
                size: [size.x * 0.09, size.y * 0.50, size.z * 0.88],
                position: [x, -size.y * 0.08, 0],
                material: primary,
                cornerRadius: 0.035
            )
        }
    }

    func buildBed(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ primary: PhysicallyBasedMaterial,
        _ secondary: PhysicallyBasedMaterial,
        _ detail: PhysicallyBasedMaterial
    ) {
        addBox(
            to: root,
            size: [size.x, size.y * 0.25, size.z],
            position: [0, -size.y * 0.375, 0],
            material: detail,
            cornerRadius: 0.02
        )
        addBox(
            to: root,
            size: [size.x * 0.96, size.y * 0.28, size.z * 0.90],
            position: [0, -size.y * 0.12, size.z * 0.03],
            material: secondary,
            cornerRadius: 0.06
        )
        addBox(
            to: root,
            size: [size.x, size.y * 0.72, max(size.z * 0.08, 0.04)],
            position: [0, size.y * 0.14, -size.z * 0.46],
            material: primary,
            cornerRadius: 0.025
        )
    }

    func buildStorage(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ primary: PhysicallyBasedMaterial,
        _ detail: PhysicallyBasedMaterial
    ) {
        addBox(to: root, size: size, position: .zero, material: primary, cornerRadius: 0.018)
        let seam = max(size.x * 0.012, 0.008)
        addBox(
            to: root,
            size: [seam, size.y * 0.90, 0.012],
            position: [0, 0, size.z * 0.5 + 0.007],
            material: detail,
            cornerRadius: 0.002
        )
        for x in [-size.x * 0.12, size.x * 0.12] {
            addBox(
                to: root,
                size: [max(size.x * 0.018, 0.012), size.y * 0.12, 0.018],
                position: [x, 0, size.z * 0.5 + 0.016],
                material: detail,
                cornerRadius: 0.005
            )
        }
    }

    func buildTelevision(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ frame: PhysicallyBasedMaterial,
        _ screen: PhysicallyBasedMaterial,
        _ detail: PhysicallyBasedMaterial
    ) {
        let depth = max(size.z, 0.035)
        addBox(to: root, size: [size.x, size.y, depth], position: .zero, material: frame, cornerRadius: 0.018)
        addBox(
            to: root,
            size: [size.x * 0.94, size.y * 0.90, 0.012],
            position: [0, 0, depth * 0.5 + 0.007],
            material: screen,
            cornerRadius: 0.008
        )
        addBox(
            to: root,
            size: [size.x * 0.28, max(size.y * 0.035, 0.012), size.z * 0.70],
            position: [0, -size.y * 0.52, 0],
            material: detail,
            cornerRadius: 0.006
        )
    }

    func buildFireplace(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ primary: PhysicallyBasedMaterial,
        _ secondary: PhysicallyBasedMaterial,
        _ detail: PhysicallyBasedMaterial
    ) {
        let sideWidth = size.x * 0.18
        let headerHeight = size.y * 0.20
        addBox(
            to: root,
            size: [size.x * 0.62, size.y * 0.58, max(size.z * 0.12, 0.025)],
            position: [0, -size.y * 0.10, size.z * 0.51],
            material: secondary,
            cornerRadius: 0.008
        )
        for x in [-size.x * 0.41, size.x * 0.41] {
            addBox(
                to: root,
                size: [sideWidth, size.y, size.z],
                position: [x, 0, 0],
                material: primary,
                cornerRadius: 0.012
            )
        }
        addBox(
            to: root,
            size: [size.x * 0.82, headerHeight, size.z],
            position: [0, size.y * 0.40, 0],
            material: primary,
            cornerRadius: 0.012
        )
        addBox(
            to: root,
            size: [size.x, size.y * 0.10, size.z * 1.08],
            position: [0, -size.y * 0.45, size.z * 0.02],
            material: detail,
            cornerRadius: 0.01
        )
    }

    func buildStairs(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ material: PhysicallyBasedMaterial
    ) {
        let stepCount = 8
        let stepDepth = size.z / Float(stepCount)
        for index in 0..<stepCount {
            let factor = Float(index + 1) / Float(stepCount)
            let stepHeight = size.y * factor
            let z = -size.z * 0.5 + stepDepth * (Float(index) + 0.5)
            addBox(
                to: root,
                size: [size.x, stepHeight, stepDepth * 1.02],
                position: [0, -size.y * 0.5 + stepHeight * 0.5, z],
                material: material,
                cornerRadius: 0.006
            )
        }
    }

    func buildBathtub(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ primary: PhysicallyBasedMaterial,
        _ secondary: PhysicallyBasedMaterial
    ) {
        let rim = min(max(min(size.x, size.z) * 0.10, 0.035), 0.14)
        addBox(
            to: root,
            size: [size.x, size.y * 0.62, size.z],
            position: [0, -size.y * 0.19, 0],
            material: primary,
            cornerRadius: min(size.x, size.z) * 0.10
        )
        addBox(
            to: root,
            size: [max(size.x - rim * 2, 0.03), max(size.y * 0.18, 0.025), max(size.z - rim * 2, 0.03)],
            position: [0, size.y * 0.20, 0],
            material: secondary,
            cornerRadius: min(size.x, size.z) * 0.08
        )
    }

    func buildSink(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ primary: PhysicallyBasedMaterial,
        _ secondary: PhysicallyBasedMaterial,
        _ detail: PhysicallyBasedMaterial
    ) {
        addBox(
            to: root,
            size: [size.x, size.y * 0.24, size.z],
            position: [0, size.y * 0.30, 0],
            material: primary,
            cornerRadius: 0.04
        )
        addBox(
            to: root,
            size: [size.x * 0.64, size.y * 0.10, size.z * 0.62],
            position: [0, size.y * 0.43, 0],
            material: secondary,
            cornerRadius: 0.035
        )
        addBox(
            to: root,
            size: [size.x * 0.42, size.y * 0.70, size.z * 0.46],
            position: [0, -size.y * 0.15, 0],
            material: primary,
            cornerRadius: 0.025
        )
        addBox(
            to: root,
            size: [max(size.x * 0.04, 0.015), size.y * 0.20, max(size.z * 0.04, 0.015)],
            position: [0, size.y * 0.50, -size.z * 0.20],
            material: detail,
            cornerRadius: 0.006
        )
    }

    func buildToilet(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ primary: PhysicallyBasedMaterial,
        _ secondary: PhysicallyBasedMaterial
    ) {
        addBox(
            to: root,
            size: [size.x * 0.84, size.y * 0.36, size.z * 0.72],
            position: [0, -size.y * 0.24, size.z * 0.09],
            material: primary,
            cornerRadius: min(size.x, size.z) * 0.16
        )
        addBox(
            to: root,
            size: [size.x, size.y * 0.12, size.z * 0.82],
            position: [0, -size.y * 0.02, size.z * 0.08],
            material: secondary,
            cornerRadius: min(size.x, size.z) * 0.17
        )
        addBox(
            to: root,
            size: [size.x * 0.82, size.y * 0.54, size.z * 0.34],
            position: [0, size.y * 0.23, -size.z * 0.31],
            material: primary,
            cornerRadius: 0.04
        )
    }

    func buildAppliance(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ primary: PhysicallyBasedMaterial,
        _ secondary: PhysicallyBasedMaterial,
        _ detail: PhysicallyBasedMaterial,
        role: RealityObjectRole
    ) {
        addBox(to: root, size: size, position: .zero, material: primary, cornerRadius: 0.025)
        let faceDepth = max(size.z * 0.018, 0.012)
        let faceHeight: Float = role == .stove ? size.y * 0.12 : size.y * 0.72
        addBox(
            to: root,
            size: [size.x * 0.88, faceHeight, faceDepth],
            position: [0, role == .stove ? size.y * 0.43 : -size.y * 0.04, size.z * 0.5 + faceDepth * 0.55],
            material: secondary,
            cornerRadius: 0.018
        )
        let controlHeight = min(max(size.y * 0.08, 0.025), 0.10)
        addBox(
            to: root,
            size: [size.x * 0.72, controlHeight, faceDepth * 1.2],
            position: [0, size.y * 0.36, size.z * 0.5 + faceDepth * 1.2],
            material: detail,
            cornerRadius: 0.008
        )
    }
}

// MARK: - Shared helpers

private extension RoomRealityRenderer {
    @discardableResult
    func addBox(
        to parent: Entity,
        size: SIMD3<Float>,
        position: SIMD3<Float>,
        material: PhysicallyBasedMaterial,
        cornerRadius: Float = 0.003,
        includeCollision: Bool = true
    ) -> Bool {
        guard generatedBoxCount < Self.maximumGeneratedBoxCount,
              size.x.isFinite, size.y.isFinite, size.z.isFinite,
              position.x.isFinite, position.y.isFinite, position.z.isFinite,
              cornerRadius.isFinite else { return false }

        let safeSize = SIMD3<Float>(
            max(abs(size.x), 0.005),
            max(abs(size.y), 0.005),
            max(abs(size.z), 0.005)
        )
        guard safeSize.x <= 100, safeSize.y <= 100, safeSize.z <= 100 else {
            return false
        }

        // All procedural pieces share one mesh. Per-entity scale preserves dimensions
        // without allocating hundreds of independent MeshResource objects.
        let mesh = cornerRadius > 0.000_1 ? Self.roundedUnitBoxMesh : Self.unitBoxMesh
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.scale = safeSize
        entity.position = position
        // The visual mesh is a shared unit box whose entity scale supplies its actual
        // dimensions. Reusing the matching unit collision shape keeps hundreds of room
        // pieces cheap while making the scanned room available to placement hit tests.
        if includeCollision {
            entity.collision = CollisionComponent(shapes: [Self.unitBoxCollisionShape])
        }
        parent.addChild(entity)
        generatedBoxCount += 1
        return true
    }

    func belongsToRenderedRoom(_ entity: Entity) -> Bool {
        var candidate: Entity? = entity
        while let current = candidate {
            if current === rootEntity { return true }
            candidate = current.parent
        }
        return false
    }

    static func planarDimensions(_ dimensions: SIMD3<Float>) -> SIMD2<Float>? {
        guard dimensions.x.isFinite, dimensions.y.isFinite,
              abs(dimensions.x) >= 0.02, abs(dimensions.y) >= 0.02,
              abs(dimensions.x) <= 30, abs(dimensions.y) <= 30 else { return nil }
        return SIMD2(abs(dimensions.x), abs(dimensions.y))
    }

    static func objectDimensions(_ dimensions: SIMD3<Float>) -> SIMD3<Float>? {
        guard dimensions.x.isFinite, dimensions.y.isFinite, dimensions.z.isFinite,
              abs(dimensions.x) >= 0.02,
              abs(dimensions.y) >= 0.02,
              abs(dimensions.z) >= 0.02,
              abs(dimensions.x) <= 30,
              abs(dimensions.y) <= 30,
              abs(dimensions.z) <= 30 else { return nil }
        return SIMD3(abs(dimensions.x), abs(dimensions.y), abs(dimensions.z))
    }

    static func isFinite(_ matrix: simd_float4x4) -> Bool {
        let values = [
            matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z, matrix.columns.0.w,
            matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z, matrix.columns.1.w,
            matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z, matrix.columns.2.w,
            matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z, matrix.columns.3.w
        ]
        return values.allSatisfy { $0.isFinite }
    }

    static func isValidAffineTransform(_ matrix: simd_float4x4) -> Bool {
        guard isFinite(matrix),
              abs(matrix.columns.0.w) <= 0.000_1,
              abs(matrix.columns.1.w) <= 0.000_1,
              abs(matrix.columns.2.w) <= 0.000_1,
              abs(matrix.columns.3.w - 1) <= 0.000_1 else { return false }

        let linear = simd_float3x3(columns: (
            SIMD3(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z),
            SIMD3(matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z),
            SIMD3(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z)
        ))
        let determinant = simd_determinant(linear)
        guard determinant.isFinite, abs(determinant) > 0.000_001 else { return false }

        let length0 = simd_length(linear.columns.0)
        let length1 = simd_length(linear.columns.1)
        let length2 = simd_length(linear.columns.2)
        for length in [length0, length1, length2] {
            guard length.isFinite, length >= 0.000_1, length <= 1_000 else { return false }
        }
        let axis0 = linear.columns.0 / length0
        let axis1 = linear.columns.1 / length1
        let axis2 = linear.columns.2 / length2
        guard abs(simd_dot(axis0, axis1)) <= 0.01,
              abs(simd_dot(axis0, axis2)) <= 0.01,
              abs(simd_dot(axis1, axis2)) <= 0.01 else { return false }
        return true
    }

    static func role(for category: CapturedRoom.Object.Category) -> RealityObjectRole {
        switch category {
        case .bathtub: .bathtub
        case .bed: .bed
        case .chair: .chair
        case .dishwasher: .dishwasher
        case .fireplace: .fireplace
        case .oven: .oven
        case .refrigerator: .refrigerator
        case .sink: .sink
        case .sofa: .sofa
        case .stairs: .stairs
        case .storage: .storage
        case .stove: .stove
        case .table: .table
        case .television: .television
        case .toilet: .toilet
        case .washerDryer: .washerDryer
        @unknown default: .unknown
        }
    }
}
