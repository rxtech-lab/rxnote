# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Next.js backend for RxNote - a quick note-taking app with App Clips support. Uses direct Turso/Drizzle database access, provides REST APIs for the iOS mobile app, and serves public note preview pages.

## Commands

```bash
bun run dev       # Development server at http://localhost:3000
bun run build     # Production build
bun run lint      # ESLint
bun run db:push   # Push schema to database
bun run db:studio # Open Drizzle Studio
```

## Tech Stack

- Next.js 16 (App Router), React 19, TypeScript (strict)
- Turso (SQLite) with Drizzle ORM
- Auth.js with OAuth 2.0 OIDC via auth.rxlab.app
- Tailwind CSS v4, shadcn/ui
- Mapbox GL for location display on preview pages
- QRCode for QR code generation

## Key Patterns

**Server Actions with Drizzle** - Preferred pattern for all CRUD operations with direct database access:
```typescript
// lib/actions/note-actions.ts
"use server";
export async function createNoteAction(data, userId) {
  // Direct Drizzle queries
  return db.insert(notes).values(data).returning();
}
```

**Direct Database Access** - No external backend API. All operations use Drizzle ORM.

## Directory Structure

```
app/
├── (auth)/              # Public auth routes (login)
├── (legal)/             # Privacy, terms, support pages
├── preview/note/[id]/   # Public note preview (with App Clips support)
├── .well-known/         # Apple App Site Association for App Clips
└── api/v1/              # REST API for iOS app
    ├── notes/           # Note CRUD + whitelist
    ├── qrcode/scan/     # QR code scanning
    ├── upload/presigned/ # S3 file upload
    └── account/delete/  # Account deletion

components/
├── ui/                  # shadcn/ui components
└── maps/                # Mapbox map components (location display)

lib/
├── db/                  # Drizzle schema and client
│   ├── index.ts         # Database client
│   └── schema/          # Table schemas (notes, note-whitelists, upload-files, account-deletions)
├── actions/             # Server Actions (CRUD)
├── schemas/             # Zod validation schemas
└── utils/               # Utilities (pagination, file helpers)
```

## Database Schema

| Table | Purpose |
|-------|---------|
| `notes` | Notes with title, markdown content, images, location, actions, visibility |
| `note_whitelists` | Email whitelist for private notes |
| `upload_files` | S3 file upload tracking |
| `account_deletions` | Account deletion requests with 24h grace period |

### Note Visibility Levels

- `public` - Accessible to anyone without authentication
- `auth-only` - Accessible to any authenticated user
- `private` - Only accessible to owner or whitelisted email addresses

### Note Actions

Notes can have typed actions stored as JSON:
- `url` - External link with label and URL
- `wifi` - WiFi credentials with SSID, password, encryption

## Key Files

| File | Purpose |
|------|---------|
| `auth.ts` | Auth.js OAuth 2.0 config with token refresh |
| `proxy.ts` | Route protection middleware |
| `lib/db/index.ts` | Drizzle client with Turso |
| `lib/db/schema/` | All table schemas |
| `lib/actions/note-actions.ts` | Note CRUD operations |
| `lib/actions/note-whitelist-actions.ts` | Whitelist management |
| `lib/schemas/notes.ts` | Zod schemas for note validation |

## Environment Variables

Required in `.env`:
- `AUTH_SECRET`, `AUTH_ISSUER`, `AUTH_CLIENT_ID`, `AUTH_CLIENT_SECRET` - OAuth config
- `TURSO_DATABASE_URL` - Turso database URL
- `TURSO_AUTH_TOKEN` - Turso auth token
- `NEXT_PUBLIC_MAPBOX_ACCESS_TOKEN` - Mapbox access token
- `NEXT_PUBLIC_URL` - Public URL for preview links

Optional (for iOS App Clips):
- `APPLE_APP_CLIP_BUNDLE_ID` - App Clips bundle ID
- `APPLE_APP_BUNDLE_ID` - Main app bundle ID

## E2E Testing

E2E tests use Playwright and run against an **in-memory SQLite database** (not the real Turso database).

```bash
bunx playwright test              # Run all E2E tests
bunx playwright test e2e/api      # Run API tests only
```

**Key files:**
- `playwright.config.ts` - Playwright configuration
- `playwright.global-setup.ts` - Test setup
- `lib/db/client.ts` - Creates in-memory DB when `IS_E2E=true`
- `lib/db/init-schema.ts` - Initializes schema from migration file
- `lib/db/migrations/0000_notes_schema.sql` - Schema SQL for in-memory DB

**Important:** When adding new columns to schema files in `lib/db/schema/`, you must also update the migration SQL file at `lib/db/migrations/0000_notes_schema.sql` for E2E tests to work.

**Multi-user testing:** Use `X-Test-User-Id` header to simulate different users in E2E tests.
