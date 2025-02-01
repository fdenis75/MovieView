import SwiftUI
import AVKit

struct MovieInfoCard: View {
    let movie: MovieFile
    let onOpenIINA: () -> Void
    let expectedThumbnailCount: Int
    @State private var isGeneratingPreview = false
    @State private var previewError: Error?
    @State private var showingError = false
    @State private var previewDuration: Double = 30.0
    @State private var showingDurationPicker = false
    @State private var generationProgress: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Text(movie.name)
                    .font(.headline)
                Spacer()
                
                if isGeneratingPreview {
                    VStack(alignment: .trailing, spacing: 4) {
                        ProgressView(value: generationProgress) {
                            Text("\(Int(generationProgress * 100))%")
                                .font(.caption)
                        }
                        .frame(width: 100)
                    }
                    .padding(.trailing, 8)
                }
                
                Button(action: { showingDurationPicker = true }) {
                    Label("Preview Settings", systemImage: "gear")
                }
                .buttonStyle(.bordered)
                .popover(isPresented: $showingDurationPicker) {
                    VStack(spacing: DesignSystem.Spacing.medium) {
                        Text("Preview Duration")
                            .font(.headline)
                        
                        Slider(value: $previewDuration, in: 10...60, step: 5) {
                            Text("Duration: \(Int(previewDuration))s")
                        }
                        
                        Text("\(Int(previewDuration)) seconds")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(width: 250)
                }
                
                Button(action: generatePreview) {
                    Label("Generate Preview", systemImage: "film.stack")
                }
                .buttonStyle(.bordered)
                .disabled(isGeneratingPreview)
                
                Button(action: onOpenIINA) {
                    Label("Open in IINA", systemImage: "play.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            
            MovieInfoGrid(movie: movie)
        }
        .cardStyle()
        .padding(.horizontal)
        .alert("Preview Generation Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(previewError?.localizedDescription ?? "Unknown error")
        }
    }
    
    private func generatePreview() {
        isGeneratingPreview = true
        generationProgress = 0
        
        Task {
            do {
                let previewURL = try await VideoPreviewGenerator.generatePreview(
                    from: movie.url,
                    duration: previewDuration,
                    thumbnailCount: expectedThumbnailCount,
                    progress: { progress in
                        Task { @MainActor in
                            generationProgress = progress
                        }
                    }
                )
                
                await MainActor.run {
                    isGeneratingPreview = false
                    generationProgress = 0
                    NSWorkspace.shared.open(previewURL)
                }
            } catch {
                await MainActor.run {
                    isGeneratingPreview = false
                    generationProgress = 0
                    previewError = error
                    showingError = true
                }
            }
        }
    }
} 