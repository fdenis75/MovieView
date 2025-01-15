import SwiftUI

struct DateRangePicker: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onSearch: () -> Void
    let isSearching: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            DatePicker(
                "Start Date",
                selection: $startDate,
                displayedComponents: [.date]
            )
            
            DatePicker(
                "End Date",
                selection: $endDate,
                in: startDate...,
                displayedComponents: [.date]
            )
            
            Button(action: onSearch) {
                if isSearching {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Find Videos")
                }
            }
            .disabled(isSearching)
        }
        .padding()
        .frame(width: 300)
    }
} 