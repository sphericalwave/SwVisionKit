#if os(iOS)
import SwiftUI

public struct VisionCaptureThumbnail: View {
    let record: VisionCaptureRecord
    @ObservedObject var store: VisionCaptureStore
    /// Native camera-buffer aspect (portrait, ~3:4) by default — media
    /// previews shouldn't be force-cropped to square. Pass `1` for contexts
    /// where a small square icon/button is genuinely wanted (e.g. the
    /// bottom-left last-video button), not a media preview.
    let aspectRatio: CGFloat
    @State private var image: UIImage?

    public init(record: VisionCaptureRecord, store: VisionCaptureStore, aspectRatio: CGFloat = 3.0 / 4.0) {
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
