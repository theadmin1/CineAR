import ARKit
import Combine
import RealityKit
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

    private(set) var arView: ARView?
    private let projectStore = SceneProjectStore()
    private let recorder = ProfessionalRecorder()
    private let roomRealityRenderer = RoomRealityRenderer(
        assetProvider: BundledRoomRealityAssetProvider()
    )
    private var renderedAnchorIDs = Set<UUID>()
    private var knownPropAnchorIDs = Set<UUID>()
    private var renderedEntities: [UUID: ModelEntity] = [:]
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

    private static let realityThemeDefaultsKey = "cinear.activeRealityTheme"

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
        importedAssetURLs = projectStore.importedModelURLs
        hasScannedRoom = FileManager.default.fileExists(atPath: roomDataURL.path)
        if let storedTheme = UserDefaults.standard.string(forKey: Self.realityThemeDefaultsKey) {
            preferredRealityThemeID = RealityThemeID(rawValue: storedTheme)
        }
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

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
        addCoachingOverlay(to: view)

        arView = view
        runSession()
        return view
    }

    private func configuration(initialWorldMap: ARWorldMap? = nil) -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        configuration.isLightEstimationEnabled = true
        configuration.isAutoFocusEnabled = true
        configuration.initialWorldMap = initialWorldMap

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
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
        loadingEntityIDs.removeAll()
        assetLoadSubscriptions.removeAll()
        selectedEntityID = nil
        guard let arView else { return }
        arView.scene.anchors.removeAll()
        roomCoordinateSpaceIsActive = initialWorldMap != nil
        arView.session.delegateQueue = .main
        arView.session.delegate = self
        arView.session.run(
            configuration(initialWorldMap: initialWorldMap),
            options: [.resetTracking, .removeExistingAnchors]
        )
        roomRealityRenderer.install(in: arView)
        restoreRoomRealityIfPossible()
    }

    func pauseForRoomScan() {
        let themeAwaitingSafeRestore = pendingRealityThemeAfterScan
        cancelPendingPostScanTheme()
        isRoomScanActive = true
        isARReady = false
        realityThemeToRestoreAfterScan = themeAwaitingSafeRestore
            ?? (roomRealityRenderer.isVisible ? activeRealityThemeID : nil)
        roomRealityRenderer.isVisible = false
        setPhysicalSceneOcclusion(enabled: false)
        arView?.isHidden = true
        do {
            try persistAllEntityTransforms()
        } catch {
            publishStatus("Dekor konumları kaydedilemedi: \(error.localizedDescription)", color: .red)
        }
        publishStatus("Oda taraması açılıyor; aynı dünya koordinatları korunuyor", color: .yellow)
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
            themeToSchedule = preferredRealityThemeID ?? .modern
            var invalidationMessage: String?
            do {
                try projectStore.invalidateWorldMapForRoomScan()
            } catch {
                invalidationMessage = error.localizedDescription
            }
            if let invalidationMessage {
                completionStatus = (
                    "Tema etkin, ancak proje haritası güncellenemedi: \(invalidationMessage)",
                    .red
                )
            } else {
                completionStatus = (
                    "Tarama kaydedildi — oda gerçekliği kamera takibiyle hizalanıyor",
                    .yellow
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
        setPhysicalSceneOcclusion(enabled: false)
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
            hasScannedRoom = true
            UserDefaults.standard.set(id.rawValue, forKey: Self.realityThemeDefaultsKey)
            setPhysicalSceneOcclusion(enabled: false)
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
            setPhysicalSceneOcclusion(enabled: true)
            publishStatus("Oda teması uygulanamadı: \(error.localizedDescription)", color: .red)
        }
    }

    func showOriginalReality() {
        cancelPendingPostScanTheme()
        shouldRestoreRoomRealityAfterInterruption = false
        roomRealityRenderer.isVisible = false
        activeRealityThemeID = nil
        preferredRealityThemeID = nil
        UserDefaults.standard.removeObject(forKey: Self.realityThemeDefaultsKey)
        setPhysicalSceneOcclusion(enabled: true)
        publishStatus("Gerçek oda görünümü etkin; eklediğin objeler korunuyor", color: .green)
    }

    func selectProp(_ prop: PropKind) {
        selectedProp = prop
        if prop == .custom, selectedAssetURL == nil {
            publishStatus("USDZ seçildi — önce kütüphaneden bir model ekle", color: .yellow)
        } else {
            publishStatus("\(prop.title) seçildi — kameradaki bir yüzeye dokun", color: .blue)
        }
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let arView else { return }
        let point = recognizer.location(in: arView)

        if let hitEntity = arView.entity(at: point),
           let id = entityID(from: hitEntity) {
            selectedEntityID = id
            publishStatus("Dekor seçildi — sürükle, döndür veya ölçekle", color: .blue)
            return
        }

        guard !isRoomScanActive, !isSessionInterrupted, isARReady else {
            publishStatus("Kamera takibi hazır olduğunda tekrar dokun", color: .yellow)
            return
        }

        guard let placementTransform = placementWorldTransform(
            in: arView,
            at: point,
            for: selectedProp
        ) else {
            publishStatus("Yüzey bulunamadı; telefonu biraz daha hareket ettir", color: .yellow)
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
            transform: StoredTransform(defaultTransform(for: selectedProp))
        )
        do {
            try projectStore.upsert(placement)
            let anchor = ARAnchor(
                name: selectedProp.anchorName(id: id),
                transform: placementTransform
            )
            knownPropAnchorIDs.insert(anchor.identifier)
            arView.session.add(anchor: anchor)
            selectedEntityID = id
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
            return placementTransform(
                position: hit.position,
                normal: hit.normal,
                prop: prop,
                cameraPosition: arView.cameraTransform.translation
            )
        }

        let preferredAlignment: ARRaycastQuery.TargetAlignment =
            (prop == .wall || prop == .lightPanel) ? .vertical : .horizontal
        let queries: [(ARRaycastQuery.Target, ARRaycastQuery.TargetAlignment)] = [
            (.existingPlaneGeometry, preferredAlignment),
            (.existingPlaneInfinite, preferredAlignment),
            (.estimatedPlane, preferredAlignment),
            (.existingPlaneGeometry, .any),
            (.existingPlaneInfinite, .any),
            (.estimatedPlane, .any)
        ]

        for (target, alignment) in queries {
            if let result = arView.raycast(
                from: point,
                allowing: target,
                alignment: alignment
            ).first {
                return result.worldTransform
            }
        }
        return nil
    }

    private func placementTransform(
        position: SIMD3<Float>,
        normal: SIMD3<Float>,
        prop: PropKind,
        cameraPosition: SIMD3<Float>
    ) -> simd_float4x4 {
        var transform = matrix_identity_float4x4
        transform.columns.3 = SIMD4(position.x, position.y, position.z, 1)

        guard prop == .wall || prop == .lightPanel else { return transform }

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
        assetLoadSubscriptions[id]?.cancel()
        assetLoadSubscriptions[id] = nil
        loadingEntityIDs.remove(id)
        selectedEntityID = nil
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
        selectedEntityID = nil
        publishStatus("Sanal dekorlar temizlendi", color: .green)
    }

    func importUSDZ(from sourceURL: URL) {
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }
        do {
            let importedURL = try projectStore.importModel(from: sourceURL)
            importedAssetURLs = projectStore.importedModelURLs
            selectedAssetURL = importedURL
            selectedProp = .custom
            publishStatus("\(importedURL.lastPathComponent) kütüphaneye eklendi", color: .green)
        } catch {
            publishStatus("USDZ içe aktarılamadı: \(error.localizedDescription)", color: .red)
        }
    }

    func reportAssetImportFailure(_ error: Error) {
        publishStatus("Dosya seçilemedi: \(error.localizedDescription)", color: .red)
    }

    func selectImportedAsset(_ url: URL) {
        selectedAssetURL = url
        selectedProp = .custom
        publishStatus("\(url.deletingPathExtension().lastPathComponent) seçildi", color: .blue)
    }

    func saveWorldMap() {
        guard let arView else {
            publishStatus("AR görünümü henüz hazır değil", color: .red)
            return
        }
        guard !isSavingWorldMap else {
            publishStatus("Sahne haritası zaten kaydediliyor", color: .yellow)
            return
        }
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

        if prop == .custom {
            guard let fileName = placement.assetFileName else {
                publishStatus("3B dekor yüklenemedi: USDZ kaydı eksik", color: .red)
                return
            }
            let modelURL: URL
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
        entity.generateCollisionShapes(recursive: true)
        anchorEntity.addChild(entity)
        arView.scene.addAnchor(anchorEntity)

        arView.installGestures(.all, for: entity)

        renderedAnchorIDs.insert(anchor.identifier)
        renderedEntities[id] = entity
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

    private func defaultTransform(for prop: PropKind) -> Transform {
        let height: Float
        switch prop {
        case .stage: height = 0.09
        case .crate: height = 0.275
        case .lightPanel, .wall, .custom: height = 0
        }
        return Transform(
            scale: [1, 1, 1],
            rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
            translation: [0, height, 0]
        )
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

        case .custom:
            preconditionFailure("Custom assets are loaded asynchronously")
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
            return
        }
        roomRealityRenderer.isVisible = false
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
                self.setPhysicalSceneOcclusion(enabled: false)
                let theme = RealityThemeCatalog.theme(withID: themeID)
                self.publishStatus("\(theme.title) oda gerçekliği yeniden hizalandı", color: .green)
                return
            }
            self.selectRealityTheme(themeID)
        }
        return true
    }

    private func setPhysicalSceneOcclusion(enabled: Bool) {
        guard let arView else { return }
        if enabled {
            arView.environment.sceneUnderstanding.options.insert(.occlusion)
        } else {
            arView.environment.sceneUnderstanding.options.remove(.occlusion)
        }
    }
}

extension ARSessionController: @preconcurrency ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let descriptor = PropKind.descriptor(from: anchor.name) else { continue }
            knownPropAnchorIDs.insert(anchor.identifier)
            DispatchQueue.main.async { [weak self] in
                self?.render(prop: descriptor.kind, id: descriptor.id, for: anchor)
            }
        }
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
            if selectedEntityID == descriptor.id {
                selectedEntityID = nil
            }
        }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        guard !isSessionInterrupted, !isRoomScanActive else { return }
        switch camera.trackingState {
        case .normal:
            isARReady = true
            didAttemptSessionFailureRecovery = false
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
            isARReady = true
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

extension ARSessionController: @preconcurrency UIGestureRecognizerDelegate {
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
