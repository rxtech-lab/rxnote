//
//  SidebarNavigationView.swift
//  RxNote
//
//  NavigationSplitView implementation for iPad (regular size class)
//

import RxNoteCore
import SwiftUI

/// NavigationSplitView with sidebar for iPad
struct SidebarNavigationView: View {
    @Environment(NavigationManager.self) private var navigationManager

    #if os(iOS)
        @State private var showQrCodeScanner = false
        @State private var isLoadingFromQR = false
        private let qrCodeService = QrCodeService()
    #endif

    var body: some View {
        @Bindable var nav = navigationManager

        NavigationSplitView(columnVisibility: $nav.columnVisibility) {
            // Column 1: Sidebar
            #if os(iOS)
                SidebarContent(showQrCodeScanner: $showQrCodeScanner)
            #else
                SidebarContent()
            #endif
        } detail: {
            // Column 2: Detail
            DetailColumn()
            #if os(macOS)
                .frame(minWidth: 400)
            #endif
        }
        .navigationSplitViewStyle(.balanced)
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

// MARK: - Sidebar Content

/// Sidebar with navigation sections
struct SidebarContent: View {
    @Environment(NavigationManager.self) private var navigationManager

    #if os(iOS)
        @Binding var showQrCodeScanner: Bool

        init(showQrCodeScanner: Binding<Bool>) {
            _showQrCodeScanner = showQrCodeScanner
        }
    #else
        init() {}
    #endif

    var body: some View {
        List {
            Section {
                SidebarButton(tab: .notes)
            }

            Section {
                SidebarButton(tab: .settings)
            }
        }
        .navigationTitle("RxNote")
        .listStyle(.sidebar)
        #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showQrCodeScanner = true
                    } label: {
                        Label("Scan", systemImage: "qrcode.viewfinder")
                    }
                    .accessibilityIdentifier("qr-scanner-button")
                }
            }
        #endif
    }
}

/// Sidebar button for tabs
struct SidebarButton: View {
    let tab: AppTab
    @Environment(NavigationManager.self) private var navigationManager

    var body: some View {
        Button {
            navigationManager.selectedTab = tab
        } label: {
            Label(tab.rawValue, systemImage: tab.systemImage)
        }
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.2) : nil)
        .foregroundStyle(isSelected ? .primary : .secondary)
        #if os(macOS)
            .buttonStyle(.plain)
        #endif
    }

    private var isSelected: Bool {
        navigationManager.selectedTab == tab
    }
}

// MARK: - Detail Column

/// Detail column showing content for selected section
struct DetailColumn: View {
    @Environment(NavigationManager.self) private var navigationManager

    var body: some View {
        @Bindable var nav = navigationManager

        switch navigationManager.selectedTab {
        case .notes:
            NavigationStack(path: $nav.notesNavigationPath) {
                NoteListView()
                    .navigationDestination(for: AppDestination.self) { destination in
                        switch destination {
                        case .noteDetail(let id):
                            NoteDetailView(noteId: id)
                        case .webPage(let page):
                            WebPageView(page: page)
                        }
                    }
            }
        case .settings:
            NavigationStack(path: $nav.settingsNavigationPath) {
                SettingsView()
                    .navigationDestination(for: AppDestination.self) { destination in
                        switch destination {
                        case .noteDetail(let id):
                            NoteDetailView(noteId: id)
                        case .webPage(let page):
                            WebPageView(page: page)
                        }
                    }
            }
        }
    }
}

#Preview {
    SidebarNavigationView()
        .environment(NavigationManager())
}
