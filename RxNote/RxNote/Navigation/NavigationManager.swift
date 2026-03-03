//
//  NavigationManager.swift
//  RxNote
//
//  Centralized navigation state manager for adaptive navigation
//

import Observation
import RxNoteCore
import SwiftUI

/// Errors that can occur during deep link handling
enum DeepLinkError: LocalizedError {
    case invalidURL(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Unable to open link: \(url)"
        }
    }
}

/// Navigation destinations for NavigationStack
enum AppDestination: Hashable {
    case noteDetail(id: String)
    case webPage(WebPage)
}

/// Main tabs in TabView (iPhone) and sections in Sidebar (iPad)
enum AppTab: String, CaseIterable, Identifiable {
    case notes = "Notes"
    case settings = "Settings"

    var id: String {
        rawValue
    }

    var systemImage: String {
        switch self {
        case .notes: return "note.text"
        case .settings: return "gearshape"
        }
    }
}

/// Centralized navigation state manager
@Observable
@MainActor
final class NavigationManager {
    // MARK: - Tab/Section Selection

    /// Currently selected tab (TabView) or section (Sidebar)
    var selectedTab: AppTab = .notes

    // MARK: - Detail Selection State

    /// Selected note ID for detail view (iPad split view)
    var selectedNoteId: String?

    // MARK: - Navigation Paths (for NavigationStack in TabView)

    /// Navigation path for Notes tab
    var notesNavigationPath = NavigationPath()

    /// Navigation path for Settings tab
    var settingsNavigationPath = NavigationPath()

    // MARK: - Deep Link State

    var isLoadingDeepLink = false
    var deepLinkError: Error?
    var showDeepLinkError = false

    // MARK: - Column Visibility (iPad)

    var columnVisibility: NavigationSplitViewVisibility = .automatic

    // MARK: - Services

    private let qrCodeService = QrCodeService()

    // MARK: - Navigation Methods

    /// Navigate to a note by its ID
    func navigateToNote(id: String) {
        if selectedTab != .notes {
            selectedTab = .notes
        }
        selectedNoteId = id
        notesNavigationPath.append(AppDestination.noteDetail(id: id))
    }

    /// Navigate to notes tab
    func navigateToNotes() {
        selectedTab = .notes
    }

    /// Clear all detail selections
    func clearSelections() {
        selectedNoteId = nil
    }

    /// Clear navigation paths
    func clearNavigationPaths() {
        notesNavigationPath = NavigationPath()
        settingsNavigationPath = NavigationPath()
    }

    // MARK: - Deep Link Handling

    /// Handle deep link URL by resolving via backend QR code service
    func handleDeepLink(_ url: URL) async {
        isLoadingDeepLink = true
        defer { isLoadingDeepLink = false }

        do {
            // Resolve URL via QR code scan endpoint
            let scanResponse = try await qrCodeService.scanQrCode(qrcontent: url.absoluteString)

            // Extract note ID from the resolved URL
            guard let noteId = extractNoteId(from: scanResponse.url) else {
                throw DeepLinkError.invalidURL(url.absoluteString)
            }
            
            if selectedTab != .notes {
                selectedTab = .notes
            }
            selectedNoteId = noteId
            notesNavigationPath.append(AppDestination.noteDetail(id: noteId))
        } catch {
            deepLinkError = error
            // Small delay to ensure view hierarchy is stable before showing alert
            try? await Task.sleep(for: .milliseconds(100))
            showDeepLinkError = true
        }
    }

    // MARK: - Helpers

    /// Extract note ID from a URL path like /api/v1/notes/{id}
    private func extractNoteId(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        let components = url.pathComponents
        if let notesIndex = components.firstIndex(of: "notes"),
           notesIndex + 1 < components.count
        {
            return components[notesIndex + 1]
        }
        return nil
    }
}
