#!/bin/bash

# macOS UI Test Script for CI/CD
# Runs UI tests for the RxNote macOS app

set -e  # Exit on error
set -o pipefail  # Catch errors in pipes

echo "======================================"
echo "RxNote macOS UI Test Script"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_PATH="RxNote/RxNote.xcodeproj"
SCHEME="${SCHEME:-RxNoteUITests}"
CONFIGURATION="${CONFIGURATION:-Debug}"
BUILD_DIR="${BUILD_DIR:-.build}"
RESULT_BUNDLE_PATH="${RESULT_BUNDLE_PATH:-macos-ui-test-results.xcresult}"
LOG_FILE="${LOG_FILE:-macos-ui-test.log}"

# Use generic macOS destination - let Xcode pick the architecture
DESTINATION="platform=macOS"
ARCH=$(uname -m)

# Check if project exists
if [ ! -d "$PROJECT_PATH" ]; then
    echo -e "${RED}❌ Error: $PROJECT_PATH not found${NC}"
    echo "Current directory: $(pwd)"
    exit 1
fi

# Check if Secrets.xcconfig exists
SECRETS_CONFIG="RxNote/RxNote/Config/Secrets.xcconfig"
if [ ! -f "$SECRETS_CONFIG" ]; then
    echo -e "${YELLOW}⚠️  Warning: $SECRETS_CONFIG not found${NC}"
    echo "This file should be created from GitHub secrets in CI or manually for local builds."
fi

# Check if test credentials are set
if [ -z "$TEST_EMAIL" ] || [ -z "$TEST_PASSWORD" ]; then
    echo -e "${YELLOW}⚠️  Warning: TEST_EMAIL or TEST_PASSWORD not set${NC}"
    echo "UI tests may fail without valid test credentials."
    echo "Set these environment variables before running UI tests:"
    echo "  export TEST_EMAIL=your-test-email@example.com"
    echo "  export TEST_PASSWORD=your-test-password"
    echo ""
fi

echo -e "${BLUE}📦 Project:${NC} $PROJECT_PATH"
echo -e "${BLUE}🎯 Scheme:${NC} $SCHEME"
echo -e "${BLUE}⚙️  Configuration:${NC} $CONFIGURATION"
echo -e "${BLUE}🖥️  Destination:${NC} $DESTINATION"
echo -e "${BLUE}🖥️  Architecture:${NC} $ARCH"
echo -e "${BLUE}📂 Build Directory:${NC} $BUILD_DIR"
echo -e "${BLUE}📊 Result Bundle:${NC} $RESULT_BUNDLE_PATH"
echo -e "${BLUE}📝 Log File:${NC} $LOG_FILE"
echo ""

# Clean previous test results
echo "🧹 Cleaning previous test results..."
rm -rf "$RESULT_BUNDLE_PATH"
rm -f "$LOG_FILE"

echo ""

# Step 1: Build for testing
echo "🔨 Building for macOS UI tests..."
echo ""

if command -v xcbeautify &> /dev/null; then
    xcodebuild build-for-testing \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        -derivedDataPath "$BUILD_DIR" \
        -skipPackagePluginValidation \
        CODE_SIGNING_REQUIRED=YES \
        CODE_SIGNING_ALLOWED=YES \
        ONLY_ACTIVE_ARCH=YES \
        SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD=NO \
        ENABLE_APP_THINNING=NO \
        2>&1 | tee "$LOG_FILE" | xcbeautify
    BUILD_EXIT_CODE=${PIPESTATUS[0]}
else
    xcodebuild build-for-testing \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        -derivedDataPath "$BUILD_DIR" \
        -skipPackagePluginValidation \
        CODE_SIGNING_REQUIRED=YES \
        CODE_SIGNING_ALLOWED=YES \
        ONLY_ACTIVE_ARCH=YES \
        SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD=NO \
        ENABLE_APP_THINNING=NO \
        2>&1 | tee "$LOG_FILE"
    BUILD_EXIT_CODE=${PIPESTATUS[0]}
fi

if [ $BUILD_EXIT_CODE -ne 0 ]; then
    echo -e "${RED}❌ Build for testing failed!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Build for testing completed${NC}"
echo ""

# Step 2: Clear quarantine attributes to prevent "damaged app" errors
echo "🔓 Clearing quarantine attributes from build products..."
xattr -cr "$BUILD_DIR" 2>/dev/null || true
echo ""

# Step 3: Run tests without building
echo "🧪 Running macOS UI tests..."
echo ""
echo "🖥️  This will run tests directly on macOS."
echo "⏱️  This may take several minutes. Logs will appear as tests run."
echo ""

set +e  # Temporarily disable exit on error to capture the exit code

# Use xcbeautify for pretty printing if available, otherwise raw output
if command -v xcbeautify &> /dev/null; then
    TEST_EMAIL="$TEST_EMAIL" TEST_PASSWORD="$TEST_PASSWORD" xcodebuild test-without-building \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        -derivedDataPath "$BUILD_DIR" \
        -resultBundlePath "$RESULT_BUNDLE_PATH" \
        -parallel-testing-enabled NO \
        2>&1 | tee -a "$LOG_FILE" | xcbeautify
    TEST_EXIT_CODE=${PIPESTATUS[0]}
else
    TEST_EMAIL="$TEST_EMAIL" TEST_PASSWORD="$TEST_PASSWORD" xcodebuild test-without-building \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        -derivedDataPath "$BUILD_DIR" \
        -resultBundlePath "$RESULT_BUNDLE_PATH" \
        -parallel-testing-enabled NO \
        2>&1 | tee -a "$LOG_FILE"
    TEST_EXIT_CODE=${PIPESTATUS[0]}
fi

set -e  # Re-enable exit on error

echo ""
echo "======================================"

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ All macOS UI tests passed!${NC}"
    echo ""
    echo "Test log saved to: $LOG_FILE"
    echo "Result bundle saved to: $RESULT_BUNDLE_PATH"

    # Extract and display test logs from result bundle
    if command -v xcrun &> /dev/null && [ -d "$RESULT_BUNDLE_PATH" ]; then
        echo ""
        echo "📝 Test Logs (NSLog output):"
        echo "======================================"

        # Extract standard output which contains NSLog statements
        xcrun xcresulttool get --path "$RESULT_BUNDLE_PATH" 2>/dev/null | \
            grep -E "🔐|⏱️|✅|❌|Safari|field|password|email|sign-in" || \
            echo "No NSLog statements found in test output"

        echo ""
        echo "Full test output saved to: macos-ui-test-details.log"
        xcrun xcresulttool get --path "$RESULT_BUNDLE_PATH" > macos-ui-test-details.log 2>&1 || true
    fi

    exit 0
else
    echo -e "${RED}❌ macOS UI tests failed!${NC}"
    echo ""
    echo "Test log saved to: $LOG_FILE"
    echo "Result bundle saved to: $RESULT_BUNDLE_PATH"

    # Extract and display test logs from result bundle on failure
    if command -v xcrun &> /dev/null && [ -d "$RESULT_BUNDLE_PATH" ]; then
        echo ""
        echo "📝 Test Logs (NSLog output):"
        echo "======================================"

        # Extract standard output which contains NSLog statements
        xcrun xcresulttool get --path "$RESULT_BUNDLE_PATH" 2>/dev/null | \
            grep -E "🔐|⏱️|✅|❌|Safari|field|password|email|sign-in" || \
            echo "No NSLog statements found in test output"

        echo ""
        echo "Full test output saved to: macos-ui-test-details.log"
        xcrun xcresulttool get --path "$RESULT_BUNDLE_PATH" > macos-ui-test-details.log 2>&1 || true
    fi

    echo ""
    echo "Common issues:"
    echo "1. Check test failures in the log above"
    echo "2. Verify backend server is running at http://localhost:3000"
    echo "3. Ensure TEST_EMAIL and TEST_PASSWORD are set correctly"
    echo "4. Grant accessibility permissions for UI testing in System Settings"
    echo "5. Review OAuth configuration in Secrets.xcconfig"
    echo ""
    echo "See $LOG_FILE for full error details"
    exit 1
fi
