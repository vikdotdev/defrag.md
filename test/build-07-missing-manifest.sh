#!/bin/sh
# Test build command with missing manifest file

set -e
cd "$(dirname "$0")/.."

echo "Testing: Build with missing manifest file"

# Test build with non-existent manifest file
if ./zig-out/bin/defrag --config test/config.json build --manifest test/fixtures/nonexistent/manifest --out test/tmp/build-07-missing-manifest.md 2>test/tmp/build-07-stderr.txt; then
    echo "FAIL: Build should have failed with missing manifest"
    exit 1
fi

# Check that proper error message was displayed
if ! grep -q "ERROR: Manifest file not found" test/tmp/build-07-stderr.txt; then
    echo "FAIL: Expected error message not found"
    echo "Stderr output:"
    cat test/tmp/build-07-stderr.txt
    exit 1
fi

# Check that no output file was created
if [ -f "test/tmp/build-07-missing-manifest.md" ]; then
    echo "FAIL: Output file should not have been created"
    exit 1
fi

echo "PASS: Build correctly fails with missing manifest"