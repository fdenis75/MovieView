import Foundation
import AVFoundation
import CoreMedia
import OSLog

enum VideoPreviewGenerator {
    private static let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.MovieView", category: "videoPreview")

    static func generatePreview(
        from url: URL,
        duration: Double = 30.0,
        thumbnailCount: Int,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let signposter = OSSignposter(logHandle: log)
        let intervalState = signposter.beginInterval("generatePreview")
        defer { signposter.endInterval("generatePreview", intervalState) }
        
        Logger.videoProcessing.debug("Generating preview with parameters:")
        Logger.videoProcessing.debug("  - URL: \(url)")
        Logger.videoProcessing.debug("  - Duration: \(duration) seconds") 
        Logger.videoProcessing.debug("  - Thumbnail count: \(thumbnailCount)")
        Logger.videoProcessing.debug("Starting preview generation for \(url.path)")
        Logger.videoProcessing.debug("Parameters - duration: \(duration), thumbnailCount: \(thumbnailCount)")
        
        let asset = AVAsset(url: url)
        let composition = AVMutableComposition()
        
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first,
              let compositionTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            throw AppError.invalidVideoFile(url)
        }
        
        let assetDuration = try await asset.load(.duration)
        let (extractCount, segmentDuration) = calculateExtractionParameters(
            duration: CMTimeGetSeconds(assetDuration),
            thumbnailCount: thumbnailCount,
            previewDuration: duration
        )
        let timeScale = assetDuration.timescale
        
        // Composition setup progress: 10%
        await MainActor.run { progress(0.1) }
        Logger.videoProcessing.debug("Starting composition setup")
        Logger.videoProcessing.debug("Calculated parameters:")
        Logger.videoProcessing.debug("  - Extract count: \(extractCount)")
        Logger.videoProcessing.debug("  - Segment duration: \(segmentDuration) seconds")
        Logger.videoProcessing.debug("  - Time scale: \(timeScale)")
        
        for i in 0..<extractCount {
            let fraction = Double(i) / Double(max(1, extractCount - 1))
            let sourceTime = CMTime(seconds: fraction * CMTimeGetSeconds(assetDuration), preferredTimescale: timeScale)
            let targetTime = CMTime(seconds: Double(i) * segmentDuration, preferredTimescale: timeScale)
            let segmentDurationTime = CMTime(seconds: segmentDuration, preferredTimescale: timeScale)
            
            try compositionTrack.insertTimeRange(
                CMTimeRange(start: sourceTime, duration: segmentDurationTime),
                of: videoTrack,
                at: targetTime
            )
            
            // Track composition progress: 10-50%
            await MainActor.run { progress(0.1 + 0.4 * Double(i + 1) / Double(extractCount)) }
        }
        
        // Export the composition
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("preview_\(UUID().uuidString).mp4")
        
        let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        )
        
        guard let exportSession = exportSession else {
            throw AppError.thumbnailGenerationFailed(url, "Could not create export session")
        }
        
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .mp4
        
        // Start export progress tracking
        var progressTimer: Timer?
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak progressTimer] _ in
            let exportProgress = Float(exportSession.progress)
            // Export progress: 50-100%
            progress(0.5 + 0.5 * Double(exportProgress))
            if exportSession.status != .exporting {
                progressTimer?.invalidate()
            }
        }
        
        await exportSession.export()
        progressTimer?.invalidate()
        
        guard exportSession.status == .completed else {
            throw AppError.thumbnailGenerationFailed(url, exportSession.error?.localizedDescription ?? "Export failed")
        }
        
        await MainActor.run { progress(1.0) }
        Logger.videoProcessing.debug("Preview generation completed successfully")
        return tempURL
    }
    
    private static func calculateExtractionParameters(
        duration: Double,
        thumbnailCount: Int,
        previewDuration: Double
    ) -> (extractCount: Int, extractDuration: Double) {
        let baseExtractsPerMinute: Double
        if duration > 0 {
            let durationInMinutes = duration / 60.0
            let initialRate = 12.0
            let decayFactor = 0.2
            baseExtractsPerMinute = (initialRate / (1 + decayFactor * durationInMinutes))
        } else {
            baseExtractsPerMinute = 12.0
        }
        
        let extractCount = Int(ceil(duration / 60.0 * baseExtractsPerMinute))
        let extractDuration = previewDuration / Double(extractCount)
        
        return (extractCount, extractDuration)
    }

    static func generatePreview(for url: URL, at timestamp: Double) async throws -> NSImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: timestamp, preferredTimescale: 600)
        let cgImage = try await generator.image(at: time).image
        return NSImage(cgImage: cgImage, size: .zero)
    }
} 