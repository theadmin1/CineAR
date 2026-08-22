import ARKit
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
        var installedJSON = false

        do {
            if hadJSON {
                try fileManager.copyItem(at: roomJSONURL, to: jsonBackupURL)
            }

            try install(staged.roomJSONURL, at: roomJSONURL)
            installedJSON = true

            removeIfPresent(jsonBackupURL)
            removeIfPresent(modelURL)
        } catch {
            let originalMessage = error.localizedDescription
            var rollbackMessages: [String] = []

            if installedJSON {
                do {
                    try restore(
                        finalURL: roomJSONURL,
                        backupURL: jsonBackupURL,
                        previouslyExisted: hadJSON
                    )
                } catch {
                    rollbackMessages.append(error.localizedDescription)
                }
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

@MainActor
final class RoomScannerController: NSObject, ObservableObject {
    static var isSupported: Bool { RoomCaptureSession.isSupported }

    @Published private(set) var statusText = "Odayı yavaşça tarayın"
    @Published private(set) var isProcessing = false
    @Published private(set) var exportSucceeded = false
    @Published private(set) var failureMessage: String?

    let captureView: RoomCaptureView
    let roomJSONURL: URL

    private let roomStore: CapturedRoomStore
    private let configuration = RoomCaptureSession.Configuration()
    private let preservesSharedARSession: Bool
    private var shouldExport = true
    private var isSessionRunning = false
    private var isTornDown = false
    private var pendingArtifacts: CapturedRoomStore.StagedArtifacts?
    private var scanGeneration: UInt64 = 0
    private var stagingTask: Task<CapturedRoomStageOutcome, Never>?

    init(
        exportURL: URL,
        roomJSONURL: URL? = nil,
        arSession: ARSession? = nil
    ) {
        let store = CapturedRoomStore(
            modelURL: exportURL,
            roomJSONURL: roomJSONURL
        )
        self.roomStore = store
        self.roomJSONURL = store.roomJSONURL
        self.preservesSharedARSession = arSession != nil
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
        stagingTask?.cancel()
        stagingTask = nil
        shouldExport = true
        discardPendingExport()
        exportSucceeded = false
        failureMessage = nil
        statusText = "Odayı yavaşça tarayın"
        isSessionRunning = true
        captureView.captureSession.run(configuration: configuration)
    }

    func finish() {
        guard isSessionRunning, !isProcessing else { return }

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
        scanGeneration &+= 1
        stagingTask?.cancel()
        stagingTask = nil
        shouldExport = false
        discardPendingExport()
        exportSucceeded = false
        isProcessing = false
        isSessionRunning = false
        failureMessage = message
        statusText = message
    }

    private func discardPendingExport() {
        guard let pendingArtifacts else { return }
        roomStore.discard(pendingArtifacts)
        self.pendingArtifacts = nil
    }

    func teardownForDismissal(discardPendingExport shouldDiscard: Bool = true) {
        guard !isTornDown else { return }
        isTornDown = true
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
    func captureSession(
        _ session: RoomCaptureSession,
        didEndWith data: CapturedRoomData,
        error: Error?
    ) {
        guard let error else { return }
        let message = "Tarama hatası: \(error.localizedDescription)"
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

        let message = "Tarama hatası: \(error.localizedDescription)"
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

        let modelURL = roomStore.modelURL
        let roomJSONURL = roomStore.roomJSONURL
        let callbackError = error?.localizedDescription
        scanGeneration &+= 1
        let generation = scanGeneration
        stagingTask?.cancel()

        statusText = "Oda verisi güvenli biçimde hazırlanıyor..."
        let worker = Task.detached(priority: .userInitiated) {
            guard !Task.isCancelled else {
                return CapturedRoomStageOutcome(artifacts: nil, failureMessage: nil)
            }
            if let callbackError {
                return CapturedRoomStageOutcome(
                    artifacts: nil,
                    failureMessage: callbackError
                )
            }
            do {
                let store = CapturedRoomStore(
                    modelURL: modelURL,
                    roomJSONURL: roomJSONURL
                )
                let artifacts = try store.stage(processedResult)
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
                self.statusText = "Oda modeli ve mekân verisi hazır"
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
        onComplete: @escaping (RoomScanResult) -> Void = { _ in }
    ) {
        self.onComplete = onComplete
        _scanner = StateObject(
            wrappedValue: RoomScannerController(
                exportURL: exportURL,
                roomJSONURL: roomJSONURL,
                arSession: arSession
            )
        )
    }

    var body: some View {
        ZStack {
            RoomCaptureContainer(controller: scanner)
                .ignoresSafeArea()

            VStack {
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
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

                Spacer()

                if scanner.exportSucceeded {
                    Button("Taramayı Kullan") {
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
                    .disabled(scanner.isProcessing || !RoomScannerController.isSupported)
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
