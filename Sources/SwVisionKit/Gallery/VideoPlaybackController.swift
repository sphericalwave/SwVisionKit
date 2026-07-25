#if os(iOS)
import AVFoundation

/// Drives a single `AVPlayer` for `VisionCapturePlayerView`'s custom
/// play/pause + scrub + mute controls (no native `VideoPlayer`/AVKit chrome).
@MainActor
final class VideoPlaybackController: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published var isPlaying = false
    @Published var isMuted = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    /// Set while the user is dragging the scrub slider, so the periodic time
    /// observer doesn't fight the drag.
    var isScrubbing = false

    private var timeObserver: Any?

    func load(url: URL) {
        removeObserver()
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.isMuted = isMuted
        player = newPlayer
        currentTime = 0
        duration = 0

        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self, !self.isScrubbing else { return }
            self.currentTime = time.seconds
            if let itemDuration = newPlayer.currentItem?.duration.seconds, itemDuration.isFinite, itemDuration > 0 {
                self.duration = itemDuration
            }
        }
    }

    func play() {
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func toggleMute() {
        isMuted.toggle()
        player?.isMuted = isMuted
    }

    func seek(to seconds: Double) {
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    /// Full teardown — call from `onDisappear` when a page scrolls out of
    /// view, not just `pause()`, so time observers/players don't pile up as
    /// the user swipes through the filmstrip.
    func stop() {
        pause()
        removeObserver()
        player = nil
    }

    private func removeObserver() {
        if let observer = timeObserver, let player {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil
    }
}
#endif
