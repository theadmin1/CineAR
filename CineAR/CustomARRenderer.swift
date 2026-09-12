import Combine
import RealityKit
import UIKit
import simd

@MainActor
final class CustomARRenderer {
    private static let rootName = "synapmantis.custom-ar.root"
    private static let wallPrefix = "synapmantis.custom-ar.wall."
    private static let doorPrefix = "synapmantis.custom-ar.door."
    private static let ceilingPrefix = "synapmantis.custom-ar.ceiling."
    /// Bury the visual wall body slightly below the drawn base plane so small LiDAR
    /// floor-height errors cannot leave a bright gap at the wall/floor seam.
    private static let floorEmbedDepth: Float = 0.10

    private(set) var rootEntity = AnchorEntity(world: .zero)
    private var contentEntity = Entity()
    private var draftEntity = Entity()
    private weak var installedARView: ARView?
    private var bundledMaterialCache: [String: any Material] = [:]
    private var bundledMaterialLoads: [String: AnyCancellable] = [:]
    private var lastRenderedDesigns: [CustomARDesignRecord] = []

    init() {
        configureRoot()
    }

    var isVisible: Bool {
        get { rootEntity.isEnabled }
        set { rootEntity.isEnabled = newValue }
    }

    func install(in arView: ARView) {
        if installedARView !== arView {
            installedARView?.scene.removeAnchor(rootEntity)
        }
        if rootEntity.scene !== arView.scene {
            rootEntity.scene?.removeAnchor(rootEntity)
            arView.scene.addAnchor(rootEntity)
        }
        installedARView = arView
    }

    func reattachWorldAnchor(in arView: ARView) {
        let wasVisible = rootEntity.isEnabled
        rootEntity.scene?.removeAnchor(rootEntity)
        contentEntity.removeFromParent()
        draftEntity.removeFromParent()
        rootEntity = AnchorEntity(world: .zero)
        rootEntity.name = Self.rootName
        rootEntity.isEnabled = wasVisible
        rootEntity.addChild(contentEntity)
        rootEntity.addChild(draftEntity)
        arView.scene.addAnchor(rootEntity)
        installedARView = arView
    }

    func clear() {
        lastRenderedDesigns = []
        contentEntity.removeFromParent()
        draftEntity.removeFromParent()
        contentEntity = Entity()
        draftEntity = Entity()
        contentEntity.name = "synapmantis.custom-ar.content"
        draftEntity.name = "synapmantis.custom-ar.draft"
        rootEntity.addChild(contentEntity)
        rootEntity.addChild(draftEntity)
    }

    func clearDraft() {
        draftEntity.removeFromParent()
        draftEntity = Entity()
        draftEntity.name = "synapmantis.custom-ar.draft"
        rootEntity.addChild(draftEntity)
    }

    func render(_ designs: [CustomARDesignRecord]) {
        lastRenderedDesigns = designs
        let staging = Entity()
        staging.name = "synapmantis.custom-ar.content"
        for design in designs where design.isValid {
            let designRoot = Entity()
            designRoot.name = "synapmantis.custom-ar.area.\(design.id.uuidString)"
            if design.walls.first?.style.isBackrooms == true,
               let floorEntity = makeBackroomsFloor(for: design) {
                designRoot.addChild(floorEntity)
            }
            for (index, wall) in design.walls.enumerated() {
                if let wallEntity = makeWall(
                    wall,
                    surfaceNormal: design.normal,
                    floorShadowSide: index < design.boundary.count
                        ? CustomARGeometry.interiorSide(
                            of: wall,
                            in: design.boundary.map(\.simd),
                            normal: design.normal
                        )
                        : nil
                ) {
                    designRoot.addChild(wallEntity)
                }
            }
            if let ceiling = design.ceiling,
               let ceilingEntity = makeCeiling(ceiling, for: design) {
                designRoot.addChild(ceilingEntity)
            }
            staging.addChild(designRoot)
        }
        contentEntity.removeFromParent()
        contentEntity = staging
        rootEntity.addChild(contentEntity)
    }

    func showAreaDraft(points: [SIMD3<Float>], closeLoop: Bool) {
        let staging = Entity()
        staging.name = "synapmantis.custom-ar.draft"
        let pointMaterial = SimpleMaterial(color: .systemYellow, roughness: 0.25, isMetallic: false)
        let lineMaterial = SimpleMaterial(color: .systemCyan, roughness: 0.35, isMetallic: false)
        for (index, point) in points.enumerated() {
            let marker = ModelEntity(mesh: .generateSphere(radius: 0.035), materials: [pointMaterial])
            marker.name = "synapmantis.custom-ar.draft.point.\(index)"
            marker.position = point
            staging.addChild(marker)
            if index > 0 {
                staging.addChild(makeLine(from: points[index - 1], to: point, material: lineMaterial))
            }
        }
        if closeLoop, points.count >= 3, let first = points.first, let last = points.last {
            staging.addChild(makeLine(from: last, to: first, material: lineMaterial))
        }
        replaceDraft(with: staging)
    }

    func showWallDraft(start: SIMD3<Float>?, end: SIMD3<Float>? = nil) {
        let staging = Entity()
        staging.name = "synapmantis.custom-ar.draft"
        let material = SimpleMaterial(color: .systemOrange, roughness: 0.25, isMetallic: false)
        if let start {
            let marker = ModelEntity(mesh: .generateSphere(radius: 0.045), materials: [material])
            marker.position = start
            staging.addChild(marker)
            if let end {
                staging.addChild(makeLine(from: start, to: end, thickness: 0.025, material: material))
            }
        }
        replaceDraft(with: staging)
    }

    func setDoor(id: UUID, isOpen: Bool, animated: Bool) {
        guard let hinge = rootEntity.findEntity(named: Self.doorPrefix + id.uuidString) else { return }
        let interiorSide: Float = hinge.position.z >= 0 ? 1 : -1
        var target = hinge.transform
        target.rotation = simd_quatf(
            angle: isOpen
                ? CustomARGeometry.inwardDoorOpenAngle(interiorSide: interiorSide)
                : 0,
            axis: [0, 1, 0]
        )
        if animated, let parent = hinge.parent {
            hinge.move(to: target, relativeTo: parent, duration: 0.38, timingFunction: .easeInOut)
        } else {
            hinge.transform = target
        }
    }

    static func wallID(containing entity: Entity?) -> UUID? {
        identifier(containing: entity, prefix: wallPrefix)
    }

    static func doorID(containing entity: Entity?) -> UUID? {
        identifier(containing: entity, prefix: doorPrefix)
    }

    static func ceilingID(containing entity: Entity?) -> UUID? {
        identifier(containing: entity, prefix: ceilingPrefix)
    }

    static func belongsToCustomAR(_ entity: Entity?) -> Bool {
        var candidate = entity
        while let current = candidate {
            if current.name.hasPrefix("synapmantis.custom-ar.") { return true }
            candidate = current.parent
        }
        return false
    }

    private func configureRoot() {
        rootEntity.name = Self.rootName
        contentEntity.name = "synapmantis.custom-ar.content"
        draftEntity.name = "synapmantis.custom-ar.draft"
        if contentEntity.parent == nil { rootEntity.addChild(contentEntity) }
        if draftEntity.parent == nil { rootEntity.addChild(draftEntity) }
    }

    private func replaceDraft(with staging: Entity) {
        draftEntity.removeFromParent()
        draftEntity = staging
        rootEntity.addChild(draftEntity)
    }

    private func makeWall(
        _ wall: CustomARWallRecord,
        surfaceNormal: SIMD3<Float>,
        floorShadowSide: Float?
    ) -> Entity? {
        let vector = wall.end.simd - wall.start.simd
        let length = simd_length(vector)
        guard length >= 0.30 else { return nil }
        let direction = vector / length
        let up = simd_normalize(surfaceNormal)
        let face = simd_cross(direction, up)
        guard simd_length_squared(face) > 0.000_001 else { return nil }
        let forward = simd_normalize(face)

        let root = Entity()
        root.name = Self.wallPrefix + wall.id.uuidString
        var transform = matrix_identity_float4x4
        transform.columns.0 = SIMD4<Float>(direction, 0)
        transform.columns.1 = SIMD4<Float>(up, 0)
        transform.columns.2 = SIMD4<Float>(forward, 0)
        transform.columns.3 = SIMD4<Float>(wall.start.simd, 1)
        root.transform = Transform(matrix: transform)

        let material = wallMaterial(wall.style)
        let embeddedHeight = wall.height + Self.floorEmbedDepth
        let embeddedCenterY = (wall.height - Self.floorEmbedDepth) * 0.5
        if wall.doors.isEmpty {
            addWallBox(
                to: root, width: length, height: embeddedHeight, depth: wall.thickness,
                center: [length * 0.5, embeddedCenterY, 0], material: material
            )
            addFloorJoinShadow(
                to: root, wall: wall, length: length, side: floorShadowSide
            )
            return root
        }

        let doors = wall.doors.sorted { $0.centerRatio < $1.centerRatio }
        var cursor: Float = 0
        for door in doors {
            let center = door.centerRatio * length
            let openingStart = max(cursor, center - door.width * 0.5)
            let openingEnd = min(length, center + door.width * 0.5)
            if openingStart > cursor + 0.01 {
                let segment = openingStart - cursor
                addWallBox(
                    to: root, width: segment, height: embeddedHeight, depth: wall.thickness,
                    center: [cursor + segment * 0.5, embeddedCenterY, 0], material: material
                )
            }
            let lintelHeight = wall.height - door.height
            if lintelHeight > 0.01 {
                addWallBox(
                    to: root, width: openingEnd - openingStart,
                    height: lintelHeight, depth: wall.thickness,
                    center: [
                        (openingStart + openingEnd) * 0.5,
                        door.height + lintelHeight * 0.5,
                        0
                    ],
                    material: material
                )
            }
            addDoor(
                door,
                openingStart: openingStart,
                wallThickness: wall.thickness,
                interiorSide: floorShadowSide ?? 1,
                wallStyle: wall.style,
                to: root
            )
            cursor = openingEnd
        }
        if cursor < length - 0.01 {
            let segment = length - cursor
            addWallBox(
                to: root, width: segment, height: embeddedHeight, depth: wall.thickness,
                center: [cursor + segment * 0.5, embeddedCenterY, 0], material: material
            )
        }
        addFloorJoinShadow(
            to: root, wall: wall, length: length, side: floorShadowSide
        )
        return root
    }

    private func addFloorJoinShadow(
        to parent: Entity,
        wall: CustomARWallRecord,
        length: Float,
        side: Float?
    ) {
        guard let side else { return }

        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(white: 0.015, alpha: 1))
        material.roughness = .init(floatLiteral: 1)
        material.metallic = .init(floatLiteral: 0)
        material.blending = .transparent(opacity: .init(floatLiteral: 0.11))

        var solidIntervals: [(Float, Float)] = []
        var cursor: Float = 0
        for door in wall.doors.sorted(by: { $0.centerRatio < $1.centerRatio }) {
            let center = min(max(door.centerRatio, 0), 1) * length
            let openingStart = max(cursor, center - door.width * 0.5)
            let openingEnd = min(length, center + door.width * 0.5)
            if openingStart > cursor + 0.02 { solidIntervals.append((cursor, openingStart)) }
            cursor = max(cursor, openingEnd)
        }
        if cursor < length - 0.02 { solidIntervals.append((cursor, length)) }

        // Flattened spheres give every solid segment rounded ends without a texture
        // allocation. Door openings remain clear instead of receiving a dark stripe.
        for (start, end) in solidIntervals {
            let segmentLength = end - start
            let shadow = ModelEntity(
                mesh: .generateSphere(radius: 0.5),
                materials: [material]
            )
            shadow.name = "synapmantis.custom-ar.floor-join-shadow"
            shadow.scale = [max(segmentLength - 0.02, 0.04), 0.006, 0.16]
            shadow.position = [
                (start + end) * 0.5,
                0.004,
                side * (wall.thickness * 0.5 + 0.075)
            ]
            parent.addChild(shadow)
        }
    }

    private func addWallBox(
        to parent: Entity,
        width: Float,
        height: Float,
        depth: Float,
        center: SIMD3<Float>,
        material: any Material
    ) {
        guard width > 0.01, height > 0.01, depth > 0.01 else { return }
        let size = SIMD3<Float>(width, height, depth)
        let box = ModelEntity(
            mesh: makeWallBoxMesh(size: size) ?? .generateBox(size: size),
            materials: [material]
        )
        box.name = "synapmantis.custom-ar.wall.segment"
        box.position = center
        box.collision = CollisionComponent(shapes: [ShapeResource.generateBox(size: size)])
        parent.addChild(box)
    }

    private func addDoor(
        _ door: CustomARDoorRecord,
        openingStart: Float,
        wallThickness: Float,
        interiorSide: Float,
        wallStyle: CustomARWallStyle,
        to parent: Entity
    ) {
        let frameColor = wallStyle.isBackrooms
            ? UIColor(red: 0.28, green: 0.22, blue: 0.10, alpha: 1)
            : UIColor(red: 0.095, green: 0.06, blue: 0.038, alpha: 1)
        let frameMaterial = SimpleMaterial(
            color: frameColor,
            roughness: 0.62,
            isMetallic: false
        )
        let frameWidth: Float = 0.065
        let frameDepth: Float = 0.035
        let frameZ = interiorSide * (wallThickness * 0.5 + frameDepth * 0.5)
        for x in [openingStart, openingStart + door.width] {
            let jamb = ModelEntity(
                mesh: .generateBox(
                    size: [frameWidth, door.height + frameWidth, frameDepth],
                    cornerRadius: 0.006
                ),
                materials: [frameMaterial]
            )
            jamb.name = "synapmantis.custom-ar.door.frame"
            jamb.position = [x, door.height * 0.5, frameZ]
            parent.addChild(jamb)
        }
        let header = ModelEntity(
            mesh: .generateBox(
                size: [door.width + frameWidth * 2, frameWidth, frameDepth],
                cornerRadius: 0.006
            ),
            materials: [frameMaterial]
        )
        header.name = "synapmantis.custom-ar.door.frame"
        header.position = [openingStart + door.width * 0.5, door.height, frameZ]
        parent.addChild(header)

        let hinge = Entity()
        hinge.name = Self.doorPrefix + door.id.uuidString
        hinge.position = [openingStart, 0, interiorSide * wallThickness * 0.54]
        hinge.orientation = simd_quatf(
            angle: door.isOpen
                ? CustomARGeometry.inwardDoorOpenAngle(interiorSide: interiorSide)
                : 0,
            axis: [0, 1, 0]
        )
        let panelSize = SIMD3<Float>(door.width, door.height, max(0.035, wallThickness * 0.45))
        let panelColor = wallStyle.isBackrooms
            ? UIColor(red: 0.43, green: 0.34, blue: 0.16, alpha: 1)
            : UIColor(red: 0.16, green: 0.11, blue: 0.075, alpha: 1)
        let panelMaterial = SimpleMaterial(
            color: panelColor,
            roughness: 0.72,
            isMetallic: false
        )
        let panel = ModelEntity(
            mesh: .generateBox(size: panelSize, cornerRadius: 0.012),
            materials: [panelMaterial]
        )
        panel.name = "synapmantis.custom-ar.door.panel"
        panel.position = [door.width * 0.5, door.height * 0.5, 0]
        panel.collision = CollisionComponent(shapes: [ShapeResource.generateBox(size: panelSize)])
        hinge.addChild(panel)

        let handle = ModelEntity(
            mesh: .generateSphere(radius: 0.028),
            materials: [SimpleMaterial(color: .lightGray, roughness: 0.22, isMetallic: true)]
        )
        handle.name = "synapmantis.custom-ar.door.handle"
        handle.position = [
            door.width * 0.32,
            door.height * 0.02,
            interiorSide * panelSize.z * 0.58
        ]
        panel.addChild(handle)

        // Shallow raised panels make the built-in door read as an actual asset
        // without another texture decode or a large mesh cost.
        let trimColor = wallStyle.isBackrooms
            ? UIColor(red: 0.37, green: 0.29, blue: 0.13, alpha: 1)
            : UIColor(red: 0.12, green: 0.075, blue: 0.045, alpha: 1)
        let trimMaterial = SimpleMaterial(
            color: trimColor,
            roughness: 0.66,
            isMetallic: false
        )
        for centerY in [door.height * 0.30, door.height * 0.70] {
            let inset = ModelEntity(
                mesh: .generateBox(
                    size: [door.width * 0.66, door.height * 0.29, 0.012],
                    cornerRadius: 0.008
                ),
                materials: [trimMaterial]
            )
            inset.name = "synapmantis.custom-ar.door.detail"
            inset.position = [
                0,
                centerY - door.height * 0.5,
                interiorSide * (panelSize.z * 0.5 + 0.006)
            ]
            panel.addChild(inset)
        }
        parent.addChild(hinge)
    }

    private func makeBackroomsFloor(for design: CustomARDesignRecord) -> ModelEntity? {
        let points = design.boundary.map { $0.simd + design.normal * 0.004 }
        let indices = CustomARGeometry.triangulatedIndices(for: points, normal: design.normal)
        guard indices.count >= 3 else { return nil }

        var descriptor = MeshDescriptor(name: "synapmantis.custom-ar.backrooms.floor.mesh")
        descriptor.positions = MeshBuffers.Positions(points)
        descriptor.normals = MeshBuffers.Normals(
            Array(repeating: design.normal, count: points.count)
        )
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(
            planarTextureCoordinates(
                for: points,
                normal: design.normal,
                tileMeters: 1.50
            )
        )
        descriptor.primitives = .triangles(indices)
        guard let mesh = try? MeshResource.generate(from: [descriptor]) else { return nil }
        let fallback = SimpleMaterial(
            color: UIColor(red: 0.29, green: 0.28, blue: 0.17, alpha: 1),
            roughness: 0.98,
            isMetallic: false
        )
        let material = bundledMaterial(named: "backrooms_yasu_floor_01", fallback: fallback)
        let floor = ModelEntity(mesh: mesh, materials: [material])
        floor.name = "synapmantis.custom-ar.backrooms.floor"
        // Intentionally no collision: the carpet must not steal taps from doors or
        // from ARKit's physical placement surface underneath it.
        return floor
    }

    private func makeCeiling(
        _ ceiling: CustomARCeilingRecord,
        for design: CustomARDesignRecord
    ) -> ModelEntity? {
        let basePoints = design.boundary.map { $0.simd + design.normal * ceiling.height }
        let topFacingIndices = CustomARGeometry.triangulatedIndices(
            for: basePoints,
            normal: design.normal
        )
        guard topFacingIndices.count >= 3 else { return nil }

        var undersideIndices: [UInt32] = []
        undersideIndices.reserveCapacity(topFacingIndices.count)
        for index in stride(from: 0, to: topFacingIndices.count, by: 3) {
            undersideIndices.append(contentsOf: [
                topFacingIndices[index], topFacingIndices[index + 2], topFacingIndices[index + 1]
            ])
        }
        var descriptor = MeshDescriptor(name: "synapmantis.custom-ar.ceiling.mesh")
        descriptor.positions = MeshBuffers.Positions(basePoints)
        descriptor.normals = MeshBuffers.Normals(
            Array(repeating: -design.normal, count: basePoints.count)
        )
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(
            planarTextureCoordinates(
                for: basePoints,
                normal: design.normal,
                tileMeters: 1.20
            )
        )
        descriptor.primitives = .triangles(undersideIndices)
        guard let mesh = try? MeshResource.generate(from: [descriptor]) else { return nil }
        let entity = ModelEntity(mesh: mesh, materials: [ceilingMaterial(ceiling.style)])
        entity.name = Self.ceilingPrefix + design.id.uuidString

        var collisionShapes: [ShapeResource] = []
        let lift = design.normal * ceiling.thickness
        for index in stride(from: 0, to: topFacingIndices.count, by: 3) {
            let a = basePoints[Int(topFacingIndices[index])]
            let b = basePoints[Int(topFacingIndices[index + 1])]
            let c = basePoints[Int(topFacingIndices[index + 2])]
            collisionShapes.append(ShapeResource.generateConvex(from: [
                a, b, c, a + lift, b + lift, c + lift
            ]))
        }
        entity.collision = CollisionComponent(shapes: collisionShapes)
        return entity
    }

    private func wallMaterial(_ style: CustomARWallStyle) -> any Material {
        switch style {
        case .studioWhite:
            SimpleMaterial(color: UIColor(white: 0.93, alpha: 1), roughness: 0.78, isMetallic: false)
        case .concrete:
            SimpleMaterial(color: UIColor(white: 0.43, alpha: 1), roughness: 0.94, isMetallic: false)
        case .brick:
            SimpleMaterial(
                color: UIColor(red: 0.42, green: 0.16, blue: 0.095, alpha: 1),
                roughness: 0.91,
                isMetallic: false
            )
        default:
            let fallback = SimpleMaterial(
                color: UIColor(red: 0.57, green: 0.50, blue: 0.25, alpha: 1),
                roughness: 0.96,
                isMetallic: false
            )
            guard let assetName = style.backroomsWallpaperAssetName else { return fallback }
            return bundledMaterial(named: assetName, fallback: fallback)
        }
    }

    private func ceilingMaterial(_ style: CustomARWallStyle) -> any Material {
        guard style.isBackrooms else { return wallMaterial(style) }
        let fallback = SimpleMaterial(
            color: UIColor(red: 0.72, green: 0.69, blue: 0.52, alpha: 1),
            roughness: 0.95,
            isMetallic: false
        )
        guard let assetName = style.backroomsCeilingAssetName else { return fallback }
        return bundledMaterial(named: assetName, fallback: fallback)
    }

    private func planarTextureCoordinates(
        for points: [SIMD3<Float>],
        normal: SIMD3<Float>,
        tileMeters: Float
    ) -> [SIMD2<Float>] {
        guard let origin = points.first, points.count > 1, tileMeters > 0 else {
            return Array(repeating: .zero, count: points.count)
        }
        var tangent = points[1] - origin
        tangent -= normal * simd_dot(tangent, normal)
        if simd_length_squared(tangent) < 0.000_001 {
            tangent = abs(normal.y) < 0.9
                ? simd_cross(normal, SIMD3<Float>(0, 1, 0))
                : simd_cross(normal, SIMD3<Float>(1, 0, 0))
        }
        tangent = simd_normalize(tangent)
        let bitangent = simd_normalize(simd_cross(normal, tangent))
        return points.map {
            let offset = $0 - origin
            return [simd_dot(offset, tangent) / tileMeters,
                    simd_dot(offset, bitangent) / tileMeters]
        }
    }

    private func makeWallBoxMesh(size: SIMD3<Float>) -> MeshResource? {
        let half = size * 0.5
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var coordinates: [SIMD2<Float>] = []
        var indices: [UInt32] = []

        func appendFace(
            _ corners: [SIMD3<Float>],
            normal: SIMD3<Float>,
            uv: [SIMD2<Float>]
        ) {
            let start = UInt32(positions.count)
            positions.append(contentsOf: corners)
            normals.append(contentsOf: Array(repeating: normal, count: 4))
            coordinates.append(contentsOf: uv)
            indices.append(contentsOf: [start, start + 1, start + 2, start, start + 2, start + 3])
        }

        let x = size.x / 1.25
        let y = size.y / 1.25
        let z = size.z / 1.25
        appendFace(
            [[-half.x, -half.y, half.z], [half.x, -half.y, half.z],
             [half.x, half.y, half.z], [-half.x, half.y, half.z]],
            normal: [0, 0, 1], uv: [[0, 0], [x, 0], [x, y], [0, y]]
        )
        appendFace(
            [[half.x, -half.y, -half.z], [-half.x, -half.y, -half.z],
             [-half.x, half.y, -half.z], [half.x, half.y, -half.z]],
            normal: [0, 0, -1], uv: [[0, 0], [x, 0], [x, y], [0, y]]
        )
        appendFace(
            [[-half.x, -half.y, -half.z], [-half.x, -half.y, half.z],
             [-half.x, half.y, half.z], [-half.x, half.y, -half.z]],
            normal: [-1, 0, 0], uv: [[0, 0], [z, 0], [z, y], [0, y]]
        )
        appendFace(
            [[half.x, -half.y, half.z], [half.x, -half.y, -half.z],
             [half.x, half.y, -half.z], [half.x, half.y, half.z]],
            normal: [1, 0, 0], uv: [[0, 0], [z, 0], [z, y], [0, y]]
        )
        appendFace(
            [[-half.x, half.y, half.z], [half.x, half.y, half.z],
             [half.x, half.y, -half.z], [-half.x, half.y, -half.z]],
            normal: [0, 1, 0], uv: [[0, 0], [x, 0], [x, z], [0, z]]
        )
        appendFace(
            [[-half.x, -half.y, -half.z], [half.x, -half.y, -half.z],
             [half.x, -half.y, half.z], [-half.x, -half.y, half.z]],
            normal: [0, -1, 0], uv: [[0, 0], [x, 0], [x, z], [0, z]]
        )

        var descriptor = MeshDescriptor(name: "synapmantis.custom-ar.wall.box")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(coordinates)
        descriptor.primitives = .triangles(indices)
        return try? MeshResource.generate(from: [descriptor])
    }

    private func bundledMaterial(
        named assetName: String,
        fallback: SimpleMaterial
    ) -> any Material {
        if let cached = bundledMaterialCache[assetName] { return cached }
        guard bundledMaterialLoads[assetName] == nil,
              let url = bundledAssetURL(named: assetName) else {
            return fallback
        }
        bundledMaterialLoads[assetName] = Entity.loadAsync(contentsOf: url)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    self.bundledMaterialLoads.removeValue(forKey: assetName)
                    if case .failure = completion {
                        // Cache the lightweight fallback for this session so a bad
                        // package can never create a repeated load/render loop.
                        self.bundledMaterialCache[assetName] = fallback
                    }
                },
                receiveValue: { [weak self] source in
                    guard let self else { return }
                    self.bundledMaterialCache[assetName] =
                        self.firstMaterial(in: source) ?? fallback
                    // The initial frame used the fallback. Replace it atomically as
                    // soon as the PBR material is decoded off the render path.
                    self.render(self.lastRenderedDesigns)
                }
            )
        return fallback
    }

    private func bundledAssetURL(named assetName: String) -> URL? {
        if let url = Bundle.main.url(
            forResource: assetName,
            withExtension: "usdz",
            subdirectory: "RoomAssets"
        ) ?? Bundle.main.url(forResource: assetName, withExtension: "usdz") {
            return url
        }
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        let explicitURL = resourceURL
            .appendingPathComponent("RoomAssets", isDirectory: true)
            .appendingPathComponent(assetName)
            .appendingPathExtension("usdz")
        return FileManager.default.fileExists(atPath: explicitURL.path) ? explicitURL : nil
    }

    private func firstMaterial(in entity: Entity) -> (any Material)? {
        if let material = entity.components[ModelComponent.self]?.materials.first {
            return material
        }
        for child in entity.children {
            if let material = firstMaterial(in: child) { return material }
        }
        return nil
    }

    private func makeLine(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        thickness: Float = 0.018,
        material: SimpleMaterial
    ) -> ModelEntity {
        let vector = end - start
        let length = max(simd_length(vector), 0.001)
        let line = ModelEntity(
            mesh: .generateBox(size: [length, thickness, thickness], cornerRadius: thickness * 0.35),
            materials: [material]
        )
        line.name = "synapmantis.custom-ar.guide"
        line.position = (start + end) * 0.5
        line.orientation = simd_quatf(from: [1, 0, 0], to: vector / length)
        return line
    }

    private static func identifier(containing entity: Entity?, prefix: String) -> UUID? {
        var candidate = entity
        while let current = candidate {
            if current.name.hasPrefix(prefix) {
                let value = String(current.name.dropFirst(prefix.count))
                if let id = UUID(uuidString: value) { return id }
            }
            candidate = current.parent
        }
        return nil
    }
}
