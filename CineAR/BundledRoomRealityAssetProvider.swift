import Foundation
import RealityKit

/// `RoomAssets` klasorundeki hazir USDZ modellerini RoomPlan rollerine baglar.
///
/// Provider bir varligi ilk kullanimda senkron olarak yukler ve prototipi bellekte
/// tutar. Her oda nesnesi icin prototipin recursive klonu uretilir; boyut ya da
/// dosya dogrulamasi basarisiz olursa renderer kendi prosedurel modeline doner.
@MainActor
final class BundledRoomRealityAssetProvider: RoomRealityAssetProviding {
    private struct Prototype {
        let entity: Entity
        let center: SIMD3<Float>
        let extents: SIMD3<Float>
    }

    private let bundle: Bundle
    private var prototypes: [String: Prototype] = [:]
    private var unavailableAssetNames = Set<String>()

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func makeEntity(
        for role: RealityObjectRole,
        theme: RealityTheme,
        targetDimensions: SIMD3<Float>
    ) -> Entity? {
        guard Self.isValidTargetDimensions(targetDimensions) else { return nil }
        guard let assetName = Self.assetName(for: role),
              let prototype = prototype(named: assetName) else {
            return makeFallbackEntity(for: role, theme: theme, size: targetDimensions)
        }

        let scale = targetDimensions / prototype.extents
        guard Self.isValidFitScale(scale) else {
            return makeFallbackEntity(for: role, theme: theme, size: targetDimensions)
        }

        let clone = prototype.entity.clone(recursive: true)
        clone.name = "cinear.roomAsset.model.\(assetName)"
        applyThemeMaterials(to: clone, role: role, theme: theme)

        // Ayrik bir kok, merkezleme ile non-uniform olcegi birbirinden ayirir.
        // Boylece prototipin kendi rotasyonu ve cocuk hiyerarsisi korunur.
        let centeredRoot = Entity()
        centeredRoot.name = "cinear.roomAsset.centered.\(assetName)"
        centeredRoot.addChild(clone)
        centeredRoot.position = -prototype.center

        let fittedRoot = Entity()
        fittedRoot.name = "cinear.roomAsset.fitted.\(assetName)"
        fittedRoot.addChild(centeredRoot)
        fittedRoot.scale = scale

        let result = Entity()
        result.name = "cinear.roomAsset.\(assetName)"
        result.addChild(fittedRoot)

        // USDZ hiyerarsisindeki beklenmeyen transformlarin bozuk/sonsuz bir
        // sahneye sizmasini engelle; tam uyum saglanmiyorsa prosedurel fallback.
        let fittedBounds = result.visualBounds(
            recursive: true,
            relativeTo: result,
            excludeInactive: true
        )
        guard Self.isValidBounds(fittedBounds) else {
            return makeFallbackEntity(for: role, theme: theme, size: targetDimensions)
        }

        return result
    }

    /// Loads a catalog model without replacing its authored PBR materials.
    /// A uniform fit preserves the real object's proportions while keeping its
    /// largest dimension inside the verified metre-sized mobile AR envelope.
    func makePhotorealEntity(
        assetName: String,
        maximumDimensions: SIMD3<Float>
    ) -> Entity? {
        guard Self.isValidTargetDimensions(maximumDimensions),
              let prototype = prototype(named: assetName) else { return nil }

        let ratios = maximumDimensions / prototype.extents
        let uniformScale = min(ratios.x, ratios.y, ratios.z)
        guard uniformScale.isFinite,
              uniformScale >= Self.minimumFitScale,
              uniformScale <= Self.maximumFitScale else { return nil }

        let clone = prototype.entity.clone(recursive: true)
        clone.name = "cinear.photoreal.model.\(assetName)"

        let centeredRoot = Entity()
        centeredRoot.name = "cinear.photoreal.centered.\(assetName)"
        centeredRoot.addChild(clone)
        centeredRoot.position = -prototype.center

        let fittedRoot = Entity()
        fittedRoot.name = "cinear.photoreal.fitted.\(assetName)"
        fittedRoot.addChild(centeredRoot)
        fittedRoot.scale = SIMD3(repeating: uniformScale)

        let result = Entity()
        result.name = "cinear.photoreal.\(assetName)"
        result.addChild(fittedRoot)
        let bounds = result.visualBounds(
            recursive: true,
            relativeTo: result,
            excludeInactive: true
        )
        return Self.isValidBounds(bounds) ? result : nil
    }
}

private extension BundledRoomRealityAssetProvider {
    static let minimumDimension: Float = 0.02
    static let maximumDimension: Float = 30
    static let minimumAssetExtent: Float = 0.0001
    static let maximumAssetExtent: Float = 10_000
    static let minimumFitScale: Float = 0.005
    static let maximumFitScale: Float = 200

    private func prototype(named assetName: String) -> Prototype? {
        if let cached = prototypes[assetName] { return cached }
        guard !unavailableAssetNames.contains(assetName),
              let url = assetURL(named: assetName) else {
            unavailableAssetNames.insert(assetName)
            return nil
        }

        do {
            let entity = try Entity.load(contentsOf: url)
            let measurementRoot = Entity()
            measurementRoot.addChild(entity)
            let bounds = measurementRoot.visualBounds(
                recursive: true,
                relativeTo: measurementRoot,
                excludeInactive: true
            )
            entity.removeFromParent()

            guard Self.isValidBounds(bounds) else {
                unavailableAssetNames.insert(assetName)
                return nil
            }

            let prototype = Prototype(
                entity: entity,
                center: bounds.center,
                extents: bounds.extents
            )
            prototypes[assetName] = prototype
            return prototype
        } catch {
            unavailableAssetNames.insert(assetName)
            return nil
        }
    }

    func assetURL(named assetName: String) -> URL? {
        // Blue-folder reference dizin yapisini bundle icinde korur. Kok aramasi,
        // klasor ileride normal bir Xcode grubuna cevrilirse de uyumluluk saglar.
        if let bundledURL = bundle.url(
            forResource: assetName,
            withExtension: "usdz",
            subdirectory: "RoomAssets"
        ) ?? bundle.url(forResource: assetName, withExtension: "usdz") {
            return bundledURL
        }

        guard let resourceURL = bundle.resourceURL else { return nil }
        let explicitURL = resourceURL
            .appendingPathComponent("RoomAssets", isDirectory: true)
            .appendingPathComponent(assetName)
            .appendingPathExtension("usdz")
        return FileManager.default.fileExists(atPath: explicitURL.path) ? explicitURL : nil
    }

    func makeFallbackEntity(
        for role: RealityObjectRole,
        theme: RealityTheme,
        size: SIMD3<Float>
    ) -> Entity {
        let root = Entity()
        root.name = "cinear.roomAsset.fallback.\(String(describing: role))"
        let recipes = theme.objectRecipes(for: role)
        let primary = recipes.primary.makeMaterial()
        let secondary = recipes.secondary.makeMaterial()
        let detail = recipes.detail.makeMaterial()

        switch role {
        case .table:
            let topHeight = max(size.y * 0.10, 0.04)
            addBox(to: root, size: [size.x, topHeight, size.z], position: [0, size.y * 0.45, 0], material: primary)
            let leg = max(min(size.x, size.z) * 0.08, 0.035)
            for x in [-size.x * 0.40, size.x * 0.40] {
                for z in [-size.z * 0.38, size.z * 0.38] {
                    addBox(to: root, size: [leg, size.y * 0.88, leg], position: [x, -size.y * 0.06, z], material: detail)
                }
            }
        case .chair:
            addBox(to: root, size: [size.x * 0.88, size.y * 0.12, size.z * 0.82], position: [0, -size.y * 0.04, 0], material: primary)
            addBox(to: root, size: [size.x * 0.88, size.y * 0.48, size.z * 0.10], position: [0, size.y * 0.26, -size.z * 0.36], material: primary)
            let leg = max(min(size.x, size.z) * 0.09, 0.025)
            for x in [-size.x * 0.34, size.x * 0.34] {
                for z in [-size.z * 0.30, size.z * 0.30] {
                    addBox(to: root, size: [leg, size.y * 0.44, leg], position: [x, -size.y * 0.28, z], material: detail)
                }
            }
        case .sofa:
            addBox(to: root, size: [size.x, size.y * 0.42, size.z * 0.88], position: [0, -size.y * 0.25, 0], material: primary)
            addBox(to: root, size: [size.x * 0.88, size.y * 0.58, size.z * 0.18], position: [0, size.y * 0.18, -size.z * 0.38], material: secondary)
            for x in [-size.x * 0.46, size.x * 0.46] {
                addBox(to: root, size: [size.x * 0.08, size.y * 0.62, size.z * 0.82], position: [x, -size.y * 0.10, 0], material: primary)
            }
        case .bed:
            addBox(to: root, size: [size.x, size.y * 0.28, size.z], position: [0, -size.y * 0.26, 0], material: detail)
            addBox(to: root, size: [size.x * 0.94, size.y * 0.30, size.z * 0.92], position: [0, size.y * 0.02, size.z * 0.02], material: secondary)
            addBox(to: root, size: [size.x, size.y * 0.82, size.z * 0.10], position: [0, size.y * 0.08, -size.z * 0.45], material: primary)
        case .storage:
            addBox(to: root, size: size, position: .zero, material: primary)
            for y in [-size.y * 0.25, 0, size.y * 0.25] {
                addBox(to: root, size: [size.x * 0.90, max(size.y * 0.025, 0.025), size.z * 0.12], position: [0, y, size.z * 0.46], material: secondary)
            }
        case .television:
            addBox(to: root, size: [size.x, size.y * 0.82, size.z * 0.32], position: [0, size.y * 0.08, 0], material: detail)
            addBox(to: root, size: [size.x * 0.92, size.y * 0.70, size.z * 0.08], position: [0, size.y * 0.08, size.z * 0.18], material: secondary)
            addBox(to: root, size: [size.x * 0.32, size.y * 0.14, size.z], position: [0, -size.y * 0.43, 0], material: primary)
        case .refrigerator, .dishwasher, .oven, .stove, .washerDryer:
            addBox(to: root, size: size, position: .zero, material: primary)
            addBox(to: root, size: [size.x * 0.88, size.y * 0.72, max(size.z * 0.025, 0.02)], position: [0, -size.y * 0.04, size.z * 0.51], material: secondary)
            addBox(to: root, size: [size.x * 0.65, max(size.y * 0.05, 0.025), max(size.z * 0.035, 0.025)], position: [0, size.y * 0.37, size.z * 0.53], material: detail)
        case .bathtub:
            addBox(to: root, size: [size.x, size.y * 0.52, size.z], position: [0, -size.y * 0.24, 0], material: primary)
            addBox(to: root, size: [size.x * 0.82, size.y * 0.20, size.z * 0.68], position: [0, size.y * 0.04, 0], material: secondary)
        case .sink:
            addBox(to: root, size: [size.x, size.y * 0.30, size.z], position: [0, size.y * 0.30, 0], material: secondary)
            addBox(to: root, size: [size.x * 0.42, size.y * 0.68, size.z * 0.42], position: [0, -size.y * 0.16, 0], material: primary)
        case .toilet:
            addBox(to: root, size: [size.x, size.y * 0.36, size.z * 0.75], position: [0, -size.y * 0.22, size.z * 0.10], material: secondary)
            addBox(to: root, size: [size.x * 0.82, size.y * 0.58, size.z * 0.30], position: [0, size.y * 0.20, -size.z * 0.32], material: primary)
        case .stairs:
            let steps = 6
            for index in 0..<steps {
                let fraction = Float(index + 1) / Float(steps)
                addBox(
                    to: root,
                    size: [size.x, size.y * fraction, size.z / Float(steps)],
                    position: [0, -size.y * 0.5 + size.y * fraction * 0.5, -size.z * 0.5 + size.z * (Float(index) + 0.5) / Float(steps)],
                    material: primary
                )
            }
        case .fireplace, .unknown:
            addBox(to: root, size: size, position: .zero, material: primary)
        }
        return root
    }

    func addBox(
        to parent: Entity,
        size: SIMD3<Float>,
        position: SIMD3<Float>,
        material: PhysicallyBasedMaterial
    ) {
        let safeSize = SIMD3<Float>(
            max(size.x, 0.01),
            max(size.y, 0.01),
            max(size.z, 0.01)
        )
        let entity = ModelEntity(
            mesh: .generateBox(size: safeSize, cornerRadius: min(safeSize.x, safeSize.z) * 0.025),
            materials: [material]
        )
        entity.position = position
        parent.addChild(entity)
    }

    func applyThemeMaterials(
        to entity: Entity,
        role: RealityObjectRole,
        theme: RealityTheme
    ) {
        let recipes = theme.objectRecipes(for: role)
        let palette: [PhysicallyBasedMaterial] = [
            recipes.primary.makeMaterial(),
            recipes.secondary.makeMaterial(),
            recipes.detail.makeMaterial()
        ]
        applyThemeMaterialsRecursively(to: entity, palette: palette)
    }

    func applyThemeMaterialsRecursively(
        to entity: Entity,
        palette: [PhysicallyBasedMaterial]
    ) {
        if var model = entity.components[ModelComponent.self],
           !model.materials.isEmpty {
            model.materials = model.materials.indices.map { palette[$0 % palette.count] }
            entity.components.set(model)
        }
        for child in entity.children {
            applyThemeMaterialsRecursively(to: child, palette: palette)
        }
    }

    static func assetName(for role: RealityObjectRole) -> String? {
        switch role {
        case .bathtub: "bathtub"
        case .bed: "bedDouble"
        case .chair: "chairModernCushion"
        case .oven: "kitchenStove"
        case .refrigerator: "kitchenFridge"
        case .sink: "bathroomSink"
        case .sofa: "loungeDesignSofa"
        case .stairs: "stairs"
        case .storage: "bookcaseClosedWide"
        case .stove: "kitchenStoveElectric"
        case .table: "table"
        case .television: "televisionModern"
        case .toilet: "toilet"
        case .washerDryer: "washerDryerStacked"
        case .dishwasher, .fireplace, .unknown: nil
        }
    }

    static func isValidTargetDimensions(_ value: SIMD3<Float>) -> Bool {
        components(of: value).allSatisfy {
            $0.isFinite && $0 >= minimumDimension && $0 <= maximumDimension
        }
    }

    static func isValidBounds(_ bounds: BoundingBox) -> Bool {
        components(of: bounds.center).allSatisfy { $0.isFinite }
            && components(of: bounds.extents).allSatisfy {
                $0.isFinite && $0 >= minimumAssetExtent && $0 <= maximumAssetExtent
            }
    }

    static func isValidFitScale(_ value: SIMD3<Float>) -> Bool {
        components(of: value).allSatisfy {
            $0.isFinite && $0 >= minimumFitScale && $0 <= maximumFitScale
        }
    }

    static func approximatelyEqual(
        _ lhs: SIMD3<Float>,
        _ rhs: SIMD3<Float>
    ) -> Bool {
        zip(components(of: lhs), components(of: rhs)).allSatisfy { left, right in
            let tolerance = max(0.001, max(abs(left), abs(right)) * 0.005)
            return abs(left - right) <= tolerance
        }
    }

    static func components(of value: SIMD3<Float>) -> [Float] {
        [value.x, value.y, value.z]
    }
}
