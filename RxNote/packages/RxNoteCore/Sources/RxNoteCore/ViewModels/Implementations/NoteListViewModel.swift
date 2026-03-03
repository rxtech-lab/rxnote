//
//  NoteListViewModel.swift
//  RxNoteCore
//
//  View model for note list with pagination and pull-to-refresh
//

import Foundation

/// View model for note list operations
@Observable
@MainActor
public final class NoteListViewModel {
    /// Current list of notes
    public private(set) var notes: [Note] = []

    /// Loading state for initial load
    public private(set) var isLoading: Bool = false

    /// Loading state for pagination
    public private(set) var isLoadingMore: Bool = false

    /// Error state
    public private(set) var error: Error?

    /// Pagination state
    private var pagination: PaginationState?

    /// Whether there are more notes to load
    public var hasNextPage: Bool {
        pagination?.hasNextPage ?? false
    }

    private let service: NoteServiceProtocol

    public init(service: NoteServiceProtocol = NoteService()) {
        self.service = service
    }

    /// Fetch notes (initial load or refresh)
    public func fetchNotes() async {
        isLoading = true
        error = nil
        do {
            let response = try await service.getNotes(filters: nil)
            notes = response.data
            pagination = response.pagination
        } catch {
            self.error = error
        }
        isLoading = false
    }

    /// Load next page of notes
    public func loadMore() async {
        guard let nextCursor = pagination?.nextCursor, !isLoadingMore else { return }

        isLoadingMore = true
        do {
            let filters = NoteFilters(cursor: nextCursor, direction: .next)
            let response = try await service.getNotes(filters: filters)
            notes.append(contentsOf: response.data)
            pagination = response.pagination
        } catch {
            self.error = error
        }
        isLoadingMore = false
    }

    /// Create a new note with the given title
    public func createNote(title: String) async -> Note? {
        error = nil
        do {
            let input = NoteInsert(
                title: title,
                visibility: ._public
            )
            let note = try await service.createNote(input)
            notes.insert(note, at: 0)
            return note
        } catch {
            self.error = error
            return nil
        }
    }

    /// Delete a note
    public func deleteNote(id: String) async {
        error = nil
        do {
            try await service.deleteNote(id: id)
            notes.removeAll { $0.id == id }
        } catch {
            self.error = error
        }
    }

    /// Clear error state
    public func clearError() {
        error = nil
    }
}
