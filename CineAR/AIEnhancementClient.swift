import ARKit
import CoreImage
import Foundation
import RealityKit
import UIKit
import simd

enum AIEnhancementStatus: Equatable {
    case disabled
    case localLiDAR
    case waiting
    case waitingForDepth
    case stabilizing
    case active(latencyMilliseconds: Int, samMaskCount: Int)
    case failed(String)

    var title: String {
        switch self {
        case .disabled: "Kapalı"
        case .localLiDAR: "Canlı LiDAR modu · PC karesi gönderilmiyor"
        case .waiting: "PC bağlantısı bekleniyor"
        case .waitingForDepth: "PC bağlı · LiDAR karesi bekleniyor"
        case .stabilizing: "Kamera yavaşlayınca AI derinliği uygulanacak"
        case .active(let latency, let masks): "Aktif · \(latency) ms · \(masks) maske"
        case .failed(let message): "Hata · \(message)"
        }
    }
}

struct AIDepthResult {
    let frameID: UUID
    let cameraTransform: simd_float4x4
    let intrinsics: simd_float3x3
    let imageWidth: Int
    let imageHeight: Int
    let depthWidth: Int
    let depthHeight: Int
    let depthMeters: [Float]
    let totalLatencyMilliseconds: Int
    let inferenceMilliseconds: Int
    let samMaskCount: Int
}

enum AIEnhancementError: LocalizedError {
    case invalidServerAddress
    case missingSceneDepth
    case imageEncodingFailed
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidServerAddress: "PC otomatik bulunamadı; terminaldeki http://...:8765 adresini gir"
        case .missingSceneDepth: "Bu karede LiDAR derinliği yok"
        case .imageEncodingFailed: "Kamera karesi AI servisi için hazırlanamadı"
        case .invalidResponse: "AI servisinden geçersiz derinlik verisi geldi"
        case .server(let message): message
        }
    }
}

@MainActor
final class AIEnhancementClient {
    private struct CapturedMetadata {
        let frameID: UUID
        let cameraTransform: simd_float4x4
        let intrinsics: simd_float3x3
        let imageWidth: Int
        let imageHeight: Int
        let depthWidth: Int
        let depthHeight: Int
        let startedAt: ContinuousClock.Instant
    }

    private let context = CIContext(options: [.cacheIntermediates: false])
    private let clock = ContinuousClock()
    private var activeTask: URLSessionDataTask?
    private var lastSubmission: ContinuousClock.Instant?
    private let minimumFrameInterval: Duration = .milliseconds(500)

    var isBusy: Bool { activeTask != nil }

    nonisolated static func serverURL(from text: String) -> URL? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if !value.contains("://") { value = "http://" + value }
        guard var components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.host != nil,
              components.user == nil,
              components.password == nil else { return nil }
        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.url
    }

    func cancel() {
        activeTask?.cancel()
        activeTask = nil
    }

    func submit(
        frame: ARFrame,
        serverURL: URL,
        completion: @escaping (Result<AIDepthResult, Error>) -> Void
    ) {
        guard activeTask == nil else { return }
        let now = clock.now
        if let lastSubmission, now - lastSubmission < minimumFrameInterval { return }
        lastSubmission = now

        guard let sceneDepth = frame.smoothedSceneDepth ?? frame.sceneDepth else {
            completion(.failure(AIEnhancementError.missingSceneDepth))
            return
        }
        let depthMap = sceneDepth.depthMap
        let depthWidth = CVPixelBufferGetWidth(depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthMap)
        guard let lidarData = Self.copyFloat32Depth(from: depthMap) else {
            completion(.failure(AIEnhancementError.missingSceneDepth))
            return
        }

        let capturedImage = frame.capturedImage
        let imageWidth = CVPixelBufferGetWidth(capturedImage)
        let imageHeight = CVPixelBufferGetHeight(capturedImage)
        guard let jpegData = jpegData(from: capturedImage) else {
            completion(.failure(AIEnhancementError.imageEncodingFailed))
            return
        }

        let metadata = CapturedMetadata(
            frameID: UUID(),
            cameraTransform: frame.camera.transform,
            intrinsics: frame.camera.intrinsics,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            depthWidth: depthWidth,
            depthHeight: depthHeight,
            startedAt: now
        )
        var endpoint = serverURL
        endpoint.append(path: "v1/depth")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        let boundary = "CineAR-\(metadata.frameID.uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.multipartBody(
            boundary: boundary,
            frameID: metadata.frameID,
            depthWidth: depthWidth,
            depthHeight: depthHeight,
            jpegData: jpegData,
            lidarData: lidarData
        )

        activeTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.activeTask = nil
                if let error {
                    if (error as? URLError)?.code != .cancelled {
                        completion(.failure(Self.connectionError(error, serverURL: serverURL)))
                    }
                    return
                }
                guard let http = response as? HTTPURLResponse, let data else {
                    completion(.failure(AIEnhancementError.invalidResponse))
                    return
                }
                guard (200..<300).contains(http.statusCode) else {
                    let detail = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
                    completion(.failure(AIEnhancementError.server(detail)))
                    return
                }
                let expectedCount = metadata.depthWidth * metadata.depthHeight
                guard data.count == expectedCount * MemoryLayout<Float>.size else {
                    completion(.failure(AIEnhancementError.invalidResponse))
                    return
                }
                var depths = [Float](repeating: 0, count: expectedCount)
                _ = depths.withUnsafeMutableBytes { destination in
                    data.copyBytes(to: destination)
                }
                let elapsed = metadata.startedAt.duration(to: self.clock.now)
                let components = elapsed.components
                let totalMilliseconds = Int(components.seconds * 1_000)
                    + Int(components.attoseconds / 1_000_000_000_000_000)
                let inference = Int(
                    Double(http.value(forHTTPHeaderField: "X-CineAR-Inference-MS") ?? "0") ?? 0
                )
                let masks = Int(http.value(forHTTPHeaderField: "X-CineAR-SAM-Masks") ?? "0") ?? 0
                completion(.success(AIDepthResult(
                    frameID: metadata.frameID,
                    cameraTransform: metadata.cameraTransform,
                    intrinsics: metadata.intrinsics,
                    imageWidth: metadata.imageWidth,
                    imageHeight: metadata.imageHeight,
                    depthWidth: metadata.depthWidth,
                    depthHeight: metadata.depthHeight,
                    depthMeters: depths,
                    totalLatencyMilliseconds: totalMilliseconds,
                    inferenceMilliseconds: inference,
                    samMaskCount: masks
                )))
            }
        }
        activeTask?.resume()
    }

    func testHealth(
        serverURL: URL,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        var endpoint = serverURL
        endpoint.append(path: "health")
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                if let error {
                    completion(.failure(Self.connectionError(error, serverURL: serverURL)))
                    return
                }
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode),
                      let data,
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      object["ready"] as? Bool == true else {
                    completion(.failure(AIEnhancementError.invalidResponse))
                    return
                }
                let device = object["device"] as? String ?? "bilinmeyen cihaz"
                let samEnabled = object["sam_enabled"] as? Bool ?? true
                let samPoints = object["sam_points_per_side"] as? Int
                let samSide = object["sam_max_side"] as? Int
                let depthSize = object["depth_input_size"] as? Int
                let warmup = object["warmup_milliseconds"] as? Double
                let warmupText = warmup.map { String(format: " • ısınma %.0f ms", $0) } ?? ""
                if let depthSize, !samEnabled {
                    completion(.success(
                        "\(device) • hızlı Depth \(depthSize) px • SAM kapalı\(warmupText)"
                    ))
                } else if let depthSize, let samPoints, let samSide {
                    completion(.success(
                        "\(device) • Depth \(depthSize) px • SAM \(samPoints)/\(samSide) px\(warmupText)"
                    ))
                } else if let samPoints, let samSide {
                    completion(.success("\(device) • hızlı SAM \(samPoints)/\(samSide) px"))
                } else {
                    completion(.success(device))
                }
            }
        }.resume()
    }

    private static func connectionError(_ error: Error, serverURL: URL) -> Error {
        guard let urlError = error as? URLError else { return error }
        let address = serverURL.absoluteString
        switch urlError.code {
        case .timedOut:
            return AIEnhancementError.server(
                "PC yanıt vermedi: \(address). Aynı Wi-Fi ve güvenlik duvarını kontrol et"
            )
        case .cannotConnectToHost:
            return AIEnhancementError.server(
                "\(address) adresinde servis yok; PC'de run_server.ps1 açık kalmalı"
            )
        case .cannotFindHost:
            return AIEnhancementError.server("PC adresi bulunamadı: \(address)")
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return AIEnhancementError.server(
                "iPhone ağ bağlantısı veya CineAR Yerel Ağ izni kapalı"
            )
        case .appTransportSecurityRequiresSecureConnection:
            return AIEnhancementError.server("iOS yerel HTTP bağlantısını engelledi")
        default:
            return AIEnhancementError.server(urlError.localizedDescription)
        }
    }

    private func jpegData(from pixelBuffer: CVPixelBuffer) -> Data? {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let maximumSide: CGFloat = 512
        let scale = min(1, maximumSide / max(image.extent.width, image.extent.height))
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.62)
    }

    private static func copyFloat32Depth(from pixelBuffer: CVPixelBuffer) -> Data? {
        guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_DepthFloat32 else {
            return nil
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        var result = Data(capacity: width * height * MemoryLayout<Float>.size)
        for row in 0..<height {
            let bytes = base
                .advanced(by: row * bytesPerRow)
                .assumingMemoryBound(to: UInt8.self)
            result.append(bytes, count: width * MemoryLayout<Float>.size)
        }
        return result
    }

    private static func multipartBody(
        boundary: String,
        frameID: UUID,
        depthWidth: Int,
        depthHeight: Int,
        jpegData: Data,
        lidarData: Data
    ) -> Data {
        var body = Data()
        func append(_ value: String) {
            body.append(value.data(using: .utf8)!)
        }
        func field(_ name: String, _ value: String) {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            append("\(value)\r\n")
        }
        field("frame_id", frameID.uuidString)
        field("depth_width", String(depthWidth))
        field("depth_height", String(depthHeight))
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"image\"; filename=\"frame.jpg\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        body.append(jpegData)
        append("\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"lidar\"; filename=\"depth.f32\"\r\n")
        append("Content-Type: application/octet-stream\r\n\r\n")
        body.append(lidarData)
        append("\r\n--\(boundary)--\r\n")
        return body
    }
}

@MainActor
final class AIDepthOcclusionRenderer {
    private weak var arView: ARView?
    private var anchor: AnchorEntity?
    private var model: ModelEntity?

    func install(in arView: ARView) {
        self.arView = arView
        if let anchor, anchor.parent != nil { return }
        let newAnchor = AnchorEntity(world: SIMD3<Float>(repeating: 0))
        newAnchor.name = "cinear.ai-depth.anchor"
        arView.scene.addAnchor(newAnchor)
        anchor = newAnchor
    }

    func clear() {
        model?.removeFromParent()
        model = nil
    }

    func remove() {
        clear()
        anchor?.removeFromParent()
        anchor = nil
        arView = nil
    }

    func render(_ result: AIDepthResult) throws {
        guard let arView else { return }
        install(in: arView)
        let mesh = try Self.makeMesh(from: result)
        let replacement = ModelEntity(mesh: mesh, materials: [OcclusionMaterial()])
        replacement.name = "cinear.ai-depth.occlusion.\(result.frameID.uuidString)"
        anchor?.addChild(replacement)
        let previous = model
        model = replacement
        previous?.removeFromParent()
    }

    private static func makeMesh(from result: AIDepthResult) throws -> MeshResource {
        let width = result.depthWidth
        let height = result.depthHeight
        let step = max(1, max(width / 80, height / 60))
        var xValues = Array(stride(from: 0, to: width, by: step))
        var yValues = Array(stride(from: 0, to: height, by: step))
        if xValues.last != width - 1 { xValues.append(width - 1) }
        if yValues.last != height - 1 { yValues.append(height - 1) }

        let fx = result.intrinsics.columns.0.x * Float(width) / Float(result.imageWidth)
        let fy = result.intrinsics.columns.1.y * Float(height) / Float(result.imageHeight)
        let cx = result.intrinsics.columns.2.x * Float(width) / Float(result.imageWidth)
        let cy = result.intrinsics.columns.2.y * Float(height) / Float(result.imageHeight)
        guard fx.isFinite, fy.isFinite, fx > 0, fy > 0 else {
            throw AIEnhancementError.invalidResponse
        }

        let columns = xValues.count
        var positions = [SIMD3<Float>]()
        var sampledDepths = [Float]()
        var valid = [Bool]()
        positions.reserveCapacity(columns * yValues.count)
        sampledDepths.reserveCapacity(columns * yValues.count)
        valid.reserveCapacity(columns * yValues.count)
        for y in yValues {
            for x in xValues {
                let measuredDepth = result.depthMeters[y * width + x]
                let isValid = measuredDepth.isFinite && (0.15...12).contains(measuredDepth)
                sampledDepths.append(measuredDepth)
                valid.append(isValid)
                guard isValid else {
                    positions.append(.zero)
                    continue
                }
                // AI/LiDAR calibration noise must not put the invisible occluder in
                // front of a prop that is touching the same physical surface. Move
                // it a few centimetres away from the captured camera; foreground
                // furniture and people still have a much larger depth separation.
                let safetyBias = min(max(measuredDepth * 0.012, 0.025), 0.060)
                let renderDepth = measuredDepth + safetyBias
                let cameraX = (Float(x) - cx) / fx * renderDepth
                let cameraY = -(Float(y) - cy) / fy * renderDepth
                let cameraPoint = SIMD4<Float>(cameraX, cameraY, -renderDepth, 1)
                let worldPoint = result.cameraTransform * cameraPoint
                positions.append([worldPoint.x, worldPoint.y, worldPoint.z])
            }
        }

        var indices = [UInt32]()
        for row in 0..<(yValues.count - 1) {
            for column in 0..<(columns - 1) {
                let topLeft = row * columns + column
                let topRight = topLeft + 1
                let bottomLeft = topLeft + columns
                let bottomRight = bottomLeft + 1
                let corners = [topLeft, topRight, bottomLeft, bottomRight]
                guard corners.allSatisfy({ valid[$0] }) else { continue }
                let depths = corners.map { sampledDepths[$0] }
                let minimum = depths.min() ?? 0
                let maximum = depths.max() ?? .greatestFiniteMagnitude
                let allowedJump = max(0.12, minimum * 0.08)
                guard maximum - minimum <= allowedJump else { continue }
                indices.append(contentsOf: [
                    UInt32(topLeft), UInt32(bottomLeft), UInt32(topRight),
                    UInt32(topRight), UInt32(bottomLeft), UInt32(bottomRight),
                ])
            }
        }
        guard indices.count >= 3 else { throw AIEnhancementError.invalidResponse }
        var descriptor = MeshDescriptor(name: "cinear.ai-depth.mesh")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }
}
