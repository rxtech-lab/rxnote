# RxNote Backend

Next.js backend for the RxNote app — provides REST APIs consumed by the iOS app and public note preview pages.

## Quick Start

```bash
bun install

# Set up environment variables
cp .env.example .env
# Edit .env with your credentials (see Environment Variables below)

# Push schema to database
bun run db:push

# Start development server
bun run dev         # http://localhost:3000
```

## Features

- **Note Management** — CRUD operations for notes with markdown, images, location, and actions
- **Visibility Control** — Public, auth-only, and private notes with email whitelist
- **Note Actions** — Attach typed actions (URL links, WiFi credentials) to notes
- **QR Code API** — Resolve QR code scans to note IDs
- **Public Previews** — Server-rendered note preview pages with Mapbox location display
- **App Clips Support** — Apple App Site Association and App Clip banner on preview pages
- **File Uploads** — S3 presigned URL generation for image uploads
- **REST API** — Full API at `/api/v1` for iOS app consumption

## Tech Stack

- **Framework**: Next.js 16 (App Router), React 19, TypeScript (strict)
- **Database**: Turso (SQLite) with Drizzle ORM
- **Auth**: Auth.js with OAuth 2.0 OIDC via auth.rxlab.app
- **UI**: Tailwind CSS v4, shadcn/ui
- **Maps**: Mapbox GL / react-map-gl
- **Validation**: Zod
- **QR Codes**: qrcode

## Project Structure

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
│       ├── upload/presigned/ # S3 presigned file uploads
│       └── account/delete/  # Account deletion
├── components/
│   ├── ui/                  # shadcn/ui components
│   └── maps/                # Mapbox map components
├── lib/
│   ├── db/                  # Drizzle schema and client
│   │   ├── index.ts         # Database client (Turso)
│   │   └── schema/          # Table schemas
│   ├── actions/             # Server Actions (CRUD)
│   ├── schemas/             # Zod validation schemas
│   └── utils/               # Utilities (pagination, file helpers)
└── e2e/                     # Playwright E2E tests
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `AUTH_SECRET` | Auth.js secret |
| `AUTH_ISSUER` | OAuth 2.0 issuer URL |
| `AUTH_CLIENT_ID` | OAuth client ID |
| `AUTH_CLIENT_SECRET` | OAuth client secret |
| `TURSO_DATABASE_URL` | Turso database URL |
| `TURSO_AUTH_TOKEN` | Turso auth token |
| `NEXT_PUBLIC_MAPBOX_ACCESS_TOKEN` | Mapbox access token |
| `NEXT_PUBLIC_URL` | Public URL for preview links and QR codes |

## Scripts

```bash
bun run dev           # Development server
bun run build         # Production build (includes db:push + openapi:generate)
bun run lint          # ESLint
bun run test          # Unit tests (Vitest)
bun run test:e2e      # End-to-end tests (Playwright)
bun run db:push       # Push schema to database
bun run db:studio     # Open Drizzle Studio
```

## API Reference

The backend exposes a REST API under `/api/v1`. See [`next.openapi.json`](./next.openapi.json) for the full OpenAPI specification.

## License

Private — RxLab Internal Use Only

