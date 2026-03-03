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

struct ContactPickerViewControllerRepresentable: UIViewControllerRepresentable {
    let onContactSelected: (CNContact) -> Void
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onContactSelected: onContactSelected, onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        
        // Wrap in a container to prevent the picker from dismissing the parent sheet
        let container = ContactPickerContainerViewController()
        container.contactPicker = picker
        return container
    }

    func updateUIViewController(_: UIViewController, context _: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        private let onContactSelected: (CNContact) -> Void
        private let onDismiss: () -> Void

        init(onContactSelected: @escaping (CNContact) -> Void, onDismiss: @escaping () -> Void) {
            self.onContactSelected = onContactSelected
            self.onDismiss = onDismiss
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onContactSelected(contact)
            onDismiss()
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onDismiss()
        }
    }
}

/// Container view controller that presents the contact picker modally
/// to prevent it from dismissing the parent SwiftUI sheet.
private class ContactPickerContainerViewController: UIViewController {
    var contactPicker: CNContactPickerViewController?
    private var hasPresented = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard !hasPresented, let picker = contactPicker else { return }
        hasPresented = true
        present(picker, animated: true)
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
