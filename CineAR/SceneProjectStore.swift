import CryptoKit
import Foundation
import RealityKit
import simd

struct SceneProject: Codable {
    static let currentVersion = 2

    var version = currentVersion
    var name = "Ana Set"
    var createdAt = Date()
    var updatedAt = Date()
    var placements: [PlacementRecord] = []
    var worldMapChecksum: String?
}

struct PlacementRecord: Codable, Identifiable {
    let id: UUID
    let kind: PropKind
    var assetFileName: String?
    var transform: StoredTransform
}

struct StoredWorldMapSnapshot {
    let data: Data
    let project: SceneProject
}

struct StoredTransform: Codable {
    var translation: [Float]
    var rotation: [Float]
    var scale: [Float]

    init(_ transform: Transform) {
        translation = [transform.translation.x, transform.translation.y, transform.translation.z]
        rotation = [
            transform.rotation.vector.x,
            transform.rotation.vector.y,
            transform.rotation.vector.z,
            transform.rotation.vector.w
        ]
        scale = [transform.scale.x, transform.scale.y, transform.scale.z]
    }

    var realityKitTransform: Transform {
        Transform(
            scale: SIMD3(scale[0], scale[1], scale[2]),
            rotation: simd_normalize(
                simd_quatf(
                    ix: rotation[0],
                    iy: rotation[1],
                    iz: rotation[2],
                    r: rotation[3]
                )
            ),
            translation: SIMD3(translation[0], translation[1], translation[2])
        )
    }
}

enum SceneProjectStoreError: LocalizedError {
    case unsupportedProjectVersion(Int)
    case invalidTransform(UUID)
    case duplicatePlacement(UUID)
    case missingPlacement(UUID)
    case invalidAssetFileName(String)
    case unsupportedAssetType
    case worldMapOutOfDate
    case worldMapChecksumMismatch
    case emptyWorldMap

    var errorDescription: String? {
        switch self {
        case .unsupportedProjectVersion(let version):
            "scene.json sürümü desteklenmiyor (sürüm \(version))"
        case .invalidTransform(let id):
            "\(id.uuidString) kimlikli dekorun dönüşüm verisi geçersiz"
        case .duplicatePlacement(let id):
            "scene.json içinde yinelenen dekor kimliği var: \(id.uuidString)"
        case .missingPlacement(let id):
            "\(id.uuidString) kimlikli dekor proje kaydında bulunamadı"
        case .invalidAssetFileName(let name):
            "Geçersiz 3B model dosya adı: \(name)"
        case .unsupportedAssetType:
            "Yalnızca USDZ dosyaları içe aktarılabilir"
        case .worldMapOutOfDate:
            "Sahne son harita kaydından sonra değişmiş; önce yeniden Kaydet'e dokunun"
        case .worldMapChecksumMismatch:
            "worldmap ve scene.json aynı kayıt sürümüne ait değil"
        case .emptyWorldMap:
            "Dünya haritası dosyası boş"
        }
    }
}

final class SceneProjectStore {
    private let fileManager = FileManager.default

    private(set) var project: SceneProject
    private(set) var initializationError: Error?

    init() {
        project = SceneProject()
        do {
            try fileManager.createDirectory(
                at: projectDirectory,
                withIntermediateDirectories: true
            )
            if fileManager.fileExists(atPath: projectURL.path) {
                project = try Self.decodeProject(from: projectURL)
            }
        } catch {
            initializationError = error
        }
    }

    var projectDirectory: URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("CineARProjects", isDirectory: true)
            .appendingPathComponent("MainSet", isDirectory: true)
    }

    var projectURL: URL { projectDirectory.appendingPathComponent("scene.json") }
    var worldMapURL: URL { projectDirectory.appendingPathComponent("worldmap.arexperience") }
    var roomModelURL: URL { projectDirectory.appendingPathComponent("room.usdz") }
    var roomDataURL: URL { projectDirectory.appendingPathComponent("room.json") }
    var recordingsDirectory: URL {
        projectDirectory.appendingPathComponent("Recordings", isDirectory: true)
    }
    var assetsDirectory: URL {
        projectDirectory.appendingPathComponent("Assets", isDirectory: true)
    }

    var importedModelURLs: [URL] {
        (try? fileManager.contentsOfDirectory(
            at: assetsDirectory,
            includingPropertiesForKeys: [.isRegularFileKey]
        ).filter {
            $0.pathExtension.lowercased() == "usdz"
                && ((try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false)
        }.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }) ?? []
    }

    func importModel(from sourceURL: URL) throws -> URL {
        guard sourceURL.isFileURL, sourceURL.pathExtension.lowercased() == "usdz" else {
            throw SceneProjectStoreError.unsupportedAssetType
        }
        try fileManager.createDirectory(at: assetsDirectory, withIntermediateDirectories: true)

        let rawBaseName = sourceURL.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = rawBaseName.isEmpty ? "Model" : rawBaseName
        var destination = assetsDirectory.appendingPathComponent(baseName)
            .appendingPathExtension("usdz")
        var suffix = 2
        while fileManager.fileExists(atPath: destination.path) {
            destination = assetsDirectory.appendingPathComponent("\(baseName)-\(suffix)")
                .appendingPathExtension("usdz")
            suffix += 1
        }
        try fileManager.copyItem(at: sourceURL, to: destination)
        return destination
    }

    func modelURL(fileName: String) throws -> URL {
        guard fileName == URL(fileURLWithPath: fileName).lastPathComponent,
              !fileName.isEmpty,
              URL(fileURLWithPath: fileName).pathExtension.lowercased() == "usdz" else {
            throw SceneProjectStoreError.invalidAssetFileName(fileName)
        }
        return assetsDirectory.appendingPathComponent(fileName)
    }

    func placement(id: UUID) -> PlacementRecord? {
        project.placements.first { $0.id == id }
    }

    func upsert(_ placement: PlacementRecord) throws {
        try commit(invalidateWorldMap: true) { candidate in
            if let index = candidate.placements.firstIndex(where: { $0.id == placement.id }) {
                candidate.placements[index] = placement
            } else {
                candidate.placements.append(placement)
            }
        }
    }

    func updateTransforms(_ transforms: [UUID: Transform]) throws {
        if let initializationError { throw initializationError }
        guard !transforms.isEmpty else { return }
        try commit(invalidateWorldMap: false) { candidate in
            for (id, transform) in transforms {
                guard let index = candidate.placements.firstIndex(where: { $0.id == id }) else {
                    throw SceneProjectStoreError.missingPlacement(id)
                }
                candidate.placements[index].transform = StoredTransform(transform)
            }
        }
    }

    func remove(id: UUID) throws {
        try commit(invalidateWorldMap: true) { candidate in
            guard candidate.placements.contains(where: { $0.id == id }) else {
                throw SceneProjectStoreError.missingPlacement(id)
            }
            candidate.placements.removeAll { $0.id == id }
        }
    }

    func removeAll() throws {
        try commit(invalidateWorldMap: true) { candidate in
            candidate.placements.removeAll()
        }
    }

    /// A new RoomPlan scan has a new spatial source of truth. Keep placements,
    /// but force the user to save a matching ARWorldMap before a later reload.
    func invalidateWorldMapForRoomScan() throws {
        try commit(invalidateWorldMap: true) { _ in }
    }

    func saveWorldMapData(_ data: Data) throws {
        if let initializationError { throw initializationError }
        guard !data.isEmpty else { throw SceneProjectStoreError.emptyWorldMap }
        try fileManager.createDirectory(at: projectDirectory, withIntermediateDirectories: true)

        var candidate = project
        candidate.version = SceneProject.currentVersion
        candidate.updatedAt = Date()
        candidate.worldMapChecksum = Self.checksum(for: data)
        try Self.validate(candidate)
        let projectData = try Self.encode(candidate)

        // The map is written first. If the following JSON write fails, the previous
        // JSON checksum will reject this new map instead of loading a mismatched pair.
        try data.write(to: worldMapURL, options: .atomic)
        try projectData.write(to: projectURL, options: .atomic)
        project = candidate
    }

    func worldMapSnapshotForLoading() throws -> StoredWorldMapSnapshot {
        let candidate = try Self.decodeProject(from: projectURL)
        let data = try Data(contentsOf: worldMapURL)
        guard !data.isEmpty else { throw SceneProjectStoreError.emptyWorldMap }

        if candidate.version >= SceneProject.currentVersion {
            guard let expectedChecksum = candidate.worldMapChecksum else {
                throw SceneProjectStoreError.worldMapOutOfDate
            }
            guard expectedChecksum == Self.checksum(for: data) else {
                throw SceneProjectStoreError.worldMapChecksumMismatch
            }
        }
        return StoredWorldMapSnapshot(data: data, project: candidate)
    }

    func activate(_ snapshot: StoredWorldMapSnapshot) {
        project = snapshot.project
        initializationError = nil
    }

    func nextRecordingURL() throws -> URL {
        try fileManager.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let suffix = UUID().uuidString.prefix(6)
        return recordingsDirectory.appendingPathComponent(
            "CineAR-\(formatter.string(from: Date()))-\(suffix).mov"
        )
    }

    private func commit(
        invalidateWorldMap: Bool,
        mutation: (inout SceneProject) throws -> Void
    ) throws {
        if let initializationError { throw initializationError }
        var candidate = project
        try mutation(&candidate)
        candidate.version = SceneProject.currentVersion
        candidate.updatedAt = Date()
        if invalidateWorldMap {
            candidate.worldMapChecksum = nil
        }
        try Self.validate(candidate)
        let data = try Self.encode(candidate)
        try fileManager.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        try data.write(to: projectURL, options: .atomic)
        project = candidate
    }

    private static func encode(_ project: SceneProject) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(project)
    }

    private static func decodeProject(from url: URL) throws -> SceneProject {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let project = try decoder.decode(SceneProject.self, from: Data(contentsOf: url))
        try validate(project)
        return project
    }

    private static func validate(_ project: SceneProject) throws {
        guard project.version > 0, project.version <= SceneProject.currentVersion else {
            throw SceneProjectStoreError.unsupportedProjectVersion(project.version)
        }

        var ids = Set<UUID>()
        for placement in project.placements {
            guard ids.insert(placement.id).inserted else {
                throw SceneProjectStoreError.duplicatePlacement(placement.id)
            }
            guard isValid(placement.transform) else {
                throw SceneProjectStoreError.invalidTransform(placement.id)
            }
            if placement.kind == .custom {
                guard let fileName = placement.assetFileName,
                      fileName == URL(fileURLWithPath: fileName).lastPathComponent,
                      URL(fileURLWithPath: fileName).pathExtension.lowercased() == "usdz" else {
                    throw SceneProjectStoreError.invalidAssetFileName(
                        placement.assetFileName ?? "(eksik)"
                    )
                }
            }
        }
    }

    private static func isValid(_ transform: StoredTransform) -> Bool {
        guard transform.translation.count == 3,
              transform.rotation.count == 4,
              transform.scale.count == 3,
              transform.translation.allSatisfy(\.isFinite),
              transform.rotation.allSatisfy(\.isFinite),
              transform.scale.allSatisfy(\.isFinite),
              transform.scale.allSatisfy({ $0 > 0.0001 }) else { return false }

        let rotationMagnitudeSquared = transform.rotation.reduce(Float.zero) {
            $0 + ($1 * $1)
        }
        return rotationMagnitudeSquared > 0.000001
    }

    private static func checksum(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
