import Foundation
@testable import RxNoteCore
import Testing

@Suite("NoteEditorViewModel Business Card Tests")
struct NoteEditorViewModelBusinessCardTests {
    @Test("Default note type is regular text")
    @MainActor
    func defaultNoteTypeIsRegularText() {
        let viewModel = NoteEditorViewModel(mode: .create, service: MockNoteService())
        #expect(viewModel.noteType == .regularTextNote)
    }

    @Test("Switch note type to business card")
    @MainActor
    func switchNoteTypeToBusinessCard() {
        let viewModel = NoteEditorViewModel(mode: .create, service: MockNoteService())
        viewModel.noteType = .businessCard
        #expect(viewModel.noteType == .businessCard)
    }

    @Test("Business card fields are empty on init")
    @MainActor
    func businessCardFieldsInitiallyEmpty() {
        let viewModel = NoteEditorViewModel(mode: .create, service: MockNoteService())
        #expect(viewModel.businessCardFirstName.isEmpty)
        #expect(viewModel.businessCardLastName.isEmpty)
        #expect(viewModel.businessCardEmails.isEmpty)
        #expect(viewModel.businessCardPhones.isEmpty)
        #expect(viewModel.businessCardSocialProfiles.isEmpty)
        #expect(viewModel.businessCardInstantMessaging.isEmpty)
        #expect(viewModel.businessCardWallets.isEmpty)
    }

    @Test("Business card canSave requires only first and last name")
    @MainActor
    func canSaveBusinessCardRequiresNames() {
        let viewModel = NoteEditorViewModel(mode: .create, service: MockNoteService())
        viewModel.noteType = .businessCard

        #expect(viewModel.canSave == false)

        viewModel.businessCardFirstName = "John"
        #expect(viewModel.canSave == false)

        viewModel.businessCardLastName = "Doe"
        #expect(viewModel.canSave == true)
    }

    @Test("Business card canSave does not require title")
    @MainActor
    func canSaveBusinessCardDoesNotRequireTitle() {
        let viewModel = NoteEditorViewModel(mode: .create, service: MockNoteService())
        viewModel.noteType = .businessCard
        viewModel.businessCardFirstName = "John"
        viewModel.businessCardLastName = "Doe"

        // canSave should be true even without setting title
        #expect(viewModel.title.isEmpty)
        #expect(viewModel.canSave == true)
    }

    @Test("Save business card auto-generates title from name")
    @MainActor
    func saveBusinessCardAutoGeneratesTitle() async {
        let mock = MockNoteService()
        let businessType = Note._typePayload(rawValue: "business-card")!
        await mock.setCreatedNote(NoteTestFactories.makeNote(type: businessType))

        let viewModel = NoteEditorViewModel(mode: .create, service: mock)
        viewModel.noteType = .businessCard
        viewModel.businessCardFirstName = "John"
        viewModel.businessCardLastName = "Doe"
        viewModel.businessCardEmails = [TypedValueEntry(type: "Work", value: "john@example.com")]

        _ = await viewModel.save()
        let input = await mock.getCapturedCreateInput()

        #expect(input != nil)
        #expect(input?.title == "John Doe")
        #expect(input?.note == nil)
        #expect(input?._type?.rawValue == "business-card")
        #expect(input?.businessCard?.value1.firstName == "John")
        #expect(input?.businessCard?.value1.lastName == "Doe")
        #expect(input?.businessCard?.value1.emails?.first?._type == "Work")
        #expect(input?.businessCard?.value1.emails?.first?.value == "john@example.com")
    }

    @Test("Load existing business card note populates fields")
    @MainActor
    func loadExistingBusinessCardNote() {
        let businessType = NoteDetail._typePayload(rawValue: "business-card")!
        let card = NoteTestFactories.makeBusinessCard(
            firstName: "Alice",
            lastName: "Ng",
            emails: [TypedValue(_type: "Personal", value: "alice@example.com")]
        )
        let detail = NoteTestFactories.makeNoteDetail(type: businessType, businessCard: card)

        let viewModel = NoteEditorViewModel(
            mode: .edit(noteId: detail.id, existing: detail),
            service: MockNoteService()
        )

        #expect(viewModel.noteType == .businessCard)
        #expect(viewModel.businessCardFirstName == "Alice")
        #expect(viewModel.businessCardLastName == "Ng")
        #expect(viewModel.businessCardEmails.count == 1)
        #expect(viewModel.businessCardEmails.first?.type == "Personal")
        #expect(viewModel.businessCardEmails.first?.value == "alice@example.com")
    }

    @Test("Load existing business card with image populates image fields")
    @MainActor
    func loadExistingBusinessCardWithImage() {
        let businessType = NoteDetail._typePayload(rawValue: "business-card")!
        let card = NoteTestFactories.makeBusinessCard(
            firstName: "Bob",
            lastName: "Smith",
            imageUrl: "https://example.com/signed-url",
            imageFileId: 42
        )
        let detail = NoteTestFactories.makeNoteDetail(type: businessType, businessCard: card)

        let viewModel = NoteEditorViewModel(
            mode: .edit(noteId: detail.id, existing: detail),
            service: MockNoteService()
        )

        #expect(viewModel.businessCardImageUrl == "https://example.com/signed-url")
        #expect(viewModel.businessCardImageFileId == 42)
    }

    @Test("Load existing business card with social profiles and IM")
    @MainActor
    func loadExistingBusinessCardWithSocialAndIM() {
        let businessType = NoteDetail._typePayload(rawValue: "business-card")!
        let card = NoteTestFactories.makeBusinessCard(
            firstName: "Carol",
            lastName: "Lee",
            socialProfiles: [NameValue(name: "Twitter", value: "@carol")],
            instantMessaging: [NameValue(name: "WeChat", value: "carol_wx")]
        )
        let detail = NoteTestFactories.makeNoteDetail(type: businessType, businessCard: card)

        let viewModel = NoteEditorViewModel(
            mode: .edit(noteId: detail.id, existing: detail),
            service: MockNoteService()
        )

        #expect(viewModel.businessCardSocialProfiles.count == 1)
        #expect(viewModel.businessCardSocialProfiles.first?.name == "Twitter")
        #expect(viewModel.businessCardSocialProfiles.first?.value == "@carol")
        #expect(viewModel.businessCardInstantMessaging.count == 1)
        #expect(viewModel.businessCardInstantMessaging.first?.name == "WeChat")
        #expect(viewModel.businessCardInstantMessaging.first?.value == "carol_wx")
    }

    @Test("Load existing business card with structured address")
    @MainActor
    func loadExistingBusinessCardWithAddress() {
        let businessType = NoteDetail._typePayload(rawValue: "business-card")!
        let card = NoteTestFactories.makeBusinessCard(
            firstName: "Dan",
            lastName: "Kim",
            address: BusinessCardAddress(street: "100 Broadway", city: "New York", state: "NY", zip: "10005", country: "US")
        )
        let detail = NoteTestFactories.makeNoteDetail(type: businessType, businessCard: card)

        let viewModel = NoteEditorViewModel(
            mode: .edit(noteId: detail.id, existing: detail),
            service: MockNoteService()
        )

        #expect(viewModel.businessCardAddress.street == "100 Broadway")
        #expect(viewModel.businessCardAddress.city == "New York")
        #expect(viewModel.businessCardAddress.state == "NY")
        #expect(viewModel.businessCardAddress.zip == "10005")
        #expect(viewModel.businessCardAddress.country == "US")
    }

    @Test("Remove business card image sets removed flag")
    @MainActor
    func removeBusinessCardImage() {
        let viewModel = NoteEditorViewModel(mode: .create, service: MockNoteService())
        viewModel.noteType = .businessCard
        viewModel.businessCardImageUrl = "https://example.com/photo.jpg"
        viewModel.businessCardImageFileId = 10

        viewModel.removeBusinessCardImage()

        #expect(viewModel.businessCardImageUrl == nil)
        #expect(viewModel.businessCardImageFileId == nil)
        #expect(viewModel.businessCardImageRemoved == true)
    }

    @Test("Switching from business card to regular clears business card payload")
    @MainActor
    func switchFromBusinessCardToRegularClearsPayload() async {
        let mock = MockNoteService()
        await mock.setCreatedNote(NoteTestFactories.makeNote())

        let viewModel = NoteEditorViewModel(mode: .create, service: mock)
        viewModel.title = "Switch Type"
        viewModel.noteType = .businessCard
        viewModel.businessCardFirstName = "Bob"
        viewModel.businessCardLastName = "Jones"
        viewModel.noteType = .regularTextNote

        _ = await viewModel.save()
        let input = await mock.getCapturedCreateInput()

        #expect(input != nil)
        #expect(input?._type?.rawValue == "regular-text-note")
        #expect(input?.businessCard == nil)
    }

    @Test("Switching from business card clears all fields")
    @MainActor
    func switchFromBusinessCardClearsAllFields() {
        let viewModel = NoteEditorViewModel(mode: .create, service: MockNoteService())
        viewModel.noteType = .businessCard
        viewModel.businessCardImageUrl = "https://example.com/photo.jpg"
        viewModel.businessCardImageFileId = 10
        viewModel.businessCardSocialProfiles = [NameValueEntry(name: "Twitter", value: "@test")]
        viewModel.businessCardInstantMessaging = [NameValueEntry(name: "WeChat", value: "test")]

        viewModel.noteType = .regularTextNote

        #expect(viewModel.businessCardImageUrl == nil)
        #expect(viewModel.businessCardImageFileId == nil)
        #expect(viewModel.businessCardSocialProfiles.isEmpty)
        #expect(viewModel.businessCardInstantMessaging.isEmpty)
        #expect(viewModel.businessCardWallets.isEmpty)
        #expect(viewModel.businessCardEmails.isEmpty)
        #expect(viewModel.businessCardPhones.isEmpty)
    }

    @Test("Load existing business card with wallets")
    @MainActor
    func loadExistingBusinessCardWithWallets() {
        let businessType = NoteDetail._typePayload(rawValue: "business-card")!
        let card = NoteTestFactories.makeBusinessCard(
            firstName: "Frank",
            lastName: "Wu",
            wallets: [NameValue(name: "Ethereum", value: "0xabc123def456")]
        )
        let detail = NoteTestFactories.makeNoteDetail(type: businessType, businessCard: card)

        let viewModel = NoteEditorViewModel(
            mode: .edit(noteId: detail.id, existing: detail),
            service: MockNoteService()
        )

        #expect(viewModel.businessCardWallets.count == 1)
        #expect(viewModel.businessCardWallets.first?.name == "Ethereum")
        #expect(viewModel.businessCardWallets.first?.value == "0xabc123def456")
    }

    @Test("Save includes social profiles and IM in payload")
    @MainActor
    func saveIncludesSocialAndIM() async {
        let mock = MockNoteService()
        let businessType = Note._typePayload(rawValue: "business-card")!
        await mock.setCreatedNote(NoteTestFactories.makeNote(type: businessType))

        let viewModel = NoteEditorViewModel(mode: .create, service: mock)
        viewModel.noteType = .businessCard
        viewModel.businessCardFirstName = "Eve"
        viewModel.businessCardLastName = "Wang"
        viewModel.businessCardSocialProfiles = [NameValueEntry(name: "LinkedIn", value: "evewang")]
        viewModel.businessCardInstantMessaging = [NameValueEntry(name: "Telegram", value: "@eve")]

        _ = await viewModel.save()
        let input = await mock.getCapturedCreateInput()

        #expect(input?.businessCard?.value1.socialProfiles?.count == 1)
        #expect(input?.businessCard?.value1.socialProfiles?.first?.name == "LinkedIn")
        #expect(input?.businessCard?.value1.instantMessaging?.count == 1)
        #expect(input?.businessCard?.value1.instantMessaging?.first?.name == "Telegram")
    }

    @Test("Save includes wallets in payload")
    @MainActor
    func saveIncludesWallets() async {
        let mock = MockNoteService()
        let businessType = Note._typePayload(rawValue: "business-card")!
        await mock.setCreatedNote(NoteTestFactories.makeNote(type: businessType))

        let viewModel = NoteEditorViewModel(mode: .create, service: mock)
        viewModel.noteType = .businessCard
        viewModel.businessCardFirstName = "Grace"
        viewModel.businessCardLastName = "Li"
        viewModel.businessCardWallets = [NameValueEntry(name: "Ethereum", value: "0x1234abcd")]

        _ = await viewModel.save()
        let input = await mock.getCapturedCreateInput()

        #expect(input?.businessCard?.value1.wallets?.count == 1)
        #expect(input?.businessCard?.value1.wallets?.first?.name == "Ethereum")
        #expect(input?.businessCard?.value1.wallets?.first?.value == "0x1234abcd")
    }

    @Test("Switching from business card clears wallets")
    @MainActor
    func switchFromBusinessCardClearsWallets() {
        let viewModel = NoteEditorViewModel(mode: .create, service: MockNoteService())
        viewModel.noteType = .businessCard
        viewModel.businessCardWallets = [NameValueEntry(name: "Bitcoin", value: "bc1qtest")]

        viewModel.noteType = .regularTextNote

        #expect(viewModel.businessCardWallets.isEmpty)
    }
}
