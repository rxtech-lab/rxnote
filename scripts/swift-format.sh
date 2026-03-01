#!/bin/bash

# Swift Format Script
# Formats all Swift files in the RxNote directory using SwiftFormat

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔧 Swift Format Script"
echo "====================="

# Check if SwiftFormat is installed
if ! command -v swiftformat &> /dev/null; then
    echo -e "${RED}❌ SwiftFormat is not installed${NC}"
    echo ""
    echo "Please install SwiftFormat using one of the following methods:"
    echo ""
    echo "  Homebrew:"
    echo "    brew install swiftformat"
    echo ""
    echo "  Mint:"
    echo "    mint install nicklockwood/SwiftFormat"
    echo ""
    exit 1
fi

# Get the repository root (parent of scripts directory)
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RXSTORAGE_PATH="$REPO_ROOT/RxNote"

# Check if RxNote directory exists
if [ ! -d "$RXSTORAGE_PATH" ]; then
    echo -e "${RED}❌ RxNote directory not found at: $RXSTORAGE_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found SwiftFormat: $(swiftformat --version)${NC}"
echo ""
echo "Formatting Swift files in: $RXSTORAGE_PATH"
echo ""

# Run SwiftFormat
swiftformat "$RXSTORAGE_PATH" \
    --exclude "**/Pods,**/Carthage,**/DerivedData,**/.build" \
    --verbose

echo ""
echo -e "${GREEN}✅ Swift formatting complete!${NC}"
