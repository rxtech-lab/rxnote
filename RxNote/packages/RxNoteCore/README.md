# RxNoteCore

Swift Package for the RxNote iOS app - shared code between main app and App Clips.

## Overview

RxNoteCore is a Swift Package Manager (SPM) module containing all the shared business logic, networking, authentication, and UI components for the RxNote iOS application.

## Structure

```
RxNoteCore/
├── Package.swift
├── Sources/
│   ├── RxNoteCore/           # Main library
│   │   ├── Configuration/    # App configuration
│   │   ├── Extensions/       # Type aliases, filters, helpers
│   │   ├── Models/           # Upload models
│   │   ├── Networking/       # API client + services
│   │   ├── ViewModels/       # @Observable view models
│   │   ├── ViewModifiers/    # SwiftUI view modifiers
│   │   ├── Utilities/        # Helper utilities
│   │   ├── Macros/           # Swift macro definitions
│   │   ├── openapi.json      # Generated OpenAPI spec
│   │   └── openapi-generator-config.yaml
│   └── RxNoteCoreMacros/     # Macro implementations
└── Tests/
    └── RxNoteCoreTests/      # Unit tests
```

## Requirements

- iOS 18.0+
- macOS 15.0+
- Swift 6.2+

## Usage

```swift
import RxNoteCore

let config = AppConfiguration.shared
let apiBaseURL = config.apiBaseURL
```

## License

Private - RxLab Internal Use Only
