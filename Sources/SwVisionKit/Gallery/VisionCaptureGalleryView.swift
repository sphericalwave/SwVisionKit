#if os(iOS)
import SwiftUI

public struct VisionCaptureGalleryView: View {
    @ObservedObject var store: VisionCaptureStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected: VisionCaptureRecord?

    public init(store: VisionCaptureStore) {
        self.store = store
    }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 4)]

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(store.records) { record in
                        VisionCaptureThumbnail(record: record, store: store)
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
                .padding(4)
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
