import SwiftUI

struct DensityPicker: View {
    @Binding var density: DensityConfig
    @ObservedObject var videoProcessor: VideoProcessor
    let isDisabled: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Spacer()
                Picker("Density", selection: $density) {
                    ForEach(DensityConfig.allCases, id: \.name) { density in
                        Text(density.name).tag(density)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
                .disabled(isDisabled)
                .onChange(of: density) { newDensity in
                    videoProcessor.reprocessCurrentVideo()
                }
            }
            
            if videoProcessor.expectedThumbnailCount > 0 {
                Text("\(videoProcessor.expectedThumbnailCount) thumbnails")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical)
    }
} 