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

// MARK: - Editor Mode

/// Mode for the note editor
public enum NoteEditorMode {
    case create
    case edit(noteId: Int, existing: NoteDetail)
    case view(noteId: Int, existing: NoteDetail)
}

// MARK: - View Model

/// View model for the note editor (create/edit)
@Observable
@MainActor
public final class NoteEditorViewModel {
    // MARK: - Form State

    public var title: String = ""
    public var content: String = ""
    public var visibility: EditorVisibility = .public
    public var latitude: Double?
    public var longitude: Double?
    public var actions: [NoteAction] = []
    public var existingImages: [SignedImage] = []
    public var pendingUploads: [PendingUpload] = []

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
            visibility = EditorVisibility(from: existing.visibility)
            existingImages = existing.images
            latitude = existing.latitude
            longitude = existing.longitude
            actions = existing.actions
        }
    }

    // MARK: - Computed Properties

    /// Whether the form has enough data to save
    public var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Whether there are any uploads still in progress
    public var hasUploadsInProgress: Bool {
        pendingUploads.contains { $0.status.isInProgress }
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
    public var noteId: Int? {
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

        do {
            switch mode {
            case .view:
                return nil

            case .create:
                let input = NoteInsert(
                    title: title.trimmingCharacters(in: .whitespaces),
                    note: content.isEmpty ? nil : content,
                    images: imageRefs.isEmpty ? nil : imageRefs,
                    latitude: latitude,
                    longitude: longitude,
                    actions: actions.isEmpty ? nil : actions,
                    visibility: visibility.insertValue
                )
                return try await service.createNote(input)

            case let .edit(noteId, _):
                let input = NoteUpdate(
                    title: title.trimmingCharacters(in: .whitespaces),
                    note: content.isEmpty ? nil : content,
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
}
