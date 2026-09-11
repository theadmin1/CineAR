import ARKit
import Foundation
import RoomPlan
import SwiftUI
import UIKit

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
    let floorCount: Int
    let wallCount: Int
    let objectCount: Int
    let usableWallCount: Int
    let totalWallSpan: Float

    var hasUsableGeometry: Bool {
        RoomScanCompletionPolicy.hasUsablePartialScan(
            floors: floorCount,
            walls: usableWallCount,
            objects: objectCount
        )
    }
    var hasCoverage: Bool {
        usableWallCount >= 4 && totalWallSpan >= 2.4
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

        let usableWalls = room.walls.filter { wall in
            wall.dimensions.x.isFinite && wall.dimensions.y.isFinite
                && wall.dimensions.x >= 0.10 && wall.dimensions.y >= 0.30
                && (0..<4).allSatisfy { column in
                    (0..<4).allSatisfy { row in wall.transform[column][row].isFinite }
                }
        }
        usableWallCount = usableWalls.count
        totalWallSpan = usableWalls.reduce(0) { $0 + $1.dimensions.x }
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
    private var latestReadyRoom: CapturedRoom?
    private var approvedRoomAtFinish: CapturedRoom?
    private var latestFrameQuality = RoomScanFrameQuality(
        trackingIsNormal: false,
        trackingGuidance: "Dünya takibi hazırlanıyor"
    )
    private var roomPlanGuidance: String?
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
        latestReadyRoom = nil
        approvedRoomAtFinish = nil
        latestFrameQuality = RoomScanFrameQuality(
            trackingIsNormal: false,
            trackingGuidance: "Dünya takibi hazırlanıyor"
        )
        roomPlanGuidance = nil
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
        approvedRoomAtFinish = latestReadyRoom
        shouldExport = true
        isProcessing = true
        statusText = latestReadyRoom == nil
            ? "Mevcut kısmi tarama sonlandırılıyor..."
            : "Taranan kısımlar 3B modele işleniyor..."
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
            statusText = "Önce zemini, sonra istediğin duvarları yavaşça tarayın"
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

    private func refreshScanQuality(
        metrics: RoomScanGeometryMetrics,
        now: TimeInterval
    ) {
        if roomPlanGuidanceExpiresAt > 0, now >= roomPlanGuidanceExpiresAt {
            roomPlanGuidance = nil
            roomPlanGuidanceExpiresAt = 0
        }

        let isUsingRetainedSnapshot = !metrics.hasUsableGeometry && latestReadyRoom != nil
        hasUsableRoomGeometry = metrics.hasUsableGeometry || latestReadyRoom != nil

        // RoomPlan is allowed to return an open or partial outline. Once there is
        // a valid floor and wall, finishing must remain available even while the
        // framework is still suggesting a better angle or revising a corner.
        isScanReady = hasUsableRoomGeometry

        if isUsingRetainedSnapshot {
            statusText = "RoomPlan duvarları güncelliyor; son geçerli taranan bölüm korunuyor"
            scanQualityText = "Kısmi tarama kullanılabilir • Bitirebilir veya devam edebilirsin"
            return
        }

        if let trackingGuidance = latestFrameQuality.trackingGuidance {
            statusText = trackingGuidance
            scanQualityText = "Takip kararsız • Ölçüm bekletiliyor"
            return
        }
        if let roomPlanGuidance {
            statusText = roomPlanGuidance
            scanQualityText = isScanReady
                ? "Taranan bölüm kullanılabilir • İstersen devam et veya bitir"
                : "RoomPlan yönlendirmesini izle"
            return
        }
        if metrics.floorCount == 0 {
            statusText = "Kamerayı aşağı eğip zemini yavaşça tara"
            scanQualityText = "Zemin henüz doğrulanmadı"
        } else if metrics.usableWallCount == 0 {
            statusText = "Zemin bulundu; duvara 1–3 metre mesafeden yaklaş"
            scanQualityText = "Geçerli bir duvar parçası bekleniyor"
        } else if !metrics.hasCoverage {
            statusText = "Taranan bölüm hazır; başka duvar ekleyebilir veya şimdi bitirebilirsin"
            scanQualityText = "Kısmi tarama kullanılabilir • Duvar \(metrics.usableWallCount)"
        } else {
            statusText = "Taranan oda hazır; istersen eksik alanları tamamla veya bitir"
            scanQualityText = "Oda taraması kullanılabilir"
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
        let generation = scanGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.scanGeneration == generation,
                  self.shouldExport,
                  self.isSessionRunning else { return }
            // Do not throw away the last valid partial scan when RoomPlan emits a
            // transient snapshot while it is joining or revising adjacent walls.
            if metrics.hasUsableGeometry {
                self.latestReadyRoom = room
                self.scanSummaryText = "Zemin \(metrics.floorCount) • Duvar \(metrics.wallCount) • Nesne \(metrics.objectCount)"
            } else if self.latestReadyRoom == nil {
                self.scanSummaryText = "Zemin \(metrics.floorCount) • Duvar \(metrics.wallCount) • Nesne \(metrics.objectCount)"
            }
            self.refreshScanQuality(metrics: metrics, now: now)
        }
    }

    func captureSession(
        _ session: RoomCaptureSession,
        didProvide instruction: RoomCaptureSession.Instruction
    ) {
        let guidance: String?
        switch instruction {
        case .normal:
            guidance = nil
        case .moveCloseToWall:
            guidance = "Duvar ayrıntısı için biraz yaklaş; yaklaşık 1–3 metre uzakta kal"
        case .moveAwayFromWall:
            guidance = "Duvarın tamamını görebilmek için biraz geri çekil"
        case .turnOnLight:
            guidance = "RoomPlan daha fazla ışık istiyor; yaygın oda ışığını artır"
        case .slowDown:
            guidance = "Telefonu yavaşlat; her duvar ve köşede kısa süre dur"
        case .lowTexture:
            guidance = "Düz yüzeyde özellik az; duvarı köşe veya kapıyla birlikte çaprazdan tara"
        @unknown default:
            guidance = "Tarama açısını değiştirip telefonu yavaşça hareket ettir"
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
            self.roomPlanGuidanceExpiresAt = expiresAt
            if let guidance {
                self.statusText = guidance
                self.scanQualityText = self.isScanReady
                    ? "Taranan bölüm kullanılabilir • Öneri isteğe bağlı"
                    : "RoomPlan yönlendirmesi etkin"
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
        let processedPreservesScannedWalls = approvedMetrics.map { approved in
            approved.totalWallSpan <= 0
                || RoomScanCompletionPolicy.preservesWallSpan(
                    processed: processedMetrics.totalWallSpan,
                    approved: approved.totalWallSpan
                )
        } ?? true
        let choice = RoomScanCompletionPolicy.output(
            approvedAtFinish: approvedRoomAtFinish != nil,
            processedUsable: processedMetrics.hasUsableGeometry
                && processedPreservesScannedWalls,
            liveUsable: approvedMetrics?.hasUsableGeometry ?? false
        )
        let roomToSave: CapturedRoom
        let completionMessage: String
        switch choice {
        case .processed:
            roomToSave = processedResult
            completionMessage = processedMetrics.hasCoverage
                ? "Oda modeli ve mekân verisi hazır"
                : "Taranan bölüm hazır; kapalı oda çevrimi gerekmiyor"
        case .approvedLive:
            guard let approvedRoomAtFinish else { return }
            roomToSave = approvedRoomAtFinish
            completionMessage = "İşlenmiş model eksik; bitirirken onayladığın canlı tarama korunuyor. Önizleme farklı olabilir"
        case .reject:
            recordFailure("Tarama sonlandırıldı ancak kaydedilebilir bir yüzey veya nesne bulunamadı; önceki kayıt değiştirilmedi")
            return
        }
        isUsingApprovedLiveScan = choice == .approvedLive
        let savedMetrics = RoomScanGeometryMetrics(room: roomToSave)
        scanSummaryText = "Zemin \(savedMetrics.floorCount) • Duvar \(savedMetrics.wallCount) • Nesne \(savedMetrics.objectCount)"
        isScanReady = savedMetrics.hasUsableGeometry
        scanQualityText = completionMessage

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
