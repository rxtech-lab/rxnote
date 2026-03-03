//
//  NoteService.swift
//  RxNoteCore
//
//  Note service for CRUD operations using generated OpenAPI client
//

import Foundation
import Logging
import OpenAPIRuntime

private let logger = Logger(label: "NoteService")

// MARK: - Protocol

/// Protocol for note service operations
public protocol NoteServiceProtocol: Sendable {
    /// Fetch paginated notes
    func getNotes(filters: NoteFilters?) async throws -> PaginatedResponse<Note>

    /// Create a new note
    func createNote(_ input: NoteInsert) async throws -> Note

    /// Get a note by ID
    func getNote(id: String) async throws -> NoteDetail

    /// Update a note by ID
    func updateNote(id: String, input: NoteUpdate) async throws -> Note

    /// Delete a note by ID
    func deleteNote(id: String) async throws
}

// MARK: - Implementation

/// Note service implementation using generated OpenAPI client
public struct NoteService: NoteServiceProtocol {
    public init() {}

    @APICall(.ok, transform: "transformPaginated")
    public func getNotes(filters: NoteFilters?) async throws -> PaginatedResponse<Note> {
        let query = Operations.getNotes.Input.Query(
            cursor: filters?.cursor,
            direction: filters?.direction.flatMap {
                Operations.getNotes.Input.Query.directionPayload(rawValue: $0.rawValue)
            },
            limit: filters?.limit,
            search: filters?.search,
            visibility: filters?.visibility.flatMap {
                Operations.getNotes.Input.Query.visibilityPayload(rawValue: $0)
            }
        )
        try await StorageAPIClient.shared.client.getNotes(.init(query: query))
    }

    private func transformPaginated(_ body: PaginatedNotesResponse) -> PaginatedResponse<Note> {
        let pagination = PaginationState(from: body.pagination)
        return PaginatedResponse(data: body.data, pagination: pagination)
    }

    @APICall(.created)
    public func createNote(_ input: NoteInsert) async throws -> Note {
        try await StorageAPIClient.shared.client.createNote(.init(body: .json(input)))
    }

    @APICall(.ok)
    public func getNote(id: String) async throws -> NoteDetail {
        try await StorageAPIClient.shared.client.getNote(.init(path: .init(id: id)))
    }

    @APICall(.ok)
    public func updateNote(id: String, input: NoteUpdate) async throws -> Note {
        try await StorageAPIClient.shared.client.updateNote(.init(path: .init(id: id), body: .json(input)))
    }

    public func deleteNote(id: String) async throws {
        let response = try await StorageAPIClient.shared.client.deleteNote(
            .init(path: .init(id: id))
        )

        switch response {
        case .noContent:
            return
        case let .badRequest(badRequest):
            let error = try? badRequest.body.json
            throw APIError.badRequest(error?.error ?? "Invalid request")
        case .unauthorized:
            throw APIError.unauthorized
        case .forbidden:
            throw APIError.forbidden
        case .notFound:
            throw APIError.notFound
        case .internalServerError:
            throw APIError.serverError("Internal server error")
        case let .undocumented(statusCode, _):
            throw APIError.serverError("HTTP \(statusCode)")
        }
    }
}
