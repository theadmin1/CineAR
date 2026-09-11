import Foundation

/// Finishing a scan is a transaction: approval belongs to the usable live
/// snapshot that the user accepted. A partial RoomPlan result is valid data; it
/// must not be rejected merely because the walls do not form a closed outline.
enum RoomScanCompletionPolicy {
    enum Output: Equatable { case processed, approvedLive, reject }

    static func hasUsablePartialScan(floors: Int, walls: Int, objects: Int) -> Bool {
        floors > 0 || walls > 0 || objects > 0
    }

    static func output(approvedAtFinish: Bool, processedUsable: Bool, liveUsable: Bool) -> Output {
        if processedUsable { return .processed }
        return approvedAtFinish && liveUsable ? .approvedLive : .reject
    }

    static func preservesWallSpan(processed: Float, approved: Float) -> Bool {
        processed.isFinite && approved.isFinite && approved > 0 && processed >= approved * 0.90
    }

}

enum RoomScanStartPolicy {
    static func hasFreshFrame(current: TimeInterval?, minimum: TimeInterval?) -> Bool {
        guard let minimum else { return current != nil }
        guard let current, current.isFinite, minimum.isFinite else { return false }
        return current >= minimum + 0.05
    }
}

enum WallPlacementPolicy {
    static func projectContact(_ point: SIMD3<Float>, onto origin: SIMD3<Float>, normal: SIMD3<Float>) -> SIMD3<Float>? {
        guard [point.x, point.y, point.z, origin.x, origin.y, origin.z,
               normal.x, normal.y, normal.z].allSatisfy(\.isFinite) else { return nil }
        let lengthSquared = normal.x * normal.x + normal.y * normal.y + normal.z * normal.z
        guard lengthSquared.isFinite, lengthSquared > 0.000_001 else { return nil }
        let delta = point - origin
        let separation = (delta.x * normal.x + delta.y * normal.y + delta.z * normal.z) / lengthSquared
        let result = point - normal * separation
        guard [result.x, result.y, result.z].allSatisfy(\.isFinite) else { return nil }
        return result
    }

    /// Do not replace a touched foreground pixel with the background median.
    static func robustDepth(center: Float?, neighbors: [Float]) -> Float? {
        guard let center, center.isFinite, (0.15...8).contains(center) else { return nil }
        let tolerance = min(0.015 + center * 0.01, 0.045)
        let cluster = neighbors.filter { $0.isFinite && abs($0 - center) <= tolerance }.sorted()
        guard cluster.count >= 9 else { return nil }
        return cluster[cluster.count / 2]
    }

    static func agreesWithPlane(separation: Float, lateralError: Float, depth: Float) -> Bool {
        guard separation.isFinite, lateralError.isFinite, lateralError >= 0,
              depth.isFinite, depth > 0 else { return false }
        return abs(separation) <= min(0.025 + depth * 0.005, 0.045)
            && lateralError <= max(0.025, depth * 0.015)
    }
}
