import ARKit
import Combine
import RealityKit
import RoomPlan
import simd
import SwiftUI
import UIKit

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
    @Published private(set) var aiEnhancementEnabled = false
    @Published private(set) var aiServerAddress = ""
    @Published private(set) var aiEnhancementStatus: AIEnhancementStatus = .disabled

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
    private var knownPropAnchorIDs = Set<UUID>()
    private var renderedEntities: [UUID: ModelEntity] = [:]
    private var renderedLights: [UUID: SpotLight] = [:]
    private var renderedLightEmitters: [UUID: ModelEntity] = [:]
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
    private var shouldSaveWorldMapWhenReady = false
    private var shouldShowRoomOutlineWhenReady = false
    private var readinessRecoveryGeneration: UInt64 = 0
    private var pendingAutoSaveAnchorIDs = Set<UUID>()

    private static let realityThemeDefaultsKey = "cinear.activeRealityTheme"
    private static let aiEnabledDefaultsKey = "cinear.aiDepth.enabled"
    private static let aiServerDefaultsKey = "cinear.aiDepth.server"

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
        aiServerAddress = UserDefaults.standard.string(forKey: Self.aiServerDefaultsKey) ?? ""
        aiEnhancementStatus = aiEnhancementEnabled ? .waiting : .disabled
        importedAssetURLs = projectStore.importedModelURLs
        hasScannedRoom = FileManager.default.fileExists(atPath: roomDataURL.path)
        // Opaque room replacements can cover people and make the camera feel unstable.
        // Always launch in the real-camera view; the legacy renderer stays internal.
        UserDefaults.standard.removeObject(forKey: Self.realityThemeDefaultsKey)
        if let error = projectStore.initializationError {
            publishStatus(
                "Kayıtlı scene.json okunamadı: \(error.localizedDescription)",
                color: .red
            )
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
        knownPropAnchorIDs.removeAll()
        renderedEntities.removeAll()
        renderedLights.removeAll()
        renderedLightEmitters.removeAll()
        loadingEntityIDs.removeAll()
        assetLoadSubscriptions.removeAll()
        selectedEntityID = nil
        selectedLightSettings = nil
        isRoomOutlineVisible = false
        guard let arView else { return }
        aiEnhancementClient.cancel()
        aiDepthRenderer.remove()
        arView.scene.anchors.removeAll()
        roomCoordinateSpaceIsActive = initialWorldMap != nil
        lastKnownFloorY = nil
        lastKnownCeilingY = nil
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
        // RoomPlan already performs its own LiDAR processing. Temporarily omit the
        // additional mesh/person passes so scanning does not run three heavy pipelines.
        arView?.session.run(
            configuration(enableAdvancedOcclusion: false),
            options: [.resetSceneReconstruction]
        )
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
            return
        }
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
                self.aiEnhancementStatus = .active(latencyMilliseconds: 0, samMaskCount: 0)
                self.publishStatus("AI servisi hazır: \(device)", color: .green)
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
                guard depth.totalLatencyMilliseconds <= 1_500 else {
                    self.aiDepthRenderer.clear()
                    self.aiEnhancementStatus = .failed(
                        "Gecikme \(depth.totalLatencyMilliseconds) ms; PC veya Wi-Fi yavaş"
                    )
                    return
                }
                do {
                    try self.aiDepthRenderer.render(depth)
                    self.aiEnhancementStatus = .active(
                        latencyMilliseconds: depth.totalLatencyMilliseconds,
                        samMaskCount: depth.samMaskCount
                    )
                } catch {
                    self.aiEnhancementStatus = .failed(error.localizedDescription)
                }
            case .failure(let error):
                if let aiError = error as? AIEnhancementError,
                   case .missingSceneDepth = aiError {
                    self.aiEnhancementStatus = .waiting
                } else {
                    self.aiDepthRenderer.clear()
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
        selectedProp = prop
        selectedEntityID = nil
        selectedLightSettings = nil
        if prop == .custom, selectedAssetURL == nil {
            isPlacingProp = false
            publishStatus("USDZ seçildi — önce kütüphaneden bir model ekle", color: .yellow)
        } else {
            isPlacingProp = true
            publishStatus(
                "\(prop.title) seçildi — \(placementInstruction(for: prop))",
                color: .blue
            )
        }
    }

    func cancelPlacement() {
        guard isPlacingProp else { return }
        isPlacingProp = false
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
        selectedEntityID = id
        if let placement = projectStore.placement(id: id), placement.kind.emitsVirtualLight {
            selectedLightSettings = placement.lightSettings ?? .defaultFixture
            publishStatus("Işık seçildi — güç, renk, yön, eğim ve hüzmeyi ayarlayabilirsin", color: .blue)
        } else {
            selectedLightSettings = nil
            publishStatus("Dekor seçildi — konumu kilitli; döndür veya ölçekle", color: .blue)
        }
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let arView else { return }
        let point = recognizer.location(in: arView)

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

        guard let placementTransform = placementWorldTransform(
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
            pendingAutoSaveAnchorIDs.insert(anchor.identifier)
            arView.session.add(anchor: anchor)
            selectedEntityID = id
            selectedLightSettings = placement.lightSettings
            isPlacingProp = false
            render(prop: selectedProp, id: id, for: anchor)
            if selectedProp == .custom {
                publishStatus("USDZ sahneye yükleniyor...", color: .yellow)
            } else if renderedEntities[id] != nil {
                publishStatus("\(selectedProp.title) sahneye sabitlendi", color: .green)
            } else {
                publishStatus("\(selectedProp.title) hazırlanıyor...", color: .yellow)
            }
        } catch {
            publishStatus("Proje kaydedilemedi: \(error.localizedDescription)", color: .red)
        }
    }

    private func placementWorldTransform(
        in arView: ARView,
        at point: CGPoint,
        for prop: PropKind
    ) -> simd_float4x4? {
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
                return placementTransform(
                    position: hit.position,
                    normal: hit.normal,
                    prop: prop,
                    cameraPosition: arView.cameraTransform.translation
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
            return placementTransform(
                position: hit.position,
                normal: hit.normal,
                prop: prop,
                cameraPosition: arView.cameraTransform.translation
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
                return placementTransform(
                    position: [position.x, position.y, position.z],
                    normal: [
                        result.worldTransform.columns.1.x,
                        result.worldTransform.columns.1.y,
                        result.worldTransform.columns.1.z
                    ],
                    prop: prop,
                    cameraPosition: arView.cameraTransform.translation
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
                return placementTransform(
                    position: ray.origin + direction * distance,
                    normal: [0, -1, 0],
                    prop: prop,
                    cameraPosition: arView.cameraTransform.translation
                )
            }
        }

        // A completed RoomPlan scan provides a persistent world-space floor level.
        // Intersect the exact screen ray with that recorded floor instead of guessing
        // from camera height. This remains stable while making the full floor tappable.
        if prop.placementSurface == .floor || prop.placementSurface == .horizontal,
           roomCoordinateSpaceIsActive,
           let floorY = lastKnownFloorY,
           let ray = arView.ray(through: point) {
            let direction = simd_normalize(ray.direction)
            guard direction.y < -0.025 else { return nil }
            let distance = (floorY - ray.origin.y) / direction.y
            if distance.isFinite, distance >= 0.20, distance <= 8.0 {
                return placementTransform(
                    position: ray.origin + direction * distance,
                    normal: [0, 1, 0],
                    prop: prop,
                    cameraPosition: arView.cameraTransform.translation
                )
            }
        }

        // Do not fabricate a camera-relative point. Such an object looks acceptable
        // for a single frame but visibly swims once the camera moves. The user keeps
        // placement mode active until ARKit has a persistent plane/RoomPlan surface.
        return nil
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
            return classification == .floor || y < cameraY - 0.25
        case .horizontal:
            return classification != .ceiling && y < cameraY + 0.20
        }
    }

    private func updateKnownFloorFromRoomData() {
        guard let room = try? RoomRealityRenderer.loadRoomJSON(from: roomDataURL) else { return }
        let levels = room.floors.compactMap { floor -> Float? in
            let y = floor.transform.columns.3.y
            return y.isFinite ? y : nil
        }.sorted()
        if !levels.isEmpty {
            lastKnownFloorY = levels[levels.count / 2]
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
        let planes = anchors.compactMap { $0 as? ARPlaneAnchor }.filter {
            $0.alignment == .horizontal
        }
        let classifiedFloors = planes.filter { $0.classification == .floor }
        let candidates = classifiedFloors.isEmpty ? planes : classifiedFloors
        let levels = candidates.map { $0.transform.columns.3.y }.filter {
            $0.isFinite && $0 < cameraY - 0.20
        }
        if let closest = levels.min(by: {
            abs($0 - (cameraY - 1.40)) < abs($1 - (cameraY - 1.40))
        }) {
            lastKnownFloorY = closest
        }
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
        guard let id = selectedEntityID, let arView else {
            publishStatus("Önce silinecek dekoru seç", color: .yellow)
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
        renderedEntities[id]?.parent?.removeFromParent()
        renderedEntities[id] = nil
        renderedLights[id] = nil
        renderedLightEmitters[id] = nil
        assetLoadSubscriptions[id]?.cancel()
        assetLoadSubscriptions[id] = nil
        loadingEntityIDs.remove(id)
        selectedEntityID = nil
        selectedLightSettings = nil
        publishStatus("Seçili dekor silindi", color: .green)
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
        renderedAnchorIDs.removeAll()
        knownPropAnchorIDs.removeAll()
        renderedEntities.removeAll()
        renderedLights.removeAll()
        renderedLightEmitters.removeAll()
        selectedEntityID = nil
        selectedLightSettings = nil
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

    func saveWorldMap() {
        guard let arView else {
            publishStatus("AR görünümü henüz hazır değil", color: .red)
            return
        }
        guard !isSavingWorldMap else {
            shouldSaveWorldMapWhenReady = true
            publishStatus("Mevcut kayıttan sonra bir kez daha kaydedilecek", color: .yellow)
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

        arView.session.getCurrentWorldMap { [weak self] worldMap, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isSavingWorldMap = false
                do {
                    if let error { throw error }
                    guard let worldMap else { throw CineARError.worldMapUnavailable }
                    try self.validate(worldMap: worldMap)
                    let data = try NSKeyedArchiver.archivedData(
                        withRootObject: worldMap,
                        requiringSecureCoding: true
                    )
                    try self.projectStore.saveWorldMapData(data)
                    self.publishStatus("Set projesi ve dünya haritası kaydedildi", color: .green)
                } catch {
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
            switch trackingState {
            case .normal?:
                self.isARReady = true
                self.didAttemptSessionFailureRecovery = false
                if self.savePendingWorldMapIfPossible(trackingState: trackingState) {
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
            let snapshot = try projectStore.worldMapSnapshotForLoading()
            guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: ARWorldMap.self,
                from: snapshot.data
            ) else {
                throw CineARError.worldMapUnavailable
            }
            try validate(worldMap: worldMap, placements: snapshot.project.placements)
            projectStore.activate(snapshot)
            runSession(initialWorldMap: worldMap)
            publishStatus("Aynı alanı göster; kamera yeniden konumlanıyor", color: .yellow)
        } catch {
            shouldShowRoomOutlineWhenReady = false
            publishStatus("Kayıtlı sahne yüklenemedi: \(error.localizedDescription)", color: .red)
        }
    }

    func startRecording() {
        guard case .idle = recordingPhase else {
            publishStatus("Kayıt işlemi zaten devam ediyor", color: .yellow)
            return
        }
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
            guard let modelURL = bundledAssetURL(named: descriptor.assetName) else {
                publishStatus("\(prop.title) modeli uygulama paketinde bulunamadı", color: .red)
                return
            }
            loadingEntityIDs.insert(id)
            let generation = renderGeneration
            let request = Entity.loadAsync(contentsOf: modelURL)
            assetLoadSubscriptions[id] = request
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    guard let self, self.renderGeneration == generation else { return }
                    self.loadingEntityIDs.remove(id)
                    self.assetLoadSubscriptions[id] = nil
                    if case .failure(let error) = completion {
                        self.publishStatus(
                            "\(prop.title) yüklenemedi: \(error.localizedDescription)",
                            color: .red
                        )
                    }
                } receiveValue: { [weak self] content in
                    guard let self,
                          let entity = self.makePhotorealLibraryEntity(
                            content: content,
                            prop: prop,
                            descriptor: descriptor
                          ) else {
                        self?.publishStatus("\(prop.title) ölçüsü hazırlanamadı", color: .red)
                        return
                    }
                    self.attach(
                        entity: entity,
                        prop: prop,
                        id: id,
                        anchor: anchor,
                        generation: generation
                    )
                }
            return
        }

        if prop.bundledAssetName != nil {
            guard let entity = makeBundledLibraryEntity(for: prop) else {
                publishStatus("\(prop.title) modeli hazırlanamadı", color: .red)
                return
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
            loadingEntityIDs.insert(id)
            let generation = renderGeneration
            let request = ModelEntity.loadModelAsync(contentsOf: modelURL)
            assetLoadSubscriptions[id] = request
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    guard let self, self.renderGeneration == generation else { return }
                    self.loadingEntityIDs.remove(id)
                    self.assetLoadSubscriptions[id] = nil
                    if case .failure(let error) = completion {
                        self.publishStatus(
                            "3B dekor yüklenemedi: \(error.localizedDescription)",
                            color: .red
                        )
                    }
                } receiveValue: { [weak self] entity in
                    self?.attach(
                        entity: entity,
                        prop: prop,
                        id: id,
                        anchor: anchor,
                        generation: generation
                    )
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

        // Translation is deliberately excluded: a placed prop stays bound to its
        // world anchor. Rotation and scale remain available for art direction.
        arView.installGestures([.rotation, .scale], for: entity)

        renderedAnchorIDs.insert(anchor.identifier)
        renderedEntities[id] = entity
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
        settings.coneAngleDegrees = min(max(degrees, 15), 120)
        previewSelectedLight(settings)
    }

    func setSelectedLightYaw(_ degrees: Float) {
        guard var settings = selectedLightSettings else { return }
        settings.yawDegrees = min(max(degrees, -180), 180)
        previewSelectedLight(settings)
    }

    func setSelectedLightTilt(_ degrees: Float) {
        guard var settings = selectedLightSettings else { return }
        settings.tiltDegrees = min(max(degrees, -75), 75)
        previewSelectedLight(settings)
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
        light.light.innerAngleInDegrees = settings.coneAngleDegrees * 0.62
        light.light.outerAngleInDegrees = settings.coneAngleDegrees
        light.light.attenuationRadius = min(
            max(sqrt(max(settings.intensityLumens, 1) / 1_000) * 4, 2),
            12
        )
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

    private func defaultTransform(for prop: PropKind) -> Transform {
        let translation: SIMD3<Float>
        if let descriptor = prop.photorealDescriptor {
            switch descriptor.surface {
            case .floor, .horizontal:
                translation = [0, descriptor.dimensions.y * 0.5, 0]
            case .wall:
                translation = [0, 0, descriptor.dimensions.z * 0.5 + 0.008]
            case .ceiling:
                translation = [0, -descriptor.dimensions.y * 0.5, 0]
            }
        } else if let descriptor = libraryDescriptor(for: prop) {
            translation = [0, descriptor.dimensions.y * 0.5, 0]
        } else {
            let height: Float
            switch prop {
            case .stage: height = 0.09
            case .crate: height = 0.275
            case .plant: height = 0.18
            case .floorLamp: height = 0.025
            case .rug: height = 0.006
            case .backdrop: height = 0.90
            case .lightPanel, .wall, .chair, .table, .sofa, .bed, .bookcase,
                 .television, .refrigerator, .oven, .stove, .sink, .bathtub,
                 .toilet, .washerDryer, .stairs, .custom:
                height = 0
            default:
                height = 0
            }
            translation = [0, height, 0]
        }
        return Transform(
            scale: [1, 1, 1],
            rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
            translation: translation
        )
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
            excludeInactive: true
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
            excludeInactive: true
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
                -descriptor.dimensions.y * 0.5 + 0.004
            )
        }
        if let descriptor = libraryDescriptor(for: prop) {
            return (
                descriptor.dimensions.x * 0.82,
                descriptor.dimensions.z * 0.82,
                -descriptor.dimensions.y * 0.5 + 0.004
            )
        }
        switch prop {
        case .stage: return (1.82, 1.22, -0.086)
        case .crate: return (0.48, 0.48, -0.271)
        case .plant: return (0.31, 0.31, -0.176)
        case .floorLamp: return (0.30, 0.30, -0.021)
        case .backdrop: return (2.10, 0.18, -0.896)
        case .wall, .lightPanel, .rug, .custom, .chair, .table, .sofa,
             .bed, .bookcase, .television, .refrigerator, .oven, .stove,
             .sink, .bathtub, .toilet, .washerDryer, .stairs:
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

        case .chair, .table, .sofa, .bed, .bookcase, .television,
             .refrigerator, .oven, .stove, .sink, .bathtub, .toilet,
             .washerDryer, .stairs, .custom:
            preconditionFailure("USDZ assets are loaded through the library path")
        default:
            preconditionFailure("Photoreal USDZ assets are loaded asynchronously")
        }
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
    private func refreshPhysicalRoomOcclusionIfPossible() -> Bool {
        guard !isRoomScanActive,
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
        submitFrameToAIIfNeeded(frame)
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        updateKnownFloor(from: anchors)
        var shouldScheduleAutomaticSave = false
        for anchor in anchors {
            guard let descriptor = PropKind.descriptor(from: anchor.name) else { continue }
            knownPropAnchorIDs.insert(anchor.identifier)
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
        for anchor in anchors {
            guard let descriptor = PropKind.descriptor(from: anchor.name) else { continue }
            knownPropAnchorIDs.remove(anchor.identifier)
            renderedAnchorIDs.remove(anchor.identifier)
            loadingEntityIDs.remove(descriptor.id)
            assetLoadSubscriptions[descriptor.id]?.cancel()
            assetLoadSubscriptions[descriptor.id] = nil
            renderedEntities[descriptor.id]?.parent?.removeFromParent()
            renderedEntities[descriptor.id] = nil
            renderedLights[descriptor.id] = nil
            renderedLightEmitters[descriptor.id] = nil
            if selectedEntityID == descriptor.id {
                selectedEntityID = nil
                selectedLightSettings = nil
            }
        }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        guard !isSessionInterrupted, !isRoomScanActive else { return }
        switch camera.trackingState {
        case .normal:
            isARReady = true
            didAttemptSessionFailureRecovery = false
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
