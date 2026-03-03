//
//  AddContactViewControllerRepresentable.swift
//  RxNote
//
//  UIKit bridge for presenting pre-filled "new contact" UI on iOS.
//

import RxNoteCore
import SwiftUI

#if os(iOS)
import Contacts
import ContactsUI
import UIKit

struct AddContactViewControllerRepresentable: UIViewControllerRepresentable {
    let action: AddContactAction
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let contact = CNMutableContact()
        contact.givenName = action.firstName
        contact.familyName = action.lastName

        if let company = action.company {
            contact.organizationName = company
        }
        if let jobTitle = action.jobTitle {
            contact.jobTitle = jobTitle
        }
        if let emails = action.emails, !emails.isEmpty {
            contact.emailAddresses = emails.map { entry in
                CNLabeledValue(label: cnEmailLabel(for: entry._type), value: entry.value as NSString)
            }
        }
        if let phones = action.phones, !phones.isEmpty {
            contact.phoneNumbers = phones.map { entry in
                CNLabeledValue(
                    label: cnPhoneLabel(for: entry._type),
                    value: CNPhoneNumber(stringValue: entry.value)
                )
            }
        }
        if let website = action.website {
            contact.urlAddresses = [
                CNLabeledValue(label: CNLabelURLAddressHomePage, value: website as NSString),
            ]
        }
        if let address = action.address?.value1 {
            let postalAddress = CNMutablePostalAddress()
            if let street = address.street { postalAddress.street = street }
            if let city = address.city { postalAddress.city = city }
            if let state = address.state { postalAddress.state = state }
            if let zip = address.zip { postalAddress.postalCode = zip }
            if let country = address.country { postalAddress.country = country }
            contact.postalAddresses = [
                CNLabeledValue(label: CNLabelWork, value: postalAddress),
            ]
        }
        if let socialProfiles = action.socialProfiles, !socialProfiles.isEmpty {
            contact.socialProfiles = socialProfiles.map { entry in
                CNLabeledValue(label: nil, value: CNSocialProfile(
                    urlString: nil, username: entry.value,
                    userIdentifier: nil, service: entry.name
                ))
            }
        }
        if let im = action.instantMessaging, !im.isEmpty {
            contact.instantMessageAddresses = im.map { entry in
                CNLabeledValue(label: nil, value: CNInstantMessageAddress(
                    username: entry.value, service: entry.name
                ))
            }
        }

        let contactController = CNContactViewController(forNewContact: contact)
        contactController.delegate = context.coordinator

        return UINavigationController(rootViewController: contactController)
    }

    func updateUIViewController(_: UINavigationController, context _: Context) {}

    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        private let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func contactViewController(
            _: CNContactViewController,
            didCompleteWith _: CNContact?
        ) {
            onDismiss()
        }
    }
}

private func cnEmailLabel(for type: String) -> String {
    switch type {
    case "Work": return CNLabelWork
    case "Home", "Personal": return CNLabelHome
    case "School": return CNLabelSchool
    default: return CNLabelOther
    }
}

private func cnPhoneLabel(for type: String) -> String {
    switch type {
    case "Mobile": return CNLabelPhoneNumberMobile
    case "Home": return CNLabelHome
    case "Work": return CNLabelWork
    case "School": return CNLabelSchool
    case "Main": return CNLabelPhoneNumberMain
    case "Home Fax": return CNLabelPhoneNumberHomeFax
    case "Work Fax": return CNLabelPhoneNumberWorkFax
    case "Pager": return CNLabelPhoneNumberPager
    default: return CNLabelOther
    }
}
#endif
