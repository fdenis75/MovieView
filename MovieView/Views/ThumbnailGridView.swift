import SwiftUI
import AppKit

struct ThumbnailGridView: View {
    let thumbnails: [VideoThumbnail]
    @Binding var selectedThumbnail: VideoThumbnail?
    let isProcessing: Bool
    let emptyMessage: String
    let selectedMovie: MovieFile?
    let videoProcessor: VideoProcessor
    @State private var showingIINAError = false
    @State private var thumbnailSize: Double = 320 // Default size
    @State private var hoveredThumbnail: VideoThumbnail?
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: thumbnailSize, maximum: thumbnailSize * 2), spacing: DesignSystem.Spacing.medium)]
    }
    
    // MARK: - Helper Views
    private var movieInfoView: some View {
        Group {
            if let movie = selectedMovie {
                MovieInfoCard(
                    movie: movie,
                    onOpenIINA: { openInIINA(url: movie.url) },
                    expectedThumbnailCount: videoProcessor.expectedThumbnailCount
                )
            }
        }
    }
    
    private var thumbnailSizeControl: some View {
        HStack {
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
            Slider(value: $thumbnailSize, in: 160...800, step: 40)
                .frame(maxWidth: 300)
            Image(systemName: "photo.fill")
                .foregroundStyle(.secondary)
            
           
                Spacer()
                Button(action: playAllInIINA) {
                    Label("Play All", systemImage: "play.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            
        }
        .padding(.horizontal)
        .padding(.vertical, DesignSystem.Spacing.small)
        .background(.ultraThinMaterial)
    }
    
    private var thumbnailGrid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.medium) {
                    ForEach(thumbnails) { thumbnail in
                        ThumbnailCell(
                            thumbnail: thumbnail,
                            size: thumbnailSize,
                            selectedThumbnail: $selectedThumbnail,
                            hoveredThumbnail: $hoveredThumbnail
                        )
                        .id(thumbnail.id)
                        .matchedGeometryEffect(id: thumbnail.id, in: namespace)
                    }
                }
                .padding(DesignSystem.Spacing.medium)
            }
            .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.1))
            .overlay {
                if thumbnails.isEmpty && !isProcessing {
                    EmptyStateView(message: emptyMessage)
                }
            }
            .onChange(of: selectedThumbnail) { thumbnail in
                if let thumbnail = thumbnail {
                    withAnimation(.spring(response: 0.3)) {
                        proxy.scrollTo(thumbnail.id, anchor: .center)
                    }
                }
            }
        }
    }
    
    @Namespace private var namespace
    @State private var isGridVisible = false
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            movieInfoView
                .transition(.move(edge: .top).combined(with: .opacity))
            
            thumbnailSizeControl
                .transition(.move(edge: .top).combined(with: .opacity))
            
            thumbnailGrid
                .transition(.opacity)
        }
        .animation(.spring(response: 0.3), value: selectedMovie)
        .animation(.spring(response: 0.3), value: thumbnailSize)
        .focusable()
        .focused($isFocused)
        .onKeyPress(.leftArrow) {
            if let current = selectedThumbnail,
               let index = thumbnails.firstIndex(of: current),
               index > 0 {
                withAnimation(.spring(response: 0.3)) {
                    selectedThumbnail = thumbnails[index - 1]
                }
            }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if let current = selectedThumbnail,
               let index = thumbnails.firstIndex(of: current),
               index < thumbnails.count - 1 {
                withAnimation(.spring(response: 0.3)) {
                    selectedThumbnail = thumbnails[index + 1]
                }
            }
            return .handled
        }
        .onAppear {
            withAnimation(.spring(response: 0.5).delay(0.1)) {
                isGridVisible = true
            }
        }
        .alert("IINA Not Installed", isPresented: $showingIINAError) {
            Button("Install IINA") {
                NSWorkspace.shared.open(URL(string: "https://iina.io")!)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("IINA is not installed. Would you like to install it?")
        }
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
    
    private func openInIINA(url: URL) {
        let iinaURL = URL(string: "iina://weblink?url=\(url.absoluteString)")!
        if !NSWorkspace.shared.open(iinaURL) {
            showingIINAError = true
        }
    }
    
    private func playAllInIINA() {
        do {
            let urls = thumbnails.map(\.videoURL)
            let tempDir = FileManager.default.temporaryDirectory
            let playlistURL = try PlaylistGenerator.createM3U8(from: urls, at: tempDir)
            let iinaURL = URL(string: "iina://open?url=\(playlistURL.absoluteString)")!
            if !NSWorkspace.shared.open(iinaURL) {
                showingIINAError = true
            }
        } catch {
            // Handle error appropriately
            print("Error creating playlist: \(error)")
        }
    }
}
/*
// MARK: - MovieInfoCard
struct MovieInfoCard: View {
    let movie: MovieFile
    let onOpenIINA: () -> Void
    let expectedThumbnailCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    HStack {
                        Text(movie.name)
                            .font(.headline)
                        Spacer()
                Button(action: onOpenIINA) {
                            Label("Open in IINA", systemImage: "play.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
            MovieInfoGrid(movie: movie)
                }
        .cardStyle()
                .padding(.horizontal)
    }
}
*/
// MARK: - MovieInfoGrid
struct MovieInfoGrid: View {
    let movie: MovieFile
    
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: DesignSystem.Spacing.medium, verticalSpacing: DesignSystem.Spacing.xxsmall) {
            MovieInfoRow(label: "Location:", value: movie.url.deletingLastPathComponent().path)
                .textSelection(.enabled)
            
            if let resourceValues = try? movie.url.resourceValues(forKeys: [.fileSizeKey]),
               let size = resourceValues.fileSize {
                MovieInfoRow(label: "Size:", value: formatFileSize(size))
            }
            
            if let resolution = movie.resolution {
                MovieInfoRow(label: "Resolution:", value: "\(Int(resolution.width))×\(Int(resolution.height))")
            }
            
                        if let codec = movie.codec {
                MovieInfoRow(label: "Codec:", value: codec)
            }
            
            if let bitrate = movie.bitrate {
                MovieInfoRow(label: "Bitrate:", value: formatFileSize(Int(bitrate)) + "/s")
            }
            
            if let frameRate = movie.frameRate {
                MovieInfoRow(label: "Frame Rate:", value: String(format: "%.2f fps", frameRate))
            }
            
            if let resourceValues = try? movie.url.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = resourceValues.contentModificationDate {
                MovieInfoRow(label: "Modified:", value: modDate.formatted(date: .abbreviated, time: .shortened))
            }
            
            if let duration = movie.duration {
                MovieInfoRow(label: "Duration:", value: formatDuration(duration))
            }
        }
    }
    
    private func formatFileSize(_ size: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
}

// MARK: - MovieInfoRow
struct MovieInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value)
        }
    }
}

// MARK: - ThumbnailCell
private struct ThumbnailCell: View {
    let thumbnail: VideoThumbnail
    let size: Double
    @Binding var selectedThumbnail: VideoThumbnail?
    @Binding var hoveredThumbnail: VideoThumbnail?
    
    private var isSelected: Bool {
        selectedThumbnail == thumbnail
    }
    
    private var isHovered: Bool {
        hoveredThumbnail == thumbnail
    }
    
    var body: some View {
                        ThumbnailView(
                            thumbnail: thumbnail,
            size: size,
                            selectedThumbnail: $selectedThumbnail
                        )
          
        .hoverEffect(scale: 1.05)
        .shadow(
            color: (isHovered || isSelected) ? DesignSystem.Shadow.large : DesignSystem.Shadow.small,
            radius: (isHovered || isSelected) ? 10 : 5
        )
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: { selectedThumbnail = thumbnail }) {
                Label("Select", systemImage: "checkmark.circle")
            }
            Button(action: { NSWorkspace.shared.selectFile(thumbnail.videoURL.path, inFileViewerRootedAtPath: thumbnail.videoURL.deletingLastPathComponent().path) }) {
                Label("Show in Finder", systemImage: "folder")
            }
            Button(action: { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(thumbnail.videoURL.path, forType: .string) }) {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
        }
    }
}

// MARK: - EmptyStateView
private struct EmptyStateView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .symbolEffect(.bounce, options: .repeating)
            Text(message)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .transition(.opacity.combined(with: .scale))
    }
}
