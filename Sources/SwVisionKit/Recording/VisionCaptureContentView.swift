#if os(iOS)
import SwiftUI

/// The only view ever shown live *and* fed to the compositor: camera preview
/// + pose overlay + HUD, nothing else. Toolbar, bottom-left thumbnail, and any
/// "recording…" indicator live one level up in `PostureCameraView` and are
/// structurally never part of this view — that's what makes toolbar exclusion
/// from recordings/photos a guarantee rather than a crop/hide trick.
public struct VisionCaptureContentView: View {
    @ObservedObject var detector: PoseDetectionService
    let report: PostureReport?

    public init(detector: PoseDetectionService, report: PostureReport?) {
        self.detector = detector
        self.report = report
    }

    public var body: some View {
        ZStack {
            CameraPreviewView(captureSession: detector.captureSession)
            PoseOverlayCanvas(pose: detector.pose)
            VStack {
                PostureHUDView(report: report)
                    .padding(.top, 12)
                Spacer()
            }
        }
    }
}
#endif
