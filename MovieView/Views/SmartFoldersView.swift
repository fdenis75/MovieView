import SwiftUI
//@_implementationOnly import MovieView.Utilities.videoFinder

struct SmartFoldersView: View {
    @StateObject private var smartFolderManager = SmartFolderManager.shared
    @ObservedObject var folderProcessor: FolderProcessor
    @ObservedObject var videoProcessor: VideoProcessor
    @State private var isShowingNewFolderSheet = false
    @State private var selectedFolder: SmartFolder?
    @State private var isProcessing = false
    
    // Mosaic generation states
    @State private var isShowingMosaicConfig = false
    @State private var mosaicConfig = MosaicConfig()
    @State private var isMosaicGenerating = false
    
    @State private var selectedVideos = Set<URL>()
    
    var body: some View {
        VStack {
            
                List {
                    ForEach(smartFolderManager.smartFolders) { folder in
                        HStack {
                            Label(folder.name, systemImage: "folder.fill.badge.gearshape")
                            Spacer()
                            Text(formatDate(folder.dateCreated))
                                .foregroundStyle(.secondary)
                        }
                        .contextMenu {
                            Button {
                                selectedFolder = folder
                                openSmartFolder(folder)
                            } label: {
                                Label("Open", systemImage: "folder")
                            }
                            
                            Button {
                                selectedFolder = folder
                                isShowingMosaicConfig = true
                            } label: {
                                Label("Generate Mosaics", systemImage: "square.grid.3x3")
                            }
                            
                            Button {
                                selectedFolder = folder
                                isShowingNewFolderSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Button {
                                let url = URL(fileURLWithPath: "/Volumes/Ext-6TB-2/Mosaics/\(folder.mosaicDirName)")
                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
                            } label: {
                                Label("Show in Finder", systemImage: "folder.badge.plus")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                smartFolderManager.removeSmartFolder(id: folder.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .onTapGesture {
                            
                            openSmartFolder(folder)
                        }
                    }
                }
            }
        
        .overlay {
            if isProcessing {
                ProgressView("Scanning videos...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
            if isMosaicGenerating {
                VStack {
                    ProgressView("Generating Mosaic...")
                        .progressViewStyle(.circular)
                    Text("\(Int(videoProcessor.mosaicProgress * 100))%")
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(8)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingNewFolderSheet = true
                } label: {
                    Label("New Smart Folder", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingNewFolderSheet) {
            SmartFolderEditor(folder: nil)
        }
        .sheet(item: $selectedFolder) { folder in
            SmartFolderEditor(folder: folder)
        }
        .sheet(isPresented: $isShowingMosaicConfig) {
            MosaicConfigSheet(config: $mosaicConfig) {
                guard let folder = selectedFolder else { return }
                Task {
                    await generateMosaicsFromSheet(for: folder)
                }
            }
        }
    }
    
    private func openSmartFolder(_ folder: SmartFolder) {
        isProcessing = true
        
        Task {
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
                folderProcessor.setSmartFolderName(folder.mosaicDirName ?? folder.name.replacingOccurrences(of: " ", with: "_"))
                // Process matching videos
                await folderProcessor.processVideos(from: videos)
                
                await MainActor.run {
                    isProcessing = false
                }
            } catch {
                print("Error processing smart folder: \(error)")
                await MainActor.run {
                    isProcessing = false
                }
            }
        }
    }
    
    private func generateMosaics(for folder: SmartFolder) {
        Task {
            isMosaicGenerating = true
            defer { isMosaicGenerating = false }
            
            let matchingVideos = folderProcessor.movies.filter { movie in
                smartFolderManager.matchesCriteria(movie: movie, criteria: folder.criteria)
            }
            
            for movie in matchingVideos {
                do {
                    let outputURL = try await videoProcessor.generateMosaic(
                        url: movie.url,
                        config: mosaicConfig,
                        smartFolderName: folder.mosaicDirName ?? folder.name.replacingOccurrences(of: " ", with: "_")
                    )
                    Logger.videoProcessing.info("Generated mosaic at: \(outputURL.path)")
                } catch {
                    Logger.videoProcessing.error("Failed to generate mosaic: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func generateMosaicsFromSheet(for folder: SmartFolder) async {
        isMosaicGenerating = true
        defer { isMosaicGenerating = false }
        
        // Get matching videos
        let videos: [MovieFile] = selectedVideos.isEmpty ? 
            folderProcessor.movies.filter { movie in
                smartFolderManager.matchesCriteria(movie: movie, criteria: folder.criteria)
            } : folderProcessor.movies.filter { selectedVideos.contains($0.url) }
        
        // Generate mosaics
        for movie in videos {
            do {
                let outputURL = try await videoProcessor.generateMosaic(
                    url: movie.url,
                    config: mosaicConfig, 
                    smartFolderName: folder.mosaicDirName ?? folder.name.replacingOccurrences(of: " ", with: "_")
                )
                Logger.videoProcessing.info("Generated mosaic at: \(outputURL.path)")
            } catch {
                Logger.videoProcessing.error("Failed to generate mosaic: \(error.localizedDescription)")
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct SmartFolderEditor: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var smartFolderManager = SmartFolderManager.shared
    
    let folder: SmartFolder?
    @State private var name: String
    @State private var criteria: SmartFolderCriteria
    @State private var hasDateRange = false
    @State private var hasFileSize = false
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var nameFilter = ""
    @State private var folderNameFilter = ""
    @State private var minSize = 0
    @State private var maxSize = 0
    
    init(folder: SmartFolder?) {
        self.folder = folder
        _name = State(initialValue: folder?.name ?? "")
        _criteria = State(initialValue: folder?.criteria ?? SmartFolderCriteria())
        _hasDateRange = State(initialValue: folder?.criteria.dateRange != nil)
        _hasFileSize = State(initialValue: folder?.criteria.fileSize != nil)
        _startDate = State(initialValue: folder?.criteria.dateRange?.start ?? Date())
        _endDate = State(initialValue: folder?.criteria.dateRange?.end ?? Date())
        _nameFilter = State(initialValue: folder?.criteria.nameContains ?? "")
        _folderNameFilter = State(initialValue: folder?.criteria.folderNameContains ?? "")
        _minSize = State(initialValue: Int(folder?.criteria.fileSize?.min ?? 0) / 1_000_000)
        _maxSize = State(initialValue: Int(folder?.criteria.fileSize?.max ?? 0) / 1_000_000)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Smart Folder Name", text: $name)
                }
                
                Section("Criteria") {
                    Toggle("Date Range", isOn: $hasDateRange)
                    if hasDateRange {
                        DatePicker("Start Date", selection: $startDate)
                        DatePicker("End Date", selection: $endDate)
                    }
                    
                    TextField("File Name Contains", text: $nameFilter)
                    TextField("Folder Name Contains", text: $folderNameFilter)
                    
                    Toggle("File Size", isOn: $hasFileSize)
                    if hasFileSize {
                        HStack {
                            Text("Min:")
                            TextField("Min Size (MB)", value: $minSize, format: .number)
                        }
                        HStack {
                            Text("Max:")
                            TextField("Max Size (MB)", value: $maxSize, format: .number)
                        }
                    }
                }
            }
            .navigationTitle(folder == nil ? "New Smart Folder" : "Edit Smart Folder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updatedCriteria = SmartFolderCriteria(
                            dateRange: hasDateRange ? .init(start: startDate, end: endDate) : nil,
                            nameContains: nameFilter.isEmpty ? nil : nameFilter,
                            folderNameContains: folderNameFilter.isEmpty ? nil : folderNameFilter,
                            fileSize: hasFileSize ? .init(
                                min: Int64(minSize) * 1_000_000,
                                max: Int64(maxSize) * 1_000_000
                            ) : nil
                        )
                        
                        if let folder = folder {
                            var updatedFolder = folder
                            updatedFolder.name = name
                            updatedFolder.criteria = updatedCriteria
                            smartFolderManager.updateSmartFolder(updatedFolder)
                        } else {
                            smartFolderManager.addSmartFolder(name: name, criteria: updatedCriteria)
                        }
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }
} 
