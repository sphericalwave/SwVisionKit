#if os(iOS)
import SwiftUI

public struct VisionCaptureGalleryView: View {
    @ObservedObject var store: VisionCaptureStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected: VisionCaptureRecord?

    public init(store: VisionCaptureStore) {
        self.store = store
    }

    // Fixed 3-column flexible grid (not `.adaptive`) — `.adaptive` combined
    // with `VisionCaptureThumbnail`'s `aspectRatio` modifier produced
    // unpredictable/overlapping cell sizing. Flexible columns give each cell
    // an exact, evenly-divided width to resolve its aspect ratio against.
    // Square crop + tight spacing matches the stock Photos library grid.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(store.records) { record in
                        VisionCaptureThumbnail(record: record, store: store, aspectRatio: 1)
                            .onTapGesture { selected = record }
                            .contextMenu {
                                Button(role: .destructive) {
                                    store.delete(record)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .navigationTitle("Vision Captures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if store.records.isEmpty {
                    ContentUnavailableView(
                        "No Captures",
                        systemImage: "photo.on.rectangle",
                        description: Text("Recorded photos and videos will show up here.")
                    )
                }
            }
            .fullScreenCover(item: $selected) { record in
                VisionCapturePlayerView(record: record, store: store)
            }
        }
    }
}
#endif
