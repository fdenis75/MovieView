import SwiftUI

struct SmartFolderCard: View {
    let folder: SmartFolder

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(folder.name)
                .font(.headline)
                .foregroundColor(.primary)

            if let mosaicName = folder.criteria.generateMosaicFolderName() {
                Text(mosaicName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(folder.dateCreated, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            // A gradient that adapts to dark/light modes
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.blue.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}