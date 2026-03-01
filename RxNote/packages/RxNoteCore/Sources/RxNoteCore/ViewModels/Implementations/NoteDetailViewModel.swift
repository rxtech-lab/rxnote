//
//  NoteDetailViewModel.swift
//  RxNoteCore
//
//  View model for note detail view
//

import Foundation

/// View model for fetching and updating a single note
@Observable
@MainActor
public final class NoteDetailViewModel {
    /// The loaded note detail
    public private(set) var note: NoteDetail?

    /// Loading state
    public private(set) var isLoading = false

    /// Error state
    public private(set) var error: Error?

    private let service: NoteServiceProtocol

    public init(service: NoteServiceProtocol = NoteService()) {
        self.service = service
    }

    /// Fetch note detail by ID
    public func fetchNote(id: Int) async {
        isLoading = true
        error = nil
        do {
            note = try await service.getNote(id: id)
        } catch {
            self.error = error
        }
        isLoading = false
    }

    /// Update a note and return the updated note summary
    public func updateNote(id: Int, input: NoteUpdate) async -> Note? {
        error = nil
        do {
            let updated = try await service.updateNote(id: id, input: input)
            // Refresh the detail after update
            await fetchNote(id: id)
            return updated
        } catch {
            self.error = error
            return nil
        }
    }

    /// Clear error state
    public func clearError() {
        error = nil
    }
}
