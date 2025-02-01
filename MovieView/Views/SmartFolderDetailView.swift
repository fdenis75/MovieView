//
//  SmartFolderDetailView.swift
//  MovieView
//
//  Created by Francois on 01/02/2025.
//


import SwiftUI

struct SmartFolderDetailView: View {
    let folder: SmartFolder
    var namespace: Namespace.ID
    @Binding var isPresented: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                // Reuse the card view appearance with the matched geometry effect.
                SmartFolderCard(folder: folder, namespace: namespace)
                    .padding()
                
                // Additional details about the folder can go here.
                Text("Folder created on: \(formatDate(folder.dateCreated))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Folder criteria: \(folder.criteria.description)")
                
                // Add any extra actions or info as needed.
                Spacer()
            }
            .padding()
            
            // Custom Back Button.
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isPresented = false
                }
            }) {
                Label("Back", systemImage: "chevron.left")
                    .padding()
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}