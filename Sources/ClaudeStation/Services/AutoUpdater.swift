import Foundation
import AppKit

@MainActor
final class AutoUpdater {
    private let repo = "tedjy971/claude-station"
    private let currentVersion: String

    init() {
        currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkForUpdates() {
        Task {
            guard let latest = await fetchLatestRelease() else { return }
            guard latest.version != currentVersion, latest.version > currentVersion else { return }

            let alert = NSAlert()
            alert.messageText = "Update Available"
            alert.informativeText = "Claude Station \(latest.version) is available (you have \(currentVersion)).\n\n\(latest.notes)"
            alert.addButton(withTitle: "Download")
            alert.addButton(withTitle: "Later")
            alert.alertStyle = .informational

            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: latest.downloadURL) {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private struct Release {
        let version: String
        let notes: String
        let downloadURL: String
    }

    private func fetchLatestRelease() async -> Release? {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        let tagName = (json["tag_name"] as? String ?? "").replacingOccurrences(of: "v", with: "")
        let body = json["body"] as? String ?? ""
        let htmlURL = json["html_url"] as? String ?? "https://github.com/\(repo)/releases"

        // Find DMG asset
        let assets = json["assets"] as? [[String: Any]] ?? []
        let dmgAsset = assets.first { ($0["name"] as? String)?.hasSuffix(".dmg") == true }
        let downloadURL = dmgAsset?["browser_download_url"] as? String ?? htmlURL

        return Release(version: tagName, notes: String(body.prefix(200)), downloadURL: downloadURL)
    }
}
