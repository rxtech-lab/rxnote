# RxNote iOS App

A quick note-taking iOS app with OAuth authentication, QR code support, and App Clips integration.

## Project Structure

```
RxNote/
├── RxNote/                      # Main app target
│   ├── Config/                     # Build configurations (xcconfig)
│   ├── Models/                     # App-level models (WebPage)
│   ├── Navigation/                 # NavigationManager
│   ├── Views/                      # SwiftUI views
│   │   ├── Notes/                  # Note list, editor, detail
│   │   ├── QRCode/                 # QR scanning, generation, printing
│   │   ├── AppClip/                # App Clips views
│   │   ├── Settings/               # Settings and account management
│   │   ├── TabBar/                 # iPhone tab navigation
│   │   └── Sidebar/                # iPad sidebar navigation
│   ├── ContentView.swift           # Auth state + Login/Main view
│   └── RxNoteApp.swift          # App entry point
├── packages/RxNoteCore/            # SPM framework (shared code)
│   ├── Sources/RxNoteCore/
│   │   ├── Configuration/          # App config
│   │   ├── Extensions/             # TypeAliases, FilterTypes, HelperTypes
│   │   ├── Networking/             # API client + services
│   │   ├── ViewModels/             # @Observable view models
│   │   ├── Macros/                 # Swift macro definitions
│   │   ├── openapi.json            # Generated OpenAPI spec
│   │   └── openapi-generator-config.yaml
│   └── Tests/RxNoteCoreTests/      # Unit tests
├── RxNoteClips/                 # App Clips target
├── RxNoteTests/                 # Unit tests
└── RxNoteUITests/               # UI tests
```

## Quick Start

1. Copy `RxNote/Config/Secrets.xcconfig.example` to `Secrets.xcconfig`
2. Add your OAuth client IDs
3. Open `RxNote.xcodeproj` in Xcode
4. Build and run (Cmd+R)

## Build & Test

```bash
# From repository root
./scripts/ios-build.sh     # Build for simulator
./scripts/ios-test.sh      # Run unit tests
./scripts/ios-ui-test.sh   # Run UI tests (requires backend)
```

## Architecture

- **iOS 18+** with @Observable macro and async/await
- **Swift OpenAPI Generator** for type-safe API client
- **OAuth 2.0 PKCE** authentication
- **RxNoteCore** SPM package shared between main app and App Clips
- **NavigationSplitView** for adaptive iPad/iPhone layout
