//
//  HelloMacApp.swift
//  HelloMac
//
//  Created by Zachary DeParle on 9/2/25.
//

import SwiftUI

@main
struct HelloMacApp: App {
    // Keep a strong reference to hotkeys for the app lifetime
    private let hotKeys = HotKeyManager()

    init() {
        // Prompt for Accessibility permission up front (if not granted)
        _ = WindowTiler.ensureAccessibility(prompt: true)
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
