//
//  ContactPickerViewControllerRepresentable.swift
//  RxNote
//
//  UIKit bridge for presenting the system contact picker on iOS.
//

import SwiftUI

#if os(iOS)
import Contacts
import ContactsUI

/// A view modifier that presents a CNContactPickerViewController from the root window.
/// This avoids the issue where CNContactPickerViewController dismisses its presenting
/// view controller chain, which would close any parent sheets.
struct ContactPickerModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onContactSelected: (CNContact) -> Void
    
    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, newValue in
                if newValue {
                    presentContactPicker()
                }
            }
    }
    
    private func presentContactPicker() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            isPresented = false
            return
        }
        
        // Find the topmost presented view controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        let picker = CNContactPickerViewController()
        let coordinator = ContactPickerCoordinator(
            onContactSelected: { contact in
                onContactSelected(contact)
                isPresented = false
            },
            onCancel: {
                isPresented = false
            }
        )
        
        // Store coordinator to keep it alive
        objc_setAssociatedObject(picker, &AssociatedKeys.coordinator, coordinator, .OBJC_ASSOCIATION_RETAIN)
        picker.delegate = coordinator
        
        topController.present(picker, animated: true)
    }
}

private struct AssociatedKeys {
    static var coordinator = "contactPickerCoordinator"
}

private final class ContactPickerCoordinator: NSObject, CNContactPickerDelegate {
    let onContactSelected: (CNContact) -> Void
    let onCancel: () -> Void
    
    init(onContactSelected: @escaping (CNContact) -> Void, onCancel: @escaping () -> Void) {
        self.onContactSelected = onContactSelected
        self.onCancel = onCancel
    }
    
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        onContactSelected(contact)
    }
    
    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        onCancel()
    }
}

extension View {
    func contactPicker(isPresented: Binding<Bool>, onContactSelected: @escaping (CNContact) -> Void) -> some View {
        modifier(ContactPickerModifier(isPresented: isPresented, onContactSelected: onContactSelected))
    }
}

// MARK: - CNContact Label Helpers

/// Reverse-maps CNLabel constants to user-friendly type strings for emails.
func emailTypeFromCNLabel(_ label: String?) -> String {
    switch label {
    case CNLabelWork: return "Work"
    case CNLabelHome: return "Home"
    case CNLabelSchool: return "School"
    default: return "Other"
    }
}

/// Reverse-maps CNLabel constants to user-friendly type strings for phones.
func phoneTypeFromCNLabel(_ label: String?) -> String {
    switch label {
    case CNLabelPhoneNumberMobile: return "Mobile"
    case CNLabelHome: return "Home"
    case CNLabelWork: return "Work"
    case CNLabelSchool: return "School"
    case CNLabelPhoneNumberMain: return "Main"
    case CNLabelPhoneNumberHomeFax: return "Home Fax"
    case CNLabelPhoneNumberWorkFax: return "Work Fax"
    case CNLabelPhoneNumberPager: return "Pager"
    default: return "Other"
    }
}
#endif
