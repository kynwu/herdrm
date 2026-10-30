import Foundation

/// The private folder where a pasted clipboard image waits, as a PNG, for the
/// pane's program to read it. A local paste types the file's own path, and the
/// program reads it after the paste, so the file stays. Each write removes
/// images older than a week, as the remote attachment cache does.
public struct ClipboardImageStore: Sendable {
    public static let maximumAge: TimeInterval = 7 * 24 * 60 * 60

    public let directory: URL

    public init(
        directory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("herdrm-clipboard", isDirectory: true)
    ) {
        self.directory = directory
    }

    /// Writes `png` under a fresh name that only the user can read, and
    /// returns its URL.
    public func write(png: Data, now: Date = Date()) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        removeImages(modifiedBefore: now.addingTimeInterval(-Self.maximumAge))
        let url = directory.appendingPathComponent("\(UUID().uuidString.lowercased()).png")
        try png.write(to: url, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return url
    }

    private func removeImages(modifiedBefore cutoff: Date) {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys)
        ) else { return }
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate,
                  modified < cutoff
            else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }
}
