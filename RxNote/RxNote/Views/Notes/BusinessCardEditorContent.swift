//
//  BusinessCardEditorContent.swift
//  RxNote
//
//  Editor content view for business card notes
//

import PhotosUI
import RxNoteCore
import SwiftUI

struct BusinessCardEditorContent: View {
    @Bindable var viewModel: NoteEditorViewModel
    @Binding var businessCardPhotoItem: PhotosPickerItem?
    let onShowCamera: () -> Void
    let onImageTapped: (String) -> Void
    let onActionEdit: (Int, NoteAction) -> Void
    let onAddContact: (AddContactAction) -> Void
    var onImportContact: (() -> Void)?

    var body: some View {
        if viewModel.isReadOnly {
            BusinessCardReadOnlyContent(
                viewModel: viewModel,
                onImageTapped: onImageTapped,
                onAddContact: onAddContact
            )
        } else {
            BusinessCardEditContent(
                viewModel: viewModel,
                businessCardPhotoItem: $businessCardPhotoItem,
                onShowCamera: onShowCamera,
                onImageTapped: onImageTapped,
                onActionEdit: onActionEdit,
                onImportContact: onImportContact
            )
        }
    }
}

// MARK: - Business Card Edit Content

struct BusinessCardEditContent: View {
    @Bindable var viewModel: NoteEditorViewModel
    @Binding var businessCardPhotoItem: PhotosPickerItem?
    let onShowCamera: () -> Void
    let onImageTapped: (String) -> Void
    let onActionEdit: (Int, NoteAction) -> Void
    var onImportContact: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            // Profile Photo
            BusinessCardProfilePhotoEdit(
                viewModel: viewModel,
                businessCardPhotoItem: $businessCardPhotoItem,
                onShowCamera: onShowCamera,
                onImportContact: onImportContact
            )
            .frame(maxWidth: .infinity)

            // Form fields
            BusinessCardForm(viewModel: viewModel)
                .padding(.horizontal, 16)

            // Actions section (edit mode - inline with edit/delete)
            if !viewModel.actions.isEmpty {
                ActionsSectionView(
                    viewModel: viewModel,
                    onActionEdit: onActionEdit
                )
            }

            // Location
            if viewModel.latitude != nil {
                MediaSectionView(
                    viewModel: viewModel,
                    onImageTapped: onImageTapped
                )
            }
        }
    }
}

// MARK: - Business Card Read-Only Content

struct BusinessCardReadOnlyContent: View {
    let viewModel: NoteEditorViewModel
    let onImageTapped: (String) -> Void
    let onAddContact: (AddContactAction) -> Void

    private var addContactAction: AddContactAction {
        let emails = viewModel.businessCardEmails
            .filter { !$0.type.isEmpty && !$0.value.isEmpty }
            .map { TypedValue(_type: $0.type, value: $0.value) }
        let phones = viewModel.businessCardPhones
            .filter { !$0.type.isEmpty && !$0.value.isEmpty }
            .map { TypedValue(_type: $0.type, value: $0.value) }
        let addressPayload: AddContactAction.addressPayload?
        if !viewModel.businessCardAddress.isEmpty {
            addressPayload = .init(value1: BusinessCardAddress(
                street: viewModel.businessCardAddress.street.isEmpty ? nil : viewModel.businessCardAddress.street,
                city: viewModel.businessCardAddress.city.isEmpty ? nil : viewModel.businessCardAddress.city,
                state: viewModel.businessCardAddress.state.isEmpty ? nil : viewModel.businessCardAddress.state,
                zip: viewModel.businessCardAddress.zip.isEmpty ? nil : viewModel.businessCardAddress.zip,
                country: viewModel.businessCardAddress.country.isEmpty ? nil : viewModel.businessCardAddress.country
            ))
        } else {
            addressPayload = nil
        }
        let socialProfiles = viewModel.businessCardSocialProfiles
            .filter { !$0.name.isEmpty && !$0.value.isEmpty }
            .map { NameValue(name: $0.name, value: $0.value) }
        let instantMessaging = viewModel.businessCardInstantMessaging
            .filter { !$0.name.isEmpty && !$0.value.isEmpty }
            .map { NameValue(name: $0.name, value: $0.value) }
        let wallets = viewModel.businessCardWallets
            .filter { !$0.name.isEmpty && !$0.value.isEmpty }
            .map { NameValue(name: $0.name, value: $0.value) }

        return AddContactAction(
            _type: .add_hyphen_contact,
            firstName: viewModel.businessCardFirstName,
            lastName: viewModel.businessCardLastName,
            emails: emails.isEmpty ? nil : emails,
            phones: phones.isEmpty ? nil : phones,
            company: viewModel.businessCardCompany.isEmpty ? nil : viewModel.businessCardCompany,
            jobTitle: viewModel.businessCardJobTitle.isEmpty ? nil : viewModel.businessCardJobTitle,
            website: viewModel.businessCardWebsite.isEmpty ? nil : viewModel.businessCardWebsite,
            address: addressPayload,
            socialProfiles: socialProfiles.isEmpty ? nil : socialProfiles,
            instantMessaging: instantMessaging.isEmpty ? nil : instantMessaging,
            wallets: wallets.isEmpty ? nil : wallets
        )
    }

    var body: some View {
        VStack(spacing: 24) {
            // Hero section
            VStack(spacing: 12) {
                BusinessCardProfilePhotoReadOnly(viewModel: viewModel)

                Text("\(viewModel.businessCardFirstName) \(viewModel.businessCardLastName)")
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("note-detail-title")

                if !viewModel.businessCardJobTitle.isEmpty || !viewModel.businessCardCompany.isEmpty {
                    Text([viewModel.businessCardJobTitle, viewModel.businessCardCompany]
                        .filter { !$0.isEmpty }
                        .joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Add to Contacts button
                Button {
                    onAddContact(addContactAction)
                } label: {
                    Label("Add to Contacts", systemImage: "person.crop.circle.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccent)
                .padding(.horizontal)
                .padding(.top, 8)
                .accessibilityIdentifier("business-card-add-contact-button")
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)

            // Contact details card
            BusinessCardContactRows(viewModel: viewModel)
                .padding(.horizontal, 16)

            // Location
            if viewModel.latitude != nil {
                MediaSectionView(
                    viewModel: viewModel,
                    onImageTapped: onImageTapped
                )
            }

            // Action buttons (read-only mode)
            if !viewModel.actions.isEmpty {
                ActionButtonsSectionView(
                    viewModel: viewModel,
                    onAddContact: onAddContact
                )
            }
        }
    }
}

// MARK: - Business Card Profile Photo Edit

struct BusinessCardProfilePhotoEdit: View {
    @Bindable var viewModel: NoteEditorViewModel
    @Binding var businessCardPhotoItem: PhotosPickerItem?
    let onShowCamera: () -> Void
    var onImportContact: (() -> Void)?

    var body: some View {
        Menu {
            #if os(iOS)
            if let onImportContact {
                Button {
                    onImportContact()
                } label: {
                    Label("Import from Contacts", systemImage: "person.crop.circle")
                }
            }
            #endif
            PhotosPicker(selection: $businessCardPhotoItem, matching: .images) {
                Label("Choose Photo", systemImage: "photo")
            }
            #if os(iOS)
                Button {
                    onShowCamera()
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }
            #endif
            if viewModel.businessCardImageUrl != nil || viewModel.businessCardPendingImageUpload != nil {
                Button(role: .destructive) {
                    viewModel.removeBusinessCardImage()
                } label: {
                    Label("Remove Photo", systemImage: "trash")
                }
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                BusinessCardProfileCircle(
                    viewModel: viewModel,
                    size: 96
                )

                Image(systemName: "camera.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.appAccent)
            }
        }
        .accessibilityIdentifier("business-card-profile-photo")
    }
}

// MARK: - Business Card Profile Photo Read-Only

struct BusinessCardProfilePhotoReadOnly: View {
    let viewModel: NoteEditorViewModel

    var body: some View {
        BusinessCardProfileCircle(viewModel: viewModel, size: 120)
    }
}

// MARK: - Business Card Profile Circle

struct BusinessCardProfileCircle: View {
    let viewModel: NoteEditorViewModel
    let size: CGFloat

    var body: some View {
        let imageUrl = viewModel.businessCardPendingImageUpload?.publicUrl ?? viewModel.businessCardImageUrl
        if let imageUrl, let url = URL(string: imageUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProfilePlaceholder(
                        firstName: viewModel.businessCardFirstName,
                        lastName: viewModel.businessCardLastName,
                        size: size
                    )
                    .overlay { ProgressView() }
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                case .failure:
                    ProfilePlaceholder(
                        firstName: viewModel.businessCardFirstName,
                        lastName: viewModel.businessCardLastName,
                        size: size
                    )
                @unknown default:
                    ProfilePlaceholder(
                        firstName: viewModel.businessCardFirstName,
                        lastName: viewModel.businessCardLastName,
                        size: size
                    )
                }
            }
        } else {
            ProfilePlaceholder(
                firstName: viewModel.businessCardFirstName,
                lastName: viewModel.businessCardLastName,
                size: size
            )
        }
    }
}

// MARK: - Profile Placeholder

struct ProfilePlaceholder: View {
    let firstName: String
    let lastName: String
    let size: CGFloat

    private var initials: String {
        String(firstName.prefix(1) + lastName.prefix(1)).uppercased()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.appAccent.opacity(0.15))
                .frame(width: size, height: size)
            if !initials.isEmpty && initials != " " {
                Text(initials)
                    .font(size >= 100 ? .largeTitle.weight(.semibold) : .title2.weight(.semibold))
                    .foregroundStyle(Color.appAccent)
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(Color.appAccent.opacity(0.5))
            }
        }
    }
}

// MARK: - Business Card Contact Rows (Read-Only, Tappable)

struct BusinessCardContactRows: View {
    let viewModel: NoteEditorViewModel

    private struct ContactRow: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let value: String
        let urlString: String?
    }

    private var rows: [ContactRow] {
        var result: [ContactRow] = []

        for entry in viewModel.businessCardEmails where !entry.value.isEmpty {
            result.append(ContactRow(icon: "envelope", label: entry.type, value: entry.value, urlString: "mailto:\(entry.value)"))
        }
        for entry in viewModel.businessCardPhones where !entry.value.isEmpty {
            result.append(ContactRow(icon: "phone", label: entry.type, value: entry.value, urlString: "tel:\(entry.value)"))
        }
        if !viewModel.businessCardWebsite.isEmpty {
            let url = viewModel.businessCardWebsite.hasPrefix("http") ? viewModel.businessCardWebsite : "https://\(viewModel.businessCardWebsite)"
            result.append(ContactRow(icon: "globe", label: "Website", value: viewModel.businessCardWebsite, urlString: url))
        }
        if !viewModel.businessCardAddress.isEmpty {
            let addressText = [viewModel.businessCardAddress.street, viewModel.businessCardAddress.city, viewModel.businessCardAddress.state, viewModel.businessCardAddress.zip, viewModel.businessCardAddress.country]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
            let encoded = addressText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? addressText
            result.append(ContactRow(icon: "mappin.and.ellipse", label: "Address", value: addressText, urlString: "http://maps.apple.com/?q=\(encoded)"))
        }
        for entry in viewModel.businessCardSocialProfiles where !entry.value.isEmpty {
            result.append(ContactRow(icon: "at", label: entry.name, value: entry.value, urlString: nil))
        }
        for entry in viewModel.businessCardInstantMessaging where !entry.value.isEmpty {
            result.append(ContactRow(icon: "message", label: entry.name, value: entry.value, urlString: nil))
        }
        for entry in viewModel.businessCardWallets where !entry.value.isEmpty {
            let truncated = entry.value.count > 14
                ? "\(entry.value.prefix(6))...\(entry.value.suffix(4))"
                : entry.value
            result.append(ContactRow(icon: "wallet.bifold", label: entry.name.isEmpty ? "Wallet" : entry.name, value: truncated, urlString: walletURI(network: entry.name, address: entry.value)))
        }

        return result
    }

    var body: some View {
        if !rows.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if let urlString = row.urlString {
                        Button {
                            openURL(urlString)
                        } label: {
                            contactRowContent(row: row, showChevron: true)
                        }
                        .buttonStyle(.plain)
                    } else {
                        contactRowContent(row: row, showChevron: false)
                    }

                    if index < rows.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            #if os(iOS)
            .background(Color(.secondarySystemBackground))
            #else
            .background(Color(NSColor.controlBackgroundColor))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func contactRowContent(row: ContactRow, showChevron: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: row.icon)
                .font(.body)
                .foregroundStyle(Color.appAccent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(row.value)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        #if os(iOS)
            UIApplication.shared.open(url)
        #else
            NSWorkspace.shared.open(url)
        #endif
    }

    private func walletURI(network: String, address: String) -> String? {
        let n = network.lowercased()
        if ["ethereum", "polygon", "base", "arbitrum"].contains(n) {
            return "ethereum:\(address)"
        }
        if n == "bitcoin" { return "bitcoin:\(address)" }
        if n == "solana" { return "solana:\(address)" }
        if n == "tron" { return "tron:\(address)" }
        if n == "ton" { return "ton://transfer/\(address)" }
        return nil
    }
}

// MARK: - Business Card Edit Form

struct BusinessCardForm: View {
    @Bindable var viewModel: NoteEditorViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Name section
            FormSection {
                FormRow {
                    HStack {
                        TextField("First Name", text: $viewModel.businessCardFirstName)
                            .accessibilityIdentifier("business-card-first-name")
                        Divider()
                            .frame(height: 20)
                        TextField("Last Name", text: $viewModel.businessCardLastName)
                            .accessibilityIdentifier("business-card-last-name")
                    }
                }

                FormRow {
                    TextField("Company", text: $viewModel.businessCardCompany)
                        .accessibilityIdentifier("business-card-company")
                }

                FormRow(showDivider: false) {
                    TextField("Job Title", text: $viewModel.businessCardJobTitle)
                        .accessibilityIdentifier("business-card-job-title")
                }
            }

            // Emails section
            TypedValueSection(
                title: "Email",
                entries: $viewModel.businessCardEmails,
                valuePlaceholder: "Email",
                variant: .email,
                defaultType: "Work",
                accessibilityPrefix: "business-card-email"
            )

            // Phones section
            TypedValueSection(
                title: "Phone",
                entries: $viewModel.businessCardPhones,
                valuePlaceholder: "Phone",
                variant: .phone,
                defaultType: "Mobile",
                accessibilityPrefix: "business-card-phone"
            )

            // Website
            FormSection {
                FormRow(showDivider: false) {
                    TextField("Website", text: $viewModel.businessCardWebsite)
#if os(iOS)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
#endif
                        .accessibilityIdentifier("business-card-website")
                }
            }

            // Address section
            FormSection {
                FormRow {
                    TextField("Street", text: $viewModel.businessCardAddress.street)
#if os(iOS)
                        .textContentType(.streetAddressLine1)
#endif
                        .accessibilityIdentifier("business-card-address-street")
                }

                FormRow {
                    TextField("City", text: $viewModel.businessCardAddress.city)
#if os(iOS)
                        .textContentType(.addressCity)
#endif
                        .accessibilityIdentifier("business-card-address-city")
                }

                FormRow {
                    TextField("State / Province", text: $viewModel.businessCardAddress.state)
#if os(iOS)
                        .textContentType(.addressState)
#endif
                        .accessibilityIdentifier("business-card-address-state")
                }

                FormRow {
                    TextField("Zip / Postal Code", text: $viewModel.businessCardAddress.zip)
#if os(iOS)
                        .textContentType(.postalCode)
#endif
                        .accessibilityIdentifier("business-card-address-zip")
                }

                FormRow(showDivider: false) {
                    TextField("Country", text: $viewModel.businessCardAddress.country)
#if os(iOS)
                        .textContentType(.countryName)
#endif
                        .accessibilityIdentifier("business-card-address-country")
                }
            }

            // Social Profiles section
            NameValueSection(
                title: "Social Profile",
                entries: $viewModel.businessCardSocialProfiles,
                namePlaceholder: "Platform",
                valuePlaceholder: "Username",
                presetCategory: .socialProfile,
                accessibilityPrefix: "business-card-social"
            )

            // Instant Messaging section
            NameValueSection(
                title: "Instant Messaging",
                entries: $viewModel.businessCardInstantMessaging,
                namePlaceholder: "Service",
                valuePlaceholder: "Username",
                presetCategory: .instantMessaging,
                accessibilityPrefix: "business-card-im"
            )

            // Wallets section
            NameValueSection(
                title: "Wallet",
                entries: $viewModel.businessCardWallets,
                namePlaceholder: "Network",
                valuePlaceholder: "Address",
                presetCategory: .walletNetwork,
                accessibilityPrefix: "business-card-wallet"
            )
        }
    }
}

// MARK: - Typed Value Section (Emails, Phones)

private enum TypedValueVariant {
    case email
    case phone
}

private struct TypedValueSection: View {
    let title: String
    @Binding var entries: [TypedValueEntry]
    let valuePlaceholder: String
    let variant: TypedValueVariant
    let defaultType: String
    let accessibilityPrefix: String

    var body: some View {
        FormSection {
            ForEach($entries) { $entry in
                FormRow {
                    HStack(spacing: 8) {
                        TextField("Type", text: $entry.type)
                            .frame(width: 80)
                            .foregroundStyle(Color.appAccent)
                            .accessibilityIdentifier("\(accessibilityPrefix)-type")

                        Divider()
                            .frame(height: 20)

                        TextField(valuePlaceholder, text: $entry.value)
#if os(iOS)
                            .keyboardType(variant == .email ? .emailAddress : .phonePad)
                            .textContentType(variant == .email ? .emailAddress : .telephoneNumber)
                            .textInputAutocapitalization(.never)
#endif
                            .accessibilityIdentifier("\(accessibilityPrefix)-value")

                        Button {
                            entries.removeAll { $0.id == entry.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                entries.append(TypedValueEntry(type: defaultType))
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.green)
                    Text("Add \(title)")
                        .foregroundStyle(Color.appAccent)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("\(accessibilityPrefix)-add")
        }
    }
}

// MARK: - Name Value Section (Social Profiles, IM)

private struct NameValueSection: View {
    let title: String
    @Binding var entries: [NameValueEntry]
    let namePlaceholder: String
    let valuePlaceholder: String
    var presetCategory: PresetCategory?
    let accessibilityPrefix: String

    @State private var pickerTargetEntryId: UUID?
    @State private var showAddPicker = false
    @State private var showEditPicker = false

    var body: some View {
        FormSection {
            ForEach($entries) { $entry in
                FormRow {
                    HStack(spacing: 8) {
                        if presetCategory != nil {
                            Button {
                                pickerTargetEntryId = entry.id
                                showEditPicker = true
                            } label: {
                                Text(entry.name.isEmpty ? namePlaceholder : entry.name)
                                    .foregroundStyle(entry.name.isEmpty ? Color.appAccent.opacity(0.5) : Color.appAccent)
                                    .frame(width: 100, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("\(accessibilityPrefix)-name")
                        } else {
                            TextField(namePlaceholder, text: $entry.name)
                                .frame(width: 100)
                                .foregroundStyle(Color.appAccent)
                                .accessibilityIdentifier("\(accessibilityPrefix)-name")
                        }

                        Divider()
                            .frame(height: 20)

                        TextField(valuePlaceholder, text: $entry.value)
#if os(iOS)
                            .textInputAutocapitalization(.never)
#endif
                            .accessibilityIdentifier("\(accessibilityPrefix)-value")

                        Button {
                            entries.removeAll { $0.id == entry.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                if presetCategory != nil {
                    showAddPicker = true
                } else {
                    entries.append(NameValueEntry())
                }
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.green)
                    Text("Add \(title)")
                        .foregroundStyle(Color.appAccent)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("\(accessibilityPrefix)-add")
        }
        .sheet(isPresented: $showAddPicker) {
            if let category = presetCategory {
                PresetPickerSheet(category: category) { selected in
                    entries.append(NameValueEntry(name: selected))
                }
            }
        }
        .sheet(isPresented: $showEditPicker) {
            if let category = presetCategory, let targetId = pickerTargetEntryId {
                PresetPickerSheet(category: category) { selected in
                    if let index = entries.firstIndex(where: { $0.id == targetId }) {
                        entries[index].name = selected
                    }
                }
            }
        }
    }
}

// MARK: - Form Section

private struct FormSection<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
#if os(iOS)
        .background(Color(.secondarySystemBackground))
#else
        .background(Color(NSColor.controlBackgroundColor))
#endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Form Row

private struct FormRow<Content: View>: View {
    var showDivider: Bool = true
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            if showDivider {
                Divider()
                    .padding(.leading, 16)
            }
        }
    }
}

// MARK: - Preview

#Preview("BusinessCardForm") {
    @Previewable @State var viewModel = NoteEditorViewModel()

    NavigationStack {
        BusinessCardForm(viewModel: viewModel)
    }
}
