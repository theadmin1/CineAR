import Foundation

@main
struct SpatialValidationTests {
    static func main() {
        // Partial scans are intentional: a closed four-wall outline is never required.
        precondition(RoomScanCompletionPolicy.hasUsablePartialScan(floors: 1, walls: 0, objects: 0))
        precondition(RoomScanCompletionPolicy.hasUsablePartialScan(floors: 0, walls: 1, objects: 0))
        precondition(RoomScanCompletionPolicy.hasUsablePartialScan(floors: 0, walls: 0, objects: 1))
        precondition(!RoomScanCompletionPolicy.hasUsablePartialScan(floors: 0, walls: 0, objects: 0))
        // A transient one-wall callback cannot erase a previously observed four-wall room.
        precondition(!RoomScanCompletionPolicy.shouldReplaceRetainedSnapshot(
            retainedUsable: true, retainedWallSpanHighWater: 12, retainedElementCount: 5,
            candidateUsable: true, candidateWallSpan: 3, candidateElementCount: 2
        ))
        // A nearly equal but semantically reduced transient snapshot is also retained;
        // a genuinely wider candidate is allowed to advance the high-water mark.
        precondition(!RoomScanCompletionPolicy.shouldReplaceRetainedSnapshot(
            retainedUsable: true, retainedWallSpanHighWater: 12, retainedElementCount: 5,
            candidateUsable: true, candidateWallSpan: 11.9, candidateElementCount: 2
        ))
        precondition(RoomScanCompletionPolicy.shouldReplaceRetainedSnapshot(
            retainedUsable: true, retainedWallSpanHighWater: 12, retainedElementCount: 5,
            candidateUsable: true, candidateWallSpan: 12.5, candidateElementCount: 2
        ))
        precondition(!RoomScanCompletionPolicy.shouldReplaceRetainedSnapshot(
            retainedUsable: true, retainedWallSpanHighWater: 12, retainedElementCount: 5,
            candidateUsable: true, candidateWallSpan: 0, candidateElementCount: 8
        ))
        precondition(RoomScanCompletionPolicy.shouldReplaceRetainedSnapshot(
            retainedUsable: false, retainedWallSpanHighWater: 0, retainedElementCount: 0,
            candidateUsable: true, candidateWallSpan: 2, candidateElementCount: 1
        ))
        // Processed topology wins only while it preserves the approved live wall span.
        precondition(RoomScanCompletionPolicy.output(
            approvedAtFinish: true, processedUsable: true, liveUsable: true,
            processedWallSpan: 11, liveWallSpan: 12
        ) == .processed)
        precondition(RoomScanCompletionPolicy.output(
            approvedAtFinish: true, processedUsable: true, liveUsable: true,
            processedWallSpan: 3, liveWallSpan: 12
        ) == .approvedLive)
        precondition(RoomScanCompletionPolicy.output(
            approvedAtFinish: true, processedUsable: false, liveUsable: true,
            processedWallSpan: 0, liveWallSpan: 12
        ) == .approvedLive)
        precondition(RoomScanCompletionPolicy.output(
            approvedAtFinish: true, processedUsable: false, liveUsable: false,
            processedWallSpan: 0, liveWallSpan: 0
        ) == .reject)
        precondition(RoomScanCompletionPolicy.output(
            approvedAtFinish: false, processedUsable: true, liveUsable: false,
            processedWallSpan: 2, liveWallSpan: 0
        ) == .processed)
        precondition(RoomScanCompletionPolicy.output(
            approvedAtFinish: false, processedUsable: false, liveUsable: true,
            processedWallSpan: 0, liveWallSpan: 2
        ) == .reject)

        // Low-confidence/missing LiDAR cannot veto a finite saved wall. A clearly
        // closer measured object still protects foreground occlusion.
        precondition(WallPlacementPolicy.persistentWallIsVisible(measuredDistance: nil, wallDistance: 3))
        precondition(WallPlacementPolicy.persistentWallIsVisible(measuredDistance: 2.92, wallDistance: 3))
        precondition(!WallPlacementPolicy.persistentWallIsVisible(measuredDistance: 2.70, wallDistance: 3))
        precondition(!WallPlacementPolicy.persistentWallIsVisible(measuredDistance: nil, wallDistance: .nan))
        precondition(WallPlacementPolicy.samePhysicalSurface(
            firstPosition: [0, 1, 0], firstNormal: [0, 0, 1],
            secondPosition: [0.04, 1.01, 0.02], secondNormal: [0.05, 0, 0.998]
        ))
        precondition(!WallPlacementPolicy.samePhysicalSurface(
            firstPosition: [0, 1, 0], firstNormal: [0, 0, 1],
            secondPosition: [0, 1, 0], secondNormal: [1, 0, 0]
        ))
        precondition(WallPlacementPolicy.robustDepth(center: 2, neighbors: Array(repeating: 2, count: 25)) == 2)
        let mixed = Array(repeating: Float(1), count: 9) + Array(repeating: Float(3), count: 16)
        precondition(WallPlacementPolicy.robustDepth(center: 1, neighbors: mixed) == 1)
        precondition(WallPlacementPolicy.robustDepth(center: 2, neighbors: mixed) == nil)
        precondition(WallPlacementPolicy.robustDepth(center: nil, neighbors: mixed) == nil)
        precondition(WallPlacementPolicy.robustDepth(center: .nan, neighbors: mixed) == nil)
        precondition(WallPlacementPolicy.robustDepth(center: 1, neighbors: Array(repeating: 1, count: 8)) == nil)
        precondition(WallPlacementPolicy.agreesWithPlane(separation: 0.01, lateralError: 0.01, depth: 2))
        precondition(!WallPlacementPolicy.agreesWithPlane(separation: 0.12, lateralError: 0, depth: 2))
        precondition(!WallPlacementPolicy.agreesWithPlane(separation: -0.12, lateralError: 0, depth: 2))
        precondition(!WallPlacementPolicy.agreesWithPlane(separation: 0, lateralError: 0.2, depth: 2))
        precondition(!WallPlacementPolicy.agreesWithPlane(separation: .nan, lateralError: 0, depth: 2))
        // No camera distance appears in contact projection: the fitted plane is fixed.
        let contact = WallPlacementPolicy.projectContact([1, 2, 0.02], onto: [0, 0, 0], normal: [0, 0, 1])!
        precondition(contact == SIMD3<Float>(1, 2, 0))
        let reverse = WallPlacementPolicy.projectContact([1, 2, 0.02], onto: [0, 0, 0], normal: [0, 0, -2])!
        precondition(reverse == contact)
        let angled = WallPlacementPolicy.projectContact([1, 2, 3], onto: .zero, normal: [1, 0, 1])!
        precondition(abs(angled.x + angled.z) < 0.00001 && angled.y == 2)
        precondition(WallPlacementPolicy.projectContact(.zero, onto: .zero, normal: .zero) == nil)
        precondition(WallPlacementPolicy.projectContact(.zero, onto: .zero, normal: [.greatestFiniteMagnitude, 0, 0]) == nil)
        precondition(!WallPlacementPolicy.agreesWithPlane(separation: 0, lateralError: -1, depth: 2))
        // Deterministic projection checks over walls at many positions/orientations.
        for step in 0..<360 {
            let radians = Float(step) * .pi / 180
            let normal = SIMD3<Float>(cos(radians), 0, sin(radians))
            let origin = SIMD3<Float>(2, 1, -3)
            let point = origin + normal * 0.024 + SIMD3<Float>(0, 0.5, 0)
            let projected = WallPlacementPolicy.projectContact(point, onto: origin, normal: normal)!
            let delta = projected - origin
            precondition(abs(delta.x * normal.x + delta.z * normal.z) < 0.00001)
            precondition(abs(projected.y - 1.5) < 0.00001)
        }
        print("Spatial validation tests passed")
    }
}
