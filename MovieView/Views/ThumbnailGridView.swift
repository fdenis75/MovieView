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
