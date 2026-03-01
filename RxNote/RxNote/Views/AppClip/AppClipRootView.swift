//
//  AppClipRootView.swift
//  RxNote
//
//  Root view for App Clips - handles deep links and shows view-only note preview
//

import RxNoteCore
import SwiftUI

/// Root view for App Clips
/// Handles incoming URLs via backend QR code resolution and displays note in view-only mode
/// Implements proper auth flow:
/// 1. First try to fetch note without auth (works for public notes)
/// 2. If 401, show sign-in button
/// 3. After sign-in, retry fetching
/// 4. If 403, show access denied
struct AppClipRootView: View {
    @State private var noteId: Int?
    @State private var parseError: String?
    @State private var oauthManager = OAuthManager(
        configuration: AppConfiguration.shared.rxAuthConfiguration
    )

    /// Service for QR code resolution
    private let qrCodeService = QrCodeService()

    /// Store resolved URL for retry after authentication
    @State private var resolvedNoteUrl: String?

    /// Store original QR content for retry after authentication
    @State private var originalQrContent: String?

    // Auth flow states
    @State private var needsAuth = false
    @State private var accessDenied = false
    @State private var isLoading = false
    @State private var loadError: Error?

    /// Sign out confirmation state
    @State private var showSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if needsAuth {
                    RxSignInView(
                        manager: oauthManager,
                        appearance: RxSignInAppearance(
                            icon: .systemImage("lock.shield.fill"),
                            title: "Sign In Required",
                            subtitle: "This note is private. Please sign in to view it.",
                            signInButtonTitle: "Sign In with RxLab"
                        ),
                        onAuthSuccess: {
                            Task {
                                if let qrcontent = originalQrContent {
                                    await fetchNoteFromQrCode(qrcontent)
                                }
                            }
                        }
                    )
                } else if accessDenied {
                    AppClipAccessDeniedView(
                        userEmail: oauthManager.currentUser?.email,
                        onTryDifferentAccount: { Task { await tryDifferentAccount() } }
                    )
                } else if let error = parseError {
                    ContentUnavailableView(
                        "Invalid URL",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    .accessibilityIdentifier("invalid-url")
                } else if isLoading {
                    loadingView
                } else if noteId != nil {
                    // TODO: Replace with NoteDetailView after OpenAPI regen
                    ContentUnavailableView(
                        "Note Preview",
                        systemImage: "note.text",
                        description: Text("Note detail view coming soon")
                    )
                    .toolbar {
                        if oauthManager.currentUser != nil {
                            ToolbarItem(placement: .primaryAction) {
                                Menu {
                                    Button(role: .destructive) {
                                        showSignOutConfirmation = true
                                    } label: {
                                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                    }
                                    .accessibilityIdentifier("app-clips-sign-out-button")
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                }
                                .accessibilityIdentifier("app-clips-more-menu")
                            }
                        }
                    }
                    .confirmationDialog(
                        title: "Sign Out",
                        message: "Are you sure you want to sign out?",
                        confirmButtonTitle: "Sign Out",
                        isPresented: $showSignOutConfirmation
                    ) {
                        Task {
                            await oauthManager.logout()
                            if let qrcontent = originalQrContent {
                                await fetchNoteFromQrCode(qrcontent)
                            }
                        }
                    }
                } else if let error = loadError {
                    errorView(error: error)
                } else if noteId == nil {
                    ProgressView("Waiting for URL...")
                } else {
                    ProgressView("Loading...")
                }
            }
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
            handleUserActivity(userActivity)
        }
        .onOpenURL { url in
            handleUrl(url)
        }
        .onAppear {
            if let urlString = UserDefaults.standard.string(forKey: "AppClipURLKey"),
               let url = URL(string: urlString)
            {
                handleUrl(url)
            }
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        ZStack {
            AnimatedGradientBackground()
            ProgressView("Loading...")
        }
    }

    private func errorView(error: Error) -> some View {
        VStack {
            ContentUnavailableView(
                "Error Loading Note",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription)
            )

            Button("Retry") {
                Task {
                    if let qrcontent = originalQrContent {
                        await fetchNoteFromQrCode(qrcontent)
                    }
                }
            }
        }
    }

    // MARK: - URL Handling

    private func handleUserActivity(_ userActivity: NSUserActivity) {
        guard let url = userActivity.webpageURL else {
            parseError = "No URL provided"
            return
        }
        handleUrl(url)
    }

    private func handleUrl(_ url: URL) {
        let qrcontent = url.absoluteString
        Task {
            await fetchNoteFromQrCode(qrcontent)
        }
    }

    // MARK: - Fetch Note via QR Code

    private func fetchNoteFromQrCode(_ qrcontent: String) async {
        // Reset states
        needsAuth = false
        accessDenied = false
        parseError = nil
        loadError = nil
        isLoading = true

        // Store the original QR content for retry after auth
        originalQrContent = qrcontent

        defer { isLoading = false }

        do {
            let scanResponse = try await qrCodeService.scanQrCode(qrcontent: qrcontent)
            resolvedNoteUrl = scanResponse.url

            // Extract note ID from URL
            if let id = extractNoteId(from: scanResponse.url) {
                noteId = id
            } else {
                parseError = "Could not parse note ID from URL"
            }

        } catch let error as APIError {
            switch error {
            case .unauthorized:
                needsAuth = true
            case .forbidden:
                accessDenied = true
            case let .unsupportedQRCode(message):
                parseError = message
            default:
                loadError = error
            }
        } catch {
            loadError = error
        }
    }

    // MARK: - Helpers

    private func extractNoteId(from urlString: String) -> Int? {
        guard let url = URL(string: urlString) else { return nil }
        let components = url.pathComponents
        if let notesIndex = components.firstIndex(of: "notes"),
           notesIndex + 1 < components.count,
           let id = Int(components[notesIndex + 1])
        {
            return id
        }
        return nil
    }

    // MARK: - Authentication

    private func tryDifferentAccount() async {
        await oauthManager.logout()
        needsAuth = true
    }
}

#Preview {
    AppClipRootView()
}
