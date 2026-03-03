//
//  RxNoteClipsApp.swift
//  RxNoteClips
//
//  App Clips entry point - uses AppClipRootView for deep link navigation
//

import RxNoteCore
import SwiftData
import SwiftUI

@main
struct RxNoteClipsApp: App {
    @State private var eventViewModel = EventViewModel()

    init() {
        // Clear tokens if running UI tests with --reset-auth flag
        if CommandLine.arguments.contains("--reset-auth") {
            let tokenStorage = KeychainTokenStorage(serviceName: "com.rxlab.RxNote")
            try? tokenStorage.clearAll()
        }
    }

    var body: some Scene {
        WindowGroup {
            AppClipRootView()
                .environment(eventViewModel)
        }
        .modelContainer(for: CustomPresetLabel.self)
    }
}
