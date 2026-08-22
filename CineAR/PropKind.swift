import Foundation

enum PropKind: String, CaseIterable, Identifiable, Codable {
    case wall
    case stage
    case crate
    case lightPanel
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wall: "Duvar"
        case .stage: "Platform"
        case .crate: "Kasa"
        case .lightPanel: "Işık"
        case .custom: "USDZ"
        }
    }

    var symbol: String {
        switch self {
        case .wall: "🧱"
        case .stage: "🎬"
        case .crate: "📦"
        case .lightPanel: "💡"
        case .custom: "🎭"
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
