//
//  NoteEditorView.swift
//  RxNote
//
//  Full-screen note editor for creating, editing, and viewing notes
//

import MapKit
import PhotosUI
import RxNoteCore
import SwiftUI

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
    @State private var showVisibilityPicker = false
    @State private var actionSheetMode: ActionSheetPresentation?
    @State private var fullscreenImageURL: String?
    @State private var wifiConnectionState: WiFiConnectionState = .idle

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
            #if os(iOS)
            .sheet(isPresented: $showCamera) {
                CameraPickerView { image in
                    Task { await handleCameraCapture(image) }
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

    @ViewBuilder
    private var editorWrapper: some View {
        if viewModel.isReadOnly || isInline {
            editorWithToolbar
        } else {
            NavigationStack {
                editorWithToolbar
            }
        }
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
                    #if os(iOS)
                    ToolbarItemGroup(placement: .bottomBar) {
                        Spacer()

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

                        Button { showLocationPicker = true } label: {
                            Image(systemName: viewModel.latitude != nil ? "location.fill" : "location")
                        }

                        Button { actionSheetMode = .create } label: {
                            Image(systemName: "link.badge.plus")
                        }

                        Spacer()
                    }
                    #else
                    ToolbarItemGroup(placement: .secondaryAction) {
                        PhotosPicker(
                            selection: $selectedPhotoItems,
                            maxSelectionCount: 5,
                            matching: .images
                        ) {
                            Label("Add Photos", systemImage: "photo.on.rectangle")
                        }

                        Button { showLocationPicker = true } label: {
                            Label("Add Location", systemImage: viewModel.latitude != nil ? "location.fill" : "location")
                        }

                        Button { actionSheetMode = .create } label: {
                            Label("Add Action", systemImage: "link.badge.plus")
                        }
                    }
                    #endif
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    if !viewModel.isReadOnly {
                        Button {
                            showVisibilityPicker = true
                        } label: {
                            Label(viewModel.visibility.displayName, systemImage: viewModel.visibility.systemImage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .popover(isPresented: $showVisibilityPicker) {
                            visibilityPicker
                        }
                    }

                    if viewModel.isReadOnly {
                        Button {
                            onEdit?()
                        } label: {
                            Image(systemName: "pencil")
                                .font(.title3.weight(.medium))
                        }
                    } else if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button {
                            Task { await saveNote() }
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .disabled(!viewModel.canSave || viewModel.hasUploadsInProgress)
                    }
                }
            }
    }

    // MARK: - Visibility Picker

    private var visibilityPicker: some View {
        VStack(spacing: 0) {
            ForEach(EditorVisibility.allCases) { vis in
                Button {
                    viewModel.visibility = vis
                    showVisibilityPicker = false
                } label: {
                    HStack {
                        Label(vis.displayName, systemImage: vis.systemImage)
                        Spacer()
                        if viewModel.visibility == vis {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.purple)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .foregroundStyle(.primary)

                if vis != EditorVisibility.allCases.last {
                    Divider()
                }
            }
        }
        .frame(width: 200)
        .presentationCompactAdaptation(.popover)
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

                // Media Section
                if !viewModel.existingImages.isEmpty || !viewModel.pendingUploads.isEmpty || viewModel.latitude != nil {
                    mediaSection
                }

                // Actions section (edit mode only - shows inline with edit/delete buttons)
                if !viewModel.actions.isEmpty && !viewModel.isReadOnly {
                    actionsSection
                }

                // Title
                if viewModel.isReadOnly {
                    Text(viewModel.title)
                        .font(.title.weight(.bold))
                        .padding(.horizontal, 16)
                } else {
                    TextField("Title", text: $viewModel.title, axis: .vertical)
                        .font(.title.weight(.bold))
                        .padding(.horizontal, 16)
                }

                // Content
                if viewModel.isReadOnly {
                    if !viewModel.content.isEmpty {
                        Text(viewModel.content)
                            .font(.body)
                            .padding(.horizontal, 16)
                    }
                } else {
                    ZStack(alignment: .topLeading) {
                        if viewModel.content.isEmpty {
                            Text("Start writing...")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                        }
                        TextEditor(text: $viewModel.content)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 200)
                    }
                }

                // Action buttons (read-only mode - prominent buttons below content)
                if !viewModel.actions.isEmpty && viewModel.isReadOnly {
                    actionButtonsSection
                }
            }
            .padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Media Section

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Location map
            if let lat = viewModel.latitude, let lon = viewModel.longitude {
                locationThumbnail(latitude: lat, longitude: lon)
            }

            // Images
            let hasImages = !viewModel.existingImages.isEmpty
                || viewModel.pendingUploads.contains(where: { $0.status.isCompleted || $0.status.isInProgress })
            if hasImages {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.existingImages, id: \.id) { image in
                            if viewModel.isReadOnly {
                                tappableImageThumbnail(url: image.url)
                            } else {
                                imageCell(url: image.url) {
                                    viewModel.removeExistingImage(id: image.id)
                                }
                            }
                        }

                        ForEach(viewModel.pendingUploads) { upload in
                            if upload.status.isCompleted, let url = upload.publicUrl {
                                if viewModel.isReadOnly {
                                    tappableImageThumbnail(url: url)
                                } else {
                                    imageCell(url: url) {
                                        viewModel.removePendingUpload(id: upload.id)
                                    }
                                }
                            } else if upload.status.isInProgress {
                                uploadProgressCell(upload)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func locationThumbnail(latitude: Double, longitude: Double) -> some View {
        ZStack(alignment: .topTrailing) {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))) {
                Marker("", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                    .tint(.purple)
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .allowsHitTesting(false)
            .overlay {
                if viewModel.isReadOnly {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            openInMaps(latitude: latitude, longitude: longitude)
                        }
                }
            }

            if viewModel.isReadOnly {
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .purple)
                    .padding(8)
            } else {
                Button {
                    viewModel.removeLocation()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.6))
                }
                .padding(8)
            }
        }
        .padding(.horizontal, 16)
    }

    private func openInMaps(latitude: Double, longitude: Double) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = viewModel.title.isEmpty ? "Location" : viewModel.title
        mapItem.openInMaps()
    }

    private func imageThumbnail(url: String) -> some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: 100, height: 100)
            case let .success(image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            case .failure:
                Image(systemName: "photo")
                    .frame(width: 100, height: 100)
                    .background(Color(.secondarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            @unknown default:
                EmptyView()
            }
        }
    }

    private func tappableImageThumbnail(url: String) -> some View {
        Button {
            fullscreenImageURL = url
        } label: {
            imageThumbnail(url: url)
        }
        .buttonStyle(.plain)
    }

    private func imageCell(url: String, onRemove: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            imageThumbnail(url: url)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.callout)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .padding(4)
        }
    }

    private func uploadProgressCell(_ upload: PendingUpload) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemFill))
                .frame(width: 100, height: 100)

            VStack(spacing: 4) {
                ProgressView(value: upload.progress)
                    .frame(width: 60)
                Text(upload.formattedSize)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(viewModel.actions.enumerated()), id: \.offset) { index, action in
                HStack {
                    actionLabel(action)
                    Spacer()
                    if !viewModel.isReadOnly {
                        Button {
                            actionSheetMode = .edit(index: index, action: viewModel.actions[index])
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            viewModel.removeAction(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func actionLabel(_ action: NoteAction) -> some View {
        switch action {
        case let .url(urlAction):
            Label(urlAction.label, systemImage: "link")
                .font(.subheadline)
        case let .wifi(wifiAction):
            Label(wifiAction.ssid, systemImage: "wifi")
                .font(.subheadline)
        }
    }

    // MARK: - Action Buttons Section (Read-Only)

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Divider()
            ForEach(Array(viewModel.actions.enumerated()), id: \.offset) { _, action in
                actionButton(for: action)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func actionButton(for action: NoteAction) -> some View {
        switch action {
        case let .url(urlAction):
            if let url = URL(string: urlAction.url) {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "link")
                            .font(.body.weight(.medium))
                        Text(urlAction.label)
                            .font(.body.weight(.medium))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    #if os(iOS)
                    .background(Color(.secondarySystemBackground))
                    #else
                    .background(Color(NSColor.controlBackgroundColor))
                    #endif
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.purple)
            }
        case let .wifi(wifiAction):
            WiFiActionButton(wifiAction: wifiAction, connectionState: $wifiConnectionState)
        }
    }

    // MARK: - Actions

    private func saveNote() async {
        if let note = await viewModel.save() {
            if let onSave {
                onSave(note)
            } else {
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

    #if os(iOS)
    private func handleCameraCapture(_ image: UIImage) async {
        if let data = image.jpegData(compressionQuality: 0.8) {
            await viewModel.uploadImage(data: data, filename: "camera_\(Int(Date().timeIntervalSince1970)).jpg")
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

// MARK: - String Identifiable Extension

extension String: @retroactive Identifiable {
    public var id: String { self }
}

#Preview("Create") {
    NoteEditorView(mode: .create)
}

#Preview("With Actions") {
    let sampleNote = NoteDetail(
        id: 1,
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
    NoteEditorView(mode: .view(noteId: 1, existing: sampleNote))
}
