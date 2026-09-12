import ARKit
import Combine
import CoreVideo
import Foundation
import QuartzCore
import RealityKit
import simd

/// ARFrame owns these immutable Core Video buffers for the duration of the
/// background read. Core Video buffers are reference-counted and copyGeometry
/// brackets every base-address access with read-only locks.
private struct LiveDepthPixelBuffers: @unchecked Sendable {
    let depth: CVPixelBuffer
    let confidence: CVPixelBuffer
}

/// A camera-synchronised fine-depth supplement to ARKit's coarser reconstruction.
/// One worker and one mesh upload at a time; no queued ARFrames, network or collision hulls.
@MainActor
final class LiveDepthOcclusionRenderer {
    private weak var arView: ARView?
    private let worker = DispatchQueue(label: "com.cinear.lidar-occlusion", qos: .userInitiated)
    private var anchor: AnchorEntity?
    private var model: ModelEntity?
    private var generation: UInt64 = 0
    private var isBuilding = false
    private var upload: AnyCancellable?
    private var expiryTimer: AnyCancellable?
    private var lastSubmitted: TimeInterval = -.greatestFiniteMagnitude
    private var acceptedTimestamp: TimeInterval?
    private var acceptedReceivedAt: TimeInterval?
    private var acceptedPose: simd_float4x4?
    private var buildStartedAt: TimeInterval = 0
    private var lastBuildSeconds: TimeInterval = 0
    private(set) var status = "Anlık LiDAR derinliği bekleniyor"

    func install(in view: ARView) {
        if arView !== view || anchor?.scene == nil {
            anchor?.removeFromParent()
            let root = AnchorEntity(world: .zero)
            root.name = "cinear.live-depth.anchor"
            let surface = ModelEntity()
            surface.name = "cinear.live-depth.occlusion"
            surface.isEnabled = false
            root.addChild(surface)
            view.scene.addAnchor(root)
            anchor = root
            model = surface
        }
        arView = view
        if expiryTimer == nil {
            expiryTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
                .sink { [weak self] _ in self?.expireIfNeeded() }
        }
    }

    func clear() {
        generation &+= 1
        upload?.cancel()
        upload = nil
        // The worker may still be running. Keep isBuilding true until it returns,
        // so a restart cannot queue a second retained ARFrame behind it.
        model?.isEnabled = false
        model?.model = nil
        acceptedTimestamp = nil
        acceptedReceivedAt = nil
        acceptedPose = nil
        lastSubmitted = -.greatestFiniteMagnitude
    }

    func update(frame: ARFrame, enabled: Bool) {
        expireIfNeeded()
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) else {
            status = "Bu cihazda anlık LiDAR derinliği yok"
            return
        }
        guard enabled, case .normal = frame.camera.trackingState else {
            if acceptedTimestamp != nil || upload != nil || isBuilding { clear() }
            status = enabled ? "Takip kararlı değil — anlık örtme beklemede" : "Sanal nesne yerleştirildiğinde anlık örtme etkinleşir"
            return
        }
        guard let view = arView else { return }
        install(in: view)
        // Raw depth follows moving hands best. Keep smoothed depth as a valid fallback
        // when the device supports it only in combination with person segmentation.
        guard let depth = frame.sceneDepth ?? frame.smoothedSceneDepth,
              let confidenceBuffer = depth.confidenceMap else {
            if acceptedTimestamp != nil || upload != nil || isBuilding { clear() }
            status = "Anlık derinlik yok — ARKit yüzey örtmesi kullanılıyor"
            return
        }
        let thermal = ProcessInfo.processInfo.thermalState
        guard thermal != .critical else {
            clear()
            status = "Cihaz sıcak — ARKit yüzey örtmesi kullanılıyor"
            return
        }
        let reduced = thermal == .serious || lastBuildSeconds > 0.045
        let interval: TimeInterval = reduced ? 1.0 / 15 : 1.0 / 30
        guard !isBuilding, upload == nil, frame.timestamp - lastSubmitted >= interval else { return }
        isBuilding = true
        lastSubmitted = frame.timestamp
        let token = generation
        let timestamp = frame.timestamp
        let pose = frame.camera.transform
        let intrinsics = frame.camera.intrinsics
        let imageSize = frame.camera.imageResolution
        let startedAt = CACurrentMediaTime()
        buildStartedAt = startedAt
        // Retain only depth/confidence buffers, not the captured camera image/frame.
        let pixelBuffers = LiveDepthPixelBuffers(
            depth: depth.depthMap,
            confidence: confidenceBuffer
        )
        worker.async { [weak self] in
            let data = Self.copyGeometry(
                depth: pixelBuffers.depth, confidence: pixelBuffers.confidence,
                intrinsics: intrinsics, imageSize: imageSize, reduced: reduced
            )
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isBuilding = false
                guard self.generation == token else { return }
                self.lastBuildSeconds = CACurrentMediaTime() - startedAt
                guard let data else {
                    self.clear()
                    self.status = "LiDAR ölçümü yetersiz — yüzeyi başka açıdan göster"
                    return
                }
                guard self.matchesCurrentFrame(timestamp: timestamp, receivedAt: startedAt, pose: pose) else { return }
                var descriptor = MeshDescriptor(name: "cinear.live-depth")
                descriptor.positions = MeshBuffers.Positions(data.positions)
                descriptor.primitives = .triangles(data.indices)
                self.upload = MeshResource.generateAsync(from: [descriptor])
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] completion in
                        guard let self, self.generation == token else { return }
                        self.upload = nil
                        self.lastBuildSeconds = CACurrentMediaTime() - startedAt
                        if case .failure = completion {
                            self.clear()
                            self.status = "Anlık örtme hazırlanamadı — ARKit kullanılıyor"
                        }
                    } receiveValue: { [weak self] mesh in
                        guard let self, self.generation == token,
                              self.matchesCurrentFrame(timestamp: timestamp, receivedAt: startedAt, pose: pose) else { return }
                        self.model?.model = ModelComponent(mesh: mesh, materials: [OcclusionMaterial()])
                        self.model?.transform = Transform(matrix: pose)
                        self.model?.isEnabled = true
                        self.acceptedTimestamp = timestamp
                        self.acceptedReceivedAt = startedAt
                        self.acceptedPose = pose
                        self.status = "Anlık LiDAR örtmesi • güvenilir ölçüm %\(Int(data.validFraction * 100))"
                    }
            }
        }
    }

    private func expireIfNeeded() {
        if upload != nil, CACurrentMediaTime() - buildStartedAt > 0.25 {
            clear()
            status = "Derinlik işlemi gecikti — ARKit kullanılıyor"
        }
        guard let timestamp = acceptedTimestamp, let receivedAt = acceptedReceivedAt,
              let pose = acceptedPose else { return }
        if !matchesCurrentFrame(timestamp: timestamp, receivedAt: receivedAt, pose: pose) {
            model?.isEnabled = false
            acceptedTimestamp = nil
            acceptedReceivedAt = nil
            acceptedPose = nil
            status = "Güncel LiDAR ölçümü bekleniyor — ARKit kullanılıyor"
        }
    }

    private func matchesCurrentFrame(timestamp: TimeInterval, receivedAt: TimeInterval, pose: simd_float4x4) -> Bool {
        // Compare each clock only with itself; do not assume AR timestamps share
        // an epoch with CACurrentMediaTime. Wall time also catches a stalled session.
        guard LiveDepthGeometry.isFresh(capturedAt: receivedAt, now: CACurrentMediaTime()),
              let frame = arView?.session.currentFrame,
              case .normal = frame.camera.trackingState,
              LiveDepthGeometry.isFresh(capturedAt: timestamp, now: frame.timestamp) else { return false }
        let relative = simd_inverse(pose) * frame.camera.transform
        let translation = SIMD3<Float>(relative.columns.3.x, relative.columns.3.y, relative.columns.3.z)
        let trace = relative.columns.0.x + relative.columns.1.y + relative.columns.2.z
        // Test full orientation, including roll; forward-vector checks miss phone rotation.
        let cosine = min(max((trace - 1) * 0.5, -1), 1)
        return simd_length(translation) <= 0.07 && cosine >= cos(Float(8) * .pi / 180)
    }

    nonisolated private static func copyGeometry(
        depth: CVPixelBuffer, confidence: CVPixelBuffer,
        intrinsics: simd_float3x3, imageSize: CGSize, reduced: Bool
    ) -> LiveDepthMeshData? {
        let width = CVPixelBufferGetWidth(depth)
        let height = CVPixelBufferGetHeight(depth)
        guard (2...1024).contains(width), (2...1024).contains(height),
              CVPixelBufferGetPixelFormatType(depth) == kCVPixelFormatType_DepthFloat32,
              CVPixelBufferGetPixelFormatType(confidence) == kCVPixelFormatType_OneComponent8,
              CVPixelBufferGetWidth(confidence) == width,
              CVPixelBufferGetHeight(confidence) == height,
              imageSize.width > 0, imageSize.height > 0 else { return nil }
        guard CVPixelBufferLockBaseAddress(depth, .readOnly) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(depth, .readOnly) }
        guard CVPixelBufferLockBaseAddress(confidence, .readOnly) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(confidence, .readOnly) }
        guard let depthBase = CVPixelBufferGetBaseAddress(depth),
              let confidenceBase = CVPixelBufferGetBaseAddress(confidence) else { return nil }
        let depthStride = CVPixelBufferGetBytesPerRow(depth)
        let confidenceStride = CVPixelBufferGetBytesPerRow(confidence)
        let sx = Float(width) / Float(imageSize.width)
        let sy = Float(height) / Float(imageSize.height)
        // Ceil keeps oversized streams inside the hard mesh allocation budget.
        var step = max(reduced ? 2 : 1, max((width + 255) / 256, (height + 191) / 192))
        func sampleCount(_ extent: Int) -> Int { (extent - 1 + step - 1) / step + 1 }
        while sampleCount(width) * sampleCount(height) > LiveDepthGeometry.maximumSampleCount { step += 1 }
        return LiveDepthGeometry.build(
            width: width, height: height, step: step,
            fx: intrinsics.columns.0.x * sx, fy: intrinsics.columns.1.y * sy,
            cx: intrinsics.columns.2.x * sx, cy: intrinsics.columns.2.y * sy
        ) { x, y in
            let z = depthBase.advanced(by: y * depthStride).assumingMemoryBound(to: Float.self)[x]
            let confidenceValue = confidenceBase.advanced(by: y * confidenceStride)
                .assumingMemoryBound(to: UInt8.self)[x]
            return (z, confidenceValue)
        }
    }
}
