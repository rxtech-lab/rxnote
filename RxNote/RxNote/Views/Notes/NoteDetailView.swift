//
//  NoteDetailView.swift
//  RxNote
//
//  Detail view for a single note, reusing the editor in readonly mode
//

import RxNoteCore
import SwiftUI

/// Displays the full detail of a note using NoteEditorView in view or edit mode
struct NoteDetailView: View {
    let noteId: String

    @State private var viewModel = NoteDetailViewModel()
    @State private var showingErrorAlert = false
    @State private var isEditing = false
    @State private var showingQRSheet = false
    #if os(iOS)
    @State private var nfcWriter = NFCWriter()
    @State private var isWritingNFC = false
    @State private var showNFCLockSheet = false
    @State private var showNFCOverwriteConfirmation = false
    @State private var existingNFCContent = ""
    @State private var pendingNFCUrl = ""
    @State private var nfcError: Error?
    @State private var showingNFCErrorAlert = false
    #endif

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.note == nil {
                ProgressView("Loading note...")
            } else if let note = viewModel.note {
                if isEditing {
                    NoteEditorView(
                        mode: .edit(noteId: noteId, existing: note),
                        onSave: { updatedNote in
                            Task {
                                await viewModel.fetchNote(id: noteId)
                                isEditing = false
                            }
                        },
                        onCancel: {
                            isEditing = false
                        }
                    )
                } else {
                    NoteEditorView(mode: .view(noteId: noteId, existing: note)) { _ in
                        Task { await viewModel.fetchNote(id: noteId) }
                    } onEdit: {
                        isEditing = true
                    }
                }
            } else if viewModel.error != nil {
                ContentUnavailableView(
                    "Failed to Load",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Could not load this note.")
                )
            } else {
                ProgressView()
            }
        }
        #if os(iOS)
        .toolbar(.hidden, for: .tabBar)
        #endif
        .toolbar {
            if !isEditing, let note = viewModel.note {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingQRSheet = true
                        } label: {
                            Label("Show QR Code", systemImage: "qrcode")
                        }

                        #if os(iOS)
                        Button {
                            Task { await writeToNFC(previewUrl: note.previewUrl) }
                        } label: {
                            Label(isWritingNFC ? "Writing..." : "Write to NFC Tag", systemImage: "wave.3.right")
                        }
                        .disabled(isWritingNFC)
                        #endif
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingQRSheet) {
            if let note = viewModel.note {
                NavigationStack {
                    QRCodeView(
                        urlString: note.previewUrl,
                        noteTitle: note.title,
                        noteContent: note.note
                    )
                }
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showNFCLockSheet) {
            NFCLockSheet(nfcWriter: nfcWriter) {
                showNFCLockSheet = false
            }
        }
        .confirmationDialog(
            title: "Tag Already Has Content",
            message: "This NFC tag already contains: \(existingNFCContent). Do you want to overwrite it?",
            confirmButtonTitle: "Overwrite",
            isPresented: $showNFCOverwriteConfirmation,
            onConfirm: {
                Task { await writeToNFCWithOverwrite() }
            }
        )
        .alert("NFC Error", isPresented: $showingNFCErrorAlert) {
            Button("OK") { nfcError = nil }
        } message: {
            if let nfcError {
                Text(nfcError.localizedDescription)
            }
        }
        #endif
        .alert(
            "Error",
            isPresented: $showingErrorAlert,
            presenting: viewModel.error
        ) { _ in
            Button("OK") {
                viewModel.clearError()
            }
        } message: { error in
            Text(error.localizedDescription)
        }
        .onChange(of: viewModel.error != nil) { _, hasError in
            if hasError {
                showingErrorAlert = true
            }
        }
        .task {
            await viewModel.fetchNote(id: noteId)
        }
        .refreshable {
            await viewModel.fetchNote(id: noteId)
        }
    }

    #if os(iOS)
    // MARK: - NFC Writing

    private func writeToNFC(previewUrl: String) async {
        isWritingNFC = true
        pendingNFCUrl = previewUrl
        defer { isWritingNFC = false }
        do {
            try await nfcWriter.writeToNfcChip(url: previewUrl)
            showNFCLockSheet = true
        } catch let NFCWriterError.tagHasExistingContent(content) {
            existingNFCContent = content
            showNFCOverwriteConfirmation = true
        } catch NFCWriterError.cancelled {
            // User cancelled - do nothing
        } catch {
            nfcError = error
            showingNFCErrorAlert = true
        }
    }

    private func writeToNFCWithOverwrite() async {
        isWritingNFC = true
        defer { isWritingNFC = false }
        do {
            try await nfcWriter.writeToNfcChip(url: pendingNFCUrl, allowOverwrite: true)
            showNFCLockSheet = true
        } catch NFCWriterError.cancelled {
            // User cancelled - do nothing
        } catch {
            nfcError = error
            showingNFCErrorAlert = true
        }
    }
    #endif
}

#Preview {
    NavigationStack {
        NoteDetailView(noteId: "1")
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .noteDetail(let id):
                    NoteDetailView(noteId: id)
                case .webPage(let page):
                    WebPageView(page: page)
                }
            }
    }
    .environment(NavigationManager())
}
