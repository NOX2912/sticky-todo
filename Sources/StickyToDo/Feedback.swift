import AppKit

/// Öffnet ein neues GitHub-Issue im Browser, App- und macOS-Version sind schon eingetragen.
enum Feedback: String {
    case bug, feature

    func open() {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        var url = URLComponents(string: "https://github.com/NOX2912/sticky-todo/issues/new")!
        url.queryItems = [
            URLQueryItem(name: "template", value: "\(rawValue).yml"),
            URLQueryItem(name: "version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String),
            URLQueryItem(name: "macos", value: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"),
        ]
        NSWorkspace.shared.open(url.url!)
    }
}
