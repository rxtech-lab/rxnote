//
//  ActionEditorView.swift
//  RxNote
//
//  Editor for creating/editing note actions (URL, WiFi, or Add Contact)
//

import Contacts
import CoreLocation
#if os(iOS)
import NetworkExtension
#endif
import RxNoteCore
import SwiftUI

struct ActionEditorView: View {
    enum Mode {
        case create
        case edit(index: Int, action: NoteAction)
    }

    let mode: Mode
    let onSave: (NoteAction) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var actionType: ActionType = .url
    @State private var urlLabel = ""
    @State private var urlString = ""
    @State private var wifiSSID = ""
    @State private var wifiPassword = ""
    @State private var wifiEncryption: WifiEncryption = .wpa
    @State private var contactFirstName = ""
    @State private var contactLastName = ""
    @State private var contactEmails: [TypedValueEntry] = []
    @State private var contactPhones: [TypedValueEntry] = []
    @State private var contactCompany = ""
    @State private var contactJobTitle = ""
    @State private var contactWebsite = ""
    @State private var contactAddress = ContactAddressEntry()
    @State private var isFetchingWiFi = false
    @State private var locationManager: CLLocationManager?
    @State private var showContactPicker = false

    enum ActionType: String, CaseIterable {
        case url = "URL"
        case wifi = "WiFi"
        case addContact = "Add Contact"
    }

    enum WifiEncryption: String, CaseIterable {
        case wpa = "WPA"
        case wep = "WEP"
        case none = "none"
    }

    init(mode: Mode = .create, initialType: ActionType = .url, onSave: @escaping (NoteAction) -> Void) {
        self.mode = mode
        self._actionType = State(initialValue: initialType)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $actionType) {
                        ForEach(ActionType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                                .accessibilityIdentifier(
                                    type == .addContact
                                        ? "action-type-add-contact"
                                        : "action-type-\(type.rawValue.lowercased().replacingOccurrences(of: " ", with: "-"))"
                                )
                        }
                    }
                    .pickerStyle(.menu)
                }

                switch actionType {
                case .url:
                    urlForm
                case .wifi:
                    wifiForm
                case .addContact:
                    addContactForm
                }
            }
            .navigationTitle(isEditing ? "Edit Action" : "New Action")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAction() }
                        .disabled(!canSave)
                }
            }
            .onAppear { prefillIfEditing() }
        }
    }

    // MARK: - URL Form

    private var urlForm: some View {
        Section("URL Action") {
            TextField("Label", text: $urlLabel)
            TextField("URL", text: $urlString)
                #if os(iOS)
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                #endif
        }
    }

    // MARK: - WiFi Form

    private var wifiForm: some View {
        Section("WiFi Action") {
            HStack {
                TextField("SSID (Network Name)", text: $wifiSSID)
                Button {
                    fetchCurrentWiFi()
                } label: {
                    if isFetchingWiFi {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "wifi")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isFetchingWiFi)
            }
            SecureField("Password", text: $wifiPassword)
            Picker("Encryption", selection: $wifiEncryption) {
                ForEach(WifiEncryption.allCases, id: \.self) { enc in
                    Text(enc.rawValue).tag(enc)
                }
            }
        }
    }

    // MARK: - Add Contact Form

    private var addContactForm: some View {
        Group {
            // Import from Contacts button
            #if os(iOS)
            Section {
                Button {
                    showContactPicker = true
                } label: {
                    HStack {
                        Image(systemName: "person.crop.circle")
                        Text("Import from Contacts")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .accessibilityIdentifier("contact-import-button")
            }
            #endif

            // Name section
            Section {
                HStack {
                    TextField("First Name", text: $contactFirstName)
                        .accessibilityIdentifier("contact-first-name")
                    Divider()
                        .frame(height: 20)
                    TextField("Last Name", text: $contactLastName)
                        .accessibilityIdentifier("contact-last-name")
                }

                TextField("Company", text: $contactCompany)
                    .accessibilityIdentifier("contact-company")

                TextField("Job Title", text: $contactJobTitle)
                    .accessibilityIdentifier("contact-job-title")
            }

            // Emails section
            Section {
                ForEach($contactEmails) { $entry in
                    HStack(spacing: 8) {
                        TextField("Type", text: $entry.type)
                            .frame(width: 80)
                            .foregroundStyle(Color.accentColor)
                            .accessibilityIdentifier("contact-email-type")

                        Divider()
                            .frame(height: 20)

                        TextField("Email", text: $entry.value)
#if os(iOS)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
#endif
                            .accessibilityIdentifier("contact-email-value")

                        Button {
                            contactEmails.removeAll { $0.id == entry.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    contactEmails.append(TypedValueEntry(type: "Work"))
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                        Text("Add Email")
                    }
                }
                .accessibilityIdentifier("contact-email-add")
            }

            // Phones section
            Section {
                ForEach($contactPhones) { $entry in
                    HStack(spacing: 8) {
                        TextField("Type", text: $entry.type)
                            .frame(width: 80)
                            .foregroundStyle(Color.accentColor)
                            .accessibilityIdentifier("contact-phone-type")

                        Divider()
                            .frame(height: 20)

                        TextField("Phone", text: $entry.value)
#if os(iOS)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
#endif
                            .accessibilityIdentifier("contact-phone-value")

                        Button {
                            contactPhones.removeAll { $0.id == entry.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    contactPhones.append(TypedValueEntry(type: "Mobile"))
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                        Text("Add Phone")
                    }
                }
                .accessibilityIdentifier("contact-phone-add")
            }

            // Website
            Section {
                TextField("Website", text: $contactWebsite)
#if os(iOS)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
#endif
                    .accessibilityIdentifier("contact-website")
            }

            // Address section
            Section("Address") {
                TextField("Street", text: $contactAddress.street)
#if os(iOS)
                    .textContentType(.streetAddressLine1)
#endif
                    .accessibilityIdentifier("contact-address-street")

                TextField("City", text: $contactAddress.city)
#if os(iOS)
                    .textContentType(.addressCity)
#endif
                    .accessibilityIdentifier("contact-address-city")

                TextField("State / Province", text: $contactAddress.state)
#if os(iOS)
                    .textContentType(.addressState)
#endif
                    .accessibilityIdentifier("contact-address-state")

                TextField("Zip / Postal Code", text: $contactAddress.zip)
#if os(iOS)
                    .textContentType(.postalCode)
#endif
                    .accessibilityIdentifier("contact-address-zip")

                TextField("Country", text: $contactAddress.country)
#if os(iOS)
                    .textContentType(.countryName)
#endif
                    .accessibilityIdentifier("contact-address-country")
            }
        }
        #if os(iOS)
        .contactPicker(isPresented: $showContactPicker) { contact in
            populateFromContact(contact)
        }
        #endif
    }

    #if os(iOS)
    private func populateFromContact(_ contact: CNContact) {
        contactFirstName = contact.givenName
        contactLastName = contact.familyName
        contactCompany = contact.organizationName
        contactJobTitle = contact.jobTitle

        // Emails
        contactEmails = contact.emailAddresses.map { email in
            let label = CNLabeledValue<NSString>.localizedString(forLabel: email.label ?? "")
            return TypedValueEntry(type: label.isEmpty ? "Work" : label, value: email.value as String)
        }
        if contactEmails.isEmpty {
            contactEmails = []
        }

        // Phones
        contactPhones = contact.phoneNumbers.map { phone in
            let label = CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: phone.label ?? "")
            return TypedValueEntry(type: label.isEmpty ? "Mobile" : label, value: phone.value.stringValue)
        }
        if contactPhones.isEmpty {
            contactPhones = []
        }

        // Website
        if let url = contact.urlAddresses.first {
            contactWebsite = url.value as String
        }

        // Address
        if let address = contact.postalAddresses.first?.value {
            contactAddress = ContactAddressEntry(
                street: address.street,
                city: address.city,
                state: address.state,
                zip: address.postalCode,
                country: address.country
            )
        }
    }
    #endif

    // MARK: - WiFi Fetch

    private func fetchCurrentWiFi() {
        #if os(iOS)
        isFetchingWiFi = true

        // Request location permission first (required for WiFi info)
        if locationManager == nil {
            locationManager = CLLocationManager()
        }
        locationManager?.requestWhenInUseAuthorization()

        Task {
            if let network = await NEHotspotNetwork.fetchCurrent() {
                await MainActor.run {
                    wifiSSID = network.ssid
                    isFetchingWiFi = false
                }
            } else {
                await MainActor.run {
                    isFetchingWiFi = false
                }
            }
        }
        #else
        // WiFi network detection not available on macOS
        #endif
    }

    // MARK: - Helpers

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        switch actionType {
        case .url:
            return !urlLabel.trimmingCharacters(in: .whitespaces).isEmpty
                && !urlString.trimmingCharacters(in: .whitespaces).isEmpty
        case .wifi:
            return !wifiSSID.trimmingCharacters(in: .whitespaces).isEmpty
        case .addContact:
            return !contactFirstName.trimmingCharacters(in: .whitespaces).isEmpty
                && !contactLastName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func saveAction() {
        let action: NoteAction
        switch actionType {
        case .url:
            action = .url(.init(
                _type: .url,
                label: urlLabel.trimmingCharacters(in: .whitespaces),
                url: urlString.trimmingCharacters(in: .whitespaces)
            ))
        case .wifi:
            let encryption = WifiAction.encryptionPayload(rawValue: wifiEncryption.rawValue)
            action = .wifi(.init(
                _type: .wifi,
                ssid: wifiSSID.trimmingCharacters(in: .whitespaces),
                password: wifiPassword.isEmpty ? nil : wifiPassword,
                encryption: encryption
            ))
        case .addContact:
            let emails = contactEmails
                .filter { !$0.type.isEmpty && !$0.value.isEmpty }
                .map { TypedValue(_type: $0.type, value: $0.value) }
            let phones = contactPhones
                .filter { !$0.type.isEmpty && !$0.value.isEmpty }
                .map { TypedValue(_type: $0.type, value: $0.value) }
            let addressPayload: AddContactAction.addressPayload?
            if !contactAddress.isEmpty {
                addressPayload = .init(value1: BusinessCardAddress(
                    street: contactAddress.street.isEmpty ? nil : contactAddress.street,
                    city: contactAddress.city.isEmpty ? nil : contactAddress.city,
                    state: contactAddress.state.isEmpty ? nil : contactAddress.state,
                    zip: contactAddress.zip.isEmpty ? nil : contactAddress.zip,
                    country: contactAddress.country.isEmpty ? nil : contactAddress.country
                ))
            } else {
                addressPayload = nil
            }
            action = .add_hyphen_contact(.init(
                _type: .add_hyphen_contact,
                firstName: contactFirstName.trimmingCharacters(in: .whitespaces),
                lastName: contactLastName.trimmingCharacters(in: .whitespaces),
                emails: emails.isEmpty ? nil : emails,
                phones: phones.isEmpty ? nil : phones,
                company: contactCompany.isEmpty ? nil : contactCompany,
                jobTitle: contactJobTitle.isEmpty ? nil : contactJobTitle,
                website: contactWebsite.isEmpty ? nil : contactWebsite,
                address: addressPayload
            ))
        }
        onSave(action)
        dismiss()
    }

    private func prefillIfEditing() {
        guard case let .edit(_, action) = mode else { return }
        switch action {
        case let .url(urlAction):
            actionType = .url
            urlLabel = urlAction.label
            urlString = urlAction.url
        case let .wifi(wifiAction):
            actionType = .wifi
            wifiSSID = wifiAction.ssid
            wifiPassword = wifiAction.password ?? ""
            if let enc = wifiAction.encryption {
                wifiEncryption = WifiEncryption(rawValue: enc.rawValue) ?? .wpa
            }
        case let .add_hyphen_contact(contactAction):
            actionType = .addContact
            contactFirstName = contactAction.firstName
            contactLastName = contactAction.lastName
            contactEmails = contactAction.emails?.map { TypedValueEntry(type: $0._type, value: $0.value) } ?? []
            contactPhones = contactAction.phones?.map { TypedValueEntry(type: $0._type, value: $0.value) } ?? []
            contactCompany = contactAction.company ?? ""
            contactJobTitle = contactAction.jobTitle ?? ""
            contactWebsite = contactAction.website ?? ""
            if let addr = contactAction.address?.value1 {
                contactAddress = ContactAddressEntry(
                    street: addr.street ?? "",
                    city: addr.city ?? "",
                    state: addr.state ?? "",
                    zip: addr.zip ?? "",
                    country: addr.country ?? ""
                )
            }
        }
    }
}

// MARK: - Contact Address Entry

struct ContactAddressEntry {
    var street: String = ""
    var city: String = ""
    var state: String = ""
    var zip: String = ""
    var country: String = ""

    var isEmpty: Bool {
        street.isEmpty && city.isEmpty && state.isEmpty && zip.isEmpty && country.isEmpty
    }
}

#Preview("Create URL Action") {
    ActionEditorView { action in
        print("Created: \(action)")
    }
}

#Preview("Create WiFi Action") {
    ActionEditorView { action in
        print("Created: \(action)")
    }
}
#Preview("Create Add Contact Action") {
    ActionEditorView(initialType: .addContact) { action in
        print("Created: \(action)")
    }
}

