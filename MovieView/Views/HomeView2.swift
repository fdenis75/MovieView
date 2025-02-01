import SwiftUI
import AVKit
import UniformTypeIdentifiers

struct HomeView: View {
    @StateObject private var videoProcessor = VideoProcessor()
    @StateObject private var folderProcessor = FolderProcessor()
    @State private var selectedSidebarItem: SidebarItem?
    @State private var searchText = ""
    @State private var selectedThumbnail: VideoThumbnail?
    @State private var showingError = false
    @State private var isShowingFilePicker = false
    @State private var isShowingFolderPicker = false
    @State private var isShowingDatePicker = false
    @State private var isFindingTodayVideos = false
    @State private var isFindingDateRangeVideos = false
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var selectedMovie: MovieFile?
    
    private var currentMovie: MovieFile? {
        guard let url = videoProcessor.currentVideoURL else { return nil }
        return MovieFile(url: url)
    }
    
    enum SidebarItem: Hashable {
        case bookmarks
        case smartFolders
        case recentVideos
        case cacheStatus
        
        var icon: String {
            switch self {
            case .bookmarks: return "bookmark.fill"
            case .smartFolders: return "folder.fill.badge.gearshape"
            case .recentVideos: return "clock.fill"
            case .cacheStatus: return "internaldrive.fill"
            }
        }
        
        var title: String {
            switch self {
            case .bookmarks: return "Bookmarks"
            case .smartFolders: return "Smart Folders"
            case .recentVideos: return "Recent Videos"
            case .cacheStatus: return "Cache Status"
            }
        }
    }
    
    private func loadTodayVideos() {
        isFindingTodayVideos = true
        Task {
            do {
                let videos = try await findTodayVideos()
                await folderProcessor.processVideos(from: videos)
                isFindingTodayVideos = false
            } catch {
                await MainActor.run {
                    folderProcessor.setError(AppError.unknownError(error.localizedDescription))
                    isFindingTodayVideos = false
                }
            }
        }
    }
    
    private func loadDateRangeVideos() {
        isFindingDateRangeVideos = true
        Task {
            do {
                let videos = try await findVideosBetweenDates(
                    start: Calendar.current.startOfDay(for: startDate),
                    end: Calendar.current.date(byAdding: .day, value: 1, to: endDate) ?? endDate
                )
                await folderProcessor.processVideos(from: videos)
                await MainActor.run {
                    isFindingDateRangeVideos = false
                    isShowingDatePicker = false
                }
            } catch {
                await MainActor.run {
                    folderProcessor.setError(AppError.unknownError(error.localizedDescription))
                    isFindingDateRangeVideos = false
                }
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedSidebarItem) {
                Section("Library") {
                    ForEach([SidebarItem.bookmarks, .smartFolders], id: \.self) { item in
                        Label(item.title, systemImage: item.icon)
                            .tag(item)
                    }
                }
                .background(.ultraThinMaterial)
                
                Section("History") {
                    ForEach([SidebarItem.recentVideos, .cacheStatus], id: \.self) { item in
                        Label(item.title, systemImage: item.icon)
                            .tag(item)
                    }
                }
                .background(.ultraThinMaterial)
            }
            .navigationTitle("MovieView")
        } content: {
            // Main Content Area
            ExtractedView
            .background(.ultraThinMaterial)
        } detail: {
            // Detail View
            if !videoProcessor.thumbnails.isEmpty {
                ThumbnailGridView(
                    thumbnails: videoProcessor.thumbnails,
                    selectedThumbnail: $selectedThumbnail,
                    isProcessing: videoProcessor.isProcessing,
                    emptyMessage: "Processing video...",
                    selectedMovie: currentMovie,
                    videoProcessor: videoProcessor
                )
                .onKeyPress(.escape) { 
                    videoProcessor.cancelProcessing()
                    return .handled
                }
            } else {
                Text("Select a thumbnail to preview")
                    .foregroundStyle(.secondary)
            }
        }
        .overlay {
            if videoProcessor.isProcessing {
                VStack {
                    ProgressView("Processing video...")
                    ProgressView(value: videoProcessor.processingProgress)
                        .frame(width: 200)
                    Button("Cancel") {
                        videoProcessor.cancelProcessing()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    .padding(.top, 8)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            if folderProcessor.isProcessing {
                VStack {
                    ProgressView("Processing folder...")
                    Button("Cancel") {
                        folderProcessor.cancelProcessing()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    .padding(.top, 8)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .onChange(of: videoProcessor.showAlert) { _ in
            showingError = videoProcessor.showAlert
        }
        .onChange(of: folderProcessor.showAlert) { _ in
            showingError = folderProcessor.showAlert
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {
                videoProcessor.dismissAlert()
                folderProcessor.dismissAlert()
            }
        } message: {
            if let error = videoProcessor.error as? AppError ?? folderProcessor.error as? AppError {
                VStack(alignment: .leading) {
                    Text(error.localizedDescription)
                    if let recovery = error.recoverySuggestion {
                        Text(recovery)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text(videoProcessor.error?.localizedDescription ?? folderProcessor.error?.localizedDescription ?? "An unknown error occurred")
            }
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "film")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Drop a video file or folder here")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }
    
    @ToolbarContentBuilder
    func toolbarContent() -> some ToolbarContent {
        ToolbarItemGroup(placement: .secondaryAction) {
            if !videoProcessor.thumbnails.isEmpty {
                DensityPicker(density: $videoProcessor.density,
                              videoProcessor: videoProcessor,
                              isDisabled: videoProcessor.isProcessing)
            }
        }
        
        // File operations group
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                isShowingFilePicker = true
            } label: {
                VStack {
                    Image(systemName: "film.fill")
                        .font(.system(size: 24))
                    Text("Open Movie")
                        .font(.caption)
                }
                .frame(width: 60)
            }
            .disabled(videoProcessor.isProcessing)
            .help("Open a movie file")
            .fileImporter(isPresented: $isShowingFilePicker, allowedContentTypes: [.movie], allowsMultipleSelection: false, onCompletion: handleFileImport)
            
            Button {
                isShowingFolderPicker = true
            } label: {
                VStack {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 24))
                    Text("Open Folder")
                        .font(.caption)
                }
                .frame(width: 60)
            }
            .fileImporter(isPresented: $isShowingFolderPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false, onCompletion: handleFolderImport)
            .disabled(videoProcessor.isProcessing)
            .help("Open a folder of movies")
        }
        
        
        // Search operations group
        ToolbarItemGroup(placement: .automatic) {
            Button {
                loadTodayVideos()
            } label: {
                VStack {
                    if isFindingTodayVideos {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 24))
                    }
                    Text("Today")
                        .font(.caption)
                }
                .frame(width: 60)
            }
            .disabled(isFindingTodayVideos)
            .help("Show today's videos")
            
            Button {
                isShowingDatePicker = true
            } label: {
                VStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 24))
                    Text("By Date")
                        .font(.caption)
                }
                .frame(width: 60)
            }
            .sheet(isPresented: $isShowingDatePicker) {
                DateRangePicker(
                    startDate: $startDate,
                    endDate: $endDate,
                    onSearch: loadDateRangeVideos,
                    isSearching: isFindingDateRangeVideos
                )
            }
            .disabled(isFindingDateRangeVideos)
            .help("Search videos by date range")
        }
    }
    
    
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                Task {
                    do {
                        try await videoProcessor.processVideo(url: url)
                        // Clear any folder view state
                        folderProcessor.movies.removeAll()
                    } catch {
                        videoProcessor.setError(error)
                    }
                }
            }
        case .failure(let error):
            videoProcessor.setError(error)
        }
    }
    
    private func handleFolderImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                Task {
                    do {
                        // Clear any video processing state
                        videoProcessor.thumbnails.removeAll()
                        try await folderProcessor.processFolder(at: url)
                        // Add to bookmarks
                        await MainActor.run {
                            BookmarkManager.shared.addBookmark(name: url.lastPathComponent, url: url)
                        }
                    } catch {
                        folderProcessor.setError(error)
                    }
                }
            }
        case .failure(let error):
            folderProcessor.setError(error)
        }
    }
    

     private var ExtractedView: some View {
      
            VStack(spacing: 20) {
                switch selectedSidebarItem {
                case .bookmarks:
                    BookmarksView(folderProcessor: folderProcessor)
                        .onChange(of: folderProcessor.movies) { movies in
                            if !movies.isEmpty {
                                selectedSidebarItem = nil  // Switch to folder view when movies are loaded
                            }
                        }
                case .smartFolders:
                    SmartFoldersView(folderProcessor: folderProcessor, videoProcessor: videoProcessor)
                       // .onChange(of: folderProcessor.movies) { movies in
                        //    if !movies.isEmpty {
                        //        selectedSidebarItem = nil  // Switch to folder view when movies are loaded
                        //    }
                        //}
                case .recentVideos:
                    if !folderProcessor.movies.isEmpty {
                        FolderView(
                            folderProcessor: folderProcessor, 
                            videoProcessor: videoProcessor, 
                            onMovieSelected: { url in
                                Task { try await videoProcessor.processVideo(url: url) }
                            }
                        )
                        .onKeyPress(.escape) { 
                            folderProcessor.cancelProcessing()
                            return .handled
                        }
                    } else {
                        emptyStateView
                    }
                case .cacheStatus:
                    Text("Cache Status View - Coming Soon")
                        .foregroundStyle(.secondary)
                case nil:
                    if !folderProcessor.movies.isEmpty {
                        FolderView(folderProcessor: folderProcessor, videoProcessor: videoProcessor, onMovieSelected: { url in
                            Task { try await videoProcessor.processVideo(url: url) }
                        })
                        .onKeyPress(.escape) { 
                            folderProcessor.cancelProcessing()
                            return .handled
                        }
                    } else {
                        emptyStateView
                    }
                }
            }
            .padding()
            .navigationTitle(selectedSidebarItem?.title ?? "Home")
            .searchable(text: $searchText, prompt: "Search videos...")
            .toolbar {
                if folderProcessor.isProcessing {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            folderProcessor.cancelProcessing()
                        }) {
                            Label("Cancel", systemImage: "xmark.circle.fill")
                        }
                        .keyboardShortcut(.escape, modifiers: [])
                    }
                }
                toolbarContent()
            }
        }
    }


#Preview {
    HomeView()
}
