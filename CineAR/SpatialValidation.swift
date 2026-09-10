import Foundation

/// Finishing a scan is a transaction: approval belongs to the live snapshot that
/// the user accepted, not to endpoint counts that processing may change.
enum RoomScanCompletionPolicy {
    enum Output: Equatable { case processed, approvedLive, reject }

    static func hasCoverage(walls: Int, directions: Int, span: Float, connections: Float) -> Bool {
        walls >= 4 && directions >= 2 && span.isFinite && span >= 2.4
            && connections.isFinite && (0.72...1).contains(connections)
    }

    static func hasObservedCoverage(
        completeWalls: Int,
        totalWalls: Int,
        observedBins: Int,
        totalBins: Int
    ) -> Bool {
        guard totalWalls >= 4, totalBins == totalWalls * 6 else { return false }
        return completeWalls >= 4 && observedBins * 100 >= totalBins * 55
    }

    static func output(approvedAtFinish: Bool, processedUsable: Bool, liveUsable: Bool) -> Output {
        guard approvedAtFinish else { return .reject }
        if processedUsable { return .processed }
        return liveUsable ? .approvedLive : .reject
    }

    static func preservesWallSpan(processed: Float, approved: Float) -> Bool {
        processed.isFinite && approved.isFinite && approved > 0 && processed >= approved * 0.90
    }

    static func preservesRoomShape(
        processedWalls: Int,
        approvedWalls: Int,
        processedDirections: Int,
        approvedDirections: Int,
        processedSpan: Float,
        approvedSpan: Float,
        processedConnections: Float,
        approvedConnections: Float
    ) -> Bool {
        guard approvedWalls >= 4,
              processedWalls + 1 >= approvedWalls,
              processedDirections >= approvedDirections,
              preservesWallSpan(processed: processedSpan, approved: approvedSpan),
              processedConnections.isFinite,
              approvedConnections.isFinite else { return false }
        return processedConnections >= max(0.60, approvedConnections - 0.15)
    }
}

enum RoomScanObservationPolicy {
    static func bin(normalizedX: Float, normalizedY: Float) -> Int? {
        guard normalizedX.isFinite, normalizedY.isFinite,
              (0...1).contains(normalizedX), (0...1).contains(normalizedY) else { return nil }
        let column = min(2, Int(min(normalizedX, 0.999_999) * 3))
        let row = min(1, Int(min(normalizedY, 0.999_999) * 2))
        return row * 3 + column
    }

    static func wallIsComplete(bins: Set<Int>) -> Bool {
        let validBins = bins.filter { (0..<6).contains($0) }
        let columns = Set(validBins.map { $0 % 3 })
        let rows = Set(validBins.map { $0 / 3 })
        return validBins.count >= 4 && columns.count == 3 && rows.count == 2
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
