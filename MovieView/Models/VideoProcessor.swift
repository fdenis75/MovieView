import SwiftUI
import AVKit
import AVFoundation
import UniformTypeIdentifiers
import AppKit
import OSLog

@MainActor
class VideoProcessor: ObservableObject {
    @Published var thumbnails: [VideoThumbnail] = []
    @Published var isProcessing = false
    @Published private(set) var error: Error?
    @Published private(set) var showAlert = false
    @Published var density: DensityConfig = .default
    @Published var processingProgress: Double = 0
    @Published var expectedThumbnailCount: Int = 0
    
    @Published var currentVideoURL: URL?
    private var currentTask: Task<Void, Never>?
    private let maxThumbnails = 200
    
    private let diskCache = ThumbnailCacheManager.shared
    private let memoryCache = ThumbnailMemoryCache.shared
    
    func processDraggedItems(_ provider: NSItemProvider) {
        Logger.videoProcessing.info("Processing dragged item...")
        guard provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
            Logger.videoProcessing.error("Item is not a movie file")
            setError(AppError.invalidVideoFile(URL(fileURLWithPath: "")))
            return
        }
        
        provider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { [weak self] (videoURL, error) in
            Logger.videoProcessing.info("Loading item...")
            if let error = error {
                Logger.videoProcessing.error("Error loading item: \(error.localizedDescription)")
                Task { @MainActor in
                    self?.setError(AppError.unknownError(error.localizedDescription))
                }
                return
            }
            
            guard let videoURL = videoURL as? URL else {
                Logger.videoProcessing.error("Invalid URL received")
                Task { @MainActor in
                    self?.setError(AppError.invalidVideoFile(URL(fileURLWithPath: "")))
                }
                return
            }
            
            Logger.videoProcessing.info("Processing video at URL: \(videoURL.path)")
            Task { @MainActor in
                do {
                    try await self?.processVideo(url: videoURL)
                } catch {
                    Logger.videoProcessing.error("Error processing video: \(error.localizedDescription)")
                    self?.setError(error)
                }
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
                Logger.videoProcessing.error("Failed to calculate expected thumbnails: \(error.localizedDescription)")
                expectedThumbnailCount = 0
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
    
    private func calculateThumbnailCount(duration: Double) -> Int {
        if duration < 5 { return 4 }
        
        let base = 320.0 / 200.0 // base on thumbnail width
        let k = 10.0
        let rawCount = base + k * log(duration)
        let totalCount = Int(rawCount / density.factor)
        
        return min(totalCount, maxThumbnails)
    }
    
    func processVideo(url: URL) async throws {
        Logger.videoProcessing.info("Starting video processing for: \(url.lastPathComponent)")
        
        try validateVideoFile(url)
        
        let startTime = Date()
        prepareForProcessing(url)
        
        currentTask = Task {
            do {
                let asset = AVAsset(url: url)
                try await validateVideoAsset(asset, url: url)
                
                let (thumbnailCount, durationSeconds) = try await getThumbnailConfiguration(from: asset)
                expectedThumbnailCount = thumbnailCount
                
                let (generator, aspectRatio) = try await configureImageGenerator(for: asset)
                let timePoints = calculateTimePoints(count: thumbnailCount, duration: durationSeconds)
                let parameters = createThumbnailParameters()
                
                try await processThumbnails(
                    timePoints: timePoints,
                    generator: generator,
                    url: url,
                    aspectRatio: aspectRatio,
                    parameters: parameters,
                    thumbnailCount: thumbnailCount
                )
                
                finishProcessing(startTime: startTime)
                
            } catch is CancellationError {
                handleCancellation()
            } catch {
                handleError(error)
            }
        }
    }
    
    private func validateVideoFile(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            Logger.videoProcessing.error("File not found: \(url.path)")
            throw AppError.fileNotFound(url)
        }
        
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            Logger.videoProcessing.error("File not accessible: \(url.path)")
            throw AppError.fileNotAccessible(url)
        }
    }
    
    private func prepareForProcessing(_ url: URL) {
        cancelProcessing()
        isProcessing = true
        processingProgress = 0
        currentVideoURL = url
        thumbnails.removeAll()
    }
    
    private func validateVideoAsset(_ asset: AVAsset, url: URL) async throws {
    
        
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            Logger.videoProcessing.debug("No video track found, falling back to audio track.")
            return
        }
        
        guard videoTrack != nil else {
            Logger.videoProcessing.error("No video track found in file: \(url.path)")
            throw AppError.invalidVideoFile(url)
        }
        
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        guard durationSeconds > 0 else {
            Logger.videoProcessing.error("Invalid video duration for file: \(url.path)")
            throw AppError.invalidVideoFile(url)
        }
    }
    
    private func getThumbnailConfiguration(from asset: AVAsset) async throws -> (count: Int, duration: Double) {
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        let thumbnailCount = calculateThumbnailCount(duration: durationSeconds)
        
        Logger.videoProcessing.info("Generating \(thumbnailCount) thumbnails for video of duration \(durationSeconds)s")
        
        return (thumbnailCount, durationSeconds)
    }
    
    private func configureImageGenerator(for asset: AVAsset) async throws -> (AVAssetImageGenerator, CGFloat) {
        let generator = AVAssetImageGenerator(asset: asset)
        var aspectRatio: CGFloat = 16.0 / 9.0
        
        if let videoTrack = try await asset.loadTracks(withMediaType: .video).first {
            let naturalSize = try await videoTrack.load(.naturalSize)
            aspectRatio = naturalSize.width / naturalSize.height
            generator.maximumSize = CGSize(width: 480, height: 480 / aspectRatio)
        }
        
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 2, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 2, preferredTimescale: 600)
        
        return (generator, aspectRatio)
    }
    
    private func calculateTimePoints(count: Int, duration: Double) -> [CMTime] {
        (0..<count).map { i -> CMTime in
            let fraction = Double(i) / Double(max(1, count - 1))
            let seconds = fraction * duration
            return CMTimeMakeWithSeconds(seconds, preferredTimescale: 600)
        }
    }
    
    private func createThumbnailParameters() -> ThumbnailParameters {
        ThumbnailParameters(
            density: Float(density.factor),
            quality: .standard,
            size: ThumbnailQuality.standard.resolution,
            format: .heic
        )
    }
    
    private func processThumbnails(
        timePoints: [CMTime],
        generator: AVAssetImageGenerator,
        url: URL,
        aspectRatio: CGFloat,
        parameters: ThumbnailParameters,
        thumbnailCount: Int
    ) async throws {
        for (index, time) in timePoints.enumerated() {
            let iterationStart = Date()
            try Task.checkCancellation()
            
            let timestamp = CMTimeGetSeconds(time)
            Logger.videoProcessing.debug("Processing thumbnail \(index + 1)/\(thumbnailCount) at \(String(format: "%.2f", timestamp))s")
            
            if let thumbnail = try await checkMemoryCache(url: url, timestamp: timestamp, parameters: parameters) {
                addThumbnail(thumbnail, at: timestamp, aspectRatio: aspectRatio)
                processingProgress = Double(index + 1) / Double(thumbnailCount)
                continue
            }
            
            if let thumbnail = try await checkDiskCache(url: url, timestamp: timestamp, parameters: parameters) {
                addThumbnail(thumbnail, at: timestamp, aspectRatio: aspectRatio)
                processingProgress = Double(index + 1) / Double(thumbnailCount)
                continue
            }
            
            try await generateAndStoreThumbnail(
                generator: generator,
                time: time,
                url: url,
                timestamp: timestamp,
                parameters: parameters,
                aspectRatio: aspectRatio,
                index: index,
                thumbnailCount: thumbnailCount,
                iterationStart: iterationStart
            )
        }
    }
    
    private func generateAndStoreThumbnail(
        generator: AVAssetImageGenerator,
        time: CMTime,
        url: URL,
        timestamp: Double,
        parameters: ThumbnailParameters,
        aspectRatio: CGFloat,
        index: Int,
        thumbnailCount: Int,
        iterationStart: Date
    ) async throws {
        do {
            let thumbnail = try await generateNewThumbnail(generator: generator, at: time)
            try await storeThumbnail(thumbnail, for: url, at: timestamp, parameters: parameters)
            addThumbnail(thumbnail, at: timestamp, aspectRatio: aspectRatio)
            processingProgress = Double(index + 1) / Double(thumbnailCount)
            
            let iterationDuration = Date().timeIntervalSince(iterationStart)
            Logger.videoProcessing.debug("Thumbnail generation took \(String(format: "%.2f", iterationDuration))s")
        } catch {
            Logger.videoProcessing.error("Failed to generate thumbnail at \(CMTimeGetSeconds(time))s: \(error.localizedDescription)")
            if !error.isCancelled {
                throw AppError.thumbnailGenerationFailed(url, error.localizedDescription)
            }
        }
    }
    
    private func finishProcessing(startTime: Date) {
        isProcessing = false
        processingProgress = 1.0
        
        let totalDuration = Date().timeIntervalSince(startTime)
        Logger.videoProcessing.info("Finished processing video in \(String(format: "%.2f", totalDuration))s")
    }
    
    private func handleCancellation() {
        Logger.videoProcessing.info("Video processing cancelled")
        isProcessing = false
        processingProgress = 0
    }
    
    private func handleError(_ error: Error) {
        Logger.videoProcessing.error("Video processing failed: \(error.localizedDescription)")
        self.setError(error)
        isProcessing = false
        processingProgress = 0
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
        guard let url = currentVideoURL else {
            Logger.videoProcessing.warning("No video to reprocess")
            return
        }
        Logger.videoProcessing.info("Reprocessing video with new density: \(self.density.name)")
        currentTask?.cancel()
        calculateExpectedThumbnails()
        Task { @MainActor in
            do {
                try await self.processVideo(url: url)
            } catch {
                Logger.videoProcessing.error("Error reprocessing video: \(error.localizedDescription)")
                self.setError(error)
            }
        }
    }
    
     func setError(_ error: Error) {
        self.error = error
        self.showAlert = true
    }
    
    func dismissAlert() {
        error = nil
        showAlert = false
    }
    
    private func checkMemoryCache(url: URL, timestamp: Double, parameters: ThumbnailParameters) async throws -> NSImage? {
        guard let videoHash = try? ThumbnailCacheMetadata.generateCacheKey(for: url) else {
            return nil
        }
        
        let key = ThumbnailMemoryCache.cacheKey(
            videoHash: videoHash,
            timestamp: timestamp,
            quality: parameters.quality
        )
        
        if let (cachedImage, _, _) = await memoryCache.retrieve(forKey: key) {
            Logger.videoProcessing.debug("Found thumbnail in memory cache")
            return cachedImage
        }
        return nil
    }
    
    private func checkDiskCache(url: URL, timestamp: Double, parameters: ThumbnailParameters) async throws -> NSImage? {
        if let cachedImage = try? await diskCache.retrieveThumbnail(
            for: url,
            at: timestamp,
            quality: parameters.quality
        ) {
            Logger.videoProcessing.debug("Found thumbnail in disk cache")
            await storeThumbnailInMemory(cachedImage, for: url, at: timestamp, parameters: parameters)
            return cachedImage
        }
        return nil
    }
    
    private func generateNewThumbnail(generator: AVAssetImageGenerator, at time: CMTime) async throws -> NSImage {
        Logger.videoProcessing.debug("Generating new thumbnail")
        let cgImage = try await generator.image(at: time).image
        return NSImage(cgImage: cgImage, size: NSSizeFromCGSize(generator.maximumSize))
    }
    
    private func storeThumbnail(_ image: NSImage, for url: URL, at timestamp: Double, parameters: ThumbnailParameters) async throws {
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            try await diskCache.storeThumbnail(
                cgImage,
                for: url,
                at: timestamp,
                quality: parameters.quality,
                parameters: parameters
            )
            await storeThumbnailInMemory(image, for: url, at: timestamp, parameters: parameters)
        }
    }
    
    private func storeThumbnailInMemory(_ image: NSImage, for url: URL, at timestamp: Double, parameters: ThumbnailParameters) async {
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
    }
}

// MARK: - Error Handling
private extension Error {
    var isCancelled: Bool {
        (self as? CancellationError) != nil
    }
}
