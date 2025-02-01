import SwiftUI
import AVKit

struct SmartFolderPreview: View {
    let folder: SmartFolder
    @State private var previewImages: [NSImage] = []
    @State private var isLoading = true
    private let maxPreviews = 4
    
    var body: some View {
        ZStack {
            if !previewImages.isEmpty {
                Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                    GridRow {
                        ForEach(0..<2) { index in
                            if index < previewImages.count {
                                Image(nsImage: previewImages[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 45)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                    GridRow {
                        ForEach(2..<4) { index in
                            if index < previewImages.count {
                                Image(nsImage: previewImages[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 45)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                }
                .opacity(isLoading ? 0 : 1)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary.opacity(0.2))
                    .frame(width: 162, height: 92)
                    .overlay {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 24))
                                .foregroundStyle(.secondary)
                        }
                    }
            }
        }
        .task {
            await loadPreviews()
        }
    }
    
    private func loadPreviews() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let query = NSMetadataQuery()
            var predicates: [NSPredicate] = []
            
            // Add file name filter
            if let nameFilter = folder.criteria.nameContains {
                predicates.append(NSPredicate(format: "kMDItemDisplayName CONTAINS[cd] %@", nameFilter))
            }
            
            // Add folder name filter
            if let folderNameFilter = folder.criteria.folderNameContains {
                predicates.append(NSPredicate(format: "kMDItemPath CONTAINS[cd] %@", folderNameFilter))
            }
            
            // Add date range
            if let dateRange = folder.criteria.dateRange {
                if let start = dateRange.start {
                    predicates.append(NSPredicate(format: "kMDItemContentCreationDate >= %@", start as NSDate))
                }
                if let end = dateRange.end {
                    predicates.append(NSPredicate(format: "kMDItemContentCreationDate < %@", end as NSDate))
                }
            }
            
            // Add file size range
            if let fileSize = folder.criteria.fileSize {
                if let min = fileSize.min {
                    predicates.append(NSPredicate(format: "kMDItemFSSize >= %lld", min))
                }
                if let max = fileSize.max {
                    predicates.append(NSPredicate(format: "kMDItemFSSize <= %lld", max))
                }
            }
            
            // Add video type filter
            let typePredicates = videoTypes.map { type in
                NSPredicate(format: "kMDItemContentTypeTree == %@", type)
            }
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: typePredicates))
            
            // Combine all predicates
            query.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            query.searchScopes = [NSMetadataQueryLocalComputerScope]
            query.sortDescriptors = [.init(key: "kMDItemContentCreationDate", ascending: false)]
            
            let videos = try await withCheckedThrowingContinuation { @Sendable (continuation) in
                NotificationCenter.default.addObserver(
                    forName: .NSMetadataQueryDidFinishGathering,
                    object: query,
                    queue: .main
                ) { _ in
                    let videos = (query.results as! [NSMetadataItem]).compactMap { item -> URL? in
                        guard let path = item.value(forAttribute: "kMDItemPath") as? String else {
                            return nil
                        }
                        let url = URL(fileURLWithPath: path)
                        return (url.lastPathComponent.lowercased().contains("amprv") || 
                               url.pathExtension.lowercased().contains("rmvb")) ? nil : url
                    }
                    continuation.resume(returning: videos)
                    query.stop()
                }
                
                DispatchQueue.main.async {
                    query.start()
                }
            }
            
            // Get previews for the first few videos
            var images: [NSImage] = []
            
            for url in videos.prefix(maxPreviews) {
                if let image = try? await VideoPreviewGenerator.generatePreview(for: url, at: 0.25) {
                    images.append(image)
                }
                if images.count >= maxPreviews {
                    break
                }
            }
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.previewImages = images
                }
            }
            
        } catch {
            Logger.videoProcessing.error("Failed to load smart folder previews: \(error.localizedDescription)")
        }
    }
} 