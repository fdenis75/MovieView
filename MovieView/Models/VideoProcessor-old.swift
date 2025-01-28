/* 
import Foundation
import AVKit
import AppKit

@MainActor
class VideoProcessor: ObservableObject {
    @Published var thumbnails: [VideoThumbnail] = []
    @Published var isProcessing = false
    @Published var error: Error?
    @Published var density: DensityConfig = .default
    @Published var processingProgress: Double = 0
    @Published var expectedThumbnailCount: Int = 0
    
    private var currentVideoURL: URL?
    private var currentTask: Task<Void, Never>?
    private let maxThumbnails = 200
    
    private let diskCache = ThumbnailCacheManager.shared
    private let memoryCache = ThumbnailMemoryCache.shared
    
    func processDraggedItems(_ provider: NSItemProvider) {
        Logger.videoProcessing.info("Processing dragged item...")
        guard provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
            Logger.videoProcessing.error("Item is not a movie file")
            self.error = AppError.invalidVideoFile(URL(fileURLWithPath: ""))
            return
        }
        
        provider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { [weak self] (videoURL, error) in
            Logger.videoProcessing.info("Loading item...")
            if let error = error {
                Logger.videoProcessing.error("Error loading item: \(error.localizedDescription)")
                Task { @MainActor in
                    self?.error = AppError.unknownError(error.localizedDescription)
                }
                return
            }
            
            guard let videoURL = videoURL as? URL else {
                Logger.videoProcessing.error("Invalid URL received")
                Task { @MainActor in
                    self?.error = AppError.invalidVideoFile(URL(fileURLWithPath: ""))
                }
                return
            }
            
            Logger.videoProcessing.info("Processing video at URL: \(videoURL.path)")
            Task { @MainActor in
                do {
                    try await self?.processVideo(url: videoURL)
                } catch {
                    Logger.videoProcessing.error("Error processing video: \(error.localizedDescription)")
                    self?.error = error
                }
            }
        }
    }
    
    func processVideo(url: URL) async throws {
        Logger.videoProcessing.info("Starting video processing for: \(url.lastPathComponent)")
        
        // Check if file exists and is accessible
        guard FileManager.default.fileExists(atPath: url.path) else {
            Logger.videoProcessing.error("File not found: \(url.path)")
            throw AppError.fileNotFound(url)
        }
        
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            Logger.videoProcessing.error("File not accessible: \(url.path)")
            throw AppError.fileNotAccessible(url)
        }
        
        isProcessing = true
        currentVideoURL = url
        thumbnails.removeAll()
        processingProgress = 0
        
        let startTime = Date()
        currentTask?.cancel()
        
        currentTask = Task {
            do {
                let asset = AVAsset(url: url)
                
                // Validate video file
                guard try await asset.load(.tracks).first(where: { try await $0.load(.mediaType) == .video }) != nil else {
                    Logger.videoProcessing.error("No video track found in file: \(url.path)")
                    throw AppError.invalidVideoFile(url)
                }
                
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)
                
                guard durationSeconds > 0 else {
                    Logger.videoProcessing.error("Invalid video duration for file: \(url.path)")
                    throw AppError.invalidVideoFile(url)
                }
                
                let thumbnailCount = calculateThumbnailCount(duration: durationSeconds)
                expectedThumbnailCount = thumbnailCount
                
                Logger.videoProcessing.info("Generating \(thumbnailCount) thumbnails for video of duration \(durationSeconds)s")
                
                let generator = AVAssetImageGenerator(asset: asset)
                generator.requestedTimeToleranceBefore = .zero
                generator.requestedTimeToleranceAfter = .zero
                
                var aspectRatio: CGFloat = 16.0 / 9.0
                if let videoTrack = try await asset.loadTracks(withMediaType: .video).first {
                    let naturalSize = try await videoTrack.load(.naturalSize)
                    aspectRatio = naturalSize.width / naturalSize.height
                    generator.maximumSize = CGSize(width: 480, height: 480 / aspectRatio)
                }
                
                let timePoints = stride(from: 0.0, to: durationSeconds, by: durationSeconds / Double(thumbnailCount))
                    .map { CMTime(seconds: $0, preferredTimescale: 600) }
                
                for (index, time) in timePoints.enumerated() {
                    try Task.checkCancellation()
                    
                    do {
                        let cgImage = try await generator.image(at: time).image
                        let thumbnail = VideoThumbnail(
                            image: NSImage(cgImage: cgImage, size: NSSizeFromCGSize(generator.maximumSize)),
                            timestamp: time,
                            videoURL: url,
                            aspectRatio: aspectRatio
                        )
                        thumbnails.append(thumbnail)
                        processingProgress = Double(index + 1) / Double(thumbnailCount)
                    } catch {
                        Logger.videoProcessing.error("Failed to generate thumbnail at \(CMTimeGetSeconds(time))s: \(error.localizedDescription)")
                        throw AppError.thumbnailGenerationFailed(url, error.localizedDescription)
                    }
                }
                
                let totalDuration = Date().timeIntervalSince(startTime)
                Logger.videoProcessing.info("Finished processing video in \(String(format: "%.2f", totalDuration))s")
                
                isProcessing = false
                processingProgress = 1.0
                
            } catch is CancellationError {
                Logger.videoProcessing.info("Video processing cancelled")
                isProcessing = false
                processingProgress = 0
            } catch {
                Logger.videoProcessing.error("Video processing failed: \(error.localizedDescription)")
                self.error = error
                isProcessing = false
                processingProgress = 0
            }
        }
    }
    
    func cancelProcessing() {
        Logger.videoProcessing.info("Cancelling video processing")
        currentTask?.cancel()
        currentTask = nil
        isProcessing = false
        processingProgress = 0
    }
    
    func reprocessCurrentVideo() {
        guard let url = currentVideoURL else {
            Logger.videoProcessing.warning("No video to reprocess")
            return
        }
        Logger.videoProcessing.info("Reprocessing video with new density: \(density.name)")
        currentTask?.cancel()
        Task {
            try? await processVideo(url: url)
        }
    }
    
    private func calculateThumbnailCount(duration: Double) -> Int {
        if duration < 5 { return 4 }
        
        let base = 320.0 / 200.0 // base on thumbnail width
        let k = 10.0
        let rawCount = base + k * log(duration)
        let totalCount = Int(rawCount / density.factor)
        
        return min(totalCount, maxThumbnails)
    }
} */
