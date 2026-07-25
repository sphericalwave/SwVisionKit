#if os(iOS)
import SwiftUI
import AVFoundation
import CoreImage
import UIKit

/// Composites the live camera frame + pose overlay + HUD into saved photos
/// and (see the video-recording extension) videos — always excluding the
/// toolbar, since the toolbar is never part of what's rendered here.
///
/// `ImageRenderer` has no "live video" mode, so the camera frame itself is
/// never rasterized through SwiftUI: `AVCaptureVideoPreviewLayer` isn't
/// guaranteed to rasterize correctly via `ImageRenderer`/`CALayer.render(in:)`
/// since it drives its content through the video pipeline rather than normal
/// layer drawing. Instead this draws the *raw* `CVPixelBuffer` the capture
/// session already hands to `PoseDetectionService` for Vision (cheap — it's
/// already in memory), and only asks `ImageRenderer` to rasterize the cheap,
/// genuinely-SwiftUI-renderable part: the skeleton overlay + HUD. Composited
/// together with `CGContext`.
@MainActor
public final class VisionCaptureCompositor: ObservableObject {
    @Published public private(set) var isRecording = false
    @Published public private(set) var isPaused = false
    @Published public private(set) var elapsed: TimeInterval = 0

    let detector: PoseDetectionService
    let store: VisionCaptureStore
    let reportProvider: () -> PostureReport?
    let ciContext = CIContext()

    private var videoWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var recordingFileName: String?
    private var frameCount: Int64 = 0
    private var timer: Timer?
    /// Reused when a given tick's `ImageRenderer` pass fails — see
    /// `currentOverlayImage(size:)`.
    private var lastOverlayImage: CGImage?

    public init(detector: PoseDetectionService, store: VisionCaptureStore, report: @escaping () -> PostureReport?) {
        self.detector = detector
        self.store = store
        self.reportProvider = report
    }

    // MARK: - Photo

    public func capturePhoto() -> VisionCaptureRecord? {
        guard let composite = renderComposite() else { return nil }
        let image = UIImage(cgImage: composite)
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else { return nil }

        let fileName = "\(UUID().uuidString).jpg"
        do {
            try jpeg.write(to: store.directory.appendingPathComponent(fileName))
        } catch {
            return nil
        }

        let record = VisionCaptureRecord(kind: .photo, fileName: fileName)
        store.add(record)
        return record
    }

    // MARK: - Shared compositing

    /// Renders the overlay-only content (skeleton + HUD, no camera layer —
    /// the camera frame is drawn separately from the raw pixel buffer) at
    /// `size` in pixels (`scale = 1`, so points == pixels here).
    func renderOverlayImage(size: CGSize) -> CGImage? {
        let content = ZStack {
            PoseOverlayCanvas(pose: detector.pose)
            VStack {
                PostureHUDView(report: reportProvider())
                    .padding(.top, 12)
                Spacer()
            }
        }
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        renderer.scale = 1
        return renderer.cgImage
    }

    /// Camera frame + overlay, composited into a single `CGImage` sized to
    /// the camera's native pixel dimensions. The camera frame is always
    /// drawn even if the overlay fails to render this pass — see
    /// `currentOverlayImage(size:)`.
    func renderComposite() -> CGImage? {
        guard let cameraBuffer = detector.latestPixelBuffer else { return nil }
        let width = CVPixelBufferGetWidth(cameraBuffer)
        let height = CVPixelBufferGetHeight(cameraBuffer)
        let overlay = currentOverlayImage(size: CGSize(width: width, height: height))

        let ciImage = CIImage(cvPixelBuffer: cameraBuffer)
        guard let cameraCGImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(cameraCGImage, in: rect)
        if let overlay { context.draw(overlay, in: rect) }
        return context.makeImage()
    }

    /// Renders a fresh overlay if possible, caching it for reuse when a given
    /// tick's `ImageRenderer` pass fails. `ImageRenderer` is a snapshot-on-
    /// demand API with no guaranteed "render off-cycle, repeatedly" mode, and
    /// this is invoked from a plain `Timer` disconnected from SwiftUI's normal
    /// view-update loop, so occasional `nil` results are expected. Falling
    /// back to the last good frame (stale by at most one tick, visually
    /// irrelevant at 15fps) beats dropping the *camera* frame too, which is
    /// what silently produced empty/unplayable recordings before this fix.
    private func currentOverlayImage(size: CGSize) -> CGImage? {
        if let fresh = renderOverlayImage(size: size) {
            lastOverlayImage = fresh
            return fresh
        }
        return lastOverlayImage
    }

    // MARK: - Video

    public func startVideoRecording() {
        guard !isRecording, let cameraBuffer = detector.latestPixelBuffer else { return }
        let width = CVPixelBufferGetWidth(cameraBuffer)
        let height = CVPixelBufferGetHeight(cameraBuffer)

        let fileName = "\(UUID().uuidString).mp4"
        let url = store.directory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)

        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 4_000_000,
                AVVideoExpectedSourceFrameRateKey: CaptureCadence.frameRate,
                AVVideoMaxKeyFrameIntervalKey: CaptureCadence.frameRate * 2,
            ],
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true

        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs)

        guard writer.canAdd(input) else { return }
        writer.add(input)
        guard writer.startWriting() else { return }
        writer.startSession(atSourceTime: .zero)

        videoWriter = writer
        videoInput = input
        pixelBufferAdaptor = adaptor
        recordingFileName = fileName
        frameCount = 0
        elapsed = 0
        lastOverlayImage = nil
        isRecording = true
        isPaused = false

        // No audio track — video is silent by construction (no ReplayKit/mic
        // passthrough involved, and no NSMicrophoneUsageDescription exists).
        let t = Timer.scheduledTimer(withTimeInterval: 1.0 / Double(CaptureCadence.frameRate), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.appendVideoFrame() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    public func stopVideoRecording() async -> VisionCaptureRecord? {
        guard isRecording, let writer = videoWriter, let input = videoInput, let fileName = recordingFileName else { return nil }
        timer?.invalidate()
        timer = nil
        isRecording = false
        isPaused = false

        input.markAsFinished()
        await writer.finishWriting()

        let duration = elapsed
        let capturedFrames = frameCount
        let status = writer.status
        let error = writer.error

        videoWriter = nil
        videoInput = nil
        pixelBufferAdaptor = nil
        recordingFileName = nil
        lastOverlayImage = nil
        frameCount = 0

        let url = store.directory.appendingPathComponent(fileName)

        guard status == .completed, capturedFrames > 0 else {
            #if DEBUG
            print("VisionCaptureCompositor: recording failed — status=\(status.rawValue) frames=\(capturedFrames) error=\(String(describing: error))")
            #endif
            try? FileManager.default.removeItem(at: url)
            return nil
        }

        let thumbnailFileName = generateThumbnail(for: url, baseName: fileName)
        let record = VisionCaptureRecord(kind: .video, fileName: fileName, thumbnailFileName: thumbnailFileName, durationSeconds: duration)
        store.add(record)
        return record
    }

    /// Stops the capture loop without finalizing the file, leaving
    /// `frameCount`/the writer untouched so `resumeVideoRecording()` can
    /// continue the same frame-count timeline with no discontinuity.
    public func pauseVideoRecording() {
        guard isRecording, !isPaused else { return }
        timer?.invalidate()
        timer = nil
        isPaused = true
    }

    public func resumeVideoRecording() {
        guard isRecording, isPaused else { return }
        isPaused = false
        let t = Timer.scheduledTimer(withTimeInterval: 1.0 / Double(CaptureCadence.frameRate), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.appendVideoFrame() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func appendVideoFrame() {
        guard isRecording,
              let adaptor = pixelBufferAdaptor,
              let input = videoInput,
              let pool = adaptor.pixelBufferPool,
              input.isReadyForMoreMediaData,
              let cameraBuffer = detector.latestPixelBuffer
        else { return }

        let overlay = currentOverlayImage(size: CGSize(
            width: CVPixelBufferGetWidth(cameraBuffer),
            height: CVPixelBufferGetHeight(cameraBuffer)
        ))

        var pixelBufferOut: CVPixelBuffer?
        let poolStatus = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBufferOut)
        guard poolStatus == kCVReturnSuccess, let outputBuffer = pixelBufferOut else {
            #if DEBUG
            print("VisionCaptureCompositor: pixel buffer pool create failed (\(poolStatus))")
            #endif
            return
        }

        compositeIntoPixelBuffer(cameraBuffer: cameraBuffer, overlay: overlay, pixelBuffer: outputBuffer)

        // Frame-count-based, not wall-clock — tick jitter doesn't distort
        // playback speed, just gives a constant frameRate-fps timeline.
        let time = CaptureCadence.presentationTime(forFrame: frameCount)
        adaptor.append(outputBuffer, withPresentationTime: time)
        frameCount += 1
        elapsed = Double(frameCount) / Double(CaptureCadence.frameRate)
    }

    private func compositeIntoPixelBuffer(cameraBuffer: CVPixelBuffer, overlay: CGImage?, pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let ciImage = CIImage(cvPixelBuffer: cameraBuffer)
        if let cameraCGImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
            context.draw(cameraCGImage, in: rect)
        }
        if let overlay { context.draw(overlay, in: rect) }
    }

    private func generateThumbnail(for url: URL, baseName: String) -> String? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        guard let cgImage = try? generator.copyCGImage(at: CMTime(seconds: 0, preferredTimescale: 600), actualTime: nil) else { return nil }
        guard let jpeg = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.7) else { return nil }

        let thumbName = "\(baseName)-thumb.jpg"
        do {
            try jpeg.write(to: store.directory.appendingPathComponent(thumbName))
        } catch {
            return nil
        }
        return thumbName
    }
}
#endif
