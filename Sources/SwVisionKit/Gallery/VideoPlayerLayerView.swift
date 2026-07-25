#if os(iOS)
import SwiftUI
import AVFoundation

/// Bare `AVPlayerLayer` wrapper — no native AVKit controls, since
/// `VisionCapturePlayerView` draws its own play/pause/scrub/mute bar.
/// Mirrors `CameraPreviewView`'s `layerClass` trick.
struct VideoPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

final class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
#endif
