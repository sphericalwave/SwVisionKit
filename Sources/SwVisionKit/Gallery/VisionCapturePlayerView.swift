#if os(iOS)
import SwiftUI
import AVFoundation

/// Full-screen swipeable viewer over every saved capture — Photos-app style:
/// back button, swipe left/right between items (`TabView(.page)`), a
/// filmstrip of thumbnails to jump directly to one, and (for video) a custom
/// play/pause + scrub + mute bar. Share and delete at the bottom.
public struct VisionCapturePlayerView: View {
    @ObservedObject var store: VisionCaptureStore
    @Environment(\.dismiss) private var dismiss
    @State private var selection: UUID

    public init(store: VisionCaptureStore, initial: VisionCaptureRecord) {
        self.store = store
        _selection = State(initialValue: initial.id)
    }

    private var currentRecord: VisionCaptureRecord? {
        store.records.first { $0.id == selection }
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $selection) {
                    ForEach(store.records) { record in
                        VisionCapturePage(record: record, store: store)
                            .tag(record.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                filmstrip
                    .padding(.vertical, 10)

                bottomToolbar
                    .padding(.bottom, 8)
            }
        }
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .padding(.top, 8)
            .padding(.leading, 12)
        }
        .onChange(of: store.records.map(\.id)) { _, ids in
            // If the current item was deleted from elsewhere, or the list
            // becomes empty, don't strand the view on a dangling selection.
            if ids.isEmpty {
                dismiss()
            } else if !ids.contains(selection) {
                selection = ids[0]
            }
        }
    }

    private var filmstrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(store.records) { record in
                        VisionCaptureThumbnail(record: record, store: store, aspectRatio: 1)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(record.id == selection ? Color.white : .clear, lineWidth: 2)
                            )
                            .id(record.id)
                            .onTapGesture {
                                withAnimation { selection = record.id }
                            }
                    }
                }
                .padding(.horizontal, 12)
            }
            .onChange(of: selection) { _, newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
    }

    private var bottomToolbar: some View {
        HStack {
            if let current = currentRecord {
                ShareLink(item: store.fileURL(for: current)) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.4), in: Circle())
                }
            }

            Spacer()

            Button {
                if let current = currentRecord {
                    deleteCurrent(current)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.4), in: Circle())
            }
        }
        .padding(.horizontal, 24)
    }

    private func deleteCurrent(_ record: VisionCaptureRecord) {
        let ids = store.records.map(\.id)
        guard let index = ids.firstIndex(of: record.id) else { return }
        store.delete(record)

        let remaining = store.records
        if remaining.isEmpty {
            dismiss()
        } else {
            selection = remaining[min(index, remaining.count - 1)].id
        }
    }
}

private struct VisionCapturePage: View {
    let record: VisionCaptureRecord
    @ObservedObject var store: VisionCaptureStore

    var body: some View {
        switch record.kind {
        case .photo:
            PhotoPage(record: record, store: store)
        case .video:
            VideoPage(record: record, store: store)
        }
    }
}

private struct PhotoPage: View {
    let record: VisionCaptureRecord
    @ObservedObject var store: VisionCaptureStore
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView().tint(.white)
            }
        }
        .task(id: record.id) {
            if let data = try? Data(contentsOf: store.fileURL(for: record)) {
                image = UIImage(data: data)
            }
        }
    }
}

private struct VideoPage: View {
    let record: VisionCaptureRecord
    @ObservedObject var store: VisionCaptureStore
    @StateObject private var playback = VideoPlaybackController()

    var body: some View {
        ZStack {
            if let player = playback.player {
                VideoPlayerLayerView(player: player)
            } else {
                ProgressView().tint(.white)
            }

            VStack {
                Spacer()
                controls
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .onAppear {
            playback.load(url: store.fileURL(for: record))
            playback.play()
        }
        .onDisappear {
            playback.stop()
        }
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button {
                playback.togglePlayPause()
            } label: {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .foregroundStyle(.white)
            }

            Slider(
                value: $playback.currentTime,
                in: 0...max(playback.duration, 0.1),
                onEditingChanged: { editing in
                    playback.isScrubbing = editing
                    if !editing { playback.seek(to: playback.currentTime) }
                }
            )
            .tint(.white)

            Button {
                playback.toggleMute()
            } label: {
                Image(systemName: playback.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.5), in: Capsule())
    }
}
#endif
