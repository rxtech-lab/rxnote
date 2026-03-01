//
//  HelperTypes.swift
//  RxNoteCore
//
//  Helper types for forms and pending operations
//

import Foundation

// MARK: - Image Reference

/// Reference to an image (either saved or from file upload)
public struct ImageReference: Sendable, Identifiable {
    public let id: UUID
    public let url: String
    public let fileId: Int?

    public init(id: UUID = UUID(), url: String, fileId: Int?) {
        self.id = id
        self.url = url
        self.fileId = fileId
    }

    /// Get the file reference for API submission ("file:N" format)
    public var fileReference: String {
        if let fileId = fileId {
            return "file:\(fileId)"
        }
        return url
    }
}
