#if os(iOS)
import SwiftUI

public struct VisionCaptureThumbnail: View {
    let record: VisionCaptureRecord
    @ObservedObject var store: VisionCaptureStore
    /// Square by default, matching the stock Photos library grid this
    /// gallery is modeled on. Callers that want a different crop (full
    /// native aspect, say) can override it.
    let aspectRatio: CGFloat
    @State private var image: UIImage?

    public init(record: VisionCaptureRecord, store: VisionCaptureStore, aspectRatio: CGFloat = 1) {
        self.record = record
        self.store = store
        self.aspectRatio = aspectRatio
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().fill(.secondary.opacity(0.15))
                }
            }
            .aspectRatio(aspectRatio, contentMode: .fill)
            .clipped()

            if record.kind == .video {
                HStack(spacing: 2) {
                    Image(systemName: "play.fill")
                    if let duration = record.durationSeconds {
                        Text(formatted(duration))
                    }
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(6)
            }
        }
        .task(id: record.id) { await loadImage() }
    }

    private func loadImage() async {
        let url = record.kind == .video ? store.thumbnailURL(for: record) : store.fileURL(for: record)
        guard let url else { return }
        let loaded = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }.value
        image = loaded
    }

    private func formatted(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
#endif
