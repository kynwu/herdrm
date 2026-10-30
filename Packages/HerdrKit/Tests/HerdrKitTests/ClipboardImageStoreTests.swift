import XCTest
@testable import HerdrKit

/// A local paste types the image's path, and the program reads the file after
/// the paste, so the PNG has to stay on disk. It stays private to the user and
/// goes after a week, like the remote attachment cache.
final class ClipboardImageStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardImageStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testWrittenImageIsPrivateToTheUser() throws {
        let png = Data([0x89, 0x50, 0x4E, 0x47])

        let url = try ClipboardImageStore(directory: directory).write(png: png)

        XCTAssertEqual(try Data(contentsOf: url), png)
        XCTAssertEqual(url.pathExtension, "png")
        XCTAssertEqual(try permissions(of: url), 0o600)
        XCTAssertEqual(try permissions(of: directory), 0o700)
    }

    func testWriteRemovesImagesOlderThanAWeek() throws {
        let store = ClipboardImageStore(directory: directory)
        let now = Date()
        let stale = try store.write(png: Data([1]), now: now)
        let recent = try store.write(png: Data([2]), now: now)
        try setModificationDate(now.addingTimeInterval(-8 * 86_400), of: stale)
        try setModificationDate(now.addingTimeInterval(-6 * 86_400), of: recent)

        let fresh = try store.write(png: Data([3]), now: now)

        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recent.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.path))
    }

    private func permissions(of url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.posixPermissions] as? NSNumber)?.intValue ?? -1
    }

    private func setModificationDate(_ date: Date, of url: URL) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }
}
