import Foundation

let videoTypes = [
    "public.mpeg-4",
    "public.movie",
    "com.apple.quicktime-movie",
    "public.avi",
    "public.mpeg"
]

public func findVideosBetweenDates(start: Date, end: Date) async throws -> [URL] {
    let query = NSMetadataQuery()
    
    let datePredicate = NSPredicate(
        format: "kMDItemContentCreationDate >= %@ AND kMDItemContentCreationDate < %@",
        start as NSDate,
        end as NSDate
    )
    
    let typePredicates = videoTypes.map { type in
        NSPredicate(format: "kMDItemContentTypeTree == %@", type)
    }
    
    let typePredicate = NSCompoundPredicate(orPredicateWithSubpredicates: typePredicates)
    query.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, typePredicate])
    query.searchScopes = [NSMetadataQueryLocalComputerScope]
    query.sortDescriptors = [.init(key: "kMDItemContentCreationDate", ascending: true)]
    
    return try await withCheckedThrowingContinuation { @Sendable (continuation) in
        NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: .main
        ) { _ in
            let videos = (query.results as! [NSMetadataItem]).compactMap { item -> URL? in
                guard let path = item.value(forAttribute: "kMDItemPath") as? String else {
                    return nil
                }
                let url = URL(fileURLWithPath: path)
                return (url.lastPathComponent.lowercased().contains("amprv") || url.pathExtension.lowercased().contains("rmvb")) ? nil : url
            }
            continuation.resume(returning: videos)
            query.stop()
        }
        
        DispatchQueue.main.async {
            query.start()
        }
    }
}

public func findTodayVideos() async throws -> [URL] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
    return try await findVideosBetweenDates(start: today, end: tomorrow)
}