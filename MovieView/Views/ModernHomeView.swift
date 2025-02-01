import SwiftUI
import AVKit
import UniformTypeIdentifiers

// MARK: - Design System

enum DesignTokens {
    enum Materials {
        static let sidebar = Material.ultraThinMaterial
        static let content = Material.regular
        static let overlay = Material.thick
    }
    
    enum Animation {
        static let standard = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)
        static let emphasis = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.8)
    }
    
    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }
    
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }
    
    enum Shadow {
        static let small = Color.black.opacity(0.1)
        static let medium = Color.black.opacity(0.15)
        static let large = Color.black.opacity(0.2)
    }
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
// MARK: - Modern Home View

struct ModernHomeView: View {
    @StateObject private var videoProcessor = VideoProcessor()
    @StateObject private var folderProcessor = FolderProcessor()
    @State private var selectedSidebarItem: SidebarItem?
    @State private var selectedMovie: MovieFile?
    @State private var selectedThumbnail: VideoThumbnail?
    @State private var isInspectorVisible = true
    @State private var searchText = ""
    
    // MARK: - Navigation States
    @State private var isShowingFilePicker = false
    @State private var isShowingFolderPicker = false
    @State private var isShowingDatePicker = false
    @State private var isFindingTodayVideos = false
    @State private var isFindingDateRangeVideos = false
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var showingError = false
    
    // MARK: - Computed Properties
    
    private var currentMovie: MovieFile? {
        guard let url = videoProcessor.currentVideoURL else { return nil }
        return MovieFile(url: url)
    }

    // MARK: - Methods
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
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                Task {
                    do {
                        try await videoProcessor.processVideo(url: url)
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
                        videoProcessor.thumbnails.removeAll()
                        try await folderProcessor.processFolder(at: url)
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
    
    // MARK: - Body
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            ModernSidebar(selectedItem: $selectedSidebarItem)
                .frame(minWidth: 220, maxWidth: 300)
        } content: {
            // Content Area
            ModernContentView(
                folderProcessor: folderProcessor,
                videoProcessor: videoProcessor,
                selectedMovie: $selectedMovie,
                selectedSidebarItem: selectedSidebarItem
            )
            .frame(minWidth: 500)
        } detail: {
            // Inspector
            if isInspectorVisible {
                ModernInspectorView(
                    selectedMovie: selectedMovie,
                    videoProcessor: videoProcessor,
                    selectedThumbnail: $selectedThumbnail
                )
                .frame(minWidth: 320, maxWidth: 400)
                .transition(.move(edge: .trailing))
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search videos...")
        .toolbar {
            modernToolbarContent
        }
        .sheet(isPresented: $isShowingDatePicker) {
            DateRangePicker(
                startDate: $startDate,
                endDate: $endDate,
                onSearch: loadDateRangeVideos,
                isSearching: isFindingDateRangeVideos
            )
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
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(videoProcessor.error?.localizedDescription ?? folderProcessor.error?.localizedDescription ?? "An unknown error occurred")
            }
        }
        .background {
            GeometryReader { geometry in
                Color.clear
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
            }
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var modernToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            ModernToolbarButtons(
                videoProcessor: videoProcessor,
                isShowingFilePicker: $isShowingFilePicker,
                isShowingFolderPicker: $isShowingFolderPicker,
                isFindingTodayVideos: $isFindingTodayVideos,
                isFindingDateRangeVideos: $isFindingDateRangeVideos,
                isShowingDatePicker: $isShowingDatePicker,
                onLoadTodayVideos: loadTodayVideos,
                handleFileImport: handleFileImport,
                handleFolderImport: handleFolderImport
            )
        }
        
        ToolbarItemGroup(placement: .automatic) {
            if !videoProcessor.thumbnails.isEmpty {
                DensityPicker(
                    density: $videoProcessor.density,
                    videoProcessor: videoProcessor,
                    isDisabled: videoProcessor.isProcessing
                )
            }
            
            Button {
                withAnimation(DesignTokens.Animation.standard) {
                    isInspectorVisible.toggle()
                }
            } label: {
                Label("Toggle Inspector", systemImage: "sidebar.right")
                    .symbolVariant(isInspectorVisible ? .fill : .none)
            }
        }
    }
}

// MARK: - Modern Sidebar

struct ModernSidebar: View {
    @Binding var selectedItem: SidebarItem?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        List(selection: $selectedItem) {
            Section("Library") {
                ForEach([SidebarItem.bookmarks, .smartFolders], id: \.self) { item in
                    NavigationLink(value: item) {
                        Label(item.title, systemImage: item.icon)
                            .symbolVariant(.fill)
                    }
                }
            }
            
            Section("History") {
                ForEach([SidebarItem.recentVideos, .cacheStatus], id: \.self) { item in
                    NavigationLink(value: item) {
                        Label(item.title, systemImage: item.icon)
                            .symbolVariant(.fill)
                    }
                }
            }
        }
        .navigationTitle("MovieView")
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(DesignTokens.Materials.sidebar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {}) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

// MARK: - Modern Content View

struct ModernContentView: View {
    @ObservedObject var folderProcessor: FolderProcessor
    @ObservedObject var videoProcessor: VideoProcessor
    @Binding var selectedMovie: MovieFile?
    let selectedSidebarItem: SidebarItem?
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var animation
    
    var body: some View {
        Group {
            switch selectedSidebarItem {
            case .bookmarks:
                BookmarksView(folderProcessor: folderProcessor)
                    .onChange(of: folderProcessor.movies) { movies in
                        if !movies.isEmpty {
                            selectedMovie = movies.first
                        }
                    }
            case .smartFolders:
                SmartFoldersView(folderProcessor: folderProcessor, videoProcessor: videoProcessor)
            case .recentVideos:
                if !folderProcessor.movies.isEmpty {
                    modernFolderView
                } else {
                    ModernEmptyStateView()
                }
            case .cacheStatus:
                ContentUnavailableView {
                    Label("Cache Status", systemImage: "internaldrive.fill")
                } description: {
                    Text("Coming Soon")
                }
            case nil:
                if !folderProcessor.movies.isEmpty {
                    modernFolderView
                } else {
                    ModernEmptyStateView()
                }
            }
        }
        .background(DesignTokens.Materials.content)
    }
    
    private var modernFolderView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 200, maximum: 300), spacing: DesignTokens.Spacing.medium)
            ], spacing: DesignTokens.Spacing.medium) {
                ForEach(folderProcessor.movies) { movie in
                    ModernMovieCard(movie: movie, isSelected: movie == selectedMovie)
                        .onTapGesture {
                            withAnimation(DesignTokens.Animation.standard) {
                                selectedMovie = movie
                                Task {
                                    try await videoProcessor.processVideo(url: movie.url)
                                }
                            }
                        }
                }
            }
            .padding()
        }
    }
}

// MARK: - Modern Inspector View

struct ModernInspectorView: View {
    let selectedMovie: MovieFile?
    let videoProcessor: VideoProcessor
    @Binding var selectedThumbnail: VideoThumbnail?
    
    var body: some View {
        Group {
            if let movie = selectedMovie {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                        // Movie Info Section
                        MovieInfoCard(
                            movie: movie,
                            onOpenIINA: {},
                            expectedThumbnailCount: videoProcessor.expectedThumbnailCount
                        )
                        
                        Divider()
                        
                        // Thumbnails Section
                        if !videoProcessor.thumbnails.isEmpty {
                            ThumbnailGridView(
                                thumbnails: videoProcessor.thumbnails,
                                selectedThumbnail: $selectedThumbnail,
                                isProcessing: videoProcessor.isProcessing,
                                emptyMessage: "Processing video...",
                                selectedMovie: movie,
                                videoProcessor: videoProcessor
                            )
                        }
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "film",
                    description: Text("Select a movie to see its details")
                )
            }
        }
        .background(DesignTokens.Materials.sidebar)
    }
}

// MARK: - Supporting Views

struct ModernMovieCard: View {
    let movie: MovieFile
    let isSelected: Bool
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading) {
            if let thumbnail = movie.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
            } else {
                Rectangle()
                    .fill(.secondary.opacity(0.2))
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
            }
            
            Text(movie.name)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Text(movie.url.lastPathComponent)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(DesignTokens.Spacing.small)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                .fill(.background)
                .shadow(radius: isHovered || isSelected ? 8 : 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        }
        .onHover { isHovered = $0 }
        .animation(DesignTokens.Animation.standard, value: isHovered)
        .animation(DesignTokens.Animation.standard, value: isSelected)
    }
}

struct ModernEmptyStateView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Videos", systemImage: "film")
        } description: {
            Text("Drop a video file or folder here to get started")
        } actions: {
            Button {} label: {
                Label("Open Video", systemImage: "plus")
            }
        }
    }
}

struct ModernToolbarButtons: View {
    @ObservedObject var videoProcessor: VideoProcessor
    @Binding var isShowingFilePicker: Bool
    @Binding var isShowingFolderPicker: Bool
    @Binding var isFindingTodayVideos: Bool
    @Binding var isFindingDateRangeVideos: Bool
    @Binding var isShowingDatePicker: Bool
    let onLoadTodayVideos: () -> Void
    let handleFileImport: (Result<[URL], Error>) -> Void
    let handleFolderImport: (Result<[URL], Error>) -> Void
    
    var body: some View {
        Group {
            Button {
                isShowingFilePicker = true
            } label: {
                Label("Open Movie", systemImage: "film.fill")
            }
            .disabled(videoProcessor.isProcessing)
            .help("Open a movie file")
            .fileImporter(
                isPresented: $isShowingFilePicker,
                allowedContentTypes: [.movie],
                allowsMultipleSelection: false,
                onCompletion: handleFileImport
            )
            
            Button {
                isShowingFolderPicker = true
            } label: {
                Label("Open Folder", systemImage: "folder.fill")
            }
            .disabled(videoProcessor.isProcessing)
            .help("Open a folder of movies")
            .fileImporter(
                isPresented: $isShowingFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false,
                onCompletion: handleFolderImport
            )
            
            Button {
                onLoadTodayVideos()
            } label: {
                Label {
                    Text("Today")
                } icon: {
                    if isFindingTodayVideos {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "clock.fill")
                    }
                }
            }
            .disabled(isFindingTodayVideos)
            .help("Show today's videos")
            
            Button {
                isShowingDatePicker = true
            } label: {
                Label("By Date", systemImage: "calendar")
            }
            .disabled(isFindingDateRangeVideos)
            .help("Search videos by date range")
        }
    }
} 