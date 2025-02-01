import SwiftUI

struct BookmarkRow: View {
    let bookmark: FolderBookmark
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Label(bookmark.name, systemImage: "folder.fill")
            Spacer()
            VStack(alignment: .trailing) {
                Text(bookmark.url.lastPathComponent)
                    .foregroundStyle(.secondary)
                Text("Last accessed: \(bookmark.lastAccessed.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Remove Bookmark", systemImage: "trash")
            }
        }
        .onTapGesture(perform: onTap)
    }
}

struct BookmarksView: View {
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @ObservedObject var folderProcessor: FolderProcessor
    @State private var isShowingFolderPicker = false
    @State private var newBookmarkName = ""
    @State private var selectedURL: URL?
    @State private var showingNamePrompt = false
    
    var body: some View {
        List {
            ForEach(bookmarkManager.bookmarks) { bookmark in
                BookmarkRow(
                    bookmark: bookmark,
                    onTap: {
                        bookmarkManager.updateLastAccessed(id: bookmark.id)
                        Task {
                            try? await folderProcessor.processFolder(at: bookmark.url)
                        }
                    },
                    onDelete: {
                        bookmarkManager.removeBookmark(id: bookmark.id)
                    }
                )
            }
        }
        .overlay {
            if folderProcessor.isProcessing {
                ProgressView("Processing folder...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingFolderPicker = true
                } label: {
                    Label("Add Bookmark", systemImage: "plus")
                }
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
                    selectedURL = url
                    showingNamePrompt = true
                }
            case .failure(let error):
                print("Error selecting folder: \(error.localizedDescription)")
            }
        }
        .alert("Bookmark Name", isPresented: $showingNamePrompt) {
            TextField("Name", text: $newBookmarkName)
            Button("Cancel", role: .cancel) {
                selectedURL = nil
                newBookmarkName = ""
            }
            Button("Add") {
                if let url = selectedURL {
                    bookmarkManager.addBookmark(name: newBookmarkName, url: url)
                    selectedURL = nil
                    newBookmarkName = ""
                }
            }
        } message: {
            Text("Enter a name for this bookmark")
        }
    }
} 