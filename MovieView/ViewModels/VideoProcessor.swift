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
    private var currentVideoURL: URL?
    private var currentTask: Task<Void, Never>?
    
    private let maxThumbnails = 200
    
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
    }
    
    private func calculateThumbnailCount(duration: Double) -> Int {
        if duration < 5 { return 4 }
        
        let base = 320.0 / 200.0 // base on thumbnail width
        let k = 10.0
        let rawCount = base + k * log(duration)
        let totalCount = Int(rawCount / density.factor)
        
        return min(totalCount, maxThumbnails)
    }
    
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
                await self?.processVideo(at: videoURL)
            }
        }
    }
    
    func processVideo(at url: URL) async {
        currentVideoURL = url
        await MainActor.run {
            calculateExpectedThumbnails()
        }
        print("Starting video processing...")
        let asset = AVAsset(url: url)
        var aspectRatio: CGFloat = 1.0
        do {
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            
            print("Video duration: \(durationSeconds) seconds")
            
            // Calculate number of thumbnails based on duration and density
            let thumbnailCount = calculateThumbnailCount(duration: durationSeconds)
            let interval = durationSeconds / Double(thumbnailCount)
            
            print("Generating \(thumbnailCount) thumbnails...")
            
            self.isProcessing = true
            self.thumbnails = []
            
            // Create times array for batch processing
            let times = (0..<thumbnailCount).map { i in
                CMTime(seconds: Double(i) * interval, preferredTimescale: 600)
            }
            
            // Set up generator
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            
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
            
            generator.requestedTimeToleranceBefore = CMTime(seconds: 2, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 2, preferredTimescale: 600)
            
            // Generate thumbnails in batches
            let batchSize = 10
            for batch in stride(from: 0, to: times.count, by: batchSize) {
                if Task.isCancelled { break }
                
                let endIndex = min(batch + batchSize, times.count)
                let batchTimes = Array(times[batch..<endIndex])
                
                do {
                    let images = try await generator.images(for: batchTimes)
                    var index = 0
                    for await result in images {
                        if Task.isCancelled { break }
                        
                        let time = batchTimes[index]
                        let image = NSImage(cgImage: try result.image, size: generator.maximumSize)
                        let thumbnail = try VideoThumbnail(image: image, timestamp: time, videoURL: url, aspectRatio: aspectRatio)
                        
                        await MainActor.run {
                            withAnimation {
                                self.thumbnails.append(thumbnail)
                            }
                        }
                        
                        print("Generated thumbnail \(batch + index + 1)/\(thumbnailCount)")
                        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds delay for visual effect
                        index += 1
                    }
                } catch {
                    print("Error generating batch: \(error.localizedDescription)")
                }
            }
            
            print("Finished processing video")
            self.isProcessing = false
        } catch {
            print("Error processing video: \(error.localizedDescription)")
            self.error = error.localizedDescription
            self.isProcessing = false
        }
    }
    
    func reprocessCurrentVideo() {
        guard let url = currentVideoURL else { return }
        currentTask?.cancel()
        calculateExpectedThumbnails()
        currentTask = Task {
            await processVideo(at: url)
        }
    }
} 
