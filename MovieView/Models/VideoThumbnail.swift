/*import Foundation
import AVFoundation
import AppKit

struct VideoThumbnail: Identifiable {
    let id = UUID()
    let image: NSImage
    let timestamp: CMTime
    let videoURL: URL
    let aspectRatio: CGFloat
    var isSceneChange: Bool = false
    
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
*/
