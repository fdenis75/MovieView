//
//  MOvieViewApp.swift
//  MOvieView
//
//  Created by Francois on 16/01/2025.
//

import SwiftUI
import SwiftData

@main
struct MovieViewApp: App {
    var body: some Scene {
        WindowGroup {
            ModernHomeView()
                .frame(minWidth: 1000, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
