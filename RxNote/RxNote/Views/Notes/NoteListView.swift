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
        #if os(iOS)
        .fullScreenCover(isPresented: $showNoteEditor, onDismiss: {
            if let noteId = pendingNavigationNoteId {
                pendingNavigationNoteId = nil
                navigationManager.navigateToNote(id: noteId)
            }
        }) {
            NavigationStack {
                NoteEditorView(mode: .create) { note in
                    Task { await viewModel.fetchNotes() }
                    pendingNavigationNoteId = note.id
                }
            }
        }
        #else
        .sheet(isPresented: $showNoteEditor, onDismiss: {
                if let noteId = pendingNavigationNoteId {
                    pendingNavigationNoteId = nil
                    navigationManager.navigateToNote(id: noteId)
                }
            }) {
                NavigationStack {
                    NoteEditorView(mode: .create) { note in
                        Task { await viewModel.fetchNotes() }
                        pendingNavigationNoteId = note.id
                    }
                }
            }
        #endif
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
        VStack(alignment: .leading) {
            HStack {
                Text(note.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()
                Label(noteTypeDisplayName, systemImage: noteTypeIcon)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
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
            .padding(.vertical, 2)
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

    private var noteTypeDisplayName: String {
        switch note._type {
        case .regular_hyphen_text_hyphen_note: return "Text"
        case .business_hyphen_card: return "Business Card"
        }
    }

    private var noteTypeIcon: String {
        switch note._type {
        case .regular_hyphen_text_hyphen_note: return "doc.text"
        case .business_hyphen_card: return "person.text.rectangle"
        }
    }
}

#Preview("Text Note Row") {
    List {
        NoteRow(note: Note(
            id: 1,
            userId: "user-1",
            _type: .regular_hyphen_text_hyphen_note,
            title: "Meeting Notes",
            note: "Discussed project timeline and deliverables for Q2.",
            images: [],
            audios: [],
            videos: [],
            actions: [],
            visibility: ._public,
            previewUrl: "https://example.com/preview/1",
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
}

#Preview("Business Card Row") {
    List {
        NoteRow(note: Note(
            id: 2,
            userId: "user-1",
            _type: .business_hyphen_card,
            title: "Jane Smith",
            images: [],
            audios: [],
            videos: [],
            actions: [],
            visibility: ._private,
            previewUrl: "https://example.com/preview/2",
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
}
