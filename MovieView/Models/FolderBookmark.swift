import Foundation

struct FolderBookmark: Identifiable, Codable {
    let id: UUID
    let name: String
    let url: URL
    let dateAdded: Date
    var lastAccessed: Date
    
    init(name: String, url: URL) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.dateAdded = Date()
        self.lastAccessed = Date()
    }
}

@MainActor
class BookmarkManager: ObservableObject {
    static let shared = BookmarkManager()
    @Published private(set) var bookmarks: [FolderBookmark] = []
    
    private let bookmarksKey = "folderBookmarks"
    
    init() {
        loadBookmarks()
    }
    
    func addBookmark(name: String, url: URL) {
        if let index = bookmarks.firstIndex(where: { $0.url == url }) {
            var bookmark = bookmarks[index]
            bookmark.lastAccessed = Date()
            bookmarks[index] = bookmark
        } else {
            let bookmark = FolderBookmark(name: name, url: url)
            bookmarks.append(bookmark)
        }
        saveBookmarks()
    }
    
    func removeBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
        saveBookmarks()
    }
    
    func updateLastAccessed(id: UUID) {
        if let index = bookmarks.firstIndex(where: { $0.id == id }) {
            var bookmark = bookmarks[index]
            bookmark.lastAccessed = Date()
            bookmarks[index] = bookmark
            saveBookmarks()
        }
    }
    
    private func loadBookmarks() {
        guard let data = UserDefaults.standard.data(forKey: bookmarksKey) else { return }
        do {
            bookmarks = try JSONDecoder().decode([FolderBookmark].self, from: data)
        } catch {
            print("Error loading bookmarks: \(error)")
        }
    }
    
    private func saveBookmarks() {
        do {
            let data = try JSONEncoder().encode(bookmarks)
            UserDefaults.standard.set(data, forKey: bookmarksKey)
        } catch {
            print("Error saving bookmarks: \(error)")
        }
    }
} 