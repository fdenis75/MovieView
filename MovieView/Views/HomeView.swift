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
                    folderProcessor.error = error.localizedDescription
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
                    folderProcessor.error = error.localizedDescription
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
                
                Section("History") {
                    ForEach([SidebarItem.recentVideos, .cacheStatus], id: \.self) { item in
                        Label(item.title, systemImage: item.icon)
                            .tag(item)
                    }
                }
            }
            .navigationTitle("MovieView")
        } content: {
            // Main Content Area
            VStack(spacing: 20) {
                if !folderProcessor.movies.isEmpty {
                    FolderView(folderProcessor: folderProcessor, onMovieSelected: { url in
                        Task { try await videoProcessor.processVideo(url: url) }
                    })
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "film")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Drop a video file or folder here")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .navigationTitle(selectedSidebarItem?.title ?? "Home")
            .searchable(text: $searchText, prompt: "Search videos...")
            .toolbar {
                // Density picker group
                ToolbarItemGroup(placement: .automatic) {
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
                    .disabled(isFindingDateRangeVideos)
                    .help("Search videos by date range")
                }
            }
        } detail: {
            // Detail View
            if !videoProcessor.thumbnails.isEmpty {
                ThumbnailGridView(
                    thumbnails: videoProcessor.thumbnails,
                    selectedThumbnail: $selectedThumbnail,
                    isProcessing: videoProcessor.isProcessing,
                    emptyMessage: "Processing video...",
                    selectedMovie: nil
                )
            
            } else {
                Text("Select a thumbnail to preview")
                    .foregroundStyle(.secondary)
            }
        }
        .overlay {
            if videoProcessor.isProcessing {
                VStack {
                    ProgressView("Processing video...")
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
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(videoProcessor.error ?? folderProcessor.error ?? "An unknown error occurred")
        }
        .onChange(of: videoProcessor.error) { error in showingError = error != nil }
        .onChange(of: folderProcessor.error) { error in showingError = error != nil }
        .onChange(of: videoProcessor.density) { _ in videoProcessor.reprocessCurrentVideo() }
        .fileImporter(isPresented: $isShowingFilePicker, allowedContentTypes: [.movie], allowsMultipleSelection: false, onCompletion: handleFileImport)
        .fileImporter(isPresented: $isShowingFolderPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false, onCompletion: handleFolderImport)
        .sheet(isPresented: $isShowingDatePicker) {
            DateRangePicker(
                startDate: $startDate,
                endDate: $endDate,
                onSearch: loadDateRangeVideos,
                isSearching: isFindingDateRangeVideos
            )
        }
        .onDrop(of: [UTType.movie, UTType.folder], delegate: VideoDropDelegate(videoProcessor: videoProcessor, folderProcessor: folderProcessor) { _ in })
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                Task {
                    try await videoProcessor.processVideo(url: url)
                }
            }
        case .failure(let error):
            videoProcessor.error = error.localizedDescription
        }
    }
    
    private func handleFolderImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                Task {
                    await folderProcessor.processFolder(at: url)
                }
            }
        case .failure(let error):
            folderProcessor.error = error.localizedDescription
        }
    }
}

#Preview {
    HomeView()
} 
