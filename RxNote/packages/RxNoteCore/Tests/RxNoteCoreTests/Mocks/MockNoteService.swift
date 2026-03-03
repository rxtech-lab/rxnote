import Foundation
@testable import RxNoteCore

final actor MockNoteService: NoteServiceProtocol {
    var notesResponse: PaginatedResponse<Note> = .init(
        data: [],
        pagination: .init(hasNextPage: false, hasPrevPage: false, nextCursor: nil, prevCursor: nil)
    )
    var createdNote: Note?
    var noteDetail: NoteDetail?
    var updatedNote: Note?

    private(set) var capturedCreateInput: NoteInsert?
    private(set) var capturedUpdateInput: NoteUpdate?

    func setCreatedNote(_ note: Note?) {
        createdNote = note
    }

    func getCapturedCreateInput() -> NoteInsert? {
        capturedCreateInput
    }

    func setUpdatedNote(_ note: Note?) {
        updatedNote = note
    }

    func getNotes(filters _: NoteFilters?) async throws -> PaginatedResponse<Note> {
        notesResponse
    }

    func createNote(_ input: NoteInsert) async throws -> Note {
        capturedCreateInput = input
        if let createdNote {
            return createdNote
        }
        throw APIError.notFound
    }

    func getNote(id _: Int) async throws -> NoteDetail {
        if let noteDetail {
            return noteDetail
        }
        throw APIError.notFound
    }

    func updateNote(id _: Int, input: NoteUpdate) async throws -> Note {
        capturedUpdateInput = input
        if let updatedNote {
            return updatedNote
        }
        throw APIError.notFound
    }

    func deleteNote(id _: Int) async throws {}
}
