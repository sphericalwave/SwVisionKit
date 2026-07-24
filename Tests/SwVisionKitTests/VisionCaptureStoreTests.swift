import XCTest
@testable import SwVisionKit

@MainActor
final class VisionCaptureStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("VisionCaptureStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testManifestRoundTripsAcrossInstances() {
        let store1 = VisionCaptureStore(directory: tempDir)
        let record = VisionCaptureRecord(kind: .photo, fileName: "a.jpg")
        store1.add(record)

        let store2 = VisionCaptureStore(directory: tempDir)
        XCTAssertEqual(store2.records.count, 1)
        XCTAssertEqual(store2.records.first?.id, record.id)
        XCTAssertEqual(store2.records.first?.fileName, "a.jpg")
    }

    func testLastVideoSkipsInterveningPhotos() {
        let store = VisionCaptureStore(directory: tempDir)
        let video1 = VisionCaptureRecord(date: Date(timeIntervalSince1970: 100), kind: .video, fileName: "v1.mp4")
        store.add(video1)
        let photo = VisionCaptureRecord(date: Date(timeIntervalSince1970: 200), kind: .photo, fileName: "p1.jpg")
        store.add(photo)

        XCTAssertEqual(store.lastVideo?.id, video1.id)
    }

    func testDeleteRemovesFileAndManifestEntry() throws {
        let store = VisionCaptureStore(directory: tempDir)
        let record = VisionCaptureRecord(kind: .photo, fileName: "a.jpg", thumbnailFileName: nil)
        store.add(record)
        try Data().write(to: store.fileURL(for: record))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL(for: record).path))

        store.delete(record)

        XCTAssertTrue(store.records.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL(for: record).path))
    }

    func testDeleteDoesNotThrowWhenFileAlreadyMissing() {
        let store = VisionCaptureStore(directory: tempDir)
        let record = VisionCaptureRecord(kind: .photo, fileName: "missing.jpg")
        store.add(record)

        store.delete(record) // file was never written to disk
        XCTAssertTrue(store.records.isEmpty)
    }

    func testLastVideoNilWhenNoVideos() {
        let store = VisionCaptureStore(directory: tempDir)
        store.add(VisionCaptureRecord(kind: .photo, fileName: "p.jpg"))
        XCTAssertNil(store.lastVideo)
    }
}
