import Foundation
@testable import RxNoteCore
import Testing

@Suite("AddContact Action Tests")
struct AddContactActionTests {
    @Test("AddContact action creation with all fields")
    func addContactActionCreation() {
        let action = AddContactAction(
            _type: .add_hyphen_contact,
            firstName: "Jane",
            lastName: "Smith",
            emails: [.init(_type: "Work", value: "jane@example.com")],
            phones: [.init(_type: "Mobile", value: "+1234567890")],
            company: "Tech Corp",
            jobTitle: "PM",
            website: "https://example.com",
            address: .init(value1: .init(street: "123 Main St", city: "Springfield"))
        )

        #expect(action._type == .add_hyphen_contact)
        #expect(action.firstName == "Jane")
        #expect(action.lastName == "Smith")
        #expect(action.emails?.first?._type == "Work")
        #expect(action.emails?.first?.value == "jane@example.com")
        #expect(action.phones?.first?._type == "Mobile")
        #expect(action.phones?.first?.value == "+1234567890")
    }

    @Test("AddContact action supports required fields only")
    func addContactActionMinimalFields() {
        let action = AddContactAction(
            _type: .add_hyphen_contact,
            firstName: "Jane",
            lastName: "Smith"
        )

        #expect(action.firstName == "Jane")
        #expect(action.lastName == "Smith")
        #expect(action.emails == nil)
        #expect(action.phones == nil)
    }

    @Test("NoteAction discriminated union includes add-contact case")
    func noteActionDiscriminatedUnion() {
        let union = NoteAction.add_hyphen_contact(.init(
            _type: .add_hyphen_contact,
            firstName: "Bob",
            lastName: "Jones"
        ))

        switch union {
        case let .add_hyphen_contact(action):
            #expect(action.firstName == "Bob")
            #expect(action.lastName == "Jones")
        default:
            Issue.record("Expected add-contact action case")
        }
    }

    @Test("Mixed action arrays encode/decode all action types")
    func mixedActionsRoundTrip() throws {
        let actions: [NoteAction] = [
            .url(.init(
                _type: .url,
                label: "Website",
                url: "https://example.com"
            )),
            .wifi(.init(
                _type: .wifi,
                ssid: "Office",
                password: "pass123",
                encryption: .WPA
            )),
            .add_hyphen_contact(.init(
                _type: .add_hyphen_contact,
                firstName: "Jane",
                lastName: "Smith",
                emails: [.init(_type: "Work", value: "jane@example.com")]
            )),
        ]

        let data = try JSONEncoder().encode(actions)
        let decoded = try JSONDecoder().decode([NoteAction].self, from: data)

        #expect(decoded.count == 3)
        #expect({
            if case .url = decoded[0] { return true }
            return false
        }())
        #expect({
            if case .wifi = decoded[1] { return true }
            return false
        }())
        #expect({
            if case .add_hyphen_contact = decoded[2] { return true }
            return false
        }())
    }
}
