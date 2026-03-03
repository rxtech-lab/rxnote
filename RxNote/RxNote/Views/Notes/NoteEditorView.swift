//
//  NoteEditorView.swift
//  RxNote
//
//  Full-screen note editor for creating, editing, and viewing notes
//

#if os(iOS)
import Contacts
#endif
import MapKit
import PhotosUI
import RxNoteCore
import SwiftUI

// MARK: - App Theme Color

extension Color {
    static var appAccent: Color {
        Color(light: Color(red: 0.506, green: 0.220, blue: 0.820),
              dark: Color(red: 0.720, green: 0.520, blue: 0.780))
    }

    init(light: Color, dark: Color) {
        #if os(iOS)
        self.init(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
        #else
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
                ? NSColor(dark)
                : NSColor(light)
        })
        #endif
    }
}

struct NoteEditorView: View {
    let mode: NoteEditorMode
    let onSave: ((Note) -> Void)?
    let onEdit: (() -> Void)?
    let onCancel: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: NoteEditorViewModel
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    #if os(iOS)
    @State private var showCamera = false
    #endif
    @State private var showLocationPicker = false
    @State private var showBusinessCardPhotoMenu = false
    @State private var businessCardPhotoItem: PhotosPickerItem?
    #if os(iOS)
    @State private var showBusinessCardCamera = false
    #endif

    @State private var actionSheetMode: ActionSheetPresentation?
    @State private var fullscreenImageURL: String?
    @State private var wifiConnectionState: WiFiConnectionState = .idle
    @State private var pendingAddContact: PendingAddContact?
    #if os(iOS)
    @State private var showContactPicker = false
    #endif

    init(
        mode: NoteEditorMode = .create,
        onSave: ((Note) -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.onSave = onSave
        self.onEdit = onEdit
        self.onCancel = onCancel
        _viewModel = State(initialValue: NoteEditorViewModel(mode: mode))
    }

    var body: some View {
        editorWrapper
            .onChange(of: selectedPhotoItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await handlePhotoSelection(items) }
                selectedPhotoItems = []
            }
            .onChange(of: businessCardPhotoItem) { _, item in
                guard let item else { return }
                Task { await handleBusinessCardPhotoSelection(item) }
                businessCardPhotoItem = nil
            }
            .scrollDismissesKeyboard(.interactively)
        #if os(iOS)
            .sheet(isPresented: $showCamera) {
                CameraPickerView { image in
                    Task { await handleCameraCapture(image) }
                }
            }
            .sheet(isPresented: $showBusinessCardCamera) {
                CameraPickerView { image in
                    Task { await handleBusinessCardCameraCapture(image) }
                }
            }
        #endif
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView(
                    latitude: viewModel.latitude,
                    longitude: viewModel.longitude
                ) { lat, lon in
                    viewModel.setLocation(latitude: lat, longitude: lon)
                }
            }
            .sheet(item: $actionSheetMode) { mode in
                switch mode {
                case .create:
                    ActionEditorView { action in
                        viewModel.addAction(action)
                    }
                case let .edit(index, action):
                    ActionEditorView(mode: .edit(index: index, action: action)) { updated in
                        viewModel.updateAction(at: index, with: updated)
                    }
                }
            }
            .sheet(item: $pendingAddContact) { pending in
                #if os(iOS)
                AddContactViewControllerRepresentable(action: pending.action) {
                    pendingAddContact = nil
                }
                #else
                VStack(spacing: 12) {
                    Text("Add Contact")
                        .font(.headline)
                    Text("Adding contacts is only available on iOS.")
                        .foregroundStyle(.secondary)
                    Button("Close") {
                        pendingAddContact = nil
                    }
                }
                .padding(24)
                #endif
            }
        #if os(iOS)
            .sheet(isPresented: $showContactPicker, onDismiss: {
                // Sheet dismissed (either by selection or cancel)
            }) {
                ContactPickerViewControllerRepresentable(
                    onContactSelected: { contact in
                        applyContact(contact)
                    },
                    onDismiss: {
                        showContactPicker = false
                    }
                )
                .ignoresSafeArea()
            }
        #endif
            .alert("Error", isPresented: .init(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.clearError() } }
            )) {
                Button("OK") { viewModel.clearError() }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
        #if os(iOS)
            .fullScreenCover(item: $fullscreenImageURL) { url in
                FullscreenImageView(imageURL: url)
            }
        #else
            .sheet(item: $fullscreenImageURL) { url in
                FullscreenImageView(imageURL: url)
            }
        #endif
    }

    // MARK: - Navigation Wrapper

    /// Whether the editor is displayed inline (without its own navigation stack)
    private var isInline: Bool {
        onCancel != nil
    }

    private var editorWrapper: some View {
        editorWithToolbar
    }

    private var editorWithToolbar: some View {
        editorContent
        #if os(iOS)
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if !viewModel.isReadOnly {
                ToolbarItem(placement: .navigation) {
                    Button {
                        if let onCancel {
                            onCancel()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                }

                ToolbarItem(placement: .principal) {}
                #if os(iOS)
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()

                    if viewModel.noteType != .businessCard {
                        PhotosPicker(
                            selection: $selectedPhotoItems,
                            maxSelectionCount: 5,
                            matching: .images
                        ) {
                            Image(systemName: "photo.on.rectangle")
                        }

                        Button { showCamera = true } label: {
                            Image(systemName: "camera")
                        }
                    }

                    Button { showLocationPicker = true } label: {
                        Image(systemName: viewModel.latitude != nil ? "location.fill" : "location")
                    }

                    Button { actionSheetMode = .create } label: {
                        Image(systemName: "link.badge.plus")
                    }
                    .accessibilityIdentifier("add-action-button")

                    Spacer()
                }
                #else
                ToolbarItemGroup(placement: .secondaryAction) {
                    if viewModel.noteType != .businessCard {
                        PhotosPicker(
                            selection: $selectedPhotoItems,
                            maxSelectionCount: 5,
                            matching: .images
                        ) {
                            Label("Add Photos", systemImage: "photo.on.rectangle")
                        }
                    }

                    Button { showLocationPicker = true } label: {
                        Label("Add Location", systemImage: viewModel.latitude != nil ? "location.fill" : "location")
                    }

                    Button { actionSheetMode = .create } label: {
                        Label("Add Action", systemImage: "link.badge.plus")
                    }
                    .accessibilityIdentifier("add-action-button")
                }
                #endif
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if !viewModel.isReadOnly {
                    Menu {
                        Section("Note Type") {
                            ForEach(EditorNoteType.allCases) { type in
                                Button {
                                    viewModel.noteType = type
                                } label: {
                                    if viewModel.noteType == type {
                                        Label(type.displayName, systemImage: "checkmark")
                                    } else {
                                        Text(type.displayName)
                                    }
                                }
                            }
                        }

                        Section("Visibility") {
                            ForEach(EditorVisibility.allCases) { vis in
                                Button {
                                    viewModel.visibility = vis
                                } label: {
                                    if viewModel.visibility == vis {
                                        Label(vis.displayName, systemImage: "checkmark")
                                    } else {
                                        Label(vis.displayName, systemImage: vis.systemImage)
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: viewModel.noteType.systemImage)
                    }
                    .accessibilityIdentifier("note-type-picker")
                }

                if viewModel.isReadOnly {
                    // Only show edit button if onEdit callback is provided
                    if let onEdit {
                        Button {
                            onEdit()
                        } label: {
                            Image(systemName: "pencil")
                                .font(.title3.weight(.medium))
                        }
                        .accessibilityIdentifier("note-detail-edit-button")
                    }
                } else if viewModel.isSaving {
                    ProgressView()
                } else {
                    Button {
                        Task { await saveNote() }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityIdentifier("note-save-button")
                    .disabled(!viewModel.canSave || viewModel.hasUploadsInProgress)
                }
            }
        }
    }

    // MARK: - Editor Content

    private var editorContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Date
                Text(viewModel.noteDate.formatted(date: .long, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)

                if viewModel.noteType == .businessCard {
                    BusinessCardEditorContent(
                        viewModel: viewModel,
                        businessCardPhotoItem: $businessCardPhotoItem,
                        onShowCamera: {
                            #if os(iOS)
                            showBusinessCardCamera = true
                            #endif
                        },
                        onImageTapped: { url in
                            fullscreenImageURL = url
                        },
                        onActionEdit: { index, action in
                            actionSheetMode = .edit(index: index, action: action)
                        },
                        onAddContact: { action in
                            pendingAddContact = PendingAddContact(action: action)
                        },
                        onImportContact: {
                            #if os(iOS)
                            showContactPicker = true
                            #endif
                        }
                    )
                } else {
                    TextNoteEditorContent(
                        viewModel: viewModel,
                        onImageTapped: { url in
                            fullscreenImageURL = url
                        },
                        onActionEdit: { index, action in
                            actionSheetMode = .edit(index: index, action: action)
                        },
                        onActionCreate: {
                            actionSheetMode = .create
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Actions

    private func saveNote() async {
        if let note = await viewModel.save() {
            onSave?(note)
            // Only dismiss if not in inline mode (detail view)
            // When onCancel is provided, the parent view handles navigation
            if !isInline {
                dismiss()
            }
        }
    }

    private func handlePhotoSelection(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await viewModel.uploadImage(data: data)
            }
        }
    }

    private func handleBusinessCardPhotoSelection(_ item: PhotosPickerItem) async {
        if let data = try? await item.loadTransferable(type: Data.self) {
            await viewModel.uploadBusinessCardImage(data: data, filename: "profile_\(Int(Date().timeIntervalSince1970)).jpg")
        }
    }

    #if os(iOS)
    private func handleCameraCapture(_ image: UIImage) async {
        if let data = image.jpegData(compressionQuality: 0.8) {
            await viewModel.uploadImage(data: data, filename: "camera_\(Int(Date().timeIntervalSince1970)).jpg")
        }
    }

    private func handleBusinessCardCameraCapture(_ image: UIImage) async {
        if let data = image.jpegData(compressionQuality: 0.8) {
            await viewModel.uploadBusinessCardImage(data: data, filename: "profile_\(Int(Date().timeIntervalSince1970)).jpg")
        }
    }

    private func applyContact(_ contact: CNContact) {
        viewModel.businessCardFirstName = contact.givenName
        viewModel.businessCardLastName = contact.familyName
        viewModel.businessCardCompany = contact.organizationName
        viewModel.businessCardJobTitle = contact.jobTitle

        viewModel.businessCardEmails = contact.emailAddresses.map { labeled in
            TypedValueEntry(type: emailTypeFromCNLabel(labeled.label), value: labeled.value as String)
        }

        viewModel.businessCardPhones = contact.phoneNumbers.map { labeled in
            TypedValueEntry(type: phoneTypeFromCNLabel(labeled.label), value: labeled.value.stringValue)
        }

        viewModel.businessCardWebsite = (contact.urlAddresses.first?.value as String?) ?? ""

        if let postal = contact.postalAddresses.first?.value {
            viewModel.businessCardAddress = EditableAddress(
                street: postal.street,
                city: postal.city,
                state: postal.state,
                zip: postal.postalCode,
                country: postal.country
            )
        } else {
            viewModel.businessCardAddress = EditableAddress()
        }

        viewModel.businessCardSocialProfiles = contact.socialProfiles.map { labeled in
            NameValueEntry(name: labeled.value.service, value: labeled.value.username)
        }

        viewModel.businessCardInstantMessaging = contact.instantMessageAddresses.map { labeled in
            NameValueEntry(name: labeled.value.service, value: labeled.value.username)
        }

        // Import contact photo if available
        if let imageData = contact.imageData {
            Task {
                await viewModel.uploadBusinessCardImage(data: imageData, filename: "profile_\(Int(Date().timeIntervalSince1970)).jpg")
            }
        } else {
            viewModel.removeBusinessCardImage()
        }
    }
    #endif
}

// MARK: - Action Sheet Presentation

private enum ActionSheetPresentation: Identifiable {
    case create
    case edit(index: Int, action: NoteAction)

    var id: String {
        switch self {
        case .create: return "create"
        case let .edit(index, _): return "edit-\(index)"
        }
    }
}

private struct PendingAddContact: Identifiable {
    let id = UUID()
    let action: AddContactAction
}

// MARK: - String Identifiable Extension

extension String: @retroactive Identifiable {
    public var id: String { self }
}

#Preview("Create") {
    NoteEditorView(mode: .create)
}

#Preview("With Actions") {
    let sampleNote = NoteDetail(
        id: "1",
        userId: "user-1",
        _type: .regular_hyphen_text_hyphen_note,
        title: "Meeting Room WiFi",
        note: "Connect to the guest network using the credentials below. The network password is updated weekly.",
        images: [],
        audios: [],
        videos: [],
        latitude: 37.7749,
        longitude: -122.4194,
        actions: [
            .url(.init(
                _type: .url,
                label: "Company Website",
                url: "https://example.com"
            )),
            .wifi(.init(
                _type: .wifi,
                ssid: "GuestNetwork",
                password: "welcome123",
                encryption: .WPA
            ))
        ],
        visibility: ._public,
        previewUrl: "https://example.com/preview/1",
        createdAt: Date(),
        updatedAt: Date(),
        whitelist: []
    )
    NoteEditorView(mode: .view(noteId: "1", existing: sampleNote))
}

#Preview("Edit Mode") {
    let sampleNote = NoteDetail(
        id: "1",
        userId: "user-1",
        _type: .regular_hyphen_text_hyphen_note,
        title: "Meeting Room WiFi",
        note: "Connect to the guest network using the credentials below.",
        images: [],
        audios: [],
        videos: [],
        latitude: 37.7749,
        longitude: -122.4194,
        actions: [
            .url(.init(
                _type: .url,
                label: "Company Website",
                url: "https://example.com"
            )),
            .wifi(.init(
                _type: .wifi,
                ssid: "GuestNetwork",
                password: "welcome123",
                encryption: .WPA
            ))
        ],
        visibility: ._public,
        previewUrl: "https://example.com/preview/1",
        createdAt: Date(),
        updatedAt: Date(),
        whitelist: []
    )
    NoteEditorView(mode: .edit(noteId: "1", existing: sampleNote))
}

#Preview("Business Card - View") {
    let card = NoteDetail(
        id: "2",
        userId: "user-1",
        _type: .business_hyphen_card,
        title: "Jane Smith",
        note: nil,
        businessCard: .init(value1: .init(
            firstName: "Jane",
            lastName: "Smith",
            emails: [.init(_type: "Work", value: "jane.smith@acme.com")],
            phones: [.init(_type: "Mobile", value: "+1 (555) 123-4567")],
            company: "Acme Corporation",
            jobTitle: "Senior Engineer",
            website: "https://janesmith.dev",
            address: .init(value1: .init(street: "123 Innovation Drive", city: "San Francisco", state: "CA", country: "US"))
        )),
        images: [],
        audios: [],
        videos: [],
        latitude: nil,
        longitude: nil,
        actions: [],
        visibility: ._public,
        previewUrl: "https://example.com/preview/2",
        createdAt: Date(),
        updatedAt: Date(),
        whitelist: []
    )
    NoteEditorView(mode: .view(noteId: "2", existing: card))
}

#Preview("Business Card - Edit") {
    let card = NoteDetail(
        id: "3",
        userId: "user-1",
        _type: .business_hyphen_card,
        title: "Bob Jones",
        note: nil,
        businessCard: .init(value1: .init(
            firstName: "Bob",
            lastName: "Jones",
            emails: [.init(_type: "Work", value: "bob@startup.io")],
            phones: [.init(_type: "Mobile", value: "+44 7700 900000")],
            company: "Startup Inc",
            jobTitle: "CTO"
        )),
        images: [],
        audios: [],
        videos: [],
        latitude: nil,
        longitude: nil,
        actions: [
            .url(.init(
                _type: .url,
                label: "LinkedIn",
                url: "https://linkedin.com/in/bobjones"
            ))
        ],
        visibility: ._private,
        previewUrl: "https://example.com/preview/3",
        createdAt: Date(),
        updatedAt: Date(),
        whitelist: []
    )
    NoteEditorView(mode: .edit(noteId: "3", existing: card))
}

#Preview("Business Card - Create") {
    NoteEditorView(mode: .create)
}
