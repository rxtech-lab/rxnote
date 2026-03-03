# Business Card Note Type — Implementation Plan

This document describes the planned changes to support a **business card** note type alongside the existing `regular-text-note` type. It also introduces a new **"add contact"** action type. This is a documentation-only plan; no actual implementation is included.

---

## Table of Contents

1. [Feature Overview](#feature-overview)
2. [Data Model](#data-model)
3. [Backend Modifications](#backend-modifications)
4. [iOS App Modifications](#ios-app-modifications)
5. [File Change Summary](#file-change-summary)

---

## Feature Overview

### Business Card Note Type

A business card note stores structured contact information that can be shared via QR codes, NFC, or direct links — just like regular text notes. Business cards contain:

| Field         | Type     | Required | Description                          |
|---------------|----------|----------|--------------------------------------|
| `firstName`   | string   | Yes      | Contact's first name                 |
| `lastName`    | string   | Yes      | Contact's last name                  |
| `email`       | string   | No       | Email address                        |
| `phone`       | string   | No       | Phone number                         |
| `company`     | string   | No       | Company or organization name         |
| `jobTitle`    | string   | No       | Job title / role                     |
| `website`     | string   | No       | Personal or company website URL      |
| `address`     | string   | No       | Mailing / office address             |

These fields are stored in a JSON column (`businessCard`) on the existing `notes` table. The `type` column distinguishes between `"regular-text-note"` and `"business-card"`.

### Add Contact Action

A new action type (`"add-contact"`) lets any note (regular or business card) include a button that, when tapped, creates a contact in the user's address book. The action carries the same contact fields listed above.

---

## Data Model

### Business Card JSON Structure

```typescript
interface BusinessCard {
  firstName: string;
  lastName: string;
  email?: string;
  phone?: string;
  company?: string;
  jobTitle?: string;
  website?: string;
  address?: string;
}
```

### Add Contact Action Structure

```typescript
interface AddContactAction {
  type: "add-contact";
  firstName: string;
  lastName: string;
  email?: string;
  phone?: string;
  company?: string;
  jobTitle?: string;
  website?: string;
  address?: string;
}
```

---

## Backend Modifications

### 1. Database Schema — `backend/lib/db/schema/notes.ts`

Add the `"business-card"` enum value to the `type` column, define the `BusinessCard` interface and the `AddContactAction` interface, and add a `businessCard` JSON column.

```typescript
// backend/lib/db/schema/notes.ts

import { sqliteTable, text, integer, real } from "drizzle-orm/sqlite-core";

export const notes = sqliteTable("notes", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  userId: text("user_id").notNull(),
  // ✅ ADD "business-card" to the enum
  type: text("type", { enum: ["regular-text-note", "business-card"] })
    .notNull()
    .default("regular-text-note"),
  title: text("title").notNull(),
  note: text("note"),
  // ✅ ADD businessCard JSON column
  businessCard: text("business_card", { mode: "json" })
    .$type<BusinessCard | null>()
    .default(null),
  images: text("images", { mode: "json" }).$type<string[]>().default([]),
  audios: text("audios", { mode: "json" }).$type<string[]>().default([]),
  videos: text("videos", { mode: "json" }).$type<string[]>().default([]),
  latitude: real("latitude"),
  longitude: real("longitude"),
  actions: text("actions", { mode: "json" })
    .$type<Action[]>()
    .default([]),
  visibility: text("visibility", {
    enum: ["public", "private", "auth-only"],
  })
    .notNull()
    .default("private"),
  createdAt: integer("created_at", { mode: "timestamp" })
    .notNull()
    .$defaultFn(() => new Date()),
  updatedAt: integer("updated_at", { mode: "timestamp" })
    .notNull()
    .$defaultFn(() => new Date()),
});

// Existing action types
export interface URLAction {
  type: "url";
  label: string;
  url: string;
}

export interface WifiAction {
  type: "wifi";
  ssid: string;
  password?: string;
  encryption?: "WPA" | "WEP" | "none";
}

// ✅ NEW: Add Contact action
export interface AddContactAction {
  type: "add-contact";
  firstName: string;
  lastName: string;
  email?: string;
  phone?: string;
  company?: string;
  jobTitle?: string;
  website?: string;
  address?: string;
}

// ✅ UPDATE: Include AddContactAction in union
export type Action = URLAction | WifiAction | AddContactAction;

// ✅ NEW: Business card data structure
export interface BusinessCard {
  firstName: string;
  lastName: string;
  email?: string;
  phone?: string;
  company?: string;
  jobTitle?: string;
  website?: string;
  address?: string;
}

export type Note = typeof notes.$inferSelect;
export type NewNote = typeof notes.$inferInsert;
```

### 2. Zod Validation Schemas — `backend/lib/schemas/notes.ts`

Add validation schemas for the new action and the business card fields.

```typescript
// backend/lib/schemas/notes.ts  — additions / modifications only

// ✅ NEW: Add Contact action schema
export const AddContactActionSchema = z.object({
  type: z.literal("add-contact"),
  firstName: z.string().min(1).describe("Contact first name"),
  lastName: z.string().min(1).describe("Contact last name"),
  email: z.string().email().optional().describe("Contact email address"),
  phone: z.string().optional().describe("Contact phone number"),
  company: z.string().optional().describe("Company or organization"),
  jobTitle: z.string().optional().describe("Job title or role"),
  website: z.string().url().optional().describe("Website URL"),
  address: z.string().optional().describe("Mailing or office address"),
});

// ✅ UPDATE: Add to discriminated union
export const ActionSchema = z
  .discriminatedUnion("type", [
    URLActionSchema,
    WifiActionSchema,
    AddContactActionSchema,  // ← new
  ])
  .describe("An action associated with the note");

// ✅ NEW: Business card schema
export const BusinessCardSchema = z.object({
  firstName: z.string().min(1).describe("First name"),
  lastName: z.string().min(1).describe("Last name"),
  email: z.string().email().optional().describe("Email address"),
  phone: z.string().optional().describe("Phone number"),
  company: z.string().optional().describe("Company or organization"),
  jobTitle: z.string().optional().describe("Job title or role"),
  website: z.string().url().optional().describe("Website URL"),
  address: z.string().optional().describe("Mailing or office address"),
});

// ✅ UPDATE: NoteInsertSchema — add "business-card" to type enum, add businessCard field
export const NoteInsertSchema = z.object({
  title: z.string().min(1).describe("Note title"),
  type: z
    .enum(["regular-text-note", "business-card"])   // ← updated
    .optional()
    .describe("Note type"),
  note: z.string().nullable().optional().describe("Markdown note content"),
  businessCard: BusinessCardSchema.nullable().optional()
    .describe("Business card data (required when type is business-card)"),
  images: z.array(z.string()).optional()
    .describe("Image file references (file:N format)"),
  audios: z.array(z.string()).optional()
    .describe("Audio file references (file:N format)"),
  videos: z.array(z.string()).optional()
    .describe("Video file references (file:N format)"),
  latitude: z.number().nullable().optional().describe("Latitude coordinate"),
  longitude: z.number().nullable().optional().describe("Longitude coordinate"),
  actions: z.array(ActionSchema).optional()
    .describe("Actions associated with the note"),
  visibility: z.enum(["public", "private", "auth-only"])
    .describe("Visibility setting"),
});

// ✅ UPDATE: NoteUpdateSchema — same additions as insert
export const NoteUpdateSchema = z.object({
  title: z.string().min(1).optional().describe("Note title"),
  type: z
    .enum(["regular-text-note", "business-card"])   // ← updated
    .optional()
    .describe("Note type"),
  note: z.string().nullable().optional().describe("Markdown note content"),
  businessCard: BusinessCardSchema.nullable().optional()
    .describe("Business card data"),
  // ... (remaining fields unchanged)
  visibility: z.enum(["public", "private", "auth-only"]).optional()
    .describe("Visibility setting"),
});

// ✅ UPDATE: NoteResponseSchema — add businessCard and update type enum
export const NoteResponseSchema = z.object({
  id: z.number().int().describe("Unique note identifier"),
  userId: z.string().describe("Owner user ID"),
  type: z.enum(["regular-text-note", "business-card"]).describe("Note type"),  // ← updated
  title: z.string().describe("Note title"),
  note: z.string().nullable().describe("Markdown note content"),
  businessCard: BusinessCardSchema.nullable().describe("Business card data"),  // ← new
  images: z.array(SignedImageSchema).describe("Signed images with IDs and URLs"),
  audios: z.array(z.string()).describe("Audio file references"),
  videos: z.array(z.string()).describe("Video file references"),
  latitude: z.number().nullable().describe("Latitude coordinate"),
  longitude: z.number().nullable().describe("Longitude coordinate"),
  actions: z.array(ActionSchema).describe("Actions associated with the note"),
  visibility: z.enum(["public", "private", "auth-only"]).describe("Visibility setting"),
  previewUrl: z.string().url().describe("Public preview URL for the note"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
  updatedAt: z.coerce.date().describe("Last update timestamp"),
});
```

### 3. Database Migration

A new Drizzle migration is required to add the `business_card` column and update the `type` column constraint.

```sql
-- drizzle migration (generated via `bun run db:push` or drizzle-kit generate)
ALTER TABLE notes ADD COLUMN business_card TEXT DEFAULT NULL;
```

> Because SQLite stores enums as plain text, no ALTER is needed for the `type` column — the enum constraint is enforced at the application layer by Drizzle/Zod.

### 4. Preview Page — `backend/app/preview/note/[id]/page.tsx`

Add rendering for the business card layout and the add-contact action button.

```tsx
// backend/app/preview/note/[id]/page.tsx  — additions only

import { Contact, ExternalLink, Wifi, Mail, Phone, Building2, Briefcase, Globe } from "lucide-react";

// ... inside the return JSX, after {/* Note Content */} and before {/* Location Map */}:

{/* ✅ NEW: Business Card */}
{note.type === "business-card" && note.businessCard && (
  <Card className="mb-8">
    <CardHeader>
      <CardTitle className="flex items-center gap-2">
        <Contact className="h-5 w-5" />
        Business Card
      </CardTitle>
    </CardHeader>
    <CardContent>
      <div className="space-y-3">
        <h2 className="text-2xl font-bold">
          {note.businessCard.firstName} {note.businessCard.lastName}
        </h2>
        {note.businessCard.jobTitle && (
          <p className="flex items-center gap-2 text-muted-foreground">
            <Briefcase className="h-4 w-4" />
            {note.businessCard.jobTitle}
          </p>
        )}
        {note.businessCard.company && (
          <p className="flex items-center gap-2 text-muted-foreground">
            <Building2 className="h-4 w-4" />
            {note.businessCard.company}
          </p>
        )}
        {note.businessCard.email && (
          <a href={`mailto:${note.businessCard.email}`}
             className="flex items-center gap-2 text-primary hover:underline">
            <Mail className="h-4 w-4" />
            {note.businessCard.email}
          </a>
        )}
        {note.businessCard.phone && (
          <a href={`tel:${note.businessCard.phone}`}
             className="flex items-center gap-2 text-primary hover:underline">
            <Phone className="h-4 w-4" />
            {note.businessCard.phone}
          </a>
        )}
        {note.businessCard.website && (
          <a href={note.businessCard.website} target="_blank" rel="noopener noreferrer"
             className="flex items-center gap-2 text-primary hover:underline">
            <Globe className="h-4 w-4" />
            {note.businessCard.website}
          </a>
        )}
        {note.businessCard.address && (
          <p className="flex items-center gap-2 text-muted-foreground">
            <MapPin className="h-4 w-4" />
            {note.businessCard.address}
          </p>
        )}
      </div>
    </CardContent>
  </Card>
)}

// ... inside the actions rendering loop, add a new case:

{action.type === "add-contact" && (
  <div key={index}
       className="flex items-center gap-2 p-3 rounded-lg border hover:bg-accent transition-colors cursor-pointer">
    <Contact className="h-4 w-4" />
    <div>
      <p className="font-medium">
        Add {action.firstName} {action.lastName} to Contacts
      </p>
      {action.company && (
        <p className="text-sm text-muted-foreground">{action.company}</p>
      )}
    </div>
  </div>
)}
```

### 5. API Route Handlers — `backend/app/api/v1/notes/route.ts` and `backend/app/api/v1/notes/[id]/route.ts`

The existing API handlers use the Zod schemas for validation, so adding `businessCard` to the schemas automatically extends the API. The response serialization in `note-actions.ts` needs to include `businessCard`.

```typescript
// backend/lib/actions/note-actions.ts  — update the response mapping

// In the function that maps DB rows to API responses, include the new field:
function mapNoteToResponse(note: Note) {
  return {
    ...existingFields,
    businessCard: note.businessCard ?? null,  // ← add this line
  };
}
```

### 6. OpenAPI Spec Regeneration

After modifying the Zod schemas, regenerate the OpenAPI spec and iOS client:

```bash
./scripts/openapi-generate.sh      # Regenerate backend/next.openapi.json
./scripts/ios-update-openapi.sh    # Regenerate Swift OpenAPI client types
```

---

## iOS App Modifications

### 1. OpenAPI-Generated Types (auto-generated)

After running `./scripts/ios-update-openapi.sh`, the Swift OpenAPI generator will produce new types for:

- `BusinessCard` — struct with `firstName`, `lastName`, `email`, `phone`, `company`, `jobTitle`, `website`, `address`
- `AddContactAction` — new case in the `NoteAction` discriminated union
- Updated `NoteInsert` / `NoteUpdate` / `NoteResponse` with `businessCard` field and `"business-card"` type enum

### 2. Type Aliases — `RxNote/packages/RxNoteCore/Sources/RxNoteCore/Extensions/`

Add a type alias for the new business card type and add-contact action in the existing extension files.

```swift
// In the file that defines NoteAction, URLAction, WifiAction type aliases:

// ✅ NEW: Business card type alias
public typealias BusinessCard = Components.Schemas.BusinessCard

// ✅ NEW: Add Contact action type alias
public typealias AddContactAction = Components.Schemas.AddContactAction
```

### 3. Action Editor — `RxNote/RxNote/Views/Notes/ActionEditorView.swift`

Add an "Add Contact" case to the `ActionType` enum and a corresponding form.

```swift
// RxNote/RxNote/Views/Notes/ActionEditorView.swift

// ✅ UPDATE: Add new action type case
enum ActionType: String, CaseIterable {
    case url = "URL"
    case wifi = "WiFi"
    case addContact = "Add Contact"  // ← new
}

// ✅ ADD: State variables for the add-contact form
@State private var contactFirstName = ""
@State private var contactLastName = ""
@State private var contactEmail = ""
@State private var contactPhone = ""
@State private var contactCompany = ""
@State private var contactJobTitle = ""
@State private var contactWebsite = ""
@State private var contactAddress = ""

// ✅ ADD: Form section in the body's switch statement
case .addContact:
    addContactForm

// ✅ ADD: Add Contact Form view
private var addContactForm: some View {
    Section("Contact Information") {
        TextField("First Name", text: $contactFirstName)
        TextField("Last Name", text: $contactLastName)
        TextField("Email", text: $contactEmail)
            #if os(iOS)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            #endif
        TextField("Phone", text: $contactPhone)
            #if os(iOS)
            .keyboardType(.phonePad)
            .textContentType(.telephoneNumber)
            #endif
        TextField("Company", text: $contactCompany)
        TextField("Job Title", text: $contactJobTitle)
        TextField("Website", text: $contactWebsite)
            #if os(iOS)
            .keyboardType(.URL)
            .textContentType(.URL)
            .textInputAutocapitalization(.never)
            #endif
        TextField("Address", text: $contactAddress)
            #if os(iOS)
            .textContentType(.fullStreetAddress)
            #endif
    }
}

// ✅ UPDATE: canSave computed property
case .addContact:
    return !contactFirstName.trimmingCharacters(in: .whitespaces).isEmpty
        && !contactLastName.trimmingCharacters(in: .whitespaces).isEmpty

// ✅ UPDATE: saveAction() function
case .addContact:
    action = .addContact(.init(
        _type: .add_hyphen_contact,
        firstName: contactFirstName.trimmingCharacters(in: .whitespaces),
        lastName: contactLastName.trimmingCharacters(in: .whitespaces),
        email: contactEmail.isEmpty ? nil : contactEmail,
        phone: contactPhone.isEmpty ? nil : contactPhone,
        company: contactCompany.isEmpty ? nil : contactCompany,
        jobTitle: contactJobTitle.isEmpty ? nil : contactJobTitle,
        website: contactWebsite.isEmpty ? nil : contactWebsite,
        address: contactAddress.isEmpty ? nil : contactAddress
    ))

// ✅ UPDATE: prefillIfEditing() function
case let .addContact(contactAction):
    actionType = .addContact
    contactFirstName = contactAction.firstName
    contactLastName = contactAction.lastName
    contactEmail = contactAction.email ?? ""
    contactPhone = contactAction.phone ?? ""
    contactCompany = contactAction.company ?? ""
    contactJobTitle = contactAction.jobTitle ?? ""
    contactWebsite = contactAction.website ?? ""
    contactAddress = contactAction.address ?? ""
```

### 4. Note Editor — `RxNote/RxNote/Views/Notes/NoteEditorView.swift`

Add a business card form section and update the action label rendering.

```swift
// RxNote/RxNote/Views/Notes/NoteEditorView.swift

// ✅ ADD: In editorContent, after the title section and before the content section,
// render business card fields when type is business-card

if viewModel.noteType == .businessCard {
    businessCardSection
}

// ✅ ADD: Business card section view
private var businessCardSection: some View {
    VStack(alignment: .leading, spacing: 12) {
        Group {
            TextField("First Name", text: $viewModel.businessCardFirstName)
                .font(.body)
            TextField("Last Name", text: $viewModel.businessCardLastName)
                .font(.body)
            TextField("Email", text: $viewModel.businessCardEmail)
                #if os(iOS)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                #endif
            TextField("Phone", text: $viewModel.businessCardPhone)
                #if os(iOS)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                #endif
            TextField("Company", text: $viewModel.businessCardCompany)
            TextField("Job Title", text: $viewModel.businessCardJobTitle)
            TextField("Website", text: $viewModel.businessCardWebsite)
                #if os(iOS)
                .keyboardType(.URL)
                .textContentType(.URL)
                #endif
            TextField("Address", text: $viewModel.businessCardAddress)
        }
        .textFieldStyle(.roundedBorder)
    }
    .padding(.horizontal, 16)
}

// ✅ UPDATE: actionLabel function to handle add-contact
@ViewBuilder
private func actionLabel(_ action: NoteAction) -> some View {
    switch action {
    case let .url(urlAction):
        Label(urlAction.label, systemImage: "link")
            .font(.body.weight(.medium))
    case let .wifi(wifiAction):
        Label(wifiAction.ssid, systemImage: "wifi")
            .font(.body.weight(.medium))
    case let .addContact(contactAction):
        Label("\(contactAction.firstName) \(contactAction.lastName)", systemImage: "person.crop.circle.badge.plus")
            .font(.body.weight(.medium))
    }
}

// ✅ UPDATE: actionButton function to handle add-contact
case let .addContact(contactAction):
    Button {
        // Import contact to address book using Contacts framework
        addContactToAddressBook(contactAction)
    } label: {
        HStack {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.body.weight(.medium))
            VStack(alignment: .leading) {
                Text("Add \(contactAction.firstName) \(contactAction.lastName)")
                    .font(.body.weight(.medium))
                if let company = contactAction.company {
                    Text(company)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "plus.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        #if os(iOS)
        .background(Color(.secondarySystemBackground))
        #else
        .background(Color(NSColor.controlBackgroundColor))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .foregroundStyle(Color.appAccent)
```

### 5. Add Contact to Address Book — New helper (contact import)

```swift
// RxNote/RxNote/Views/Notes/NoteEditorView.swift or a new utility file

import Contacts
import ContactsUI

private func addContactToAddressBook(_ contactAction: AddContactAction) {
    let contact = CNMutableContact()
    contact.givenName = contactAction.firstName
    contact.familyName = contactAction.lastName

    if let email = contactAction.email {
        contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: email as NSString)]
    }
    if let phone = contactAction.phone {
        contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: phone))]
    }
    if let company = contactAction.company {
        contact.organizationName = company
    }
    if let jobTitle = contactAction.jobTitle {
        contact.jobTitle = jobTitle
    }
    if let website = contactAction.website {
        contact.urlAddresses = [CNLabeledValue(label: CNLabelURLAddressHomePage, value: website as NSString)]
    }

    // Present CNContactViewController for user confirmation
    // (implementation details depend on UIKit bridge)
}
```

### 6. Note Type Picker — `RxNote/RxNote/Views/Notes/NoteEditorView.swift`

When creating a new note, the user should be able to choose between a regular text note and a business card. This can be a segmented control or a picker at the top of the editor.

```swift
// In editorContent, at the very top (before the date):

if !viewModel.isReadOnly {
    Picker("Note Type", selection: $viewModel.noteType) {
        Text("Text Note").tag(NoteType.regularTextNote)
        Text("Business Card").tag(NoteType.businessCard)
    }
    .pickerStyle(.segmented)
    .padding(.horizontal, 16)
}
```

### 7. View Model Updates — `RxNote/packages/RxNoteCore/Sources/RxNoteCore/ViewModels/`

The `NoteEditorViewModel` needs new properties for business card fields and the note type.

```swift
// NoteEditorViewModel additions

enum NoteType: String, CaseIterable {
    case regularTextNote = "regular-text-note"
    case businessCard = "business-card"
}

@Published var noteType: NoteType = .regularTextNote
@Published var businessCardFirstName = ""
@Published var businessCardLastName = ""
@Published var businessCardEmail = ""
@Published var businessCardPhone = ""
@Published var businessCardCompany = ""
@Published var businessCardJobTitle = ""
@Published var businessCardWebsite = ""
@Published var businessCardAddress = ""

// Update save() to include businessCard when noteType == .businessCard
// Update load() to populate business card fields from existing note
```

---

## File Change Summary

### Backend Files

| File | Change |
|------|--------|
| `backend/lib/db/schema/notes.ts` | Add `"business-card"` to type enum, add `businessCard` JSON column, add `AddContactAction` and `BusinessCard` interfaces, update `Action` union |
| `backend/lib/schemas/notes.ts` | Add `AddContactActionSchema`, `BusinessCardSchema`, update `ActionSchema` union, update `NoteInsertSchema`/`NoteUpdateSchema`/`NoteResponseSchema` with `businessCard` field and updated type enum |
| `backend/lib/actions/note-actions.ts` | Include `businessCard` field in response mapping |
| `backend/app/preview/note/[id]/page.tsx` | Add business card rendering card, add "add-contact" action rendering, import new lucide icons |
| `backend/app/api/v1/notes/route.ts` | No direct changes needed (Zod schemas handle validation automatically) |
| `backend/app/api/v1/notes/[id]/route.ts` | No direct changes needed (Zod schemas handle validation automatically) |
| `drizzle/migrations/` | New migration file for `business_card` column |
| `backend/next.openapi.json` | Regenerated via `./scripts/openapi-generate.sh` |

### iOS App Files

| File | Change |
|------|--------|
| `RxNote/packages/RxNoteCore/Sources/RxNoteCore/openapi.json` | Regenerated via `./scripts/ios-update-openapi.sh` |
| `RxNote/packages/RxNoteCore/Sources/RxNoteCore/Extensions/` | Add `BusinessCard` and `AddContactAction` type aliases |
| `RxNote/RxNote/Views/Notes/ActionEditorView.swift` | Add `.addContact` case to `ActionType` enum, add contact form fields, update `canSave`, `saveAction()`, `prefillIfEditing()` |
| `RxNote/RxNote/Views/Notes/NoteEditorView.swift` | Add note type picker, business card form section, update `actionLabel()` and `actionButton()` for add-contact, add `addContactToAddressBook()` helper |
| `RxNote/packages/RxNoteCore/Sources/RxNoteCore/ViewModels/NoteEditorViewModel.swift` | Add `NoteType` enum, business card field properties, update `save()` and `load()` |
| `RxNote/RxNote/Info.plist` | Add `NSContactsUsageDescription` for Contacts framework permission |

### Documentation Files

| File | Change |
|------|--------|
| `backend/docs/FEATURES.md` | Add Business Card section and Add Contact action description |
| `backend/docs/API.md` | Document new `businessCard` field in request/response, document `add-contact` action type |
