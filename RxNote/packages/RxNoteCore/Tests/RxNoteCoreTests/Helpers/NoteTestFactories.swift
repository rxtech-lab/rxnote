import Foundation
@testable import RxNoteCore

enum NoteTestFactories {
    static func makeBusinessCard(
        firstName: String = "John",
        lastName: String = "Doe",
        emails: [TypedValue]? = [TypedValue(_type: "Work", value: "john@example.com")],
        phones: [TypedValue]? = [TypedValue(_type: "Mobile", value: "+1234567890")],
        company: String? = "Acme Inc",
        jobTitle: String? = "Engineer",
        website: String? = "https://example.com",
        address: BusinessCardAddress? = BusinessCardAddress(street: "123 Main St", city: "Springfield"),
        imageUrl: String? = nil,
        imageFileId: Int? = nil,
        socialProfiles: [NameValue]? = nil,
        instantMessaging: [NameValue]? = nil,
        wallets: [NameValue]? = nil
    ) -> BusinessCard {
        BusinessCard(
            firstName: firstName,
            lastName: lastName,
            emails: emails,
            phones: phones,
            company: company,
            jobTitle: jobTitle,
            website: website,
            address: address.map { .init(value1: $0) },
            imageUrl: imageUrl,
            imageFileId: imageFileId,
            socialProfiles: socialProfiles,
            instantMessaging: instantMessaging,
            wallets: wallets
        )
    }

    static func makeNote(
        id: Int = 1,
        type: Note._typePayload = .regular_hyphen_text_hyphen_note,
        title: String = "Test Note",
        note: String? = "Sample note",
        businessCard: BusinessCard? = nil,
        actions: [NoteAction] = []
    ) -> Note {
        Note(
            id: id,
            userId: TestHelpers.defaultUserId,
            _type: type,
            title: title,
            note: note,
            businessCard: businessCard.map { .init(value1: $0) },
            images: [],
            audios: [],
            videos: [],
            latitude: nil,
            longitude: nil,
            actions: actions,
            visibility: ._private,
            previewUrl: "https://example.com/preview/\(id)",
            createdAt: TestHelpers.defaultDate,
            updatedAt: TestHelpers.defaultDate
        )
    }

    static func makeNoteDetail(
        id: Int = 1,
        type: NoteDetail._typePayload = .regular_hyphen_text_hyphen_note,
        title: String = "Test Note",
        note: String? = "Sample note",
        businessCard: BusinessCard? = nil,
        actions: [NoteAction] = []
    ) -> NoteDetail {
        NoteDetail(
            id: id,
            userId: TestHelpers.defaultUserId,
            _type: type,
            title: title,
            note: note,
            businessCard: businessCard.map { .init(value1: $0) },
            images: [],
            audios: [],
            videos: [],
            latitude: nil,
            longitude: nil,
            actions: actions,
            visibility: ._private,
            previewUrl: "https://example.com/preview/\(id)",
            createdAt: TestHelpers.defaultDate,
            updatedAt: TestHelpers.defaultDate,
            whitelist: []
        )
    }
}
