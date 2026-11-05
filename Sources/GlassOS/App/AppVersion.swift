import Foundation

struct AppVersion {
    static var current: String {
        if let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return bundleVersion
        }

        // Fall back to reading VERSION file from the source directory
        let possiblePaths = [
            Bundle.main.bundlePath + "/../../../VERSION",
            Bundle.main.resourcePath.map { $0 + "/VERSION" },
            FileManager.default.currentDirectoryPath + "/VERSION"
        ].compactMap { $0 }

        for path in possiblePaths {
            if let version = try? String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) {
                return version
            }
        }

        return "1.0.0"
    }
}
