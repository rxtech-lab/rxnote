//
//  TestHelpers.swift
//  RxNoteCoreTests
//
//  Test helpers for creating model instances
//

import Foundation
@testable import RxNoteCore

/// Helper methods for creating test data
enum TestHelpers {
    /// Default test date (2024-01-01 00:00:00 UTC)
    static let defaultDate: Date = ISO8601DateFormatter().date(from: "2024-01-01T00:00:00Z")!

    /// Default test user ID
    static let defaultUserId = "test-user-id"

    /// Create an ImageReference for testing
    static func makeImageReference(
        id: UUID = UUID(),
        url: String = "https://example.com/signed/image.jpg",
        fileId: Int? = nil
    ) -> ImageReference {
        ImageReference(id: id, url: url, fileId: fileId)
    }

    /// Create a QrCodeScanResponse for testing
    static func makeQrCodeScanResponse(
        type: QrCodeType = .note,
        url: String = "https://example.com/api/v1/notes/1"
    ) -> QrCodeScanResponse {
        QrCodeScanResponse(_type: .init(value1: type), url: url)
    }
}
