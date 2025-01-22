import SwiftUI

enum MovieSortOption {
    case name
    case date
    case size
    
    var title: String {
        switch self {
        case .name: return "Name"
        case .date: return "Date"
        case .size: return "Size"
        }
    }
}

struct MovieCardView: View {
    let movie: MovieFile
    let onSelect: (URL) -> Void
    let size: Double
    @State private var isHovered = false
    @State private var isSelected = false
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            if let thumbnail = movie.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size / movie.aspectRatio)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Rectangle()
                    .fill(.secondary.opacity(0.2))
                    .frame(width: 320, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        ProgressView()
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                if !movie.relativePath.isEmpty {
                    Text(movie.relativePath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                HStack(spacing: 8) {
                    if let date = try? movie.url.resourceValues(forKeys: [.contentModificationDateKey])
                        .contentModificationDate
                    {
                        Text(date, style: .date)
                    }
                    if let size = try? movie.url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .onHover { hovering in
            withAnimation {
                isHovered = hovering
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.mint : Color.gray.opacity(0.3), lineWidth: isHovered ? 2 : 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)
                .shadow(radius: 2)
        }
        .onTapGesture(count: 1) {
            onSelect(movie.url)
        }
    }
}

struct FolderView: View {
    
    @ObservedObject var folderProcessor: FolderProcessor
    let onMovieSelected: (URL) -> Void
    @State private var sortOption: MovieSortOption = .name
    @State private var sortAscending = true
    @State private var selectedFolder: String?
    @State private var thumbnailSize: Double = 240  // Default size
    @State private var selectedMovie: MovieFile?
    @State private var hoveredMovie: MovieFile?
    @FocusState private var isFocused: Bool
    
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: thumbnailSize, maximum: thumbnailSize * 2), spacing: 16)]
    }
    
    private var folders: [String] {
        let paths = folderProcessor.movies.compactMap { movie in
            let components = movie.relativePath.split(separator: "/")
            return components.first.map(String.init)
        }
        return Array(Set(paths)).sorted()
    }
    
    private var filteredMovies: [MovieFile] {
        if let selectedFolder = selectedFolder {
            return folderProcessor.movies.filter { movie in
                let components = movie.relativePath.split(separator: "/")
                return components.first.map(String.init) == selectedFolder
            }
        }
        return folderProcessor.movies
    }
    
    private var sortedMovies: [MovieFile] {
        let sorted = filteredMovies.sorted { first, second in
            switch sortOption {
            case .name:
                return sortAscending
                ? first.name.localizedStandardCompare(second.name) == .orderedAscending
                : first.name.localizedStandardCompare(second.name) == .orderedDescending
            case .date:
                let firstDate =
                (try? first.url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? Date.distantPast
                let secondDate =
                (try? second.url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? Date.distantPast
                return sortAscending ? firstDate < secondDate : firstDate > secondDate
            case .size:
                let firstSize = (try? first.url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                let secondSize = (try? second.url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                return sortAscending ? firstSize < secondSize : firstSize > secondSize
            }
        }
        return sorted
    }
    
    
    @ViewBuilder
    private var slideView: some View {
        HStack {
            Image(systemName: "photo")
            Slider(
                value: $thumbnailSize,
                in: 160...320,
                step: 40
            )
            Image(systemName: "photo.fill")
        }
    }
    
    
    @ViewBuilder
    private var menuView: some View {
       
            Menu {
                Button("All Folders") {
                    selectedFolder = nil
                }
                Divider()
                ForEach(folders, id: \.self) { folder in
                    Button(folder) {
                        selectedFolder = folder
                    }
                }
            } label: {
                Label(selectedFolder ?? "All Folders", systemImage: "folder")
                    .frame(width: 150, alignment: .leading)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            
            Picker("Sort by", selection: $sortOption) {
                ForEach([MovieSortOption.name, .date, .size], id: \.title) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            
            Button(action: {
                withAnimation {
                    sortAscending.toggle()
                }
            }) {
                Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
            }
            .buttonStyle(.borderless)
            
            Spacer()
            
            if folderProcessor.isProcessing {
                ProgressView()
                    .scaleEffect(0.7)
                    .padding(.trailing, 4)
                Text("Scanning... found \(folderProcessor.movies.count) movies")
                    .foregroundStyle(.secondary)
            } else {
                Text("Found \(folderProcessor.movies.count) movies")
                    .foregroundStyle(.secondary)
            }
        }
    
    /*
    @ViewBuilder
    private var thumbnailGridView: some View {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(sortedMovies) { movie in
                    MovieCardView(movie: movie, onSelect: onMovieSelected, size: thumbnailSize)
                        .onHover { isHovered in
                            hoveredMovie = isHovered ? movie : nil
                        }
                        // .scaleEffect(hoveredMovie == movie || selectedMovie == movie ? 1.05 : 1.0)
                        .shadow(
                            color: .black.opacity(hoveredMovie == movie || selectedMovie == movie ? 0.2 : 0),
                            radius: 5
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedMovie == movie ? Color.blue : Color.gray.opacity(0.3), lineWidth: selectedMovie == movie ? 2 : 1)
                        )
                        .animation(.spring(response: 0.3), value: hoveredMovie)
                        .animation(.spring(response: 0.3), value: selectedMovie)
                        .background(selectedMovie == movie ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                        .onTapGesture {
                            selectedMovie = movie
                            onMovieSelected(movie.url)
                        }
                }
            }
            .padding()
        }
    
    */
    
    var body: some View {
      
        VStack(spacing: 0) {
            slideView
                .padding(.horizontal)
            
            HStack {
                menuView
            }
            .padding()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(sortedMovies) { movie in
                            MovieCardView(movie: movie, onSelect: onMovieSelected, size: thumbnailSize)
                                .id(movie)
                                .onHover { isHovered in
                                    hoveredMovie = isHovered ? movie : nil
                                }
                           
                            
                               // .animation(.spring(response: 0.3), value: hoveredMovie)
                                //.animation(.spring(response: 0.3), value: selectedMovie)
                                .background(selectedMovie == movie ? Color.accentColor.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture(count: 1) { isSelected in 
                                    selectedMovie = movie
                                    onMovieSelected(movie.url)
                                }
                                
                        }
                        .onKeyPress(.leftArrow) {
                            if let current = selectedMovie,
                               let index = sortedMovies.firstIndex(of: current),
                               index > 0
                            {
                                selectedMovie = sortedMovies[index - 1]
                                onMovieSelected(sortedMovies[index - 1].url)
                            } else if selectedMovie == nil && !sortedMovies.isEmpty {
                                selectedMovie = sortedMovies[0]
                                onMovieSelected(sortedMovies[0].url)
                            }
                           
                            return .handled
                        }
                        .onKeyPress(.rightArrow) {
                            if let current = selectedMovie,
                               let index = sortedMovies.firstIndex(of: current),
                               index < sortedMovies.count - 1
                            {
                                selectedMovie = sortedMovies[index + 1]
                                onMovieSelected(sortedMovies[index + 1].url)
                            } else if selectedMovie == nil && !sortedMovies.isEmpty {
                                selectedMovie = sortedMovies[0]
                                onMovieSelected(sortedMovies[0].url)
                            }
                           
                            return .handled
                        }
                        .onKeyPress(.upArrow) {
                            if let current = selectedMovie,
                               let index = sortedMovies.firstIndex(of: current)
                            {
                                let columnsCount = max(1, Int(NSScreen.main?.frame.width ?? 1600) / Int(thumbnailSize))
                                let newIndex = max(0, index - columnsCount)
                                if newIndex != index {
                                    selectedMovie = sortedMovies[newIndex]
                                    onMovieSelected(sortedMovies[newIndex].url)
                                }
                            } else if !sortedMovies.isEmpty {
                                selectedMovie = sortedMovies[0]
                                onMovieSelected(sortedMovies[0].url)
                            }
                            return .handled
                        }
                        .onKeyPress(.downArrow) {
                            if let current = selectedMovie,
                               let index = sortedMovies.firstIndex(of: current)
                            {
                                let columnsCount = max(1, Int(NSScreen.main?.frame.width ?? 1600) / Int(thumbnailSize))
                                let newIndex = min(sortedMovies.count - 1, index + columnsCount)
                                if newIndex != index {
                                    selectedMovie = sortedMovies[newIndex]
                                    onMovieSelected(sortedMovies[newIndex].url)
                                }
                            } else if !sortedMovies.isEmpty {
                                selectedMovie = sortedMovies[0]
                                onMovieSelected(sortedMovies[0].url)
                            }
                            return .handled
                        }
                    }
                
                    .padding()
                }
            }
               
            
        }
        .overlay {
            if folderProcessor.movies.isEmpty && !folderProcessor.isProcessing {
                Text("No movies found")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
