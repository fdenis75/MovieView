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
} 
