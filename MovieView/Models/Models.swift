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
@MainActor
class MovieFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let relativePath: String
    var thumbnail: NSImage?
    var aspectRatio: CGFloat = 1.0
    var duration: TimeInterval?
    var resolution: CGSize?
    var codec: String?
    var bitrate: Int64?
    var frameRate: Float64?
    
    init(url: URL, relativePath: String = "", aspectRatio: CGFloat = 1.0) {
        self.url = url
        self.name = url.lastPathComponent
        self.relativePath = relativePath
        self.aspectRatio = aspectRatio
        
        // Load metadata asynchronously
        Task {
            let asset = AVAsset(url: url)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            if let track = try? await tracks.first {
                self.resolution = try? await track.load(.naturalSize)
                if let frameRate = try? await track.load(.nominalFrameRate) {
                    self.frameRate = Float64(frameRate)
                }
                self.codec = try? await track.mediaFormat
                self.bitrate = try? await Int64(track.load(.estimatedDataRate))
            }
            self.duration = try? await asset.load(.duration).seconds
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MovieFile, rhs: MovieFile) -> Bool {
        lhs.id == rhs.id
    }
}

extension AVAssetTrack {
    var mediaFormat: String {
        get async throws {
            var format = ""
            let descriptions = try await load(.formatDescriptions)
            for (index, formatDesc) in descriptions.enumerated() {
                let type = CMFormatDescriptionGetMediaType(formatDesc).toString()
                let subType = CMFormatDescriptionGetMediaSubType(formatDesc).toString()
                format += "\(type)/\(subType)"
                if index < descriptions.count - 1 {
                    format += ","
                }
            }
            return format
        }
    }
}

extension FourCharCode {
    func toString() -> String {
        let bytes: [CChar] = [
            CChar((self >> 24) & 0xff),
            CChar((self >> 16) & 0xff),
            CChar((self >> 8) & 0xff),
            CChar(self & 0xff),
            0
        ]
        let result = String(cString: bytes)
        let characterSet = CharacterSet.whitespaces
        return result.trimmingCharacters(in: characterSet)
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
