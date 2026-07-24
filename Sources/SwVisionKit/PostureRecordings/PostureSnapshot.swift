import Foundation

// Captures exactly what the Vision HUD shows at a point in time.
public struct PostureSnapshot: Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let postureClass: String
    public let spineLabel: String
    public let hipLabel: String
    public let shoulderLabel: String
}

extension PostureSnapshot {
    public init(from report: PostureReport) {
        id = UUID()
        date = Date()
        postureClass = report.postureClass.rawValue
        spineLabel = report.spineLabel
        hipLabel = report.hipLabel
        shoulderLabel = report.shoulderLabel
    }
}
