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

    func testCreateAddContactAction() throws {
        let app = launchApp()
        try app.signInWithEmailAndPassword()

        XCTAssertTrue(app.addNoteButton.waitForExistence(timeout: 10), "Add note button should exist")
        app.addNoteButton.tap()

        XCTAssertTrue(app.noteTitleField.waitForExistence(timeout: 10), "Title field should exist")
        app.noteTitleField.tap()
        app.noteTitleField.typeText("Action Test Note")

        XCTAssertTrue(app.addActionButton.waitForExistence(timeout: 5), "Add action button should exist")
        app.addActionButton.tap()

        let addContactSegment = app.actionTypeAddContact.exists
            ? app.actionTypeAddContact
            : app.buttons["Add Contact"].firstMatch
        XCTAssertTrue(addContactSegment.waitForExistence(timeout: 5), "Add Contact option should exist")
        addContactSegment.tap()

        XCTAssertTrue(app.contactFirstNameField.waitForExistence(timeout: 5), "Contact first name field should exist")
        app.contactFirstNameField.tap()
        app.contactFirstNameField.typeText("Jane")

        XCTAssertTrue(app.contactLastNameField.waitForExistence(timeout: 5), "Contact last name field should exist")
        app.contactLastNameField.tap()
        app.contactLastNameField.typeText("Smith")

        app.buttons["Save"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Jane Smith"].firstMatch.waitForExistence(timeout: 5), "Saved add-contact action should appear")
    }
}
