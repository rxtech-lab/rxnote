//
//  NoteEditorViewModel.swift
//  RxNoteCore
//
//  View model for creating and editing notes
//

import Foundation

// MARK: - Editor Visibility

/// Visibility level for the editor form
public enum EditorVisibility: String, CaseIterable, Identifiable, Sendable {
    case `public` = "public"
    case `private` = "private"
    case authOnly = "auth-only"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .public: return "Public"
        case .private: return "Private"
        case .authOnly: return "Auth Only"
        }
    }

    public var systemImage: String {
        switch self {
        case .public: return "globe"
        case .private: return "lock"
        case .authOnly: return "person.badge.key"
        }
    }

    public var insertValue: NoteInsert.visibilityPayload {
        .init(rawValue: rawValue)!
    }

    public var updateValue: NoteUpdate.visibilityPayload {
        .init(rawValue: rawValue)!
    }

    public init(from detail: NoteDetail.visibilityPayload) {
        self.init(rawValue: detail.rawValue)!
    }

    public init(from note: Note.visibilityPayload) {
        self.init(rawValue: note.rawValue)!
    }
}

// MARK: - Note Type

/// Note type for editor mode and payload mapping
public enum EditorNoteType: String, CaseIterable, Identifiable, Sendable {
    case regularTextNote = "regular-text-note"
    case businessCard = "business-card"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .regularTextNote: return "Text Note"
        case .businessCard: return "Business Card"
        }
    }

    public var systemImage: String {
        switch self {
        case .regularTextNote: return "doc.text"
        case .businessCard: return "person.text.rectangle"
        }
    }

    public var insertValue: NoteInsert._typePayload {
        .init(rawValue: rawValue)!
    }

    public var updateValue: NoteUpdate._typePayload {
        .init(rawValue: rawValue)!
    }
}

// MARK: - Identifiable Entry Types

/// Identifiable wrapper for typed value entries (emails, phones)
public struct TypedValueEntry: Identifiable, Sendable {
    public let id: UUID
    public var type: String
    public var value: String

    public init(id: UUID = UUID(), type: String = "", value: String = "") {
        self.id = id
        self.type = type
        self.value = value
    }
}

/// Identifiable wrapper for name-value entries (social profiles, IM)
public struct NameValueEntry: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var value: String

    public init(id: UUID = UUID(), name: String = "", value: String = "") {
        self.id = id
        self.name = name
        self.value = value
    }
}

/// Editable structured address
public struct EditableAddress: Sendable {
    public var street: String
    public var city: String
    public var state: String
    public var zip: String
    public var country: String

    public init(street: String = "", city: String = "", state: String = "", zip: String = "", country: String = "") {
        self.street = street
        self.city = city
        self.state = state
        self.zip = zip
        self.country = country
    }

    public var isEmpty: Bool {
        street.isEmpty && city.isEmpty && state.isEmpty && zip.isEmpty && country.isEmpty
    }
}

// MARK: - Editor Mode

/// Mode for the note editor
public enum NoteEditorMode {
    case create
    case edit(noteId: String, existing: NoteDetail)
    case view(noteId: String, existing: NoteDetail)
}

// MARK: - View Model

/// View model for the note editor (create/edit)
@Observable
@MainActor
public final class NoteEditorViewModel {
    // MARK: - Form State

    public var title: String = ""
    public var content: String = ""
    public var noteType: EditorNoteType = .regularTextNote {
        didSet {
            if noteType != .businessCard {
                clearBusinessCardFields()
            }
        }
    }
    public var visibility: EditorVisibility = .public
    public var latitude: Double?
    public var longitude: Double?
    public var actions: [NoteAction] = []
    public var existingImages: [SignedImage] = []
    public var pendingUploads: [PendingUpload] = []
    public var businessCardFirstName: String = ""
    public var businessCardLastName: String = ""
    public var businessCardEmails: [TypedValueEntry] = []
    public var businessCardPhones: [TypedValueEntry] = []
    public var businessCardCompany: String = ""
    public var businessCardJobTitle: String = ""
    public var businessCardWebsite: String = ""
    public var businessCardAddress: EditableAddress = EditableAddress()
    public var businessCardImageUrl: String?
    public var businessCardImageFileId: Int?
    public var businessCardPendingImageUpload: PendingUpload?
    public var businessCardImageRemoved: Bool = false
    public var businessCardSocialProfiles: [NameValueEntry] = []
    public var businessCardInstantMessaging: [NameValueEntry] = []
    public var businessCardWallets: [NameValueEntry] = []

    // MARK: - State

    public private(set) var isSaving = false
    public private(set) var error: Error?
    public let mode: NoteEditorMode

    // MARK: - Private

    private let service: NoteServiceProtocol

    // MARK: - Initialization

    public init(mode: NoteEditorMode = .create, service: NoteServiceProtocol = NoteService()) {
        self.mode = mode
        self.service = service

        switch mode {
        case .create:
            break
        case let .edit(_, existing), let .view(_, existing):
            title = existing.title
            content = existing.note ?? ""
            noteType = EditorNoteType(rawValue: existing._type.rawValue) ?? .regularTextNote
            visibility = EditorVisibility(from: existing.visibility)
            existingImages = existing.images
            latitude = existing.latitude
            longitude = existing.longitude
            actions = existing.actions
            if let businessCard = existing.businessCard {
                let bc = businessCard.value1
                businessCardFirstName = bc.firstName
                businessCardLastName = bc.lastName
                businessCardEmails = bc.emails?.map { TypedValueEntry(type: $0._type, value: $0.value) } ?? []
                businessCardPhones = bc.phones?.map { TypedValueEntry(type: $0._type, value: $0.value) } ?? []
                businessCardCompany = bc.company ?? ""
                businessCardJobTitle = bc.jobTitle ?? ""
                businessCardWebsite = bc.website ?? ""
                if let addr = bc.address?.value1 {
                    businessCardAddress = EditableAddress(
                        street: addr.street ?? "",
                        city: addr.city ?? "",
                        state: addr.state ?? "",
                        zip: addr.zip ?? "",
                        country: addr.country ?? ""
                    )
                }
                businessCardImageUrl = bc.imageUrl
                businessCardImageFileId = bc.imageFileId
                businessCardSocialProfiles = bc.socialProfiles?.map { NameValueEntry(name: $0.name, value: $0.value) } ?? []
                businessCardInstantMessaging = bc.instantMessaging?.map { NameValueEntry(name: $0.name, value: $0.value) } ?? []
                businessCardWallets = bc.wallets?.map { NameValueEntry(name: $0.name, value: $0.value) } ?? []
            }
        }
    }

    // MARK: - Computed Properties

    /// Whether the form has enough data to save
    public var canSave: Bool {
        if noteType == .businessCard {
            let hasFirstName = !businessCardFirstName.trimmingCharacters(in: .whitespaces).isEmpty
            let hasLastName = !businessCardLastName.trimmingCharacters(in: .whitespaces).isEmpty
            return hasFirstName && hasLastName
        }
        let hasTitle = !title.trimmingCharacters(in: .whitespaces).isEmpty
        return hasTitle
    }

    /// Whether there are any uploads still in progress
    public var hasUploadsInProgress: Bool {
        pendingUploads.contains { $0.status.isInProgress }
            || (businessCardPendingImageUpload?.status.isInProgress ?? false)
    }

    /// Note date for display
    public var noteDate: Date {
        switch mode {
        case .create:
            return Date()
        case let .edit(_, existing), let .view(_, existing):
            return existing.createdAt
        }
    }

    /// Whether in edit mode
    public var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    /// Whether in read-only view mode
    public var isReadOnly: Bool {
        if case .view = mode { return true }
        return false
    }

    /// The note ID (for edit/view modes)
    public var noteId: String? {
        switch mode {
        case .create: return nil
        case let .edit(id, _): return id
        case let .view(id, _): return id
        }
    }

    // MARK: - Save

    /// Save the note (create or update)
    /// - Returns: The created/updated Note on success, nil on failure
    public func save() async -> Note? {
        guard canSave else { return nil }
        isSaving = true
        error = nil
        defer { isSaving = false }

        // Collect image references
        var imageRefs: [String] = []
        for image in existingImages {
            imageRefs.append("file:\(image.id)")
        }
        for upload in pendingUploads where upload.status.isCompleted {
            if let ref = upload.fileReference {
                imageRefs.append(ref)
            }
        }

        // Auto-generate title for business cards
        let resolvedTitle: String
        let resolvedContent: String?
        if noteType == .businessCard {
            resolvedTitle = "\(businessCardFirstName.trimmingCharacters(in: .whitespaces)) \(businessCardLastName.trimmingCharacters(in: .whitespaces))"
            resolvedContent = nil
        } else {
            resolvedTitle = title.trimmingCharacters(in: .whitespaces)
            resolvedContent = content.isEmpty ? nil : content
        }

        do {
            switch mode {
            case .view:
                return nil

            case .create:
                let input = NoteInsert(
                    title: resolvedTitle,
                    _type: noteType.insertValue,
                    note: resolvedContent,
                    businessCard: noteType == .businessCard
                        ? .init(value1: buildBusinessCardPayload())
                        : nil,
                    images: imageRefs.isEmpty ? nil : imageRefs,
                    latitude: latitude,
                    longitude: longitude,
                    actions: actions.isEmpty ? nil : actions,
                    visibility: visibility.insertValue
                )
                return try await service.createNote(input)

            case let .edit(noteId, _):
                let input = NoteUpdate(
                    title: resolvedTitle,
                    _type: noteType.updateValue,
                    note: resolvedContent,
                    businessCard: noteType == .businessCard
                        ? .init(value1: buildBusinessCardPayload())
                        : nil,
                    images: imageRefs,
                    latitude: latitude,
                    longitude: longitude,
                    actions: actions.isEmpty ? nil : actions,
                    visibility: visibility.updateValue
                )
                return try await service.updateNote(id: noteId, input: input)
            }
        } catch {
            self.error = error
            return nil
        }
    }

    // MARK: - Image Management

    /// Upload an image from Data
    public func uploadImage(data: Data, filename: String = "photo.jpg") async {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(UUID().uuidString)_\(filename)")

        do {
            try data.write(to: fileURL)

            let contentType = MIMEType.from(url: fileURL)
            let fileSize = Int64(data.count)

            let pending = PendingUpload(
                localURL: fileURL,
                filename: filename,
                contentType: contentType,
                fileSize: fileSize,
                status: .uploading
            )
            let uploadId = pending.id
            pendingUploads.append(pending)

            let result = try await UploadManager.shared.upload(file: fileURL) { [weak self] sent, total in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let idx = self.pendingUploads.firstIndex(where: { $0.id == uploadId }) {
                        self.pendingUploads[idx].progress = Double(sent) / Double(total)
                    }
                }
            }

            if let idx = pendingUploads.firstIndex(where: { $0.id == uploadId }) {
                pendingUploads[idx].fileId = result.fileId
                pendingUploads[idx].publicUrl = result.publicUrl
                pendingUploads[idx].status = .completed
            }

            try? FileManager.default.removeItem(at: fileURL)
        } catch {
            self.error = error
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Remove an existing server image
    public func removeExistingImage(id: Int) {
        existingImages.removeAll { $0.id == id }
    }

    /// Remove a pending upload by its ID
    public func removePendingUpload(id: UUID) {
        pendingUploads.removeAll { $0.id == id }
    }

    // MARK: - Business Card Image Management

    /// Upload a profile image for the business card
    public func uploadBusinessCardImage(data: Data, filename: String = "profile.jpg") async {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(UUID().uuidString)_\(filename)")

        do {
            try data.write(to: fileURL)

            let contentType = MIMEType.from(url: fileURL)
            let fileSize = Int64(data.count)

            let pending = PendingUpload(
                localURL: fileURL,
                filename: filename,
                contentType: contentType,
                fileSize: fileSize,
                status: .uploading
            )
            businessCardPendingImageUpload = pending
            businessCardImageRemoved = false

            let result = try await UploadManager.shared.upload(file: fileURL) { [weak self] sent, total in
                Task { @MainActor [weak self] in
                    self?.businessCardPendingImageUpload?.progress = Double(sent) / Double(total)
                }
            }

            businessCardPendingImageUpload?.fileId = result.fileId
            businessCardPendingImageUpload?.publicUrl = result.publicUrl
            businessCardPendingImageUpload?.status = .completed
            businessCardImageUrl = result.publicUrl

            try? FileManager.default.removeItem(at: fileURL)
        } catch {
            businessCardPendingImageUpload = nil
            self.error = error
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Remove the business card profile image
    public func removeBusinessCardImage() {
        businessCardImageUrl = nil
        businessCardImageFileId = nil
        businessCardPendingImageUpload = nil
        businessCardImageRemoved = true
    }

    // MARK: - Action Management

    /// Add a new action
    public func addAction(_ action: NoteAction) {
        actions.append(action)
    }

    /// Remove an action at index
    public func removeAction(at index: Int) {
        guard actions.indices.contains(index) else { return }
        actions.remove(at: index)
    }

    /// Update an action at index
    public func updateAction(at index: Int, with action: NoteAction) {
        guard actions.indices.contains(index) else { return }
        actions[index] = action
    }

    // MARK: - Location Management

    /// Set the note location
    public func setLocation(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Remove the note location
    public func removeLocation() {
        latitude = nil
        longitude = nil
    }

    // MARK: - Error Handling

    /// Clear the current error
    public func clearError() {
        error = nil
    }

    // MARK: - Private Helpers

    private func clearBusinessCardFields() {
        businessCardFirstName = ""
        businessCardLastName = ""
        businessCardEmails = []
        businessCardPhones = []
        businessCardCompany = ""
        businessCardJobTitle = ""
        businessCardWebsite = ""
        businessCardAddress = EditableAddress()
        businessCardImageUrl = nil
        businessCardImageFileId = nil
        businessCardPendingImageUpload = nil
        businessCardImageRemoved = false
        businessCardSocialProfiles = []
        businessCardInstantMessaging = []
        businessCardWallets = []
    }

    private func buildBusinessCardPayload() -> BusinessCard {
        // Resolve image reference: pending upload > existing file > removed
        let imageRef: String?
        if let pending = businessCardPendingImageUpload, pending.status.isCompleted, let ref = pending.fileReference {
            imageRef = ref
        } else if businessCardImageRemoved {
            imageRef = nil
        } else if let fileId = businessCardImageFileId {
            imageRef = "file:\(fileId)"
        } else {
            imageRef = nil
        }

        // Filter out empty entries
        let emails = businessCardEmails
            .filter { !$0.type.isEmpty && !$0.value.isEmpty }
            .map { TypedValue(_type: $0.type, value: $0.value) }
        let phones = businessCardPhones
            .filter { !$0.type.isEmpty && !$0.value.isEmpty }
            .map { TypedValue(_type: $0.type, value: $0.value) }
        let socialProfiles = businessCardSocialProfiles
            .filter { !$0.name.isEmpty && !$0.value.isEmpty }
            .map { NameValue(name: $0.name, value: $0.value) }
        let instantMessaging = businessCardInstantMessaging
            .filter { !$0.name.isEmpty && !$0.value.isEmpty }
            .map { NameValue(name: $0.name, value: $0.value) }
        let wallets = businessCardWallets
            .filter { !$0.name.isEmpty && !$0.value.isEmpty }
            .map { NameValue(name: $0.name, value: $0.value) }

        let addressPayload: BusinessCard.addressPayload?
        if !businessCardAddress.isEmpty {
            addressPayload = .init(value1: BusinessCardAddress(
                street: businessCardAddress.street.isEmpty ? nil : businessCardAddress.street,
                city: businessCardAddress.city.isEmpty ? nil : businessCardAddress.city,
                state: businessCardAddress.state.isEmpty ? nil : businessCardAddress.state,
                zip: businessCardAddress.zip.isEmpty ? nil : businessCardAddress.zip,
                country: businessCardAddress.country.isEmpty ? nil : businessCardAddress.country
            ))
        } else {
            addressPayload = nil
        }

        return BusinessCard(
            firstName: businessCardFirstName.trimmingCharacters(in: .whitespaces),
            lastName: businessCardLastName.trimmingCharacters(in: .whitespaces),
            emails: emails.isEmpty ? nil : emails,
            phones: phones.isEmpty ? nil : phones,
            company: businessCardCompany.isEmpty ? nil : businessCardCompany,
            jobTitle: businessCardJobTitle.isEmpty ? nil : businessCardJobTitle,
            website: businessCardWebsite.isEmpty ? nil : businessCardWebsite,
            address: addressPayload,
            imageUrl: imageRef,
            socialProfiles: socialProfiles.isEmpty ? nil : socialProfiles,
            instantMessaging: instantMessaging.isEmpty ? nil : instantMessaging,
            wallets: wallets.isEmpty ? nil : wallets
        )
    }
}
