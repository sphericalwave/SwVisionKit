#if os(iOS)
import SwiftUI
import AVKit

public struct VisionCapturePlayerView: View {
    let record: VisionCaptureRecord
    @ObservedObject var store: VisionCaptureStore
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var image: UIImage?

    public init(record: VisionCaptureRecord, store: VisionCaptureStore) {
        self.record = record
        self.store = store
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch record.kind {
            case .video:
                if let player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                }
            case .photo:
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white, .black.opacity(0.5))
            }
            .padding()
        }
        .onAppear {
            switch record.kind {
            case .video:
                let p = AVPlayer(url: store.fileURL(for: record))
                player = p
                p.play()
            case .photo:
                if let data = try? Data(contentsOf: store.fileURL(for: record)) {
                    image = UIImage(data: data)
                }
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
#endif
