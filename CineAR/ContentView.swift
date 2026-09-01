import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var updateChecker: AppUpdateChecker
    @StateObject private var session = ARSessionController()
    @State private var showingRoomScanner = false
    @State private var showingAssetImporter = false
    @State private var showingPropLibrary = false
    @State private var showingAISettings = false
    @State private var showingSceneContents = false
    @State private var showingSavedPlaces = false
    @State private var showingCGIStudio = false
    @State private var roomScanResult: RoomScanResult?
    @State private var controlsExpanded = false
    @State private var sceneObjectPendingDeletion: SceneObjectSummary?
    @State private var savedPlacePendingDeletion: SavedPlaceSummary?
    @State private var newSavedPlaceName = ""

    var body: some View {
        ZStack {
            ARViewContainer(controller: session)
                .ignoresSafeArea()

            if session.isPlacingProp,
               !session.isRecording,
               !session.isRecordingTransitioning {
                placementReticle
            }

            if session.isFloorMeterEnabled,
               !session.isRecording,
               !session.isRecordingTransitioning {
                floorMeterReticle
            }

            if session.isRecording || session.isRecordingTransitioning {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture(count: 2) {
                        if session.isRecording {
                            session.stopRecording()
                        }
                    }
                    .accessibilityLabel("Kaydı bitirmek için iki kez dokun")
            } else {
                VStack(spacing: 12) {
                    statusBar
                    Spacer()
                    if session.isFloorMeterEnabled {
                        floorMeterPanel
                    }
                    if session.isPlacingProp {
                        placementBar
                    } else {
                        if session.selectedLightSettings != nil {
                            lightControls
                        }
                        if controlsExpanded {
                            controls
                        } else {
                            compactControls
                        }
                    }
                }
                .padding()
            }
        }
        .statusBarHidden(session.isRecording || session.isRecordingTransitioning)
        .onChange(of: session.isPlacingProp) { oldValue, newValue in
            if newValue, showingCGIStudio {
                showingCGIStudio = false
            }
            if oldValue, !newValue {
                controlsExpanded = false
            }
        }
        .fullScreenCover(isPresented: $showingRoomScanner, onDismiss: {
            session.resumeAfterRoomScan(result: roomScanResult)
            roomScanResult = nil
        }) {
            RoomScannerScreen(
                exportURL: session.roomModelURL,
                roomJSONURL: session.roomDataURL,
                arSession: session.sharedARSession
            ) { result in
                roomScanResult = result
            }
        }
        .fileImporter(
            isPresented: $showingAssetImporter,
            allowedContentTypes: [UTType(filenameExtension: "usdz") ?? .data]
        ) { result in
            switch result {
            case .success(let url):
                session.importUSDZ(from: url)
            case .failure(let error):
                session.reportAssetImportFailure(error)
            }
        }
        .sheet(isPresented: $showingPropLibrary) {
            propLibrary
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingAISettings) {
            aiSettings
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingSceneContents) {
            sceneContents
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingSavedPlaces) {
            savedPlacesLibrary
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingCGIStudio) {
            liveCGIStudio
                .presentationDetents([.medium, .large])
        }
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(session.trackingColor)
                .frame(width: 10, height: 10)
            Text(session.statusText)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
            Spacer()
        }
        .padding(12)
        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 14))
    }

    private var controls: some View {
        VStack(spacing: 12) {
            roomRealityControls

            Text("Nesne seçildiğinde panel kapanır; yeşil takipte algılanmış zemine dokun")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PropKind.quickCases) { prop in
                        Button {
                            session.selectProp(prop)
                        } label: {
                            VStack(spacing: 4) {
                                Text(prop.symbol).font(.title2)
                                Text(prop.title).font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(session.selectedProp == prop ? Color.white : Color.primary)
                            .frame(width: 70, height: 54)
                            .background(
                                session.selectedProp == prop
                                    ? Color.accentColor.opacity(0.85)
                                    : Color.white.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        }
                    }
                }
            }

            Button {
                showingPropLibrary = true
            } label: {
                Label(
                    "Hazır 3B Nesne Kütüphanesi (\(PropKind.furnitureCases.count) parça)",
                    systemImage: "square.grid.3x3.fill"
                )
                .foregroundStyle(.white)
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
            }

            if !session.importedAssetURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(session.importedAssetURLs, id: \.self) { url in
                            Button {
                                session.selectImportedAsset(url)
                            } label: {
                                Label(
                                    url.deletingPathExtension().lastPathComponent,
                                    systemImage: "cube.transparent"
                                )
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    session.selectedAssetURL == url
                                        ? Color.accentColor.opacity(0.85)
                                        : Color.white.opacity(0.1),
                                    in: Capsule()
                                )
                            }
                        }
                    }
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                utilityButton(session.hasScannedRoom ? "Yeniden Tara" : "Oda Tara", "viewfinder") {
                    beginRoomScan()
                }
                .disabled(!RoomScannerController.isSupported || !session.isARReady)

                utilityButton("USDZ Ekle", "cube.transparent.fill") {
                    showingAssetImporter = true
                }

                utilityButton("Kaydet", "square.and.arrow.down") {
                    session.saveWorldMap()
                }
                utilityButton("Yükle", "arrow.clockwise.icloud") {
                    session.loadWorldMap()
                }
                utilityButton("Sahne Listesi", "list.bullet.rectangle") {
                    showingSceneContents = true
                }
                utilityButton("Mekânlar", "square.stack.3d.up.fill") {
                    showingSavedPlaces = true
                }
                utilityButton("Seçileni Sil", "trash") {
                    session.removeSelectedProp()
                }
                utilityButton("Tümünü Sil", "trash.slash") {
                    session.removeAllProps()
                }
                utilityButton("HEVC Çekim", "record.circle") {
                    session.startRecording()
                }
                utilityButton("AI Derinlik", "cpu.fill") {
                    showingAISettings = true
                    session.testAIServerConnection()
                }
                utilityButton(
                    session.isFloorMeterEnabled ? "Ölçeri Kapat" : "Zemin Ölçer",
                    "ruler.fill"
                ) {
                    session.setFloorMeterEnabled(!session.isFloorMeterEnabled)
                }
                utilityButton("Sahne Işığı", "lightbulb.max.fill") {
                    session.showSceneLightControls()
                }
                utilityButton("Canlı CGI", "wand.and.stars") {
                    showingCGIStudio = true
                }
                utilityButton(
                    updateChecker.isChecking ? "Denetleniyor" : "Güncelleme",
                    updateChecker.isChecking ? "hourglass" : "arrow.down.circle.fill"
                ) {
                    Task {
                        await updateChecker.checkForUpdates(showCurrentStatus: true)
                    }
                }
                .disabled(updateChecker.isChecking)

                if let url = session.lastRecordingURL {
                    ShareLink(item: url) {
                        utilityLabel("Çekimi Paylaş", "square.and.arrow.up")
                    }
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var roomRealityControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Oda Gerçekliği", systemImage: "viewfinder.circle.fill")
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text(session.hasScannedRoom ? "Tarama hazır" : "Tarama gerekli")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(session.hasScannedRoom ? .green : .secondary)
                Button {
                    controlsExpanded = false
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.title3)
                }
                .accessibilityLabel("Kontrolleri küçült")
            }

            HStack(spacing: 8) {
                roomModeButton(
                    title: "Gerçek",
                    icon: "camera.fill",
                    isSelected: !session.isRoomOutlineVisible
                ) {
                    session.showOriginalReality()
                }

                roomModeButton(
                    title: "Beyaz Hatlar",
                    icon: "square.dashed.inset.filled",
                    isSelected: session.isRoomOutlineVisible
                ) {
                    session.showRoomOutline()
                }
                .disabled(!session.hasScannedRoom)
            }

            Text("Tarama sırasında ve Beyaz Hatlar modunda kamera kapanmaz; katı duvar çizilmez")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var aiSettings: some View {
        NavigationStack {
            Form {
                Section("SAM 2 + Depth Anything") {
                    Toggle(
                        "PC destekli AI occlusion",
                        isOn: Binding(
                            get: { session.aiEnhancementEnabled },
                            set: { session.setAIEnhancementEnabled($0) }
                        )
                    )

                    TextField(
                        "PC adresini buraya yaz",
                        text: Binding(
                            get: { session.aiServerAddress },
                            set: { session.setAIServerAddress($0) }
                        )
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                    Text("Etkin adres: \(session.aiServerAddress)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    LabeledContent("Durum") {
                        Text(session.aiEnhancementStatus.title)
                            .foregroundStyle(aiStatusColor)
                            .multilineTextAlignment(.trailing)
                    }

                    Button("PC bağlantısını test et") {
                        session.testAIServerConnection()
                    }
                    .disabled(AIEnhancementClient.serverURL(from: session.aiServerAddress) == nil)

                    Button("iPhone Yerel Ağ ayarını aç") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                }

                Section("Çalışma şekli") {
                    LabeledContent("Uygulama sürümü", value: appVersionText)

                    Text(
                        "iPhone kamera ve LiDAR derinliğini aynı Wi-Fi'daki PC'ye yollar. "
                            + "Depth Anything boşlukları tamamlar; SAM 2 nesne sınırlarını ayırır. "
                            + "Sonuç yalnız sanal nesnelerin gerçek insan ve mobilyaların arkasında "
                            + "doğru kesilmesi için görünmez derinlik ağı olarak kullanılır."
                    )
                    .font(.footnote)

                    Text("PC servisi kapalıysa ARKit'in yerel LiDAR occlusion sistemi çalışmaya devam eder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(
                        "PC terminalinde gösterilen http://...:8765 adresini eksiksiz gir. "
                            + "iPhone Safari'de aynı adresin sonuna /health ekleyerek aç. "
                            + "Safari'de açılmıyorsa iki cihaz aynı Wi-Fi'da değildir; "
                            + "Safari'de açılıp uygulamada açılmıyorsa CineAR için Yerel Ağ iznini etkinleştir."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("AI Derinlik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") { showingAISettings = false }
                }
            }
        }
    }

    private var aiStatusColor: Color {
        switch session.aiEnhancementStatus {
        case .active: .green
        case .failed: .red
        case .waiting, .waitingForDepth, .stabilizing: .orange
        case .disabled: .secondary
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")
            as? String ?? "?"
        return "\(version) (\(build))"
    }

    private func roomModeButton(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    isSelected ? Color.accentColor.opacity(0.88) : Color.white.opacity(0.10),
                    in: Capsule()
                )
        }
    }

    private var compactControls: some View {
        VStack(spacing: 8) {
            Button {
                beginRoomScan()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "viewfinder.circle.fill")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.hasScannedRoom ? "Odayı Yeniden Tara" : "Odayı Tara")
                            .font(.subheadline.weight(.bold))
                        Text(roomScanAvailabilityText)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.9), in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .disabled(!RoomScannerController.isSupported || !session.isARReady)
            .opacity(RoomScannerController.isSupported ? (session.isARReady ? 1 : 0.7) : 0.55)
            .accessibilityHint(roomScanAvailabilityText)

            HStack(spacing: 8) {
                compactButton("Zemin", "ruler.fill") {
                    session.setFloorMeterEnabled(!session.isFloorMeterEnabled)
                }
                compactButton("Kontroller", "slider.horizontal.3") {
                    controlsExpanded = true
                }
                compactButton("Nesneler", "shippingbox.fill") {
                    showingPropLibrary = true
                }
                compactButton("Sahne", "list.bullet.rectangle") {
                    showingSceneContents = true
                }
                compactButton("Mekânlar", "square.stack.3d.up.fill") {
                    showingSavedPlaces = true
                }
            }
        }
        .disabled(session.isRecordingTransitioning)
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var roomScanAvailabilityText: String {
        if !RoomScannerController.isSupported {
            return "Bu cihaz RoomPlan taramasını desteklemiyor"
        }
        if !session.isARReady {
            return "Kamera ve AR takibi hazırlanıyor…"
        }
        return session.hasScannedRoom ? "Yeni bir oda taraması başlat" : "Duvar, zemin ve büyük nesneleri tara"
    }

    private func beginRoomScan() {
        guard RoomScannerController.isSupported, session.isARReady else { return }
        session.pauseForRoomScan()
        showingRoomScanner = true
    }

    private var lightControls: some View {
        VStack(spacing: 9) {
            HStack {
                Label("Sanal Işık", systemImage: "lightbulb.max.fill")
                    .font(.subheadline.weight(.bold))
                Spacer()
                Toggle(
                    "",
                    isOn: Binding(
                        get: { session.selectedLightSettings?.isEnabled ?? false },
                        set: { session.setSelectedLightEnabled($0) }
                    )
                )
                .labelsHidden()
            }

            if let settings = session.selectedLightSettings {
                Button {
                    if session.isAimingLight {
                        session.cancelSelectedLightTargeting()
                    } else {
                        session.beginSelectedLightTargeting()
                    }
                } label: {
                    Label(
                        session.isAimingLight ? "Hedef Seçimini İptal Et" : "Projektör Hedefini Seç",
                        systemImage: session.isAimingLight ? "xmark.circle" : "scope"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(session.isAimingLight ? .red : .blue)

                lightSliderRow(
                    title: "Güç",
                    valueText: "\(Int(settings.intensityLumens)) lm",
                    value: Binding(
                        get: { Double(session.selectedLightSettings?.intensityLumens ?? 6_000) },
                        set: { session.setSelectedLightIntensity(Float($0)) }
                    ),
                    range: 0...12_000,
                    step: 100
                )
                lightSliderRow(
                    title: "Sıcaklık",
                    valueText: "\(Int(settings.temperatureKelvin)) K",
                    value: Binding(
                        get: { Double(session.selectedLightSettings?.temperatureKelvin ?? 4_200) },
                        set: { session.setSelectedLightTemperature(Float($0)) }
                    ),
                    range: 2_000...6_500,
                    step: 100
                )
                lightSliderRow(
                    title: "Yatay yön",
                    valueText: "\(Int(settings.effectiveYawDegrees))°",
                    value: Binding(
                        get: { Double(session.selectedLightSettings?.effectiveYawDegrees ?? 0) },
                        set: { session.setSelectedLightYaw(Float($0)) }
                    ),
                    range: -180...180,
                    step: 1
                )
                lightSliderRow(
                    title: "Dikey eğim",
                    valueText: "\(Int(settings.effectiveTiltDegrees))°",
                    value: Binding(
                        get: { Double(session.selectedLightSettings?.effectiveTiltDegrees ?? 0) },
                        set: { session.setSelectedLightTilt(Float($0)) }
                    ),
                    range: -75...75,
                    step: 1
                )
                lightSliderRow(
                    title: "Hüzme genişliği",
                    valueText: "\(Int(settings.coneAngleDegrees))° spot",
                    value: Binding(
                        get: { Double(session.selectedLightSettings?.coneAngleDegrees ?? 18) },
                        set: { session.setSelectedLightConeAngle(Float($0)) }
                    ),
                    range: 8...90,
                    step: 1
                )
                lightSliderRow(
                    title: "Kenar yumuşaklığı",
                    valueText: "%\(Int(settings.effectiveBeamSoftness * 100))",
                    value: Binding(
                        get: { Double(session.selectedLightSettings?.effectiveBeamSoftness ?? 0.34) },
                        set: { session.setSelectedLightSoftness(Float($0)) }
                    ),
                    range: 0...1,
                    step: 0.01
                )
            }

            Text("Spot ışık sanal nesneleri aydınlatır; LiDAR yüzeyindeki yumuşak projektör izi kamera görünümünde hedef noktayı gösterir.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func lightSliderRow(
        title: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(title).font(.caption.weight(.semibold))
                Spacer()
                Text(valueText).font(.caption.monospacedDigit())
            }
            Slider(
                value: value,
                in: range,
                step: step,
                onEditingChanged: { isEditing in
                    if !isEditing { session.persistSelectedLightSettings() }
                }
            )
        }
    }

    private func compactButton(
        _ title: String,
        _ icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.body)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
        }
    }

    private var placementBar: some View {
        HStack(spacing: 12) {
            Text(session.selectedProp.symbol).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(session.selectedProp.title) yerleştir")
                    .font(.subheadline.weight(.bold))
                Text(session.placementSurfaceMessage)
                    .font(.caption2)
                    .foregroundStyle(session.placementSurfaceColor)
            }
            Spacer()
            Button("İptal") { session.cancelPlacement() }
                .buttonStyle(.borderedProminent)
                .tint(.red)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var placementReticle: some View {
        GeometryReader { proxy in
            let point = session.placementReticlePoint
                ?? CGPoint(x: proxy.size.width * 0.5, y: proxy.size.height * 0.5)
            ZStack {
                Circle()
                    .stroke(session.placementSurfaceColor, lineWidth: 3)
                    .frame(width: 46, height: 46)
                Circle()
                    .fill(session.placementSurfaceColor)
                    .frame(width: 7, height: 7)
                Rectangle()
                    .fill(session.placementSurfaceColor)
                    .frame(width: 66, height: 1)
                Rectangle()
                    .fill(session.placementSurfaceColor)
                    .frame(width: 1, height: 66)
            }
            .position(point)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var floorMeterReticle: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                var ruler = Path()
                ruler.move(to: CGPoint(x: center.x - 120, y: center.y))
                ruler.addLine(to: CGPoint(x: center.x + 120, y: center.y))
                ruler.move(to: CGPoint(x: center.x, y: center.y - 120))
                ruler.addLine(to: CGPoint(x: center.x, y: center.y + 120))
                for offset in stride(from: -100, through: 100, by: 20) {
                    let length: CGFloat = offset.isMultiple(of: 100) ? 13 : 7
                    ruler.move(to: CGPoint(x: center.x + CGFloat(offset), y: center.y - length))
                    ruler.addLine(to: CGPoint(x: center.x + CGFloat(offset), y: center.y + length))
                    ruler.move(to: CGPoint(x: center.x - length, y: center.y + CGFloat(offset)))
                    ruler.addLine(to: CGPoint(x: center.x + length, y: center.y + CGFloat(offset)))
                }
                context.stroke(
                    ruler,
                    with: .color(session.floorMeterColor.opacity(0.88)),
                    lineWidth: 1.2
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)),
                    with: .color(session.floorMeterColor)
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var floorMeterPanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("Zemin Ölçer", systemImage: "ruler.fill")
                    .font(.subheadline.weight(.bold))
                Spacer()
                Button("Sıfırı Yenile") { session.resetFloorMeterOrigin() }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                Button {
                    session.setFloorMeterEnabled(false)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .accessibilityLabel("Zemin Ölçeri kapat")
            }

            Text(session.floorMeterStatus)
                .font(.caption)
                .foregroundStyle(session.floorMeterColor)

            if let reading = session.floorMeterReading {
                HStack(spacing: 12) {
                    floorMeterValue("LiDAR", reading.depthMeters, "m")
                    floorMeterValue("Zemin", reading.floorDistanceMeters, "m")
                    floorMeterValue("Kamera", reading.cameraHeightMeters, "m")
                }
                HStack(spacing: 10) {
                    Text(String(format: "X %+.2f", Double(reading.xMeters)))
                    Text("Y +0.00")
                    Text(String(format: "Z %+.2f", Double(reading.zMeters)))
                }
                .font(.caption.monospacedDigit().weight(.semibold))
                Text(
                    "Kot \(String(format: "%+.2f m", Double(reading.floorLevelMeters))) • "
                        + "\(reading.sourceTitle)"
                        + (reading.tiltDegrees.map { String(format: " • eğim %.1f°", Double($0)) } ?? "")
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func floorMeterValue(_ title: String, _ value: Float, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(String(format: "%.2f %@", Double(value), unit))
                .font(.caption.monospacedDigit().weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sceneContents: some View {
        NavigationStack {
            Group {
                if session.sceneObjects.isEmpty {
                    ContentUnavailableView(
                        "Sahne Boş",
                        systemImage: "cube.transparent",
                        description: Text("Eklediğin nesneler ve canlı efektler burada listelenecek.")
                    )
                } else {
                    List {
                        Section("\(session.sceneObjects.count) sahne öğesi") {
                            ForEach(session.sceneObjects) { item in
                                HStack(spacing: 12) {
                                    Button {
                                        session.selectSceneObject(id: item.id)
                                        showingSceneContents = false
                                    } label: {
                                        HStack(spacing: 12) {
                                            Text(item.symbol).font(.title2)
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(item.title)
                                                    .font(.body.weight(.semibold))
                                                Text(item.detail)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            if item.id == session.selectedEntityID {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.green)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    Button(role: .destructive) {
                                        sceneObjectPendingDeletion = item
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("\(item.title) öğesini sil")
                                }
                            }
                        }

                        Section {
                            Button(role: .destructive) {
                                session.removeAllProps()
                            } label: {
                                Label("Sahnedeki Her Şeyi Sil", systemImage: "trash.slash")
                            }
                        } footer: {
                            Text("Silme işlemi taranmış oda kaydını değil, sanal nesne ve efektleri kaldırır.")
                        }
                    }
                }
            }
            .navigationTitle("Sahne İçeriği")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") { showingSceneContents = false }
                }
            }
            .alert(
                "Sahne öğesi silinsin mi?",
                isPresented: Binding(
                    get: { sceneObjectPendingDeletion != nil },
                    set: { if !$0 { sceneObjectPendingDeletion = nil } }
                ),
                presenting: sceneObjectPendingDeletion
            ) { item in
                Button("Sil", role: .destructive) {
                    session.removeSceneObject(id: item.id)
                    sceneObjectPendingDeletion = nil
                }
                Button("Vazgeç", role: .cancel) {
                    sceneObjectPendingDeletion = nil
                }
            } message: { item in
                Text("\(item.title) sahneden ve scene.json kaydından kaldırılacak.")
            }
        }
    }

    private var savedPlacesLibrary: some View {
        NavigationStack {
            List {
                Section("Yeni kayıt") {
                    TextField("Mekân adı (isteğe bağlı)", text: $newSavedPlaceName)
                    Button {
                        session.saveWorldMap(archiveName: newSavedPlaceName)
                        newSavedPlaceName = ""
                    } label: {
                        Label("Aktif Mekânı Kaydet", systemImage: "square.and.arrow.down.fill")
                    }
                    Text("Dünya haritası, tarama, nesneler, ışıklar ve özel USDZ dosyaları birlikte saklanır.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Kayıtlı mekânlar") {
                    if session.savedPlaces.isEmpty {
                        Text("Henüz arşivlenmiş mekân yok.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(session.savedPlaces) { place in
                            HStack(spacing: 12) {
                                Button {
                                    session.loadSavedPlace(id: place.id)
                                    showingSavedPlaces = false
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: place.hasRoomScan
                                            ? "viewfinder.circle.fill"
                                            : "cube.transparent")
                                            .font(.title2)
                                            .foregroundStyle(place.hasRoomScan ? .green : .blue)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(place.name)
                                                .font(.body.weight(.semibold))
                                            Text(
                                                "\(place.objectCount) öğe • "
                                                    + place.updatedAt.formatted(
                                                        date: .abbreviated,
                                                        time: .shortened
                                                    )
                                            )
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .foregroundStyle(.secondary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                Button(role: .destructive) {
                                    savedPlacePendingDeletion = place
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("\(place.name) kaydını sil")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Kayıtlı Mekânlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") { showingSavedPlaces = false }
                }
            }
            .alert(
                "Mekân kaydı silinsin mi?",
                isPresented: Binding(
                    get: { savedPlacePendingDeletion != nil },
                    set: { if !$0 { savedPlacePendingDeletion = nil } }
                ),
                presenting: savedPlacePendingDeletion
            ) { place in
                Button("Sil", role: .destructive) {
                    session.deleteSavedPlace(id: place.id)
                    savedPlacePendingDeletion = nil
                }
                Button("Vazgeç", role: .cancel) {
                    savedPlacePendingDeletion = nil
                }
            } message: { place in
                Text("\(place.name) arşivi kalıcı olarak silinecek; aktif sahne etkilenmeyecek.")
            }
        }
    }

    private var liveCGIStudio: some View {
        NavigationStack {
            Form {
                Section("Gerçek zamanlı efektler") {
                    Button {
                        session.selectProp(.bloodWaterfall)
                        showingCGIStudio = false
                    } label: {
                        Label("Kan Şelalesi Yerleştir", systemImage: "drop.triangle.fill")
                    }
                    Text("Başlangıç noktasını taranmış duvarda seç; akış dünya koordinatına sabitlenir ve sahne kaydıyla geri gelir.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle(
                        "Avuçta Canlı Elma",
                        isOn: Binding(
                            get: { session.isLiveAppleEnabled },
                            set: { session.setLiveAppleEnabled($0) }
                        )
                    )
                    Text("Vision el eklemlerini, kişi derinliği/LiDAR ise avuç mesafesini ölçer. Elma geçici canlı efekttir; sahneye sabitlenmez.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Türkçe sesli komut") {
                    Button {
                        session.toggleCGIVoiceCommands()
                    } label: {
                        Label(
                            session.isListeningForCGICommands ? "Dinlemeyi Durdur" : "Komut Dinle",
                            systemImage: session.isListeningForCGICommands ? "stop.circle.fill" : "mic.circle.fill"
                        )
                    }
                    Text("“Elimde elma olsun”, “elmayı kaldır” veya “kan şelalesi aksın” diyebilirsin.")
                        .font(.caption)
                    LabeledContent("Durum", value: session.liveCGIStatus)
                    Button {
                        session.openAppPermissionSettings()
                    } label: {
                        Label("Mikrofon ve Konuşma İzinleri", systemImage: "gear")
                    }
                }
            }
            .navigationTitle("Canlı CGI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") { showingCGIStudio = false }
                }
            }
        }
    }

    private var propLibrary: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(PropLibraryCategory.allCases) { category in
                        let props = PropKind.photorealCases.filter {
                            $0.photorealDescriptor?.category == category
                        }
                        if !props.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(category.title)
                                    .font(.headline)
                                LazyVGrid(
                                    columns: Array(
                                        repeating: GridItem(.flexible(), spacing: 10),
                                        count: 3
                                    ),
                                    spacing: 10
                                ) {
                                    ForEach(props) { prop in
                                        Button {
                                            session.selectProp(prop)
                                            showingPropLibrary = false
                                        } label: {
                                            VStack(spacing: 6) {
                                                Text(prop.symbol).font(.largeTitle)
                                                Text(prop.title)
                                                    .font(.caption.weight(.semibold))
                                                    .lineLimit(2)
                                                    .minimumScaleFactor(0.75)
                                                    .multilineTextAlignment(.center)
                                            }
                                            .frame(maxWidth: .infinity, minHeight: 92)
                                            .background(
                                                .thinMaterial,
                                                in: RoundedRectangle(cornerRadius: 14)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("30 Gerçekçi 3B Nesne")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { showingPropLibrary = false }
                }
            }
        }
    }

    private func utilityButton(
        _ title: String,
        _ icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            utilityLabel(title, icon)
        }
    }

    private func utilityLabel(_ title: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.body)
            Text(title)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}
