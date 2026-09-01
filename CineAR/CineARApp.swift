import Foundation
import SwiftUI
import UIKit

@main
struct CineARApp: App {
    @StateObject private var updateChecker = AppUpdateChecker()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .environmentObject(updateChecker)
                .task {
                    await updateChecker.checkForUpdates(showCurrentStatus: false)
                }
                .alert(item: $updateChecker.notice) { notice in
                    if let actionTitle = notice.actionTitle,
                       notice.actionURL != nil {
                        return Alert(
                            title: Text(notice.title),
                            message: Text(notice.message),
                            primaryButton: .default(Text(actionTitle)) {
                                updateChecker.openUpdate(from: notice)
                            },
                            secondaryButton: .cancel(Text("Daha Sonra"))
                        )
                    }
                    return Alert(
                        title: Text(notice.title),
                        message: Text(notice.message),
                        dismissButton: .default(Text("Tamam"))
                    )
                }
        }
    }
}

@MainActor
final class AppUpdateChecker: ObservableObject {
    struct Notice: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let actionTitle: String?
        let actionURL: URL?
    }

    @Published private(set) var isChecking = false
    @Published var notice: Notice?

    private struct LookupResponse: Decodable {
        let results: [LookupResult]
    }

    private struct LookupResult: Decodable {
        let version: String
        let trackViewUrl: URL?
    }

    private var lastAutomaticCheck: Date?
    private static let automaticCheckInterval: TimeInterval = 6 * 60 * 60
    private static let testFlightURL = URL(
        string: "https://apps.apple.com/app/testflight/id899247664"
    )!

    func checkForUpdates(showCurrentStatus: Bool) async {
        guard !isChecking else { return }
        if !showCurrentStatus,
           let lastAutomaticCheck,
           Date().timeIntervalSince(lastAutomaticCheck) < Self.automaticCheckInterval {
            return
        }

        guard let bundleID = Bundle.main.bundleIdentifier,
              let currentVersion = Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
              ) as? String,
              var components = URLComponents(string: "https://itunes.apple.com/lookup") else {
            if showCurrentStatus {
                notice = Notice(
                    title: "Sürüm okunamadı",
                    message: "Uygulamanın sürüm bilgisi bulunamadı.",
                    actionTitle: nil,
                    actionURL: nil
                )
            }
            return
        }

        let appStoreID = Bundle.main.object(forInfoDictionaryKey: "CineARAppStoreID") as? String
        components.queryItems = [
            URLQueryItem(
                name: appStoreID?.isEmpty == false ? "id" : "bundleId",
                value: appStoreID?.isEmpty == false ? appStoreID : bundleID
            ),
            URLQueryItem(name: "country", value: "tr")
        ]
        guard let url = components.url else { return }

        isChecking = true
        defer { isChecking = false }
        if !showCurrentStatus { lastAutomaticCheck = Date() }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            request.cachePolicy = .reloadRevalidatingCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let lookup = try JSONDecoder().decode(LookupResponse.self, from: data)
            guard let storeResult = lookup.results.first else {
                if showCurrentStatus { publishTestFlightOrUnavailableNotice() }
                return
            }

            if storeResult.version.compare(currentVersion, options: .numeric) == .orderedDescending {
                let fallbackStoreURL = appStoreID.flatMap {
                    URL(string: "https://apps.apple.com/app/id\($0)")
                }
                notice = Notice(
                    title: "Yeni CineAR sürümü hazır",
                    message: "Yüklü sürüm \(currentVersion), yeni sürüm \(storeResult.version). Güncelleme App Store üzerinden güvenli biçimde kurulacak.",
                    actionTitle: "Güncelle",
                    actionURL: storeResult.trackViewUrl ?? fallbackStoreURL
                )
            } else if showCurrentStatus {
                notice = Notice(
                    title: "CineAR güncel",
                    message: "En yeni sürümü kullanıyorsun: \(currentVersion).",
                    actionTitle: nil,
                    actionURL: nil
                )
            }
        } catch {
            guard showCurrentStatus else { return }
            if isTestFlightBuild {
                publishTestFlightOrUnavailableNotice()
            } else {
                notice = Notice(
                    title: "Güncelleme denetlenemedi",
                    message: "İnternet bağlantısını kontrol edip tekrar dene: \(error.localizedDescription)",
                    actionTitle: nil,
                    actionURL: nil
                )
            }
        }
    }

    func openUpdate(from notice: Notice) {
        guard let url = notice.actionURL else { return }
        UIApplication.shared.open(url)
    }

    private var isTestFlightBuild: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

    private func publishTestFlightOrUnavailableNotice() {
        if isTestFlightBuild {
            notice = Notice(
                title: "TestFlight sürümü",
                message: "Beta güncellemeleri TestFlight tarafından kurulur. TestFlight'ı açıp CineAR için Güncelle düğmesini kullan.",
                actionTitle: "TestFlight'ı Aç",
                actionURL: Self.testFlightURL
            )
        } else {
            notice = Notice(
                title: "App Store kaydı bulunamadı",
                message: "CineAR henüz bu App Store bölgesinde yayınlanmamış olabilir.",
                actionTitle: nil,
                actionURL: nil
            )
        }
    }
}
