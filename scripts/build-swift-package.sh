#!/bin/bash
# Build RxNoteCore Swift package directly

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/../RxNote/packages/RxNoteCore"

cd "$PACKAGE_DIR"

# Clean and build
rm -rf .build
swift build --disable-sandbox 2>&1
