import Foundation
import SwiftUI

class AutoUpdater: ObservableObject {
    static let shared = AutoUpdater()

    @Published var updateAvailable = false
    @Published var latestVersion = ""
    @Published var updateStatus: UpdateStatus = .idle
    @Published var updateLog: [String] = []

    private let repoOwner = "6nmsb4mvzs-ui"
    private let repoName = "ba"
    private var checkTimer: Timer?

    enum UpdateStatus: Equatable {
        case idle
        case checking
        case available(String)
        case downloading
        case installing
        case complete
        case failed(String)
    }

    private init() {
        startPeriodicCheck()
    }

    private func startPeriodicCheck() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.checkForUpdates()
        }
    }

    func checkForUpdates() {
        updateStatus = .checking
        addLog("Checking for updates...")

        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/contents/VERSION"
        guard let url = URL(string: urlString) else {
            updateStatus = .failed("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3.raw", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.updateStatus = .failed(error.localizedDescription)
                    self?.addLog("Error: \(error.localizedDescription)")
                    return
                }

                guard let data = data,
                      let remoteVersion = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                else {
                    self?.updateStatus = .failed("Could not read version")
                    self?.addLog("Failed to read remote version")
                    return
                }

                self?.latestVersion = remoteVersion
                let current = AppVersion.current

                if self?.isNewer(remoteVersion, than: current) == true {
                    self?.updateAvailable = true
                    self?.updateStatus = .available(remoteVersion)
                    self?.addLog("Update available: v\(remoteVersion) (current: v\(current))")
                } else {
                    self?.updateAvailable = false
                    self?.updateStatus = .idle
                    self?.addLog("Already up to date (v\(current))")
                }
            }
        }.resume()
    }

    func performUpdate() {
        updateStatus = .downloading
        addLog("Starting update...")

        let appPath = Bundle.main.bundlePath
        let parentDir = (appPath as NSString).deletingLastPathComponent
        let repoDir = parentDir + "/GlassOS-update"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                // Clean up previous update directory
                let fm = FileManager.default
                if fm.fileExists(atPath: repoDir) {
                    try fm.removeItem(atPath: repoDir)
                }

                self?.mainLog("Cloning latest version...")

                let cloneProcess = Process()
                cloneProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                cloneProcess.arguments = ["clone", "--depth", "1",
                                          "https://github.com/\(self?.repoOwner ?? "")/\(self?.repoName ?? "").git",
                                          repoDir]
                try cloneProcess.run()
                cloneProcess.waitUntilExit()

                guard cloneProcess.terminationStatus == 0 else {
                    self?.mainLog("Git clone failed")
                    DispatchQueue.main.async {
                        self?.updateStatus = .failed("Git clone failed")
                    }
                    return
                }

                DispatchQueue.main.async {
                    self?.updateStatus = .installing
                }
                self?.mainLog("Building update...")

                let buildProcess = Process()
                buildProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
                buildProcess.arguments = [repoDir + "/build.command", "--update"]
                buildProcess.currentDirectoryURL = URL(fileURLWithPath: repoDir)
                try buildProcess.run()
                buildProcess.waitUntilExit()

                guard buildProcess.terminationStatus == 0 else {
                    self?.mainLog("Build failed")
                    DispatchQueue.main.async {
                        self?.updateStatus = .failed("Build failed")
                    }
                    return
                }

                self?.mainLog("Update complete! Restart to apply.")
                DispatchQueue.main.async {
                    self?.updateStatus = .complete
                    self?.updateAvailable = false
                }

                // Clean up
                try? fm.removeItem(atPath: repoDir)

            } catch {
                self?.mainLog("Update error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.updateStatus = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func isNewer(_ remote: String, than local: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let localParts = local.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(remoteParts.count, localParts.count) {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }

    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        DispatchQueue.main.async {
            self.updateLog.append("[\(timestamp)] \(message)")
        }
    }

    private func mainLog(_ message: String) {
        DispatchQueue.main.async {
            self.addLog(message)
        }
    }
}
