//
//  accessibility.swift
//  RxNoteUITests
//
//  Accessibility identifier helpers for UI tests
//

import XCTest

extension XCUIApplication {
    // MARK: - Tabs

    var tabNotes: XCUIElement {
        tabBars.buttons["tab-notes"].firstMatch
    }

    var tabSettings: XCUIElement {
        tabBars.buttons["tab-settings"].firstMatch
    }

    // MARK: - Note List

    var addNoteButton: XCUIElement {
        buttons["add-note-button"].firstMatch
    }

    func noteRow(id: Int) -> XCUIElement {
        // NavigationLink is not exposed as a button, use descendants to find by identifier
        descendants(matching: .any).matching(identifier: "note-row-\(id)").firstMatch
    }

    // MARK: - Note Editor

    var noteTitleField: XCUIElement {
        textFields["note-title-field"].firstMatch
    }

    var noteContentField: XCUIElement {
        textViews["note-content-field"].firstMatch
    }

    var noteSaveButton: XCUIElement {
        buttons["note-save-button"].firstMatch
    }

    var addActionButton: XCUIElement {
        buttons["add-action-button"].firstMatch
    }

    var noteTypePicker: XCUIElement {
        buttons["note-type-picker"].firstMatch
    }

    var businessCardFirstNameField: XCUIElement {
        textFields["business-card-first-name"].firstMatch
    }

    var businessCardLastNameField: XCUIElement {
        textFields["business-card-last-name"].firstMatch
    }

    var businessCardEmailField: XCUIElement {
        textFields["business-card-email"].firstMatch
    }

    var businessCardPhoneField: XCUIElement {
        textFields["business-card-phone"].firstMatch
    }

    var businessCardCompanyField: XCUIElement {
        textFields["business-card-company"].firstMatch
    }

    var businessCardJobTitleField: XCUIElement {
        textFields["business-card-job-title"].firstMatch
    }

    var businessCardWebsiteField: XCUIElement {
        textFields["business-card-website"].firstMatch
    }

    var businessCardAddressField: XCUIElement {
        textFields["business-card-address"].firstMatch
    }

    var businessCardProfilePhoto: XCUIElement {
        buttons["business-card-profile-photo"].firstMatch
    }

    var actionTypeAddContact: XCUIElement {
        buttons["action-type-add-contact"].firstMatch
    }

    var contactFirstNameField: XCUIElement {
        textFields["contact-first-name"].firstMatch
    }

    var contactLastNameField: XCUIElement {
        textFields["contact-last-name"].firstMatch
    }

    var addContactButton: XCUIElement {
        buttons["add-contact-button"].firstMatch
    }

    // MARK: - Note Detail

    var noteDetailTitle: XCUIElement {
        staticTexts["note-detail-title"].firstMatch
    }

    var noteDetailEditButton: XCUIElement {
        buttons["note-detail-edit-button"].firstMatch
    }

    // MARK: - Deep Link

    var deepLinkErrorOkButton: XCUIElement {
        buttons["deep-link-error-ok-button"].firstMatch
    }

    var deepLinkErrorMessage: XCUIElement {
        staticTexts["deep-link-error-message"].firstMatch
    }

    // MARK: - QR Code

    var qrScannerButton: XCUIElement {
        buttons["qr-scanner-button"].firstMatch
    }

    // MARK: - App Clips

    var appClipsSignInRequired: XCUIElement {
        staticTexts["Sign In Required"].firstMatch
    }

    var appClipsAccessDenined: XCUIElement {
        staticTexts["app-clips-access-denied"].firstMatch
    }

    var appClipsMoreMenu: XCUIElement {
        buttons["app-clips-more-menu"].firstMatch
    }

    var appClipsSignOutButton: XCUIElement {
        buttons["app-clips-sign-out-button"].firstMatch
    }

    var appClipsInvalidUrl: XCUIElement {
        otherElements["invalid-url"].firstMatch
    }
}
