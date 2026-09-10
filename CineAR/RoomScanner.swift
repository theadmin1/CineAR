import ARKit
import Foundation
import RoomPlan
import SwiftUI
import UIKit
import simd

enum RoomScanResult: Equatable, Sendable {
    case success(URL)
    case cancelled
    case failure(String)
}

enum CapturedRoomStoreError: LocalizedError {
    case missingStagedArtifact(String)
    case commitFailed(original: String, rollback: String?)

    var errorDescription: String? {
        switch self {
        case .missingStagedArtifact(let filename):
            return "Geçici oda dosyası bulunamadı: \(filename)"
        case .commitFailed(let original, let rollback):
            guard let rollback else {
                return "Oda dosyaları kullanıma alınamadı: \(original)"
            }
            return "Oda dosyaları kullanıma alınamadı: \(original). Önceki sürüm geri yüklenemedi: \(rollback)"
        }
    }
}

/// Keeps RoomPlan's semantic JSON in a staged transaction until the user accepts the scan.
/// The live renderer consumes this JSON directly. Generating an additional RoomPlan USDZ
/// during preview teardown caused an avoidable memory spike on real devices, so stale
/// `room.usdz` archives are removed when a new semantic scan is committed.
struct CapturedRoomStore {
    struct StagedArtifacts: Equatable, Sendable {
        let roomJSONURL: URL
    }

    let modelURL: URL
    let roomJSONURL: URL

    private let fileManager: FileManager

    init(
        modelURL: URL,
        roomJSONURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.modelURL = modelURL
        self.roomJSONURL = roomJSONURL ?? Self.defaultRoomJSONURL(for: modelURL)
        self.fileManager = fileManager
    }

    static func defaultRoomJSONURL(for modelURL: URL) -> URL {
        modelURL.deletingLastPathComponent().appendingPathComponent("room.json")
    }

    func loadCapturedRoom() throws -> CapturedRoom {
        let data = try Data(contentsOf: roomJSONURL, options: [.mappedIfSafe])
        return try JSONDecoder().decode(CapturedRoom.self, from: data)
    }

    func stage(_ room: CapturedRoom) throws -> StagedArtifacts {
        try prepareParentDirectory(for: roomJSONURL)

        let identifier = UUID().uuidString
        let stagedJSONURL = temporarySibling(
            of: roomJSONURL,
            identifier: identifier,
            pathExtension: "json"
        )
        let artifacts = StagedArtifacts(roomJSONURL: stagedJSONURL)

        do {
            // Keep the mobile critical path compact. Pretty-printing and key sorting
            // temporarily duplicate a large RoomPlan result without helping the renderer.
            let roomData = try JSONEncoder().encode(room)
            try roomData.write(to: stagedJSONURL, options: .atomic)
            return artifacts
        } catch {
            discard(artifacts)
            throw error
        }
    }

    /// Atomically installs the semantic room and restores the previous JSON on failure.
    func commit(_ staged: StagedArtifacts) throws {
        try requireStagedFile(at: staged.roomJSONURL)

        let identifier = UUID().uuidString
        let jsonBackupURL = backupSibling(of: roomJSONURL, identifier: identifier)
        let hadJSON = fileManager.fileExists(atPath: roomJSONURL.path)
        var createdJSONBackup = false

        do {
            if hadJSON {
                try fileManager.copyItem(at: roomJSONURL, to: jsonBackupURL)
                createdJSONBackup = true
            }

            try install(staged.roomJSONURL, at: roomJSONURL)

            removeIfPresent(jsonBackupURL)
            removeIfPresent(modelURL)
        } catch {
            let originalMessage = error.localizedDescription
            var rollbackMessages: [String] = []

            if createdJSONBackup {
                do {
                    try restore(
                        finalURL: roomJSONURL,
                        backupURL: jsonBackupURL,
                        previouslyExisted: hadJSON
                    )
                } catch {
                    rollbackMessages.append(error.localizedDescription)
                }
            } else if !hadJSON {
                // A failed first install must not leave a partial destination behind.
                removeIfPresent(roomJSONURL)
            }

            discard(staged)
            removeIfPresent(jsonBackupURL)
            throw CapturedRoomStoreError.commitFailed(
                original: originalMessage,
                rollback: rollbackMessages.isEmpty ? nil : rollbackMessages.joined(separator: "; ")
            )
        }
    }

    func discard(_ staged: StagedArtifacts) {
        removeIfPresent(staged.roomJSONURL)
    }

    private func prepareParentDirectory(for url: URL) throws {
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    private func temporarySibling(
        of url: URL,
        identifier: String,
        pathExtension: String
    ) -> URL {
        url.deletingLastPathComponent()
            .appendingPathComponent(".RoomScan-\(identifier)-\(UUID().uuidString)")
            .appendingPathExtension(pathExtension)
    }

    private func backupSibling(of url: URL, identifier: String) -> URL {
        url.deletingLastPathComponent()
            .appendingPathComponent(".RoomScanBackup-\(identifier)-\(url.lastPathComponent)")
    }

    private func requireStagedFile(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw CapturedRoomStoreError.missingStagedArtifact(url.lastPathComponent)
        }
    }

    private func install(_ stagedURL: URL, at finalURL: URL) throws {
        if fileManager.fileExists(atPath: finalURL.path) {
            _ = try fileManager.replaceItemAt(finalURL, withItemAt: stagedURL)
        } else {
            try fileManager.moveItem(at: stagedURL, to: finalURL)
        }
    }

    private func restore(
        finalURL: URL,
        backupURL: URL,
        previouslyExisted: Bool
    ) throws {
        if fileManager.fileExists(atPath: finalURL.path) {
            try fileManager.removeItem(at: finalURL)
        }
        if previouslyExisted {
            try fileManager.moveItem(at: backupURL, to: finalURL)
        }
    }

    private func removeIfPresent(_ url: URL) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.removeItem(at: url)
    }
}

private struct CapturedRoomStageOutcome: Sendable {
    let artifacts: CapturedRoomStore.StagedArtifacts?
    let failureMessage: String?
}

private struct RoomScanFrameQuality: Sendable {
    let trackingIsNormal: Bool
    let trackingGuidance: String?

    static func measureTracking(frame: ARFrame) -> RoomScanFrameQuality {
        let trackingIsNormal: Bool
        let trackingGuidance: String?
        switch frame.camera.trackingState {
        case .normal:
            trackingIsNormal = true
            trackingGuidance = nil
        case .notAvailable:
            trackingIsNormal = false
            trackingGuidance = "Kamera takibi kullanılamıyor; telefonu sabit tut"
        case .limited(let reason):
            trackingIsNormal = false
            switch reason {
            case .excessiveMotion:
                trackingGuidance = "Telefonu daha yavaş hareket ettir"
            case .insufficientFeatures:
                trackingGuidance = "Düz duvara çapraz açıyla yaklaş; köşe veya dokulu alan göster"
            case .relocalizing:
                trackingGuidance = "Oda koordinatları yeniden bulunuyor; aynı alanda sabit kal"
            case .initializing:
                trackingGuidance = "Dünya takibi hazırlanıyor; telefonu kısa süre sabit tut"
            @unknown default:
                trackingGuidance = "Takip sınırlı; telefonu yavaşça detaylı bir alana çevir"
            }
        }

        return RoomScanFrameQuality(
            trackingIsNormal: trackingIsNormal,
            trackingGuidance: trackingGuidance
        )
    }
}

private struct RoomScanGeometryMetrics: Sendable {
    struct WallMeasurement: Equatable, Sendable {
        let width: Float
        let height: Float
        let center: SIMD3<Float>
        let normal: SIMD3<Float>
    }

    let floorCount: Int
    let wallCount: Int
    let objectCount: Int
    let substantialWallCount: Int
    let directionCount: Int
    let totalWallSpan: Float
    let connectedEndpointRatio: Float
    let walls: [UUID: WallMeasurement]

    var hasUsableGeometry: Bool { floorCount > 0 && substantialWallCount > 0 }
    var hasCoverage: Bool {
        RoomScanCompletionPolicy.hasCoverage(walls: substantialWallCount, directions: directionCount,
                                             span: totalWallSpan, connections: connectedEndpointRatio)
    }

    init(room: CapturedRoom) {
        floorCount = room.floors.filter { floor in
            let dimensions = [floor.dimensions.x, floor.dimensions.y, floor.dimensions.z]
            return dimensions.allSatisfy(\.isFinite) && dimensions.filter { $0 >= 0.1 }.count >= 2
                && (0..<4).allSatisfy { column in
                    (0..<4).allSatisfy { row in floor.transform[column][row].isFinite }
                }
        }.count
        wallCount = room.walls.count
        objectCount = room.objects.count

        let substantialWalls = room.walls.filter { wall in
            wall.dimensions.x.isFinite && wall.dimensions.y.isFinite
                && wall.dimensions.x >= 0.55 && wall.dimensions.y >= 1.0
                && (0..<4).allSatisfy { column in
                    (0..<4).allSatisfy { row in wall.transform[column][row].isFinite }
                }
        }
        substantialWallCount = substantialWalls.count
        totalWallSpan = substantialWalls.reduce(0) { $0 + $1.dimensions.x }
        walls = Dictionary(uniqueKeysWithValues: substantialWalls.map {
            let rawNormal = SIMD3<Float>(
                $0.transform.columns.2.x,
                $0.transform.columns.2.y,
                $0.transform.columns.2.z
            )
            let normalLength = simd_length(rawNormal)
            let normal = normalLength > 0.000_001 ? rawNormal / normalLength : .zero
            return (
                $0.identifier,
                WallMeasurement(
                    width: $0.dimensions.x,
                    height: $0.dimensions.y,
                    center: SIMD3<Float>(
                        $0.transform.columns.3.x,
                        $0.transform.columns.3.y,
                        $0.transform.columns.3.z
                    ),
                    normal: normal
                )
            )
        })
        directionCount = Self.distinctDirectionCount(in: substantialWalls)
        connectedEndpointRatio = Self.connectedEndpointRatio(in: substantialWalls)
    }

    private static func distinctDirectionCount(
        in walls: [CapturedRoom.Surface]
    ) -> Int {
        var directions: [Float] = []
        let minimumSeparation = Float.pi / 6

        for wall in walls {
            let normal = wall.transform.columns.2
            var angle = atan2f(normal.z, normal.x)
            while angle < 0 { angle += Float.pi }
            while angle >= Float.pi { angle -= Float.pi }

            let isNewDirection = directions.allSatisfy { existing in
                let delta = abs(angle - existing)
                return min(delta, Float.pi - delta) >= minimumSeparation
            }
            if isNewDirection { directions.append(angle) }
        }
        return directions.count
    }

    /// A complete room outline has wall endpoints that meet other wall endpoints at
    /// corners. This catches the common "four walls look present, one wall is only
    /// half scanned" case without assuming that every room is rectangular.
    private static func connectedEndpointRatio(
        in walls: [CapturedRoom.Surface]
    ) -> Float {
        struct Endpoint {
            let wallID: UUID
            let x: Float
            let z: Float
        }

        var endpoints: [Endpoint] = []
        endpoints.reserveCapacity(walls.count * 2)
        for wall in walls {
            let halfWidth = wall.dimensions.x * 0.5
            for localX in [-halfWidth, halfWidth] {
                let world = wall.transform * SIMD4<Float>(localX, 0, 0, 1)
                guard world.x.isFinite, world.z.isFinite else { continue }
                endpoints.append(Endpoint(wallID: wall.identifier, x: world.x, z: world.z))
            }
        }
        guard endpoints.count >= 6 else { return 0 }

        let maximumCornerGapSquared: Float = 0.35 * 0.35
        var connectedCount = 0
        for (index, endpoint) in endpoints.enumerated() {
            let isConnected = endpoints.enumerated().contains { otherIndex, other in
                guard index != otherIndex, endpoint.wallID != other.wallID else { return false }
                let dx = endpoint.x - other.x
                let dz = endpoint.z - other.z
                return dx * dx + dz * dz <= maximumCornerGapSquared
            }
            if isConnected { connectedCount += 1 }
        }
        return Float(connectedCount) / Float(endpoints.count)
    }
}

private struct RoomScanWallObservation {
    let referenceWidth: Float
    let referenceHeight: Float
    let referenceCenter: SIMD3<Float>
    let referenceNormal: SIMD3<Float>
    var bins: Set<Int>
}

private struct RoomScanObservationProgress {
    let completeWallCount: Int
    let wallCount: Int
    let observedBinCount: Int
    let totalBinCount: Int

    var percentage: Int {
        guard totalBinCount > 0 else { return 0 }
        return min(100, Int((Float(observedBinCount) / Float(totalBinCount) * 100).rounded()))
    }

    var isComplete: Bool {
        RoomScanCompletionPolicy.hasObservedCoverage(
            completeWalls: completeWallCount,
            totalWalls: wallCount,
            observedBins: observedBinCount,
            totalBins: totalBinCount
        )
    }
}

@MainActor
final class RoomScannerController: NSObject, ObservableObject {
    static var isSupported: Bool { RoomCaptureSession.isSupported }

    @Published private(set) var statusText = "Odayı yavaşça tarayın"
    @Published private(set) var scanSummaryText = "Zemin bekleniyor • Duvar bekleniyor"
    @Published private(set) var scanQualityText = "Tarama kalitesi ölçülüyor"
    @Published private(set) var hasUsableRoomGeometry = false
    @Published private(set) var isScanReady = false
    @Published private(set) var isProcessing = false
    @Published private(set) var exportSucceeded = false
    @Published private(set) var isUsingApprovedLiveScan = false
    @Published private(set) var failureMessage: String?

    let captureView: RoomCaptureView
    let roomJSONURL: URL

    private let roomStore: CapturedRoomStore
    private let configuration: RoomCaptureSession.Configuration = {
        var configuration = RoomCaptureSession.Configuration()
        configuration.isCoachingEnabled = true
        return configuration
    }()
    private let preservesSharedARSession: Bool
    private let minimumARFrameTimestamp: TimeInterval?
    private var shouldExport = true
    private var isSessionRunning = false
    private var isTornDown = false
    private var pendingArtifacts: CapturedRoomStore.StagedArtifacts?
    private var scanGeneration: UInt64 = 0
    private var stagingTask: Task<CapturedRoomStageOutcome, Never>?
    private var lastScanSummaryUpdateTime: TimeInterval = 0
    private var lastFrameQualityUpdateTime: TimeInterval = 0
    private var scanStartedAt: TimeInterval = 0
    private var geometryStableSince: TimeInterval?
    private var latestReadyRoom: CapturedRoom?
    private var approvedRoomAtFinish: CapturedRoom?
    private var lastWallMeasurements: [UUID: RoomScanGeometryMetrics.WallMeasurement] = [:]
    private var wallObservations: [UUID: RoomScanWallObservation] = [:]
    private var latestFrameQuality = RoomScanFrameQuality(
        trackingIsNormal: false,
        trackingGuidance: "Dünya takibi hazırlanıyor"
    )
    private var roomPlanGuidance: String?
    private var roomPlanGuidanceBlocksCompletion = false
    private var roomPlanGuidanceExpiresAt: TimeInterval = 0

    init(
        exportURL: URL,
        roomJSONURL: URL? = nil,
        arSession: ARSession? = nil,
        minimumARFrameTimestamp: TimeInterval? = nil
    ) {
        let store = CapturedRoomStore(
            modelURL: exportURL,
            roomJSONURL: roomJSONURL
        )
        self.roomStore = store
        self.roomJSONURL = store.roomJSONURL
        self.preservesSharedARSession = arSession != nil
        self.minimumARFrameTimestamp = minimumARFrameTimestamp
        if let arSession {
            self.captureView = RoomCaptureView(frame: .zero, arSession: arSession)
        } else {
            self.captureView = RoomCaptureView(frame: .zero)
        }
        super.init()
        captureView.captureSession.delegate = self
        captureView.delegate = self
    }

    init?(coder: NSCoder) {
        fatalError("RoomScannerController yalnızca init(exportURL:) ile oluşturulabilir")
    }

    func encode(with coder: NSCoder) {
        // RoomCaptureViewDelegate, NSCoding uyumluluğu ister. Bu controller arşivlenmez.
    }

    func start() {
        guard Self.isSupported else {
            recordFailure("RoomPlan için LiDAR destekli cihaz gerekli")
            return
        }
        guard !isTornDown, !isSessionRunning, !isProcessing else { return }

        scanGeneration &+= 1
        lastScanSummaryUpdateTime = 0
        lastFrameQualityUpdateTime = 0
        scanStartedAt = 0
        geometryStableSince = nil
        latestReadyRoom = nil
        approvedRoomAtFinish = nil
        lastWallMeasurements.removeAll(keepingCapacity: true)
        wallObservations.removeAll(keepingCapacity: true)
        latestFrameQuality = RoomScanFrameQuality(
            trackingIsNormal: false,
            trackingGuidance: "Dünya takibi hazırlanıyor"
        )
        roomPlanGuidance = nil
        roomPlanGuidanceBlocksCompletion = false
        roomPlanGuidanceExpiresAt = 0
        let isRetryingAfterFailure = failureMessage != nil
        stagingTask?.cancel()
        stagingTask = nil
        shouldExport = true
        discardPendingExport()
        exportSucceeded = false
        isUsingApprovedLiveScan = false
        failureMessage = nil
        scanSummaryText = "Zemin bekleniyor • Duvar bekleniyor"
        scanQualityText = "Tarama kalitesi ölçülüyor"
        hasUsableRoomGeometry = false
        isScanReady = false
        statusText = "Dünya takibi hazırlanıyor…"
        isProcessing = true
        if isRetryingAfterFailure,
           let arConfiguration = captureView.captureSession.arSession.configuration {
            captureView.captureSession.arSession.run(arConfiguration, options: [])
        }
        startWhenWorldTrackingIsReady(generation: scanGeneration, attempt: 0)
    }

    func finish() {
        guard isSessionRunning, !isProcessing else { return }
        guard isScanReady, let latestReadyRoom else {
            statusText = "Bitirmeden önce sarı kalite uyarısını gider"
            return
        }

        approvedRoomAtFinish = latestReadyRoom
        shouldExport = true
        isProcessing = true
        statusText = "3B oda modeli işleniyor..."
        isSessionRunning = false
        stopCaptureSession()
    }

    func cancel() {
        teardownForDismissal()
    }

    func commitExport() -> URL? {
        guard exportSucceeded, let pendingArtifacts else {
            recordFailure("Kaydedilecek oda modeli bulunamadı")
            return nil
        }

        do {
            try roomStore.commit(pendingArtifacts)
            self.pendingArtifacts = nil
            return roomStore.roomJSONURL
        } catch {
            recordFailure("Oda taraması kullanıma alınamadı: \(error.localizedDescription)")
            return nil
        }
    }

    private func recordFailure(_ message: String) {
        latestReadyRoom = nil
        approvedRoomAtFinish = nil
        scanGeneration &+= 1
        stagingTask?.cancel()
        stagingTask = nil
        shouldExport = false
        discardPendingExport()
        exportSucceeded = false
        isScanReady = false
        isProcessing = false
        isSessionRunning = false
        failureMessage = message
        statusText = message
    }

    private func startWhenWorldTrackingIsReady(generation: UInt64, attempt: Int) {
        guard scanGeneration == generation,
              !isTornDown,
              shouldExport,
              isProcessing,
              !isSessionRunning else { return }

        let currentFrame = captureView.captureSession.arSession.currentFrame
        let trackingState = currentFrame?.camera.trackingState
        let hasFreshFrame = RoomScanStartPolicy.hasFreshFrame(
            current: currentFrame?.timestamp,
            minimum: minimumARFrameTimestamp
        )
        if case .normal? = trackingState, hasFreshFrame {
            isProcessing = false
            isSessionRunning = true
            scanStartedAt = ProcessInfo.processInfo.systemUptime
            statusText = "Önce zemini, sonra duvarları yavaşça tarayın"
            captureView.captureSession.run(configuration: configuration)
            return
        }

        guard attempt < 32 else {
            recordFailure(
                "Dünya takibi hazır olmadı. Kamerayı kitaplık veya köşe gibi detaylı bir alana tutup Tekrar Tara'ya basın"
            )
            return
        }

        if let trackingState {
            switch trackingState {
            case .limited(.excessiveMotion):
                statusText = "Telefonu sabit ve yavaş tutun…"
            case .limited(.insufficientFeatures):
                statusText = "Kamerayı detaylı ve aydınlık bir alana yöneltin…"
            case .limited(.relocalizing):
                statusText = "Oda koordinatları yeniden bulunuyor…"
            case .limited(.initializing):
                statusText = "Dünya takibi hazırlanıyor…"
            case .notAvailable:
                statusText = "Kamera takibi yeniden başlatılıyor…"
            case .normal:
                break
            @unknown default:
                statusText = "Dünya takibi hazırlanıyor…"
            }
        } else {
            statusText = "Dünya takibi hazırlanıyor…"
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.startWhenWorldTrackingIsReady(generation: generation, attempt: attempt + 1)
        }
    }

    private func scanFailureMessage(for error: Error) -> String {
        guard let captureError = error as? RoomCaptureSession.CaptureError else {
            return "Tarama hatası: \(error.localizedDescription)"
        }
        switch captureError {
        case .worldTrackingFailure:
            return "Dünya takibi kesildi. Telefonu yavaşlatın, detaylı bir yüzeye yöneltip Tekrar Tara'ya basın"
        case .deviceTooHot:
            return "iPhone çok ısındı. Cihaz soğuduktan sonra tekrar tarayın"
        case .exceedSceneSizeLimit:
            return "Tarama alanı RoomPlan sınırını aştı. Odayı daha küçük bölümler halinde tarayın"
        case .deviceNotSupported:
            return "Bu cihaz RoomPlan oda taramasını desteklemiyor"
        case .invalidARConfiguration:
            return "AR yapılandırması RoomPlan ile uyumlu değil. Taramayı kapatıp yeniden açın"
        case .internalError:
            return "RoomPlan geçici bir hata verdi. Taramayı yeniden deneyin"
        @unknown default:
            return "Tarama hatası: \(error.localizedDescription)"
        }
    }

    private func discardPendingExport() {
        guard let pendingArtifacts else { return }
        roomStore.discard(pendingArtifacts)
        self.pendingArtifacts = nil
    }

    private func wallGeometryChanged(
        from previous: [UUID: RoomScanGeometryMetrics.WallMeasurement],
        to current: [UUID: RoomScanGeometryMetrics.WallMeasurement]
    ) -> Bool {
        guard Set(previous.keys) == Set(current.keys) else { return true }
        for (identifier, measurement) in current {
            guard let old = previous[identifier] else { return true }
            if abs(old.width - measurement.width) >= 0.06
                || abs(old.height - measurement.height) >= 0.06
                || simd_distance(old.center, measurement.center) >= 0.04
                || abs(simd_dot(old.normal, measurement.normal)) < cos(Float.pi / 60) {
                return true
            }
        }
        return false
    }

    private func updateWallObservation(
        room: CapturedRoom,
        cameraTransform: simd_float4x4?
    ) {
        guard let cameraTransform, latestFrameQuality.trackingIsNormal else { return }
        let cameraPosition = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        let rawForward = SIMD3<Float>(
            -cameraTransform.columns.2.x,
            -cameraTransform.columns.2.y,
            -cameraTransform.columns.2.z
        )
        let forwardLength = simd_length(rawForward)
        guard forwardLength > 0.000_001 else { return }
        let cameraForward = rawForward / forwardLength

        var nearest: (
            id: UUID,
            bin: Int,
            distance: Float,
            width: Float,
            height: Float,
            center: SIMD3<Float>,
            normal: SIMD3<Float>
        )?

        for wall in room.walls {
            let width = wall.dimensions.x
            let height = wall.dimensions.y
            guard width.isFinite, height.isFinite, width >= 0.55, height >= 1 else { continue }

            let center = SIMD3<Float>(
                wall.transform.columns.3.x,
                wall.transform.columns.3.y,
                wall.transform.columns.3.z
            )
            let rawNormal = SIMD3<Float>(
                wall.transform.columns.2.x,
                wall.transform.columns.2.y,
                wall.transform.columns.2.z
            )
            let normalLength = simd_length(rawNormal)
            guard normalLength > 0.000_001 else { continue }
            let normal = rawNormal / normalLength
            let denominator = simd_dot(cameraForward, normal)
            guard abs(denominator) >= 0.28 else { continue }

            let distance = simd_dot(center - cameraPosition, normal) / denominator
            guard distance.isFinite, (0.35...5.5).contains(distance) else { continue }
            let worldHit = cameraPosition + cameraForward * distance
            let localHit = wall.transform.inverse * SIMD4<Float>(worldHit.x, worldHit.y, worldHit.z, 1)
            guard localHit.x.isFinite, localHit.y.isFinite,
                  abs(localHit.x) <= width * 0.52,
                  abs(localHit.y) <= height * 0.52 else { continue }

            let normalizedX = min(1, max(0, localHit.x / width + 0.5))
            let normalizedY = min(1, max(0, localHit.y / height + 0.5))
            guard let bin = RoomScanObservationPolicy.bin(
                normalizedX: normalizedX,
                normalizedY: normalizedY
            ) else { continue }

            if let nearest, distance >= nearest.distance { continue }
            nearest = (wall.identifier, bin, distance, width, height, center, normal)
        }

        guard let nearest else { return }
        if let existing = wallObservations[nearest.id] {
            let widthChange = abs(existing.referenceWidth - nearest.width)
                / max(existing.referenceWidth, nearest.width)
            let heightChange = abs(existing.referenceHeight - nearest.height)
                / max(existing.referenceHeight, nearest.height)
            let centerShift = simd_distance(existing.referenceCenter, nearest.center)
            let orientationAgreement = abs(simd_dot(existing.referenceNormal, nearest.normal))
            if widthChange > 0.25 || heightChange > 0.25 || centerShift > 0.25
                || orientationAgreement < cos(Float.pi / 18) {
                wallObservations[nearest.id] = RoomScanWallObservation(
                    referenceWidth: nearest.width,
                    referenceHeight: nearest.height,
                    referenceCenter: nearest.center,
                    referenceNormal: nearest.normal,
                    bins: [nearest.bin]
                )
            } else {
                var updated = existing
                updated.bins.insert(nearest.bin)
                wallObservations[nearest.id] = updated
            }
        } else {
            wallObservations[nearest.id] = RoomScanWallObservation(
                referenceWidth: nearest.width,
                referenceHeight: nearest.height,
                referenceCenter: nearest.center,
                referenceNormal: nearest.normal,
                bins: [nearest.bin]
            )
        }
    }

    private func observationProgress(
        metrics: RoomScanGeometryMetrics
    ) -> RoomScanObservationProgress {
        var completeWallCount = 0
        var observedBinCount = 0
        for identifier in metrics.walls.keys {
            let bins = wallObservations[identifier]?.bins ?? []
            observedBinCount += min(6, bins.count)
            if RoomScanObservationPolicy.wallIsComplete(bins: bins) {
                completeWallCount += 1
            }
        }
        return RoomScanObservationProgress(
            completeWallCount: completeWallCount,
            wallCount: metrics.walls.count,
            observedBinCount: observedBinCount,
            totalBinCount: metrics.walls.count * 6
        )
    }

    private func refreshScanQuality(
        metrics: RoomScanGeometryMetrics,
        now: TimeInterval
    ) {
        if roomPlanGuidanceExpiresAt > 0, now >= roomPlanGuidanceExpiresAt {
            roomPlanGuidance = nil
            roomPlanGuidanceBlocksCompletion = false
            roomPlanGuidanceExpiresAt = 0
        }
        let geometryChanged = wallGeometryChanged(
            from: lastWallMeasurements,
            to: metrics.walls
        )
        if geometryChanged {
            lastWallMeasurements = metrics.walls
            geometryStableSince = now
        } else if geometryStableSince == nil, !metrics.walls.isEmpty {
            geometryStableSince = now
        }

        let geometryIsStable = geometryStableSince.map { now - $0 >= 1.5 } ?? false
        let scanHasSettled = scanStartedAt > 0 && now - scanStartedAt >= 12
        let hasWallCoverage = metrics.hasCoverage
        let observedProgress = observationProgress(metrics: metrics)

        hasUsableRoomGeometry = metrics.hasUsableGeometry

        isScanReady = hasUsableRoomGeometry
            && hasWallCoverage
            && observedProgress.isComplete
            && geometryIsStable
            && scanHasSettled
            && latestFrameQuality.trackingIsNormal
            && !roomPlanGuidanceBlocksCompletion

        if let trackingGuidance = latestFrameQuality.trackingGuidance {
            statusText = trackingGuidance
            scanQualityText = "Takip kararsız • Ölçüm bekletiliyor"
            return
        }
        if let roomPlanGuidance {
            statusText = roomPlanGuidance
            scanQualityText = "RoomPlan yönlendirmesini tamamla"
            return
        }
        if metrics.floorCount == 0 {
            statusText = "Kamerayı aşağı eğip zemini yavaşça tara"
            scanQualityText = "Zemin henüz doğrulanmadı"
        } else if metrics.substantialWallCount == 0 {
            statusText = "Zemin bulundu; duvara 1–3 metre mesafeden yaklaş"
            scanQualityText = "Tam boy bir duvar bekleniyor"
        } else if !hasWallCoverage {
            statusText = "Duvarın iki ucunu ve komşu köşeyi çapraz açıyla tara"
            let cornerPercent = Int((metrics.connectedEndpointRatio * 100).rounded())
            scanQualityText = "Duvar çevrimi eksik • Köşe bağlantısı %"
                + String(cornerPercent)
        } else if !observedProgress.isComplete {
            statusText = "Her duvarın sol, orta, sağ; alt ve üst bölgelerine yavaşça bak"
            scanQualityText = "Doğrulanan duvar \(observedProgress.completeWallCount)/4 • Gerçek görüş %\(observedProgress.percentage)"
        } else if !geometryIsStable || !scanHasSettled {
            statusText = "Ölçünün tamamlanması için telefonu kısa süre sabit tut"
            scanQualityText = "Duvarlar bulundu • Ölçüler kararlı hale geliyor"
        } else {
            statusText = "Tarama kararlı; istersen eksik alanları tamamla veya bitir"
            scanQualityText = "Işık, takip ve duvar kapsaması uygun"
        }
    }

    private func acceptFrameQualityMeasurement(_ measurement: RoomScanFrameQuality) {
        latestFrameQuality = measurement
    }

    func teardownForDismissal(discardPendingExport shouldDiscard: Bool = true) {
        guard !isTornDown else { return }
        isTornDown = true
        latestReadyRoom = nil
        approvedRoomAtFinish = nil
        scanGeneration &+= 1
        stagingTask?.cancel()
        stagingTask = nil
        shouldExport = false
        isProcessing = false
        if isSessionRunning {
            isSessionRunning = false
            stopCaptureSession()
        }
        captureView.delegate = nil
        captureView.captureSession.delegate = nil
        if shouldDiscard {
            discardPendingExport()
        }
    }

    private func stopCaptureSession() {
        if preservesSharedARSession {
            captureView.captureSession.stop(pauseARSession: false)
        } else {
            captureView.captureSession.stop()
        }
    }
}

extension RoomScannerController: @preconcurrency RoomCaptureSessionDelegate {
    func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        // RoomPlan can publish several semantic snapshots per video frame. Updating
        // SwiftUI for every snapshot floods the main queue and makes the native white
        // scan lines lag behind the camera. The geometry still updates at full speed;
        // only the small text summary is throttled.
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastScanSummaryUpdateTime >= 0.25 else { return }
        lastScanSummaryUpdateTime = now
        let metrics = RoomScanGeometryMetrics(room: room)
        let currentFrame = session.arSession.currentFrame
        if now - lastFrameQualityUpdateTime >= 0.75,
           let frame = currentFrame {
            lastFrameQualityUpdateTime = now
            acceptFrameQualityMeasurement(RoomScanFrameQuality.measureTracking(frame: frame))
        }
        let cameraTransform = currentFrame?.camera.transform
        let generation = scanGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.scanGeneration == generation,
                  self.shouldExport,
                  self.isSessionRunning else { return }
            self.updateWallObservation(room: room, cameraTransform: cameraTransform)
            self.scanSummaryText = "Zemin \(metrics.floorCount) • Duvar \(metrics.wallCount) • Nesne \(metrics.objectCount)"
            self.refreshScanQuality(metrics: metrics, now: now)
            self.latestReadyRoom = self.isScanReady ? room : nil
        }
    }

    func captureSession(
        _ session: RoomCaptureSession,
        didProvide instruction: RoomCaptureSession.Instruction
    ) {
        let guidance: String?
        let blocksCompletion: Bool
        switch instruction {
        case .normal:
            guidance = nil
            blocksCompletion = false
        case .moveCloseToWall:
            guidance = "Duvar ayrıntısı için biraz yaklaş; yaklaşık 1–3 metre uzakta kal"
            blocksCompletion = true
        case .moveAwayFromWall:
            guidance = "Duvarın tamamını görebilmek için biraz geri çekil"
            blocksCompletion = true
        case .turnOnLight:
            guidance = "RoomPlan daha fazla ışık istiyor; yaygın oda ışığını artır"
            blocksCompletion = true
        case .slowDown:
            guidance = "Telefonu yavaşlat; her duvar ve köşede kısa süre dur"
            blocksCompletion = true
        case .lowTexture:
            guidance = "Düz yüzeyde özellik az; duvarı köşe veya kapıyla birlikte çaprazdan tara"
            blocksCompletion = true
        @unknown default:
            guidance = "Tarama açısını değiştirip telefonu yavaşça hareket ettir"
            blocksCompletion = true
        }

        let generation = scanGeneration
        let expiresAt = guidance == nil
            ? 0
            : ProcessInfo.processInfo.systemUptime + 2.5
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.scanGeneration == generation,
                  self.shouldExport,
                  self.isSessionRunning else { return }
            self.roomPlanGuidance = guidance
            self.roomPlanGuidanceBlocksCompletion = blocksCompletion
            self.roomPlanGuidanceExpiresAt = expiresAt
            if let guidance {
                self.statusText = guidance
                self.scanQualityText = "RoomPlan yönlendirmesi etkin"
                self.isScanReady = false
            }
        }
    }

    func captureSession(
        _ session: RoomCaptureSession,
        didEndWith data: CapturedRoomData,
        error: Error?
    ) {
        guard let error else { return }
        let message = scanFailureMessage(for: error)
        let generation = scanGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.scanGeneration == generation,
                  self.shouldExport else { return }
            self.recordFailure(message)
        }
    }
}

extension RoomScannerController: @preconcurrency RoomCaptureViewDelegate {
    func captureView(
        shouldPresent roomDataForProcessing: CapturedRoomData,
        error: Error?
    ) -> Bool {
        guard shouldExport else { return false }
        guard let error else { return true }

        let message = scanFailureMessage(for: error)
        let generation = scanGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.scanGeneration == generation,
                  self.shouldExport else { return }
            self.recordFailure(message)
        }
        return false
    }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        guard shouldExport, isProcessing, !isSessionRunning, !isTornDown else { return }

        if let error {
            recordFailure(scanFailureMessage(for: error))
            return
        }
        let processedMetrics = RoomScanGeometryMetrics(room: processedResult)
        let approvedMetrics = approvedRoomAtFinish.map { RoomScanGeometryMetrics(room: $0) }
        let processedPreservesApprovedRoom = approvedMetrics.map {
            RoomScanCompletionPolicy.preservesRoomShape(
                processedWalls: processedMetrics.substantialWallCount,
                approvedWalls: $0.substantialWallCount,
                processedDirections: processedMetrics.directionCount,
                approvedDirections: $0.directionCount,
                processedSpan: processedMetrics.totalWallSpan,
                approvedSpan: $0.totalWallSpan,
                processedConnections: processedMetrics.connectedEndpointRatio,
                approvedConnections: $0.connectedEndpointRatio
            )
        } ?? false
        let choice = RoomScanCompletionPolicy.output(
            approvedAtFinish: approvedRoomAtFinish != nil,
            processedUsable: processedMetrics.hasUsableGeometry
                && processedPreservesApprovedRoom,
            liveUsable: approvedMetrics?.hasUsableGeometry ?? false
        )
        let roomToSave: CapturedRoom
        let completionMessage: String
        switch choice {
        case .processed:
            roomToSave = processedResult
            completionMessage = processedMetrics.hasCoverage
                ? "Oda modeli ve mekân verisi hazır"
                : "Oda kullanılabilir; işleme sonrası bazı sınırlar değişti. Kullanmadan önce önizlemeyi kontrol et"
        case .approvedLive:
            guard let approvedRoomAtFinish else { return }
            roomToSave = approvedRoomAtFinish
            completionMessage = "İşlenmiş model eksik; bitirirken onayladığın canlı tarama korunuyor. Önizleme farklı olabilir"
        case .reject:
            recordFailure("Kaydedilebilir zemin ve duvar verisi yok; önceki kayıt değiştirilmedi")
            return
        }
        isUsingApprovedLiveScan = choice == .approvedLive
        let savedMetrics = RoomScanGeometryMetrics(room: roomToSave)
        scanSummaryText = "Zemin \(savedMetrics.floorCount) • Duvar \(savedMetrics.wallCount) • Nesne \(savedMetrics.objectCount)"
        isScanReady = choice == .processed && processedMetrics.hasCoverage
        scanQualityText = isScanReady ? "Onaylanan oda hazır" : completionMessage

        let modelURL = roomStore.modelURL
        let roomJSONURL = roomStore.roomJSONURL
        scanGeneration &+= 1
        let generation = scanGeneration
        stagingTask?.cancel()

        statusText = "Oda verisi güvenli biçimde hazırlanıyor..."
        let worker = Task.detached(priority: .userInitiated) {
            guard !Task.isCancelled else {
                return CapturedRoomStageOutcome(artifacts: nil, failureMessage: nil)
            }
            do {
                let store = CapturedRoomStore(
                    modelURL: modelURL,
                    roomJSONURL: roomJSONURL
                )
                let artifacts = try store.stage(roomToSave)
                guard !Task.isCancelled else {
                    store.discard(artifacts)
                    return CapturedRoomStageOutcome(artifacts: nil, failureMessage: nil)
                }
                return CapturedRoomStageOutcome(
                    artifacts: artifacts,
                    failureMessage: nil
                )
            } catch {
                return CapturedRoomStageOutcome(
                    artifacts: nil,
                    failureMessage: error.localizedDescription
                )
            }
        }
        stagingTask = worker

        Task { @MainActor [weak self] in
            let outcome = await worker.value
            guard let self else {
                if let artifacts = outcome.artifacts {
                    CapturedRoomStore(
                        modelURL: modelURL,
                        roomJSONURL: roomJSONURL
                    ).discard(artifacts)
                }
                return
            }
            guard self.scanGeneration == generation,
                  self.shouldExport,
                  !self.isTornDown else {
                if let artifacts = outcome.artifacts {
                    self.roomStore.discard(artifacts)
                }
                return
            }
            self.stagingTask = nil

            self.discardPendingExport()
            if let artifacts = outcome.artifacts {
                self.pendingArtifacts = artifacts
                self.statusText = completionMessage
                self.exportSucceeded = true
                self.failureMessage = nil
                self.isProcessing = false
            } else if let failureMessage = outcome.failureMessage {
                self.recordFailure(
                    "Oda verisi dışa aktarılamadı: " + failureMessage
                )
            }
        }
    }
}

struct RoomScannerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner: RoomScannerController
    @State private var didReportResult = false
    private let onComplete: (RoomScanResult) -> Void

    init(
        exportURL: URL,
        roomJSONURL: URL? = nil,
        arSession: ARSession? = nil,
        minimumARFrameTimestamp: TimeInterval? = nil,
        onComplete: @escaping (RoomScanResult) -> Void = { _ in }
    ) {
        self.onComplete = onComplete
        _scanner = StateObject(
            wrappedValue: RoomScannerController(
                exportURL: exportURL,
                roomJSONURL: roomJSONURL,
                arSession: arSession,
                minimumARFrameTimestamp: minimumARFrameTimestamp
            )
        )
    }

    var body: some View {
        ZStack {
            RoomCaptureContainer(controller: scanner)
                .ignoresSafeArea()

            VStack {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(scanner.statusText)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        if scanner.isProcessing {
                            ProgressView()
                        }
                        Button {
                            reportAndDismiss(
                                scanner.failureMessage.map(RoomScanResult.failure) ?? .cancelled
                            )
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                        }
                    }
                    Label(
                        scanner.scanSummaryText,
                        systemImage: scanner.isScanReady
                            ? "checkmark.circle.fill"
                            : "viewfinder.circle"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(scanner.isScanReady ? .green : .yellow)
                    Label(
                        scanner.scanQualityText,
                        systemImage: scanner.isScanReady
                            ? "checkmark.shield.fill"
                            : "exclamationmark.triangle.fill"
                    )
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(scanner.isScanReady ? .green : .yellow)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

                Spacer()

                if scanner.exportSucceeded {
                    Button(scanner.isUsingApprovedLiveScan ? "Onaylanan Canlı Taramayı Kullan" : "Taramayı Kullan") {
                        guard let url = scanner.commitExport() else { return }
                        reportAndDismiss(.success(url))
                    }
                        .buttonStyle(CineARPrimaryButtonStyle(color: .green))
                } else if scanner.failureMessage != nil {
                    HStack(spacing: 12) {
                        if RoomScannerController.isSupported {
                            Button("Tekrar Tara") { scanner.start() }
                                .buttonStyle(CineARPrimaryButtonStyle(color: .blue))
                        }
                        Button("Kapat") {
                            reportAndDismiss(
                                scanner.failureMessage.map(RoomScanResult.failure) ?? .cancelled
                            )
                        }
                        .buttonStyle(CineARPrimaryButtonStyle(color: .red))
                    }
                } else {
                    Button {
                        scanner.finish()
                    } label: {
                        Label("Taramayı Bitir", systemImage: "checkmark.circle.fill")
                    }
                    .disabled(
                        scanner.isProcessing
                            || !RoomScannerController.isSupported
                            || !scanner.isScanReady
                    )
                    .buttonStyle(CineARPrimaryButtonStyle(color: .blue))
                }
            }
            .padding()
        }
        .onAppear { scanner.start() }
        .onDisappear {
            guard !didReportResult else { return }
            didReportResult = true
            let result = scanner.failureMessage.map(RoomScanResult.failure) ?? .cancelled
            scanner.cancel()
            onComplete(result)
        }
    }

    private func reportAndDismiss(_ result: RoomScanResult) {
        guard !didReportResult else { return }
        didReportResult = true

        switch result {
        case .success:
            scanner.teardownForDismissal(discardPendingExport: false)
        case .cancelled, .failure:
            scanner.cancel()
        }
        onComplete(result)
        dismiss()
    }
}

private struct RoomCaptureContainer: UIViewRepresentable {
    let controller: RoomScannerController

    final class Coordinator {
        weak var controller: RoomScannerController?

        init(controller: RoomScannerController) {
            self.controller = controller
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> RoomCaptureView {
        controller.captureView
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}

    static func dismantleUIView(_ uiView: RoomCaptureView, coordinator: Coordinator) {
        coordinator.controller?.teardownForDismissal()
    }
}

struct CineARPrimaryButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(color.opacity(configuration.isPressed ? 0.65 : 0.95), in: Capsule())
    }
}
