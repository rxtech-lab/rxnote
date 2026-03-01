//
//  ActionEditorView.swift
//  RxNote
//
//  Editor for creating/editing note actions (URL or WiFi)
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
    @State private var isFetchingWiFi = false
    @State private var locationManager: CLLocationManager?

    enum ActionType: String, CaseIterable {
        case url = "URL"
        case wifi = "WiFi"
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
                        }
                    }
                    .pickerStyle(.segmented)
                }

                switch actionType {
                case .url:
                    urlForm
                case .wifi:
                    wifiForm
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
