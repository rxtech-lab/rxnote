import Foundation
@testable import RxNoteCore
import Testing

@Suite("BusinessCard Model Tests")
struct BusinessCardModelTests {
    @Test("BusinessCard supports all fields")
    func businessCardFullFields() {
        let card = NoteTestFactories.makeBusinessCard()

        #expect(card.firstName == "John")
        #expect(card.lastName == "Doe")
        #expect(card.emails?.first?._type == "Work")
        #expect(card.emails?.first?.value == "john@example.com")
        #expect(card.phones?.first?._type == "Mobile")
        #expect(card.phones?.first?.value == "+1234567890")
        #expect(card.company == "Acme Inc")
        #expect(card.jobTitle == "Engineer")
        #expect(card.website == "https://example.com")
        #expect(card.address?.value1.street == "123 Main St")
        #expect(card.address?.value1.city == "Springfield")
    }

    @Test("BusinessCard allows required fields only")
    func businessCardRequiredFieldsOnly() {
        let card = BusinessCard(firstName: "Jane", lastName: "Smith")

        #expect(card.firstName == "Jane")
        #expect(card.lastName == "Smith")
        #expect(card.emails == nil)
        #expect(card.phones == nil)
    }

    @Test("BusinessCard supports imageUrl field")
    func businessCardImageUrl() {
        let card = NoteTestFactories.makeBusinessCard(imageUrl: "file:42")
        #expect(card.imageUrl == "file:42")
    }

    @Test("BusinessCard supports imageFileId field")
    func businessCardImageFileId() {
        let card = NoteTestFactories.makeBusinessCard(imageFileId: 42)
        #expect(card.imageFileId == 42)
    }

    @Test("BusinessCard supports social profiles")
    func businessCardSocialProfiles() {
        let card = NoteTestFactories.makeBusinessCard(
            socialProfiles: [NameValue(name: "Twitter", value: "@johndoe")]
        )
        #expect(card.socialProfiles?.first?.name == "Twitter")
        #expect(card.socialProfiles?.first?.value == "@johndoe")
    }

    @Test("BusinessCard supports instant messaging")
    func businessCardInstantMessaging() {
        let card = NoteTestFactories.makeBusinessCard(
            instantMessaging: [NameValue(name: "WeChat", value: "wxid_123")]
        )
        #expect(card.instantMessaging?.first?.name == "WeChat")
        #expect(card.instantMessaging?.first?.value == "wxid_123")
    }

    @Test("BusinessCard supports structured address")
    func businessCardStructuredAddress() {
        let card = NoteTestFactories.makeBusinessCard(
            address: BusinessCardAddress(street: "456 Oak Ave", city: "Portland", state: "OR", zip: "97201", country: "US")
        )
        #expect(card.address?.value1.street == "456 Oak Ave")
        #expect(card.address?.value1.city == "Portland")
        #expect(card.address?.value1.state == "OR")
        #expect(card.address?.value1.zip == "97201")
        #expect(card.address?.value1.country == "US")
    }

    @Test("BusinessCard supports wallets")
    func businessCardWallets() {
        let card = NoteTestFactories.makeBusinessCard(
            wallets: [NameValue(name: "Ethereum", value: "0x1234567890abcdef")]
        )
        #expect(card.wallets?.first?.name == "Ethereum")
        #expect(card.wallets?.first?.value == "0x1234567890abcdef")
    }

    @Test("BusinessCard JSON encode/decode round trip")
    func businessCardJsonRoundTrip() throws {
        let card = NoteTestFactories.makeBusinessCard(
            imageUrl: "file:10",
            imageFileId: 10,
            socialProfiles: [NameValue(name: "GitHub", value: "johndoe")],
            instantMessaging: [NameValue(name: "Telegram", value: "@jd")],
            wallets: [NameValue(name: "Ethereum", value: "0xabc123")]
        )
        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(BusinessCard.self, from: data)

        #expect(decoded.firstName == card.firstName)
        #expect(decoded.lastName == card.lastName)
        #expect(decoded.emails?.count == card.emails?.count)
        #expect(decoded.phones?.count == card.phones?.count)
        #expect(decoded.company == card.company)
        #expect(decoded.jobTitle == card.jobTitle)
        #expect(decoded.website == card.website)
        #expect(decoded.address?.value1.street == card.address?.value1.street)
        #expect(decoded.imageUrl == card.imageUrl)
        #expect(decoded.imageFileId == card.imageFileId)
        #expect(decoded.socialProfiles?.count == card.socialProfiles?.count)
        #expect(decoded.instantMessaging?.count == card.instantMessaging?.count)
        #expect(decoded.wallets?.count == card.wallets?.count)
        #expect(decoded.wallets?.first?.name == "Ethereum")
    }
}
