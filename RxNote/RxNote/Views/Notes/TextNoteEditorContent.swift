//
//  TextNoteEditorContent.swift
//  RxNote
//
//  Editor content view for regular text notes
//

import MapKit
import RxNoteCore
import SwiftUI

struct TextNoteEditorContent: View {
    @Bindable var viewModel: NoteEditorViewModel
    let onImageTapped: (String) -> Void
    let onActionEdit: (Int, NoteAction) -> Void
    let onActionCreate: () -> Void

    var body: some View {
        Group {
            // Media Section
            if !viewModel.existingImages.isEmpty || !viewModel.pendingUploads.isEmpty || viewModel.latitude != nil {
                MediaSectionView(
                    viewModel: viewModel,
                    onImageTapped: onImageTapped
                )
            }

            // Actions section (edit mode only - shows inline with edit/delete buttons)
            if !viewModel.actions.isEmpty && !viewModel.isReadOnly {
                ActionsSectionView(
                    viewModel: viewModel,
                    onActionEdit: onActionEdit
                )
            }

            // Title
            if viewModel.isReadOnly {
                Text(viewModel.title)
                    .font(.title.weight(.bold))
                    .padding(.horizontal, 16)
                    .accessibilityIdentifier("note-detail-title")
            } else {
                TextField("Title", text: $viewModel.title)
                    .font(.title.weight(.bold))
                    .padding(.horizontal, 16)
                    .submitLabel(.done)
                    .accessibilityIdentifier("note-title-field")
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
                        .accessibilityIdentifier("note-content-field")
                }
            }

            // Action buttons (read-only mode - prominent buttons below content)
            if !viewModel.actions.isEmpty && viewModel.isReadOnly {
                ActionButtonsSectionView(
                    viewModel: viewModel,
                    onAddContact: { _ in }
                )
            }
        }
    }
}

// MARK: - Media Section View

struct MediaSectionView: View {
    @Bindable var viewModel: NoteEditorViewModel
    let onImageTapped: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Location map
            if let lat = viewModel.latitude, let lon = viewModel.longitude {
                LocationThumbnailView(
                    latitude: lat,
                    longitude: lon,
                    title: viewModel.title,
                    isReadOnly: viewModel.isReadOnly,
                    onRemove: { viewModel.removeLocation() }
                )
            }

            // Images
            let hasImages = !viewModel.existingImages.isEmpty
                || viewModel.pendingUploads.contains(where: { $0.status.isCompleted || $0.status.isInProgress })
            if hasImages {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.existingImages, id: \.id) { image in
                            if viewModel.isReadOnly {
                                TappableImageThumbnail(url: image.url, onTap: onImageTapped)
                            } else {
                                ImageCellView(url: image.url) {
                                    viewModel.removeExistingImage(id: image.id)
                                }
                            }
                        }

                        ForEach(viewModel.pendingUploads) { upload in
                            if upload.status.isCompleted, let url = upload.publicUrl {
                                if viewModel.isReadOnly {
                                    TappableImageThumbnail(url: url, onTap: onImageTapped)
                                } else {
                                    ImageCellView(url: url) {
                                        viewModel.removePendingUpload(id: upload.id)
                                    }
                                }
                            } else if upload.status.isInProgress {
                                UploadProgressCell(upload: upload)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}

// MARK: - Location Thumbnail View

struct LocationThumbnailView: View {
    let latitude: Double
    let longitude: Double
    let title: String
    let isReadOnly: Bool
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))) {
                Marker("", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                    .tint(Color.appAccent)
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .allowsHitTesting(false)
            .overlay {
                if isReadOnly {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            openInMaps()
                        }
                }
            }

            if isReadOnly {
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .purple)
                    .padding(8)
            } else {
                Button {
                    onRemove()
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

    private func openInMaps() {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = title.isEmpty ? "Location" : title
        mapItem.openInMaps()
    }
}

// MARK: - Image Views

struct ImageThumbnail: View {
    let url: String

    var body: some View {
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
                    #if os(iOS)
                    .background(Color(.secondarySystemFill))
                    #else
                    .background(Color(NSColor.controlBackgroundColor))
                    #endif
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            @unknown default:
                EmptyView()
            }
        }
    }
}

struct TappableImageThumbnail: View {
    let url: String
    let onTap: (String) -> Void

    var body: some View {
        Button {
            onTap(url)
        } label: {
            ImageThumbnail(url: url)
        }
        .buttonStyle(.plain)
    }
}

struct ImageCellView: View {
    let url: String
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ImageThumbnail(url: url)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.callout)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .padding(4)
        }
    }
}

struct UploadProgressCell: View {
    let upload: PendingUpload

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                #if os(iOS)
                .fill(Color(.secondarySystemFill))
                #else
                .fill(Color(NSColor.controlBackgroundColor))
                #endif
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
}

// MARK: - Actions Section View

struct ActionsSectionView: View {
    @Bindable var viewModel: NoteEditorViewModel
    let onActionEdit: (Int, NoteAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(viewModel.actions.enumerated()), id: \.offset) { index, action in
                HStack {
                    ActionLabelView(action: action)
                        .foregroundStyle(Color.appAccent)
                    Spacer()
                    Button {
                        onActionEdit(index, viewModel.actions[index])
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        viewModel.removeAction(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.callout)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.6))
                    }
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
        }
        .padding(.horizontal, 16)
    }
}

struct ActionLabelView: View {
    let action: NoteAction

    var body: some View {
        switch action {
        case let .url(urlAction):
            Label(urlAction.label, systemImage: "link")
                .font(.body.weight(.medium))
        case let .wifi(wifiAction):
            Label(wifiAction.ssid, systemImage: "wifi")
                .font(.body.weight(.medium))
        case let .add_hyphen_contact(contactAction):
            Label(
                "\(contactAction.firstName) \(contactAction.lastName)",
                systemImage: "person.crop.circle.badge.plus"
            )
            .font(.body.weight(.medium))
        }
    }
}

// MARK: - Action Buttons Section View (Read-Only)

struct ActionButtonsSectionView: View {
    let viewModel: NoteEditorViewModel
    let onAddContact: (AddContactAction) -> Void
    @State private var wifiConnectionState: WiFiConnectionState = .idle

    var body: some View {
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
                .foregroundStyle(Color.appAccent)
            }
        case let .wifi(wifiAction):
            WiFiActionButton(wifiAction: wifiAction, connectionState: $wifiConnectionState)
        case let .add_hyphen_contact(contactAction):
            Button {
                onAddContact(contactAction)
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.body.weight(.medium))
                    VStack(alignment: .leading) {
                        Text("Add \(contactAction.firstName) \(contactAction.lastName)")
                            .font(.body.weight(.medium))
                        if let company = contactAction.company {
                            Text(company)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "plus.circle")
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
            .foregroundStyle(Color.appAccent)
            .accessibilityIdentifier("add-contact-button")
        }
    }
}
