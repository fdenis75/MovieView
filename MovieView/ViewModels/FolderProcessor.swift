import SwiftUI
import AVKit
import AVFoundation
import AppKit

@MainActor
class FolderProcessor: ObservableObject {
    @Published var movies: [MovieFile] = []
    @Published var isProcessing = false
    @Published var error: String?
    private var processTask: Task<Void, Never>?
    
    func processVideos(from urls: [URL]) async {
        isProcessing = true
        processTask?.cancel()
        movies = []
        
        processTask = Task {
            for url in urls {
                guard !Task.isCancelled else { break }
                
                let pathExtension = url.pathExtension.lowercased()
                let relativePath = url.deletingLastPathComponent().path.replacingOccurrences(of: "/Volumes/", with: "").replacingOccurrences(of: "/", with: "-")
                            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let movie = MovieFile(url: url, relativePath: relativePath)
                await MainActor.run {
                    movies.append(movie)
                }
                
                // Generate thumbnail in background
                if let thumbnail = try? await generateThumbnail(for: url) {
                    await MainActor.run {
                        if let index = movies.firstIndex(where: { $0.id == movie.id }) {
                            movies[index].thumbnail = thumbnail
                        }
                    }
                }
            }
            isProcessing = false
        }
    }
    
    func processFolder(at url: URL) async {
        isProcessing = true
        processTask?.cancel()
        movies = []
        
        processTask = Task {
            await processDirectory(at: url)
            isProcessing = false
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
            
            while let fileURL = enumerator?.nextObject() as? URL {
                guard !Task.isCancelled else { return }
                
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                    
                    if resourceValues.isDirectory == true {
                        continue
                    }
                    
                    if let typeIdentifier = resourceValues.typeIdentifier,
                       UTType(typeIdentifier)?.conforms(to: .movie) == true {
                        let relativePath = fileURL.path.replacingOccurrences(of: url.path, with: "")
                            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
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
                    print("Error processing file \(fileURL): \(error.localizedDescription)")
                }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
    
    private func generateThumbnail(for url: URL) async throws -> NSImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        // Get video track's natural size
        let tracks = try await asset.loadTracks(withMediaType: .video)
        if let videoTrack = tracks.first {
            let naturalSize = try await videoTrack.load(.naturalSize)
            let aspectRatio = naturalSize.width / naturalSize.height
            
            // Calculate dimensions that maintain aspect ratio within 480px width (maximum slider size)
            let width: CGFloat = 480
            let height = width / aspectRatio
            generator.maximumSize = CGSize(width: width, height: height)
        } else {
            // Fallback to 16:9 if no video track found
            generator.maximumSize = CGSize(width: 480, height: 270)
        }
        
        let time = try await asset.load(.duration)
        let timestamp = CMTime(seconds: max(2.0, CMTimeGetSeconds(time)/2), preferredTimescale: 600)
        
        let cgImage = try generator.copyCGImage(at: timestamp, actualTime: nil)
        return NSImage(cgImage: cgImage, size: generator.maximumSize)
    }
    
    func cancelProcessing() {
        processTask?.cancel()
        processTask = nil
        isProcessing = false
    }
} 
