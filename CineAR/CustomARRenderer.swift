import RealityKit
import UIKit
import simd

@MainActor
final class CustomARRenderer {
    private static let rootName = "synapmantis.custom-ar.root"
    private static let wallPrefix = "synapmantis.custom-ar.wall."
    private static let doorPrefix = "synapmantis.custom-ar.door."
    private static let ceilingPrefix = "synapmantis.custom-ar.ceiling."

    private(set) var rootEntity = AnchorEntity(world: .zero)
    private var contentEntity = Entity()
    private var draftEntity = Entity()
    private weak var installedARView: ARView?

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
        let staging = Entity()
        staging.name = "synapmantis.custom-ar.content"
        for design in designs where design.isValid {
            let designRoot = Entity()
            designRoot.name = "synapmantis.custom-ar.area.\(design.id.uuidString)"
            addBoundary(design, to: designRoot)
            for wall in design.walls {
                if let wallEntity = makeWall(wall, surfaceNormal: design.normal) {
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
        var target = hinge.transform
        target.rotation = simd_quatf(
            angle: isOpen ? -.pi * 0.52 : 0,
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

    private func addBoundary(_ design: CustomARDesignRecord, to parent: Entity) {
        let points = design.boundary.map(\.simd)
        guard points.count >= 3 else { return }
        let material = SimpleMaterial(
            color: UIColor.systemCyan.withAlphaComponent(0.82),
            roughness: 0.30,
            isMetallic: false
        )
        let lift = design.normal * 0.012
        for index in points.indices {
            parent.addChild(makeLine(
                from: points[index] + lift,
                to: points[(index + 1) % points.count] + lift,
                thickness: 0.014,
                material: material
            ))
        }
    }

    private func makeWall(
        _ wall: CustomARWallRecord,
        surfaceNormal: SIMD3<Float>
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
        if wall.doors.isEmpty {
            addWallBox(
                to: root, width: length, height: wall.height, depth: wall.thickness,
                center: [length * 0.5, wall.height * 0.5, 0], material: material
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
                    to: root, width: segment, height: wall.height, depth: wall.thickness,
                    center: [cursor + segment * 0.5, wall.height * 0.5, 0], material: material
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
                door, openingStart: openingStart, wallThickness: wall.thickness, to: root
            )
            cursor = openingEnd
        }
        if cursor < length - 0.01 {
            let segment = length - cursor
            addWallBox(
                to: root, width: segment, height: wall.height, depth: wall.thickness,
                center: [cursor + segment * 0.5, wall.height * 0.5, 0], material: material
            )
        }
        return root
    }

    private func addWallBox(
        to parent: Entity,
        width: Float,
        height: Float,
        depth: Float,
        center: SIMD3<Float>,
        material: SimpleMaterial
    ) {
        guard width > 0.01, height > 0.01, depth > 0.01 else { return }
        let size = SIMD3<Float>(width, height, depth)
        let box = ModelEntity(
            mesh: .generateBox(size: size, cornerRadius: min(depth * 0.08, 0.008)),
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
        to parent: Entity
    ) {
        let hinge = Entity()
        hinge.name = Self.doorPrefix + door.id.uuidString
        hinge.position = [openingStart, 0, wallThickness * 0.54]
        hinge.orientation = simd_quatf(
            angle: door.isOpen ? -.pi * 0.52 : 0,
            axis: [0, 1, 0]
        )
        let panelSize = SIMD3<Float>(door.width, door.height, max(0.035, wallThickness * 0.45))
        let panel = ModelEntity(
            mesh: .generateBox(size: panelSize, cornerRadius: 0.012),
            materials: [SimpleMaterial(
                color: UIColor(red: 0.16, green: 0.11, blue: 0.075, alpha: 1),
                roughness: 0.72,
                isMetallic: false
            )]
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
        handle.position = [door.width * 0.82, door.height * 0.52, panelSize.z * 0.58]
        panel.addChild(handle)
        parent.addChild(hinge)
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
        descriptor.primitives = .triangles(undersideIndices)
        guard let mesh = try? MeshResource.generate(from: [descriptor]) else { return nil }
        let entity = ModelEntity(mesh: mesh, materials: [wallMaterial(ceiling.style)])
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

    private func wallMaterial(_ style: CustomARWallStyle) -> SimpleMaterial {
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
        }
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
