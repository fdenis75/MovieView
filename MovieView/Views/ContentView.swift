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
        Group {
            if currentView == .empty {
                NavigationStack {
                    VStack(spacing: 16) {
                        Image(systemName: "film")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Drop a video file or folder here")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        HStack(spacing: 16) {
                            Button("Open Movie...") {
                                isShowingFilePicker = true
                            }
                            Button("Open Folder...") {
                                isShowingFolderPicker = true
                            }
                            Button(action: loadTodayVideos) {
                                if isFindingTodayVideos {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("Today's Videos")
                                }
                            }
                            .disabled(isFindingTodayVideos)
                            Button(action: { isShowingDatePicker = true }) {
                                Text("Search by Date...")
                            }
                            .disabled(isFindingDateRangeVideos)
                        }
                        .padding(.top)
                    }
                }
            } else if currentView == .folder {
                NavigationSplitView {
                    FolderView(folderProcessor: folderProcessor, onMovieSelected: { url in
                        Task {
                            await videoProcessor.processVideo(at: url)
                        }
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
            } else {
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
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if currentView == .processing || (currentView == .folder && !videoProcessor.thumbnails.isEmpty) {
                    DensityPicker(density: $videoProcessor.density, 
                                videoProcessor: videoProcessor,
                                isDisabled: videoProcessor.isProcessing)
                }
            }
            
            ToolbarItem(placement: .automatic) {
                HStack {
                    if currentView != .empty {
                        Button(action: {
                            currentView = .empty
                            videoProcessor.cancelProcessing()
                            folderProcessor.movies = []
                            selectedMovie = nil
                        }) {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                    
                    Button(action: {
                        isShowingFilePicker = true
                    }) {
                        Label("Open Movie", systemImage: "folder")
                    }
                    .disabled(videoProcessor.isProcessing)
                    
                    Button(action: {
                        isShowingFolderPicker = true
                    }) {
                        Label("Open Folder", systemImage: "folder.badge.plus")
                    }
                    .disabled(videoProcessor.isProcessing)
                }
            }
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.movie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await videoProcessor.processVideo(at: url)
                        currentView = .processing
                    }
                }
            case .failure(let error):
                videoProcessor.error = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $isShowingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await folderProcessor.processFolder(at: url)
                        currentView = .folder
                    }
                }
            case .failure(let error):
                folderProcessor.error = error.localizedDescription
            }
        }
        .sheet(item: $selectedThumbnail) { thumbnail in
            VideoPlayer(player: AVPlayer(url: thumbnail.videoURL))
                .frame(minWidth: 640, minHeight: 360)
                .onAppear {
                    AVPlayer(url: thumbnail.videoURL).seek(to: thumbnail.timestamp)
                }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(videoProcessor.error ?? folderProcessor.error ?? "An unknown error occurred")
        }
        .onChange(of: videoProcessor.error) { error in
            showingError = error != nil
        }
        .onChange(of: folderProcessor.error) { error in
            showingError = error != nil
        }
        .onChange(of: videoProcessor.density) { _ in
            videoProcessor.reprocessCurrentVideo()
        }
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
