//
//  AdaptiveRootView.swift
//  RxNote
//
//  Main view that detects size class and switches between TabBar/Sidebar navigation
//

import SwiftUI

/// Adaptive root view that uses TabView on iPhone and NavigationSplitView on iPad
struct AdaptiveRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var navigationManager = NavigationManager()
    
    /// Binding to pending deep link URL from ContentView (received before auth completed)
    @Binding var pendingDeepLinkURL: URL?

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                // iPhone: TabView with TabBar
                TabBarView()
            } else {
                // iPad/macOS: NavigationSplitView with Sidebar
                SidebarNavigationView()
            }
        }
        .environment(navigationManager)
        // Handle universal links (https://...)
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
            if let url = userActivity.webpageURL {
                Task {
                    await navigationManager.handleDeepLink(url)
                }
            }
        }
        // Handle custom URL scheme (rxnote://...)
        .onOpenURL { url in
            Task {
                await navigationManager.handleDeepLink(url)
            }
        }
        // Process pending deep link once when view first appears
        .onAppear {
            if let url = pendingDeepLinkURL {
                let urlToProcess = url
                pendingDeepLinkURL = nil
                Task {
                    await navigationManager.handleDeepLink(urlToProcess)
                }
            }
        }
        .alert("Deep Link Error", isPresented: $navigationManager.showDeepLinkError) {
            Button("OK", role: .cancel) {}
                .accessibilityIdentifier("deep-link-error-ok-button")
        } message: {
            if let error = navigationManager.deepLinkError {
                Text(error.localizedDescription)
                    .accessibilityIdentifier("deep-link-error-message")
            }
        }
        .overlay {
            if navigationManager.isLoadingDeepLink {
                ZStack {
                    Color.black.opacity(0.3)
                    ProgressView("Loading note...")
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(10)
                }
                .ignoresSafeArea()
            }
        }
    }
}

#Preview {
    AdaptiveRootView(pendingDeepLinkURL: .constant(nil))
}
