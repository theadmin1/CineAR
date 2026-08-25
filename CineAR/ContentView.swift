import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var session = ARSessionController()
    @State private var showingRoomScanner = false
    @State private var showingAssetImporter = false
    @State private var showingPropLibrary = false
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
                    } else if controlsExpanded {
                        controls
                    } else {
                        compactControls
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

            Text("Nesne seçildiğinde bu panel kapanır; zeminin istediğin yerine dokunabilirsin")
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
                Text("Zemine veya görünen yüzeye dokun")
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

    private var propLibrary: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                    spacing: 10
                ) {
                    ForEach(PropKind.furnitureCases) { prop in
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
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("3B Nesne Kütüphanesi")
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
