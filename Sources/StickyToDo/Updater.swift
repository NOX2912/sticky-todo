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
        Task { try? await check() }
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            Task { try? await self?.check() }
        }
    }

    /// Wirft, wenn GitHub nicht erreichbar ist oder ablehnt (offline, Rate-Limit),
    /// damit „Nach Updates suchen …“ das nicht als „neueste Version“ meldet.
    func check() async throws {
        struct Response: Decodable {
            struct Asset: Decodable {
                let name: String
                let browserDownloadUrl: URL
            }
            let tagName: String
            let assets: [Asset]
        }
        let (data, response) = try await URLSession.shared.data(from: latestRelease)
        if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 {
            throw UpdateError.server(status: status)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let release = try decoder.decode(Response.self, from: data)
        guard let zip = release.assets.first(where: { $0.name.hasSuffix(".zip") }) else { return }
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
        let target = Bundle.main.bundleURL
        // Direkt aus dem Download-Ordner gestartet, läuft die App an einem schreibgeschützten Ort
        // (App Translocation) und kann sich dort nicht ersetzen.
        if target.path.contains("/AppTranslocation/") { throw UpdateError.translocated }
        try await replaceApp(at: target, withZipFrom: release.zip)

        // Neue Version starten, sobald diese beendet ist
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "sleep 1; open \"$0\"", target.path]
        try relaunch.run()
        NSApp.terminate(nil)
    }

    /// Lädt die ZIP, entpackt sie und tauscht die App aus. Eigene Funktion, damit die Zwischendateien
    /// aufgeräumt sind, bevor `NSApp.terminate` den Prozess beendet (danach liefe kein `defer` mehr).
    private func replaceApp(at target: URL, withZipFrom url: URL) async throws {
        let (zip, _) = try await URLSession.shared.download(from: url)
        defer { try? FileManager.default.removeItem(at: zip) }
        // Auf demselben Volume wie die App entpacken, sonst kann replaceItemAt sie nicht verschieben.
        let folder = try FileManager.default.url(
            for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: target, create: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try run("/usr/bin/ditto", "-x", "-k", zip.path, folder.path)
        guard let app = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .first(where: { $0.pathExtension == "app" }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try run("/usr/bin/xattr", "-cr", app.path)
        _ = try FileManager.default.replaceItemAt(target, withItemAt: app)
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

/// Update-Fehler mit verständlicher Meldung
enum UpdateError: LocalizedError {
    case server(status: Int)
    case translocated

    var errorDescription: String? {
        switch self {
        case .server(let status):
            return tr("GitHub hat mit Status \(status) geantwortet. Bitte später erneut versuchen.",
                      "GitHub responded with status \(status). Please try again later.")
        case .translocated:
            return tr("Bitte zieh „To Do“ zuerst in den Programme-Ordner und öffne die App von dort.",
                      "Please move “To Do” to your Applications folder first and open it from there.")
        }
    }
}
