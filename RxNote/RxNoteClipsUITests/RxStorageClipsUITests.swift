//
//  RxNoteClipsUITests.swift
//  RxNoteClipsUITests
//
//  Created by Qiwei Li on 1/27/26.
//

import XCTest

final class RxNoteClipsUITests: XCTestCase {
    // MARK: - URL Parsing Tests

    func testInvalidURLShowsError() {
        let app = launchAppClip(withURL: "http://localhost:3000/invalid/path")

        let errorTitle = app.staticTexts["Invalid URL"]
        XCTAssertTrue(errorTitle.waitForExistence(timeout: 30))
    }

    // MARK: - Note Loading Tests

    func testPublicNoteLoadsSuccessfully() {
        let app = launchAppClip(withNoteId: 1)

        // Wait for loading to complete
        let loadingIndicator = app.staticTexts["Loading..."]
        XCTAssertTrue(loadingIndicator.waitForNonExistence(timeout: 15))

        // Verify no error state is shown
        let errorTitle = app.staticTexts["Invalid URL"]
        XCTAssertFalse(errorTitle.exists)

        XCTAssertFalse(app.appClipsSignInRequired.exists)
    }

    func testPrivateNoteRequiresSignIn() throws {
        let app = launchAppClip(withNoteId: 2)

        // Wait for auth check to complete and sign-in view to appear
        XCTAssertTrue(app.appClipsSignInRequired.waitForExistence(timeout: 10))

        try app.signInWithEmailAndPassword(isAppclips: true)
    }

    // MARK: - Error Handling Tests

    func testAccessDenied() throws {
        // This test note created by different users
        let app = launchAppClip(withNoteId: 3)
        try app.signInWithEmailAndPassword(isAppclips: true)
        XCTAssertTrue(app.appClipsAccessDenined.waitForExistence(timeout: 30))
    }

    // MARK: - Sign Out Button Visibility Tests

    func testSignOutNotShownWhenNotAuthenticated() {
        let app = launchAppClip(withNoteId: 1)

        // Wait for loading to complete
        let loadingIndicator = app.staticTexts["Loading..."]
        XCTAssertTrue(loadingIndicator.waitForNonExistence(timeout: 15))

        // Verify the more menu (ellipsis button) is NOT shown when not authenticated
        XCTAssertFalse(app.appClipsMoreMenu.exists, "More menu should not be shown when user is not authenticated")

        // Also verify sign out button doesn't exist
        XCTAssertFalse(app.appClipsSignOutButton.exists, "Sign out button should not be shown when user is not authenticated")
    }

    func testSignOutShownWhenAuthenticated() throws {
        let app = launchAppClip(withNoteId: 2)

        // Sign in
        try app.signInWithEmailAndPassword(isAppclips: true)

        // Verify the more menu IS shown when authenticated
        XCTAssertTrue(app.appClipsMoreMenu.waitForExistence(timeout: 5), "More menu should be shown when user is authenticated")

        // Tap the more menu to reveal sign out button
        app.appClipsMoreMenu.tap()

        // Verify sign out button is visible in the menu
        XCTAssertTrue(app.appClipsSignOutButton.waitForExistence(timeout: 5), "Sign out button should be shown when user is authenticated")
    }
}
