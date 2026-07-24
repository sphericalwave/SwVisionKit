import CoreMedia

/// Pure frame-count → presentation-time math for the capture compositor's
/// fixed-cadence recording loop. Frame-count-based, not wall-clock, so timer
/// tick jitter doesn't distort playback speed — every frame is exactly
/// `1/frameRate` after the previous one regardless of when the timer fired.
/// No platform dependency (unlike the rest of `Recording/`) so this stays
/// testable on any host, including macOS CI.
public enum CaptureCadence {
    public static let frameRate: Int32 = 15

    public static func presentationTime(forFrame frameCount: Int64) -> CMTime {
        CMTime(value: frameCount, timescale: frameRate)
    }
}
