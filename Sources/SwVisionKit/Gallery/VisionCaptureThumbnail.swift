#if os(iOS)
import SwiftUI
import ImageIO

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

            if record.kind == .video, let duration = record.durationSeconds {
                Text(formatted(duration))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.8), radius: 2)
                    .padding(6)
            }
        }
        .task(id: record.id) { await loadImage() }
    }

    private func loadImage() async {
        let url = record.kind == .video ? store.thumbnailURL(for: record) : store.fileURL(for: record)
        guard let url else { return }
        let loaded = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            // Grid cells are small: decode a ~400 px ImageIO thumbnail, never
            // the full-resolution bitmap.
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [
                      kCGImageSourceCreateThumbnailFromImageAlways: true,
                      kCGImageSourceCreateThumbnailWithTransform: true,
                      kCGImageSourceThumbnailMaxPixelSize: 400,
                  ] as CFDictionary) else { return nil }
            return UIImage(cgImage: cg)
        }.value
        image = loaded
    }

    private func formatted(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
#endif
