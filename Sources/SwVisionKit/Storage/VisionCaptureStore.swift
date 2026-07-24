import Foundation

@MainActor
public final class VisionCaptureStore: ObservableObject {
    @Published public private(set) var records: [VisionCaptureRecord] = []

    public let directory: URL
    private let manifestURL: URL

    /// `directory` is injectable for testing; defaults to an app-sandboxed
    /// Application Support folder (not the system Photos library, not
    /// Documents — this is an internal app concept, not user-file-visible).
    public init(directory: URL? = nil) {
        let dir = directory ?? Self.defaultDirectory()
        self.directory = dir
        self.manifestURL = dir.appendingPathComponent("manifest.json")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        load()
    }

    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("VisionCaptures", isDirectory: true)
    }

    public var lastVideo: VisionCaptureRecord? {
        records.first { $0.kind == .video }
    }

    public func add(_ record: VisionCaptureRecord) {
        records.insert(record, at: 0)
        persist()
    }

    public func delete(_ record: VisionCaptureRecord) {
        records.removeAll { $0.id == record.id }
        try? FileManager.default.removeItem(at: fileURL(for: record))
        if let thumbURL = thumbnailURL(for: record) {
            try? FileManager.default.removeItem(at: thumbURL)
        }
        persist()
    }

    public func fileURL(for record: VisionCaptureRecord) -> URL {
        directory.appendingPathComponent(record.fileName)
    }

    public func thumbnailURL(for record: VisionCaptureRecord) -> URL? {
        guard let name = record.thumbnailFileName else { return nil }
        return directory.appendingPathComponent(name)
    }

    private func load() {
        guard
            let data = try? Data(contentsOf: manifestURL),
            let decoded = try? JSONDecoder().decode([VisionCaptureRecord].self, from: data)
        else { return }
        records = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: manifestURL, options: .atomic)
    }
}
