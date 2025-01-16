import SwiftUI
import AVKit
import AppKit

struct ThumbnailView: View {
    let thumbnail: VideoThumbnail
    let size: Double
    @State private var isHovering = false
    @Binding var selectedThumbnail: VideoThumbnail?
    @State private var previewPlayer: AVPlayer?
    @State private var opacity: Double = 0
    @State private var showingIINAError = false
    @State private var isForcePressed = false
    /*
    private func openInIINA() {
        let encodedPath = thumbnail.videoURL.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? thumbnail.videoURL.path
        let timestamp = Int(CMTimeGetSeconds(thumbnail.timestamp))
        let iinaURL = URL(string: "iina://open?url=\(encodedPath)&fullscreen=1&mpv-start=\(timestamp)")!
        
        do {
            try NSWorkspace.shared.open(iinaURL)
        } catch {
            showingIINAError = true
        }
    }*/
    
    private func openInIINA() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/Applications/IINA.app/Contents/MacOS/iina-cli")
        let encodedPath = thumbnail.videoURL.path
        task.arguments = ["\(encodedPath)", "--mpv-start=\(Int(CMTimeGetSeconds(thumbnail.timestamp)))"]
        
        do {
            try task.run()
        } catch {
            showingIINAError = true
        }
    }

    private var overlayContent: some View {
        HStack {
            Text(thumbnail.formattedTime)
                .font(.caption)
                .padding(4)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            Spacer()
            
            Button(action: openInIINA) {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .padding(4)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(8)
    }
    
    private var videoPreview: some View {
        VideoPlayer(player: previewPlayer!)
            .frame(width: isForcePressed ? size * 1.6 : size, height: isForcePressed ? (size * 1.6/thumbnail.aspectRatio) : size/thumbnail.aspectRatio)
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay { Color.black.opacity(0.2) }
            .overlay(alignment: .bottom) { overlayContent }
    }
    
    private var thumbnailImage: some View {
        Image(nsImage: thumbnail.image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: isForcePressed ? size * 1.6 : size, height: isForcePressed ? (size * 1.6/thumbnail.aspectRatio) : size/thumbnail.aspectRatio)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay { Color.black.opacity(0.2) }
            .overlay(alignment: .bottom) { overlayContent }
            .overlay(
                    Group {
                        if thumbnail.isSceneChange {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.yellow, lineWidth: 2)
                                .overlay(
                                    Image(systemName: "camera.filters")
                                        .foregroundColor(.yellow)
                                        .padding(4)
                                        .background(.black.opacity(0.6))
                                        .cornerRadius(4)
                                        .padding(4),
                                    alignment: .topLeading
                                )
                        }
                    }
                )
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isHovering, let player = previewPlayer {
                    videoPreview
                } else {
                    thumbnailImage
                }
            }
            .scaleEffect(isForcePressed ? 2.0 : 1.0)
        }
        .frame(width: isForcePressed ? size * 1.6 : size, height: isForcePressed ? (size * 1.6/thumbnail.aspectRatio) : size/thumbnail.aspectRatio)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.5)) {
                opacity = 1
            }
        }
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                let player = AVPlayer(url: thumbnail.videoURL)
                player.isMuted = true
                player.seek(to: thumbnail.timestamp)
                player.play()
                
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: player.currentItem,
                    queue: .main
                ) { _ in
                    player.seek(to: thumbnail.timestamp)
                    player.play()
                }
                
                previewPlayer = player
            } else {
                previewPlayer?.pause()
                previewPlayer = nil
                if !isForcePressed {
                    withAnimation {
                        isForcePressed = false
                    }
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring()) {
                        isForcePressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring()) {
                        isForcePressed = false
                    }
                }
        )
        .onTapGesture(count: 2) { openInIINA() }
        .onTapGesture(count: 1) { selectedThumbnail = thumbnail }
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
