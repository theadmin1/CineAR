import Foundation

/// Finishing a scan is a transaction: approval belongs to the usable live
/// snapshot that the user accepted. A partial RoomPlan result is valid data; it
/// must not be rejected merely because the walls do not form a closed outline.
enum RoomScanCompletionPolicy {
    enum Output: Equatable { case processed, approvedLive, reject }

    /// RoomPlan can temporarily withdraw wall segments while it joins corners. Keep
    /// a high-water snapshot instead of allowing a floor-only or much smaller update
    /// to erase wall geometry that was already observed.
    static func shouldReplaceRetainedSnapshot(
        retainedUsable: Bool,
        retainedWallSpanHighWater: Float,
        retainedElementCount: Int,
        candidateUsable: Bool,
        candidateWallSpan: Float,
        candidateElementCount: Int
    ) -> Bool {
        guard candidateUsable,
              candidateWallSpan.isFinite,
              retainedWallSpanHighWater.isFinite,
              candidateWallSpan >= 0,
              retainedWallSpanHighWater >= 0 else { return false }
        guard retainedUsable else { return true }

        let retainedHasWalls = retainedWallSpanHighWater >= 0.10
        let candidateHasWalls = candidateWallSpan >= 0.10
        if retainedHasWalls && !candidateHasWalls { return false }
        if candidateHasWalls && !retainedHasWalls { return true }
        if retainedHasWalls && candidateHasWalls {
            // A two-percent allowance lets RoomPlan refine dimensions without making
            // repeated small reductions ratchet the retained high-water mark down.
            guard candidateWallSpan + 0.02 >= retainedWallSpanHighWater * 0.98 else {
                return false
            }
            if candidateWallSpan > retainedWallSpanHighWater + 0.02 { return true }
            // For nearly equal wall coverage retain the snapshot with more semantic
            // information. A temporary wall merge must not also erase floor/objects.
            return candidateElementCount >= retainedElementCount
        }
        return candidateElementCount >= retainedElementCount
    }

    static func hasUsablePartialScan(floors: Int, walls: Int, objects: Int) -> Bool {
        floors > 0 || walls > 0 || objects > 0
    }

    static func output(
        approvedAtFinish: Bool,
        processedUsable: Bool,
        liveUsable: Bool,
        processedWallSpan: Float,
        liveWallSpan: Float
    ) -> Output {
        if processedUsable {
            if approvedAtFinish, liveUsable, liveWallSpan >= 0.10 {
                // Processing may merge collinear fragments, so wall count is not a
                // useful comparison. It may not, however, discard most of the measured
                // wall span (the observed four-walls-to-one-wall regression).
                guard processedWallSpan.isFinite,
                      processedWallSpan >= liveWallSpan * 0.85 else {
                    return .approvedLive
                }
            }
            return .processed
        }
        return approvedAtFinish && liveUsable ? .approvedLive : .reject
    }

}

enum WallPlacementPolicy {
    /// RoomPlan supplies a stable wall normal and finite outline, but its plane may
    /// be a few centimetres away from the physical finish. Admit a fresh LiDAR point
    /// only when it is close enough to be a refinement of that wall, rather than a
    /// separate foreground surface. The caller can then keep the scanned orientation
    /// while using the measured point as the exact contact plane.
    static func liveContactMatchesPersistentWall(
        measuredPosition: SIMD3<Float>,
        measuredNormal: SIMD3<Float>?,
        wallPosition: SIMD3<Float>,
        wallNormal: SIMD3<Float>
    ) -> Bool {
        let values = [
            measuredPosition.x, measuredPosition.y, measuredPosition.z,
            wallPosition.x, wallPosition.y, wallPosition.z,
            wallNormal.x, wallNormal.y, wallNormal.z,
        ]
        guard values.allSatisfy(\.isFinite) else { return false }
        let wallLengthSquared = wallNormal.x * wallNormal.x
            + wallNormal.y * wallNormal.y + wallNormal.z * wallNormal.z
        guard wallLengthSquared.isFinite, wallLengthSquared > 0.000_001 else { return false }
        let wallDirection = wallNormal / sqrt(wallLengthSquared)

        if let measuredNormal {
            guard [measuredNormal.x, measuredNormal.y, measuredNormal.z].allSatisfy(\.isFinite)
            else { return false }
            let measuredLengthSquared = measuredNormal.x * measuredNormal.x
                + measuredNormal.y * measuredNormal.y + measuredNormal.z * measuredNormal.z
            guard measuredLengthSquared.isFinite, measuredLengthSquared > 0.000_001 else {
                return false
            }
            let measuredDirection = measuredNormal / sqrt(measuredLengthSquared)
            let normalAgreement = measuredDirection.x * wallDirection.x
                + measuredDirection.y * wallDirection.y
                + measuredDirection.z * wallDirection.z
            guard abs(normalAgreement) >= 0.88 else { return false }
        }

        let delta = measuredPosition - wallPosition
        let signedSeparation = delta.x * wallDirection.x
            + delta.y * wallDirection.y + delta.z * wallDirection.z
        let lateral = delta - wallDirection * signedSeparation
        let lateralLengthSquared = lateral.x * lateral.x
            + lateral.y * lateral.y + lateral.z * lateral.z
        let distanceSquared = delta.x * delta.x + delta.y * delta.y + delta.z * delta.z
        return abs(signedSeparation) <= 0.05
            && lateralLengthSquared <= 0.0064
            && distanceSquared <= 0.0144
    }

    /// Missing/low-confidence depth is not evidence that a finite saved wall is bad.
    /// A saved wall is rejected only when LiDAR positively measures a foreground
    /// surface a meaningful distance in front of it.
    static func persistentWallIsVisible(measuredDistance: Float?, wallDistance: Float) -> Bool {
        guard wallDistance.isFinite, wallDistance > 0 else { return false }
        guard let measuredDistance else { return true }
        guard measuredDistance.isFinite, measuredDistance > 0 else { return true }
        let foregroundClearance = min(max(0.10, wallDistance * 0.025), 0.16)
        return measuredDistance + foregroundClearance >= wallDistance
    }

    /// ARPlane, RoomPlan and LiDAR mesh can all describe the same wall on adjacent
    /// frames. Treat a source switch as continuous when their fitted planes agree.
    static func samePhysicalSurface(
        firstPosition: SIMD3<Float>,
        firstNormal: SIMD3<Float>,
        secondPosition: SIMD3<Float>,
        secondNormal: SIMD3<Float>
    ) -> Bool {
        let firstLengthSquared = firstNormal.x * firstNormal.x
            + firstNormal.y * firstNormal.y + firstNormal.z * firstNormal.z
        let secondLengthSquared = secondNormal.x * secondNormal.x
            + secondNormal.y * secondNormal.y + secondNormal.z * secondNormal.z
        guard firstLengthSquared.isFinite, secondLengthSquared.isFinite,
              firstLengthSquared > 0.000_001, secondLengthSquared > 0.000_001 else { return false }
        let firstLength = sqrt(firstLengthSquared)
        let secondLength = sqrt(secondLengthSquared)
        let normalAgreement = abs(
            (firstNormal.x * secondNormal.x + firstNormal.y * secondNormal.y
                + firstNormal.z * secondNormal.z) / (firstLength * secondLength)
        )
        let delta = secondPosition - firstPosition
        let planeSeparation = abs(
            (delta.x * firstNormal.x + delta.y * firstNormal.y + delta.z * firstNormal.z)
                / firstLength
        )
        let distanceSquared = delta.x * delta.x + delta.y * delta.y + delta.z * delta.z
        return normalAgreement >= 0.92 && planeSeparation <= 0.08 && distanceSquared <= 0.0225
    }

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
