import Foundation

public struct VisionCaptureRecord: Codable, Identifiable, Equatable {
    public enum Kind: String, Codable {
        case video
        case photo
    }

    public let id: UUID
    public let date: Date
    public let kind: Kind
    public let fileName: String
    public let thumbnailFileName: String?
    public let durationSeconds: Double?

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        kind: Kind,
        fileName: String,
        thumbnailFileName: String? = nil,
        durationSeconds: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.fileName = fileName
        self.thumbnailFileName = thumbnailFileName
        self.durationSeconds = durationSeconds
    }
}
