import Foundation

struct SmartFolder: Identifiable, Codable {
    let id: UUID
    var name: String
    var criteria: SmartFolderCriteria
    let dateCreated: Date
    var mosaicDirName: String?
    
    init(name: String, criteria: SmartFolderCriteria) {
        self.id = UUID()
        self.name = name
        self.criteria = criteria
        self.dateCreated = Date()
        self.mosaicDirName = criteria.generateMosaicFolderName()
    }
}

struct SmartFolderCriteria: Codable {
    var dateRange: DateRange?
    var nameContains: String?
    var folderNameContains: String?
    var minDuration: TimeInterval?
    var maxDuration: TimeInterval?
    var fileSize: FileSizeRange?
    var fileTypes: [String]?
    
    struct DateRange: Codable {
        var start: Date?
        var end: Date?
    }
    
    struct FileSizeRange: Codable {
        var min: Int64?
        var max: Int64?
    }
    
    /// Returns a short string suitable for use as a mosaic folder name.
    /// The string is generated based on the criteria settings.
    /// - Returns: A string that summarizes the criteria, or nil if no criteria are set.
    func generateMosaicFolderName() -> String? {
        var components: [String] = []
        
        // Add name filter if present
        if let name = nameContains, !name.isEmpty {
            components.append("n-\(name)")
        }
        
        // Add folder filter if present 
        if let folder = folderNameContains, !folder.isEmpty {
            components.append("f-\(folder)")
        }
        
        // Add date range if present
        if let dates = dateRange {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyMMdd"
            if let start = dates.start {
                components.append("from-\(formatter.string(from: start))")
            }
            if let end = dates.end {
                components.append("to-\(formatter.string(from: end))")
            }
        }
        
        // Add size range if present
        if let size = fileSize {
            if let min = size.min {
                components.append("min\(min/1_000_000)MB")
            }
            if let max = size.max {
                components.append("max\(max/1_000_000)MB") 
            }
        }
        
        // Return nil if no criteria are set
        guard !components.isEmpty else { return nil }
        
        // Join with underscores and limit length
        let joined = components.joined(separator: "_")
        let maxLength = 50
        if joined.count <= maxLength {
            return joined
        }
        return String(joined.prefix(maxLength))
    }
}

@MainActor
class SmartFolderManager: ObservableObject {
    static let shared = SmartFolderManager()
    @Published private(set) var smartFolders: [SmartFolder] = []
    
    private let smartFoldersKey = "smartFolders"
    
    init() {
        loadSmartFolders()
        smartFolders = createDefaultSmartFolders() + smartFolders
    }
    
    func addSmartFolder(name: String, criteria: SmartFolderCriteria) {
        let folder = SmartFolder(name: name, criteria: criteria)
        smartFolders.append(folder)
        saveSmartFolders()
    }
    
    func removeSmartFolder(id: UUID) {
        // Only remove if it's not a default folder
        if !createDefaultSmartFolders().contains(where: { $0.id == id }) {
            smartFolders.removeAll { $0.id == id }
            saveSmartFolders()
        }
    }
    
    func updateSmartFolder(_ folder: SmartFolder) {
        if let index = smartFolders.firstIndex(where: { $0.id == folder.id }) {
            smartFolders[index] = folder
            saveSmartFolders()
        }
    }
    
    func matchesCriteria(movie: MovieFile, criteria: SmartFolderCriteria) -> Bool {
        // Check name contains
        if let nameContains = criteria.nameContains,
           !nameContains.isEmpty,
           !movie.name.localizedStandardContains(nameContains) {
            return false
        }
        
        // Check folder name contains
        if let folderNameContains = criteria.folderNameContains,
           !folderNameContains.isEmpty {
            let components = movie.relativePath.split(separator: "/")
            if let folderName = components.first.map(String.init),
               !folderName.localizedStandardContains(folderNameContains) {
                return false
            }
        }
        
        // Check date range
        if let dateRange = criteria.dateRange,
           let resourceValues = try? movie.url.resourceValues(forKeys: [.contentModificationDateKey]),
           let modificationDate = resourceValues.contentModificationDate {
            if let start = dateRange.start, modificationDate < start {
                return false
            }
            if let end = dateRange.end, modificationDate > end {
                return false
            }
        }
        
        // Check file size
        if let fileSize = criteria.fileSize,
           let resourceValues = try? movie.url.resourceValues(forKeys: [.fileSizeKey]),
           let size = resourceValues.fileSize {
            if let min = fileSize.min, Int64(size) < min {
                return false
            }
            if let max = fileSize.max, Int64(size) > max {
                return false
            }
        }
        
        // Check file types
        if let fileTypes = criteria.fileTypes,
           !fileTypes.isEmpty,
           !fileTypes.contains(movie.url.pathExtension.lowercased()) {
            return false
        }
        
        return true
    }
    
    private func createDefaultSmartFolders() -> [SmartFolder] {
        let today = SmartFolder(
            name: "Today's videos",
            criteria: SmartFolderCriteria(
                dateRange: .init(
                    start: Calendar.current.startOfDay(for: Date()),
                    end: Calendar.current.date(byAdding: .day, value: +1, to: Date())
                )
            )
        )
        
        let recent = SmartFolder(
            name: "Recent Videos",
            criteria: SmartFolderCriteria(
                dateRange: .init(
                    start: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
                    end: Date()
                )
            )
        )
        
        let large = SmartFolder(
            name: "Large Videos",
            criteria: SmartFolderCriteria(
                fileSize: .init(min: 4_000_000_000)
            )
        )
        
        return [today, recent, large]
    }
    
    private func loadSmartFolders() {
        guard let data = UserDefaults.standard.data(forKey: smartFoldersKey) else { return }
        do {
            smartFolders = try JSONDecoder().decode([SmartFolder].self, from: data)
        } catch {
            print("Error loading smart folders: \(error)")
        }
    }
    
    private func saveSmartFolders() {
        do {
            let data = try JSONEncoder().encode(smartFolders)
            UserDefaults.standard.set(data, forKey: smartFoldersKey)
        } catch {
            print("Error saving smart folders: \(error)")
        }
    }
} 
