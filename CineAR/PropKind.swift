import Foundation
import simd

enum PropPlacementSurface: String, Codable {
    case floor
    case horizontal
    case wall
    case ceiling
}

enum PropLibraryCategory: String, CaseIterable, Identifiable {
    case furniture
    case storage
    case equipment
    case wall
    case lighting
    case electronics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .furniture: "Mobilya"
        case .storage: "Depolama"
        case .equipment: "Ekipman"
        case .wall: "Duvar"
        case .lighting: "Işık"
        case .electronics: "Elektronik"
        }
    }
}

struct PhotorealPropDescriptor {
    let assetName: String
    let dimensions: SIMD3<Float>
    let surface: PropPlacementSurface
    let category: PropLibraryCategory
    let emitsLight: Bool
}

enum PropKind: String, CaseIterable, Identifiable, Codable {
    // Lightweight legacy props remain decodable so existing saved scenes still load.
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

    // Curated Poly Haven CC0 photoreal catalog (30 objects).
    case metalOfficeDesk
    case schoolChair
    case schoolDesk
    case metalTrashCan
    case cardboardBox
    case plasticCrate
    case woodenCrate
    case blueBarrel
    case handTruck
    case drawerCabinet
    case filingCabinet
    case steelShelves
    case toolChest
    case plasticChair
    case woodenStool
    case wetFloorSign
    case fireExtinguisher
    case securityCamera
    case powerBox
    case payphone
    case wallClock
    case cagedCeilingLight
    case industrialPendant
    case ceilingFan
    case industrialWallLamp
    case cagedWallLight
    case deskLamp
    case classicLaptop
    case crtTelevision
    case boombox

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wall: "Duvar"
        case .stage: "Platform"
        case .crate: "Kasa"
        case .lightPanel: "Işık Paneli"
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
        case .metalOfficeDesk: "Metal Ofis Masası"
        case .schoolChair: "Okul Sandalyesi"
        case .schoolDesk: "Okul Sırası"
        case .metalTrashCan: "Metal Çöp Kutuları"
        case .cardboardBox: "Yıpranmış Koli"
        case .plasticCrate: "Plastik Kasa"
        case .woodenCrate: "Ahşap Kasa"
        case .blueBarrel: "Depo Varili"
        case .handTruck: "Yük Arabası"
        case .drawerCabinet: "Raflı Çekmeceli Dolap"
        case .filingCabinet: "Vintage Çekmeceli Dolap"
        case .steelShelves: "Çelik Raf"
        case .toolChest: "Takım Sandığı"
        case .plasticChair: "Plastik Sandalye"
        case .woodenStool: "Ahşap Tabure"
        case .wetFloorSign: "Islak Zemin Tabelası"
        case .fireExtinguisher: "Yangın Tüpü"
        case .securityCamera: "Güvenlik Kamerası"
        case .powerBox: "Elektrik Panosu"
        case .payphone: "Eski Ankesörlü Telefon"
        case .wallClock: "Duvar Saati"
        case .cagedCeilingLight: "Kafesli Tavan Işığı"
        case .industrialPendant: "Endüstriyel Sarkıt"
        case .ceilingFan: "Tavan Vantilatörü"
        case .industrialWallLamp: "Endüstriyel Duvar Işığı"
        case .cagedWallLight: "Kafesli Duvar Işığı"
        case .deskLamp: "Masa Lambası"
        case .classicLaptop: "Klasik Dizüstü"
        case .crtTelevision: "Tüplü Televizyon"
        case .boombox: "Kasetçalar"
        }
    }

    var symbol: String {
        switch self {
        case .wall: "🧱"
        case .stage: "🎬"
        case .crate, .cardboardBox, .plasticCrate, .woodenCrate: "📦"
        case .lightPanel, .cagedCeilingLight, .industrialPendant,
             .industrialWallLamp, .cagedWallLight, .deskLamp: "💡"
        case .chair, .schoolChair, .plasticChair: "🪑"
        case .table, .metalOfficeDesk, .schoolDesk: "🗄️"
        case .sofa: "🛋️"
        case .bed: "🛏️"
        case .bookcase, .steelShelves: "📚"
        case .television, .crtTelevision: "📺"
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
        case .metalTrashCan: "🗑️"
        case .blueBarrel: "🛢️"
        case .handTruck: "🛒"
        case .drawerCabinet, .filingCabinet: "🗃️"
        case .toolChest: "🧰"
        case .woodenStool: "🪵"
        case .wetFloorSign: "⚠️"
        case .fireExtinguisher: "🧯"
        case .securityCamera: "📹"
        case .powerBox: "⚡"
        case .payphone: "☎️"
        case .wallClock: "🕒"
        case .ceilingFan: "🌀"
        case .classicLaptop: "💻"
        case .boombox: "📻"
        }
    }

    static let quickCases: [PropKind] = [.wall, .stage, .crate, .lightPanel, .custom]
    static let furnitureCases: [PropKind] = photorealCases

    static let photorealCases: [PropKind] = [
        .metalOfficeDesk, .schoolChair, .schoolDesk, .metalTrashCan,
        .cardboardBox, .plasticCrate, .woodenCrate, .blueBarrel,
        .handTruck, .drawerCabinet, .filingCabinet, .steelShelves,
        .toolChest, .plasticChair, .woodenStool, .wetFloorSign,
        .fireExtinguisher, .securityCamera, .powerBox, .payphone,
        .wallClock, .cagedCeilingLight, .industrialPendant, .ceilingFan,
        .industrialWallLamp, .cagedWallLight, .deskLamp, .classicLaptop,
        .crtTelevision, .boombox
    ]

    var photorealDescriptor: PhotorealPropDescriptor? {
        switch self {
        case .metalOfficeDesk:
            .init(assetName: "metal_office_desk", dimensions: [1.50, 0.76, 0.75], surface: .floor, category: .furniture, emitsLight: false)
        case .schoolChair:
            .init(assetName: "SchoolChair_01", dimensions: [0.48, 0.84, 0.52], surface: .floor, category: .furniture, emitsLight: false)
        case .schoolDesk:
            .init(assetName: "SchoolDesk_01", dimensions: [0.66, 0.78, 0.55], surface: .floor, category: .furniture, emitsLight: false)
        case .metalTrashCan:
            .init(assetName: "metal_trash_can", dimensions: [1.35, 0.65, 0.45], surface: .floor, category: .storage, emitsLight: false)
        case .cardboardBox:
            .init(assetName: "cardboard_box_01", dimensions: [0.45, 0.40, 0.58], surface: .horizontal, category: .storage, emitsLight: false)
        case .plasticCrate:
            .init(assetName: "plastic_crate_02", dimensions: [0.60, 0.34, 0.40], surface: .horizontal, category: .storage, emitsLight: false)
        case .woodenCrate:
            .init(assetName: "wooden_crate_02", dimensions: [0.55, 0.48, 1.15], surface: .horizontal, category: .storage, emitsLight: false)
        case .blueBarrel:
            .init(assetName: "Barrel_02", dimensions: [0.58, 0.90, 0.58], surface: .floor, category: .storage, emitsLight: false)
        case .handTruck:
            .init(assetName: "hand_truck", dimensions: [0.55, 1.30, 0.65], surface: .floor, category: .equipment, emitsLight: false)
        case .drawerCabinet:
            .init(assetName: "drawer_cabinet", dimensions: [0.90, 1.50, 0.50], surface: .floor, category: .storage, emitsLight: false)
        case .filingCabinet:
            .init(assetName: "vintage_wooden_drawer_01", dimensions: [0.86, 0.55, 0.46], surface: .floor, category: .storage, emitsLight: false)
        case .steelShelves:
            .init(assetName: "steel_frame_shelves_01", dimensions: [1.20, 1.84, 0.46], surface: .floor, category: .storage, emitsLight: false)
        case .toolChest:
            .init(assetName: "metal_tool_chest", dimensions: [0.76, 0.52, 0.46], surface: .horizontal, category: .equipment, emitsLight: false)
        case .plasticChair:
            .init(assetName: "plastic_monobloc_chair_01", dimensions: [0.56, 0.84, 0.58], surface: .floor, category: .furniture, emitsLight: false)
        case .woodenStool:
            .init(assetName: "wooden_stool_01", dimensions: [0.39, 0.46, 0.39], surface: .floor, category: .furniture, emitsLight: false)
        case .wetFloorSign:
            .init(assetName: "WetFloorSign_01", dimensions: [0.38, 0.62, 0.32], surface: .floor, category: .equipment, emitsLight: false)
        case .fireExtinguisher:
            .init(assetName: "korean_fire_extinguisher_01", dimensions: [0.25, 0.58, 0.30], surface: .floor, category: .equipment, emitsLight: false)
        case .securityCamera:
            .init(assetName: "security_camera_01", dimensions: [0.27, 0.20, 0.36], surface: .wall, category: .wall, emitsLight: false)
        case .powerBox:
            .init(assetName: "power_box_01", dimensions: [0.46, 0.66, 0.21], surface: .wall, category: .wall, emitsLight: false)
        case .payphone:
            .init(assetName: "korean_public_payphone_01", dimensions: [0.31, 0.55, 0.29], surface: .wall, category: .wall, emitsLight: false)
        case .wallClock:
            .init(assetName: "wall_clock", dimensions: [0.39, 0.39, 0.07], surface: .wall, category: .wall, emitsLight: false)
        case .cagedCeilingLight:
            .init(assetName: "caged_hanging_light", dimensions: [1.10, 0.72, 0.35], surface: .ceiling, category: .lighting, emitsLight: true)
        case .industrialPendant:
            .init(assetName: "hanging_industrial_lamp", dimensions: [0.55, 1.35, 0.55], surface: .ceiling, category: .lighting, emitsLight: true)
        case .ceilingFan:
            .init(assetName: "ceiling_fan", dimensions: [1.30, 0.46, 1.30], surface: .ceiling, category: .equipment, emitsLight: false)
        case .industrialWallLamp:
            .init(assetName: "industrial_wall_lamp", dimensions: [0.30, 0.44, 0.34], surface: .wall, category: .lighting, emitsLight: true)
        case .cagedWallLight:
            .init(assetName: "industrial_wall_sconce", dimensions: [0.28, 0.42, 0.32], surface: .wall, category: .lighting, emitsLight: true)
        case .deskLamp:
            .init(assetName: "desk_lamp_arm_01", dimensions: [0.34, 0.72, 0.46], surface: .horizontal, category: .lighting, emitsLight: true)
        case .classicLaptop:
            .init(assetName: "classic_laptop", dimensions: [0.38, 0.32, 0.30], surface: .horizontal, category: .electronics, emitsLight: false)
        case .crtTelevision:
            .init(assetName: "television_02", dimensions: [0.58, 0.48, 0.48], surface: .horizontal, category: .electronics, emitsLight: false)
        case .boombox:
            .init(assetName: "boombox", dimensions: [0.52, 0.31, 0.23], surface: .horizontal, category: .electronics, emitsLight: false)
        default:
            nil
        }
    }

    var placementSurface: PropPlacementSurface {
        if let surface = photorealDescriptor?.surface { return surface }
        switch self {
        case .wall, .lightPanel, .backdrop:
            return PropPlacementSurface.wall
        case .custom:
            return PropPlacementSurface.horizontal
        default:
            return PropPlacementSurface.floor
        }
    }

    var emitsVirtualLight: Bool {
        photorealDescriptor?.emitsLight == true || self == .lightPanel || self == .floorLamp
    }

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
        default: nil
        }
    }

    var anchorName: String { "cinear.prop.\(rawValue)" }

    func anchorName(id: UUID) -> String {
        "\(anchorName).\(id.uuidString)"
    }

    static func from(anchorName: String?) -> PropKind? {
        guard let anchorName else { return nil }
        let parts = anchorName.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4,
              parts[0] == "cinear",
              parts[1] == "prop" else { return nil }
        return PropKind(rawValue: String(parts[2]))
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
