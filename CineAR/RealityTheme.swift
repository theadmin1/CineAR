import RealityKit
import UIKit

/// Kullanıcının tek dokunuşla seçebileceği hazır oda görünümleri.
enum RealityThemeID: String, CaseIterable, Codable, Identifiable, Sendable {
    case modern
    case soundStage
    case sciFi
    case warmLoft

    var id: String { rawValue }
}

enum RealitySurfaceRole: Equatable, Sendable {
    case wall
    case floor
    case ceiling
    case door
    case window
    case opening
    case trim
}

enum RealityObjectRole: Equatable, Sendable {
    case bathtub
    case bed
    case chair
    case dishwasher
    case fireplace
    case oven
    case refrigerator
    case sink
    case sofa
    case stairs
    case storage
    case stove
    case table
    case television
    case toilet
    case washerDryer
    case unknown
}

/// Texture gerektirmeyen, hızlı oluşturulan bir PBR materyal tarifi.
/// Daha sonra aynı rollere USDZ içindeki dokulu materyaller bağlanabilir.
struct RealityMaterialRecipe: Sendable {
    let red: Float
    let green: Float
    let blue: Float
    let alpha: Float
    let roughness: Float
    let metallic: Float

    init(
        _ red: Float,
        _ green: Float,
        _ blue: Float,
        alpha: Float = 1,
        roughness: Float,
        metallic: Float = 0
    ) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
        self.roughness = roughness
        self.metallic = metallic
    }

    @MainActor
    func makeMaterial() -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        let color = UIColor(
            red: CGFloat(clamped(red)),
            green: CGFloat(clamped(green)),
            blue: CGFloat(clamped(blue)),
            alpha: CGFloat(clamped(alpha))
        )
        material.baseColor = .init(tint: color)
        material.roughness = .init(floatLiteral: clamped(roughness))
        material.metallic = .init(floatLiteral: clamped(metallic))
        if alpha < 0.999 {
            material.blending = .transparent(
                opacity: .init(floatLiteral: clamped(alpha))
            )
        }
        return material
    }

    private func clamped(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

struct RealityTheme: Identifiable, Sendable {
    let id: RealityThemeID
    let title: String
    let subtitle: String
    let symbolName: String

    let wall: RealityMaterialRecipe
    let floor: RealityMaterialRecipe
    let ceiling: RealityMaterialRecipe
    let door: RealityMaterialRecipe
    let glass: RealityMaterialRecipe
    let opening: RealityMaterialRecipe
    let trim: RealityMaterialRecipe
    let furniturePrimary: RealityMaterialRecipe
    let furnitureSecondary: RealityMaterialRecipe
    let furnitureDetail: RealityMaterialRecipe
    let screen: RealityMaterialRecipe

    /// Taranan düzlemlerin kamerayı örtebilmesi için küçük bir fiziksel kalınlık.
    let surfaceThickness: Float

    func materialRecipe(for role: RealitySurfaceRole) -> RealityMaterialRecipe {
        switch role {
        case .wall: wall
        case .floor: floor
        case .ceiling: ceiling
        case .door: door
        case .window: glass
        case .opening: opening
        case .trim: trim
        }
    }

    func objectRecipes(
        for role: RealityObjectRole
    ) -> (
        primary: RealityMaterialRecipe,
        secondary: RealityMaterialRecipe,
        detail: RealityMaterialRecipe
    ) {
        switch role {
        case .television, .fireplace:
            (furnitureDetail, screen, trim)
        case .refrigerator, .dishwasher, .oven, .stove, .washerDryer:
            (furnitureSecondary, trim, furnitureDetail)
        case .bathtub, .sink, .toilet:
            (furnitureSecondary, furniturePrimary, trim)
        case .stairs:
            (floor, furnitureSecondary, trim)
        case .bed, .chair, .sofa, .storage, .table, .unknown:
            (furniturePrimary, furnitureSecondary, furnitureDetail)
        }
    }
}

enum RealityThemeCatalog {
    static let modern = RealityTheme(
        id: .modern,
        title: "Modern",
        subtitle: "Açık taş, doğal ahşap ve mat siyah ayrıntılar",
        symbolName: "square.grid.2x2.fill",
        wall: .init(0.78, 0.80, 0.79, roughness: 0.82),
        floor: .init(0.30, 0.19, 0.11, roughness: 0.68),
        ceiling: .init(0.88, 0.89, 0.87, roughness: 0.90),
        door: .init(0.21, 0.12, 0.07, roughness: 0.62),
        glass: .init(0.42, 0.72, 0.84, alpha: 0.28, roughness: 0.08),
        opening: .init(0.035, 0.045, 0.055, roughness: 0.88),
        trim: .init(0.055, 0.06, 0.065, roughness: 0.34, metallic: 0.52),
        furniturePrimary: .init(0.16, 0.30, 0.32, roughness: 0.72),
        furnitureSecondary: .init(0.86, 0.84, 0.78, roughness: 0.76),
        furnitureDetail: .init(0.035, 0.04, 0.045, roughness: 0.28, metallic: 0.38),
        screen: .init(0.025, 0.055, 0.075, roughness: 0.06, metallic: 0.12),
        surfaceThickness: 0.045
    )

    static let soundStage = RealityTheme(
        id: .soundStage,
        title: "Film Stüdyosu",
        subtitle: "Koyu akustik yüzeyler, gri set zemini ve metal ekipman",
        symbolName: "movieclapper.fill",
        wall: .init(0.075, 0.08, 0.09, roughness: 0.95),
        floor: .init(0.12, 0.125, 0.13, roughness: 0.76),
        ceiling: .init(0.045, 0.05, 0.058, roughness: 0.92),
        door: .init(0.055, 0.06, 0.07, roughness: 0.70, metallic: 0.20),
        glass: .init(0.24, 0.31, 0.36, alpha: 0.22, roughness: 0.12),
        opening: .init(0.012, 0.014, 0.018, roughness: 1),
        trim: .init(0.22, 0.23, 0.24, roughness: 0.30, metallic: 0.78),
        furniturePrimary: .init(0.11, 0.115, 0.12, roughness: 0.88),
        furnitureSecondary: .init(0.28, 0.29, 0.30, roughness: 0.62),
        furnitureDetail: .init(0.035, 0.038, 0.042, roughness: 0.24, metallic: 0.72),
        screen: .init(0.76, 0.80, 0.85, roughness: 0.10, metallic: 0.08),
        surfaceThickness: 0.055
    )

    static let sciFi = RealityTheme(
        id: .sciFi,
        title: "Bilimkurgu",
        subtitle: "Titanyum paneller, soğuk cam ve turkuaz teknoloji ayrıntıları",
        symbolName: "sparkles.rectangle.stack.fill",
        wall: .init(0.11, 0.15, 0.18, roughness: 0.32, metallic: 0.64),
        floor: .init(0.055, 0.075, 0.085, roughness: 0.24, metallic: 0.72),
        ceiling: .init(0.08, 0.12, 0.15, roughness: 0.26, metallic: 0.66),
        door: .init(0.17, 0.22, 0.25, roughness: 0.22, metallic: 0.78),
        glass: .init(0.05, 0.64, 0.74, alpha: 0.34, roughness: 0.05, metallic: 0.05),
        opening: .init(0.005, 0.018, 0.024, roughness: 0.52),
        trim: .init(0.06, 0.76, 0.82, roughness: 0.16, metallic: 0.48),
        furniturePrimary: .init(0.12, 0.17, 0.20, roughness: 0.34, metallic: 0.54),
        furnitureSecondary: .init(0.33, 0.39, 0.42, roughness: 0.26, metallic: 0.68),
        furnitureDetail: .init(0.025, 0.035, 0.04, roughness: 0.16, metallic: 0.82),
        screen: .init(0.04, 0.78, 0.88, roughness: 0.04, metallic: 0.12),
        surfaceThickness: 0.06
    )

    static let warmLoft = RealityTheme(
        id: .warmLoft,
        title: "Sıcak Loft",
        subtitle: "Tuğla tonları, koyu ahşap ve eskitilmiş metal",
        symbolName: "building.2.fill",
        wall: .init(0.45, 0.17, 0.09, roughness: 0.94),
        floor: .init(0.19, 0.105, 0.055, roughness: 0.78),
        ceiling: .init(0.32, 0.24, 0.18, roughness: 0.88),
        door: .init(0.12, 0.065, 0.035, roughness: 0.74),
        glass: .init(0.42, 0.58, 0.61, alpha: 0.26, roughness: 0.10),
        opening: .init(0.035, 0.026, 0.022, roughness: 0.94),
        trim: .init(0.10, 0.075, 0.06, roughness: 0.38, metallic: 0.62),
        furniturePrimary: .init(0.28, 0.13, 0.055, roughness: 0.76),
        furnitureSecondary: .init(0.43, 0.34, 0.24, roughness: 0.82),
        furnitureDetail: .init(0.075, 0.065, 0.058, roughness: 0.32, metallic: 0.70),
        screen: .init(0.05, 0.042, 0.035, roughness: 0.08, metallic: 0.14),
        surfaceThickness: 0.05
    )

    static let all: [RealityTheme] = [modern, soundStage, sciFi, warmLoft]

    static func theme(withID id: RealityThemeID) -> RealityTheme {
        all.first(where: { $0.id == id }) ?? modern
    }
}
