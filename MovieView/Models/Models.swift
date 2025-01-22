import SwiftUI
import AVKit
import AVFoundation
import AppKit

// MARK: - View State
enum ViewState {
    case empty
    case folder
    case processing
}

// MARK: - Movie File
struct MovieFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let relativePath: String
    var thumbnail: NSImage?
    var aspectRatio: CGFloat = 1.0
    
    init(url: URL, relativePath: String = "", aspectRatio: CGFloat = 1.0) {
        self.url = url
        self.name = url.lastPathComponent
        self.relativePath = relativePath
        self.aspectRatio = aspectRatio
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MovieFile, rhs: MovieFile) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Density Configuration
struct DensityConfig: Equatable, Hashable {
    let name: String
    let factor: Double
    let extractsMultiplier: Double
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    static let xxl = DensityConfig(name: "XXL", factor: 0.25, extractsMultiplier: 0.25)
    static let xl = DensityConfig(name: "XL", factor: 0.5, extractsMultiplier: 0.5)
    static let l = DensityConfig(name: "L", factor: 0.75, extractsMultiplier: 0.75)
    static let m = DensityConfig(name: "M", factor: 1.0, extractsMultiplier: 1.0)
    static let s = DensityConfig(name: "S", factor: 2.0, extractsMultiplier: 1.5)
    static let xs = DensityConfig(name: "XS", factor: 3.0, extractsMultiplier: 2.0)
    static let xxs = DensityConfig(name: "XXS", factor: 4.0, extractsMultiplier: 3.0)
    
    static let allCases = [xxl, xl, l, m, s, xs, xxs]
    static let `default` = s
}

// MARK: - Video Thumbnail
struct VideoThumbnail: Identifiable, Equatable {
    let id = UUID()
    let image: NSImage
    let timestamp: CMTime
    let videoURL: URL
    let aspectRatio: CGFloat
    var isSceneChange: Bool = false
    
    static func == (lhs: VideoThumbnail, rhs: VideoThumbnail) -> Bool {
        lhs.id == rhs.id
    }
    
    var formattedTime: String {
        let seconds = CMTimeGetSeconds(timestamp)
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
} 
