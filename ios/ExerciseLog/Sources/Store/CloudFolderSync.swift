import Foundation

/// Mirrors the log into a folder the user picks in Files.
///
/// Picking a folder through the document picker grants access without any
/// iCloud entitlement, and the grant survives relaunches as a
/// security-scoped bookmark. Whatever provider backs the folder (iCloud
/// Drive, Google Drive, Dropbox) does the actual syncing; this type only
/// reads and writes one file inside it. On the Mac the same file then sits
/// at `~/Library/Mobile Documents/com~apple~CloudDocs/<folder>/` or
/// `~/My Drive/<folder>/`, which is what makes it readable by scripts.
enum CloudFolderSync {
    static let fileName = "exercise-log.json"
    private static let bookmarkKey = "el-folder-bookmark"
    private static let nameKey = "el-folder-name"

    enum CloudError: LocalizedError {
        case notConfigured
        case bookmarkStale
        case accessDenied
        case stillDownloading
        case notALogFile
        case coordination(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "No sync folder chosen yet."
            case .bookmarkStale: return "The sync folder moved or was deleted. Choose it again."
            case .accessDenied: return "iOS would not grant access to the sync folder. Choose it again."
            case .stillDownloading: return "The log is still downloading from the cloud. Try again in a moment."
            case .notALogFile: return "The file in that folder is not an Exercise Log, so it was left untouched."
            case .coordination(let detail): return detail
            }
        }
    }

    static var isConfigured: Bool { UserDefaults.standard.data(forKey: bookmarkKey) != nil }
    static var displayName: String? { UserDefaults.standard.string(forKey: nameKey) }

    static func remember(_ url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(data, forKey: bookmarkKey)
        UserDefaults.standard.set(url.lastPathComponent, forKey: nameKey)
    }

    static func forget() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        UserDefaults.standard.removeObject(forKey: nameKey)
    }

    private static func resolve() throws -> URL {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            throw CloudError.notConfigured
        }
        var stale = false
        let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        if stale {
            guard url.startAccessingSecurityScopedResource() else { throw CloudError.bookmarkStale }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let refreshed = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            else { throw CloudError.bookmarkStale }
            UserDefaults.standard.set(refreshed, forKey: bookmarkKey)
        }
        return url
    }

    private static func withFile<T>(_ body: (URL) throws -> T) throws -> T {
        let folder = try resolve()
        guard folder.startAccessingSecurityScopedResource() else { throw CloudError.accessDenied }
        defer { folder.stopAccessingSecurityScopedResource() }
        return try body(folder.appendingPathComponent(fileName))
    }

    /// The cloud copy, or nil when the folder has no log yet.
    static func read() throws -> LogFile? {
        try withFile { url in
            let fm = FileManager.default
            if !fm.fileExists(atPath: url.path) {
                // A placeholder that has not been pulled to this device yet
                // looks like a missing file. Ask for it and bail rather than
                // treat "nothing here" as truth.
                var isPlaceholder = false
                if let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey]),
                   values.isUbiquitousItem == true {
                    isPlaceholder = true
                }
                if isPlaceholder {
                    try? fm.startDownloadingUbiquitousItem(at: url)
                    throw CloudError.stillDownloading
                }
                return nil
            }
            var result: LogFile?
            var coordinationError: NSError?
            var thrown: Error?
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readURL in
                do {
                    let data = try Data(contentsOf: readURL)
                    guard !data.isEmpty else { return }
                    let file: LogFile
                    do { file = try LogJSON.decoder.decode(LogFile.self, from: data) }
                    catch { throw CloudError.notALogFile }
                    guard file.app == LogFile.appID else { throw CloudError.notALogFile }
                    result = file
                } catch { thrown = error }
            }
            if let coordinationError { throw CloudError.coordination(coordinationError.localizedDescription) }
            if let thrown { throw thrown }
            resolveConflicts(at: url)
            return result
        }
    }

    private static func resolveConflicts(at url: URL) {
        guard let versions = NSFileVersion.unresolvedConflictVersionsOfItem(at: url), !versions.isEmpty else { return }
        for v in versions { v.isResolved = true }
        try? NSFileVersion.removeOtherVersionsOfItem(at: url)
    }

    static func write(_ file: LogFile) throws {
        let payload = try LogJSON.encoder.encode(file)
        try withFile { url in
            var coordinationError: NSError?
            var thrown: Error?
            NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { writeURL in
                do { try payload.write(to: writeURL, options: .atomic) }
                catch { thrown = error }
            }
            if let coordinationError { throw CloudError.coordination(coordinationError.localizedDescription) }
            if let thrown { throw thrown }
        }
    }
}
