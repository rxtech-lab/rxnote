//
//  RxNoteDeepLinkTests.swift
//  RxNoteUITests
//
//  UI tests for deep link handling
//

import XCTest

final class RxNoteDeepLinkTests: XCTestCase {
    // MARK: - Public Note Deep Link

    func testDeepLinkToPublicNote() throws {
        let app = launchAppWithDeepLink(noteId: 1)
        try app.signInWithEmailAndPassword(expectsDeepLinkNavigation: true)

        // Wait for note detail to load
        XCTAssertTrue(app.noteDetailTitle.waitForExistence(timeout: 15), "Note detail should load via deep link")
        XCTAssertEqual(app.noteDetailTitle.label, "Public Test Note")
    }

    // MARK: - Private Note Deep Link (accessible)

    func testDeepLinkToPrivateNote() throws {
        let app = launchAppWithDeepLink(noteId: 2)
        try app.signInWithEmailAndPassword(expectsDeepLinkNavigation: true)

        // Wait for note detail to load after sign-in
        XCTAssertTrue(app.noteDetailTitle.waitForExistence(timeout: 30), "Private note detail should load after sign-in")
        XCTAssertEqual(app.noteDetailTitle.label, "Private Test Note")
    }

    // MARK: - Private Note Deep Link (access denied)

    func testDeepLinkToPrivateNoteBelongsToOthers() throws {
        let app = launchAppWithDeepLink(noteId: 3)
        try app.signInWithEmailAndPassword(expectsDeepLinkNavigation: true)

        // Deep link navigates to note detail, but note fetch fails with access denied
        let errorAlert = app.alerts["Deep Link Error"].firstMatch
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 30), "Error alert should appear for access denied note")
    }

    // MARK: - Invalid Deep Link URL

    func testDeepLinkInvalidUrl() throws {
        let app = launchAppWithDeepLink(url: "rxnote://invalid/path")
        try app.signInWithEmailAndPassword(expectsDeepLinkNavigation: true)
        // Should show an error or return to normal state
        // The app should handle invalid paths gracefully
        let errorAlert = app.alerts["Deep Link Error"].firstMatch
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 15), "Deep link error alert should appear for invalid URL")
    }

    // MARK: - Non-existent Note Deep Link

    func testDeepLinkNonExistentNote() throws {
        let app = launchAppWithDeepLink(noteId: 999999)
        try app.signInWithEmailAndPassword(expectsDeepLinkNavigation: true)

        // Should show an error alert
        let errorAlert = app.alerts["Deep Link Error"].firstMatch
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 30), "Deep link error alert should appear for non-existent note")
    }
}
