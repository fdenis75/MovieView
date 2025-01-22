import Foundation
import SwiftUI
import OSLog
import AppKit
import AVFoundation

// Import models directly
//@preconcurrency import CacheModels

/// Manages the disk-based caching of video thumbnails
actor ThumbnailCacheManager {
    private let logger = Logger(subsystem: "com.movieview", category: "ThumbnailCache")
    private let fileManager = FileManager.default
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    /// Maximum cache size in bytes (5GB default)
    private let maxCacheSize: Int64 = 5 * 1024 * 1024 * 1024
    
    /// Singleton instance
    static let shared = ThumbnailCacheManager()
    private init() {
        setupCacheDirectory()
    }
    
    /// Setup the cache directory structure
    private func setupCacheDirectory() {
        do {
            let cacheDir = try getCacheDirectory()
            try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create cache directory: \(error.localizedDescription)")
        }
    }
    
    /// Get the base cache directory
    private func getCacheDirectory() throws -> URL {
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MovieView")
            .appendingPathComponent("Thumbnails")
        print("cacheDir: \(cacheDir.path)")
        if !fileManager.fileExists(atPath: cacheDir.path) {
            try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        return cacheDir
    }
    
    /// Store a thumbnail in the cache
    func storeThumbnail(_ image: CGImage,
                       for videoURL: URL,
                       at timestamp: TimeInterval,
                       quality: ThumbnailQuality,
                       parameters: ThumbnailParameters) async throws {
        let videoHash = try ThumbnailCacheMetadata.generateCacheKey(for: videoURL)
        let cacheDir = ThumbnailCacheMetadata.cacheDirectory(for: videoHash)
        
        // Create directories if needed
        try fileManager.createDirectory(at: cacheDir.appendingPathComponent("thumbnails"),
                                     withIntermediateDirectories: true)
        
        // Generate thumbnail filename
        let filename = "\(Int(timestamp))_\(quality.rawValue).\(parameters.format.fileExtension)"
        let thumbnailURL = cacheDir.appendingPathComponent("thumbnails").appendingPathComponent(filename)
        
        // Save the image
        try await saveThumbnail(image, to: thumbnailURL, format: parameters.format)
        
        // Update metadata
        try await updateMetadata(for: videoHash, thumbnailURL: thumbnailURL, timestamp: timestamp, quality: quality)
        
        // Check cache size and clean if necessary
        try await performCacheCleanupIfNeeded()
    }
    
    /// Save thumbnail image to disk
    private func saveThumbnail(_ image: CGImage, to url: URL, format: CacheFormat) async throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            AVFileType.heic.rawValue as CFString,
            1,
            nil
        ) else {
            throw CacheError.thumbnailEncodingFailed
        }
        
        let options: [String: Any] = [
            kCGImageDestinationLossyCompressionQuality as String: 0.4,
            kCGImageDestinationEmbedThumbnail as String: true,
            kCGImagePropertyHasAlpha as String: false
        ]
        
        CGImageDestinationAddImage(destination, image, options as CFDictionary?)
        
        if !CGImageDestinationFinalize(destination) {
            throw CacheError.thumbnailEncodingFailed
        }
        
       
    }
    
    
    /// Update the metadata file for a cached video
    private func updateMetadata(for videoHash: String,
                              thumbnailURL: URL,
                              timestamp: TimeInterval,
                              quality: ThumbnailQuality) async throws {
        let metadataURL = ThumbnailCacheMetadata.cacheDirectory(for: videoHash)
            .appendingPathComponent("metadata.json")
        
        let metadata: ThumbnailCacheMetadata
        
        if fileManager.fileExists(atPath: metadataURL.path) {
            let data = try Data(contentsOf: metadataURL)
            metadata = try decoder.decode(ThumbnailCacheMetadata.self, from: data)
        } else {
            // Create new metadata
            metadata = ThumbnailCacheMetadata(
                version: ThumbnailCacheMetadata.currentVersion,
                videoHash: videoHash,
                modificationDate: Date(),
                parameters: .standard,
                thumbnails: [],
                lastAccessDate: Date()
            )
        }
        
        // Write updated metadata
        let updatedData = try encoder.encode(metadata)
        try updatedData.write(to: metadataURL)
    }
    
    /// Clean up old cache entries if size limit is exceeded
    private func performCacheCleanupIfNeeded() async throws {
        let currentSize = try await calculateCacheSize()
        
        if currentSize > maxCacheSize {
            try await cleanupOldCacheEntries()
        }
    }
    
    /// Calculate total cache size
    private func calculateCacheSize() async throws -> Int64 {
        let cacheDir = try getCacheDirectory()
        let resourceKeys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey]
        let enumerator = fileManager.enumerator(at: cacheDir,
                                              includingPropertiesForKeys: Array(resourceKeys))!
        
        var totalSize: Int64 = 0
        
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
            if !resourceValues.isDirectory! {
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        }
        
        return totalSize
    }
    
    /// Remove old cache entries to free up space
    private func cleanupOldCacheEntries() async throws {
        let cacheDir = try getCacheDirectory()
        var entries: [(URL, Date)] = []
        
        // Collect all video directories and their last access times
        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .contentModificationDateKey]
        if let enumerator = fileManager.enumerator(
            at: cacheDir,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                if resourceValues.isDirectory == true {
                    if let metadataURL = try? getMetadataURL(for: fileURL),
                       let metadata = try? loadMetadata(from: metadataURL) {
                        entries.append((fileURL, metadata.lastAccessDate))
                    }
                }
            }
        }
        
        // Sort by last access date (oldest first)
        entries.sort { $0.1 < $1.1 }
        
        // Calculate how much space we need to free
        let currentSize = try await calculateCacheSize()
        let targetSize = Int64(Double(maxCacheSize) * 0.8) // Aim to reduce to 80% of max
        var freedSpace: Int64 = 0
        let spaceToFree = currentSize - targetSize
        
        // Remove oldest entries until we free enough space
        for (dirURL, _) in entries {
            if freedSpace >= spaceToFree {
                break
            }
            
            // Calculate directory size before removing
            let dirSize = try calculateDirectorySize(dirURL)
            
            // Remove directory and its contents
            try fileManager.removeItem(at: dirURL)
            
            freedSpace += dirSize
            
            logger.info("Removed cache entry: \(dirURL.lastPathComponent), freed \(ByteCountFormatter.string(fromByteCount: dirSize, countStyle: .file))")
        }
        
        logger.info("Cache cleanup completed. Freed \(ByteCountFormatter.string(fromByteCount: freedSpace, countStyle: .file))")
    }
    
    /// Calculate the size of a directory
    private func calculateDirectorySize(_ url: URL) throws -> Int64 {
        let resourceKeys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey]
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
            if resourceValues.isDirectory != true {
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        }
        
        return totalSize
    }
    
    /// Get the metadata URL for a cache directory
    private func getMetadataURL(for directoryURL: URL) throws -> URL {
        return directoryURL.appendingPathComponent("metadata.json")
    }
    
    /// Load metadata from a URL
    private func loadMetadata(from url: URL) throws -> ThumbnailCacheMetadata {
        let data = try Data(contentsOf: url)
        return try decoder.decode(ThumbnailCacheMetadata.self, from: data)
    }
    
    /// Update the last access time for a video's cache
    private func updateLastAccessTime(for videoHash: String) async throws {
        let metadataURL = ThumbnailCacheMetadata.cacheDirectory(for: videoHash)
            .appendingPathComponent("metadata.json")
        
        if fileManager.fileExists(atPath: metadataURL.path) {
            var metadata = try loadMetadata(from: metadataURL)
            metadata = ThumbnailCacheMetadata(
                version: metadata.version,
                videoHash: metadata.videoHash,
                modificationDate: metadata.modificationDate,
                parameters: metadata.parameters,
                thumbnails: metadata.thumbnails,
                lastAccessDate: Date()
            )
            
            let updatedData = try encoder.encode(metadata)
            try updatedData.write(to: metadataURL)
        }
    }
    
    /// Retrieve a thumbnail from the cache
    func retrieveThumbnail(for videoURL: URL,
                          at timestamp: TimeInterval,
                          quality: ThumbnailQuality) async throws -> NSImage? {
        let videoHash = try ThumbnailCacheMetadata.generateCacheKey(for: videoURL)
        let cacheDir = ThumbnailCacheMetadata.cacheDirectory(for: videoHash)
        let filename = "\(Int(timestamp))_\(quality.rawValue)"
        
        // Try both formats
        for format in CacheFormat.allCases {
            let thumbnailURL = cacheDir
                .appendingPathComponent("thumbnails")
                .appendingPathComponent("\(filename).\(format.fileExtension)")
            
            if fileManager.fileExists(atPath: thumbnailURL.path) {
                // Update last access time
                try await updateLastAccessTime(for: videoHash)
                
                // Load the image
                if let image = NSImage(contentsOf: thumbnailURL) {
                    return image
                }
            }
        }
        
        return nil
    }
    
    /// Clear the entire cache
    func clearCache() async throws {
        let cacheDir = try getCacheDirectory()
        try fileManager.removeItem(at: cacheDir)
        try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
    
    /// Remove cache for a specific video
    func removeCacheForVideo(_ videoURL: URL) async throws {
        let videoHash = try ThumbnailCacheMetadata.generateCacheKey(for: videoURL)
        let cacheDir = ThumbnailCacheMetadata.cacheDirectory(for: videoHash)
        
        if fileManager.fileExists(atPath: cacheDir.path) {
            try fileManager.removeItem(at: cacheDir)
        }
    }
}

// MARK: - Error Types
extension ThumbnailCacheManager {
    enum CacheError: Error {
        case thumbnailEncodingFailed
        case metadataEncodingFailed
        case invalidCacheDirectory
    }
}

// MARK: - NSImage Extensions
private extension NSImage {
    func heicData() -> Data? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData,
                                                               "public.heic" as CFString,
                                                               1, nil) else {
            return nil
        }
        
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return data as Data
    }
    
    func jpegData(compressionQuality: CGFloat = 0.8) -> Data? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
} 
