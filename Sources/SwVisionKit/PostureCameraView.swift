#if os(iOS)
import SwiftUI

public struct PostureCameraView: View {
    private enum CaptureMode {
        case photo, video
    }

    @StateObject private var detector: PoseDetectionService
    @StateObject private var store = PostureStore()
    @StateObject private var captureStore: VisionCaptureStore
    @StateObject private var compositor: VisionCaptureCompositor

    @Environment(\.dismiss) private var dismiss
    @Environment(\.isPresented) private var isPresented
    @State private var recordingsPresented = false
    @State private var galleryPresented = false
    @State private var didRecord = false
    @State private var captureMode: CaptureMode = .video

    public init() {
        let detector = PoseDetectionService()
        let captureStore = VisionCaptureStore()
        _detector = StateObject(wrappedValue: detector)
        _captureStore = StateObject(wrappedValue: captureStore)
        _compositor = StateObject(wrappedValue: VisionCaptureCompositor(
            detector: detector,
            store: captureStore,
            report: { detector.pose.flatMap(PostureAnalyzer.analyze) }
        ))
    }

    private var report: PostureReport? {
        detector.pose.flatMap(PostureAnalyzer.analyze)
    }

    public var body: some View {
        ZStack {
            VisionCaptureContentView(detector: detector, report: report)

            VStack {
                if compositor.isRecording {
                    recordingBadge
                        .padding(.top, 8)
                }
                Spacer()
                ZStack {
                    captureControls

                    HStack {
                        VisionCaptureBottomThumbnail(store: captureStore) { galleryPresented = true }
                            .padding(.leading, 16)
                        Spacer()
                    }
                }
                .padding(.bottom, 12)
            }

            // Brief "Saved" confirmation
            if didRecord {
                VStack {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.green.opacity(0.85), in: Capsule())
                        .padding(.top, 12)
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .navigationTitle("Posture Check")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { detector.flip() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                }
                .disabled(compositor.isRecording)
            }
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 16) {
                    // Record current text reading
                    Button {
                        let r = report ?? PostureReport(postureClass: .unknown, spineAngle: 0, hipTilt: nil, shoulderTilt: nil)
                        store.record(r)
                        showSaved()
                    } label: {
                        Image(systemName: "record.circle")
                    }
                    .tint(.red)

                    // Text-reading history
                    Button { recordingsPresented = true } label: {
                        Image(systemName: "list.bullet.clipboard")
                    }
                    .badge(store.snapshots.count)

                    if isPresented {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
        .sheet(isPresented: $recordingsPresented) {
            PostureRecordingsView(store: store)
        }
        .sheet(isPresented: $galleryPresented) {
            VisionCaptureGalleryView(store: captureStore)
        }
        .task { detector.start() }
        .onDisappear { detector.stop() }
    }

    /// Bottom control area, centered above the tab bar. Swaps entirely
    /// between an idle row (thumbnail / mode toggle / shutter) and a
    /// recording row (pause-resume / stop / capture-still), matching Apple
    /// Camera's own control set rather than trying to keep one button doing
    /// double duty.
    @ViewBuilder
    private var captureControls: some View {
        if compositor.isRecording {
            recordingControls
        } else {
            idleControls
        }
    }

    private var idleControls: some View {
        HStack(spacing: 28) {
            Button {
                captureMode = (captureMode == .photo) ? .video : .photo
            } label: {
                Image(systemName: captureMode == .video ? "video.fill" : "camera.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.black.opacity(0.35), in: Circle())
            }

            Button {
                switch captureMode {
                case .photo:
                    if compositor.capturePhoto() != nil { showSaved() }
                case .video:
                    compositor.startVideoRecording()
                }
            } label: {
                ZStack {
                    Circle().stroke(.white, lineWidth: 3).frame(width: 34, height: 34)
                    Circle().fill(captureMode == .video ? .red : .white).frame(width: 26, height: 26)
                }
            }
        }
    }

    /// Pause/resume (leading), stop (center), capture-still (trailing) — the
    /// same three controls Apple's Camera app shows once video recording
    /// starts.
    private var recordingControls: some View {
        HStack(spacing: 36) {
            Button {
                if compositor.isPaused {
                    compositor.resumeVideoRecording()
                } else {
                    compositor.pauseVideoRecording()
                }
            } label: {
                Image(systemName: compositor.isPaused ? "play.fill" : "pause.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.black.opacity(0.35), in: Circle())
            }

            Button {
                Task {
                    if await compositor.stopVideoRecording() != nil { showSaved() }
                }
            } label: {
                ZStack {
                    Circle().stroke(.white, lineWidth: 3).frame(width: 34, height: 34)
                    RoundedRectangle(cornerRadius: 4).fill(.red).frame(width: 16, height: 16)
                }
            }

            Button {
                if compositor.capturePhoto() != nil { showSaved() }
            } label: {
                ZStack {
                    Circle().stroke(.white, lineWidth: 3).frame(width: 34, height: 34)
                    Circle().fill(.white).frame(width: 26, height: 26)
                }
            }
        }
    }

    private var recordingBadge: some View {
        Label(elapsedLabel, systemImage: compositor.isPaused ? "pause.circle.fill" : "record.circle.fill")
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.red.opacity(0.85), in: Capsule())
    }

    private var elapsedLabel: String {
        let s = Int(compositor.elapsed.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func showSaved() {
        withAnimation { didRecord = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation { didRecord = false }
        }
    }
}
#endif
