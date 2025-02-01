import Foundation
import AppKit
import SwiftUI

// Import models directly
//@preconcurrency import CacheModels

/// Manages in-memory caching of thumbnails using NSCache
actor ThumbnailMemoryCache {
    /// Cache entry combining the image and its metadata
    private final class CacheEntry: NSObject {
        let image: NSImage
        let timestamp: TimeInterval
        let quality: ThumbnailQuality
        let accessCount: Int
        let lastAccess: Date
        
        init(image: NSImage, timestamp: TimeInterval, quality: ThumbnailQuality, accessCount: Int, lastAccess: Date) {
            self.image = image
            self.timestamp = timestamp
            self.quality = quality
            self.accessCount = accessCount
            self.lastAccess = lastAccess
            super.init()
        }
    }
    
    /// The underlying NSCache instance
    private let cache: NSCache<NSString, CacheEntry> = {
        let cache = NSCache<NSString, CacheEntry>()
        
        // Set reasonable limits (can be adjusted based on system memory)
        cache.countLimit = 1000 // Maximum number of items
        
        // Default to 25% of system memory or 4GB, whichever is smaller
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let maxMemory = min(physicalMemory / 4, 4 * 1024 * 1024 * 1024)
        cache.totalCostLimit = Int(maxMemory)
        
        return cache
    }()
    
    /// Singleton instance
    static let shared = ThumbnailMemoryCache()
    private init() {
        setupMemoryWarningNotification()
    }
    
    /// Setup notification observer for memory warnings
    private func setupMemoryWarningNotification() {
        Task { @MainActor in
            NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task {
                    await self?.handleMemoryWarning()
                }
            }
        }
    }
    
    /// Handle memory warning by clearing part of the cache
    private func handleMemoryWarning() {
        // Clear 75% of items when receiving memory warning
        cache.countLimit /=  4
    }
    
    /// Store a thumbnail in the memory cache
    func store(image: NSImage,
              forKey key: String,
              timestamp: TimeInterval,
              quality: ThumbnailQuality) {
        let entry = CacheEntry(
            image: image,
            timestamp: timestamp,
            quality: quality,
            accessCount: 0,
            lastAccess: Date()
        )
        
        // Use the image's memory size as the cost
        let cost = estimateMemoryCost(for: image)
        cache.setObject(entry, forKey: key as NSString, cost: cost)
    }
    
    /// Retrieve a thumbnail from the memory cache
    func retrieve(forKey key: String) -> (NSImage, TimeInterval, ThumbnailQuality)? {
        guard let entry = cache.object(forKey: key as NSString) else {
            return nil
        }
        
        return (entry.image, entry.timestamp, entry.quality)
    }
    
    /// Clear all items from the cache
    func clearCache() {
        cache.removeAllObjects()
    }
    
    /// Remove a specific item from the cache
    func removeItem(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }
    
    /// Estimate the memory cost of an image
    private func estimateMemoryCost(for image: NSImage) -> Int {
        let pixelSize = image.size.width * image.size.height
        
        // Assuming 4 bytes per pixel (RGBA)
        let bytesPerPixel = 4
        
        // Add 20% overhead for NSImage structure
        return Int(pixelSize * CGFloat(bytesPerPixel) * 1.2)
    }
    
    /// Update cache limits based on system conditions
    func updateCacheLimits(countLimit: Int? = nil, memoryLimit: Int? = nil) {
        if let count = countLimit {
            cache.countLimit = count
        }
        
        if let memory = memoryLimit {
            cache.totalCostLimit = memory
        }
    }
}

// MARK: - Cache Key Generation
extension ThumbnailMemoryCache {
    /// Generate a cache key for a thumbnail
    static func cacheKey(videoHash: String, timestamp: TimeInterval, quality: ThumbnailQuality) -> String {
        return "\(videoHash)_\(Int(timestamp))_\(quality.rawValue)"
    }
} 
