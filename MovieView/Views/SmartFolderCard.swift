import SwiftUI

struct SmartFolderCard: View {
    let folder: SmartFolder
    var namespace: Namespace.ID
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            // Preview Section
            SmartFolderPreview(folder: folder)
                .matchedGeometryEffect(id: "preview-\(folder.id)", in: namespace)
            
            // Info Section
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                Text(folder.name)
                    .font(.headline)
                    .lineLimit(1)
                    .matchedGeometryEffect(id: "title-\(folder.id)", in: namespace)
                
                Text(formatDate(folder.dateCreated))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .matchedGeometryEffect(id: "date-\(folder.id)", in: namespace)
                
                Text(folder.criteria.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .matchedGeometryEffect(id: "criteria-\(folder.id)", in: namespace)
            }
            .padding(DesignTokens.Spacing.medium)
        }
        .frame(width: 200)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
                .shadow(
                    color: isHovered ? DesignTokens.Shadow.large : DesignTokens.Shadow.small,
                    radius: isHovered ? 10 : 5
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                .strokeBorder(isHovered ? Color.accentColor : .clear, lineWidth: 2)
        }
        .onHover { isHovered = $0 }
        .animation(DesignTokens.Animation.standard, value: isHovered)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
