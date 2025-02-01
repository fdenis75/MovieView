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
    @Environment(\.colorScheme) private var colorScheme
    
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
        let iinaURL = URL(string: "iina://weblink?url=\(thumbnail.videoURL.absoluteString)")!
        NSWorkspace.shared.open(iinaURL)
    }

    private var overlayContent: some View {
        HStack {
            Text(thumbnail.formattedTime)
                .font(.caption)
                .padding(DesignSystem.Spacing.xxsmall)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
            
            Spacer()
            
            Button(action: openInIINA) {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .padding(DesignSystem.Spacing.xxsmall)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
        }
        .padding(DesignSystem.Spacing.small)
    }
    
    private var videoPreview: some View {
        VideoPlayer(player: previewPlayer!)
            .frame(
                width: isForcePressed ? size * 1.6 : size,
                height: isForcePressed ? (size * 1.6/thumbnail.aspectRatio) : size/thumbnail.aspectRatio
            )
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            .overlay { Color.black.opacity(0.2) }
            .overlay(alignment: .bottom) { overlayContent }
    }
    
    private var thumbnailImage: some View {
        Image(nsImage: thumbnail.image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(
                width: isForcePressed ? size * 1.6 : size,
                height: isForcePressed ? (size * 1.6/thumbnail.aspectRatio) : size/thumbnail.aspectRatio
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            .overlay { Color.black.opacity(0.2) }
            .overlay(alignment: .bottom) { overlayContent }
            .overlay(
                Group {
                    if thumbnail.isSceneChange {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .stroke(Color.yellow, lineWidth: 2)
                            .overlay(
                                Image(systemName: "camera.filters")
                                    .foregroundColor(.yellow)
                                    .padding(DesignSystem.Spacing.xxsmall)
                                    .background(.black.opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                                    .padding(DesignSystem.Spacing.xxsmall),
                                alignment: .topLeading
                            )
                    }
                }
            )
    }
    
    var body: some View {
        Group {
            if let player = previewPlayer {
                videoPreview
            } else {
                thumbnailImage
            }
        }
        .onTapGesture {
            selectedThumbnail = thumbnail
        }
        .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 50) {
            isForcePressed = true
            let player = AVPlayer(url: thumbnail.videoURL)
            player.seek(to: CMTime(seconds: thumbnail.time, preferredTimescale: 600))
            previewPlayer = player
            player.play()
        } onPressingChanged: { isPressing in
            if !isPressing {
                isForcePressed = false
                previewPlayer?.pause()
                previewPlayer = nil
            }
        }
        .animation(.spring(response: DesignSystem.Animation.quick), value: isForcePressed)
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
