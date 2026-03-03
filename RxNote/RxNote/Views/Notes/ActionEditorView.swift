//
//  ActionEditorView.swift
//  RxNote
//
//  Editor for creating/editing note actions (URL, WiFi, or Add Contact)
//

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
    @State private var contactEmail = ""
    @State private var contactPhone = ""
    @State private var contactCompany = ""
    @State private var contactJobTitle = ""
    @State private var contactWebsite = ""
    @State private var contactAddress = ""
    @State private var isFetchingWiFi = false
    @State private var locationManager: CLLocationManager?

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

    init(mode: Mode = .create, onSave: @escaping (NoteAction) -> Void) {
        self.mode = mode
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
                    .pickerStyle(.segmented)
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
        Section("Contact Information") {
            TextField("First Name", text: $contactFirstName)
                .accessibilityIdentifier("contact-first-name")
            TextField("Last Name", text: $contactLastName)
                .accessibilityIdentifier("contact-last-name")
            TextField("Email", text: $contactEmail)
                #if os(iOS)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                #endif
            TextField("Phone", text: $contactPhone)
                #if os(iOS)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                #endif
            TextField("Company", text: $contactCompany)
            TextField("Job Title", text: $contactJobTitle)
            TextField("Website", text: $contactWebsite)
                #if os(iOS)
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                #endif
            TextField("Address", text: $contactAddress)
                #if os(iOS)
                .textContentType(.fullStreetAddress)
                #endif
        }
    }

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
            let trimmedEmail = contactEmail.trimmingCharacters(in: .whitespaces)
            let trimmedPhone = contactPhone.trimmingCharacters(in: .whitespaces)
            let trimmedAddress = contactAddress.trimmingCharacters(in: .whitespaces)
            action = .add_hyphen_contact(.init(
                _type: .add_hyphen_contact,
                firstName: contactFirstName.trimmingCharacters(in: .whitespaces),
                lastName: contactLastName.trimmingCharacters(in: .whitespaces),
                emails: trimmedEmail.isEmpty ? nil : [.init(_type: "Work", value: trimmedEmail)],
                phones: trimmedPhone.isEmpty ? nil : [.init(_type: "Mobile", value: trimmedPhone)],
                company: contactCompany.isEmpty ? nil : contactCompany,
                jobTitle: contactJobTitle.isEmpty ? nil : contactJobTitle,
                website: contactWebsite.isEmpty ? nil : contactWebsite,
                address: trimmedAddress.isEmpty ? nil : .init(value1: .init(street: trimmedAddress))
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
            contactEmail = contactAction.emails?.first?.value ?? ""
            contactPhone = contactAction.phones?.first?.value ?? ""
            contactCompany = contactAction.company ?? ""
            contactJobTitle = contactAction.jobTitle ?? ""
            contactWebsite = contactAction.website ?? ""
            contactAddress = contactAction.address?.value1.street ?? ""
        }
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
