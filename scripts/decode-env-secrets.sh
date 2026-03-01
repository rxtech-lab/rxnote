#!/bin/bash

# Script to decode base64-encoded RXNOTE_TESTING_SECRET and write to RxNote/.env

set -e

# Get the repository root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_FILE="$REPO_ROOT/RxNote/.env"

# Check if RXNOTE_TESTING_SECRET is set
if [ -z "$RXNOTE_TESTING_SECRET" ]; then
    echo "Error: RXNOTE_TESTING_SECRET environment variable is not set"
    exit 1
fi

# Decode base64 and write to .env file
echo "$RXNOTE_TESTING_SECRET" | base64 --decode > "$OUTPUT_FILE"

echo "Successfully decoded secrets to $OUTPUT_FILE"
