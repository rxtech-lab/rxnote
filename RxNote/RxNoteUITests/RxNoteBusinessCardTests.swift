//
//  RxNoteBusinessCardTests.swift
//  RxNoteUITests
//
//  UI tests for business card note type and add-contact action.
//

import XCTest

final class RxNoteBusinessCardTests: XCTestCase {
    func testNoteTypePickerIsVisible() throws {
        let app = launchApp()
        try app.signInWithEmailAndPassword()

        XCTAssertTrue(app.addNoteButton.waitForExistence(timeout: 10), "Add note button should exist")
        app.addNoteButton.tap()

        XCTAssertTrue(app.noteTypePicker.waitForExistence(timeout: 10), "Note type picker menu should exist")
        app.noteTypePicker.tap()
        XCTAssertTrue(app.buttons["Text Note"].firstMatch.waitForExistence(timeout: 5), "Text Note option should be visible")
        XCTAssertTrue(app.buttons["Business Card"].firstMatch.exists, "Business Card option should be visible")
    }

    func testCreateBusinessCardNote() throws {
        let app = launchApp()
        try app.signInWithEmailAndPassword()

        XCTAssertTrue(app.addNoteButton.waitForExistence(timeout: 10), "Add note button should exist")
        app.addNoteButton.tap()

        XCTAssertTrue(app.noteTypePicker.waitForExistence(timeout: 10), "Note type picker menu should exist")
        app.noteTypePicker.tap()
        app.buttons["Business Card"].firstMatch.tap()

        // Business card mode: no title field, just first/last name
        XCTAssertTrue(app.businessCardFirstNameField.waitForExistence(timeout: 10), "Business card first name field should exist")
        app.businessCardFirstNameField.tap()
        app.businessCardFirstNameField.typeText("John")

        XCTAssertTrue(app.businessCardLastNameField.waitForExistence(timeout: 5), "Business card last name field should exist")
        app.businessCardLastNameField.tap()
        app.businessCardLastNameField.typeText("Doe")

        XCTAssertTrue(app.noteSaveButton.waitForExistence(timeout: 5), "Save button should exist")
        app.noteSaveButton.tap()

        // Title is auto-generated from first + last name
        XCTAssertTrue(app.staticTexts["John Doe"].firstMatch.waitForExistence(timeout: 15), "Created business card note should appear with auto-generated title")
    }

    func testImportContactFromContactsAndSave() throws {
        let app = launchApp()
        try app.signInWithEmailAndPassword()

        XCTAssertTrue(app.addNoteButton.waitForExistence(timeout: 10), "Add note button should exist")
        app.addNoteButton.tap()

        // Switch to Business Card type
        XCTAssertTrue(app.noteTypePicker.waitForExistence(timeout: 10), "Note type picker menu should exist")
        app.noteTypePicker.tap()
        app.buttons["Business Card"].firstMatch.tap()

        // Tap on the profile photo to open the menu
        XCTAssertTrue(app.businessCardFirstNameField.waitForExistence(timeout: 10), "Business card first name field should exist")
        XCTAssertTrue(app.businessCardProfilePhoto.waitForExistence(timeout: 10), "Business card profile photo should exist")
        app.businessCardProfilePhoto.tap()

        // Tap "Import from Contacts" menu option
        let importButton = app.buttons["Import from Contacts"].firstMatch
        XCTAssertTrue(importButton.waitForExistence(timeout: 5), "Import from Contacts option should be visible")
        importButton.tap()

        // Wait for the contact picker to appear (system CNContactPickerViewController)
        // The picker is presented modally, so we need to wait for it to fully appear
        sleep(1)

        // The contact picker cells are in a table view - tap the first available contact
        // Use coordinate-based tap since system picker cells may not be directly hittable

        let contactsViewServiceApp = XCUIApplication(bundleIdentifier: "com.apple.ContactsUI.ContactsViewService")
        contactsViewServiceApp/*@START_MENU_TOKEN@*/ .cells["John Appleseed"]/*[[".cells",".containing(.staticText, identifier: \"John Appleseed\")",".containing(.button, identifier: \"Contact photo for John Appleseed\")",".collectionViews.cells[\"John Appleseed\"]",".cells[\"John Appleseed\"]"],[[[-1,4],[-1,3],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .firstMatch.tap()

        // After selecting a contact, the fields should be populated
        // Wait for the first name field to be visible again (picker dismisses)
        XCTAssertTrue(app.businessCardFirstNameField.waitForExistence(timeout: 10), "First name field should exist after import")

        // Save the imported contact as a business card note
        XCTAssertTrue(app.noteSaveButton.waitForExistence(timeout: 5), "Save button should exist")
        app.noteSaveButton.tap()

        // Verify the note was created - we should return to the note list
        XCTAssertTrue(app.staticTexts["John Appleseed"].firstMatch.waitForExistence(timeout: 15), "Created business card note should appear with contact's name as title")
    }
    
    
}
