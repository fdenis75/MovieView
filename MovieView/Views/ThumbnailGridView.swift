import SwiftUI
import AppKit

struct ThumbnailGridView: View {
    let thumbnails: [VideoThumbnail]
    @Binding var selectedThumbnail: VideoThumbnail?
    let isProcessing: Bool
    let emptyMessage: String
    let selectedMovie: MovieFile?
    @State private var showingIINAError = false
    @State private var thumbnailSize: Double = 320 // Default size
    @State private var hoveredThumbnail: VideoThumbnail?
    @FocusState private var isFocused: Bool
    
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: thumbnailSize, maximum: thumbnailSize * 2), spacing: 16)]
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
        let encodedPath = url.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? url.path
        let iinaURL = URL(string: "iina://open?url=\(encodedPath)&fullscreen=1")!
        NSWorkspace.shared.open(iinaURL)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if let movie = selectedMovie {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(movie.name)
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            openInIINA(url: movie.url)
                        }) {
                            Label("Open in IINA", systemImage: "play.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                   
                }
                .padding()
                .background(.background.secondary)
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            HStack {
                Image(systemName: "photo")
                Slider(
                    value: $thumbnailSize,
                    in: 160...800,
                    step: 40
                )
                Image(systemName: "photo.fill")
            }
            .padding(.horizontal)
            
            ScrollView {
                  if let movie = selectedMovie {
                 Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                        GridRow {
                            Text("Location:").foregroundStyle(.secondary)
                            Text(movie.url.deletingLastPathComponent().path)
                        }
                        GridRow {
                            Text("Size:").foregroundStyle(.secondary)
                            if let resourceValues = try? movie.url.resourceValues(forKeys: [.fileSizeKey]),
                               let size = resourceValues.fileSize {
                                Text(formatFileSize(size))
                            }
                        }
                        if let resolution = movie.resolution {
                            GridRow {
                                Text("Resolution:").foregroundStyle(.secondary)
                                Text("\(Int(resolution.width))×\(Int(resolution.height))")
                            }
                        }
                        if let codec = movie.codec {
                            GridRow {
                                Text("Codec:").foregroundStyle(.secondary)
                                Text(codec)
                            }
                        }
                        if let bitrate = movie.bitrate {
                            GridRow {
                                Text("Bitrate:").foregroundStyle(.secondary)
                                Text(formatFileSize(Int(bitrate)) + "/s")
                            }
                        }
                        if let frameRate = movie.frameRate {
                            GridRow {
                                Text("Frame Rate:").foregroundStyle(.secondary)
                                Text(String(format: "%.2f fps", frameRate))
                            }
                        }
                        GridRow {
                            Text("Modified:").foregroundStyle(.secondary)
                            if let resourceValues = try? movie.url.resourceValues(forKeys: [.contentModificationDateKey]),
                               let modDate = resourceValues.contentModificationDate {
                                Text(modDate.formatted(date: .abbreviated, time: .shortened))
                            }
                        }
                        if let duration = movie.duration {
                            GridRow {
                                Text("Duration:").foregroundStyle(.secondary)
                                Text(formatDuration(duration))
                            }
                        }
                    }
                }
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(thumbnails) { thumbnail in
                        ThumbnailView(
                            thumbnail: thumbnail,
                            size: thumbnailSize,
                            selectedThumbnail: $selectedThumbnail
                        )
                        .onHover { isHovered in
                            hoveredThumbnail = isHovered ? thumbnail : nil
                        }
                        .scaleEffect(hoveredThumbnail == thumbnail || selectedThumbnail == thumbnail ? 1.05 : 1.0)
                        .shadow(color: .black.opacity(hoveredThumbnail == thumbnail || selectedThumbnail == thumbnail ? 0.2 : 0), radius: 5)
                        .animation(.spring(response: 0.3), value: hoveredThumbnail)
                        .animation(.spring(response: 0.3), value: selectedThumbnail)
                        .background(selectedThumbnail == thumbnail ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .overlay {
                if thumbnails.isEmpty && !isProcessing {
                    Text(emptyMessage)
                        .foregroundColor(.secondary)
                }
            }
        }
        .focusable()
        .focused($isFocused)
        .onKeyPress(.leftArrow) {
            if let current = selectedThumbnail,
               let index = thumbnails.firstIndex(of: current),
               index > 0 {
                selectedThumbnail = thumbnails[index - 1]
            } else if selectedThumbnail == nil && !thumbnails.isEmpty {
                selectedThumbnail = thumbnails[0]
            }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if let current = selectedThumbnail,
               let index = thumbnails.firstIndex(of: current),
               index < thumbnails.count - 1 {
                selectedThumbnail = thumbnails[index + 1]
            } else if selectedThumbnail == nil && !thumbnails.isEmpty {
                selectedThumbnail = thumbnails[0]
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            if let current = selectedThumbnail,
               let index = thumbnails.firstIndex(of: current) {
                let columnsCount = max(1, Int(NSScreen.main?.frame.width ?? 1600) / Int(thumbnailSize))
                let newIndex = max(0, index - columnsCount)
                if newIndex != index {
                    selectedThumbnail = thumbnails[newIndex]
                }
            } else if !thumbnails.isEmpty {
                selectedThumbnail = thumbnails[0]
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if let current = selectedThumbnail,
               let index = thumbnails.firstIndex(of: current) {
                let columnsCount = max(1, Int(NSScreen.main?.frame.width ?? 1600) / Int(thumbnailSize))
                let newIndex = min(thumbnails.count - 1, index + columnsCount)
                if newIndex != index {
                    selectedThumbnail = thumbnails[newIndex]
                }
            } else if !thumbnails.isEmpty {
                selectedThumbnail = thumbnails[0]
            }
            return .handled
        }
        .alert("IINA Not Found", isPresented: $showingIINAError) {
            Button("OK", role: .cancel) {}
            Button("Install IINA") {
                if let url = URL(string: "https://iina.io") {
                    NSWorkspace.shared.open(url)
                }
            }
        } message: {
            Text("IINA is not installed. Would you like to install it?")
        }
    }
}/*
struct ThumbnailGridView: View {
    let thumbnails: [VideoThumbnail]
    @Binding var selectedThumbnail: VideoThumbnail?
    let isProcessing: Bool
    let emptyMessage: String
    let selectedMovie: MovieFile?
    @State private var showingIINAError = false
    @State private var thumbnailSize: Double = 320 // Default size
    @State private var hoveredThumbnail: VideoThumbnail?
    @State private var visibleThumbnails: [VideoThumbnail] = [] // For lazy loading
    @FocusState private var isFocused: Bool
    
    private let batchSize = 50 // Number of thumbnails to load at a time

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: thumbnailSize, maximum: thumbnailSize * 2), spacing: 16)]
    }
    
    private func loadMoreThumbnails(currentIndex: Int) {
        let nextBatch = thumbnails[currentIndex..<min(currentIndex + batchSize, thumbnails.count)]
        visibleThumbnails.append(contentsOf: nextBatch)
    }
    
    private func openInIINA(url: URL) {
        let encodedPath = url.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? url.path
        let iinaURL = URL(string: "iina://open?url=\(encodedPath)&fullscreen=1")!
        NSWorkspace.shared.open(iinaURL)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if !thumbnails.isEmpty {
                HStack {
                    Spacer()
                    Button(action: {
                        openInIINA(url: thumbnails[0].videoURL)
                    }) {
                        Label("Open in IINA", systemImage: "play.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
            }
            
            HStack {
                Image(systemName: "photo")
                Slider(
                    value: $thumbnailSize,
                    in: 160...800,
                    step: 40
                )
                Image(systemName: "photo.fill")
            }
            .padding(.horizontal)
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(visibleThumbnails) { thumbnail in
                        ThumbnailView(
                            thumbnail: thumbnail,
                            size: thumbnailSize,
                            selectedThumbnail: $selectedThumbnail
                        )
                        .onAppear {
                            if thumbnail == visibleThumbnails.last {
                                loadMoreThumbnails(currentIndex: visibleThumbnails.count)
                            }
                        }
                        .onHover { isHovered in
                            hoveredThumbnail = isHovered ? thumbnail : nil
                        }
                        .scaleEffect(hoveredThumbnail == thumbnail || selectedThumbnail == thumbnail ? 1.05 : 1.0)
                        .shadow(color: .black.opacity(hoveredThumbnail == thumbnail || selectedThumbnail == thumbnail ? 0.2 : 0), radius: 5)
                        .animation(.spring(response: 0.3), value: hoveredThumbnail)
                        .animation(.spring(response: 0.3), value: selectedThumbnail)
                        .background(selectedThumbnail == thumbnail ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .overlay {
                if thumbnails.isEmpty && !isProcessing {
                    Text(emptyMessage)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            loadMoreThumbnails(currentIndex: 0)
        }
        .focusable()
        .focused($isFocused)
    }
}
*/
