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
        guard let assetName = Self.assetName(for: role),
              Self.isValidTargetDimensions(targetDimensions),
              let prototype = prototype(named: assetName) else { return nil }

        let scale = targetDimensions / prototype.extents
        guard Self.isValidFitScale(scale) else { return nil }

        let clone = prototype.entity.clone(recursive: true)
        clone.name = "cinear.roomAsset.model.\(assetName)"
        applyThemeMaterials(to: clone, role: role, theme: theme)

        // Ayrik bir kok, merkezleme ile non-uniform olcegi birbirinden ayirir.
        // Boylece prototipin kendi rotasyonu ve cocuk hiyerarsisi korunur.
        let fittedRoot = Entity()
        fittedRoot.name = "cinear.roomAsset.fitted.\(assetName)"
        fittedRoot.addChild(clone)
        clone.position -= prototype.center
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
        guard Self.isValidBounds(fittedBounds),
              Self.approximatelyEqual(fittedBounds.center, .zero),
              Self.approximatelyEqual(fittedBounds.extents, targetDimensions) else {
            return nil
        }

        return result
    }
}

private extension BundledRoomRealityAssetProvider {
    static let minimumDimension: Float = 0.02
    static let maximumDimension: Float = 30
    static let minimumAssetExtent: Float = 0.0001
    static let maximumAssetExtent: Float = 10_000
    static let minimumFitScale: Float = 0.005
    static let maximumFitScale: Float = 200

    func prototype(named assetName: String) -> Prototype? {
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
        bundle.url(
            forResource: assetName,
            withExtension: "usdz",
            subdirectory: "RoomAssets"
        ) ?? bundle.url(forResource: assetName, withExtension: "usdz")
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
