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
                .ignoresSafeArea()

            VStack {
                if compositor.isRecording {
                    recordingBadge
                        .padding(.top, 8)
                }
                Spacer()
                HStack {
                    VisionCaptureBottomThumbnail(store: captureStore) { galleryPresented = true }
                        .padding(.leading, 16)
                        .padding(.bottom, 100)
                    Spacer()
                }
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
                        .padding(.top, 80)
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .navigationTitle("Posture Check")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { detector.flip() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                }
                .tint(.white)
                .disabled(compositor.isRecording)
            }
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 16) {
                    // Photo/video mode toggle
                    Button {
                        captureMode = (captureMode == .photo) ? .video : .photo
                    } label: {
                        Image(systemName: captureMode == .video ? "video.fill" : "camera.fill")
                    }
                    .tint(.white)
                    .disabled(compositor.isRecording)

                    // Photo/video shutter
                    Button { handleShutter() } label: {
                        shutterIcon
                    }

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
                    .tint(.white)
                    .badge(store.snapshots.count)

                    if isPresented {
                        Button("Done") { dismiss() }
                            .tint(.white)
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

    private var shutterIcon: some View {
        ZStack {
            Circle()
                .stroke(.white, lineWidth: 3)
                .frame(width: 34, height: 34)
            if captureMode == .video && compositor.isRecording {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.red)
                    .frame(width: 16, height: 16)
            } else {
                Circle()
                    .fill(.red)
                    .frame(width: 26, height: 26)
            }
        }
    }

    private var recordingBadge: some View {
        Label(elapsedLabel, systemImage: "record.circle.fill")
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

    private func handleShutter() {
        switch captureMode {
        case .photo:
            if compositor.capturePhoto() != nil { showSaved() }
        case .video:
            if compositor.isRecording {
                Task {
                    if await compositor.stopVideoRecording() != nil { showSaved() }
                }
            } else {
                compositor.startVideoRecording()
            }
        }
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
