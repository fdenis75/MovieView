import SwiftUI

struct SmartFolderCard: View {
    let folder: SmartFolder
    let namespace: Namespace.ID  // for matched geometry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Folder Name
            Text(folder.name)
                .font(.headline)
                .foregroundColor(.primary)
            
            // Creation Date
            Text(formatDate(folder.dateCreated))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            // Gradient background that adapts to system colors.
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 4)
        // This modifier makes it available for animated transitions.
        .matchedGeometryEffect(id: folder.id, in: namespace)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
