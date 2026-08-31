import ARKit
import AVFoundation
import Combine
import Foundation
import ImageIO
import RealityKit
import RoomPlan
import Speech
import simd
import SwiftUI
import UIKit
import Vision

struct SceneObjectSummary: Identifiable, Equatable {
    let id: UUID
    let title: String
    let symbol: String
    let detail: String
    let isLiveEffect: Bool
}

@MainActor
final class ARSessionController: NSObject, ObservableObject {
    @Published var selectedProp: PropKind = .crate
    @Published var selectedEntityID: UUID?
    @Published var statusText = "Kamerayı hareket ettirerek alanı tara"
    @Published var trackingColor: Color = .yellow
    @Published private(set) var isRecording = false
    @Published private(set) var isRecordingTransitioning = false
    @Published var lastRecordingURL: URL?
    @Published private(set) var importedAssetURLs: [URL] = []
    @Published var selectedAssetURL: URL?
    @Published private(set) var activeRealityThemeID: RealityThemeID?
    @Published private(set) var hasScannedRoom = false
    @Published private(set) var isARReady = false
    @Published private(set) var isPlacingProp = false
    @Published private(set) var isRoomOutlineVisible = false
    @Published private(set) var selectedLightSettings: VirtualLightSettings?
    @Published private(set) var isAimingLight = false
    @Published private(set) var placementSurfaceMessage = "Yüzey ölçülüyor"
    @Published private(set) var placementSurfaceColor: Color = .yellow
    @Published private(set) var placementReticlePoint: CGPoint?
    @Published private(set) var aiEnhancementEnabled = false
    @Published private(set) var aiServerAddress = ""
    @Published private(set) var aiEnhancementStatus: AIEnhancementStatus = .disabled
    @Published private(set) var sceneObjects: [SceneObjectSummary] = []
    @Published private(set) var savedPlaces: [SavedPlaceSummary] = []
    @Published private(set) var isLiveAppleEnabled = false
    @Published private(set) var isListeningForCGICommands = false
    @Published private(set) var liveCGIStatus = "Hazır efekt seç veya Türkçe komut ver"

    private(set) var arView: ARView?
    private let projectStore = SceneProjectStore()
    private let recorder = ProfessionalRecorder()
    private let roomRealityRenderer = RoomRealityRenderer(
        assetProvider: BundledRoomRealityAssetProvider()
    )
    private let manualAssetProvider = BundledRoomRealityAssetProvider()
    private let aiEnhancementClient = AIEnhancementClient()
    private let aiDepthRenderer = AIDepthOcclusionRenderer()
    private var renderedAnchorIDs = Set<UUID>()
    private var renderedAnchorIDByPlacementID: [UUID: UUID] = [:]
    private var knownPropAnchorIDs = Set<UUID>()
    private var supersededPropAnchorIDs = Set<UUID>()
    private var managedPropAnchorsByPlacementID: [UUID: ARAnchor] = [:]
    private var renderedEntities: [UUID: ModelEntity] = [:]
    private var renderedLights: [UUID: SpotLight] = [:]
    private var renderedLightEmitters: [UUID: ModelEntity] = [:]
    private var renderedLightFootprints: [UUID: AnchorEntity] = [:]
    private var loadingEntityIDs = Set<UUID>()
    private var assetLoadSubscriptions: [UUID: AnyCancellable] = [:]
    private var renderGeneration: UInt64 = 0
    private weak var coachingOverlay: ARCoachingOverlayView?
    private var isSavingWorldMap = false
    private var recordingPhase: RecordingPhase = .idle
    private var roomCoordinateSpaceIsActive = false
    private var preferredRealityThemeID: RealityThemeID?
    private var isSessionInterrupted = false
    private var shouldRestoreRoomRealityAfterInterruption = false
    private var configurationBeforeInterruption: ARConfiguration?
    private var isRoomScanActive = false
    private var didAttemptSessionFailureRecovery = false
    private var realityThemeToRestoreAfterScan: RealityThemeID?
    private var pendingRealityThemeAfterScan: RealityThemeID?
    private var isPostScanThemeScheduled = false
    private var postScanThemeGeneration: UInt64 = 0
    private var isRoomRealityRendering = false
    private var lastKnownFloorY: Float?
    private var lastKnownCeilingY: Float?
    private let floorSurfaceTracker = FloorSurfaceTracker()
    private var lastPlacementGuidanceTimestamp: TimeInterval = 0
    private var lastProjectorRefreshTimestamp: TimeInterval = 0
    private var shouldSaveWorldMapWhenReady = false
    private var shouldShowRoomOutlineWhenReady = false
    private var readinessRecoveryGeneration: UInt64 = 0
    private var pendingAutoSaveAnchorIDs = Set<UUID>()
    private var shouldArchiveAfterNextSave = false
    private var pendingArchiveName: String?
    private var bloodWaterfallParticles: [UUID: [BloodWaterfallParticle]] = [:]
    private var liveAppleAnchor: AnchorEntity?
    private var filteredLiveApplePosition: SIMD3<Float>?
    private var lastLiveAppleObservationTimestamp: TimeInterval = 0
    private var lastHandDetectionTimestamp: TimeInterval = 0
    private var handDetectionInFlight = false
    private let handDetectionQueue = DispatchQueue(
        label: "com.cinear.hand-pose",
        qos: .userInitiated
    )
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "tr_TR"))
    private let speechAudioEngine = AVAudioEngine()
    private var speechRequest: SFSpeechAudioBufferRecognitionRequest?
    private var speechTask: SFSpeechRecognitionTask?
    private var lastProcessedCGITranscript = ""
    private var hasSpeechInputTap = false

    private static let realityThemeDefaultsKey = "cinear.activeRealityTheme"
    private static let aiEnabledDefaultsKey = "cinear.aiDepth.enabled"
    private static let aiServerDefaultsKey = "cinear.aiDepth.server"
    // The user's verified RTX server on the current LAN. This is a real initial
    // value, not a TextField placeholder; it remains editable if DHCP changes it.
    private static let defaultAIServerAddress = "http://192.168.1.12:8765"
    private static let obsoleteAIServerAddresses: Set<String> = [
        "http://192.168.1.9:8765",
        "http://192.168.1.20:8765"
    ]
    private static let liveAppleSceneID = UUID(
        uuidString: "C1EA0000-0000-4000-8000-000000000001"
    )!

    private enum RecordingPhase {
        case idle
        case starting
        case recording
        case stopping
    }

    var roomModelURL: URL { projectStore.roomModelURL }
    var roomDataURL: URL { projectStore.roomDataURL }
    var sharedARSession: ARSession? { arView?.session }

    override init() {
        super.init()
        aiEnhancementEnabled = UserDefaults.standard.bool(forKey: Self.aiEnabledDefaultsKey)
        let storedAIAddress = UserDefaults.standard.string(forKey: Self.aiServerDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let storedAIAddress,
           !Self.obsoleteAIServerAddresses.contains(storedAIAddress),
           AIEnhancementClient.serverURL(from: storedAIAddress) != nil {
            aiServerAddress = storedAIAddress
        } else {
            aiServerAddress = Self.defaultAIServerAddress
        }
        UserDefaults.standard.set(aiServerAddress, forKey: Self.aiServerDefaultsKey)
        aiEnhancementStatus = aiEnhancementEnabled ? .waiting : .disabled
        importedAssetURLs = projectStore.importedModelURLs
        hasScannedRoom = FileManager.default.fileExists(atPath: roomDataURL.path)
        if projectStore.savedPlaces.isEmpty,
           projectStore.project.worldMapChecksum != nil {
            _ = try? projectStore.archiveCurrentProject(preferredName: "Önceki Mekân")
        }
        refreshSceneCatalogs()
        // Opaque room replacements can cover people and make the camera feel unstable.
        // Always launch in the real-camera view; the legacy renderer stays internal.
        UserDefaults.standard.removeObject(forKey: Self.realityThemeDefaultsKey)
        if let error = projectStore.initializationError {
            publishStatus(
                "Kayıtlı scene.json okunamadı: \(error.localizedDescription)",
                color: .red
            )
        } else if let notice = projectStore.initializationNotice {
            publishStatus(notice, color: .yellow)
        }
    }

    func makeARView() -> ARView {
        if let arView { return arView }

        let view = ARView(frame: .zero)
        view.automaticallyConfigureSession = false
        view.session.delegateQueue = .main
        view.session.delegate = self
        view.environment.sceneUnderstanding.options.insert(.occlusion)
        view.environment.sceneUnderstanding.options.insert(.collision)
        view.renderOptions.remove(.disablePersonOcclusion)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
        let surfaceProbe = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleSurfaceProbe(_:))
        )
        surfaceProbe.minimumPressDuration = 0
        surfaceProbe.cancelsTouchesInView = false
        surfaceProbe.delegate = self
        view.addGestureRecognizer(surfaceProbe)
        addCoachingOverlay(to: view)

        arView = view
        if aiEnhancementEnabled {
            aiDepthRenderer.install(in: view)
        }
        runSession()
        return view
    }

    private func configuration(
        initialWorldMap: ARWorldMap? = nil,
        enableAdvancedOcclusion: Bool = true
    ) -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        configuration.isLightEstimationEnabled = true
        configuration.isAutoFocusEnabled = true
        configuration.initialWorldMap = initialWorldMap

        if enableAdvancedOcclusion,
           ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
        }
        if enableAdvancedOcclusion,
           ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }
        // Keep scene depth alongside person depth when the device supports both.
        // Person segmentation handles people; scene depth/mesh handles furniture
        // crossing in front of a virtual prop.
        if enableAdvancedOcclusion,
           ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        if enableAdvancedOcclusion,
           ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            configuration.frameSemantics.insert(.smoothedSceneDepth)
        }
        return configuration
    }

    private func runSession(initialWorldMap: ARWorldMap? = nil) {
        guard ARWorldTrackingConfiguration.isSupported else {
            publishStatus("Bu cihaz ARKit dünya takibini desteklemiyor", color: .red)
            return
        }

        renderGeneration &+= 1
        readinessRecoveryGeneration &+= 1
        cancelPendingPostScanTheme()
        isARReady = false
        isSessionInterrupted = false
        shouldRestoreRoomRealityAfterInterruption = false
        configurationBeforeInterruption = nil
        didAttemptSessionFailureRecovery = false
        assetLoadSubscriptions.values.forEach { $0.cancel() }
        renderedAnchorIDs.removeAll()
        renderedAnchorIDByPlacementID.removeAll()
        knownPropAnchorIDs.removeAll()
        supersededPropAnchorIDs.removeAll()
        pendingAutoSaveAnchorIDs.removeAll()
        managedPropAnchorsByPlacementID.removeAll()
        if let initialWorldMap {
            for anchor in initialWorldMap.anchors {
                guard let descriptor = PropKind.descriptor(from: anchor.name) else { continue }
                managedPropAnchorsByPlacementID[descriptor.id] = anchor
            }
        }
        renderedEntities.removeAll()
        renderedLights.removeAll()
        renderedLightEmitters.removeAll()
        renderedLightFootprints.removeAll()
        bloodWaterfallParticles.removeAll()
        loadingEntityIDs.removeAll()
        assetLoadSubscriptions.removeAll()
        selectedEntityID = nil
        selectedLightSettings = nil
        isAimingLight = false
        placementReticlePoint = nil
        liveAppleAnchor = nil
        filteredLiveApplePosition = nil
        isRoomOutlineVisible = false
        guard let arView else { return }
        aiEnhancementClient.cancel()
        aiDepthRenderer.remove()
        arView.scene.anchors.removeAll()
        roomCoordinateSpaceIsActive = initialWorldMap != nil
        lastKnownFloorY = nil
        lastKnownCeilingY = nil
        floorSurfaceTracker.reset()
        if roomCoordinateSpaceIsActive {
            updateKnownFloorFromRoomData()
        }
        arView.session.delegateQueue = .main
        arView.session.delegate = self
        arView.session.run(
            configuration(initialWorldMap: initialWorldMap),
            options: [.resetTracking, .removeExistingAnchors]
        )
        roomRealityRenderer.install(in: arView)
        if aiEnhancementEnabled {
            aiDepthRenderer.install(in: arView)
            aiEnhancementStatus = .waiting
        }
        refreshPhysicalRoomOcclusionIfPossible()
        restoreRoomRealityIfPossible()
        scheduleReadinessRecovery()
    }

    func pauseForRoomScan() {
        cancelPlacement()
        if isListeningForCGICommands { stopCGIVoiceCommands() }
        aiEnhancementClient.cancel()
        aiDepthRenderer.clear()
        let themeAwaitingSafeRestore = pendingRealityThemeAfterScan
        cancelPendingPostScanTheme()
        readinessRecoveryGeneration &+= 1
        shouldShowRoomOutlineWhenReady = false
        isRoomScanActive = true
        isARReady = false
        realityThemeToRestoreAfterScan = themeAwaitingSafeRestore
            ?? (roomRealityRenderer.isVisible ? activeRealityThemeID : nil)
        roomRealityRenderer.isVisible = false
        roomRealityRenderer.isPhysicalOcclusionVisible = false
        isRoomOutlineVisible = false
        setPhysicalSceneOcclusion(enabled: false)
        arView?.isHidden = true
        // Keep the already-stable world-tracking configuration untouched. Re-running
        // the shared ARSession here creates an initializing gap just as RoomPlan starts,
        // which RoomPlan reports as `worldTrackingFailure`. RoomPlan preserves the
        // settings of a supplied, already-running ARSession.
        do {
            try persistAllEntityTransforms()
        } catch {
            publishStatus("Dekor konumları kaydedilemedi: \(error.localizedDescription)", color: .red)
        }
        publishStatus("Oda taraması açılıyor; aynı dünya koordinatları korunuyor", color: .yellow)
    }

    func setAIEnhancementEnabled(_ enabled: Bool) {
        aiEnhancementEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.aiEnabledDefaultsKey)
        guard enabled else {
            aiEnhancementClient.cancel()
            aiDepthRenderer.clear()
            aiEnhancementStatus = .disabled
            refreshPhysicalRoomOcclusionIfPossible()
            return
        }
        // The live LiDAR/AI mesh is more precise than RoomPlan's coarse furniture
        // boxes. Never run both depth writers together; overlapping occluders are the
        // main reason a newly placed prop can appear half cut or fully hidden.
        roomRealityRenderer.isPhysicalOcclusionVisible = false
        aiEnhancementStatus = AIEnhancementClient.serverURL(from: aiServerAddress) == nil
            ? .failed(AIEnhancementError.invalidServerAddress.localizedDescription)
            : .waiting
        if let arView { aiDepthRenderer.install(in: arView) }
    }

    func setAIServerAddress(_ address: String) {
        aiServerAddress = address
        UserDefaults.standard.set(address, forKey: Self.aiServerDefaultsKey)
        if aiEnhancementEnabled {
            aiEnhancementClient.cancel()
            aiDepthRenderer.clear()
            aiEnhancementStatus = AIEnhancementClient.serverURL(from: address) == nil
                ? .failed(AIEnhancementError.invalidServerAddress.localizedDescription)
                : .waiting
        }
    }

    func testAIServerConnection() {
        guard let url = AIEnhancementClient.serverURL(from: aiServerAddress) else {
            aiEnhancementStatus = .failed(AIEnhancementError.invalidServerAddress.localizedDescription)
            return
        }
        aiEnhancementStatus = .waiting
        aiEnhancementClient.testHealth(serverURL: url) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let device):
                // A successful test means the user intends to use the service. The old
                // flow painted the test green but left frame submission disabled when
                // the toggle was off, which looked exactly like a broken connection.
                self.setAIEnhancementEnabled(true)
                self.aiEnhancementStatus = .active(latencyMilliseconds: 0, samMaskCount: 0)
                self.publishStatus(
                    "AI servisi hazır: \(device) — canlı derinlik otomatik açıldı",
                    color: .green
                )
            case .failure(let error):
                self.aiEnhancementStatus = .failed(error.localizedDescription)
            }
        }
    }

    private func submitFrameToAIIfNeeded(_ frame: ARFrame) {
        guard aiEnhancementEnabled,
              !isRoomScanActive,
              !isSessionInterrupted,
              case .normal = frame.camera.trackingState,
              let serverURL = AIEnhancementClient.serverURL(from: aiServerAddress) else { return }
        aiEnhancementClient.submit(frame: frame, serverURL: serverURL) { [weak self] result in
            guard let self, self.aiEnhancementEnabled else { return }
            switch result {
            case .success(let depth):
                // RTX 3050-class PCs commonly need 2-3 seconds for Depth Anything
                // plus SAM 2. The mesh is already expressed in the captured frame's
                // world transform, so a valid static-scene result remains usable. The
                // previous 1.5 s cutoff incorrectly reported successful HTTP 200
                // responses as a broken connection.
                guard depth.totalLatencyMilliseconds <= 6_000 else {
                    self.aiDepthRenderer.clear()
                    self.refreshPhysicalRoomOcclusionIfPossible(
                        allowWhileAIEnabled: true
                    )
                    self.aiEnhancementStatus = .failed(
                        "Gecikme \(depth.totalLatencyMilliseconds) ms; PC veya Wi-Fi yavaş"
                    )
                    return
                }
                do {
                    self.roomRealityRenderer.isPhysicalOcclusionVisible = false
                    try self.aiDepthRenderer.render(depth)
                    self.aiEnhancementStatus = .active(
                        latencyMilliseconds: depth.totalLatencyMilliseconds,
                        samMaskCount: depth.samMaskCount
                    )
                } catch {
                    self.refreshPhysicalRoomOcclusionIfPossible(
                        allowWhileAIEnabled: true
                    )
                    self.aiEnhancementStatus = .failed(error.localizedDescription)
                }
            case .failure(let error):
                if let aiError = error as? AIEnhancementError,
                   case .missingSceneDepth = aiError {
                    if self.aiEnhancementStatus != .waitingForDepth {
                        self.aiDepthRenderer.clear()
                        self.refreshPhysicalRoomOcclusionIfPossible(
                            allowWhileAIEnabled: true
                        )
                    }
                    self.aiEnhancementStatus = .waitingForDepth
                } else {
                    self.aiDepthRenderer.clear()
                    self.refreshPhysicalRoomOcclusionIfPossible(
                        allowWhileAIEnabled: true
                    )
                    self.aiEnhancementStatus = .failed(error.localizedDescription)
                }
            }
        }
    }

    func resumeAfterRoomScan(result: RoomScanResult?) {
        isRoomScanActive = false
        isARReady = false
        didAttemptSessionFailureRecovery = false
        isSessionInterrupted = false
        shouldRestoreRoomRealityAfterInterruption = false
        configurationBeforeInterruption = nil
        arView?.isHidden = false
        setPhysicalSceneOcclusion(enabled: true)

        var themeToSchedule = realityThemeToRestoreAfterScan
        var completionStatus: (message: String, color: Color)?
        switch result {
        case .success:
            hasScannedRoom = FileManager.default.fileExists(atPath: roomDataURL.path)
            roomCoordinateSpaceIsActive = hasScannedRoom
            roomRealityRenderer.clear()
            roomRealityRenderer.isVisible = false
            activeRealityThemeID = nil
            preferredRealityThemeID = nil
            isRoomOutlineVisible = false
            shouldShowRoomOutlineWhenReady = false
            themeToSchedule = nil
            UserDefaults.standard.removeObject(forKey: Self.realityThemeDefaultsKey)
            var invalidationMessage: String?
            do {
                try projectStore.invalidateWorldMapForRoomScan()
            } catch {
                invalidationMessage = error.localizedDescription
            }
            if let invalidationMessage {
                shouldSaveWorldMapWhenReady = false
                completionStatus = (
                    "Tarama kaydedildi, ancak proje haritası güncellenemedi: \(invalidationMessage)",
                    .red
                )
            } else {
                updateKnownFloorFromRoomData()
                shouldSaveWorldMapWhenReady = hasScannedRoom
                shouldArchiveAfterNextSave = hasScannedRoom
                pendingArchiveName = nil
                completionStatus = (
                    "Tarama kaydedildi — sahne haritası takip hazır olunca otomatik kaydedilecek",
                    .green
                )
            }
        case .cancelled:
            completionStatus = ("Oda taraması iptal edildi; AR sahnesi devam ediyor", .yellow)
        case .failure(let message):
            completionStatus = ("Oda taraması tamamlanamadı: \(message)", .red)
        case nil:
            completionStatus = ("Oda taraması kapatıldı; AR sahnesi devam ediyor", .yellow)
        }

        realityThemeToRestoreAfterScan = nil
        pendingRealityThemeAfterScan = themeToSchedule
        arView?.session.delegateQueue = .main
        arView?.session.delegate = self
        arView?.session.run(configuration(), options: [])
        refreshPhysicalRoomOcclusionIfPossible()
        scheduleReadinessRecovery()

        if let completionStatus {
            publishStatus(completionStatus.message, color: completionStatus.color)
        }
        if let trackingState = arView?.session.currentFrame?.camera.trackingState {
            _ = schedulePendingPostScanThemeIfReady(trackingState: trackingState)
        }
    }

    func selectRealityTheme(_ id: RealityThemeID) {
        cancelPendingPostScanTheme()
        guard !isSessionInterrupted else {
            publishStatus("AR oturumu kesintisi bitene kadar oda teması değiştirilemez", color: .yellow)
            return
        }
        guard !isRoomRealityRendering else {
            publishStatus("Oda gerçekliği hazırlanıyor; lütfen kısa bir süre bekle", color: .yellow)
            return
        }
        guard let arView else {
            publishStatus("AR görünümü henüz hazır değil", color: .red)
            return
        }
        guard FileManager.default.fileExists(atPath: roomDataURL.path) else {
            hasScannedRoom = false
            publishStatus("Önce Oda Tara ile alanın duvar ve nesnelerini tara", color: .yellow)
            return
        }
        guard roomCoordinateSpaceIsActive else {
            publishStatus("Kayıtlı odayı hizalamak için önce sahne haritasını Yükle", color: .yellow)
            return
        }
        guard let trackingState = arView.session.currentFrame?.camera.trackingState,
              case .normal = trackingState else {
            pendingRealityThemeAfterScan = id
            publishStatus("Tema, kamera takibi hazır olduğunda uygulanacak", color: .yellow)
            return
        }

        isRoomRealityRendering = true
        roomRealityRenderer.isPhysicalOcclusionVisible = false
        setPhysicalSceneOcclusion(enabled: true)
        defer { isRoomRealityRendering = false }

        do {
            roomRealityRenderer.install(in: arView)
            let theme = RealityThemeCatalog.theme(withID: id)
            let report = try roomRealityRenderer.render(
                roomJSONURL: roomDataURL,
                theme: theme
            )
            roomRealityRenderer.isVisible = true
            activeRealityThemeID = id
            preferredRealityThemeID = id
            isRoomOutlineVisible = false
            hasScannedRoom = true
            UserDefaults.standard.set(id.rawValue, forKey: Self.realityThemeDefaultsKey)
            setPhysicalSceneOcclusion(enabled: true)
            var notices: [String] = []
            if report.polygonApproximationCount > 0 {
                notices.append("\(report.polygonApproximationCount) yüzey yaklaşıklandı")
            }
            let omittedCount = report.skippedElementCount + report.unmatchedPortalCount
            if omittedCount > 0 {
                notices.append("\(omittedCount) öğe eşleşmedi")
            }
            let detail = notices.isEmpty ? "" : " • " + notices.joined(separator: ", ")
            publishStatus(
                "\(theme.title) etkin — \(report.renderedElementCount) oda öğesi değiştirildi\(detail)",
                color: notices.isEmpty ? .green : .yellow
            )
        } catch {
            roomRealityRenderer.isVisible = false
            activeRealityThemeID = nil
            isRoomOutlineVisible = false
            setPhysicalSceneOcclusion(enabled: true)
            refreshPhysicalRoomOcclusionIfPossible()
            publishStatus("Oda teması uygulanamadı: \(error.localizedDescription)", color: .red)
        }
    }

    func showOriginalReality() {
        cancelPendingPostScanTheme()
        shouldRestoreRoomRealityAfterInterruption = false
        roomRealityRenderer.isVisible = false
        activeRealityThemeID = nil
        preferredRealityThemeID = nil
        isRoomOutlineVisible = false
        shouldShowRoomOutlineWhenReady = false
        UserDefaults.standard.removeObject(forKey: Self.realityThemeDefaultsKey)
        setPhysicalSceneOcclusion(enabled: true)
        refreshPhysicalRoomOcclusionIfPossible()
        publishStatus("Gerçek oda görünümü etkin; eklediğin objeler korunuyor", color: .green)
    }

    func showRoomOutline() {
        cancelPendingPostScanTheme()
        shouldRestoreRoomRealityAfterInterruption = false
        guard !isRoomScanActive, !isSessionInterrupted else {
            publishStatus("Tarama veya AR kesintisi bittiğinde tekrar dene", color: .yellow)
            return
        }
        guard let arView else {
            publishStatus("AR görünümü henüz hazır değil", color: .red)
            return
        }
        guard FileManager.default.fileExists(atPath: roomDataURL.path) else {
            hasScannedRoom = false
            shouldShowRoomOutlineWhenReady = false
            publishStatus("Beyaz oda hatları için önce Oda Tara'yı tamamla", color: .yellow)
            return
        }
        guard roomCoordinateSpaceIsActive else {
            shouldShowRoomOutlineWhenReady = true
            loadWorldMap()
            return
        }
        guard let trackingState = arView.session.currentFrame?.camera.trackingState,
              case .normal = trackingState else {
            shouldShowRoomOutlineWhenReady = true
            scheduleReadinessRecovery()
            publishStatus("Beyaz Hatlar takip hazır olduğunda otomatik açılacak", color: .yellow)
            return
        }

        do {
            shouldShowRoomOutlineWhenReady = false
            roomRealityRenderer.install(in: arView)
            let report: RoomRealityRenderReport
            if roomRealityRenderer.hasPreparedOutline,
               let preparedReport = roomRealityRenderer.lastReport {
                report = preparedReport
            } else {
                report = try roomRealityRenderer.renderOutline(roomJSONURL: roomDataURL)
            }
            roomRealityRenderer.isVisible = true
            isRoomOutlineVisible = true
            activeRealityThemeID = nil
            preferredRealityThemeID = nil
            UserDefaults.standard.removeObject(forKey: Self.realityThemeDefaultsKey)
            setPhysicalSceneOcclusion(enabled: true)
            updateKnownFloorFromRoomData()
            refreshPhysicalRoomOcclusionIfPossible()
            publishStatus(
                "Beyaz Hatlar etkin — \(report.renderedElementCount) tarama öğesi gösteriliyor",
                color: .green
            )
        } catch {
            roomRealityRenderer.isVisible = false
            isRoomOutlineVisible = false
            shouldShowRoomOutlineWhenReady = false
            setPhysicalSceneOcclusion(enabled: true)
            publishStatus("Oda hatları gösterilemedi: \(error.localizedDescription)", color: .red)
        }
    }

    func selectProp(_ prop: PropKind) {
        persistSelectedLightSettings()
        isAimingLight = false
        placementReticlePoint = nil
        selectedProp = prop
        selectedEntityID = nil
        selectedLightSettings = nil
        if prop == .custom, selectedAssetURL == nil {
            isPlacingProp = false
            publishStatus("USDZ seçildi — önce kütüphaneden bir model ekle", color: .yellow)
        } else {
            isPlacingProp = true
            placementSurfaceMessage = "LiDAR yüzeyi doğrulanıyor"
            placementSurfaceColor = .yellow
            publishStatus(
                "\(prop.title) seçildi — \(placementInstruction(for: prop))",
                color: .blue
            )
        }
    }

    func cancelPlacement() {
        guard isPlacingProp else { return }
        isPlacingProp = false
        placementSurfaceMessage = "Yerleştirme kapalı"
        placementSurfaceColor = .yellow
        placementReticlePoint = nil
        publishStatus("Yerleştirme iptal edildi", color: .yellow)
    }

    private func placementInstruction(for prop: PropKind) -> String {
        switch prop.placementSurface {
        case .floor: "taranmış zemine dokun"
        case .horizontal: "zemine veya masa gibi yatay yüzeye dokun"
        case .wall: "taranmış duvara dokun"
        case .ceiling: "telefonu tavana çevirip taranmış tavana dokun"
        }
    }

    private func placementFailureMessage(for prop: PropKind) -> String {
        switch prop.placementSurface {
        case .floor:
            "Kararlı zemin bulunamadı — zemini yavaşça tara, sonra tekrar dokun"
        case .horizontal:
            "Kararlı yatay yüzey bulunamadı — yüzeyi yavaşça tara, sonra tekrar dokun"
        case .wall:
            "Kararlı duvar bulunamadı — duvarı yavaşça tara, sonra tekrar dokun"
        case .ceiling:
            "Kararlı tavan bulunamadı — telefonu yukarı çevirip tavanı yavaşça tara"
        }
    }

    private func selectRenderedEntity(id: UUID) {
        persistSelectedLightSettings()
        isAimingLight = false
        selectedEntityID = id
        if let placement = projectStore.placement(id: id), placement.kind.emitsVirtualLight {
            selectedLightSettings = placement.lightSettings ?? .defaultFixture
            publishStatus("Işık seçildi — güç, renk, yön, eğim ve hüzmeyi ayarlayabilirsin", color: .blue)
        } else {
            selectedLightSettings = nil
            publishStatus("Dekor seçildi — konumu kilitli; döndür veya ölçekle", color: .blue)
        }
    }

    func selectSceneObject(id: UUID) {
        if id == Self.liveAppleSceneID {
            publishStatus("Canlı elma efekti seçildi — kapatmak için Sahne listesindeki çöp kutusunu kullan", color: .blue)
            return
        }
        guard projectStore.placement(id: id) != nil else {
            refreshSceneCatalogs()
            publishStatus("Sahne öğesi artık bulunmuyor", color: .yellow)
            return
        }
        isPlacingProp = false
        placementReticlePoint = nil
        selectRenderedEntity(id: id)
    }

    func setLiveAppleEnabled(_ enabled: Bool) {
        isLiveAppleEnabled = enabled
        filteredLiveApplePosition = nil
        lastLiveAppleObservationTimestamp = 0
        if enabled {
            liveCGIStatus = "Elini kameraya göster; elma avuç merkezine bağlanacak"
            publishStatus("Canlı elma etkin — avucunu açık biçimde kameraya göster", color: .green)
        } else {
            if let anchor = liveAppleAnchor {
                anchor.scene?.removeAnchor(anchor)
            }
            liveAppleAnchor = nil
            liveCGIStatus = "Canlı elma kapalı"
        }
        refreshSceneCatalogs()
    }

    func toggleCGIVoiceCommands() {
        if isListeningForCGICommands {
            stopCGIVoiceCommands()
        } else {
            startCGIVoiceCommands()
        }
    }

    func stopCGIVoiceCommands() {
        speechTask?.cancel()
        speechTask = nil
        speechRequest?.endAudio()
        speechRequest = nil
        if speechAudioEngine.isRunning { speechAudioEngine.stop() }
        if hasSpeechInputTap {
            speechAudioEngine.inputNode.removeTap(onBus: 0)
            hasSpeechInputTap = false
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isListeningForCGICommands = false
        if liveCGIStatus == "Dinliyorum…" {
            liveCGIStatus = "Sesli komut kapalı"
        }
    }

    private func startCGIVoiceCommands() {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            requestMicrophoneAndBeginCGISpeechRecognition()
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if status == .authorized {
                        self.requestMicrophoneAndBeginCGISpeechRecognition()
                    } else {
                        self.liveCGIStatus = "Konuşma tanıma izni verilmedi"
                        self.publishStatus("Ayarlar'dan Konuşma Tanıma iznini aç", color: .yellow)
                    }
                }
            }
        case .denied, .restricted:
            liveCGIStatus = "Konuşma tanıma izni kapalı"
            publishStatus("Ayarlar'dan Konuşma Tanıma iznini aç", color: .yellow)
        @unknown default:
            liveCGIStatus = "Konuşma tanıma kullanılamıyor"
        }
    }

    private func requestMicrophoneAndBeginCGISpeechRecognition() {
        let audioSession = AVAudioSession.sharedInstance()
        switch audioSession.recordPermission {
        case .granted:
            beginCGISpeechRecognition()
        case .undetermined:
            audioSession.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.beginCGISpeechRecognition()
                    } else {
                        self.liveCGIStatus = "Mikrofon izni verilmedi"
                        self.publishStatus("Ayarlar'dan Mikrofon iznini aç", color: .yellow)
                    }
                }
            }
        case .denied:
            liveCGIStatus = "Mikrofon izni kapalı"
            publishStatus("Ayarlar'dan Mikrofon iznini aç", color: .yellow)
        @unknown default:
            liveCGIStatus = "Mikrofon kullanılamıyor"
        }
    }

    private func beginCGISpeechRecognition() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            liveCGIStatus = "Türkçe konuşma tanıma şu anda kullanılamıyor"
            return
        }
        stopCGIVoiceCommands()
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.duckOthers, .defaultToSpeaker]
            )
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.taskHint = .confirmation
            if speechRecognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            speechRequest = request
            lastProcessedCGITranscript = ""

            let inputNode = speechAudioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) {
                [weak request] buffer, _ in
                request?.append(buffer)
            }
            hasSpeechInputTap = true
            speechAudioEngine.prepare()
            try speechAudioEngine.start()
            isListeningForCGICommands = true
            liveCGIStatus = "Dinliyorum…"

            speechTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if let result {
                        self.handleCGITranscript(
                            result.bestTranscription.formattedString,
                            isFinal: result.isFinal
                        )
                    }
                    if error != nil {
                        self.stopCGIVoiceCommands()
                    }
                }
            }
        } catch {
            stopCGIVoiceCommands()
            liveCGIStatus = "Mikrofon başlatılamadı: \(error.localizedDescription)"
            publishStatus(liveCGIStatus, color: .red)
        }
    }

    private func handleCGITranscript(_ transcript: String, isFinal: Bool) {
        let command = transcript.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "tr_TR")
        ).lowercased()
        guard command != lastProcessedCGITranscript else { return }

        if command.contains("kan selalesi") || command.contains("kan ak") {
            lastProcessedCGITranscript = command
            selectProp(.bloodWaterfall)
            liveCGIStatus = "Kan şelalesi seçildi; başlangıç için duvara dokun"
            if isFinal { stopCGIVoiceCommands() }
            return
        }
        if command.contains("elma") {
            lastProcessedCGITranscript = command
            let shouldRemove = command.contains("kaldir")
                || command.contains("sil")
                || command.contains("kapat")
            setLiveAppleEnabled(!shouldRemove)
            liveCGIStatus = shouldRemove
                ? "Elma efekti kaldırıldı"
                : "Elma etkin; elini kameraya göster"
            if isFinal { stopCGIVoiceCommands() }
            return
        }
        liveCGIStatus = transcript.isEmpty ? "Dinliyorum…" : "Duyulan: \(transcript)"
        if isFinal { stopCGIVoiceCommands() }
    }

    private func updateLiveAppleTracking(using frame: ARFrame) {
        guard isLiveAppleEnabled, isARReady, !isRoomScanActive, !isSessionInterrupted,
              let arView else { return }
        if frame.timestamp - lastHandDetectionTimestamp < 0.12 || handDetectionInFlight {
            if frame.timestamp - lastLiveAppleObservationTimestamp > 0.42 {
                liveAppleAnchor?.isEnabled = false
            }
            return
        }
        lastHandDetectionTimestamp = frame.timestamp
        handDetectionInFlight = true
        let pixelBuffer = frame.capturedImage
        let viewportSize = arView.bounds.size
        let imageOrientation: CGImagePropertyOrientation
        switch arView.window?.windowScene?.interfaceOrientation {
        case .some(.landscapeLeft): imageOrientation = .up
        case .some(.landscapeRight): imageOrientation = .down
        case .some(.portraitUpsideDown): imageOrientation = .left
        default: imageOrientation = .right
        }
        handDetectionQueue.async { [weak self, weak arView] in
            let request = VNDetectHumanHandPoseRequest()
            request.maximumHandCount = 1
            var normalizedPalm: CGPoint?
            do {
                let handler = VNImageRequestHandler(
                    cvPixelBuffer: pixelBuffer,
                    orientation: imageOrientation,
                    options: [:]
                )
                try handler.perform([request])
                if let observation = request.results?.first {
                    let points = try observation.recognizedPoints(.all)
                    let jointNames: [VNHumanHandPoseObservation.JointName] = [
                        .wrist, .indexMCP, .middleMCP, .littleMCP
                    ]
                    let valid = jointNames.compactMap { name -> VNRecognizedPoint? in
                        guard let point = points[name], point.confidence >= 0.30 else { return nil }
                        return point
                    }
                    if valid.count >= 3 {
                        let count = CGFloat(valid.count)
                        normalizedPalm = CGPoint(
                            x: valid.reduce(CGFloat.zero) { $0 + $1.location.x } / count,
                            y: valid.reduce(CGFloat.zero) { $0 + $1.location.y } / count
                        )
                    }
                }
            } catch {
                normalizedPalm = nil
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.handDetectionInFlight = false
                guard self.isLiveAppleEnabled,
                      let arView,
                      let normalizedPalm,
                      viewportSize.width > 0,
                      viewportSize.height > 0 else { return }
                let point = CGPoint(
                    x: normalizedPalm.x * viewportSize.width,
                    y: (1 - normalizedPalm.y) * viewportSize.height
                )
                self.placeLiveApple(using: frame, in: arView, at: point)
            }
        }
    }

    private func placeLiveApple(using frame: ARFrame, in arView: ARView, at point: CGPoint) {
        guard let depth = sceneDepthSample(frame: frame, in: arView, at: point) else {
            liveCGIStatus = "El görüldü; avuç derinliği ölçülüyor"
            return
        }
        let cameraPosition = SIMD3<Float>(
            frame.camera.transform.columns.3.x,
            frame.camera.transform.columns.3.y,
            frame.camera.transform.columns.3.z
        )
        var towardCamera = cameraPosition - depth.worldPoint
        if simd_length_squared(towardCamera) > 0.000_001 {
            towardCamera = simd_normalize(towardCamera)
        } else {
            towardCamera = [0, 0, 1]
        }
        let measured = depth.worldPoint + towardCamera * 0.045 + SIMD3<Float>(0, 0.055, 0)
        let filtered: SIMD3<Float>
        if let previous = filteredLiveApplePosition,
           simd_distance(previous, measured) < 0.45 {
            filtered = previous + (measured - previous) * 0.24
        } else {
            filtered = measured
        }
        filteredLiveApplePosition = filtered
        lastLiveAppleObservationTimestamp = frame.timestamp

        let anchor: AnchorEntity
        if let existing = liveAppleAnchor, existing.scene != nil {
            anchor = existing
        } else {
            anchor = AnchorEntity(world: filtered)
            anchor.name = "cinear.cgi.live-apple"
            let apple = makeAppleEntity()
            apple.position.y = -0.065
            anchor.addChild(apple)
            arView.scene.addAnchor(anchor)
            liveAppleAnchor = anchor
        }
        anchor.position = filtered
        anchor.isEnabled = true
        liveCGIStatus = String(format: "Elma avuçta • %.2f m", depth.depthMeters)
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let arView else { return }
        let point = recognizer.location(in: arView)

        if isAimingLight {
            retargetSelectedLight(in: arView, at: point)
            return
        }

        if !isPlacingProp,
           let hitEntity = arView.entity(at: point),
           let id = entityID(from: hitEntity) {
            selectRenderedEntity(id: id)
            return
        }

        guard isPlacingProp else { return }

        guard !isRoomScanActive,
              !isSessionInterrupted,
              isARReady,
              let trackingState = arView.session.currentFrame?.camera.trackingState,
              case .normal = trackingState else {
            publishStatus("Kararlı yerleştirme için telefonu yavaşlat ve yeşil takibi bekle", color: .yellow)
            return
        }

        guard let placementSolution = placementSolution(
            in: arView,
            at: point,
            for: selectedProp
        ) else {
            publishStatus(
                placementFailureMessage(for: selectedProp),
                color: .yellow
            )
            return
        }
        let placementTransform = placementSolution.transform

        let id = UUID()
        guard selectedProp != .custom || selectedAssetURL != nil else {
            publishStatus("Önce kütüphaneden bir USDZ dekor seç", color: .yellow)
            return
        }
        let placement = PlacementRecord(
            id: id,
            kind: selectedProp,
            assetFileName: selectedProp == .custom ? selectedAssetURL?.lastPathComponent : nil,
            transform: StoredTransform(defaultTransform(for: selectedProp)),
            lightSettings: selectedProp.emitsVirtualLight ? .defaultFixture : nil
        )
        do {
            try projectStore.upsert(placement)
            let anchor = ARAnchor(
                name: selectedProp.anchorName(id: id),
                transform: placementTransform
            )
            knownPropAnchorIDs.insert(anchor.identifier)
            managedPropAnchorsByPlacementID[id] = anchor
            pendingAutoSaveAnchorIDs.insert(anchor.identifier)
            arView.session.add(anchor: anchor)
            selectedEntityID = id
            selectedLightSettings = placement.lightSettings
            isPlacingProp = false
            placementReticlePoint = nil
            render(prop: selectedProp, id: id, for: anchor)
            refreshSceneCatalogs()
            if selectedProp == .custom {
                publishStatus("USDZ sahneye yükleniyor...", color: .yellow)
            } else if renderedEntities[id] != nil {
                publishStatus(
                    "\(selectedProp.title) yüzeye sabitlendi — \(placementSolution.source.title)",
                    color: .green
                )
            } else {
                publishStatus("\(selectedProp.title) hazırlanıyor...", color: .yellow)
            }
        } catch {
            publishStatus("Proje kaydedilemedi: \(error.localizedDescription)", color: .red)
        }
    }

    @objc private func handleSurfaceProbe(_ recognizer: UILongPressGestureRecognizer) {
        guard isPlacingProp, let arView,
              recognizer.state == .began || recognizer.state == .changed else { return }
        let point = recognizer.location(in: arView)
        placementReticlePoint = point
        guard let frame = arView.session.currentFrame else { return }
        updatePlacementGuidance(using: frame, at: point, force: true)
    }

    private func placementSolution(
        in arView: ARView,
        at point: CGPoint,
        for prop: PropKind
    ) -> PlacementSurfaceSolution? {
        if prop.placementSurface == .floor {
            return strictFloorPlacementSolution(in: arView, at: point, for: prop)
        }

        // When a room theme is visible, use the geometry the user actually sees. The
        // RoomPlan replacement scene is virtual RealityKit content, so ARKit's plane
        // raycast below cannot intersect it on its own.
        if let hit = roomRealityRenderer.placementHit(in: arView, at: point) {
            if surfaceAccepts(
                prop: prop,
                normal: hit.normal,
                position: hit.position,
                cameraY: arView.cameraTransform.translation.y
            ) {
                return PlacementSurfaceSolution(
                    transform: placementTransform(
                        position: hit.position,
                        normal: hit.normal,
                        prop: prop,
                        cameraPosition: arView.cameraTransform.translation
                    ),
                    position: hit.position,
                    normal: hit.normal,
                    source: .roomPlanGeometry,
                    depthMeters: nil
                )
            }
        }

        // Scene-understanding collision is backed by the LiDAR reconstruction mesh.
        // It catches stable horizontal surfaces such as tables even when ARKit has
        // not promoted that patch to a plane anchor yet.
        if let hit = arView.hitTest(point, query: .all, mask: .all).first(where: {
            entityID(from: $0.entity) == nil
                && !belongsToRoomReality($0.entity)
                && surfaceAccepts(
                    prop: prop,
                    normal: $0.normal,
                    position: $0.position,
                    cameraY: arView.cameraTransform.translation.y
                )
        }) {
            return PlacementSurfaceSolution(
                transform: placementTransform(
                    position: hit.position,
                    normal: hit.normal,
                    prop: prop,
                    cameraPosition: arView.cameraTransform.translation
                ),
                position: hit.position,
                normal: hit.normal,
                source: .lidarMesh,
                depthMeters: nil
            )
        }

        let preferredAlignment: ARRaycastQuery.TargetAlignment =
            prop.placementSurface == .wall ? .vertical : .horizontal
        let queries: [(ARRaycastQuery.Target, ARRaycastQuery.TargetAlignment)] = [
            (.existingPlaneGeometry, preferredAlignment),
            (.existingPlaneInfinite, preferredAlignment)
        ]

        for (target, alignment) in queries {
            let results = arView.raycast(
                from: point,
                allowing: target,
                alignment: alignment
            )
            if let result = results.first(where: {
                raycastResult($0, matches: prop, cameraY: arView.cameraTransform.translation.y)
            }) {
                let position = result.worldTransform.columns.3
                let worldPosition = SIMD3<Float>(position.x, position.y, position.z)
                let normal = SIMD3<Float>(
                        result.worldTransform.columns.1.x,
                        result.worldTransform.columns.1.y,
                        result.worldTransform.columns.1.z
                    )
                return PlacementSurfaceSolution(
                    transform: placementTransform(
                        position: worldPosition,
                        normal: normal,
                        prop: prop,
                        cameraPosition: arView.cameraTransform.translation
                    ),
                    position: worldPosition,
                    normal: normal,
                    source: .arkitPlane,
                    depthMeters: nil
                )
            }
        }

        // RoomPlan also gives us a persistent ceiling height. Intersecting the screen
        // ray with it keeps ceiling fixtures stable even when ARKit's live ceiling
        // plane is temporarily outside the current camera frame.
        if prop.placementSurface == .ceiling,
           roomCoordinateSpaceIsActive,
           let ceilingY = lastKnownCeilingY,
           let ray = arView.ray(through: point) {
            let direction = simd_normalize(ray.direction)
            guard direction.y > 0.025 else { return nil }
            let distance = (ceilingY - ray.origin.y) / direction.y
            if distance.isFinite, distance >= 0.20, distance <= 8.0 {
                let position = ray.origin + direction * distance
                return PlacementSurfaceSolution(
                    transform: placementTransform(
                        position: position,
                        normal: [0, -1, 0],
                        prop: prop,
                        cameraPosition: arView.cameraTransform.translation
                    ),
                    position: position,
                    normal: [0, -1, 0],
                    source: .roomPlanLevel,
                    depthMeters: nil
                )
            }
        }

        // A completed RoomPlan scan provides a persistent world-space floor level.
        // Intersect the exact screen ray with that recorded floor instead of guessing
        // from camera height. This remains stable while making the full floor tappable.
        if prop.placementSurface == .horizontal,
           roomCoordinateSpaceIsActive,
           let floorY = lastKnownFloorY,
           let ray = arView.ray(through: point) {
            let direction = simd_normalize(ray.direction)
            guard direction.y < -0.025 else { return nil }
            let distance = (floorY - ray.origin.y) / direction.y
            if distance.isFinite, distance >= 0.20, distance <= 8.0 {
                let position = ray.origin + direction * distance
                return PlacementSurfaceSolution(
                    transform: placementTransform(
                        position: position,
                        normal: [0, 1, 0],
                        prop: prop,
                        cameraPosition: arView.cameraTransform.translation
                    ),
                    position: position,
                    normal: [0, 1, 0],
                    source: .roomPlanLevel,
                    depthMeters: nil
                )
            }
        }

        // Do not fabricate a camera-relative point. Such an object looks acceptable
        // for a single frame but visibly swims once the camera moves. The user keeps
        // placement mode active until ARKit has a persistent plane/RoomPlan surface.
        return nil
    }

    /// Floor props use a deliberately stricter resolver than generic horizontal
    /// props. A table is horizontal and often sits more than 25 cm below the camera;
    /// height alone can therefore never prove that a hit is the floor.
    private func strictFloorPlacementSolution(
        in arView: ARView,
        at point: CGPoint,
        for prop: PropKind
    ) -> PlacementSurfaceSolution? {
        guard let frame = arView.session.currentFrame else { return nil }
        let cameraY = frame.camera.transform.columns.3.y
        let depth = sceneDepthSample(frame: frame, in: arView, at: point)

        // A finite classified plane is the strongest tap-local ARKit result. When
        // LiDAR depth exists it must agree, preventing a floor plane behind a table
        // from accepting the table pixel as a floor placement.
        let classifiedResults = arView.raycast(
            from: point,
            allowing: .existingPlaneGeometry,
            alignment: .horizontal
        )
        for result in classifiedResults {
            guard let plane = result.anchor as? ARPlaneAnchor,
                  plane.classification == .floor else { continue }
            let position = SIMD3<Float>(
                result.worldTransform.columns.3.x,
                result.worldTransform.columns.3.y,
                result.worldTransform.columns.3.z
            )
            guard depth.map({ floorDepthAgrees($0, position: position, floorY: position.y) })
                    ?? true else { continue }
            return floorSolution(
                position: position,
                normal: [0, 1, 0],
                prop: prop,
                cameraPosition: arView.cameraTransform.translation,
                source: .classifiedFloorPlane,
                depth: depth
            )
        }

        guard let floor = floorSurfaceTracker.estimate(cameraY: cameraY),
              floor.isStable else { return nil }
        lastKnownFloorY = floor.y

        // Scene-understanding collision is exact to the reconstructed LiDAR mesh,
        // but RealityKit doesn't expose the mesh face classification in this hit.
        // Require agreement with both the classified floor level and tap-local depth.
        if let hit = arView.hitTest(point, query: .all, mask: .all).first(where: {
            entityID(from: $0.entity) == nil
                && !belongsToRoomReality($0.entity)
                && !belongsToProjectorVisualization($0.entity)
                && abs(simd_normalize($0.normal).y) >= 0.78
                && abs($0.position.y - floor.y) <= 0.055
        }), let depth,
           floorDepthAgrees(depth, position: hit.position, floorY: floor.y) {
            return floorSolution(
                position: hit.position,
                normal: hit.normal,
                prop: prop,
                cameraPosition: arView.cameraTransform.translation,
                source: .lidarMesh,
                depth: depth
            )
        }

        if let hit = roomRealityRenderer.placementHit(in: arView, at: point),
           abs(simd_normalize(hit.normal).y) >= 0.78,
           abs(hit.position.y - floor.y) <= 0.055,
           let depth,
           floorDepthAgrees(depth, position: hit.position, floorY: floor.y) {
            return floorSolution(
                position: hit.position,
                normal: hit.normal,
                prop: prop,
                cameraPosition: arView.cameraTransform.translation,
                source: .roomPlanGeometry,
                depth: depth
            )
        }

        // Extend the trusted floor only when the current depth pixel independently
        // lands on that same metric level. This makes an already-scanned floor fully
        // tappable without ever projecting through furniture in the foreground.
        guard let ray = arView.ray(through: point) else { return nil }
        let direction = simd_normalize(ray.direction)
        guard direction.y < -0.025 else { return nil }
        let distance = (floor.y - ray.origin.y) / direction.y
        guard distance.isFinite, (0.20...8.0).contains(distance) else { return nil }
        let position = ray.origin + direction * distance
        guard let depth,
              floorDepthAgrees(depth, position: position, floorY: floor.y) else { return nil }
        return floorSolution(
            position: position,
            normal: [0, 1, 0],
            prop: prop,
            cameraPosition: arView.cameraTransform.translation,
            source: floor.source,
            depth: depth
        )
    }

    private func floorSolution(
        position: SIMD3<Float>,
        normal: SIMD3<Float>,
        prop: PropKind,
        cameraPosition: SIMD3<Float>,
        source: PlacementSurfaceSource,
        depth: SceneDepthSurfaceSample?
    ) -> PlacementSurfaceSolution {
        PlacementSurfaceSolution(
            transform: placementTransform(
                position: position,
                normal: normal,
                prop: prop,
                cameraPosition: cameraPosition
            ),
            position: position,
            normal: normal,
            source: source,
            depthMeters: depth?.depthMeters
        )
    }

    private func floorDepthAgrees(
        _ depth: SceneDepthSurfaceSample,
        position: SIMD3<Float>,
        floorY: Float
    ) -> Bool {
        guard abs(depth.worldPoint.y - floorY) <= 0.10,
              simd_distance(depth.worldPoint, position) <= 0.22 else { return false }
        if let normal = depth.worldNormal {
            return abs(normal.y) >= 0.68
        }
        return true
    }

    private func updatePlacementGuidance(
        using frame: ARFrame,
        at requestedPoint: CGPoint? = nil,
        force: Bool = false
    ) {
        guard isPlacingProp, let arView,
              force || frame.timestamp - lastPlacementGuidanceTimestamp >= 0.14 else { return }
        lastPlacementGuidanceTimestamp = frame.timestamp
        guard isARReady, case .normal = frame.camera.trackingState else {
            placementSurfaceMessage = "Sarı: dünya takibinin yeşile dönmesini bekle"
            placementSurfaceColor = .yellow
            return
        }
        let point = requestedPoint
            ?? placementReticlePoint
            ?? CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        if let solution = placementSolution(in: arView, at: point, for: selectedProp) {
            let depthText = solution.depthMeters.map { String(format: " • %.2f m", $0) } ?? ""
            placementSurfaceMessage = "Doğrulandı: \(solution.source.title)\(depthText)"
            placementSurfaceColor = .green
            return
        }

        if selectedProp.placementSurface == .floor {
            let cameraY = frame.camera.transform.columns.3.y
            if let estimate = floorSurfaceTracker.estimate(cameraY: cameraY), estimate.isStable,
               sceneDepthSample(frame: frame, in: arView, at: point) != nil {
                placementSurfaceMessage = "Kırmızı: görünen yüzey zemin değil"
                placementSurfaceColor = .red
            } else {
                placementSurfaceMessage = "Sarı: LiDAR zemini ölçüyor"
                placementSurfaceColor = .yellow
            }
        } else {
            placementSurfaceMessage = "Sarı: uygun yüzeyi yavaşça tara"
            placementSurfaceColor = .yellow
        }
    }

    private func surfaceAccepts(
        prop: PropKind,
        normal: SIMD3<Float>,
        position: SIMD3<Float>,
        cameraY: Float
    ) -> Bool {
        guard simd_length_squared(normal) > 0.000_001 else { return false }
        let verticalComponent = abs(simd_normalize(normal).y)
        switch prop.placementSurface {
        case .wall:
            return verticalComponent < 0.45
        case .ceiling:
            return verticalComponent > 0.72 && position.y > cameraY + 0.25
        case .floor:
            return verticalComponent > 0.72 && position.y < cameraY - 0.25
        case .horizontal:
            return verticalComponent > 0.72 && position.y < cameraY + 0.20
        }
    }

    private func raycastResult(
        _ result: ARRaycastResult,
        matches prop: PropKind,
        cameraY: Float
    ) -> Bool {
        let y = result.worldTransform.columns.3.y
        let classification = (result.anchor as? ARPlaneAnchor)?.classification
        switch prop.placementSurface {
        case .wall:
            return true
        case .ceiling:
            return classification == .ceiling || y > cameraY + 0.25
        case .floor:
            return classification == .floor
        case .horizontal:
            return classification != .ceiling && y < cameraY + 0.20
        }
    }

    private func updateKnownFloorFromRoomData() {
        floorSurfaceTracker.clearRoomFloor()
        lastKnownFloorY = nil
        guard let room = try? RoomRealityRenderer.loadRoomJSON(from: roomDataURL) else { return }
        let levels = room.floors.compactMap { floor -> Float? in
            let y = floor.transform.columns.3.y
            return y.isFinite ? y : nil
        }.sorted()
        if !levels.isEmpty {
            let roomFloorY = levels[levels.count / 2]
            floorSurfaceTracker.setRoomFloor(roomFloorY)
            lastKnownFloorY = roomFloorY
        }
        do {
            if let ceilingY = try roomRealityRenderer.inferredCeilingLevel(
                roomJSONURL: roomDataURL
            ), ceilingY.isFinite {
                lastKnownCeilingY = ceilingY
            }
        } catch {
            lastKnownCeilingY = nil
        }
    }

    private func updateKnownFloor(from anchors: [ARAnchor]) {
        guard let cameraY = arView?.session.currentFrame?.camera.transform.columns.3.y else { return }
        floorSurfaceTracker.update(with: anchors, cameraY: cameraY)
        if let estimate = floorSurfaceTracker.estimate(cameraY: cameraY), estimate.isStable {
            lastKnownFloorY = estimate.y
        }
    }

    private func sceneDepthSample(
        frame: ARFrame,
        in arView: ARView,
        at viewPoint: CGPoint
    ) -> SceneDepthSurfaceSample? {
        guard arView.bounds.width > 1, arView.bounds.height > 1,
              let sceneDepth = frame.smoothedSceneDepth ?? frame.sceneDepth else { return nil }
        let depthMap = sceneDepth.depthMap
        let depthWidth = CVPixelBufferGetWidth(depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthMap)
        guard depthWidth > 4, depthHeight > 4 else { return nil }

        let orientation = arView.window?.windowScene?.interfaceOrientation ?? .portrait
        let normalizedViewPoint = CGPoint(
            x: viewPoint.x / arView.bounds.width,
            y: viewPoint.y / arView.bounds.height
        )
        let imagePoint = normalizedViewPoint.applying(
            frame.displayTransform(
                for: orientation,
                viewportSize: arView.bounds.size
            ).inverted()
        )
        guard imagePoint.x.isFinite, imagePoint.y.isFinite,
              (0...1).contains(imagePoint.x), (0...1).contains(imagePoint.y) else { return nil }

        let centerX = min(max(Int(imagePoint.x * CGFloat(depthWidth - 1)), 2), depthWidth - 3)
        let centerY = min(max(Int(imagePoint.y * CGFloat(depthHeight - 1)), 2), depthHeight - 3)
        let confidenceMap = sceneDepth.confidenceMap

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        if let confidenceMap { CVPixelBufferLockBaseAddress(confidenceMap, .readOnly) }
        defer {
            if let confidenceMap { CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly) }
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
        }
        guard let depthBase = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let depthBytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let confidenceBase = confidenceMap.flatMap { CVPixelBufferGetBaseAddress($0) }
        let confidenceBytesPerRow = confidenceMap.map { CVPixelBufferGetBytesPerRow($0) } ?? 0

        func confidenceIsUsable(x: Int, y: Int) -> Bool {
            guard let confidenceBase else { return true }
            let value = confidenceBase
                .advanced(by: y * confidenceBytesPerRow + x)
                .assumingMemoryBound(to: UInt8.self).pointee
            return value >= UInt8(ARConfidenceLevel.medium.rawValue)
        }

        func depthValue(x: Int, y: Int) -> Float? {
            guard x >= 0, x < depthWidth, y >= 0, y < depthHeight,
                  confidenceIsUsable(x: x, y: y) else { return nil }
            let row = depthBase.advanced(by: y * depthBytesPerRow)
            let value = row.assumingMemoryBound(to: Float32.self)[x]
            return value.isFinite && (0.15...8.0).contains(value) ? value : nil
        }

        var neighborhood: [Float] = []
        neighborhood.reserveCapacity(25)
        for y in (centerY - 2)...(centerY + 2) {
            for x in (centerX - 2)...(centerX + 2) {
                if let value = depthValue(x: x, y: y) { neighborhood.append(value) }
            }
        }
        guard neighborhood.count >= 9 else { return nil }
        neighborhood.sort()
        let medianDepth = neighborhood[neighborhood.count / 2]

        func unproject(x: Int, y: Int, depth: Float) -> SIMD3<Float> {
            let imageResolution = frame.camera.imageResolution
            let scaleX = Float(depthWidth) / Float(imageResolution.width)
            let scaleY = Float(depthHeight) / Float(imageResolution.height)
            let intrinsics = frame.camera.intrinsics
            let fx = intrinsics.columns.0.x * scaleX
            let fy = intrinsics.columns.1.y * scaleY
            let cx = intrinsics.columns.2.x * scaleX
            let cy = intrinsics.columns.2.y * scaleY
            let cameraPoint = SIMD4<Float>(
                (Float(x) - cx) / fx * depth,
                -(Float(y) - cy) / fy * depth,
                -depth,
                1
            )
            let worldPoint = frame.camera.transform * cameraPoint
            return SIMD3(worldPoint.x, worldPoint.y, worldPoint.z)
        }

        let worldPoint = unproject(x: centerX, y: centerY, depth: medianDepth)
        var worldNormal: SIMD3<Float>?
        if let leftDepth = depthValue(x: centerX - 2, y: centerY),
           let rightDepth = depthValue(x: centerX + 2, y: centerY),
           let upperDepth = depthValue(x: centerX, y: centerY - 2),
           let lowerDepth = depthValue(x: centerX, y: centerY + 2) {
            let horizontal = unproject(x: centerX + 2, y: centerY, depth: rightDepth)
                - unproject(x: centerX - 2, y: centerY, depth: leftDepth)
            let vertical = unproject(x: centerX, y: centerY + 2, depth: lowerDepth)
                - unproject(x: centerX, y: centerY - 2, depth: upperDepth)
            let crossed = simd_cross(horizontal, vertical)
            if simd_length_squared(crossed) > 0.000_001 {
                worldNormal = simd_normalize(crossed)
            }
        }
        return SceneDepthSurfaceSample(
            worldPoint: worldPoint,
            worldNormal: worldNormal,
            depthMeters: medianDepth
        )
    }

    private func placementTransform(
        position: SIMD3<Float>,
        normal: SIMD3<Float>,
        prop: PropKind,
        cameraPosition: SIMD3<Float>
    ) -> simd_float4x4 {
        var transform = matrix_identity_float4x4
        transform.columns.3 = SIMD4(position.x, position.y, position.z, 1)

        guard prop.placementSurface == .wall else { return transform }

        // Wall props remain upright and face the camera side of the scanned wall.
        var forward = SIMD3<Float>(normal.x, 0, normal.z)
        guard simd_length_squared(forward) > 0.000_001 else { return transform }
        forward = simd_normalize(forward)
        let towardCamera = cameraPosition - position
        if simd_dot(forward, towardCamera) < 0 {
            forward = -forward
        }
        let up = SIMD3<Float>(0, 1, 0)
        let right = simd_normalize(simd_cross(up, forward))
        transform.columns.0 = SIMD4(right.x, right.y, right.z, 0)
        transform.columns.1 = SIMD4(up.x, up.y, up.z, 0)
        transform.columns.2 = SIMD4(forward.x, forward.y, forward.z, 0)
        return transform
    }

    func removeSelectedProp() {
        guard let id = selectedEntityID else {
            publishStatus("Önce silinecek dekoru seç", color: .yellow)
            return
        }
        removeSceneObject(id: id)
    }

    func removeSceneObject(id: UUID) {
        if id == Self.liveAppleSceneID {
            setLiveAppleEnabled(false)
            publishStatus("Canlı elma efekti sahneden kaldırıldı", color: .green)
            return
        }
        guard let arView, let placement = projectStore.placement(id: id) else {
            refreshSceneCatalogs()
            publishStatus("Silinecek sahne öğesi bulunamadı", color: .yellow)
            return
        }
        do {
            try projectStore.remove(id: id)
        } catch {
            publishStatus("Dekor silinemedi: \(error.localizedDescription)", color: .red)
            return
        }

        let anchor = arView.session.currentFrame?.anchors.first(where: {
            PropKind.descriptor(from: $0.name)?.id == id
        })
        if let anchor {
            arView.session.remove(anchor: anchor)
            renderedAnchorIDs.remove(anchor.identifier)
            knownPropAnchorIDs.remove(anchor.identifier)
        }
        managedPropAnchorsByPlacementID[id] = nil
        detachRenderedPlacement(id: id, clearSelection: true)
        refreshSceneCatalogs()
        publishStatus("\(placement.kind.title) sahneden silindi", color: .green)
    }

    func removeAllProps() {
        guard let arView else { return }
        do {
            try projectStore.removeAll()
        } catch {
            publishStatus("Dekorlar temizlenemedi: \(error.localizedDescription)", color: .red)
            return
        }

        renderGeneration &+= 1
        assetLoadSubscriptions.values.forEach { $0.cancel() }
        assetLoadSubscriptions.removeAll()
        loadingEntityIDs.removeAll()
        let propAnchors = arView.session.currentFrame?.anchors.filter {
            PropKind.from(anchorName: $0.name) != nil
        } ?? []
        for anchor in propAnchors {
            arView.session.remove(anchor: anchor)
        }
        renderedEntities.values.forEach { $0.parent?.removeFromParent() }
        renderedLightFootprints.values.forEach { $0.scene?.removeAnchor($0) }
        renderedAnchorIDs.removeAll()
        renderedAnchorIDByPlacementID.removeAll()
        knownPropAnchorIDs.removeAll()
        supersededPropAnchorIDs.removeAll()
        pendingAutoSaveAnchorIDs.removeAll()
        managedPropAnchorsByPlacementID.removeAll()
        renderedEntities.removeAll()
        renderedLights.removeAll()
        renderedLightEmitters.removeAll()
        renderedLightFootprints.removeAll()
        selectedEntityID = nil
        selectedLightSettings = nil
        isAimingLight = false
        setLiveAppleEnabled(false)
        refreshSceneCatalogs()
        publishStatus("Sanal dekorlar temizlendi", color: .green)
    }

    func importUSDZ(from sourceURL: URL) {
        persistSelectedLightSettings()
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }
        do {
            let importedURL = try projectStore.importModel(from: sourceURL)
            importedAssetURLs = projectStore.importedModelURLs
            selectedAssetURL = importedURL
            selectedProp = .custom
            selectedLightSettings = nil
            isPlacingProp = true
            publishStatus("\(importedURL.lastPathComponent) seçildi — kararlı yüzey görünce dokun", color: .green)
        } catch {
            publishStatus("USDZ içe aktarılamadı: \(error.localizedDescription)", color: .red)
        }
    }

    func reportAssetImportFailure(_ error: Error) {
        publishStatus("Dosya seçilemedi: \(error.localizedDescription)", color: .red)
    }

    func selectImportedAsset(_ url: URL) {
        persistSelectedLightSettings()
        selectedAssetURL = url
        selectedProp = .custom
        selectedEntityID = nil
        selectedLightSettings = nil
        isPlacingProp = true
        publishStatus("\(url.deletingPathExtension().lastPathComponent) seçildi — kararlı yüzey görünce dokun", color: .blue)
    }

    func showSceneLightControls() {
        persistSelectedLightSettings()
        isAimingLight = false
        if let placement = projectStore.project.placements.last(where: {
            $0.kind.emitsVirtualLight
        }) {
            selectedEntityID = placement.id
            selectedLightSettings = placement.lightSettings ?? .defaultFixture
            isPlacingProp = false
            if isARReady {
                let recovery = restorePlacementAnchorsIfNeeded(
                    allowCreatingMissingAnchors: true
                )
                if recovery.insertedAnchor {
                    shouldSaveWorldMapWhenReady = true
                    scheduleReadinessRecovery()
                }
            }
            publishStatus(
                "Sahne ışığı seçildi — güç, sıcaklık, yön, eğim ve hüzmeyi ayarla",
                color: .blue
            )
            return
        }

        selectedProp = .cagedCeilingLight
        selectedEntityID = nil
        selectedLightSettings = nil
        isPlacingProp = true
        placementSurfaceMessage = "Sarı: LiDAR tavanı ölçüyor"
        placementSurfaceColor = .yellow
        publishStatus(
            "Sahne ışığı eklemek için taranmış tavana dokun",
            color: .blue
        )
    }

    func saveWorldMap(archiveName: String? = nil) {
        shouldArchiveAfterNextSave = true
        let normalizedName = archiveName?.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingArchiveName = normalizedName.flatMap { $0.isEmpty ? nil : $0 }
        guard let arView else {
            shouldArchiveAfterNextSave = false
            pendingArchiveName = nil
            publishStatus("AR görünümü henüz hazır değil", color: .red)
            return
        }
        guard !isSavingWorldMap else {
            shouldSaveWorldMapWhenReady = true
            publishStatus("Mevcut kayıt tamamlanınca mekân arşivlenecek", color: .yellow)
            return
        }
        guard let trackingState = arView.session.currentFrame?.camera.trackingState,
              case .normal = trackingState else {
            shouldSaveWorldMapWhenReady = true
            scheduleReadinessRecovery()
            publishStatus(
                "Kaydetme sıraya alındı — kamera takibi hazır olunca tamamlanacak",
                color: .yellow
            )
            return
        }
        shouldSaveWorldMapWhenReady = false
        performWorldMapSave(in: arView)
    }

    private func performWorldMapSave(in arView: ARView) {
        guard !isSavingWorldMap else {
            publishStatus("Sahne haritası zaten kaydediliyor", color: .yellow)
            return
        }
        persistSelectedLightSettings()
        do {
            try persistAllEntityTransforms()
        } catch {
            publishStatus("Dekor konumları kaydedilemedi: \(error.localizedDescription)", color: .red)
            return
        }

        isSavingWorldMap = true
        publishStatus("Sahne haritası hazırlanıyor...", color: .yellow)

        captureAndSaveWorldMap(in: arView, attempt: 0)
    }

    private func captureAndSaveWorldMap(in arView: ARView, attempt: Int) {
        arView.session.getCurrentWorldMap { [weak self] worldMap, error in
            guard let self else { return }
            DispatchQueue.main.async {
                do {
                    if let error { throw error }
                    guard let worldMap else { throw CineARError.worldMapUnavailable }
                    // scene.json is written before ARKit acknowledges the newly added
                    // anchor. A world-map snapshot taken during that short window can
                    // otherwise contain the old anchor set. Replace only CineAR's
                    // managed anchors with the freshest ARFrame snapshot; Apple
                    // explicitly permits editing ARWorldMap.anchors before archiving.
                    self.reconcileManagedAnchors(
                        in: worldMap,
                        currentFrame: arView.session.currentFrame
                    )
                    do {
                        try self.validate(worldMap: worldMap)
                    } catch let cinearError as CineARError {
                        guard case .sceneSnapshotMismatch = cinearError,
                              attempt >= 12 else { throw cinearError }

                        // An anchor absent from every source after the retry window has
                        // no recoverable world transform. Keep the valid intersection
                        // instead of leaving the whole project permanently unsavable.
                        let survivingIDs = Set(worldMap.anchors.compactMap {
                            PropKind.descriptor(from: $0.name)?.id
                        })
                        let repairedData = try NSKeyedArchiver.archivedData(
                            withRootObject: worldMap,
                            requiringSecureCoding: true
                        )
                        let discardedCount = try self.projectStore.saveWorldMapData(
                            repairedData,
                            retainingPlacementIDs: survivingIDs
                        )
                        self.discardOrphanedRenderedContent(survivingIDs: survivingIDs)
                        self.isSavingWorldMap = false
                        let archiveResult = self.archiveSavedPlaceIfRequested()
                        self.refreshSceneCatalogs()
                        let archiveDetail = archiveResult.message.map { " — " + $0 } ?? ""
                        self.publishStatus(
                            "Sahne kaydı onarıldı — \(discardedCount) anchorsız kayıt temizlendi\(archiveDetail)",
                            color: archiveResult.failed ? .yellow : .green
                        )
                        return
                    }
                    let data = try NSKeyedArchiver.archivedData(
                        withRootObject: worldMap,
                        requiringSecureCoding: true
                    )
                    try self.projectStore.saveWorldMapData(data)
                    self.isSavingWorldMap = false
                    let archiveResult = self.shouldSaveWorldMapWhenReady
                        ? (message: nil, failed: false)
                        : self.archiveSavedPlaceIfRequested()
                    self.refreshSceneCatalogs()
                    let archiveDetail = archiveResult.message.map { " — " + $0 } ?? ""
                    self.publishStatus(
                        "Set projesi ve dünya haritası kaydedildi\(archiveDetail)",
                        color: archiveResult.failed ? .yellow : .green
                    )
                } catch {
                    if let cinearError = error as? CineARError,
                       case .sceneSnapshotMismatch = cinearError,
                       attempt < 12,
                       self.arView === arView,
                       !self.isRoomScanActive,
                       !self.isSessionInterrupted {
                        self.publishStatus(
                            "Yeni dekor dünya haritasına işleniyor...",
                            color: .yellow
                        )
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                            guard let self, self.isSavingWorldMap else { return }
                            self.captureAndSaveWorldMap(in: arView, attempt: attempt + 1)
                        }
                        return
                    }
                    self.isSavingWorldMap = false
                    self.shouldArchiveAfterNextSave = false
                    self.pendingArchiveName = nil
                    self.publishStatus(
                        "Kaydetme başarısız: \(error.localizedDescription)",
                        color: .red
                    )
                }
                if self.shouldSaveWorldMapWhenReady || self.shouldShowRoomOutlineWhenReady {
                    self.scheduleReadinessRecovery()
                }
            }
        }
    }

    private func reconcileManagedAnchors(
        in worldMap: ARWorldMap,
        currentFrame: ARFrame?
    ) {
        let expectedKinds = Dictionary(uniqueKeysWithValues: projectStore.project.placements.map {
            ($0.id, $0.kind)
        })
        var freshestAnchors: [UUID: ARAnchor] = [:]

        func collect(_ anchors: [ARAnchor]) {
            for anchor in anchors {
                guard let descriptor = PropKind.descriptor(from: anchor.name),
                      expectedKinds[descriptor.id] == descriptor.kind else { continue }
                freshestAnchors[descriptor.id] = anchor
            }
        }

        // A RoomPlan transition can briefly omit app anchors from both its result and
        // the first live frame. Because scanning shares the ARSession coordinate space,
        // the last committed anchor transforms are still safe candidates.
        collect(projectStore.storedManagedAnchors())
        // The new map overrides stored copies; the current ARFrame wins last.
        collect(worldMap.anchors)
        collect(Array(managedPropAnchorsByPlacementID.values))
        if let currentFrame { collect(currentFrame.anchors) }

        let unmanagedAnchors = worldMap.anchors.filter {
            $0.name?.hasPrefix("cinear.prop.") != true
        }
        let managedAnchors = projectStore.project.placements.compactMap {
            freshestAnchors[$0.id]
        }
        worldMap.anchors = unmanagedAnchors + managedAnchors
    }

    private func discardOrphanedRenderedContent(survivingIDs: Set<UUID>) {
        let discardedIDs = Set(renderedEntities.keys).subtracting(survivingIDs)
        for id in discardedIDs {
            detachRenderedPlacement(id: id)
            managedPropAnchorsByPlacementID[id] = nil
        }
        if let selectedEntityID, !survivingIDs.contains(selectedEntityID) {
            self.selectedEntityID = nil
            selectedLightSettings = nil
        }
    }

    private func detachRenderedPlacement(id: UUID, clearSelection: Bool = false) {
        if let anchorID = renderedAnchorIDByPlacementID.removeValue(forKey: id) {
            renderedAnchorIDs.remove(anchorID)
        }
        renderedEntities[id]?.parent?.removeFromParent()
        renderedEntities[id] = nil
        renderedLights[id]?.removeFromParent()
        renderedLights[id] = nil
        renderedLightEmitters[id] = nil
        bloodWaterfallParticles[id] = nil
        if let footprint = renderedLightFootprints.removeValue(forKey: id) {
            footprint.scene?.removeAnchor(footprint)
        }
        assetLoadSubscriptions[id]?.cancel()
        assetLoadSubscriptions[id] = nil
        loadingEntityIDs.remove(id)
        if clearSelection, selectedEntityID == id {
            selectedEntityID = nil
            selectedLightSettings = nil
            isAimingLight = false
        }
    }

    /// RoomPlan reconfiguration and AR relocalization may briefly remove app-owned
    /// anchors even though their scene records and last world transforms are valid.
    /// Rebind visuals to a live matching anchor, or recreate the missing anchor after
    /// a short grace period so an object never disappears permanently.
    private func restorePlacementAnchorsIfNeeded(
        allowCreatingMissingAnchors: Bool
    ) -> (insertedAnchor: Bool, waitingForAnchor: Bool) {
        guard let arView, !isRoomScanActive, !isSessionInterrupted else {
            return (false, false)
        }

        let placements = projectStore.project.placements
        let expectedKinds = Dictionary(uniqueKeysWithValues: placements.map {
            ($0.id, $0.kind)
        })
        var liveAnchors: [UUID: ARAnchor] = [:]
        for anchor in arView.session.currentFrame?.anchors ?? [] {
            guard let descriptor = PropKind.descriptor(from: anchor.name),
                  expectedKinds[descriptor.id] == descriptor.kind,
                  liveAnchors[descriptor.id] == nil else { continue }
            liveAnchors[descriptor.id] = anchor
        }
        var storedAnchors: [UUID: ARAnchor] = [:]
        let needsStoredFallback = placements.contains {
            liveAnchors[$0.id] == nil && managedPropAnchorsByPlacementID[$0.id] == nil
        }
        if needsStoredFallback {
            for anchor in projectStore.storedManagedAnchors() {
                guard let descriptor = PropKind.descriptor(from: anchor.name),
                      expectedKinds[descriptor.id] == descriptor.kind,
                      storedAnchors[descriptor.id] == nil else { continue }
                storedAnchors[descriptor.id] = anchor
            }
        }

        var insertedAnchor = false
        var waitingForAnchor = false
        for placement in placements {
            if let liveAnchor = liveAnchors[placement.id] {
                knownPropAnchorIDs.insert(liveAnchor.identifier)
                managedPropAnchorsByPlacementID[placement.id] = liveAnchor
                if renderedAnchorIDByPlacementID[placement.id] != liveAnchor.identifier {
                    detachRenderedPlacement(id: placement.id)
                    render(prop: placement.kind, id: placement.id, for: liveAnchor)
                }
                continue
            }

            guard let cachedAnchor = managedPropAnchorsByPlacementID[placement.id]
                ?? storedAnchors[placement.id] else { continue }

            if pendingAutoSaveAnchorIDs.contains(cachedAnchor.identifier) {
                waitingForAnchor = true
                continue
            }
            guard allowCreatingMissingAnchors else {
                waitingForAnchor = true
                continue
            }

            let replacement = ARAnchor(
                name: placement.kind.anchorName(id: placement.id),
                transform: cachedAnchor.transform
            )
            supersededPropAnchorIDs.insert(cachedAnchor.identifier)
            managedPropAnchorsByPlacementID[placement.id] = replacement
            knownPropAnchorIDs.insert(replacement.identifier)
            pendingAutoSaveAnchorIDs.insert(replacement.identifier)
            detachRenderedPlacement(id: placement.id)
            arView.session.add(anchor: replacement)
            render(prop: placement.kind, id: placement.id, for: replacement)
            insertedAnchor = true
            waitingForAnchor = true
        }
        return (insertedAnchor, waitingForAnchor)
    }

    @discardableResult
    private func savePendingWorldMapIfPossible(
        trackingState: ARCamera.TrackingState?
    ) -> Bool {
        guard shouldSaveWorldMapWhenReady, !isSavingWorldMap,
              let trackingState, case .normal = trackingState,
              let arView else { return false }
        shouldSaveWorldMapWhenReady = false
        performWorldMapSave(in: arView)
        return true
    }

    private func scheduleReadinessRecovery() {
        readinessRecoveryGeneration &+= 1
        let generation = readinessRecoveryGeneration
        pollReadiness(generation: generation, attempt: 0)
    }

    private func pollReadiness(generation: UInt64, attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + (attempt == 0 ? 0.12 : 0.25)) {
            [weak self] in
            guard let self,
                  self.readinessRecoveryGeneration == generation,
                  !self.isRoomScanActive,
                  !self.isSessionInterrupted else { return }

            let trackingState = self.arView?.session.currentFrame?.camera.trackingState
            var anchorRecoveryWaiting = false
            switch trackingState {
            case .normal?:
                self.isARReady = true
                self.didAttemptSessionFailureRecovery = false
                let anchorRecovery = self.restorePlacementAnchorsIfNeeded(
                    allowCreatingMissingAnchors: attempt >= 4
                )
                anchorRecoveryWaiting = anchorRecovery.waitingForAnchor
                if anchorRecovery.insertedAnchor {
                    self.shouldSaveWorldMapWhenReady = true
                } else if self.savePendingWorldMapIfPossible(trackingState: trackingState) {
                    return
                }
                if self.shouldShowRoomOutlineWhenReady {
                    self.shouldShowRoomOutlineWhenReady = false
                    self.showRoomOutline()
                    return
                }
            case .limited(let reason)?:
                _ = reason
                self.isARReady = false
            case .notAvailable?, nil:
                self.isARReady = false
            }

            let needsAnotherCheck = !self.isARReady
                || self.shouldSaveWorldMapWhenReady
                || self.shouldShowRoomOutlineWhenReady
                || anchorRecoveryWaiting
            if needsAnotherCheck, attempt < 40 {
                self.pollReadiness(generation: generation, attempt: attempt + 1)
            }
        }
    }

    func loadWorldMap() {
        guard !isSavingWorldMap else {
            publishStatus("Kaydetme tamamlanmadan sahne yüklenemez", color: .yellow)
            return
        }
        do {
            let snapshot: StoredWorldMapSnapshot
            let recoveryNotice: String?
            do {
                snapshot = try projectStore.worldMapSnapshotForLoading()
                recoveryNotice = nil
            } catch let storeError as SceneProjectStoreError {
                switch storeError {
                case .worldMapOutOfDate, .worldMapChecksumMismatch:
                    let recovery = try projectStore.recoverWorldMapSnapshot()
                    snapshot = recovery.snapshot
                    if recovery.discardedPlacementCount == 0,
                       recovery.discardedAnchorCount == 0 {
                        recoveryNotice = "Kayıt doğrulaması onarıldı"
                    } else {
                        recoveryNotice = "Sahne kurtarıldı — "
                            + "\(recovery.discardedPlacementCount) haritasız nesne, "
                            + "\(recovery.discardedAnchorCount) sahipsiz anchor temizlendi"
                    }
                default:
                    throw storeError
                }
            }
            guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: ARWorldMap.self,
                from: snapshot.data
            ) else {
                throw CineARError.worldMapUnavailable
            }
            try validate(worldMap: worldMap, placements: snapshot.project.placements)
            projectStore.activate(snapshot)
            importedAssetURLs = projectStore.importedModelURLs
            hasScannedRoom = FileManager.default.fileExists(atPath: roomDataURL.path)
            refreshSceneCatalogs()
            runSession(initialWorldMap: worldMap)
            let prefix = recoveryNotice.map { $0 + " — " } ?? ""
            publishStatus(prefix + "aynı alanı göster; kamera yeniden konumlanıyor", color: .yellow)
        } catch {
            shouldShowRoomOutlineWhenReady = false
            publishStatus("Kayıtlı sahne yüklenemedi: \(error.localizedDescription)", color: .red)
        }
    }

    func loadSavedPlace(id: UUID) {
        guard !isSavingWorldMap else {
            publishStatus("Kaydetme tamamlanmadan başka mekân yüklenemez", color: .yellow)
            return
        }
        do {
            let snapshot = try projectStore.installSavedPlace(id: id)
            guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: ARWorldMap.self,
                from: snapshot.data
            ) else {
                throw CineARError.worldMapUnavailable
            }
            try validate(worldMap: worldMap, placements: snapshot.project.placements)
            projectStore.activate(snapshot)
            importedAssetURLs = projectStore.importedModelURLs
            hasScannedRoom = FileManager.default.fileExists(atPath: roomDataURL.path)
            roomCoordinateSpaceIsActive = hasScannedRoom
            roomRealityRenderer.clear()
            roomRealityRenderer.isVisible = false
            isRoomOutlineVisible = false
            setLiveAppleEnabled(false)
            refreshSceneCatalogs()
            runSession(initialWorldMap: worldMap)
            publishStatus("Kayıtlı mekân açıldı — aynı alanı göstererek yeniden konumlan", color: .yellow)
        } catch {
            refreshSceneCatalogs()
            publishStatus("Mekân yüklenemedi: \(error.localizedDescription)", color: .red)
        }
    }

    func deleteSavedPlace(id: UUID) {
        do {
            try projectStore.deleteSavedPlace(id: id)
            refreshSceneCatalogs()
            publishStatus("Kayıtlı mekân silindi", color: .green)
        } catch {
            publishStatus("Mekân silinemedi: \(error.localizedDescription)", color: .red)
        }
    }

    func startRecording() {
        guard case .idle = recordingPhase else {
            publishStatus("Kayıt işlemi zaten devam ediyor", color: .yellow)
            return
        }
        if isListeningForCGICommands { stopCGIVoiceCommands() }
        recordingPhase = .starting
        isRecordingTransitioning = true
        coachingOverlay?.isHidden = true
        publishStatus("HEVC kayıt hazırlanıyor...", color: .yellow)

        persistSelectedLightSettings()
        do {
            try persistAllEntityTransforms()
            let url = try projectStore.nextRecordingURL()
            recorder.start(
                outputURL: url,
                runtimeFailure: { [weak self] error in
                    guard let self, case .recording = self.recordingPhase else { return }
                    self.publishStatus(
                        "Kayıt sırasında hata oluştu: \(error.localizedDescription)",
                        color: .red
                    )
                    self.stopRecording()
                },
                completion: { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success:
                        guard case .starting = self.recordingPhase else { return }
                        self.recordingPhase = .recording
                        self.isRecordingTransitioning = false
                        self.isRecording = true
                        self.coachingOverlay?.isHidden = true
                        self.statusText = "HEVC çekim devam ediyor — yönü değiştirmeyin"
                        self.trackingColor = .red
                    case .failure(let error):
                        self.recordingPhase = .idle
                        self.isRecordingTransitioning = false
                        self.isRecording = false
                        self.coachingOverlay?.isHidden = false
                        self.publishStatus(
                            "Kayıt başlatılamadı: \(error.localizedDescription)",
                            color: .red
                        )
                    }
                }
            )
        } catch {
            recordingPhase = .idle
            isRecordingTransitioning = false
            coachingOverlay?.isHidden = false
            publishStatus("Kayıt dosyası açılamadı: \(error.localizedDescription)", color: .red)
        }
    }

    func stopRecording() {
        guard case .recording = recordingPhase else {
            publishStatus("Durdurulabilecek etkin bir kayıt yok", color: .yellow)
            return
        }
        recordingPhase = .stopping
        isRecordingTransitioning = true
        publishStatus("MOV dosyası tamamlanıyor...", color: .yellow)

        recorder.stop { [weak self] result in
            guard let self else { return }
            self.recordingPhase = .idle
            self.isRecordingTransitioning = false
            self.isRecording = false
            self.coachingOverlay?.isHidden = false
            switch result {
            case .success(let url):
                self.lastRecordingURL = url
                self.publishStatus("Çekim MOV dosyasına kaydedildi", color: .green)
            case .failure(let error):
                self.publishStatus("Kayıt bitirilemedi: \(error.localizedDescription)", color: .red)
            }
        }
    }

    private func render(prop: PropKind, id: UUID, for anchor: ARAnchor) {
        guard arView != nil,
              knownPropAnchorIDs.contains(anchor.identifier),
              !renderedAnchorIDs.contains(anchor.identifier),
              renderedEntities[id] == nil,
              !loadingEntityIDs.contains(id) else { return }
        guard let placement = projectStore.placement(id: id), placement.kind == prop else {
            publishStatus(
                "Sahne tutarsız: \(id.uuidString) kimlikli anchor için dekor kaydı yok",
                color: .red
            )
            return
        }

        if let descriptor = prop.photorealDescriptor {
            let generation = renderGeneration
            let loadingProxy = makeLoadingProxy(
                for: prop,
                dimensions: descriptor.dimensions
            )
            attach(
                entity: loadingProxy,
                prop: prop,
                id: id,
                anchor: anchor,
                generation: generation
            )
            guard let modelURL = bundledAssetURL(named: descriptor.assetName) else {
                publishStatus(
                    "\(prop.title) USDZ pakette bulunamadı; görünür yedek model kullanılıyor",
                    color: .yellow
                )
                return
            }
            loadingEntityIDs.insert(id)
            let request = Entity.loadAsync(contentsOf: modelURL)
            assetLoadSubscriptions[id] = request
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    guard let self, self.renderGeneration == generation else { return }
                    self.loadingEntityIDs.remove(id)
                    self.assetLoadSubscriptions[id] = nil
                    if case .failure(let error) = completion {
                        self.publishStatus(
                            "\(prop.title) USDZ açılamadı; yedek model gösteriliyor: "
                                + error.localizedDescription,
                            color: .yellow
                        )
                    }
                } receiveValue: { [weak self] content in
                    guard let self,
                          let entity = self.makePhotorealLibraryEntity(
                            content: content,
                            prop: prop,
                            descriptor: descriptor
                          ) else {
                        self?.publishStatus(
                            "\(prop.title) ölçüsü okunamadı; yedek model gösteriliyor",
                            color: .yellow
                        )
                        return
                    }
                    if self.replaceRenderedEntity(
                        entity: entity,
                        prop: prop,
                        id: id,
                        anchor: anchor,
                        generation: generation
                    ) {
                        self.publishStatus(
                            "\(prop.title) gerçek USDZ modeli hazır",
                            color: .green
                        )
                    }
                }
            return
        }

        if prop.bundledAssetName != nil {
            let entity: ModelEntity
            if let bundledEntity = makeBundledLibraryEntity(for: prop) {
                entity = bundledEntity
            } else {
                let dimensions = libraryDescriptor(for: prop)?.dimensions
                    ?? SIMD3<Float>(repeating: 0.5)
                entity = makeLoadingProxy(for: prop, dimensions: dimensions)
                publishStatus(
                    "\(prop.title) USDZ açılamadı; görünür yedek model kullanılıyor",
                    color: .yellow
                )
            }
            attach(
                entity: entity,
                prop: prop,
                id: id,
                anchor: anchor,
                generation: renderGeneration
            )
            return
        }

        if prop == .custom {
            let modelURL: URL
            guard let fileName = placement.assetFileName else {
                publishStatus("3B dekor yüklenemedi: USDZ kaydı eksik", color: .red)
                return
            }
            do {
                modelURL = try projectStore.modelURL(fileName: fileName)
            } catch {
                publishStatus("3B dekor yüklenemedi: \(error.localizedDescription)", color: .red)
                return
            }
            let generation = renderGeneration
            attach(
                entity: makeLoadingProxy(
                    for: prop,
                    dimensions: SIMD3<Float>(repeating: 0.35)
                ),
                prop: prop,
                id: id,
                anchor: anchor,
                generation: generation
            )
            loadingEntityIDs.insert(id)
            let request = ModelEntity.loadModelAsync(contentsOf: modelURL)
            assetLoadSubscriptions[id] = request
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    guard let self, self.renderGeneration == generation else { return }
                    self.loadingEntityIDs.remove(id)
                    self.assetLoadSubscriptions[id] = nil
                    if case .failure(let error) = completion {
                        self.publishStatus(
                            "3B dekor açılamadı; yedek model gösteriliyor: "
                                + error.localizedDescription,
                            color: .yellow
                        )
                    }
                } receiveValue: { [weak self] entity in
                    guard let self else { return }
                    if self.replaceRenderedEntity(
                        entity: entity,
                        prop: prop,
                        id: id,
                        anchor: anchor,
                        generation: generation
                    ) {
                        self.publishStatus("3B dekor hazır", color: .green)
                    }
                }
            return
        }

        attach(
            entity: makeBuiltInEntity(for: prop),
            prop: prop,
            id: id,
            anchor: anchor,
            generation: renderGeneration
        )
    }

    private func attach(
        entity: ModelEntity,
        prop: PropKind,
        id: UUID,
        anchor: ARAnchor,
        generation: UInt64
    ) {
        guard let arView,
              generation == renderGeneration,
              knownPropAnchorIDs.contains(anchor.identifier),
              !renderedAnchorIDs.contains(anchor.identifier),
              renderedEntities[id] == nil,
              let placement = projectStore.placement(id: id),
              placement.kind == prop else { return }
        let entity = makeContactPivotEntity(content: entity, for: prop)
        let anchorEntity = AnchorEntity(anchor: anchor)
        entity.name = id.uuidString
        entity.transform = placement.transform.realityKitTransform
        if entity.collision == nil {
            entity.generateCollisionShapes(recursive: true)
        }
        addContactShadow(to: entity, for: prop)
        if prop.emitsVirtualLight {
            let settings = placement.lightSettings ?? .defaultFixture
            installVirtualLight(on: entity, prop: prop, id: id, settings: settings)
            if selectedEntityID == id {
                selectedLightSettings = settings
            }
        }
        anchorEntity.addChild(entity)
        arView.scene.addAnchor(anchorEntity)
        if prop.emitsVirtualLight,
           let light = renderedLights[id],
           let settings = placement.lightSettings ?? selectedLightSettings {
            apply(settings: settings, to: light, prop: prop)
        }

        // Translation is deliberately excluded: a placed prop stays bound to its
        // world anchor. Rotation and scale remain available for art direction.
        arView.installGestures([.rotation, .scale], for: entity)

        renderedAnchorIDs.insert(anchor.identifier)
        renderedAnchorIDByPlacementID[id] = anchor.identifier
        renderedEntities[id] = entity
        if prop == .bloodWaterfall {
            installBloodWaterfallRuntime(on: entity, id: id)
        }
    }

    private func installBloodWaterfallRuntime(on entity: ModelEntity, id: UUID) {
        var particles: [BloodWaterfallParticle] = []
        for index in 0..<18 {
            guard let drop = entity.findEntity(named: "cinear.blood.drop.\(index)") as? ModelEntity
            else { continue }
            particles.append(
                BloodWaterfallParticle(
                    entity: drop,
                    phase: Float(index) / 18,
                    lateral: drop.position.x,
                    depth: drop.position.z
                )
            )
        }
        bloodWaterfallParticles[id] = particles
    }

    private func updateBloodWaterfalls(timestamp: TimeInterval) {
        let time = Float(timestamp)
        for particles in bloodWaterfallParticles.values {
            for (index, particle) in particles.enumerated() {
                let progress = (time * (0.62 + Float(index % 4) * 0.035) + particle.phase)
                    .truncatingRemainder(dividingBy: 1)
                particle.entity.position = [
                    particle.lateral + sin(time * 2.3 + Float(index)) * 0.012,
                    -0.04 - progress * 1.43,
                    particle.depth
                ]
                let stretch = 1.35 + min(progress * 1.8, 1.5)
                particle.entity.scale = [1, stretch, 1]
            }
        }
    }

    @discardableResult
    private func replaceRenderedEntity(
        entity: ModelEntity,
        prop: PropKind,
        id: UUID,
        anchor: ARAnchor,
        generation: UInt64
    ) -> Bool {
        guard let arView,
              generation == renderGeneration,
              knownPropAnchorIDs.contains(anchor.identifier),
              renderedAnchorIDs.contains(anchor.identifier),
              let current = renderedEntities[id],
              let parent = current.parent,
              let placement = projectStore.placement(id: id),
              placement.kind == prop else { return false }

        let preservedTransform = current.transform
        let entity = makeContactPivotEntity(content: entity, for: prop)
        renderedLights[id]?.removeFromParent()
        renderedLights[id] = nil
        renderedLightEmitters[id] = nil
        current.removeFromParent()

        entity.name = id.uuidString
        entity.transform = preservedTransform
        if entity.collision == nil {
            entity.generateCollisionShapes(recursive: true)
        }
        addContactShadow(to: entity, for: prop)
        if prop.emitsVirtualLight {
            let settings = (selectedEntityID == id ? selectedLightSettings : nil)
                ?? placement.lightSettings
                ?? .defaultFixture
            installVirtualLight(on: entity, prop: prop, id: id, settings: settings)
            if selectedEntityID == id {
                selectedLightSettings = settings
            }
        }
        parent.addChild(entity)
        if prop.emitsVirtualLight,
           let light = renderedLights[id] {
            let settings = (selectedEntityID == id ? selectedLightSettings : nil)
                ?? placement.lightSettings
                ?? .defaultFixture
            apply(settings: settings, to: light, prop: prop)
        }
        arView.installGestures([.rotation, .scale], for: entity)
        renderedEntities[id] = entity
        return true
    }

    func setSelectedLightEnabled(_ isEnabled: Bool) {
        guard var settings = selectedLightSettings else { return }
        settings.isEnabled = isEnabled
        previewSelectedLight(settings)
        persistSelectedLightSettings()
    }

    func setSelectedLightIntensity(_ lumens: Float) {
        guard var settings = selectedLightSettings else { return }
        settings.intensityLumens = min(max(lumens, 0), 12_000)
        previewSelectedLight(settings)
    }

    func setSelectedLightTemperature(_ kelvin: Float) {
        guard var settings = selectedLightSettings else { return }
        settings.temperatureKelvin = min(max(kelvin, 2_000), 6_500)
        previewSelectedLight(settings)
    }

    func setSelectedLightConeAngle(_ degrees: Float) {
        guard var settings = selectedLightSettings else { return }
        settings.coneAngleDegrees = min(max(degrees, 8), 120)
        previewSelectedLight(settings)
    }

    func setSelectedLightSoftness(_ softness: Float) {
        guard var settings = selectedLightSettings else { return }
        settings.beamSoftness = min(max(softness, 0), 1)
        previewSelectedLight(settings)
    }

    func setSelectedLightYaw(_ degrees: Float) {
        guard var settings = selectedLightSettings else { return }
        settings.yawDegrees = min(max(degrees, -180), 180)
        settings.targetPosition = nil
        settings.targetNormal = nil
        previewSelectedLight(settings)
    }

    func setSelectedLightTilt(_ degrees: Float) {
        guard var settings = selectedLightSettings else { return }
        settings.tiltDegrees = min(max(degrees, -75), 75)
        settings.targetPosition = nil
        settings.targetNormal = nil
        previewSelectedLight(settings)
    }

    func beginSelectedLightTargeting() {
        guard selectedEntityID != nil, selectedLightSettings != nil else {
            publishStatus("Önce sahnedeki bir ışığı seç", color: .yellow)
            return
        }
        isPlacingProp = false
        isAimingLight = true
        publishStatus(
            "Projektör hedefi — ışığın vuracağı zemin, masa veya duvara dokun",
            color: .blue
        )
    }

    func cancelSelectedLightTargeting() {
        guard isAimingLight else { return }
        isAimingLight = false
        publishStatus("Projektör hedef seçimi iptal edildi", color: .yellow)
    }

    func persistSelectedLightSettings() {
        guard let id = selectedEntityID,
              let settings = selectedLightSettings,
              settings.isValid,
              let placement = projectStore.placement(id: id),
              placement.kind.emitsVirtualLight,
              placement.lightSettings != settings else { return }
        do {
            try projectStore.updateLightSettings(id: id, settings: settings)
        } catch {
            publishStatus("Işık ayarları kaydedilemedi: \(error.localizedDescription)", color: .red)
        }
    }

    private func previewSelectedLight(_ settings: VirtualLightSettings) {
        selectedLightSettings = settings
        guard let id = selectedEntityID,
              let light = renderedLights[id],
              let prop = projectStore.placement(id: id)?.kind else { return }
        apply(settings: settings, to: light, prop: prop)
    }

    private func retargetSelectedLight(in arView: ARView, at point: CGPoint) {
        guard let id = selectedEntityID,
              var settings = selectedLightSettings,
              renderedLights[id] != nil else {
            isAimingLight = false
            publishStatus("Işık hedeflenemedi; sahnedeki ışığı yeniden seç", color: .yellow)
            return
        }
        guard let hit = projectorSurfaceHit(in: arView, at: point) else {
            publishStatus("Projektör hedefi bulunamadı; yüzeyi biraz daha tara", color: .yellow)
            return
        }
        let normal = simd_normalize(hit.normal)
        settings.targetPosition = [hit.position.x, hit.position.y, hit.position.z]
        settings.targetNormal = [normal.x, normal.y, normal.z]
        selectedLightSettings = settings
        isAimingLight = false
        previewSelectedLight(settings)
        persistSelectedLightSettings()
        publishStatus(
            String(format: "Projektör hedefi sabitlendi — %.2f m", hit.distanceMeters),
            color: .green
        )
    }

    private func projectorSurfaceHit(in arView: ARView, at point: CGPoint) -> ProjectorSurfaceHit? {
        if let hit = arView.hitTest(point, query: .all, mask: .all).first(where: {
            entityID(from: $0.entity) == nil
                && !belongsToProjectorVisualization($0.entity)
        }), simd_length_squared(hit.normal) > 0.000_001 {
            let distance = simd_distance(hit.position, arView.cameraTransform.translation)
            return ProjectorSurfaceHit(
                position: hit.position,
                normal: hit.normal,
                distanceMeters: distance
            )
        }
        if let hit = roomRealityRenderer.placementHit(in: arView, at: point),
           simd_length_squared(hit.normal) > 0.000_001 {
            return ProjectorSurfaceHit(
                position: hit.position,
                normal: hit.normal,
                distanceMeters: simd_distance(hit.position, arView.cameraTransform.translation)
            )
        }
        for alignment in [ARRaycastQuery.TargetAlignment.horizontal, .vertical] {
            if let result = arView.raycast(
                from: point,
                allowing: .existingPlaneGeometry,
                alignment: alignment
            ).first {
                let position = SIMD3<Float>(
                    result.worldTransform.columns.3.x,
                    result.worldTransform.columns.3.y,
                    result.worldTransform.columns.3.z
                )
                let normal = SIMD3<Float>(
                    result.worldTransform.columns.1.x,
                    result.worldTransform.columns.1.y,
                    result.worldTransform.columns.1.z
                )
                return ProjectorSurfaceHit(
                    position: position,
                    normal: normal,
                    distanceMeters: simd_distance(position, arView.cameraTransform.translation)
                )
            }
        }
        return nil
    }

    private func installVirtualLight(
        on entity: ModelEntity,
        prop: PropKind,
        id: UUID,
        settings: VirtualLightSettings
    ) {
        renderedLights[id]?.removeFromParent()
        let light = SpotLight()
        light.name = "cinear.virtual-light.\(id.uuidString)"
        light.shadow = SpotLightComponent.Shadow()

        let dimensions = prop.photorealDescriptor?.dimensions ?? SIMD3<Float>(0.5, 0.5, 0.5)
        switch prop.placementSurface {
        case .ceiling:
            light.position = [0, -dimensions.y * 0.48, 0]
        case .wall:
            light.position = [0, 0, dimensions.z * 0.52]
        case .floor, .horizontal:
            light.position = [0, dimensions.y * 0.34, dimensions.z * 0.16]
        }
        entity.addChild(light)
        renderedLights[id] = light
        var emitterMaterial = UnlitMaterial()
        emitterMaterial.color = .init(tint: .white)
        let emitter: ModelEntity
        if prop == .cagedCeilingLight || prop == .lightPanel {
            emitter = ModelEntity(
                mesh: .generateBox(size: [0.58, 0.018, 0.07], cornerRadius: 0.009),
                materials: [emitterMaterial]
            )
        } else {
            emitter = ModelEntity(
                mesh: .generateSphere(radius: 0.035),
                materials: [emitterMaterial]
            )
        }
        emitter.name = "cinear.virtual-light.emitter"
        light.addChild(emitter)
        renderedLightEmitters[id] = emitter
        apply(settings: settings, to: light, prop: prop)
    }

    private func apply(settings: VirtualLightSettings, to light: SpotLight, prop: PropKind) {
        light.isEnabled = settings.isEnabled
        light.light.intensity = settings.intensityLumens
        light.light.color = Self.colorTemperature(kelvin: settings.temperatureKelvin)
        light.light.innerAngleInDegrees = settings.coneAngleDegrees
            * (1 - settings.effectiveBeamSoftness * 0.72)
        light.light.outerAngleInDegrees = settings.coneAngleDegrees
        light.light.attenuationRadius = min(
            max(sqrt(max(settings.intensityLumens, 1) / 1_000) * 4, 2),
            12
        )
        if let target = settings.projectorTarget,
           let parent = light.parent {
            let parentWorld = parent.transformMatrix(relativeTo: nil)
            let localTarget4 = simd_inverse(parentWorld) * SIMD4(target.x, target.y, target.z, 1)
            let localTarget = SIMD3(localTarget4.x, localTarget4.y, localTarget4.z)
            let direction = localTarget - light.position
            if simd_length_squared(direction) > 0.000_001 {
                light.orientation = simd_quatf(
                    from: SIMD3<Float>(0, 0, -1),
                    to: simd_normalize(direction)
                )
                light.light.attenuationRadius = min(max(simd_length(direction) * 1.35, 2), 20)
            }
        } else {
            let baseDirection: SIMD3<Float>
            switch prop.placementSurface {
            case .ceiling:
                baseDirection = [0, -1, 0]
            case .wall:
                baseDirection = simd_normalize(SIMD3<Float>(0, -0.35, 1))
            case .floor, .horizontal:
                baseDirection = simd_normalize(SIMD3<Float>(0, -0.88, 0.32))
            }
            let yaw = simd_quatf(
                angle: settings.effectiveYawDegrees * .pi / 180,
                axis: SIMD3<Float>(0, 1, 0)
            )
            let tilt = simd_quatf(
                angle: settings.effectiveTiltDegrees * .pi / 180,
                axis: SIMD3<Float>(1, 0, 0)
            )
            let direction = simd_normalize(yaw.act(tilt.act(baseDirection)))
            light.orientation = simd_quatf(
                from: SIMD3<Float>(0, 0, -1),
                to: direction
            )
        }
        if let idText = light.name.split(separator: ".").last,
           let id = UUID(uuidString: String(idText)),
           let emitter = renderedLightEmitters[id] {
            var material = UnlitMaterial()
            material.color = .init(tint: Self.colorTemperature(kelvin: settings.temperatureKelvin))
            if var model = emitter.components[ModelComponent.self] {
                model.materials = [material]
                emitter.components.set(model)
            }
        }
        refreshProjectorFootprint(id: entityID(for: light), settings: settings)
    }

    private func refreshProjectorLights() {
        for (id, light) in renderedLights {
            guard let placement = projectStore.placement(id: id) else { continue }
            let settings = (selectedEntityID == id ? selectedLightSettings : nil)
                ?? placement.lightSettings
                ?? .defaultFixture
            apply(settings: settings, to: light, prop: placement.kind)
        }
    }

    private func refreshProjectorFootprint(
        id: UUID?,
        settings: VirtualLightSettings
    ) {
        guard let id, let arView, let light = renderedLights[id], light.scene != nil,
              settings.isEnabled, settings.intensityLumens > 1 else {
            if let id, let footprint = renderedLightFootprints.removeValue(forKey: id) {
                footprint.scene?.removeAnchor(footprint)
            }
            return
        }

        let lightWorld = light.transformMatrix(relativeTo: nil)
        let origin = SIMD3<Float>(
            lightWorld.columns.3.x,
            lightWorld.columns.3.y,
            lightWorld.columns.3.z
        )
        let forward = simd_normalize(SIMD3<Float>(
            -lightWorld.columns.2.x,
            -lightWorld.columns.2.y,
            -lightWorld.columns.2.z
        ))

        let target: SIMD3<Float>
        let storedNormal: SIMD3<Float>?
        if let storedTarget = settings.projectorTarget {
            target = storedTarget
            storedNormal = settings.projectorTargetNormal
        } else if forward.y < -0.025,
                  let floorY = lastKnownFloorY {
            let distance = (floorY - origin.y) / forward.y
            guard distance.isFinite, (0.15...20).contains(distance) else { return }
            target = origin + forward * distance
            storedNormal = [0, 1, 0]
        } else {
            if let footprint = renderedLightFootprints.removeValue(forKey: id) {
                footprint.scene?.removeAnchor(footprint)
            }
            return
        }

        let beam = target - origin
        let distance = simd_length(beam)
        guard distance.isFinite, distance >= 0.08, distance <= 20 else { return }
        let direction = beam / distance
        var normal = storedNormal ?? -direction
        guard simd_length_squared(normal) > 0.000_001 else { return }
        normal = simd_normalize(normal)
        if simd_dot(normal, -direction) < 0 { normal = -normal }

        let halfAngle = settings.coneAngleDegrees * .pi / 360
        let radius = min(max(tan(halfAngle) * distance, 0.045), 3.5)
        let incidence = max(abs(simd_dot(direction, normal)), 0.28)
        let elongatedRadius = min(radius / incidence, radius * 3.2)

        let anchor: AnchorEntity
        let visualRoot: Entity
        if let existing = renderedLightFootprints[id],
           let existingRoot = existing.children.first {
            anchor = existing
            visualRoot = existingRoot
        } else {
            anchor = AnchorEntity(world: .zero)
            anchor.name = "cinear.projector.anchor.\(id.uuidString)"
            visualRoot = Entity()
            visualRoot.name = "cinear.projector.surface.\(id.uuidString)"
            anchor.addChild(visualRoot)
            let factors: [Float] = [1.0, 0.82, 0.64, 0.46, 0.28]
            for (index, factor) in factors.enumerated() {
                guard let disc = makeProjectorDisc(index: index) else { continue }
                disc.name = "cinear.projector.disc.\(index)"
                disc.position.y = Float(index) * 0.00035
                disc.scale = [factor, 1, factor]
                visualRoot.addChild(disc)
            }
            arView.scene.addAnchor(anchor)
            renderedLightFootprints[id] = anchor
        }

        var projectedForward = direction - normal * simd_dot(direction, normal)
        if simd_length_squared(projectedForward) < 0.000_001 {
            projectedForward = SIMD3<Float>(0, 0, 1)
                - normal * simd_dot(SIMD3<Float>(0, 0, 1), normal)
        }
        if simd_length_squared(projectedForward) < 0.000_001 {
            projectedForward = SIMD3<Float>(1, 0, 0)
                - normal * simd_dot(SIMD3<Float>(1, 0, 0), normal)
        }
        let surfaceForward = simd_normalize(projectedForward)
        let surfaceRight = simd_normalize(simd_cross(normal, surfaceForward))
        let orientationMatrix = simd_float3x3(columns: (
            surfaceRight,
            normal,
            surfaceForward
        ))
        visualRoot.position = target + normal * 0.006
        visualRoot.orientation = simd_quatf(orientationMatrix)

        let factors: [Float] = [1.0, 0.82, 0.64, 0.46, 0.28]
        let intensity = min(max(settings.intensityLumens / 12_000, 0), 1)
        let color = Self.colorTemperature(kelvin: settings.temperatureKelvin)
        for (index, child) in visualRoot.children.enumerated() {
            guard index < factors.count, let disc = child as? ModelEntity else { continue }
            let factor = factors[index]
            disc.scale = [radius * factor, 1, elongatedRadius * factor]
            let edgeWeight = Float(index + 1) / Float(factors.count)
            let alpha = CGFloat(
                min(0.34, (0.018 + intensity * 0.105)
                    * (0.55 + edgeWeight * (1.2 - settings.effectiveBeamSoftness * 0.45)))
            )
            var material = UnlitMaterial()
            material.color = .init(tint: color.withAlphaComponent(alpha))
            if var model = disc.components[ModelComponent.self] {
                model.materials = [material]
                disc.components.set(model)
            }
        }
    }

    private func makeProjectorDisc(index: Int) -> ModelEntity? {
        let segments = 48
        var positions: [SIMD3<Float>] = [.zero]
        positions.reserveCapacity(segments + 1)
        for segment in 0..<segments {
            let angle = Float(segment) / Float(segments) * 2 * .pi
            positions.append([cos(angle), 0, sin(angle)])
        }
        var indices: [UInt32] = []
        indices.reserveCapacity(segments * 3)
        for segment in 0..<segments {
            indices.append(0)
            indices.append(UInt32((segment + 1) % segments + 1))
            indices.append(UInt32(segment + 1))
        }
        var descriptor = MeshDescriptor(name: "cinear.projector.disc.\(index)")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.primitives = .triangles(indices)
        guard let mesh = try? MeshResource.generate(from: [descriptor]) else { return nil }
        return ModelEntity(mesh: mesh, materials: [UnlitMaterial()])
    }

    private func entityID(for light: SpotLight) -> UUID? {
        guard let idText = light.name.split(separator: ".").last else { return nil }
        return UUID(uuidString: String(idText))
    }

    private static func colorTemperature(kelvin: Float) -> UIColor {
        let temperature = Double(min(max(kelvin, 2_000), 6_500)) / 100
        let red: Double
        let green: Double
        let blue: Double
        if temperature <= 66 {
            red = 255
            green = 99.4708025861 * log(temperature) - 161.1195681661
            blue = temperature <= 19
                ? 0
                : 138.5177312231 * log(temperature - 10) - 305.0447927307
        } else {
            red = 329.698727446 * pow(temperature - 60, -0.1332047592)
            green = 288.1221695283 * pow(temperature - 60, -0.0755148492)
            blue = 255
        }
        func channel(_ value: Double) -> CGFloat {
            CGFloat(min(max(value, 0), 255) / 255)
        }
        return UIColor(red: channel(red), green: channel(green), blue: channel(blue), alpha: 1)
    }

    private func persistAllEntityTransforms() throws {
        let transforms = Dictionary(uniqueKeysWithValues: renderedEntities.map {
            ($0.key, $0.value.transform)
        })
        try projectStore.updateTransforms(transforms)
    }

    private func validate(
        worldMap: ARWorldMap,
        placements: [PlacementRecord]? = nil
    ) throws {
        var anchorKinds: [UUID: PropKind] = [:]
        for anchor in worldMap.anchors {
            guard let descriptor = PropKind.descriptor(from: anchor.name) else { continue }
            guard anchorKinds.updateValue(descriptor.kind, forKey: descriptor.id) == nil else {
                throw CineARError.duplicatePropAnchor(descriptor.id)
            }
        }

        let records = placements ?? projectStore.project.placements
        let placementKinds = Dictionary(uniqueKeysWithValues: records.map {
            ($0.id, $0.kind)
        })
        let anchorIDs = Set(anchorKinds.keys)
        let placementIDs = Set(placementKinds.keys)
        let missingFromMap = placementIDs.subtracting(anchorIDs).count
        let missingFromProject = anchorIDs.subtracting(placementIDs).count
        let kindMismatch = anchorIDs.intersection(placementIDs).filter {
            anchorKinds[$0] != placementKinds[$0]
        }.count

        guard missingFromMap == 0, missingFromProject == 0, kindMismatch == 0 else {
            throw CineARError.sceneSnapshotMismatch(
                missingFromMap: missingFromMap,
                missingFromProject: missingFromProject,
                kindMismatch: kindMismatch
            )
        }
    }

    private func entityID(from entity: Entity) -> UUID? {
        var candidate: Entity? = entity
        while let current = candidate {
            if let id = UUID(uuidString: current.name) { return id }
            candidate = current.parent
        }
        return nil
    }

    private func belongsToRoomReality(_ entity: Entity) -> Bool {
        var candidate: Entity? = entity
        while let current = candidate {
            if current.name.hasPrefix("cinear.reality.") { return true }
            candidate = current.parent
        }
        return false
    }

    private func belongsToProjectorVisualization(_ entity: Entity) -> Bool {
        var candidate: Entity? = entity
        while let current = candidate {
            if current.name.hasPrefix("cinear.projector.") { return true }
            candidate = current.parent
        }
        return false
    }

    /// Wraps every visual in a surface-contact pivot. Rotation and scale then happen
    /// around the physical contact point instead of the USDZ's often arbitrary center.
    private func makeContactPivotEntity(
        content: ModelEntity,
        for prop: PropKind
    ) -> ModelEntity {
        if content.name.hasPrefix("cinear.contact-pivot") { return content }
        let root = ModelEntity()
        root.name = "cinear.contact-pivot.\(prop.rawValue)"
        root.addChild(content)
        let bounds = root.visualBounds(
            recursive: true,
            relativeTo: root,
            excludeInactive: false
        )
        let extents = bounds.extents
        if [extents.x, extents.y, extents.z].allSatisfy({ $0.isFinite && $0 > 0.0001 }) {
            switch prop.placementSurface {
            case .floor, .horizontal:
                let minimumY = bounds.center.y - extents.y * 0.5
                content.position.y -= minimumY
            case .ceiling:
                let maximumY = bounds.center.y + extents.y * 0.5
                content.position.y -= maximumY
            case .wall:
                let minimumZ = bounds.center.z - extents.z * 0.5
                content.position.z += 0.008 - minimumZ
            }
            root.collision = CollisionComponent(
                shapes: [ShapeResource.generateBox(size: SIMD3(
                    max(extents.x, 0.04),
                    max(extents.y, 0.04),
                    max(extents.z, 0.04)
                ))]
            )
        } else if content.collision == nil {
            content.generateCollisionShapes(recursive: true)
        }
        return root
    }

    private func defaultTransform(for prop: PropKind) -> Transform {
        return Transform(
            scale: [1, 1, 1],
            rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
            translation: .zero
        )
    }

    /// Gives immediate visual confirmation while RealityKit opens a bundled or
    /// imported USDZ. It deliberately uses the catalog envelope, so it occupies the
    /// same contact plane as the final asset and remains a usable fallback if that
    /// individual file cannot be decoded on the device.
    private func makeLoadingProxy(
        for prop: PropKind,
        dimensions: SIMD3<Float>
    ) -> ModelEntity {
        let safeDimensions = SIMD3<Float>(
            max(dimensions.x, 0.04),
            max(dimensions.y, 0.04),
            max(dimensions.z, 0.04)
        )
        let mesh = MeshResource.generateBox(
            size: safeDimensions,
            cornerRadius: min(safeDimensions.x, safeDimensions.y, safeDimensions.z) * 0.06
        )
        let entity: ModelEntity
        if prop.emitsVirtualLight {
            var material = UnlitMaterial()
            material.color = .init(
                tint: UIColor(red: 1.0, green: 0.82, blue: 0.48, alpha: 1)
            )
            entity = ModelEntity(mesh: mesh, materials: [material])
        } else {
            let material = SimpleMaterial(
                color: UIColor(red: 0.28, green: 0.52, blue: 0.66, alpha: 1),
                roughness: 0.82,
                isMetallic: false
            )
            entity = ModelEntity(mesh: mesh, materials: [material])
        }
        entity.name = "cinear.loading-proxy.\(prop.rawValue)"
        entity.collision = CollisionComponent(
            shapes: [ShapeResource.generateBox(size: safeDimensions)]
        )
        return entity
    }

    private func bundledAssetURL(named assetName: String) -> URL? {
        if let url = Bundle.main.url(
            forResource: assetName,
            withExtension: "usdz",
            subdirectory: "RoomAssets"
        ) ?? Bundle.main.url(forResource: assetName, withExtension: "usdz") {
            return url
        }
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        let explicitURL = resourceURL
            .appendingPathComponent("RoomAssets", isDirectory: true)
            .appendingPathComponent(assetName)
            .appendingPathExtension("usdz")
        return FileManager.default.fileExists(atPath: explicitURL.path) ? explicitURL : nil
    }

    private func makePhotorealLibraryEntity(
        content: Entity,
        prop: PropKind,
        descriptor: PhotorealPropDescriptor
    ) -> ModelEntity? {
        let measurementRoot = Entity()
        measurementRoot.addChild(content)
        let bounds = measurementRoot.visualBounds(
            recursive: true,
            relativeTo: measurementRoot,
            // The USDZ is intentionally measured before it is anchored. RealityKit
            // reports unanchored entities as inactive, so excluding inactive children
            // produces a zero-size box and forces every valid model to its proxy.
            excludeInactive: false
        )
        content.removeFromParent()
        let extents = bounds.extents
        guard [extents.x, extents.y, extents.z].allSatisfy({ $0.isFinite && $0 > 0.0001 }) else {
            return nil
        }
        let ratios = descriptor.dimensions / extents
        let scale = min(ratios.x, ratios.y, ratios.z)
        guard scale.isFinite, (0.001...1_000).contains(scale) else { return nil }

        let centered = Entity()
        centered.addChild(content)
        centered.position = -bounds.center

        let fitted = Entity()
        fitted.addChild(centered)
        fitted.scale = SIMD3(repeating: scale)

        let root = ModelEntity()
        root.name = "cinear.photoreal.\(prop.rawValue)"
        root.addChild(fitted)
        let fittedBounds = root.visualBounds(
            recursive: true,
            relativeTo: root,
            excludeInactive: false
        )
        guard [fittedBounds.extents.x, fittedBounds.extents.y, fittedBounds.extents.z]
            .allSatisfy({ $0.isFinite && $0 > 0.0001 && $0 < 12 }) else { return nil }

        // The descriptor defines the placement envelope. Align the rendered mesh
        // with the envelope's contact face so uniformly fitted assets never float.
        switch descriptor.surface {
        case .floor, .horizontal:
            fitted.position.y = (-descriptor.dimensions.y + fittedBounds.extents.y) * 0.5
        case .ceiling:
            fitted.position.y = (descriptor.dimensions.y - fittedBounds.extents.y) * 0.5
        case .wall:
            fitted.position.z = (-descriptor.dimensions.z + fittedBounds.extents.z) * 0.5
        }
        root.collision = CollisionComponent(
            shapes: [ShapeResource.generateBox(size: descriptor.dimensions)]
        )
        return root
    }

    private func makeBundledLibraryEntity(for prop: PropKind) -> ModelEntity? {
        guard let descriptor = libraryDescriptor(for: prop),
              let content = manualAssetProvider.makeEntity(
                for: descriptor.role,
                theme: RealityThemeCatalog.modern,
                targetDimensions: descriptor.dimensions
              ) else { return nil }

        let root = ModelEntity()
        root.name = "cinear.library.\(prop.rawValue)"
        root.addChild(content)
        root.collision = CollisionComponent(
            shapes: [ShapeResource.generateBox(size: descriptor.dimensions)]
        )
        return root
    }

    private func addContactShadow(to entity: ModelEntity, for prop: PropKind) {
        guard let contact = groundContactDescriptor(for: prop) else { return }
        let material = RealityMaterialRecipe(
            0.015, 0.018, 0.022,
            alpha: 0.20,
            roughness: 1
        ).makeMaterial()
        let shadow = ModelEntity(
            mesh: .generateSphere(radius: 0.5),
            materials: [material]
        )
        shadow.name = "cinear.contact-shadow"
        shadow.scale = [contact.width, 0.006, contact.depth]
        shadow.position = [0, contact.localY, 0]
        entity.addChild(shadow)
    }

    private func groundContactDescriptor(
        for prop: PropKind
    ) -> (width: Float, depth: Float, localY: Float)? {
        if let descriptor = prop.photorealDescriptor,
           descriptor.surface == .floor || descriptor.surface == .horizontal {
            return (
                descriptor.dimensions.x * 0.82,
                descriptor.dimensions.z * 0.82,
                0.004
            )
        }
        if let descriptor = libraryDescriptor(for: prop) {
            return (
                descriptor.dimensions.x * 0.82,
                descriptor.dimensions.z * 0.82,
                0.004
            )
        }
        switch prop {
        case .stage: return (1.82, 1.22, 0.004)
        case .crate: return (0.48, 0.48, 0.004)
        case .plant: return (0.31, 0.31, 0.004)
        case .floorLamp: return (0.30, 0.30, 0.004)
        case .apple: return (0.13, 0.13, 0.004)
        case .wall, .lightPanel, .rug, .custom, .chair, .table, .sofa,
             .bed, .bookcase, .television, .refrigerator, .oven, .stove,
             .sink, .bathtub, .toilet, .washerDryer, .stairs, .bloodWaterfall:
            return nil
        default:
            return nil
        }
    }

    private func libraryDescriptor(
        for prop: PropKind
    ) -> (role: RealityObjectRole, dimensions: SIMD3<Float>)? {
        switch prop {
        case .chair: (.chair, [0.58, 0.92, 0.58])
        case .table: (.table, [1.40, 0.76, 0.82])
        case .sofa: (.sofa, [2.00, 0.90, 0.88])
        case .bed: (.bed, [1.60, 0.68, 2.05])
        case .bookcase: (.storage, [1.05, 1.90, 0.38])
        case .television: (.television, [1.20, 0.76, 0.16])
        case .refrigerator: (.refrigerator, [0.76, 1.82, 0.72])
        case .oven: (.oven, [0.66, 0.92, 0.66])
        case .stove: (.stove, [0.66, 0.92, 0.66])
        case .sink: (.sink, [0.68, 0.90, 0.58])
        case .bathtub: (.bathtub, [1.72, 0.62, 0.78])
        case .toilet: (.toilet, [0.70, 0.82, 0.76])
        case .washerDryer: (.washerDryer, [0.72, 1.62, 0.72])
        case .stairs: (.stairs, [1.20, 1.20, 2.00])
        case .wall, .stage, .crate, .lightPanel, .plant, .floorLamp,
             .rug, .backdrop, .custom: nil
        default: nil
        }
    }

    private func makeBuiltInEntity(for prop: PropKind) -> ModelEntity {
        switch prop {
        case .wall:
            let mesh = MeshResource.generateBox(width: 2.4, height: 2.5, depth: 0.05)
            let material = SimpleMaterial(
                color: UIColor(red: 0.16, green: 0.24, blue: 0.31, alpha: 1),
                roughness: 0.78,
                isMetallic: false
            )
            return ModelEntity(mesh: mesh, materials: [material])

        case .stage:
            let mesh = MeshResource.generateBox(width: 2.0, height: 0.18, depth: 1.4)
            let material = SimpleMaterial(color: .darkGray, roughness: 0.62, isMetallic: false)
            return ModelEntity(mesh: mesh, materials: [material])

        case .crate:
            let mesh = MeshResource.generateBox(size: 0.55, cornerRadius: 0.025)
            let material = SimpleMaterial(
                color: UIColor(red: 0.42, green: 0.24, blue: 0.10, alpha: 1),
                roughness: 0.9,
                isMetallic: false
            )
            return ModelEntity(mesh: mesh, materials: [material])

        case .lightPanel:
            let mesh = MeshResource.generateBox(width: 0.9, height: 0.55, depth: 0.035)
            var material = UnlitMaterial()
            material.color = .init(tint: .white)
            return ModelEntity(mesh: mesh, materials: [material])

        case .plant:
            let potMaterial = SimpleMaterial(
                color: UIColor(red: 0.45, green: 0.20, blue: 0.10, alpha: 1),
                roughness: 0.88,
                isMetallic: false
            )
            let leafMaterial = SimpleMaterial(
                color: UIColor(red: 0.10, green: 0.42, blue: 0.16, alpha: 1),
                roughness: 0.82,
                isMetallic: false
            )
            let root = ModelEntity(
                mesh: .generateBox(size: [0.34, 0.36, 0.34], cornerRadius: 0.06),
                materials: [potMaterial]
            )
            let foliage = ModelEntity(mesh: .generateSphere(radius: 0.36), materials: [leafMaterial])
            foliage.position = [0, 0.48, 0]
            root.addChild(foliage)
            return root

        case .floorLamp:
            let frameMaterial = SimpleMaterial(color: .darkGray, roughness: 0.34, isMetallic: true)
            let shadeMaterial = SimpleMaterial(
                color: UIColor(red: 0.84, green: 0.77, blue: 0.63, alpha: 1),
                roughness: 0.72,
                isMetallic: false
            )
            var bulbMaterial = UnlitMaterial()
            bulbMaterial.color = .init(
                tint: UIColor(red: 1, green: 0.84, blue: 0.54, alpha: 1)
            )
            let root = ModelEntity(
                mesh: .generateBox(size: [0.32, 0.045, 0.32], cornerRadius: 0.06),
                materials: [frameMaterial]
            )
            let pole = ModelEntity(
                mesh: .generateBox(width: 0.025, height: 1.34, depth: 0.025),
                materials: [frameMaterial]
            )
            pole.position = [0, 0.69, 0]
            let lowerShade = ModelEntity(
                mesh: .generateBox(size: [0.36, 0.17, 0.36], cornerRadius: 0.085),
                materials: [shadeMaterial]
            )
            lowerShade.position = [0, 1.34, 0]
            let upperShade = ModelEntity(
                mesh: .generateBox(size: [0.28, 0.15, 0.28], cornerRadius: 0.075),
                materials: [shadeMaterial]
            )
            upperShade.position = [0, 1.48, 0]
            let bulb = ModelEntity(
                mesh: .generateSphere(radius: 0.065),
                materials: [bulbMaterial]
            )
            bulb.position = [0, 1.31, 0]
            root.addChild(pole)
            root.addChild(lowerShade)
            root.addChild(upperShade)
            root.addChild(bulb)
            return root

        case .rug:
            let material = SimpleMaterial(
                color: UIColor(red: 0.26, green: 0.43, blue: 0.52, alpha: 1),
                roughness: 0.96,
                isMetallic: false
            )
            return ModelEntity(
                mesh: .generateBox(size: [1.80, 0.012, 1.20], cornerRadius: 0.08),
                materials: [material]
            )

        case .backdrop:
            let material = SimpleMaterial(
                color: UIColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 1),
                roughness: 0.76,
                isMetallic: false
            )
            return ModelEntity(
                mesh: .generateBox(size: [2.40, 1.80, 0.045], cornerRadius: 0.025),
                materials: [material]
            )

        case .bloodWaterfall:
            return makeBloodWaterfallEntity()

        case .apple:
            return makeAppleEntity()

        case .chair, .table, .sofa, .bed, .bookcase, .television,
             .refrigerator, .oven, .stove, .sink, .bathtub, .toilet,
             .washerDryer, .stairs, .custom:
            preconditionFailure("USDZ assets are loaded through the library path")
        default:
            preconditionFailure("Photoreal USDZ assets are loaded asynchronously")
        }
    }

    private func makeAppleEntity() -> ModelEntity {
        let skin = RealityMaterialRecipe(
            0.64, 0.025, 0.018,
            roughness: 0.31,
            metallic: 0.02
        ).makeMaterial()
        let stemMaterial = RealityMaterialRecipe(
            0.18, 0.07, 0.025,
            roughness: 0.88
        ).makeMaterial()
        let leafMaterial = RealityMaterialRecipe(
            0.04, 0.28, 0.055,
            roughness: 0.68
        ).makeMaterial()

        let root = ModelEntity()
        root.name = "cinear.cgi.apple"
        let body = ModelEntity(mesh: .generateSphere(radius: 0.065), materials: [skin])
        body.scale = [1.0, 0.92, 1.0]
        body.position.y = 0.062
        let crown = ModelEntity(mesh: .generateSphere(radius: 0.046), materials: [skin])
        crown.scale = [1.08, 0.46, 1.08]
        crown.position.y = 0.105
        let stem = ModelEntity(
            mesh: .generateBox(size: [0.009, 0.046, 0.009], cornerRadius: 0.003),
            materials: [stemMaterial]
        )
        stem.position = [0.004, 0.145, 0]
        stem.orientation = simd_quatf(angle: -0.18, axis: [0, 0, 1])
        let leaf = ModelEntity(
            mesh: .generateBox(size: [0.047, 0.004, 0.021], cornerRadius: 0.008),
            materials: [leafMaterial]
        )
        leaf.position = [0.026, 0.143, 0]
        leaf.orientation = simd_quatf(angle: 0.30, axis: [0, 0, 1])
        root.addChild(body)
        root.addChild(crown)
        root.addChild(stem)
        root.addChild(leaf)
        root.collision = CollisionComponent(
            shapes: [ShapeResource.generateSphere(radius: 0.069)]
        )
        return root
    }

    private func makeBloodWaterfallEntity() -> ModelEntity {
        let root = ModelEntity()
        root.name = "cinear.cgi.blood-waterfall"
        let liquid = RealityMaterialRecipe(
            0.40, 0.006, 0.012,
            alpha: 0.82,
            roughness: 0.24,
            metallic: 0.03
        ).makeMaterial()
        let darkLiquid = RealityMaterialRecipe(
            0.16, 0.002, 0.008,
            alpha: 0.72,
            roughness: 0.32
        ).makeMaterial()

        let sheet = ModelEntity(
            mesh: .generateBox(size: [0.72, 1.48, 0.018], cornerRadius: 0.009),
            materials: [liquid]
        )
        sheet.name = "cinear.blood.sheet"
        sheet.position = [0, -0.73, 0.035]
        root.addChild(sheet)

        for index in 0..<18 {
            let radius = Float(0.017 + Double(index % 4) * 0.003)
            let drop = ModelEntity(mesh: .generateSphere(radius: radius), materials: [
                index.isMultiple(of: 3) ? darkLiquid : liquid
            ])
            drop.name = "cinear.blood.drop.\(index)"
            let lateral = (Float(index % 6) - 2.5) * 0.11
            drop.position = [lateral, -Float(index) / 18 * 1.42, 0.065 + Float(index % 3) * 0.009]
            drop.scale.y = 1.8 + Float(index % 3) * 0.35
            root.addChild(drop)
        }

        let puddle = ModelEntity(mesh: .generateSphere(radius: 0.5), materials: [darkLiquid])
        puddle.name = "cinear.blood.puddle"
        puddle.position = [0, -1.49, 0.22]
        puddle.scale = [0.86, 0.022, 0.34]
        root.addChild(puddle)
        root.collision = CollisionComponent(
            shapes: [ShapeResource.generateBox(size: [0.76, 1.54, 0.08])]
        )
        return root
    }

    private func addCoachingOverlay(to view: ARView) {
        let coaching = ARCoachingOverlayView()
        coaching.session = view.session
        coaching.goal = .anyPlane
        coaching.activatesAutomatically = true
        coaching.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(coaching)
        coachingOverlay = coaching
        NSLayoutConstraint.activate([
            coaching.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            coaching.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            coaching.topAnchor.constraint(equalTo: view.topAnchor),
            coaching.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func refreshSceneCatalogs() {
        var titleCounts: [String: Int] = [:]
        let placements = projectStore.project.placements.reversed().map { placement in
            let baseTitle: String
            if placement.kind == .custom, let fileName = placement.assetFileName {
                baseTitle = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
            } else {
                baseTitle = placement.kind.title
            }
            let occurrence = (titleCounts[baseTitle] ?? 0) + 1
            titleCounts[baseTitle] = occurrence
            let title = occurrence == 1 ? baseTitle : "\(baseTitle) \(occurrence)"
            return SceneObjectSummary(
                id: placement.id,
                title: title,
                symbol: placement.kind.symbol,
                detail: sceneObjectDetail(for: placement),
                isLiveEffect: placement.kind == .bloodWaterfall
            )
        }
        var result = Array(placements)
        if isLiveAppleEnabled {
            result.insert(
                SceneObjectSummary(
                    id: Self.liveAppleSceneID,
                    title: "Eldeki Elma",
                    symbol: "🍎",
                    detail: "Canlı CGI • Vision el takibi",
                    isLiveEffect: true
                ),
                at: 0
            )
        }
        sceneObjects = result
        savedPlaces = projectStore.savedPlaces
    }

    private func sceneObjectDetail(for placement: PlacementRecord) -> String {
        let surface: String
        switch placement.kind.placementSurface {
        case .floor: surface = "Zemin"
        case .horizontal: surface = "Yatay yüzey"
        case .wall: surface = "Duvar"
        case .ceiling: surface = "Tavan"
        }
        if placement.kind == .bloodWaterfall { return "Canlı CGI • Duvara sabit" }
        if placement.kind.emitsVirtualLight { return "Sanal ışık • \(surface)" }
        return surface
    }

    private func archiveSavedPlaceIfRequested() -> (message: String?, failed: Bool) {
        guard shouldArchiveAfterNextSave else { return (nil, false) }
        shouldArchiveAfterNextSave = false
        let name = pendingArchiveName
        pendingArchiveName = nil
        do {
            let summary = try projectStore.archiveCurrentProject(preferredName: name)
            savedPlaces = projectStore.savedPlaces
            return ("\(summary.name) Kayıtlı Mekânlar'a eklendi", false)
        } catch {
            return ("mekân arşivlenemedi: \(error.localizedDescription)", true)
        }
    }

    private func publishStatus(_ text: String, color: Color) {
        DispatchQueue.main.async { [weak self] in
            self?.statusText = text
            self?.trackingColor = color
        }
    }

    private func restoreRoomRealityIfPossible() {
        guard roomCoordinateSpaceIsActive,
              let preferredRealityThemeID,
              FileManager.default.fileExists(atPath: roomDataURL.path) else {
            roomRealityRenderer.isVisible = false
            setPhysicalSceneOcclusion(enabled: true)
            refreshPhysicalRoomOcclusionIfPossible()
            return
        }
        roomRealityRenderer.isVisible = false
        isRoomOutlineVisible = false
        setPhysicalSceneOcclusion(enabled: true)
        pendingRealityThemeAfterScan = preferredRealityThemeID
        if let trackingState = arView?.session.currentFrame?.camera.trackingState {
            _ = schedulePendingPostScanThemeIfReady(trackingState: trackingState)
        }
    }

    @discardableResult
    private func restoreRoomRealityAfterInterruptionIfReady(
        trackingState: ARCamera.TrackingState?
    ) -> Bool {
        guard shouldRestoreRoomRealityAfterInterruption else { return false }
        guard !isSessionInterrupted,
              roomCoordinateSpaceIsActive,
              let arView,
              let themeID = activeRealityThemeID ?? preferredRealityThemeID,
              FileManager.default.fileExists(atPath: roomDataURL.path) else {
            shouldRestoreRoomRealityAfterInterruption = false
            roomRealityRenderer.isVisible = false
            setPhysicalSceneOcclusion(enabled: true)
            return false
        }

        if let trackingState {
            guard case .normal = trackingState else { return false }
        }

        shouldRestoreRoomRealityAfterInterruption = false
        roomRealityRenderer.install(in: arView)
        selectRealityTheme(themeID)
        return true
    }

    private func cancelPendingPostScanTheme() {
        postScanThemeGeneration &+= 1
        pendingRealityThemeAfterScan = nil
        isPostScanThemeScheduled = false
    }

    /// RoomPlan görünümü tamamen kapandıktan ve ARKit normal takibe döndükten sonra
    /// oda geometrisini kurar. Kısa gecikme, iki ağır RealityKit/RoomPlan yaşam döngüsünün
    /// aynı ana iş parçacığı karesinde üst üste binmesini engeller.
    @discardableResult
    private func schedulePendingPostScanThemeIfReady(
        trackingState: ARCamera.TrackingState?
    ) -> Bool {
        guard let themeID = pendingRealityThemeAfterScan else { return false }
        guard let trackingState, case .normal = trackingState else { return true }
        guard !isPostScanThemeScheduled else { return true }

        isPostScanThemeScheduled = true
        postScanThemeGeneration &+= 1
        let generation = postScanThemeGeneration
        publishStatus("Oda gerçekliği hazırlanıyor...", color: .yellow)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            guard generation == self.postScanThemeGeneration,
                  self.pendingRealityThemeAfterScan == themeID else { return }
            self.isPostScanThemeScheduled = false
            guard
                  !self.isRoomScanActive,
                  !self.isSessionInterrupted,
                  let trackingState = self.arView?.session.currentFrame?.camera.trackingState,
                  case .normal = trackingState else { return }

            self.pendingRealityThemeAfterScan = nil
            if self.roomRealityRenderer.lastReport != nil,
               self.activeRealityThemeID == themeID {
                self.roomRealityRenderer.isVisible = true
                self.setPhysicalSceneOcclusion(enabled: true)
                let theme = RealityThemeCatalog.theme(withID: themeID)
                self.publishStatus("\(theme.title) oda gerçekliği yeniden hizalandı", color: .green)
                return
            }
            self.selectRealityTheme(themeID)
        }
        return true
    }

    @discardableResult
    private func refreshPhysicalRoomOcclusionIfPossible(
        allowWhileAIEnabled: Bool = false
    ) -> Bool {
        guard !isRoomScanActive,
              (!aiEnhancementEnabled || allowWhileAIEnabled),
              activeRealityThemeID == nil,
              roomCoordinateSpaceIsActive,
              let arView,
              FileManager.default.fileExists(atPath: roomDataURL.path) else {
            roomRealityRenderer.isPhysicalOcclusionVisible = false
            return false
        }

        roomRealityRenderer.install(in: arView)
        if roomRealityRenderer.hasPreparedPhysicalOcclusion {
            roomRealityRenderer.isPhysicalOcclusionVisible = true
            return true
        }
        do {
            let count = try roomRealityRenderer.preparePhysicalOcclusion(
                roomJSONURL: roomDataURL
            )
            roomRealityRenderer.isPhysicalOcclusionVisible = count > 0
            return count > 0
        } catch {
            roomRealityRenderer.isPhysicalOcclusionVisible = false
            return false
        }
    }

    private func setPhysicalSceneOcclusion(enabled: Bool) {
        guard let arView else { return }
        if enabled {
            arView.environment.sceneUnderstanding.options.insert(.occlusion)
            arView.environment.sceneUnderstanding.options.insert(.collision)
        } else {
            arView.environment.sceneUnderstanding.options.remove(.occlusion)
            arView.environment.sceneUnderstanding.options.remove(.collision)
        }
    }
}

extension ARSessionController: @preconcurrency ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        updatePlacementGuidance(using: frame)
        updateBloodWaterfalls(timestamp: frame.timestamp)
        updateLiveAppleTracking(using: frame)
        if frame.timestamp - lastProjectorRefreshTimestamp >= 0.16 {
            lastProjectorRefreshTimestamp = frame.timestamp
            refreshProjectorLights()
        }
        submitFrameToAIIfNeeded(frame)
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        updateKnownFloor(from: anchors)
        var shouldScheduleAutomaticSave = false
        for anchor in anchors {
            guard let descriptor = PropKind.descriptor(from: anchor.name) else { continue }
            if supersededPropAnchorIDs.contains(anchor.identifier) {
                session.remove(anchor: anchor)
                continue
            }
            guard let placement = projectStore.placement(id: descriptor.id),
                  placement.kind == descriptor.kind else {
                // Never let a late relocalization callback resurrect a prop the user
                // has already deleted, or leave an orphan that poisons the next save.
                session.remove(anchor: anchor)
                continue
            }
            knownPropAnchorIDs.insert(anchor.identifier)
            managedPropAnchorsByPlacementID[descriptor.id] = anchor
            if pendingAutoSaveAnchorIDs.remove(anchor.identifier) != nil {
                shouldScheduleAutomaticSave = true
            }
            DispatchQueue.main.async { [weak self] in
                self?.render(prop: descriptor.kind, id: descriptor.id, for: anchor)
            }
        }
        if shouldScheduleAutomaticSave {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                guard let self, !self.isRoomScanActive, !self.isSessionInterrupted else { return }
                self.shouldSaveWorldMapWhenReady = true
                self.scheduleReadinessRecovery()
            }
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        updateKnownFloor(from: anchors)
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        floorSurfaceTracker.remove(anchors)
        if let cameraY = session.currentFrame?.camera.transform.columns.3.y {
            if let estimate = floorSurfaceTracker.estimate(cameraY: cameraY), estimate.isStable {
                lastKnownFloorY = estimate.y
            }
        }
        for anchor in anchors {
            guard let descriptor = PropKind.descriptor(from: anchor.name) else { continue }
            knownPropAnchorIDs.remove(anchor.identifier)
            pendingAutoSaveAnchorIDs.remove(anchor.identifier)
            if supersededPropAnchorIDs.remove(anchor.identifier) != nil {
                continue
            }
            if let placement = projectStore.placement(id: descriptor.id),
               placement.kind == descriptor.kind {
                // Keep the last known transform and the current visual alive. RoomPlan
                // and relocalization can remove an ARAnchor transiently; deleting the
                // entity here made valid props and lights vanish permanently.
                managedPropAnchorsByPlacementID[descriptor.id] = anchor
                if !isRoomScanActive, !isSessionInterrupted {
                    scheduleReadinessRecovery()
                }
                continue
            }
            managedPropAnchorsByPlacementID[descriptor.id] = nil
            detachRenderedPlacement(id: descriptor.id, clearSelection: true)
        }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        guard !isSessionInterrupted, !isRoomScanActive else { return }
        switch camera.trackingState {
        case .normal:
            isARReady = true
            didAttemptSessionFailureRecovery = false
            let anchorRecovery = restorePlacementAnchorsIfNeeded(
                allowCreatingMissingAnchors: false
            )
            if anchorRecovery.waitingForAnchor {
                scheduleReadinessRecovery()
                publishStatus(
                    "Sahne anchor'ları yeniden bağlanıyor; nesneler korunuyor",
                    color: .yellow
                )
                return
            }
            if savePendingWorldMapIfPossible(trackingState: camera.trackingState) {
                return
            }
            if shouldShowRoomOutlineWhenReady {
                shouldShowRoomOutlineWhenReady = false
                showRoomOutline()
                return
            }
            if schedulePendingPostScanThemeIfReady(trackingState: camera.trackingState) {
                return
            }
            if restoreRoomRealityAfterInterruptionIfReady(trackingState: camera.trackingState) {
                return
            }
            publishStatus("Takip hazır — dekor seçip yüzeye dokun", color: .green)
        case .notAvailable:
            isARReady = false
            publishStatus("Kamera takibi kullanılamıyor", color: .red)
        case .limited(let reason):
            // Limited tracking may still render an existing scene, but accepting a
            // new anchor here is the main source of visible placement drift.
            isARReady = false
            let message: String
            switch reason {
            case .initializing: message = "AR oturumu hazırlanıyor"
            case .excessiveMotion: message = "Telefonu daha yavaş hareket ettir"
            case .insufficientFeatures: message = "Daha aydınlık ve detaylı bir alana yönelt"
            case .relocalizing: message = "Kayıtlı sahne yeniden bulunuyor"
            @unknown default: message = "Takip sınırlı"
            }
            publishStatus(message, color: .yellow)
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        guard let arView, session === arView.session else {
            publishStatus("AR hatası: \(error.localizedDescription)", color: .red)
            return
        }

        isARReady = false
        guard !isRoomScanActive else {
            publishStatus(
                "Oda taraması sırasında AR durdu; taramayı kapatıp yeniden dene: "
                    + error.localizedDescription,
                color: .red
            )
            return
        }

        shouldRestoreRoomRealityAfterInterruption =
            shouldRestoreRoomRealityAfterInterruption
            || (
                roomCoordinateSpaceIsActive
                && activeRealityThemeID != nil
                && roomRealityRenderer.isVisible
            )
        shouldShowRoomOutlineWhenReady = shouldShowRoomOutlineWhenReady
            || isRoomOutlineVisible
        roomRealityRenderer.isVisible = false
        isRoomOutlineVisible = false
        setPhysicalSceneOcclusion(enabled: true)

        guard !didAttemptSessionFailureRecovery else {
            publishStatus(
                "AR yeniden başlatılamadı; uygulamayı yeniden aç: \(error.localizedDescription)",
                color: .red
            )
            return
        }

        didAttemptSessionFailureRecovery = true
        isSessionInterrupted = false
        configurationBeforeInterruption = nil
        session.delegateQueue = .main
        session.delegate = self
        session.run(session.configuration ?? configuration(), options: [])
        publishStatus(
            "AR oturumu durdu; içerikler korunarak otomatik yeniden başlatılıyor",
            color: .yellow
        )
    }

    func sessionWasInterrupted(_ session: ARSession) {
        guard !isSessionInterrupted else { return }

        readinessRecoveryGeneration &+= 1
        isARReady = false
        isSessionInterrupted = true
        configurationBeforeInterruption = session.configuration
        guard !isRoomScanActive else {
            publishStatus(
                "Oda taraması kesildi; taramayı kapatıp yeniden dene",
                color: .yellow
            )
            return
        }

        shouldRestoreRoomRealityAfterInterruption =
            roomCoordinateSpaceIsActive
            && activeRealityThemeID != nil
            && roomRealityRenderer.isVisible
        shouldShowRoomOutlineWhenReady = shouldShowRoomOutlineWhenReady
            || isRoomOutlineVisible
        roomRealityRenderer.isVisible = false
        isRoomOutlineVisible = false
        setPhysicalSceneOcclusion(enabled: true)
        publishStatus("AR oturumu kesildi — aynı alanda kalın", color: .yellow)
    }

    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        // Preserve both the scanned-room coordinate space and manually placed anchors.
        true
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        guard isSessionInterrupted else { return }

        isSessionInterrupted = false
        guard let arView, session === arView.session else {
            configurationBeforeInterruption = nil
            shouldRestoreRoomRealityAfterInterruption = false
            publishStatus("AR oturumu yeniden bağlanamadı", color: .red)
            return
        }

        if isRoomScanActive {
            configurationBeforeInterruption = nil
            publishStatus(
                "Oda taraması kesildi; taramayı kapatıp yeniden dene",
                color: .yellow
            )
            return
        }

        session.delegateQueue = .main
        session.delegate = self
        let resumeConfiguration = configurationBeforeInterruption
            ?? session.configuration
            ?? configuration()
        configurationBeforeInterruption = nil
        session.run(resumeConfiguration, options: [])
        scheduleReadinessRecovery()

        if pendingRealityThemeAfterScan != nil {
            _ = schedulePendingPostScanThemeIfReady(
                trackingState: session.currentFrame?.camera.trackingState
            )
            publishStatus("AR oturumu sürdürülüyor — oda gerçekliği yeniden hizalanıyor", color: .yellow)
            return
        }

        if shouldRestoreRoomRealityAfterInterruption {
            if !restoreRoomRealityAfterInterruptionIfReady(
                trackingState: session.currentFrame?.camera.trackingState
            ) {
                publishStatus(
                    "AR oturumu sürdürülüyor — oda yeniden hizalanıyor",
                    color: .yellow
                )
            }
        } else {
            setPhysicalSceneOcclusion(enabled: true)
            publishStatus("AR oturumu sürdürüldü", color: .yellow)
        }
    }
}

extension ARSessionController: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // The placement/selection tap must not disable RealityKit's translation,
        // rotation and scale recognizers installed on manual props.
        true
    }
}

private struct SceneDepthSurfaceSample {
    let worldPoint: SIMD3<Float>
    let worldNormal: SIMD3<Float>?
    let depthMeters: Float
}

private struct BloodWaterfallParticle {
    let entity: ModelEntity
    let phase: Float
    let lateral: Float
    let depth: Float
}

private struct ProjectorSurfaceHit {
    let position: SIMD3<Float>
    let normal: SIMD3<Float>
    let distanceMeters: Float
}

private struct PlacementSurfaceSolution {
    let transform: simd_float4x4
    let position: SIMD3<Float>
    let normal: SIMD3<Float>
    let source: PlacementSurfaceSource
    let depthMeters: Float?
}

private enum PlacementSurfaceSource: Equatable {
    case classifiedFloorPlane
    case classifiedFloorMesh
    case lidarMesh
    case arkitPlane
    case roomPlanGeometry
    case roomPlanLevel

    var title: String {
        switch self {
        case .classifiedFloorPlane: "ARKit zemin"
        case .classifiedFloorMesh: "LiDAR zemin"
        case .lidarMesh: "LiDAR yüzey"
        case .arkitPlane: "ARKit yüzey"
        case .roomPlanGeometry: "RoomPlan yüzey"
        case .roomPlanLevel: "RoomPlan kotu"
        }
    }
}

private struct FloorSurfaceEstimate {
    let y: Float
    let isStable: Bool
    let source: PlacementSurfaceSource
}

/// Maintains a metric floor level from classified AR planes, classified LiDAR mesh
/// faces and a completed RoomPlan scan. Unclassified horizontal planes are never
/// admitted: they are commonly desks, shelves or seats.
private final class FloorSurfaceTracker {
    private var roomFloorY: Float?
    private var classifiedPlaneLevels: [UUID: Float] = [:]
    private var classifiedMeshLevels: [UUID: Float] = [:]
    private var liveHistory: [Float] = []
    private var latestLiveSource: PlacementSurfaceSource = .classifiedFloorMesh

    func reset() {
        roomFloorY = nil
        classifiedPlaneLevels.removeAll()
        classifiedMeshLevels.removeAll()
        liveHistory.removeAll()
        latestLiveSource = .classifiedFloorMesh
    }

    func setRoomFloor(_ y: Float) {
        guard y.isFinite else { return }
        roomFloorY = y
    }

    func clearRoomFloor() {
        roomFloorY = nil
    }

    func remove(_ anchors: [ARAnchor]) {
        for anchor in anchors {
            classifiedPlaneLevels[anchor.identifier] = nil
            classifiedMeshLevels[anchor.identifier] = nil
        }
    }

    func update(with anchors: [ARAnchor], cameraY: Float) {
        guard cameraY.isFinite else { return }
        for anchor in anchors {
            if let plane = anchor as? ARPlaneAnchor {
                if plane.alignment == .horizontal,
                   plane.classification == .floor,
                   plane.transform.columns.3.y.isFinite {
                    classifiedPlaneLevels[plane.identifier] = plane.transform.columns.3.y
                } else {
                    classifiedPlaneLevels[plane.identifier] = nil
                }
            } else if let mesh = anchor as? ARMeshAnchor {
                if let level = Self.classifiedFloorLevel(in: mesh), level.isFinite {
                    classifiedMeshLevels[mesh.identifier] = level
                } else {
                    classifiedMeshLevels[mesh.identifier] = nil
                }
            }
        }

        let expectedFloor = cameraY - 1.35
        let planeCandidates = classifiedPlaneLevels.values.filter {
            $0 < cameraY - 0.30 && $0 > cameraY - 3.2
        }
        let meshCandidates = classifiedMeshLevels.values.filter {
            $0 < cameraY - 0.30 && $0 > cameraY - 3.2
        }
        let candidates: [Float]
        if !planeCandidates.isEmpty {
            candidates = planeCandidates
            latestLiveSource = .classifiedFloorPlane
        } else {
            candidates = meshCandidates
            latestLiveSource = .classifiedFloorMesh
        }
        guard let candidate = candidates.min(by: {
            abs($0 - expectedFloor) < abs($1 - expectedFloor)
        }) else { return }

        if let last = liveHistory.last, abs(last - candidate) > 0.18 {
            liveHistory.removeAll()
        }
        liveHistory.append(candidate)
        if liveHistory.count > 24 {
            liveHistory.removeFirst(liveHistory.count - 24)
        }
    }

    func estimate(cameraY: Float) -> FloorSurfaceEstimate? {
        let liveMedian = Self.median(liveHistory)
        let liveSpread: Float
        if let liveMedian {
            liveSpread = Self.median(liveHistory.map { abs($0 - liveMedian) }) ?? .greatestFiniteMagnitude
        } else {
            liveSpread = .greatestFiniteMagnitude
        }
        let minimumHistory = latestLiveSource == .classifiedFloorPlane ? 2 : 4
        let liveIsStable = liveHistory.count >= minimumHistory && liveSpread <= 0.035

        if let liveMedian, liveIsStable {
            if let roomFloorY, abs(roomFloorY - liveMedian) <= 0.08 {
                return FloorSurfaceEstimate(
                    y: (roomFloorY + liveMedian * 2) / 3,
                    isStable: true,
                    source: latestLiveSource
                )
            }
            return FloorSurfaceEstimate(
                y: liveMedian,
                isStable: true,
                source: latestLiveSource
            )
        }
        if let roomFloorY,
           roomFloorY < cameraY - 0.25,
           roomFloorY > cameraY - 3.2 {
            return FloorSurfaceEstimate(
                y: roomFloorY,
                isStable: true,
                source: .roomPlanLevel
            )
        }
        if let liveMedian {
            return FloorSurfaceEstimate(
                y: liveMedian,
                isStable: false,
                source: latestLiveSource
            )
        }
        return nil
    }

    private static func classifiedFloorLevel(in anchor: ARMeshAnchor) -> Float? {
        let geometry = anchor.geometry
        guard geometry.faces.count > 0 else { return nil }
        let maximumSamples = 240
        let step = max(1, geometry.faces.count / maximumSamples)
        var levels: [Float] = []
        levels.reserveCapacity(min(geometry.faces.count, maximumSamples))

        for faceIndex in stride(from: 0, to: geometry.faces.count, by: step) {
            guard classification(of: faceIndex, in: geometry) == .floor else { continue }
            let indices = vertexIndices(of: faceIndex, in: geometry)
            guard indices.count == 3 else { continue }
            let vertices = indices.map { vertex(at: $0, in: geometry) }
            let localCenter = (vertices[0] + vertices[1] + vertices[2]) / 3
            let worldCenter = anchor.transform * SIMD4(localCenter.x, localCenter.y, localCenter.z, 1)
            if worldCenter.y.isFinite { levels.append(worldCenter.y) }
        }
        guard levels.count >= 3 else { return nil }
        return median(levels)
    }

    private static func classification(
        of faceIndex: Int,
        in geometry: ARMeshGeometry
    ) -> ARMeshClassification {
        guard let source = geometry.classification,
              faceIndex >= 0, faceIndex < source.count else { return .none }
        let address = source.buffer.contents().advanced(
            by: source.offset + faceIndex * source.stride
        )
        let raw = Int(address.assumingMemoryBound(to: UInt8.self).pointee)
        return ARMeshClassification(rawValue: raw) ?? .none
    }

    private static func vertexIndices(of faceIndex: Int, in geometry: ARMeshGeometry) -> [Int] {
        let faces = geometry.faces
        let start = faceIndex * faces.indexCountPerPrimitive
        return (0..<faces.indexCountPerPrimitive).map { offset in
            let address = faces.buffer.contents().advanced(
                by: (start + offset) * faces.bytesPerIndex
            )
            if faces.bytesPerIndex == MemoryLayout<UInt16>.size {
                return Int(address.assumingMemoryBound(to: UInt16.self).pointee)
            }
            return Int(address.assumingMemoryBound(to: UInt32.self).pointee)
        }
    }

    private static func vertex(at index: Int, in geometry: ARMeshGeometry) -> SIMD3<Float> {
        let vertices = geometry.vertices
        let address = vertices.buffer.contents().advanced(
            by: vertices.offset + index * vertices.stride
        )
        let values = address.assumingMemoryBound(to: Float.self)
        return SIMD3(values[0], values[1], values[2])
    }

    private static func median(_ values: [Float]) -> Float? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        if sorted.count.isMultiple(of: 2) {
            return (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) * 0.5
        }
        return sorted[sorted.count / 2]
    }
}

private enum CineARError: LocalizedError {
    case worldMapUnavailable
    case duplicatePropAnchor(UUID)
    case sceneSnapshotMismatch(
        missingFromMap: Int,
        missingFromProject: Int,
        kindMismatch: Int
    )

    var errorDescription: String? {
        switch self {
        case .worldMapUnavailable:
            "Dünya haritası henüz hazır değil"
        case .duplicatePropAnchor(let id):
            "Dünya haritasında yinelenen dekor anchor'ı var: \(id.uuidString)"
        case .sceneSnapshotMismatch(
            let missingFromMap,
            let missingFromProject,
            let kindMismatch
        ):
            "worldmap/scene.json eşleşmiyor (haritada eksik: \(missingFromMap), "
                + "projede eksik: \(missingFromProject), tür farkı: \(kindMismatch))"
        }
    }
}
