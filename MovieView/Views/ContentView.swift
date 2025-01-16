import SwiftUI
import AVKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var videoProcessor = VideoProcessor()
    @StateObject private var folderProcessor = FolderProcessor()
    @State private var selectedThumbnail: VideoThumbnail?
    @State private var showingError = false
    @State private var isShowingFilePicker = false
    @State private var isShowingFolderPicker = false
    @State private var currentView: ViewState = .empty
    @State private var selectedMovie: MovieFile?
    @State private var isFindingTodayVideos = false
    @State private var isShowingDatePicker = false
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var isFindingDateRangeVideos = false
    
    private func loadTodayVideos() {
        isFindingTodayVideos = true
        Task {
            do {
                let videos = try await findTodayVideos()
                await folderProcessor.processVideos(from: videos)
                await MainActor.run {
                    currentView = .folder
                    isFindingTodayVideos = false
                }
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
                    currentView = .folder
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
        mainContent
            .modifier(ContentViewModifiers(
                videoProcessor: videoProcessor,
                folderProcessor: folderProcessor,
                selectedThumbnail: $selectedThumbnail,
                showingError: $showingError,
                isShowingFilePicker: $isShowingFilePicker,
                isShowingFolderPicker: $isShowingFolderPicker,
                isShowingDatePicker: $isShowingDatePicker,
                startDate: $startDate,
                endDate: $endDate,
                currentView: $currentView,
                isFindingDateRangeVideos: isFindingDateRangeVideos,
               // toolbarContent: toolbarContent,
                processingOverlay: AnyView(processingOverlay),
                thumbnailSheet: { thumbnail in AnyView(thumbnailSheet(thumbnail)) },
                handleFileImport: handleFileImport,
                handleFolderImport: handleFolderImport,
                loadDateRangeVideos: loadDateRangeVideos
            ))
            .toolbar(content: toolbarContent)
    }

    @ViewBuilder
    private var mainContent: some View {
        Group {
            switch currentView {
            case .empty:
                HomeView()
            case .folder:
                folderView
            default:
                processingView
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "film")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Drop a video file or folder here")
                    .font(.title2)
                    .foregroundColor(.secondary)
                buttonRow
            }
        }
    }

    @ViewBuilder
    private var buttonRow: some View {
        HStack(spacing: 16) {
            Button("Open Movie...") { isShowingFilePicker = true }
            Button("Open Folder...") { isShowingFolderPicker = true }
            Button(action: loadTodayVideos) {
                if isFindingTodayVideos {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Today's Videos")
                }
            }
            .disabled(isFindingTodayVideos)
            Button("Search by Date...") { isShowingDatePicker = true }
                .disabled(isFindingDateRangeVideos)
        }
        .padding(.top)
    }

    @ViewBuilder
    private var folderView: some View {
        NavigationSplitView {
            FolderView(folderProcessor: folderProcessor, onMovieSelected: { url in
                Task { try await videoProcessor.processVideo(url: url) }
            })
        } detail: {
            ThumbnailGridView(
                thumbnails: videoProcessor.thumbnails,
                selectedThumbnail: $selectedThumbnail,
                isProcessing: videoProcessor.isProcessing,
                emptyMessage: "Double-click a movie to view its mosaic",
                selectedMovie: selectedMovie
            )
        }
        .navigationTitle(selectedMovie?.name ?? "Movie Browser")
    }

    @ViewBuilder
    private var processingView: some View {
        NavigationStack {
            ThumbnailGridView(
                thumbnails: videoProcessor.thumbnails,
                selectedThumbnail: $selectedThumbnail,
                isProcessing: videoProcessor.isProcessing,
                emptyMessage: "Processing video...",
                selectedMovie: selectedMovie
            )
        }
    }

    @ViewBuilder
    private var processingOverlay: some View {
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

    @ToolbarContentBuilder
    func toolbarContent() -> some ToolbarContent {
        if currentView == .processing || (currentView == .folder && !videoProcessor.thumbnails.isEmpty) {
            ToolbarItem(placement: .automatic) {
                DensityPicker(density: $videoProcessor.density, 
                            videoProcessor: videoProcessor,
                            isDisabled: videoProcessor.isProcessing)
            }
        }
        
        ToolbarItem(placement: .automatic) {
            HStack {
                if currentView != .empty {
                    Button(action: resetToEmpty) {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
                
                Button(action: { isShowingFilePicker = true }) {
                    Label("Open Movie", systemImage: "folder")
                }
                .disabled(videoProcessor.isProcessing)
                
                Button(action: { isShowingFolderPicker = true }) {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                }
                .disabled(videoProcessor.isProcessing)
            }
        }
    }

    private func resetToEmpty() {
        currentView = .empty
        videoProcessor.cancelProcessing()
        folderProcessor.movies = []
        selectedMovie = nil
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                Task {
                    try await videoProcessor.processVideo(url: url)
                    currentView = .processing
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
                    try await folderProcessor.processFolder(at: url)
                    currentView = .folder
                }
            }
        case .failure(let error):
            folderProcessor.error = error.localizedDescription
        }
    }

    @ViewBuilder
    private func thumbnailSheet(_ thumbnail: VideoThumbnail) -> some View {
        VideoPlayer(player: AVPlayer(url: thumbnail.videoURL))
            .frame(minWidth: 640, minHeight: 360)
            .onAppear {
                AVPlayer(url: thumbnail.videoURL).seek(to: thumbnail.timestamp)
            }
    }
}

private struct ContentViewModifiers: ViewModifier {
    let videoProcessor: VideoProcessor
    let folderProcessor: FolderProcessor
    @Binding var selectedThumbnail: VideoThumbnail?
    @Binding var showingError: Bool
    @Binding var isShowingFilePicker: Bool
    @Binding var isShowingFolderPicker: Bool
    @Binding var isShowingDatePicker: Bool
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var currentView: ViewState
    let isFindingDateRangeVideos: Bool
   // let toolbarContent: any ToolbarContent
    let processingOverlay: AnyView
    let thumbnailSheet: (VideoThumbnail) -> AnyView
    let handleFileImport: (Result<[URL], Error>) -> Void
    let handleFolderImport: (Result<[URL], Error>) -> Void
    let loadDateRangeVideos: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay(processingOverlay)
          //  .toolbar(toolbarContent)
            .fileImporter(isPresented: $isShowingFilePicker, allowedContentTypes: [.movie], allowsMultipleSelection: false, onCompletion: handleFileImport)
            .fileImporter(isPresented: $isShowingFolderPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false, onCompletion: handleFolderImport)
            .sheet(item: $selectedThumbnail, content: thumbnailSheet)
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(videoProcessor.error ?? folderProcessor.error ?? "An unknown error occurred")
            }
            .onChange(of: videoProcessor.error) { error in showingError = error != nil }
            .onChange(of: folderProcessor.error) { error in showingError = error != nil }
            .onChange(of: videoProcessor.density) { _ in videoProcessor.reprocessCurrentVideo() }
            .onDrop(of: [UTType.movie, UTType.folder], delegate: VideoDropDelegate(videoProcessor: videoProcessor, folderProcessor: folderProcessor) { state in
                currentView = state
            })
            .sheet(isPresented: $isShowingDatePicker) {
                DateRangePicker(
                    startDate: $startDate,
                    endDate: $endDate,
                    onSearch: loadDateRangeVideos,
                    isSearching: isFindingDateRangeVideos
                )
            }
    }
}

#Preview {
   let cv = ContentView()

    
}
