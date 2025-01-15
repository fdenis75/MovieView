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
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
