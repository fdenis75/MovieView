import Foundation
import AVKit
import AppKit
import OSLog

@MainActor
class FolderProcessor: ObservableObject {
    @Published var movies: [MovieFile] = []
    @Published var isProcessing = false
    @Published var error: Error?
    
    private var processTask: Task<Void, Never>?
    
    func processVideos(from urls: [URL]) async {
        Logger.folderProcessing.info("Processing \(urls.count) videos")
        isProcessing = true
        movies.removeAll()
        
        for url in urls {
            guard !Task.isCancelled else { break }
            
            do {
                // Check if file exists and is accessible
                guard FileManager.default.fileExists(atPath: url.path) else {
                    Logger.folderProcessing.error("File not found: \(url.path)")
                    throw AppError.fileNotFound(url)
                }
                
                guard FileManager.default.isReadableFile(atPath: url.path) else {
                    Logger.folderProcessing.error("File not accessible: \(url.path)")
                    throw AppError.fileNotAccessible(url)
                }
                
                let movie = MovieFile(url: url)
                movies.append(movie)
                
                // Generate thumbnail in background
                if let thumbnail = try? await generateThumbnail(for: url) {
                    await MainActor.run {
                        if let index = movies.firstIndex(where: { $0.id == movie.id }) {
                            movies[index].thumbnail = thumbnail
                        }
                    }
                }
            } catch {
                Logger.folderProcessing.error("Error processing video \(url.path): \(error.localizedDescription)")
                self.error = error
            }
        }
        
        await MainActor.run {
            isProcessing = false
        }
    }
    
    func processFolder(at url: URL) async throws {
        Logger.folderProcessing.info("Processing folder at: \(url.path)")
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            Logger.folderProcessing.error("Folder not found: \(url.path)")
            throw AppError.fileNotFound(url)
        }
        
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            Logger.folderProcessing.error("Folder not accessible: \(url.path)")
            throw AppError.fileNotAccessible(url)
        }
        
        isProcessing = true
        processTask?.cancel()
        movies = []
        
        processTask = Task {
            await processDirectory(at: url)
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    private func processDirectory(at url: URL) async {
        guard !Task.isCancelled else { return }
        
        do {
            let resourceKeys: [URLResourceKey] = [
                .isDirectoryKey,
                .contentModificationDateKey,
                .fileSizeKey,
                .typeIdentifierKey
            ]
            
            let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )
            
            guard let enumerator = enumerator else {
                Logger.folderProcessing.error("Failed to create enumerator for folder: \(url.path)")
                throw AppError.folderProcessingFailed(url, "Failed to enumerate directory")
            }
            
            for case let fileURL as URL in enumerator {
                guard !Task.isCancelled else { break }
                
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                    
                    // Skip directories
                    if resourceValues.isDirectory ?? false { continue }
                    
                    // Check if it's a video file
                    if let typeIdentifier = resourceValues.typeIdentifier,
                       UTType(typeIdentifier)?.conforms(to: .movie) ?? false {
                        let relativePath = fileURL.path.replacingOccurrences(of: url.path, with: "")
                        let movie = MovieFile(url: fileURL, relativePath: relativePath)
                        
                        await MainActor.run {
                            movies.append(movie)
                        }
                        
                        // Generate thumbnail in background
                        if let thumbnail = try? await generateThumbnail(for: fileURL) {
                            await MainActor.run {
                                if let index = movies.firstIndex(where: { $0.id == movie.id }) {
                                    movies[index].thumbnail = thumbnail
                                }
                            }
                        }
                    }
                } catch {
                    Logger.folderProcessing.error("Error processing file \(fileURL.path): \(error.localizedDescription)")
                    continue
                }
            }
        } catch {
            Logger.folderProcessing.error("Error processing folder \(url.path): \(error.localizedDescription)")
            await MainActor.run {
                self.error = AppError.folderProcessingFailed(url, error.localizedDescription)
            }
        }
    }
    
    private func generateThumbnail(for url: URL) async throws -> NSImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        // Get video dimensions for aspect ratio
        if let track = try? await asset.loadTracks(withMediaType: .video).first {
            let size = try await track.load(.naturalSize)
            let aspectRatio = size.width / size.height
            generator.maximumSize = CGSize(width: 320, height: 320 / aspectRatio)
        }
        
        do {
            let duration = try await asset.load(.duration)
            let time = CMTimeMultiplyByFloat64(duration, multiplier: 0.1)
            let cgImage = try await generator.image(at: time).image
            return NSImage(cgImage: cgImage, size: NSSizeFromCGSize(generator.maximumSize))
        } catch {
            Logger.folderProcessing.error("Failed to generate thumbnail for \(url.path): \(error.localizedDescription)")
            return nil
        }
    }
    
    func cancelProcessing() {
        Logger.folderProcessing.info("Cancelling folder processing")
        processTask?.cancel()
        processTask = nil
        isProcessing = false
    }
} 
