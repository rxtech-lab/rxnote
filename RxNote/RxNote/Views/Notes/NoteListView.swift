//
//  NoteListView.swift
//  RxNote
//
//  Note list view with add button and pull-to-refresh
//

import RxNoteCore
import SwiftUI

/// List view showing all user notes with add/delete functionality
struct NoteListView: View {
    @Environment(NavigationManager.self) private var navigationManager
    @State private var viewModel = NoteListViewModel()
    @State private var showNoteEditor = false
    @State private var showingErrorAlert = false
    @State private var pendingNavigationNoteId: Int?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.notes.isEmpty {
                ProgressView("Loading notes...")
            } else if viewModel.notes.isEmpty {
                ContentUnavailableView(
                    "No Notes",
                    systemImage: "note.text",
                    description: Text("Tap + to create your first note")
                )
            } else {
                notesList
            }
        }
        .navigationTitle("Notes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNoteEditor = true
                } label: {
                    Label("Add Note", systemImage: "plus")
                }
                .accessibilityIdentifier("add-note-button")
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showNoteEditor, onDismiss: {
            if let noteId = pendingNavigationNoteId {
                pendingNavigationNoteId = nil
                navigationManager.navigateToNote(id: noteId)
            }
        }) {
            NoteEditorView(mode: .create) { note in
                Task { await viewModel.fetchNotes() }
                pendingNavigationNoteId = note.id
            }
        }
        #else
        .sheet(isPresented: $showNoteEditor, onDismiss: {
            if let noteId = pendingNavigationNoteId {
                pendingNavigationNoteId = nil
                navigationManager.navigateToNote(id: noteId)
            }
        }) {
            NoteEditorView(mode: .create) { note in
                Task { await viewModel.fetchNotes() }
                pendingNavigationNoteId = note.id
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
            await viewModel.fetchNotes()
        }
        .refreshable {
            await viewModel.fetchNotes()
        }
    }

    private var notesList: some View {
        List {
            ForEach(viewModel.notes, id: \.id) { note in
                NavigationLink(value: AppDestination.noteDetail(id: note.id)) {
                    NoteRow(note: note)
                }
                .accessibilityIdentifier("note-row-\(note.id)")
                    .onAppear {
                        // Load more when reaching near the end
                        if note.id == viewModel.notes.last?.id, viewModel.hasNextPage {
                            Task {
                                await viewModel.loadMore()
                            }
                        }
                    }
            }
            .onDelete { indexSet in
                Task {
                    for index in indexSet {
                        let note = viewModel.notes[index]
                        await viewModel.deleteNote(id: note.id)
                    }
                }
            }

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.automatic)
    }
}

// MARK: - Note Row

/// Single row in the note list
private struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title)
                .font(.headline)
                .lineLimit(1)

            if let content = note.note {
                Text(content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Label(note.visibility.rawValue, systemImage: visibilityIcon)
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var visibilityIcon: String {
        switch note.visibility {
        case ._public: return "globe"
        case ._private: return "lock"
        case .auth_hyphen_only: return "person.badge.key"
        }
    }
}


#Preview {
    NavigationStack {
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
    .environment(NavigationManager())
}
