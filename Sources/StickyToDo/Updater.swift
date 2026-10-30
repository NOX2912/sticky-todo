import AppKit

/// Sucht auf GitHub nach einem neueren Release und ersetzt die App durch dessen ZIP.
/// Weil die App selbst lädt (nicht der Browser), ist das Update nicht in Quarantäne
/// und braucht kein erneutes „Dennoch öffnen“.
@MainActor
final class Updater: ObservableObject {
    struct Release {
        let version: String
        let zip: URL
    }

    @Published private(set) var available: Release?
    @Published private(set) var installing = false

    let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    private let latestRelease = URL(string: "https://api.github.com/repos/NOX2912/sticky-todo/releases/latest")!
    private var timer: Timer?

    func start() {
        Task { await check() }
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            Task { await self?.check() }
        }
    }

    func check() async {
        struct Response: Decodable {
            struct Asset: Decodable {
                let name: String
                let browserDownloadUrl: URL
            }
            let tagName: String
            let assets: [Asset]
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let (data, _) = try? await URLSession.shared.data(from: latestRelease),
              let release = try? decoder.decode(Response.self, from: data),
              let zip = release.assets.first(where: { $0.name.hasSuffix(".zip") }) else { return }
        let version = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        if version.compare(current, options: .numeric) == .orderedDescending {
            available = Release(version: version, zip: zip.browserDownloadUrl)
        }
    }

    func install() {
        guard let release = available, !installing else { return }
        installing = true
        Task {
            do {
                try await install(release)
            } catch {
                installing = false
                NSApp.activate()
                let alert = NSAlert()
                alert.messageText = tr("Update fehlgeschlagen", "Update failed")
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }

    private func install(_ release: Release) async throws {
        let (zip, _) = try await URLSession.shared.download(from: release.zip)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try run("/usr/bin/ditto", "-x", "-k", zip.path, folder.path)
        guard let app = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .first(where: { $0.pathExtension == "app" }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try run("/usr/bin/xattr", "-cr", app.path)

        let target = Bundle.main.bundleURL
        _ = try FileManager.default.replaceItemAt(target, withItemAt: app)

        // Neue Version starten, sobald diese beendet ist
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "sleep 1; open \"$0\"", target.path]
        try relaunch.run()
        NSApp.terminate(nil)
    }

    private func run(_ tool: String, _ arguments: String...) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CocoaError(.fileWriteUnknown) }
    }
}
