//
//  FilterTypes.swift
//  RxNoteCore
//
//  Filter and pagination helper types
//

import Foundation

// MARK: - Note Filters

/// Filters for note queries
public struct NoteFilters: Sendable {
    public var visibility: String?
    public var search: String?
    public var cursor: String?
    public var direction: PaginationDirection?
    public var limit: Int?

    public init(
        visibility: String? = nil,
        search: String? = nil,
        cursor: String? = nil,
        direction: PaginationDirection? = nil,
        limit: Int? = nil
    ) {
        self.visibility = visibility
        self.search = search
        self.cursor = cursor
        self.direction = direction
        self.limit = limit
    }
}

// MARK: - Paginated Response

/// Generic paginated response wrapper
public struct PaginatedResponse<T: Sendable>: Sendable {
    public let data: [T]
    public let pagination: PaginationState

    public init(data: [T], pagination: PaginationState) {
        self.data = data
        self.pagination = pagination
    }
}

/// Pagination state for UI
public struct PaginationState: Sendable {
    public let hasNextPage: Bool
    public let hasPrevPage: Bool
    public let nextCursor: String?
    public let prevCursor: String?

    public init(
        hasNextPage: Bool,
        hasPrevPage: Bool,
        nextCursor: String?,
        prevCursor: String?
    ) {
        self.hasNextPage = hasNextPage
        self.hasPrevPage = hasPrevPage
        self.nextCursor = nextCursor
        self.prevCursor = prevCursor
    }

    /// Create from generated PaginationInfo
    public init(from info: PaginationInfo) {
        hasNextPage = info.hasNextPage
        hasPrevPage = info.hasPrevPage
        nextCursor = info.nextCursor
        prevCursor = info.prevCursor
    }
}
