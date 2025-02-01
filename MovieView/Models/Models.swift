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
struct DensityConfig: Equatable, Hashable, Codable {
    let name: String
    let factor: Double
    let extractsMultiplier: Double
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case factor
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(factor, forKey: .factor)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let factor = try container.decode(Double.self, forKey: .factor)
        
        // Find the matching case based on factor
        if let config = DensityConfig.allCases.first(where: { $0.factor == factor }) {
            self = config
        } else {
            // Default to .s if no match found
            self = .s
        }
    }
    
    init(name: String, factor: Double, extractsMultiplier: Double) {
        self.name = name
        self.factor = factor
        self.extractsMultiplier = extractsMultiplier
    }
    
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

    var rawValue: Double {
        factor
    }
}

// MARK: - Video Thumbnail
struct VideoThumbnail: Identifiable, Equatable {
    let id = UUID()
    let image: NSImage
    let timestamp: CMTime
    let videoURL: URL
    let aspectRatio: CGFloat
    var isSceneChange: Bool = false
    
    var time: Double {
        CMTimeGetSeconds(timestamp)
    }
    
    static func == (lhs: VideoThumbnail, rhs: VideoThumbnail) -> Bool {
        lhs.id == rhs.id
    }
    
    var formattedTime: String {
        let seconds = time
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
