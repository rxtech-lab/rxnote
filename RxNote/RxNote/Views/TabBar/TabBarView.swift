//
//  TabBarView.swift
//  RxNote
//
//  TabView implementation for iPhone (compact size class)
//

import RxNoteCore
import SwiftUI

/// TabView with tabs for iPhone navigation: Notes, QR Scanner, Settings
struct TabBarView: View {
    @Environment(NavigationManager.self) private var navigationManager

    #if os(iOS)
    @State private var showQrCodeScanner = false
    @State private var isLoadingFromQR = false
    private let qrCodeService = QrCodeService()
    #endif

    var body: some View {
        @Bindable var nav = navigationManager

        TabView(selection: $nav.selectedTab) {
            // Notes Tab
            NavigationStack(path: $nav.notesNavigationPath) {
                NoteListView()
                #if os(iOS)
                    .qrCodeScannerToolbar(isPresented: $showQrCodeScanner)
                #endif
                    .navigationDestination(for: AppDestination.self) { destination in
                        switch destination {
                        case .noteDetail(let id):
                            NoteDetailView(noteId: id)
//                            Text("Note Detail for ID: \(id)")
                        case .webPage(let page):
                            WebPageView(page: page)
                        }
                    }
            }
            .tabItem {
                Label(AppTab.notes.rawValue, systemImage: AppTab.notes.systemImage)
            }
            .tag(AppTab.notes)
            .accessibilityIdentifier("tab-notes")

            // Settings Tab
            NavigationStack(path: $nav.settingsNavigationPath) {
                SettingsView()
                #if os(iOS)
                    .qrCodeScannerToolbar(isPresented: $showQrCodeScanner)
                #endif
                    .navigationDestination(for: AppDestination.self) { destination in
                        switch destination {
                        case .noteDetail(let id):
                            NoteDetailView(noteId: id)
                        case .webPage(let page):
                            WebPageView(page: page)
                        }
                    }
            }
            .tabItem {
                Label(AppTab.settings.rawValue, systemImage: AppTab.settings.systemImage)
            }
            .tag(AppTab.settings)
            .accessibilityIdentifier("tab-settings")
        }
        #if os(iOS)
        .sheet(isPresented: $showQrCodeScanner) {
            NavigationStack {
                QRCodeScannerView { code in
                    showQrCodeScanner = false
                    Task {
                        await handleScannedQRCode(code)
                    }
                }
            }
        }
        .overlay {
            if isLoadingFromQR {
                LoadingOverlay(title: "Loading note from QR code...")
            }
        }
        #endif
    }

    #if os(iOS)
    private func handleScannedQRCode(_ code: String) async {
        isLoadingFromQR = true
        defer { isLoadingFromQR = false }

        do {
            let scanResponse = try await qrCodeService.scanQrCode(qrcontent: code)
            if let noteId = extractNoteId(from: scanResponse.url) {
                navigationManager.navigateToNote(id: noteId)
            }
        } catch {
            navigationManager.deepLinkError = error
            navigationManager.showDeepLinkError = true
        }
    }

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
    #endif
}

#Preview {
    TabBarView()
        .environment(NavigationManager())
}
