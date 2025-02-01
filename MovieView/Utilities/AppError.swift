import Foundation
import OSLog

enum AppError: LocalizedError {
    case fileNotFound(URL)
    case fileNotAccessible(URL)
    case invalidVideoFile(URL)
    case thumbnailGenerationFailed(URL, String)
    case folderProcessingFailed(URL, String)
    case iinaMissing
    case iinaLaunchFailed(String)
    case cacheError(String)
    case unknownError(String)
    case operationInProgress
    case mosaicGenerationFailed(URL, String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .fileNotAccessible(let url):
            return "Cannot access file: \(url.lastPathComponent)"
        case .invalidVideoFile(let url):
            return "Invalid video file: \(url.lastPathComponent)"
        case .thumbnailGenerationFailed(let url, let reason):
            return "Failed to generate thumbnails for \(url.lastPathComponent): \(reason)"
        case .folderProcessingFailed(let url, let reason):
            return "Failed to process folder \(url.lastPathComponent): \(reason)"
        case .iinaMissing:
            return "IINA is not installed"
        case .iinaLaunchFailed(let reason):
            return "Failed to launch IINA: \(reason)"
        case .cacheError(let reason):
            return "Cache error: \(reason)"
        case .unknownError(let message):
            return message
        case .operationInProgress:
            return "Another operation is already in progress"
        case .mosaicGenerationFailed(let url, let reason):
            return "Failed to generate mosaic for \(url.lastPathComponent): \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "Please check if the file exists and try again."
        case .fileNotAccessible:
            return "Please check file permissions and try again."
        case .invalidVideoFile:
            return "The file appears to be corrupted or in an unsupported format."
        case .thumbnailGenerationFailed:
            return "Try processing the file again or check if it's a valid video file."
        case .folderProcessingFailed:
            return "Check folder permissions and try again."
        case .iinaMissing:
            return "Install IINA from https://iina.io"
        case .iinaLaunchFailed:
            return "Try reinstalling IINA or launching it manually."
        case .cacheError:
            return "Try clearing the app's cache."
        case .unknownError:
            return "Please try again or contact support if the issue persists."
        case .operationInProgress:
            return "Please wait for the current operation to complete before starting a new one."
        case .mosaicGenerationFailed:
            return "Try processing the file again or check if it's a valid video file."
        }
    }
}

extension Logger {
    /// Shared logger instance for the app
    static let shared = Logger(subsystem: "com.movieview", category: "default")
    
    /// Video processing related logs
    static let videoProcessing = Logger(subsystem: "com.movieview", category: "video")
    
    /// Folder processing related logs
    static let folderProcessing = Logger(subsystem: "com.movieview", category: "folder")
    
    /// Cache related logs
    static let cache = Logger(subsystem: "com.movieview", category: "cache")
    
    /// UI related logs
    static let ui = Logger(subsystem: "com.movieview", category: "ui")
} 