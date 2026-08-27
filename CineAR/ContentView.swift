import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var session = ARSessionController()
    @State private var showingRoomScanner = false
    @State private var showingAssetImporter = false
    @State private var showingPropLibrary = false
    @State private var showingAISettings = false
    @State private var roomScanResult: RoomScanResult?
    @State private var controlsExpanded = false

    var body: some View {
        ZStack {
            ARViewContainer(controller: session)
                .ignoresSafeArea()

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
                utilityButton("Oda Tara", "viewfinder") {
                    session.pauseForRoomScan()
                    showingRoomScanner = true
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
                }

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
                        "http://192.168.1.20:8765",
                        text: Binding(
                            get: { session.aiServerAddress },
                            set: { session.setAIServerAddress($0) }
                        )
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                    LabeledContent("Durum") {
                        Text(session.aiEnhancementStatus.title)
                            .foregroundStyle(aiStatusColor)
                            .multilineTextAlignment(.trailing)
                    }

                    Button("PC bağlantısını test et") {
                        session.testAIServerConnection()
                    }
                    .disabled(AIEnhancementClient.serverURL(from: session.aiServerAddress) == nil)
                }

                Section("Çalışma şekli") {
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
        case .waiting: .orange
        case .disabled: .secondary
        }
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
        HStack(spacing: 8) {
            compactButton("Kontroller", "slider.horizontal.3") {
                controlsExpanded = true
            }
            compactButton("Nesneler", "shippingbox.fill") {
                showingPropLibrary = true
            }
            compactButton(
                session.isRoomOutlineVisible ? "Gerçek" : "Hatlar",
                session.isRoomOutlineVisible ? "camera.fill" : "square.dashed.inset.filled"
            ) {
                if session.isRoomOutlineVisible {
                    session.showOriginalReality()
                } else {
                    session.showRoomOutline()
                }
            }
            .disabled(!session.hasScannedRoom)
            compactButton("Oda Tara", "viewfinder") {
                session.pauseForRoomScan()
                showingRoomScanner = true
            }
            .disabled(!RoomScannerController.isSupported || !session.isARReady)
        }
        .disabled(session.isRecordingTransitioning)
        .padding(8)
        .background(.ultraThinMaterial, in: Capsule())
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
                lightSliderRow(
                    title: "Güç",
                    valueText: "\(Int(settings.intensityLumens)) lm",
                    value: Binding(
                        get: { Double(session.selectedLightSettings?.intensityLumens ?? 1_600) },
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
                    valueText: "\(Int(settings.coneAngleDegrees))°",
                    value: Binding(
                        get: { Double(session.selectedLightSettings?.coneAngleDegrees ?? 72) },
                        set: { session.setSelectedLightConeAngle(Float($0)) }
                    ),
                    range: 15...120,
                    step: 1
                )
            }

            Text("Bu ışık yalnızca sanal dekorları etkiler; gerçek kamera görüntüsü değiştirilmez.")
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
                Text(placementPrompt)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("İptal") { session.cancelPlacement() }
                .buttonStyle(.borderedProminent)
                .tint(.red)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var placementPrompt: String {
        switch session.selectedProp.placementSurface {
        case .floor: "Yeşil takipte taranmış zemine dokun"
        case .horizontal: "Yeşil takipte zemine veya yatay yüzeye dokun"
        case .wall: "Yeşil takipte taranmış duvara dokun"
        case .ceiling: "Telefonu yukarı çevirip taranmış tavana dokun"
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
