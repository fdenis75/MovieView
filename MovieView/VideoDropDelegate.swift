import SwiftUI
import UniformTypeIdentifiers

struct VideoDropDelegate: DropDelegate {
    let videoProcessor: VideoProcessor
    let folderProcessor: FolderProcessor
    let onStateChange: (ViewState) -> Void
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [UTType.movie]) || info.hasItemsConforming(to: [UTType.folder])
    }
    
    func performDrop(info: DropInfo) -> Bool {
        if let provider = info.itemProviders(for: [UTType.movie]).first {
            videoProcessor.processDraggedItems(provider)
            onStateChange(.processing)
            return true
        }
        
        if let provider = info.itemProviders(for: [UTType.folder]).first {
            provider.loadItem(forTypeIdentifier: UTType.folder.identifier, options: nil) { (folderURL, error) in
                if let error = error {
                    Task { @MainActor in
                        folderProcessor.setError(AppError.unknownError(error.localizedDescription))
                    }
                    return
                }
                
                guard let url = folderURL as? URL else {
                    Task { @MainActor in
                        folderProcessor.setError(AppError.invalidVideoFile(URL(fileURLWithPath: "")))
                    }
                    return
                }
                
                Task { @MainActor in
                    try await folderProcessor.processFolder(at: url)
                    onStateChange(.folder)
                }
            }
            return true
        }
        
        return false
    }
} 
