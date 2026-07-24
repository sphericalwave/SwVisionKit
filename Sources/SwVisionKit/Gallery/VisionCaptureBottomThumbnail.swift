#if os(iOS)
import SwiftUI

/// The bottom-left "last video" thumbnail on `PostureCameraView` — tapping
/// opens the full gallery. Hidden until there's at least one saved video.
public struct VisionCaptureBottomThumbnail: View {
    @ObservedObject var store: VisionCaptureStore
    let action: () -> Void

    public init(store: VisionCaptureStore, action: @escaping () -> Void) {
        self.store = store
        self.action = action
    }

    public var body: some View {
        if let last = store.lastVideo {
            Button(action: action) {
                VisionCaptureThumbnail(record: last, store: store)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white, lineWidth: 2))
                    .shadow(radius: 3)
            }
        }
    }
}
#endif
