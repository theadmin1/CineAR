import RoomPlan
import SwiftUI
import UIKit

enum RoomScanResult: Equatable, Sendable {
    case success(URL)
    case cancelled
    case failure(String)
}

final class RoomScannerController: NSObject, ObservableObject {
    static var isSupported: Bool { RoomCaptureSession.isSupported }

    @Published private(set) var statusText = "Odayı yavaşça tarayın"
    @Published private(set) var isProcessing = false
    @Published private(set) var exportSucceeded = false
    @Published private(set) var failureMessage: String?

    let captureView = RoomCaptureView(frame: .zero)
    private let exportURL: URL
    private let configuration = RoomCaptureSession.Configuration()
    private var shouldExport = true
    private var isSessionRunning = false
    private var pendingExportURL: URL?

    init(exportURL: URL) {
        self.exportURL = exportURL
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
        guard !isSessionRunning, !isProcessing else { return }

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
        captureView.captureSession.stop()
    }

    func cancel() {
        shouldExport = false
        isProcessing = false
        discardPendingExport()
        guard isSessionRunning else { return }

        isSessionRunning = false
        captureView.captureSession.stop()
    }

    func commitExport() -> URL? {
        guard exportSucceeded, let pendingExportURL else {
            recordFailure("Kaydedilecek oda modeli bulunamadı")
            return nil
        }

        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: exportURL.path) {
                _ = try fileManager.replaceItemAt(exportURL, withItemAt: pendingExportURL)
            } else {
                try fileManager.moveItem(at: pendingExportURL, to: exportURL)
            }
            self.pendingExportURL = nil
            return exportURL
        } catch {
            recordFailure("Oda modeli kullanıma alınamadı: \(error.localizedDescription)")
            return nil
        }
    }

    private func recordFailure(_ message: String) {
        shouldExport = false
        discardPendingExport()
        exportSucceeded = false
        isProcessing = false
        isSessionRunning = false
        failureMessage = message
        statusText = message
    }

    private func discardPendingExport() {
        guard let pendingExportURL else { return }
        try? FileManager.default.removeItem(at: pendingExportURL)
        self.pendingExportURL = nil
    }
}

extension RoomScannerController: RoomCaptureSessionDelegate {
    func captureSession(
        _ session: RoomCaptureSession,
        didEndWith data: CapturedRoomData,
        error: Error?
    ) {
        guard let error else { return }
        let message = "Tarama hatası: \(error.localizedDescription)"
        DispatchQueue.main.async { [weak self] in
            guard let self, self.shouldExport else { return }
            self.recordFailure(message)
        }
    }
}

extension RoomScannerController: RoomCaptureViewDelegate {
    func captureView(
        shouldPresent roomDataForProcessing: CapturedRoomData,
        error: Error?
    ) -> Bool {
        guard shouldExport else { return false }
        guard let error else { return true }

        let message = "Tarama hatası: \(error.localizedDescription)"
        DispatchQueue.main.async { [weak self] in
            guard let self, self.shouldExport else { return }
            self.recordFailure(message)
        }
        return false
    }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.shouldExport else {
                self.isProcessing = false
                return
            }

            do {
                if let error { throw error }
                self.pendingExportURL = try self.stageExport(processedResult)
                self.statusText = "Oda modeli kaydedildi"
                self.exportSucceeded = true
                self.failureMessage = nil
            } catch {
                self.recordFailure("Model dışa aktarılamadı: \(error.localizedDescription)")
            }
            self.isProcessing = false
        }
    }
}

private extension RoomScannerController {
    func stageExport(_ room: CapturedRoom) throws -> URL {
        let fileManager = FileManager.default
        let directory = exportURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let temporaryURL = directory
            .appendingPathComponent("RoomScan-\(UUID().uuidString)")
            .appendingPathExtension("usdz")
        do {
            try room.export(to: temporaryURL, exportOptions: .parametric)
            return temporaryURL
        } catch {
            if fileManager.fileExists(atPath: temporaryURL.path) {
                try? fileManager.removeItem(at: temporaryURL)
            }
            throw error
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
        onComplete: @escaping (RoomScanResult) -> Void = { _ in }
    ) {
        self.onComplete = onComplete
        _scanner = StateObject(wrappedValue: RoomScannerController(exportURL: exportURL))
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
            break
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
        coordinator.controller?.cancel()
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
