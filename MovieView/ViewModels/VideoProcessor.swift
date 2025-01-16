import SwiftUI
import AVKit
import AVFoundation
import UniformTypeIdentifiers
import AppKit

@MainActor
class VideoProcessor: ObservableObject {
    @Published var thumbnails: [VideoThumbnail] = []
    @Published var isProcessing = false
    @Published var error: String?
    @Published var density: DensityConfig = .default
    @Published var expectedThumbnailCount: Int = 0
    @Published var processingProgress: Double = 0
    
    private var currentVideoURL: URL?
    private var currentTask: Task<Void, Never>?
    private let maxThumbnails = 200
    
    private let diskCache = ThumbnailCacheManager.shared
    private let memoryCache = ThumbnailMemoryCache.shared

    func processDraggedItems(_ provider: NSItemProvider) {
        print("Processing dragged item...")
        guard provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
            print("Item is not a movie file")
            self.error = "The dropped file is not a supported video format"
            return
        }
        
        provider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { [weak self] (videoURL, error) in
            print("Loading item...")
            if let error = error {
                print("Error loading item: \(error.localizedDescription)")
                Task { @MainActor in
                    self?.error = error.localizedDescription
                }
                return
            }
            
            guard let videoURL = videoURL as? URL else {
                print("Invalid URL received")
                Task { @MainActor in
                    self?.error = "Invalid video file URL"
                }
                return
            }
            
            print("Processing video at URL: \(videoURL)")
            Task { @MainActor in
                try await self?.processVideo(url: videoURL)
            }
        }
    }

    func calculateExpectedThumbnails() {
        guard let url = currentVideoURL else {
            expectedThumbnailCount = 0
            return
        }
        
        Task {
            let asset = AVAsset(url: url)
            do {
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)
                expectedThumbnailCount = calculateThumbnailCount(duration: durationSeconds)
            } catch {
                expectedThumbnailCount = 0
            }
        }
    }
    
    func cancelProcessing() {
        currentTask?.cancel()
        isProcessing = false
        processingProgress = 0
    }
    
    private func calculateThumbnailCount(duration: Double) -> Int {
        if duration < 5 { return 4 }
        
        let base = 320.0 / 200.0 // base on thumbnail width
        let k = 10.0
        let rawCount = base + k * log(duration)
        let totalCount = Int(rawCount / density.factor)
        
        return min(totalCount, maxThumbnails)
    }
    
    func processVideo(url: URL) async throws {
        let startTime = Date()
        print("🎬 Starting video processing at \(startTime)")
        
        isProcessing = true
        processingProgress = 0
        currentVideoURL = url
        thumbnails.removeAll()
        
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        let thumbnailCount = calculateThumbnailCount(duration: durationSeconds)
        
        print("📊 Video duration: \(durationSeconds)s, generating \(thumbnailCount) thumbnails")
        
        let generator = AVAssetImageGenerator(asset: asset)
        var aspectRatio: CGFloat = 16.0 / 9.0

        // Get video track's natural size
            let tracks = try await asset.loadTracks(withMediaType: .video)
            if let videoTrack = tracks.first {
                let naturalSize = try await videoTrack.load(.naturalSize)
                aspectRatio = naturalSize.width / naturalSize.height
                
                // Calculate dimensions that maintain aspect ratio within 480px width (maximum slider size)
                let width: CGFloat = 480
                let height = width / aspectRatio
                generator.maximumSize = CGSize(width: width * 2, height: height * 2)
            } else {
                // Fallback to 16:9 if no video track found
                aspectRatio = 16.0 / 9.0
            generator.maximumSize = CGSize(width: 480 * 2, height: 270 * 2)
        }
        
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        
        // Calculate time points for thumbnails
        let timePoints = (0..<thumbnailCount).map { i -> CMTime in
            let fraction = Double(i) / Double(max(1, thumbnailCount - 1))
            let seconds = fraction * durationSeconds
            return CMTimeMakeWithSeconds(seconds, preferredTimescale: 600)
        }
        
        // Create thumbnail parameters
        let parameters = ThumbnailParameters(
            density: Float(density.factor),
            quality: .standard,
            size: ThumbnailQuality.standard.resolution,
            format: .heic
        )
        
        // Process thumbnails with caching
        for (index, time) in timePoints.enumerated() {
            let iterationStart = Date()
            try Task.checkCancellation()
            
            let timestamp = CMTimeGetSeconds(time)
            print("🖼 Processing thumbnail \(index + 1)/\(thumbnailCount) at \(String(format: "%.2f", timestamp))s")
            
            // Try to get from memory cache first
            let videoHash = try? ThumbnailCacheMetadata.generateCacheKey(for: url)
            let cacheKey = videoHash.map { hash in
                ThumbnailMemoryCache.cacheKey(
                    videoHash: hash,
                    timestamp: timestamp,
                    quality: parameters.quality
                )
            }
            
            if let hash = videoHash,
               let key = cacheKey,
               let (cachedImage, _, _) = await memoryCache.retrieve(forKey: key) {
                print("✅ Found in memory cache")
                addThumbnail(cachedImage, at: timestamp, aspectRatio: aspectRatio)
                processingProgress = Double(index + 1) / Double(thumbnailCount)
                continue
            }
            
            // Try to get from disk cache
            if let cachedImage = try? await diskCache.retrieveThumbnail(
                for: url,
                at: timestamp,
                quality: parameters.quality
            ) {
                print("💾 Found in disk cache")
                // Store in memory cache
                if let videoHash = try? ThumbnailCacheMetadata.generateCacheKey(for: url) {
                    await memoryCache.store(
                        image: cachedImage,
                        forKey: ThumbnailMemoryCache.cacheKey(
                            videoHash: videoHash,
                            timestamp: timestamp,
                            quality: parameters.quality
                        ),
                        timestamp: timestamp,
                        quality: parameters.quality
                    )
                }
                
                addThumbnail(cachedImage, at: timestamp, aspectRatio: aspectRatio)
                processingProgress = Double(index + 1) / Double(thumbnailCount)
                continue
            }
            
            // Generate new thumbnail
            do {
                print("🔄 Generating new thumbnail")
                let cgImage = try await generator.image(at: time).image
                let image = NSImage(cgImage: cgImage, size: parameters.size)
                
                // Store in both caches
                try await diskCache.storeThumbnail(
                    image,
                    for: url,
                    at: timestamp,
                    quality: parameters.quality,
                    parameters: parameters
                )
                
                if let videoHash = try? ThumbnailCacheMetadata.generateCacheKey(for: url) {
                    await memoryCache.store(
                        image: image,
                        forKey: ThumbnailMemoryCache.cacheKey(
                            videoHash: videoHash,
                            timestamp: timestamp,
                            quality: parameters.quality
                        ),
                        timestamp: timestamp,
                        quality: parameters.quality
                    )
                }
                
                addThumbnail(image, at: timestamp, aspectRatio: aspectRatio)
                processingProgress = Double(index + 1) / Double(thumbnailCount)
                
                let iterationDuration = Date().timeIntervalSince(iterationStart)
                print("⏱ Thumbnail generation took \(String(format: "%.2f", iterationDuration))s")
            } catch {
                if !error.isCancelled {
                    throw error
                }
            }
        }
        
        isProcessing = false
        processingProgress = 1.0
        
        let totalDuration = Date().timeIntervalSince(startTime)
        print("✨ Finished processing video in \(String(format: "%.2f", totalDuration))s")
    }
    
    private func addThumbnail(_ image: NSImage, at timestamp: TimeInterval, aspectRatio: CGFloat) {
        let thumbnail = VideoThumbnail(
            image: image,
            timestamp: CMTimeMakeWithSeconds(timestamp, preferredTimescale: 600),
            videoURL: currentVideoURL!,
            aspectRatio: aspectRatio
        )
        thumbnails.append(thumbnail)
    }

     func reprocessCurrentVideo() {
        guard let url = currentVideoURL else { return }
        currentTask?.cancel()
        calculateExpectedThumbnails()
        Task { @MainActor in
                try await self.processVideo(url: url)
            }
    
}
}
// MARK: - Error Handling
private extension Error {
    var isCancelled: Bool {
        (self as? CancellationError) != nil
    }
}
