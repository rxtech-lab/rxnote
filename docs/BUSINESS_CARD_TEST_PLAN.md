# Business Card Feature — iOS Frontend Test Plan

This document describes the test plan for the business card note type and add-contact action on the iOS frontend. All tests are documentation only; no actual test code is included.

---

## Table of Contents

1. [Unit Tests](#unit-tests)
2. [UI Tests](#ui-tests)
3. [Test Data](#test-data)

---

## Unit Tests

Location: `RxNote/RxNoteTests/`

### 1. BusinessCardModelTests

Validates the business card data model serialization and deserialization.

| Test Case | Description |
|-----------|-------------|
| `testBusinessCardFullFields` | Create a `BusinessCard` with all fields populated; verify all properties are set correctly. |
| `testBusinessCardRequiredFieldsOnly` | Create a `BusinessCard` with only `firstName` and `lastName`; verify optional fields are `nil`. |
| `testBusinessCardJSONRoundTrip` | Encode a `BusinessCard` to JSON and decode it back; verify equality. |
| `testBusinessCardJSONDecoding` | Decode a known JSON payload into a `BusinessCard`; verify all fields match. |
| `testBusinessCardOptionalFieldsNullInJSON` | Decode a JSON payload where optional fields are `null`; verify the struct has `nil` for those fields. |

### 2. AddContactActionTests

Validates the add-contact action model and its integration in the `NoteAction` discriminated union.

| Test Case | Description |
|-----------|-------------|
| `testAddContactActionCreation` | Create an `AddContactAction` with all fields; verify properties. |
| `testAddContactActionMinimalFields` | Create an `AddContactAction` with only required fields; verify optional fields are `nil`. |
| `testAddContactActionJSONRoundTrip` | Encode and decode an `AddContactAction`; verify equality. |
| `testNoteActionDiscriminatedUnion` | Create a `NoteAction` with `.addContact` case; verify the discriminator works correctly. |
| `testNoteActionArrayWithMixedTypes` | Create an array of `NoteAction` with `.url`, `.wifi`, and `.addContact`; verify JSON encoding/decoding preserves all three types. |

### 3. NoteEditorViewModelBusinessCardTests

Validates the view model behavior for business card notes.

| Test Case | Description |
|-----------|-------------|
| `testDefaultNoteTypeIsRegularText` | Verify `noteType` defaults to `.regularTextNote`. |
| `testSwitchNoteTypeToBusinessCard` | Set `noteType` to `.businessCard`; verify the type changes. |
| `testBusinessCardFieldsInitiallyEmpty` | Verify all business card fields (`businessCardFirstName`, etc.) are empty strings on init. |
| `testCanSaveBusinessCardRequiresFirstAndLastName` | Set `noteType` to `.businessCard`, leave first/last name empty; verify `canSave` is `false`. Fill in first and last name plus title; verify `canSave` is `true`. |
| `testSaveBusinessCardIncludesBusinessCardData` | Set up a business card with fields, call `save()`; verify the API request includes the `businessCard` JSON. |
| `testLoadExistingBusinessCardNote` | Initialize view model with a business card note; verify all business card fields are populated from the note data. |
| `testSwitchFromBusinessCardToRegularClearsFields` | Fill in business card fields, then switch to `.regularTextNote`; verify the business card data is not sent in the save payload. |

---

## UI Tests

Location: `RxNote/RxNoteUITests/`

### 1. BusinessCardCrudTests

End-to-end tests for creating, viewing, editing, and deleting business card notes.

#### `testCreateBusinessCardNote`

**Steps:**
1. Launch app and sign in.
2. Tap the "Add note" button.
3. Switch the note type picker to "Business Card".
4. Fill in the title field: "John Doe's Card".
5. Fill in business card fields: First Name = "John", Last Name = "Doe", Email = "john@example.com", Company = "Acme Inc", Job Title = "Engineer".
6. Tap "Save".

**Expected Results:**
- The note list should display "John Doe's Card".
- Tapping the note should show the business card layout with all contact information rendered.

#### `testViewBusinessCardDetail`

**Steps:**
1. Launch app and sign in.
2. Navigate to an existing business card note.
3. Verify the detail view shows business card fields.

**Expected Results:**
- First name, last name, email, phone, company, and job title are displayed.
- The layout should use the business card style (distinct from the regular text note layout).

#### `testEditBusinessCardNote`

**Steps:**
1. Launch app and sign in.
2. Navigate to an existing business card note.
3. Tap "Edit".
4. Change the company name from "Acme Inc" to "New Corp".
5. Tap "Save".

**Expected Results:**
- The detail view should show "New Corp" as the company.

#### `testDeleteBusinessCardNote`

**Steps:**
1. Launch app and sign in.
2. Create a business card note titled "Card to Delete".
3. Go back to the note list.
4. Swipe left on "Card to Delete" and tap "Delete".

**Expected Results:**
- The note should no longer appear in the list.

### 2. AddContactActionTests

UI tests for the add-contact action creation and interaction.

#### `testCreateAddContactAction`

**Steps:**
1. Launch app and sign in.
2. Create a new note (regular text or business card).
3. Tap the "Add Action" button in the toolbar.
4. Select "Add Contact" from the action type picker.
5. Fill in: First Name = "Jane", Last Name = "Smith", Email = "jane@example.com", Phone = "+1234567890".
6. Tap "Save" on the action editor.
7. Verify the action appears in the actions section.
8. Save the note.

**Expected Results:**
- The action label shows "Jane Smith" with a contact icon.
- After saving, viewing the note in read-only mode shows an "Add Jane Smith to Contacts" button.

#### `testEditAddContactAction`

**Steps:**
1. Launch app and sign in.
2. Navigate to a note with an existing add-contact action.
3. Tap "Edit" on the note.
4. Tap the edit (pencil) icon next to the add-contact action.
5. Change the company from "OldCo" to "NewCo".
6. Tap "Save" on the action editor.
7. Save the note.

**Expected Results:**
- The action should still show the contact name.
- Opening the action editor again should show "NewCo" as the company.

#### `testDeleteAddContactAction`

**Steps:**
1. Launch app and sign in.
2. Navigate to a note with an add-contact action.
3. Tap "Edit" on the note.
4. Tap the "X" button next to the add-contact action.
5. Save the note.

**Expected Results:**
- The action should no longer appear on the note.

#### `testAddContactButtonOpensContactSheet`

**Steps:**
1. Launch app and sign in.
2. Navigate to a note with an add-contact action (in read-only/view mode).
3. Tap the "Add … to Contacts" button.

**Expected Results:**
- The system Contacts UI should appear, pre-filled with the contact's information.
- The user can confirm or cancel adding the contact.

> **Note:** This test may need to handle system permission dialogs for Contacts access.

### 3. NoteTypePickerTests

Tests for the note type selector in the editor.

#### `testNoteTypePickerIsVisible`

**Steps:**
1. Launch app and sign in.
2. Tap "Add note" to open the create editor.

**Expected Results:**
- A segmented control or picker is visible at the top with "Text Note" and "Business Card" options.
- "Text Note" is selected by default.

#### `testSwitchToBusinessCardShowsContactFields`

**Steps:**
1. Launch app and sign in.
2. Open the note editor.
3. Select "Business Card" from the type picker.

**Expected Results:**
- The business card form fields (First Name, Last Name, Email, Phone, Company, Job Title, Website, Address) appear.
- The markdown text editor may be hidden or optional.

#### `testSwitchBackToTextNoteHidesContactFields`

**Steps:**
1. Launch app and sign in.
2. Open the note editor.
3. Select "Business Card", fill in some fields.
4. Switch back to "Text Note".

**Expected Results:**
- The business card form fields are hidden.
- The standard markdown content editor is shown.

### 4. MixedActionTests

Tests combining different action types.

#### `testNoteWithAllActionTypes`

**Steps:**
1. Launch app and sign in.
2. Create a new note.
3. Add a URL action (label: "Website", url: "https://example.com").
4. Add a WiFi action (SSID: "Office", password: "pass123").
5. Add an Add Contact action (First: "Bob", Last: "Jones").
6. Save the note.

**Expected Results:**
- All three actions appear in the edit mode actions section.
- In read-only mode, all three action buttons are rendered correctly with distinct icons.

---

## Test Data

### Sample Business Card Note (API Payload)

```json
{
  "title": "John Doe",
  "type": "business-card",
  "note": null,
  "businessCard": {
    "firstName": "John",
    "lastName": "Doe",
    "email": "john.doe@example.com",
    "phone": "+1-555-0100",
    "company": "Acme Corporation",
    "jobTitle": "Senior Engineer",
    "website": "https://johndoe.dev",
    "address": "123 Main St, San Francisco, CA 94102"
  },
  "images": [],
  "actions": [],
  "visibility": "public"
}
```

### Sample Add Contact Action

```json
{
  "type": "add-contact",
  "firstName": "Jane",
  "lastName": "Smith",
  "email": "jane.smith@company.com",
  "phone": "+1-555-0200",
  "company": "Tech Corp",
  "jobTitle": "Product Manager"
}
```

### Sample Note with Mixed Actions

```json
{
  "title": "Office Info",
  "type": "regular-text-note",
  "note": "Welcome to the office!",
  "actions": [
    {
      "type": "url",
      "label": "Company Website",
      "url": "https://example.com"
    },
    {
      "type": "wifi",
      "ssid": "OfficeNetwork",
      "password": "welcome123",
      "encryption": "WPA"
    },
    {
      "type": "add-contact",
      "firstName": "Front",
      "lastName": "Desk",
      "email": "reception@example.com",
      "phone": "+1-555-0300",
      "company": "Example Inc",
      "jobTitle": "Receptionist"
    }
  ],
  "visibility": "public"
}
```

### Accessibility Identifiers

The following accessibility identifiers should be added for UI testing:

| Identifier | Element |
|-----------|---------|
| `note-type-picker` | Segmented control for note type selection |
| `business-card-first-name` | First name text field |
| `business-card-last-name` | Last name text field |
| `business-card-email` | Email text field |
| `business-card-phone` | Phone text field |
| `business-card-company` | Company text field |
| `business-card-job-title` | Job title text field |
| `business-card-website` | Website text field |
| `business-card-address` | Address text field |
| `action-type-add-contact` | Add Contact segment in action type picker |
| `contact-first-name` | First name field in action editor |
| `contact-last-name` | Last name field in action editor |
| `add-contact-button` | "Add to Contacts" button in read-only view |
