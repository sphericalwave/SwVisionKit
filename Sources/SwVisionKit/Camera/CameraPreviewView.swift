#if os(iOS)
import SwiftUI
import AVFoundation

public struct CameraPreviewView: UIViewRepresentable {
    let captureSession: AVCaptureSession

    public init(captureSession: AVCaptureSession) {
        self.captureSession = captureSession
    }

    public func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = captureSession
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    public func updateUIView(_ uiView: PreviewUIView, context: Context) { }
}

// Using layerClass makes the UIView's own backing layer an AVCaptureVideoPreviewLayer,
// so its frame always matches the view bounds automatically — no manual frame sync needed.
public final class PreviewUIView: UIView {
    override public class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
#endif
