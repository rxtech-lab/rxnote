# CLAUDE.md

**You don't have access to cd cmd, please write a script in the root and run it when command needs cd**

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dual-platform quick note-taking app:

- **Backend** (`/backend`) - Next.js app providing REST APIs for the mobile app and public note preview pages
- **iOS App** (`/RxNote`) - Swift mobile app with App Clips support for QR code/NFC interactions

## Commands

```bash
# Backend (uses Bun)
cd backend
bun run dev       # Development server at http://localhost:3000
bun run build     # Production build
bun run lint      # ESLint
bun run db:push   # Push schema to database
bun run db:studio # Open Drizzle Studio

# iOS App
./scripts/ios-build.sh   # Build for iOS Simulator (Debug config)
./scripts/ios-test.sh    # Run unit tests
./scripts/ios-ui-test.sh # Run UI tests
open RxNote/RxNote.xcodeproj  # Open in Xcode
```

## Backend Architecture

### Tech Stack

- Next.js 16 (App Router), React 19, TypeScript (strict)
- Turso (SQLite) with Drizzle ORM for direct database access
- Auth.js with OAuth 2.0 OIDC via auth.rxlab.app
- Tailwind CSS v4, shadcn/ui
- Mapbox GL for location display on preview pages
- QRCode for QR code generation
- Provides REST APIs consumed by mobile app

### Key Patterns

**Server Actions over REST API** - All CRUD operations use Server Actions in `/lib/actions/` with direct Drizzle queries:

```typescript
// lib/actions/note-actions.ts
"use server";
export async function createNoteAction(data, userId) {
  // Direct Drizzle database queries
}
```

**Direct Database Access** - No external backend API. All database operations use Drizzle ORM with Turso.

### Directory Structure

```
backend/
├── app/
│   ├── (auth)/              # Public auth routes (login)
│   ├── (legal)/             # Privacy, terms, support pages
│   ├── preview/note/[id]/   # Public note preview (with App Clips support)
│   ├── .well-known/         # Apple App Site Association
│   └── api/v1/              # REST API for iOS app
│       ├── notes/           # Note CRUD + whitelist
│       ├── qrcode/scan/     # QR code scanning
│       ├── upload/presigned/ # S3 file upload
│       └── account/delete/  # Account deletion
├── components/
│   ├── ui/                  # shadcn/ui components
│   └── maps/                # Mapbox map components
├── lib/
│   ├── db/                  # Drizzle schema and client
│   │   ├── index.ts         # Database client
│   │   └── schema/          # Table schemas (notes, note-whitelists, upload-files, account-deletions)
│   ├── actions/             # Server Actions (CRUD)
│   ├── schemas/             # Zod validation schemas
│   └── utils/               # Utilities (pagination, file helpers)
└── e2e/                     # Playwright E2E tests
```

### Database Schema

| Table               | Purpose                                              |
| ------------------- | ---------------------------------------------------- |
| `notes`             | Notes with title, markdown, images, location, actions, visibility |
| `note_whitelists`   | Email whitelist for private notes                    |
| `upload_files`      | S3 file upload tracking                              |
| `account_deletions` | Account deletion requests with 24h grace period      |

### Note Visibility Levels

- `public` - Accessible to anyone without authentication
- `auth-only` - Accessible to any authenticated user
- `private` - Only accessible to owner or whitelisted email addresses

### Note Actions

Notes can have typed actions stored as JSON:
- `url` - External link with label and URL
- `wifi` - WiFi credentials with SSID, password, encryption

### Key Files

| File                           | Purpose                                     |
| ------------------------------ | ------------------------------------------- |
| `auth.ts`                      | Auth.js OAuth 2.0 config with token refresh |
| `proxy.ts`                     | Route protection middleware                 |
| `lib/db/index.ts`              | Drizzle client with Turso                   |
| `lib/db/schema/`               | All table schemas                           |
| `lib/actions/note-actions.ts`  | Note CRUD operations                        |
| `lib/schemas/notes.ts`         | Zod schemas for note validation             |
| `drizzle.config.ts`            | Drizzle configuration                       |

### Environment Variables

Required in `/backend/.env`:

- `AUTH_SECRET`, `AUTH_ISSUER`, `AUTH_CLIENT_ID`, `AUTH_CLIENT_SECRET` - OAuth config
- `TURSO_DATABASE_URL` - Turso database URL
- `TURSO_AUTH_TOKEN` - Turso auth token
- `NEXT_PUBLIC_MAPBOX_ACCESS_TOKEN` - Mapbox access token
- `NEXT_PUBLIC_URL` - Public URL for preview links

## iOS Mobile App Architecture

### Tech Stack

- Swift with SwiftUI (iOS 18+)
- @Observable macro for state management (no SwiftData)
- OAuth 2.0 PKCE authentication via auth.rxlab.app
- Bearer token authentication for API requests
- RxNoteCore SPM framework (shared between main app and App Clips)
- NavigationSplitView for adaptive iPad/iPhone layout
- Swift OpenAPI Generator for API client codegen

### Two Modes

**Full App Mode** - Requires installation and OAuth authentication

- Full CRUD operations on notes
- Complete access to all features
- Pull-to-refresh on lists

**App Clips Mode** - Triggered by QR code or NFC chip scan

- View note details only (no create/update/delete)
- Three access levels:
  - **Public**: No authentication required
  - **Auth-only**: Requires authentication
  - **Private**: Requires authentication + whitelist

### Directory Structure

```
RxNote/
├── RxNote/                      # Main app target
│   ├── Config/                     # Build configurations
│   │   ├── Debug.xcconfig          # Dev environment (localhost)
│   │   ├── Release.xcconfig        # Prod environment
│   │   └── Secrets.xcconfig        # OAuth client IDs (gitignored)
│   ├── Info.plist                  # Uses $(VARIABLE) substitution
│   ├── Navigation/                 # NavigationManager
│   ├── Views/
│   │   ├── Notes/                  # Note list, editor, detail views
│   │   ├── QRCode/                 # QR scanning, generation, printing
│   │   ├── AppClip/                # App Clips views
│   │   ├── Settings/               # Settings and account management
│   │   ├── TabBar/                 # iPhone tab navigation
│   │   └── Sidebar/                # iPad sidebar navigation
│   ├── ContentView.swift           # Auth state + Login/Main view
│   └── RxNoteApp.swift          # App entry point
├── packages/RxNoteCore/            # SPM framework (shared code)
│   └── Sources/RxNoteCore/
│       ├── Models/                 # Custom models (Upload, etc.)
│       ├── Extensions/             # TypeAliases, FilterTypes, HelperTypes
│       ├── Networking/             # APIClient + Services
│       ├── Configuration/          # AppConfiguration
│       ├── openapi.json            # Generated OpenAPI spec
│       └── openapi-generator-config.yaml
├── RxNoteClips/                 # App Clips target
├── RxNoteTests/                 # Unit tests
└── RxNoteUITests/               # UI tests
```

### Configuration System

**xcconfig Files** - Environment-based configuration:

- `Debug.xcconfig` - Development (localhost API)
- `Release.xcconfig` - Production (rxlab.app API)
- `Secrets.xcconfig` - OAuth client IDs (gitignored, must create locally)

### Authentication Flow

**OAuth 2.0 PKCE Flow:**

1. User taps "Sign in with RxLab" in LoginView
2. OAuthManager launches ASWebAuthenticationSession
3. User authenticates at auth.rxlab.app
4. Callback to `rxnote://oauth/callback` with auth code
5. Exchange code for access/refresh tokens
6. Store tokens securely in Keychain via TokenStorage
7. Inject Bearer token in all API requests via APIClient

**URL Scheme:** `rxnote://`

### Key Features

- **OAuth Login** - ASWebAuthenticationSession with PKCE
- **Bearer Token Auth** - Secure API authentication via Keychain
- **Pull to Refresh** - Available on all list views
- **NavigationSplitView** - Two-column layout on iPad, stack on iPhone
- **QR Code Support** - Generate, scan, print QR codes for notes
- **App Clips** - View-only mode triggered by QR/NFC
- **Note Editor** - Title, markdown content, images, location, actions

### UI Patterns

**Confirmation Dialogs** - Use the custom `.confirmationDialog` modifier:

```swift
.confirmationDialog(
    title: "Delete Note",
    message: "Are you sure?",
    isPresented: $showDeleteConfirmation,
    onConfirm: { /* delete */ }
)
```

See `Views/Modifiers/ConfirmationDialogModifier.swift` for the implementation.

### Testing

```bash
./scripts/ios-test.sh      # Unit tests (Swift Package tests)
./scripts/ios-ui-test.sh   # UI tests (requires backend running)
```

### Team Setup

1. Clone repository
2. Install dependencies: `cd backend && bun install`
3. Copy `RxNote/RxNote/Config/Secrets.xcconfig.example` to `Secrets.xcconfig`
4. Contact team for OAuth client IDs and add to `Secrets.xcconfig`
5. Open `RxNote/RxNote.xcodeproj` in Xcode
6. Build and run (Cmd+R)

## Build and test

Since you don't have access to cd, run `scripts/ios-test.sh` and `scripts/ios-build.sh` script to build and test the iOS mobile app which includes testing the app and its packages.

## OpenAPI

APIs are defined in OpenAPI format and use codegen for both backend and iOS mobile app. When updating the backend API, run `./scripts/ios-update-openapi.sh` to regenerate clients. This will regenerate both the OpenAPI spec and Swift client types. Use this always!
