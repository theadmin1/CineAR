import ARKit
import CryptoKit
import Foundation
import RealityKit
import simd

enum FilmLookID: String, CaseIterable, Codable, Identifiable, Sendable {
    case natural
    case cinema
    case tealOrange
    case noir
    case thriller
    case dream

    var id: String { rawValue }

    var title: String {
        switch self {
        case .natural: "Doğal"
        case .cinema: "Sinema"
        case .tealOrange: "Teal & Orange"
        case .noir: "Noir"
        case .thriller: "Gerilim"
        case .dream: "Rüya"
        }
    }

    var symbol: String {
        switch self {
        case .natural: "camera.filters"
        case .cinema: "film.fill"
        case .tealOrange: "circle.lefthalf.filled"
        case .noir: "circle.righthalf.filled"
        case .thriller: "moon.stars.fill"
        case .dream: "sparkles"
        }
    }

    var saturation: Double {
        switch self {
        case .natural: 1
        case .cinema: 0.88
        case .tealOrange: 1.18
        case .noir: 0
        case .thriller: 0.62
        case .dream: 0.78
        }
    }

    var contrast: Double {
        switch self {
        case .natural: 1
        case .cinema: 1.14
        case .tealOrange: 1.16
        case .noir: 1.28
        case .thriller: 1.24
        case .dream: 0.88
        }
    }

    var brightness: Double {
        switch self {
        case .natural: 0
        case .cinema: -0.015
        case .tealOrange: -0.01
        case .noir: -0.035
        case .thriller: -0.055
        case .dream: 0.035
        }
    }

    var hueDegrees: Double {
        switch self {
        case .natural, .cinema, .noir: 0
        case .tealOrange: -6
        case .thriller: -12
        case .dream: 8
        }
    }

    var tintRGBA: (red: Double, green: Double, blue: Double, alpha: Double) {
        switch self {
        case .natural: (0, 0, 0, 0)
        case .cinema: (0.08, 0.18, 0.28, 0.10)
        case .tealOrange: (0.04, 0.28, 0.30, 0.13)
        case .noir: (0.08, 0.09, 0.12, 0.08)
        case .thriller: (0.04, 0.16, 0.10, 0.16)
        case .dream: (0.40, 0.24, 0.48, 0.11)
        }
    }

    var vignetteOpacity: Double {
        switch self {
        case .natural: 0
        case .cinema: 0.34
        case .tealOrange: 0.25
        case .noir: 0.48
        case .thriller: 0.52
        case .dream: 0.18
        }
    }
}

struct SceneProject: Codable {
    static let currentVersion = 7

    var version = currentVersion
    var name = "Ana Set"
    var createdAt = Date()
    var updatedAt = Date()
    var placements: [PlacementRecord] = []
    var worldMapChecksum: String?
    // Metric levels in the matching ARWorldMap coordinate space. Optional fields
    // keep scene files from versions 1-4 decodable without a separate JSON schema.
    var calibratedFloorY: Float?
    var calibratedCeilingY: Float?
    // Version-6 cinematic settings are optional so all earlier scene.json files
    // decode without a custom decoder. Missing values mean natural/100 percent.
    var filmLook: FilmLookID?
    var contactShadowStrength: Float?
    // Version-7 manual relocalization data. The reference is a repeatable point on
    // a permanent wall; roomAlignment maps immutable RoomPlan coordinates into the
    // corrected ARWorldMap coordinate space.
    var alignmentReference: StoredTransform?
    var roomAlignment: StoredTransform?
}

struct PlacementRecord: Codable, Identifiable {
    let id: UUID
    let kind: PropKind
    var assetFileName: String?
    var transform: StoredTransform
    var lightSettings: VirtualLightSettings? = nil
}

struct VirtualLightSettings: Codable, Equatable {
    static let defaultFixture = VirtualLightSettings(
        isEnabled: true,
        // Strong enough to remain visibly distinct from RealityKit's automatic
        // environment lighting while still leaving headroom for art direction.
        intensityLumens: 6_000,
        temperatureKelvin: 4_200,
        coneAngleDegrees: 18,
        yawDegrees: 0,
        tiltDegrees: 0,
        beamSoftness: 0.34
    )

    var isEnabled: Bool
    var intensityLumens: Float
    var temperatureKelvin: Float
    var coneAngleDegrees: Float
    // Optional for forward compatibility with version-3 scenes created before
    // steerable fixtures were introduced.
    var yawDegrees: Float?
    var tiltDegrees: Float?
    // Version-4 projector data is optional so scenes saved by earlier releases
    // continue to decode without migration failures. The target is stored in the
    // restored AR world coordinate system and therefore survives world-map reloads.
    var beamSoftness: Float?
    var targetPosition: [Float]?
    var targetNormal: [Float]?

    init(
        isEnabled: Bool,
        intensityLumens: Float,
        temperatureKelvin: Float,
        coneAngleDegrees: Float,
        yawDegrees: Float? = nil,
        tiltDegrees: Float? = nil,
        beamSoftness: Float? = nil,
        targetPosition: [Float]? = nil,
        targetNormal: [Float]? = nil
    ) {
        self.isEnabled = isEnabled
        self.intensityLumens = intensityLumens
        self.temperatureKelvin = temperatureKelvin
        self.coneAngleDegrees = coneAngleDegrees
        self.yawDegrees = yawDegrees
        self.tiltDegrees = tiltDegrees
        self.beamSoftness = beamSoftness
        self.targetPosition = targetPosition
        self.targetNormal = targetNormal
    }

    var effectiveYawDegrees: Float { yawDegrees ?? 0 }
    var effectiveTiltDegrees: Float { tiltDegrees ?? 0 }
    var effectiveBeamSoftness: Float { beamSoftness ?? 0.34 }

    var projectorTarget: SIMD3<Float>? {
        guard let targetPosition,
              targetPosition.count == 3,
              targetPosition.allSatisfy(\.isFinite) else { return nil }
        return SIMD3(targetPosition[0], targetPosition[1], targetPosition[2])
    }

    var projectorTargetNormal: SIMD3<Float>? {
        guard let targetNormal,
              targetNormal.count == 3,
              targetNormal.allSatisfy(\.isFinite) else { return nil }
        let normal = SIMD3(targetNormal[0], targetNormal[1], targetNormal[2])
        guard simd_length_squared(normal) > 0.000_001 else { return nil }
        return simd_normalize(normal)
    }

    var isValid: Bool {
        let yawIsValid = yawDegrees.map { $0.isFinite && (-180...180).contains($0) } ?? true
        let tiltIsValid = tiltDegrees.map { $0.isFinite && (-75...75).contains($0) } ?? true
        let softnessIsValid = beamSoftness.map { $0.isFinite && (0...1).contains($0) } ?? true
        let targetIsValid = targetPosition.map {
            $0.count == 3 && $0.allSatisfy(\.isFinite)
        } ?? true
        let targetNormalIsValid = targetNormal.map {
            guard $0.count == 3, $0.allSatisfy(\.isFinite) else { return false }
            return simd_length_squared(SIMD3($0[0], $0[1], $0[2])) > 0.000_001
        } ?? true
        return intensityLumens.isFinite && (0...12_000).contains(intensityLumens)
            && temperatureKelvin.isFinite && (2_000...6_500).contains(temperatureKelvin)
            && coneAngleDegrees.isFinite && (8...120).contains(coneAngleDegrees)
            && yawIsValid
            && tiltIsValid
            && softnessIsValid
            && targetIsValid
            && targetNormalIsValid
    }
}

struct StoredWorldMapSnapshot {
    let data: Data
    let project: SceneProject
}

struct RecoveredWorldMapSnapshot {
    let snapshot: StoredWorldMapSnapshot
    let discardedPlacementCount: Int
    let discardedAnchorCount: Int
}

struct SavedPlaceSummary: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
    var objectCount: Int
    var hasRoomScan: Bool
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
    case invalidLightSettings(UUID)
    case invalidVisualStyle
    case invalidSpatialCalibration
    case invalidAlignmentReference
    case worldMapOutOfDate
    case worldMapChecksumMismatch
    case emptyWorldMap
    case savedPlaceNotFound(UUID)
    case invalidSavedPlace(UUID)

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
        case .invalidLightSettings(let id):
            "\(id.uuidString) kimlikli ışık ayarları geçersiz"
        case .invalidVisualStyle:
            "Film filtresi veya gölge gücü geçersiz"
        case .invalidSpatialCalibration:
            "Zemin/tavan kalibrasyonu geçersiz veya oda yüksekliği gerçekçi değil"
        case .invalidAlignmentReference:
            "Mekân hizalama referansı geçersiz"
        case .worldMapOutOfDate:
            "Sahne son harita kaydından sonra değişmiş; önce yeniden Kaydet'e dokunun"
        case .worldMapChecksumMismatch:
            "worldmap ve scene.json aynı kayıt sürümüne ait değil"
        case .emptyWorldMap:
            "Dünya haritası dosyası boş"
        case .savedPlaceNotFound(let id):
            "Kayıtlı mekân bulunamadı: \(id.uuidString)"
        case .invalidSavedPlace:
            "Kayıtlı mekân dosyaları eksik veya birbiriyle eşleşmiyor"
        }
    }
}

final class SceneProjectStore {
    private let fileManager = FileManager.default

    private(set) var project: SceneProject
    private(set) var initializationError: Error? = nil
    private(set) var initializationNotice: String? = nil

    init() {
        project = SceneProject()
        do {
            try fileManager.createDirectory(
                at: projectDirectory,
                withIntermediateDirectories: true
            )
            try fileManager.createDirectory(
                at: savedPlacesDirectory,
                withIntermediateDirectories: true
            )
            if fileManager.fileExists(atPath: projectURL.path) {
                project = try Self.decodeProject(from: projectURL)
            }
        } catch {
            let decodingError = error
            do {
                let recoveredCount = try rebuildCorruptProjectFromWorldMap()
                initializationNotice = "Bozuk scene.json yedeklendi; "
                    + "dünya haritasından \(recoveredCount) nesne kurtarıldı"
            } catch {
                initializationError = decodingError
            }
        }
    }

    var projectDirectory: URL {
        projectsRootDirectory
            .appendingPathComponent("MainSet", isDirectory: true)
    }

    var projectsRootDirectory: URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("CineARProjects", isDirectory: true)
    }

    var savedPlacesDirectory: URL {
        projectsRootDirectory.appendingPathComponent("SavedPlaces", isDirectory: true)
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

    var savedPlaces: [SavedPlaceSummary] {
        let directories = (try? fileManager.contentsOfDirectory(
            at: savedPlacesDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return directories.compactMap { directory in
            guard ((try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false)
            else { return nil }
            return try? Self.decodeSavedPlaceManifest(
                from: directory.appendingPathComponent("place.json")
            )
        }.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.name < rhs.name }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    @discardableResult
    func archiveCurrentProject(preferredName: String? = nil) throws -> SavedPlaceSummary {
        let snapshot = try worldMapSnapshotForLoading()
        let identifier = UUID()
        let stagingURL = savedPlacesDirectory.appendingPathComponent(
            ".staging-\(identifier.uuidString)",
            isDirectory: true
        )
        let destinationURL = savedPlaceDirectory(id: identifier)
        try fileManager.createDirectory(at: savedPlacesDirectory, withIntermediateDirectories: true)
        removeIfPresent(stagingURL)
        try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: true)

        let now = Date()
        let suppliedName = preferredName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = SavedPlaceSummary(
            id: identifier,
            name: suppliedName.flatMap { $0.isEmpty ? nil : $0 } ?? Self.defaultSavedPlaceName(now),
            createdAt: now,
            updatedAt: now,
            objectCount: snapshot.project.placements.count,
            hasRoomScan: fileManager.fileExists(atPath: roomDataURL.path)
        )

        do {
            try Self.encode(snapshot.project).write(
                to: stagingURL.appendingPathComponent("scene.json"),
                options: .atomic
            )
            try snapshot.data.write(
                to: stagingURL.appendingPathComponent("worldmap.arexperience"),
                options: .atomic
            )
            if fileManager.fileExists(atPath: roomDataURL.path) {
                try fileManager.copyItem(
                    at: roomDataURL,
                    to: stagingURL.appendingPathComponent("room.json")
                )
            }
            if fileManager.fileExists(atPath: assetsDirectory.path) {
                try fileManager.copyItem(
                    at: assetsDirectory,
                    to: stagingURL.appendingPathComponent("Assets", isDirectory: true)
                )
            }
            try Self.encodeSavedPlaceManifest(summary).write(
                to: stagingURL.appendingPathComponent("place.json"),
                options: .atomic
            )
            try fileManager.moveItem(at: stagingURL, to: destinationURL)
            return summary
        } catch {
            removeIfPresent(stagingURL)
            throw error
        }
    }

    /// Validates a saved scene before replacing the active working set. The current
    /// set is backed up for the duration of the transaction and restored on failure.
    func installSavedPlace(id: UUID) throws -> StoredWorldMapSnapshot {
        let sourceDirectory = savedPlaceDirectory(id: id)
        guard fileManager.fileExists(atPath: sourceDirectory.path) else {
            throw SceneProjectStoreError.savedPlaceNotFound(id)
        }
        let manifest = try Self.decodeSavedPlaceManifest(
            from: sourceDirectory.appendingPathComponent("place.json")
        )
        guard manifest.id == id else { throw SceneProjectStoreError.invalidSavedPlace(id) }

        let candidate = try Self.decodeProject(
            from: sourceDirectory.appendingPathComponent("scene.json")
        )
        let worldMapData = try Data(
            contentsOf: sourceDirectory.appendingPathComponent("worldmap.arexperience")
        )
        guard !worldMapData.isEmpty,
              candidate.worldMapChecksum == Self.checksum(for: worldMapData) else {
            throw SceneProjectStoreError.invalidSavedPlace(id)
        }
        guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: ARWorldMap.self,
            from: worldMapData
        ) else {
            throw SceneProjectStoreError.invalidSavedPlace(id)
        }
        let placementKinds = Dictionary(uniqueKeysWithValues: candidate.placements.map {
            ($0.id, $0.kind)
        })
        let anchorDescriptors = worldMap.anchors.compactMap {
            PropKind.descriptor(from: $0.name)
        }
        var anchorKinds: [UUID: PropKind] = [:]
        for descriptor in anchorDescriptors {
            guard anchorKinds.updateValue(descriptor.kind, forKey: descriptor.id) == nil else {
                throw SceneProjectStoreError.invalidSavedPlace(id)
            }
        }
        guard anchorKinds == placementKinds else {
            throw SceneProjectStoreError.invalidSavedPlace(id)
        }
        for placement in candidate.placements where placement.kind == .custom {
            guard let fileName = placement.assetFileName,
                  fileManager.fileExists(atPath: sourceDirectory
                    .appendingPathComponent("Assets", isDirectory: true)
                    .appendingPathComponent(fileName).path) else {
                throw SceneProjectStoreError.invalidSavedPlace(id)
            }
        }

        let backupDirectory = projectsRootDirectory.appendingPathComponent(
            ".active-backup-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        let managedNames = ["scene.json", "worldmap.arexperience", "room.json", "Assets"]
        do {
            for name in managedNames {
                let activeURL = projectDirectory.appendingPathComponent(name)
                if fileManager.fileExists(atPath: activeURL.path) {
                    try fileManager.moveItem(
                        at: activeURL,
                        to: backupDirectory.appendingPathComponent(name)
                    )
                }
            }
            for name in managedNames {
                let archivedURL = sourceDirectory.appendingPathComponent(name)
                guard fileManager.fileExists(atPath: archivedURL.path) else { continue }
                try fileManager.copyItem(
                    at: archivedURL,
                    to: projectDirectory.appendingPathComponent(name)
                )
            }
            project = candidate
            initializationError = nil
            removeIfPresent(backupDirectory)
            return StoredWorldMapSnapshot(data: worldMapData, project: candidate)
        } catch {
            for name in managedNames {
                removeIfPresent(projectDirectory.appendingPathComponent(name))
                let backupURL = backupDirectory.appendingPathComponent(name)
                if fileManager.fileExists(atPath: backupURL.path) {
                    try? fileManager.moveItem(
                        at: backupURL,
                        to: projectDirectory.appendingPathComponent(name)
                    )
                }
            }
            removeIfPresent(backupDirectory)
            throw error
        }
    }

    func deleteSavedPlace(id: UUID) throws {
        let directory = savedPlaceDirectory(id: id)
        guard fileManager.fileExists(atPath: directory.path) else {
            throw SceneProjectStoreError.savedPlaceNotFound(id)
        }
        try fileManager.removeItem(at: directory)
    }

    private func savedPlaceDirectory(id: UUID) -> URL {
        savedPlacesDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    private func removeIfPresent(_ url: URL) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.removeItem(at: url)
    }

    /// The shared ARSession keeps the same coordinate space while RoomPlan scans.
    /// If RoomPlan's transition temporarily omits manual anchors from the live frame,
    /// their last committed world transforms remain valid reconciliation candidates.
    func storedManagedAnchors() -> [ARAnchor] {
        do {
            let data = try Data(contentsOf: worldMapURL)
            guard !data.isEmpty,
                  let worldMap = try NSKeyedUnarchiver.unarchivedObject(
                      ofClass: ARWorldMap.self,
                      from: data
                  ) else { return [] }
            return worldMap.anchors.filter {
                $0.name?.hasPrefix("cinear.prop.") == true
            }
        } catch {
            return []
        }
    }

    private func rebuildCorruptProjectFromWorldMap() throws -> Int {
        let identifier = UUID().uuidString
        let backupURL = projectDirectory.appendingPathComponent(
            "scene-corrupt-\(identifier).json"
        )
        if fileManager.fileExists(atPath: projectURL.path) {
            try fileManager.copyItem(at: projectURL, to: backupURL)
        }

        var recoveredPlacements: [PlacementRecord] = []
        var seenIDs = Set<UUID>()
        if let data = try? Data(contentsOf: worldMapURL),
           !data.isEmpty,
           let worldMap = try? NSKeyedUnarchiver.unarchivedObject(
               ofClass: ARWorldMap.self,
               from: data
           ) {
            for anchor in worldMap.anchors {
                guard let descriptor = PropKind.descriptor(from: anchor.name),
                      descriptor.kind != .custom,
                      seenIDs.insert(descriptor.id).inserted else { continue }
                recoveredPlacements.append(
                    PlacementRecord(
                        id: descriptor.id,
                        kind: descriptor.kind,
                        assetFileName: nil,
                        transform: Self.recoveredDefaultTransform(for: descriptor.kind),
                        lightSettings: descriptor.kind.emitsVirtualLight
                            ? VirtualLightSettings.defaultFixture
                            : nil
                    )
                )
            }
        }

        var recoveredProject = SceneProject()
        recoveredProject.placements = recoveredPlacements
        // Force one synchronized world-map save. The old map is still available as
        // an anchor source, but its previous JSON checksum can no longer be trusted.
        recoveredProject.worldMapChecksum = nil
        try Self.validate(recoveredProject)
        let data = try Self.encode(recoveredProject)
        try data.write(to: projectURL, options: .atomic)
        project = recoveredProject
        initializationError = nil
        return recoveredPlacements.count
    }

    private static func recoveredDefaultTransform(for _: PropKind) -> StoredTransform {
        return StoredTransform(
            Transform(
                scale: [1, 1, 1],
                rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
                translation: .zero
            )
        )
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

    func updateLightSettings(id: UUID, settings: VirtualLightSettings) throws {
        try commit(invalidateWorldMap: false) { candidate in
            guard let index = candidate.placements.firstIndex(where: { $0.id == id }) else {
                throw SceneProjectStoreError.missingPlacement(id)
            }
            guard candidate.placements[index].kind.emitsVirtualLight, settings.isValid else {
                throw SceneProjectStoreError.invalidLightSettings(id)
            }
            candidate.placements[index].lightSettings = settings
        }
    }

    func updateVisualStyle(
        filmLook: FilmLookID,
        contactShadowStrength: Float
    ) throws {
        try commit(invalidateWorldMap: false) { candidate in
            guard contactShadowStrength.isFinite,
                  (0...2).contains(contactShadowStrength) else {
                throw SceneProjectStoreError.invalidVisualStyle
            }
            candidate.filmLook = filmLook
            candidate.contactShadowStrength = contactShadowStrength
        }
    }

    func setCalibratedFloorY(_ floorY: Float) throws {
        try commit(invalidateWorldMap: true) { candidate in
            guard floorY.isFinite else {
                throw SceneProjectStoreError.invalidSpatialCalibration
            }
            candidate.calibratedFloorY = floorY
            if let ceilingY = candidate.calibratedCeilingY,
               !(1.50...6.50).contains(ceilingY - floorY) {
                candidate.calibratedCeilingY = nil
            }
        }
    }

    func setCalibratedCeilingY(_ ceilingY: Float) throws {
        try commit(invalidateWorldMap: true) { candidate in
            guard ceilingY.isFinite else {
                throw SceneProjectStoreError.invalidSpatialCalibration
            }
            if let floorY = candidate.calibratedFloorY,
               !(1.50...6.50).contains(ceilingY - floorY) {
                throw SceneProjectStoreError.invalidSpatialCalibration
            }
            candidate.calibratedCeilingY = ceilingY
        }
    }

    /// RoomPlan and the active ARWorldMap already share the same world coordinate
    /// space. Correcting only the measured floor/ceiling metadata must therefore keep
    /// the map valid; invalidating it here would make stable anchors relocalize again.
    func reconcileSpatialCalibration(floorY: Float?, ceilingY: Float?) throws {
        try commit(invalidateWorldMap: false) { candidate in
            guard floorY.map({ $0.isFinite }) ?? true,
                  ceilingY.map({ $0.isFinite }) ?? true else {
                throw SceneProjectStoreError.invalidSpatialCalibration
            }
            if let floorY, let ceilingY,
               !(1.50...6.50).contains(ceilingY - floorY) {
                throw SceneProjectStoreError.invalidSpatialCalibration
            }
            candidate.calibratedFloorY = floorY
            candidate.calibratedCeilingY = ceilingY
        }
    }

    func setAlignmentReference(_ reference: StoredTransform) throws {
        try commit(invalidateWorldMap: false) { candidate in
            guard Self.isValid(reference) else {
                throw SceneProjectStoreError.invalidAlignmentReference
            }
            candidate.alignmentReference = reference
        }
    }

    /// Applies a rigid, gravity-preserving correction to RoomPlan metadata and any
    /// world-space light targets. ARAnchor transforms are recreated by the controller
    /// and the following automatic world-map save makes the corrected scene durable.
    func applyAlignmentCorrection(
        _ correction: simd_float4x4,
        newReference: StoredTransform
    ) throws {
        let correctionTransform = StoredTransform(Transform(matrix: correction))
        let values = [
            correction.columns.0.x, correction.columns.0.y,
            correction.columns.0.z, correction.columns.0.w,
            correction.columns.1.x, correction.columns.1.y,
            correction.columns.1.z, correction.columns.1.w,
            correction.columns.2.x, correction.columns.2.y,
            correction.columns.2.z, correction.columns.2.w,
            correction.columns.3.x, correction.columns.3.y,
            correction.columns.3.z, correction.columns.3.w,
        ]
        let translation = SIMD3<Float>(
            correction.columns.3.x,
            correction.columns.3.y,
            correction.columns.3.z
        )
        let up = SIMD3<Float>(
            correction.columns.1.x,
            correction.columns.1.y,
            correction.columns.1.z
        )
        guard values.allSatisfy(\.isFinite),
              simd_length(translation) <= 5,
              simd_length_squared(up) > 0.000_001,
              simd_dot(simd_normalize(up), SIMD3<Float>(0, 1, 0)) >= 0.985,
              Self.isValid(correctionTransform),
              Self.isValid(newReference) else {
            throw SceneProjectStoreError.invalidAlignmentReference
        }

        try commit(invalidateWorldMap: true) { candidate in
            let existing = candidate.roomAlignment?.realityKitTransform.matrix
                ?? matrix_identity_float4x4
            candidate.roomAlignment = StoredTransform(
                Transform(matrix: correction * existing)
            )
            candidate.alignmentReference = newReference

            if let floorY = candidate.calibratedFloorY {
                let point = correction * SIMD4<Float>(0, floorY, 0, 1)
                candidate.calibratedFloorY = point.y
            }
            if let ceilingY = candidate.calibratedCeilingY {
                let point = correction * SIMD4<Float>(0, ceilingY, 0, 1)
                candidate.calibratedCeilingY = point.y
            }
            for index in candidate.placements.indices {
                guard var light = candidate.placements[index].lightSettings,
                      let target = light.projectorTarget else { continue }
                let corrected = correction * SIMD4<Float>(target, 1)
                light.targetPosition = [corrected.x, corrected.y, corrected.z]
                if let normal = light.projectorTargetNormal {
                    let correctedNormal = correction * SIMD4<Float>(normal, 0)
                    let vector = SIMD3<Float>(
                        correctedNormal.x,
                        correctedNormal.y,
                        correctedNormal.z
                    )
                    if simd_length_squared(vector) > 0.000_001 {
                        let normalized = simd_normalize(vector)
                        light.targetNormal = [normalized.x, normalized.y, normalized.z]
                    }
                }
                candidate.placements[index].lightSettings = light
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
        try commit(invalidateWorldMap: true) { candidate in
            candidate.alignmentReference = nil
            candidate.roomAlignment = nil
        }
    }

    @discardableResult
    func saveWorldMapData(
        _ data: Data,
        retainingPlacementIDs: Set<UUID>? = nil
    ) throws -> Int {
        if let initializationError { throw initializationError }
        guard !data.isEmpty else { throw SceneProjectStoreError.emptyWorldMap }
        try fileManager.createDirectory(at: projectDirectory, withIntermediateDirectories: true)

        var candidate = project
        let originalPlacementCount = candidate.placements.count
        if let retainingPlacementIDs {
            candidate.placements.removeAll { !retainingPlacementIDs.contains($0.id) }
        }
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
        initializationError = nil
        return originalPlacementCount - candidate.placements.count
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

    /// Repairs a scene/map pair left between the JSON and world-map writes.
    /// A placement without a matching world anchor cannot be positioned safely,
    /// so only that orphan is discarded; every matching placement is preserved.
    func recoverWorldMapSnapshot() throws -> RecoveredWorldMapSnapshot {
        var candidate = try Self.decodeProject(from: projectURL)
        let storedData = try Data(contentsOf: worldMapURL)
        guard !storedData.isEmpty,
              let worldMap = try NSKeyedUnarchiver.unarchivedObject(
                  ofClass: ARWorldMap.self,
                  from: storedData
              ) else {
            throw SceneProjectStoreError.emptyWorldMap
        }

        let placementKinds = Dictionary(uniqueKeysWithValues: candidate.placements.map {
            ($0.id, $0.kind)
        })
        var matchingAnchors: [UUID: ARAnchor] = [:]
        var managedAnchorCount = 0
        for anchor in worldMap.anchors {
            guard anchor.name?.hasPrefix("cinear.prop.") == true else { continue }
            managedAnchorCount += 1
            guard let descriptor = PropKind.descriptor(from: anchor.name) else { continue }
            guard placementKinds[descriptor.id] == descriptor.kind,
                  matchingAnchors[descriptor.id] == nil else { continue }
            matchingAnchors[descriptor.id] = anchor
        }

        let originalPlacementCount = candidate.placements.count
        candidate.placements.removeAll { matchingAnchors[$0.id] == nil }
        let survivingIDs = Set(candidate.placements.map(\.id))
        let unmanagedAnchors = worldMap.anchors.filter {
            $0.name?.hasPrefix("cinear.prop.") != true
        }
        let managedAnchors = candidate.placements.compactMap { matchingAnchors[$0.id] }
        worldMap.anchors = unmanagedAnchors + managedAnchors

        // Defensive check: all managed anchors left in the repaired map must belong
        // to the placements that survived the intersection above.
        guard managedAnchors.allSatisfy({ anchor in
            guard let descriptor = PropKind.descriptor(from: anchor.name) else { return false }
            return survivingIDs.contains(descriptor.id)
        }) else {
            throw SceneProjectStoreError.worldMapChecksumMismatch
        }

        let repairedData = try NSKeyedArchiver.archivedData(
            withRootObject: worldMap,
            requiringSecureCoding: true
        )
        candidate.version = SceneProject.currentVersion
        candidate.updatedAt = Date()
        candidate.worldMapChecksum = Self.checksum(for: repairedData)
        try Self.validate(candidate)
        let projectData = try Self.encode(candidate)
        try repairedData.write(to: worldMapURL, options: .atomic)
        try projectData.write(to: projectURL, options: .atomic)
        project = candidate
        initializationError = nil

        return RecoveredWorldMapSnapshot(
            snapshot: StoredWorldMapSnapshot(data: repairedData, project: candidate),
            discardedPlacementCount: originalPlacementCount - candidate.placements.count,
            discardedAnchorCount: max(0, managedAnchorCount - managedAnchors.count)
        )
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

    private static func encodeSavedPlaceManifest(_ summary: SavedPlaceSummary) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(summary)
    }

    private static func decodeSavedPlaceManifest(from url: URL) throws -> SavedPlaceSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SavedPlaceSummary.self, from: Data(contentsOf: url))
    }

    private static func defaultSavedPlaceName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMM yyyy HH:mm"
        return "Mekân \(formatter.string(from: date))"
    }

    private static func decodeProject(from url: URL) throws -> SceneProject {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var project = try decoder.decode(SceneProject.self, from: Data(contentsOf: url))
        if project.version < 4 {
            // Earlier renderers stored a half-height offset in the placement entity.
            // Version 4 uses a contact-plane pivot, so retaining that legacy offset
            // would make every restored object float above its anchor.
            for index in project.placements.indices {
                guard project.placements[index].transform.translation.count == 3 else { continue }
                project.placements[index].transform.translation = [0, 0, 0]
                if var light = project.placements[index].lightSettings {
                    if abs(light.coneAngleDegrees - 72) < 0.01 {
                        light.coneAngleDegrees = 18
                    }
                    if light.beamSoftness == nil { light.beamSoftness = 0.34 }
                    project.placements[index].lightSettings = light
                }
            }
            project.version = 4
            project.updatedAt = Date()
        }
        if project.version < 5 {
            project.version = 5
            project.updatedAt = Date()
        }
        if project.version < 6 {
            project.filmLook = project.filmLook ?? .natural
            project.contactShadowStrength = project.contactShadowStrength ?? 1
            project.version = 6
            project.updatedAt = Date()
        }
        if project.version < 7 {
            project.version = 7
            project.updatedAt = Date()
        }
        try validate(project)
        return project
    }

    private static func validate(_ project: SceneProject) throws {
        guard project.version > 0, project.version <= SceneProject.currentVersion else {
            throw SceneProjectStoreError.unsupportedProjectVersion(project.version)
        }

        guard project.calibratedFloorY.map({ $0.isFinite }) ?? true,
              project.calibratedCeilingY.map({ $0.isFinite }) ?? true else {
            throw SceneProjectStoreError.invalidSpatialCalibration
        }
        if let floorY = project.calibratedFloorY,
           let ceilingY = project.calibratedCeilingY,
           !(1.50...6.50).contains(ceilingY - floorY) {
            throw SceneProjectStoreError.invalidSpatialCalibration
        }
        guard project.contactShadowStrength.map({
            $0.isFinite && (0...2).contains($0)
        }) ?? true else {
            throw SceneProjectStoreError.invalidVisualStyle
        }
        guard project.alignmentReference.map({ isValid($0) }) ?? true,
              project.roomAlignment.map({ isValid($0) }) ?? true else {
            throw SceneProjectStoreError.invalidAlignmentReference
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
            if let lightSettings = placement.lightSettings {
                guard placement.kind.emitsVirtualLight, lightSettings.isValid else {
                    throw SceneProjectStoreError.invalidLightSettings(placement.id)
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
