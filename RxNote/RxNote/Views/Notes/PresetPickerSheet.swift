//
//  PresetPickerSheet.swift
//  RxNote
//
//  Picker sheet for selecting preset or custom labels for social profiles / IM
//

import RxNoteCore
import SwiftData
import SwiftUI

// MARK: - Preset Category

enum PresetCategory {
    case socialProfile
    case instantMessaging
    case walletNetwork

    var title: String {
        switch self {
        case .socialProfile: "Social Profile"
        case .instantMessaging: "Instant Messaging"
        case .walletNetwork: "Wallet Network"
        }
    }

    var swiftDataCategory: String {
        switch self {
        case .socialProfile: "socialProfile"
        case .instantMessaging: "instantMessaging"
        case .walletNetwork: "walletNetwork"
        }
    }

    func presets(from response: BusinessCardPresets) -> [String] {
        switch self {
        case .socialProfile: response.socialProfiles
        case .instantMessaging: response.instantMessaging
        case .walletNetwork: response.walletNetworks
        }
    }
}

// MARK: - Preset Picker Sheet

struct PresetPickerSheet: View {
    let category: PresetCategory
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var customLabels: [CustomPresetLabel]
    @State private var apiPresets: [String] = []
    @State private var isLoading = true
    @State private var showCustomForm = false

    init(category: PresetCategory, onSelect: @escaping (String) -> Void) {
        self.category = category
        self.onSelect = onSelect
        let cat = category.swiftDataCategory
        _customLabels = Query(
            filter: #Predicate<CustomPresetLabel> { $0.category == cat },
            sort: \CustomPresetLabel.createdAt
        )
    }

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    Section {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else {
                    if !apiPresets.isEmpty {
                        Section {
                            ForEach(apiPresets, id: \.self) { preset in
                                Button {
                                    onSelect(preset)
                                    dismiss()
                                } label: {
                                    Text(preset)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }

                    if !customLabels.isEmpty {
                        Section("Custom") {
                            ForEach(customLabels) { label in
                                Button {
                                    onSelect(label.label)
                                    dismiss()
                                } label: {
                                    Text(label.label)
                                        .foregroundStyle(.primary)
                                }
                            }
                            .onDelete(perform: deleteCustomLabels)
                        }
                    }
                }

                Section {
                    Button {
                        showCustomForm = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                            Text("Add Custom Label")
                        }
                    }
                }
            }
            .navigationTitle("Add \(category.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showCustomForm) {
                CustomLabelFormView(category: category) { label in
                    onSelect(label)
                    dismiss()
                }
            }
            .task {
                await loadPresets()
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func loadPresets() async {
        do {
            let presets = try await PresetService().getBusinessCardPresets()
            apiPresets = category.presets(from: presets)
        } catch {
            apiPresets = []
        }
        isLoading = false
    }

    private func deleteCustomLabels(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(customLabels[index])
        }
    }
}

// MARK: - Custom Label Form

struct CustomLabelFormView: View {
    let category: PresetCategory
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var labelText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        Form {
            Section {
                TextField("Label name", text: $labelText)
                    .focused($isFocused)
#if os(iOS)
                    .textInputAutocapitalization(.words)
#endif
            }
        }
        .navigationTitle("Custom Label")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let trimmed = labelText.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    let customLabel = CustomPresetLabel(
                        category: category.swiftDataCategory,
                        label: trimmed
                    )
                    modelContext.insert(customLabel)
                    onSave(trimmed)
                }
                .disabled(labelText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}
