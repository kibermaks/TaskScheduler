import Foundation
import SwiftUI
import AppKit

/// Handles lightweight update checks against GitHub releases.
final class UpdateService: ObservableObject {
    struct UpdateInfo {
        let version: String
        let title: String
        let releaseNotes: String
        let downloadURL: URL?
        let pageURL: URL
    }
    
    struct UpdateAlert: Identifiable {
        enum Kind {
            case updateAvailable(UpdateInfo)
            case upToDate(String)
            case failure(String)
        }
        
        let id = UUID()
        let kind: Kind
    }
    
    @Published private(set) var isChecking = false
    @Published var pendingAlert: UpdateAlert?
    
    private let repoOwner = "kibermaks"
    private let repoName = "TaskScheduler"
    private let lastCheckDefaultsKey = "TaskScheduler.LastUpdateCheckDate"
    private var periodicTimer: Timer?
    private var hasScheduledChecks = false
    
    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 20
        configuration.httpAdditionalHeaders = [
            "Accept": "application/vnd.github+json"
        ]
        return URLSession(configuration: configuration)
    }()
    
    deinit {
        periodicTimer?.invalidate()
    }
    
    // MARK: - Public API
    
    func startAutomaticChecks() {
        guard !hasScheduledChecks else { return }
        hasScheduledChecks = true
        checkForUpdates(userInitiated: false, ignoreThrottle: true)
        schedulePeriodicChecks()
    }
    
    func userInitiatedCheck() {
        checkForUpdates(userInitiated: true, ignoreThrottle: true)
    }
    
    func installLatestUpdate(_ info: UpdateInfo) {
        let url = info.downloadURL ?? info.pageURL
        NSWorkspace.shared.open(url)
        dismissAlert()
    }
    
    func dismissAlert() {
        pendingAlert = nil
    }
    
    // MARK: - Update Logic
    
    private func checkForUpdatesIfNeeded() {
        guard shouldPerformAutomaticCheck else { return }
        checkForUpdates(userInitiated: false, ignoreThrottle: false)
    }
    
    private var shouldPerformAutomaticCheck: Bool {
        let defaults = UserDefaults.standard
        guard let lastCheck = defaults.object(forKey: lastCheckDefaultsKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastCheck) > 60 * 60 * 24
    }
    
    private func checkForUpdates(userInitiated: Bool, ignoreThrottle: Bool) {
        if isChecking { return }
        if !ignoreThrottle && !userInitiated && !shouldPerformAutomaticCheck {
            return
        }
        
        isChecking = true
        Task {
            defer {
                Task { @MainActor in
                    self.isChecking = false
                }
            }
            
            do {
                let request = try buildLatestReleaseRequest()
                let (data, response) = try await urlSession.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw UpdateError.invalidResponse
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw UpdateError.badStatus(httpResponse.statusCode)
                }
                
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                try await handleRelease(release, userInitiated: userInitiated)
            } catch {
                if userInitiated {
                    await MainActor.run {
                        self.pendingAlert = UpdateAlert(kind: .failure(errorMessage(for: error)))
                    }
                }
            }
        }
    }
    
    private func handleRelease(_ release: GitHubRelease, userInitiated: Bool) async throws {
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let normalizedTag = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        let comparison = compareVersion(lhs: normalizedTag, rhs: currentVersion)
        
        await MainActor.run {
            UserDefaults.standard.set(Date(), forKey: self.lastCheckDefaultsKey)
        }
        
        switch comparison {
        case .orderedDescending:
            let info = UpdateInfo(
                version: normalizedTag,
                title: release.name.isEmpty ? "Task Scheduler \(normalizedTag)" : release.name,
                releaseNotes: release.notesPreview,
                downloadURL: preferredDownloadURL(from: release.assets),
                pageURL: release.htmlURL
            )
            await MainActor.run {
                self.pendingAlert = UpdateAlert(kind: .updateAvailable(info))
            }
        default:
            guard userInitiated else { return }
            await MainActor.run {
                self.pendingAlert = UpdateAlert(kind: .upToDate(currentVersion))
            }
        }
    }
    
    private func buildLatestReleaseRequest() throws -> URLRequest {
        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else {
            throw UpdateError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return request
    }
    
    private func preferredDownloadURL(from assets: [GitHubRelease.Asset]) -> URL? {
        let dmg = assets.first { $0.browserDownloadURL.pathExtension.lowercased() == "dmg" }
        if let dmgURL = dmg?.browserDownloadURL { return dmgURL }
        let zip = assets.first { $0.browserDownloadURL.pathExtension.lowercased() == "zip" }
        if let zipURL = zip?.browserDownloadURL { return zipURL }
        return assets.first?.browserDownloadURL
    }
    
    private func errorMessage(for error: Error) -> String {
        if let updateError = error as? UpdateError {
            return updateError.localizedDescription
        }
        return error.localizedDescription
    }
    
    private func schedulePeriodicChecks() {
        periodicTimer?.invalidate()
        periodicTimer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            self?.checkForUpdatesIfNeeded()
        }
        if let timer = periodicTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    // MARK: - Helpers
    
    private func compareVersion(lhs: String, rhs: String) -> ComparisonResult {
        let lhsComponents = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let rhsComponents = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let maxCount = max(lhsComponents.count, rhsComponents.count)
        
        for index in 0..<maxCount {
            let left = index < lhsComponents.count ? lhsComponents[index] : 0
            let right = index < rhsComponents.count ? rhsComponents[index] : 0
            if left < right { return .orderedAscending }
            if left > right { return .orderedDescending }
        }
        return .orderedSame
    }
}

// MARK: - Models

extension UpdateService {
    private struct GitHubRelease: Decodable {
        let tagName: String
        let name: String
        let body: String?
        let htmlURL: URL
        let assets: [Asset]
        
        var notesPreview: String {
            let trimmed = (body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let lines = trimmed.split(separator: "\n").map { String($0) }
            return lines.prefix(6).joined(separator: "\n")
        }
        
        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: URL
            
            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name
            case body
            case htmlURL = "html_url"
            case assets
        }
    }
    
    enum UpdateError: LocalizedError {
        case invalidURL
        case invalidResponse
        case badStatus(Int)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Failed to build update URL."
            case .invalidResponse:
                return "GitHub returned an invalid response."
            case .badStatus(let code):
                return "GitHub update check failed with status code \(code)."
            }
        }
    }
}
