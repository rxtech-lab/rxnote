//
//  RxNoteNoteCrudTests.swift
//  RxNoteUITests
//
//  UI tests for note CRUD operations
//

import XCTest

final class RxNoteNoteCrudTests: XCTestCase {
    // MARK: - Create Note

    func testCreateNote() throws {
        let app = launchApp()
        try app.signInWithEmailAndPassword()

        // Tap add note button
        XCTAssertTrue(app.addNoteButton.waitForExistence(timeout: 10), "Add note button should exist")
        app.addNoteButton.tap()

        // Fill in title
        XCTAssertTrue(app.noteTitleField.waitForExistence(timeout: 10), "Title field should exist")
        app.noteTitleField.tap()
        app.noteTitleField.typeText("UI Test Note")

        // Fill in content
        XCTAssertTrue(app.noteContentField.waitForExistence(timeout: 5), "Content field should exist")
        app.noteContentField.tap()
        app.noteContentField.typeText("This is a test note created by UI tests")

        // Tap save
        XCTAssertTrue(app.noteSaveButton.waitForExistence(timeout: 5), "Save button should exist")
        app.noteSaveButton.tap()

        // Verify we return to the list and the note appears
        let noteTitle = app.staticTexts["UI Test Note"].firstMatch
        XCTAssertTrue(noteTitle.waitForExistence(timeout: 15), "Created note should appear in the list")
    }

    // MARK: - View Note Detail

    func testViewNoteDetail() throws {
        let app = launchApp()
        try app.signInWithEmailAndPassword()

        // Wait for notes list to load
        let noteText = app.staticTexts["Private Test Note"].firstMatch
        XCTAssertTrue(noteText.waitForExistence(timeout: 15), "Private Test Note should appear in the list")

        // Tap on the note row (tap the static text which is inside the row)
        noteText.tap()

        // Verify detail view shows the title
        XCTAssertTrue(app.noteDetailTitle.waitForExistence(timeout: 10), "Note detail title should exist")
        XCTAssertEqual(app.noteDetailTitle.label, "Private Test Note")
    }

    // MARK: - Edit Note

    func testEditNote() throws {
        let app = launchApp()
        try app.signInWithEmailAndPassword()

        // First create a note to edit
        XCTAssertTrue(app.addNoteButton.waitForExistence(timeout: 10), "Add note button should exist")
        app.addNoteButton.tap()

        XCTAssertTrue(app.noteTitleField.waitForExistence(timeout: 10), "Title field should exist")
        app.noteTitleField.tap()
        app.noteTitleField.typeText("Note to Edit")

        app.noteSaveButton.tap()

        // Wait for navigation to detail view (after save, app navigates to detail)
        XCTAssertTrue(app.noteDetailTitle.waitForExistence(timeout: 15), "Note detail title should exist")
        XCTAssertEqual(app.noteDetailTitle.label, "Note to Edit")

        // Tap edit button
        XCTAssertTrue(app.noteDetailEditButton.waitForExistence(timeout: 5), "Edit button should exist")
        app.noteDetailEditButton.tap()

        // Verify editor opens with title field editable
        XCTAssertTrue(app.noteTitleField.waitForExistence(timeout: 10), "Title field should exist in edit mode")

        // Modify the title - clear existing text and type new one
        app.noteTitleField.tap()
        app.noteTitleField.press(forDuration: 1.0)
        let selectAll = app.menuItems["Select All"].firstMatch
        if selectAll.waitForExistence(timeout: 3) {
            selectAll.tap()
        }
        app.noteTitleField.typeText("Updated Note Title")

        // Save the edited note
        app.noteSaveButton.tap()

        // Verify the title is updated in detail view
        XCTAssertTrue(app.staticTexts["Updated Note Title"].waitForExistence(timeout: 15), "Note detail title should exist after edit")
    }

    // MARK: - Delete Note

    func testDeleteNote() throws {
        let app = launchApp()
        try app.signInWithEmailAndPassword()

        // First create a note to delete
        XCTAssertTrue(app.addNoteButton.waitForExistence(timeout: 10), "Add note button should exist")
        app.addNoteButton.tap()

        XCTAssertTrue(app.noteTitleField.waitForExistence(timeout: 10), "Title field should exist")
        app.noteTitleField.tap()
        app.noteTitleField.typeText("Note to Delete")

        // check save button exists before tapping
        XCTAssertTrue(app.noteSaveButton.waitForExistence(timeout: 5), "Save button should exist")
        app.noteSaveButton.tap()

        // wait back button
        let backButton = app.navigationBars.buttons["Notes"].firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Back button should exist")
        backButton.tap() // Go back to list to ensure the note is created before we try

        // Wait for the note to appear in the list
        let noteToDelete = app.staticTexts["Note to Delete"].firstMatch
        XCTAssertTrue(noteToDelete.waitForExistence(timeout: 15), "Note to delete should appear in the list")

        // Find the cell containing this note and swipe on it
        // The staticText is inside a cell, we need to swipe on the cell for delete action to work
        let cell = app.cells.containing(.staticText, identifier: "Note to Delete").firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "Cell containing the note should exist")
        cell.swipeLeft()

        // Tap delete button
        let deleteButton = app.buttons["Delete"].firstMatch
        if deleteButton.waitForExistence(timeout: 5) {
            deleteButton.tap()
        }

        // Verify the note is removed from the list
        XCTAssertTrue(noteToDelete.waitForNonExistence(timeout: 10), "Deleted note should no longer appear in the list")
    }
}
