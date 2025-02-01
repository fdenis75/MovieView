import SwiftUI

struct MosaicConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var config: MosaicConfig
    let onGenerate: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Dimensions") {
                    Picker("Width", selection: $config.width) {
                        Text("1920").tag(1920)
                        Text("2560").tag(2560)
                        Text("3840").tag(3840)
                    }
                    .pickerStyle(.segmented)
                    
                    Toggle("Auto Layout", isOn: $config.useAutoLayout)
                        .help("Optimize layout for screen size")
                }
                
                Section("Density") {
                    Picker("Thumbnail Density", selection: $config.density) {
                        ForEach(DensityConfig.allCases, id: \.self) { density in
                            Text(density.name).tag(density)
                        }
                    }
                }
                
                Section("Style") {
                    Toggle("Add Border", isOn: $config.addBorder)
                    
                    if config.addBorder {
                        ColorPicker("Border Color", selection: .init(
                            get: { Color(cgColor: config.borderColor) },
                            set: { config.borderColor = $0.cgColor! }
                        ))
                        
                        Slider(value: $config.borderWidth, in: 1...5) {
                            Text("Border Width")
                        } minimumValueLabel: {
                            Text("1")
                        } maximumValueLabel: {
                            Text("5")
                        }
                    }
                    
                    Toggle("Add Shadow", isOn: $config.addShadow)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Mosaic Configuration")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        onGenerate()
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }
} 