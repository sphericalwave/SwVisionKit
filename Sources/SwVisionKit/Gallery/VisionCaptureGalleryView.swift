#if os(iOS)
import SwiftUI

public struct VisionCaptureGalleryView: View {
    @ObservedObject var store: VisionCaptureStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected: VisionCaptureRecord?

    public init(store: VisionCaptureStore) {
        self.store = store
    }

    private let columnCount = 3
    private let spacing: CGFloat = 3
    private let cornerRadius: CGFloat = 10

    public var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                // Explicit, definite cell size computed from the container
                // width — GridItem(.flexible())/.adaptive() combined with
                // VisionCaptureThumbnail's own aspectRatio modifier produced
                // unpredictable/overlapping cell sizing (each cell resolving
                // its size differently against the placeholder vs. the
                // loaded image). Pinning an exact frame on every cell removes
                // that ambiguity entirely.
                let cellSize = (proxy.size.width - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount)
                let columns = Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: columnCount)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: spacing) {
                        ForEach(store.records) { record in
                            VisionCaptureThumbnail(record: record, store: store, aspectRatio: 1)
                                .frame(width: cellSize, height: cellSize)
                                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
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
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Vision Captures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                VisionCapturePlayerView(store: store, initial: record)
            }
        }
    }
}
#endif
