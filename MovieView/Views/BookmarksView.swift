import SwiftUI

struct BookmarksView: View {
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @State private var isShowingFolderPicker = false
    @State private var newBookmarkName = ""
    @State private var selectedURL: URL?
    @State private var showingNamePrompt = false
    
    var body: some View {
        List {
            ForEach(bookmarkManager.bookmarks) { bookmark in
                HStack {
                    Label(bookmark.name, systemImage: "folder.fill")
                    Spacer()
                    Text(bookmark.url.lastPathComponent)
                        .foregroundStyle(.secondary)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        bookmarkManager.removeBookmark(id: bookmark.id)
                    } label: {
                        Label("Remove Bookmark", systemImage: "trash")
                    }
                }
                .onTapGesture {
                    bookmarkManager.updateLastAccessed(id: bookmark.id)
                    // Handle opening the folder
                }
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