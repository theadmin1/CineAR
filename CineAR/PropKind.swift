import Foundation

enum PropKind: String, CaseIterable, Identifiable, Codable {
    case wall
    case stage
    case crate
    case lightPanel
    case chair
    case table
    case sofa
    case bed
    case bookcase
    case television
    case refrigerator
    case oven
    case stove
    case sink
    case bathtub
    case toilet
    case washerDryer
    case stairs
    case plant
    case floorLamp
    case rug
    case backdrop
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wall: "Duvar"
        case .stage: "Platform"
        case .crate: "Kasa"
        case .lightPanel: "Işık"
        case .chair: "Sandalye"
        case .table: "Masa"
        case .sofa: "Koltuk"
        case .bed: "Yatak"
        case .bookcase: "Kitaplık"
        case .television: "Televizyon"
        case .refrigerator: "Buzdolabı"
        case .oven: "Fırın"
        case .stove: "Ocak"
        case .sink: "Lavabo"
        case .bathtub: "Küvet"
        case .toilet: "Tuvalet"
        case .washerDryer: "Çamaşır Makinesi"
        case .stairs: "Merdiven"
        case .plant: "Salon Bitkisi"
        case .floorLamp: "Ayaklı Lamba"
        case .rug: "Halı"
        case .backdrop: "Fon Perdesi"
        case .custom: "USDZ"
        }
    }

    var symbol: String {
        switch self {
        case .wall: "🧱"
        case .stage: "🎬"
        case .crate: "📦"
        case .lightPanel: "💡"
        case .chair: "🪑"
        case .table: "🍽️"
        case .sofa: "🛋️"
        case .bed: "🛏️"
        case .bookcase: "📚"
        case .television: "📺"
        case .refrigerator: "🧊"
        case .oven: "♨️"
        case .stove: "🍳"
        case .sink: "🚰"
        case .bathtub: "🛁"
        case .toilet: "🚽"
        case .washerDryer: "🧺"
        case .stairs: "🪜"
        case .plant: "🪴"
        case .floorLamp: "🏮"
        case .rug: "🟫"
        case .backdrop: "🎞️"
        case .custom: "🎭"
        }
    }

    static let quickCases: [PropKind] = [.wall, .stage, .crate, .lightPanel, .custom]

    static let furnitureCases: [PropKind] = [
        .chair, .table, .sofa, .bed, .bookcase, .television, .refrigerator,
        .oven, .stove, .sink, .bathtub, .toilet, .washerDryer, .stairs,
        .plant, .floorLamp, .rug, .backdrop
    ]

    var bundledAssetName: String? {
        switch self {
        case .chair: "chairModernCushion"
        case .table: "table"
        case .sofa: "loungeDesignSofa"
        case .bed: "bedDouble"
        case .bookcase: "bookcaseClosedWide"
        case .television: "televisionModern"
        case .refrigerator: "kitchenFridge"
        case .oven: "kitchenStove"
        case .stove: "kitchenStoveElectric"
        case .sink: "bathroomSink"
        case .bathtub: "bathtub"
        case .toilet: "toilet"
        case .washerDryer: "washerDryerStacked"
        case .stairs: "stairs"
        case .wall, .stage, .crate, .lightPanel, .plant, .floorLamp,
             .rug, .backdrop, .custom: nil
        }
    }

    var anchorName: String { "cinear.prop.\(rawValue)" }

    func anchorName(id: UUID) -> String {
        "\(anchorName).\(id.uuidString)"
    }

    static func from(anchorName: String?) -> PropKind? {
        guard let anchorName else { return nil }
        return allCases.first { anchorName.hasPrefix($0.anchorName) }
    }

    static func descriptor(from anchorName: String?) -> (kind: PropKind, id: UUID)? {
        guard let anchorName,
              let kind = from(anchorName: anchorName),
              let idText = anchorName.split(separator: ".").last,
              let id = UUID(uuidString: String(idText)) else {
            return nil
        }
        return (kind, id)
    }
}
