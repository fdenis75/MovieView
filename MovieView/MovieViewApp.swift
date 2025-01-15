//
//  MovieViewApp.swift
//  MovieView
//
//  Created by Francois on 11/01/2025.
//

import SwiftUI

@main
struct MovieViewApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minWidth: 1000, minHeight: 800)
                
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
