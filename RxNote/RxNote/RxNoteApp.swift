//
//  RxNoteApp.swift
//  RxNote
//
//  Created by Qiwei Li on 1/27/26.
//

import RxNoteCore
import SwiftUI

@main
struct RxNoteApp: App {
    @State private var eventViewModel = EventViewModel()
    @State private var authManager = OAuthManager(
        configuration: AppConfiguration.shared.rxAuthConfiguration
    )

    init() {
        // Clear tokens if running UI tests with --reset-auth flag
        if CommandLine.arguments.contains("--reset-auth") {
            let tokenStorage = KeychainTokenStorage(serviceName: "com.rxlab.RxNote")
            try? tokenStorage.clearAll()
        }

        #if DEBUG
            // Handle --test-qr-code launch argument for UI testing
            if let qrIndex = CommandLine.arguments.firstIndex(of: "--test-qr-code"),
               qrIndex + 1 < CommandLine.arguments.count
            {
                let qrContent = CommandLine.arguments[qrIndex + 1]
                UserDefaults.standard.set(qrContent, forKey: "testQRCodeContent")
            }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView(authManager: authManager)
                .environment(eventViewModel)
                .environment(authManager)
                .task {
                    await authManager.checkExistingAuth()
                }
        }
        #if os(macOS)
        .defaultSize(width: 500, height: 600)
        .windowResizability(.contentSize)
        #endif
    }
}
