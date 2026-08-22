import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var session = ARSessionController()
    @State private var showingRoomScanner = false
    @State private var showingAssetImporter = false
    @State private var roomScanResult: RoomScanResult?

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
                    controls
                        .disabled(session.isRecordingTransitioning)
                }
                .padding()
            }
        }
        .statusBarHidden(session.isRecording || session.isRecordingTransitioning)
        .fullScreenCover(isPresented: $showingRoomScanner, onDismiss: {
            session.resumeAfterRoomScan(result: roomScanResult)
            roomScanResult = nil
        }) {
            RoomScannerScreen(exportURL: session.roomModelURL) { result in
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
            Text("Dekor seçip yüzeye dokun • Seçili dekoru sürükle, döndür veya ölçekle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PropKind.allCases) { prop in
                        Button {
                            session.selectedProp = prop
                        } label: {
                            VStack(spacing: 4) {
                                Text(prop.symbol).font(.title2)
                                Text(prop.title).font(.caption2.weight(.semibold))
                            }
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
                .disabled(!RoomScannerController.isSupported)

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
