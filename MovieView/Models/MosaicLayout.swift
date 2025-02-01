import Foundation
import CoreGraphics
import AppKit

/// Represents the layout information for a mosaic
struct MosaicLayout {
    /// Number of rows in the mosaic
    let rows: Int
    
    /// Number of columns in the mosaic
    let cols: Int
    
    /// Base size for thumbnails
    let thumbnailSize: CGSize
    
    /// Positions of thumbnails in the mosaic
    let positions: [(x: Int, y: Int)]
    
    /// Total number of thumbnails
    let thumbCount: Int
    
    /// Individual sizes for each thumbnail (may vary for emphasis)
    let thumbnailSizes: [CGSize]
    
    /// Overall size of the mosaic
    let mosaicSize: CGSize
    
    /// Calculate optimal layout for given parameters
    /// - Parameters:
    ///   - originalAspectRatio: Aspect ratio of the original video
    ///   - thumbnailCount: Number of thumbnails to include
    ///   - mosaicWidth: Desired width of the mosaic
    ///   - useAutoLayout: Whether to optimize for screen size
    /// - Returns: Optimal layout configuration
    static func calculateOptimalLayout(
        originalAspectRatio: CGFloat,
        thumbnailCount: Int,
        mosaicWidth: Int,
        useAutoLayout: Bool = false
    ) -> MosaicLayout {
        if useAutoLayout {
            return calculateAutoLayout(
                originalAspectRatio: originalAspectRatio,
                thumbnailCount: thumbnailCount
            )
        } else {
            return calculateClassicLayout(
                originalAspectRatio: originalAspectRatio,
                thumbnailCount: thumbnailCount,
                mosaicWidth: mosaicWidth
            )
        }
    }
    
    /// Calculate layout optimized for screen size
    private static func calculateAutoLayout(
        originalAspectRatio: CGFloat,
        thumbnailCount: Int
    ) -> MosaicLayout {
        guard let screen = NSScreen.main else {
            return calculateClassicLayout(
                originalAspectRatio: originalAspectRatio,
                thumbnailCount: thumbnailCount,
                mosaicWidth: 1920
            )
        }
        
        let screenSize = screen.visibleFrame.size
        let scaleFactor = screen.backingScaleFactor
        
        // Calculate minimum readable thumbnail size
        let minThumbWidth: CGFloat = 160 * scaleFactor
        let minThumbHeight = minThumbWidth / originalAspectRatio
        
        // Calculate maximum possible thumbnails
        let maxHorizontal = Int(floor(screenSize.width / minThumbWidth))
        let maxVertical = Int(floor(screenSize.height / minThumbHeight))
        
        var bestLayout: MosaicLayout?
        var bestScore: CGFloat = 0
        
        // Try different grid configurations
        for rows in 1...maxVertical {
            for cols in 1...maxHorizontal {
                let totalThumbs = rows * cols
                if totalThumbs < thumbnailCount { continue }
                
                let thumbWidth = screenSize.width / CGFloat(cols)
                let thumbHeight = screenSize.height / CGFloat(rows)
                
                // Calculate scores based on coverage and readability
                let coverage = (thumbWidth * CGFloat(cols) * thumbHeight * CGFloat(rows)) / (screenSize.width * screenSize.height)
                let readabilityScore = (thumbWidth * thumbHeight) / (minThumbWidth * minThumbHeight)
                let score = coverage * 0.6 + readabilityScore * 0.4
                
                if score > bestScore {
                    bestScore = score
                    bestLayout = createLayout(
                        rows: rows,
                        cols: cols,
                        thumbnailCount: thumbnailCount,
                        thumbWidth: thumbWidth,
                        thumbHeight: thumbHeight
                    )
                }
            }
        }
        
        return bestLayout ?? calculateClassicLayout(
            originalAspectRatio: originalAspectRatio,
            thumbnailCount: thumbnailCount,
            mosaicWidth: Int(screenSize.width)
        )
    }
    
    /// Calculate classic grid layout
    private static func calculateClassicLayout(
        originalAspectRatio: CGFloat,
        thumbnailCount: Int,
        mosaicWidth: Int
    ) -> MosaicLayout {
        let count = thumbnailCount
        let rows = Int(sqrt(Double(count)))
        let cols = Int(ceil(Double(count) / Double(rows)))
        
        let thumbWidth = CGFloat(mosaicWidth) / CGFloat(cols)
        let thumbHeight = thumbWidth / originalAspectRatio
        
        return createLayout(
            rows: rows,
            cols: cols,
            thumbnailCount: count,
            thumbWidth: thumbWidth,
            thumbHeight: thumbHeight
        )
    }
    
    /// Create layout with calculated dimensions
    private static func createLayout(
        rows: Int,
        cols: Int,
        thumbnailCount: Int,
        thumbWidth: CGFloat,
        thumbHeight: CGFloat
    ) -> MosaicLayout {
        var positions: [(x: Int, y: Int)] = []
        var thumbnailSizes: [CGSize] = []
        
        for row in 0..<rows {
            for col in 0..<cols {
                if positions.count < thumbnailCount {
                    positions.append((
                        x: Int(CGFloat(col) * thumbWidth),
                        y: Int(CGFloat(row) * thumbHeight)
                    ))
                    thumbnailSizes.append(CGSize(
                        width: thumbWidth,
                        height: thumbHeight
                    ))
                }
            }
        }
        
        return MosaicLayout(
            rows: rows,
            cols: cols,
            thumbnailSize: CGSize(width: thumbWidth, height: thumbHeight),
            positions: positions,
            thumbCount: thumbnailCount,
            thumbnailSizes: thumbnailSizes,
            mosaicSize: CGSize(
                width: CGFloat(cols) * thumbWidth,
                height: CGFloat(rows) * thumbHeight
            )
        )
    }
} 