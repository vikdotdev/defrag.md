#!/bin/sh
# Test validate command with missing manifest file

set -e
cd "$(dirname "$0")/.."

echo "Testing: Validate with missing manifest file"

# Test validate with non-existent manifest file
if ./zig-out/bin/defrag --config test/config.json validate --manifest test/fixtures/nonexistent/manifest 2>test/tmp/validate-02-stderr.txt; then
    echo "FAIL: Validate should have failed with missing manifest"
    exit 1
fi

# Check that proper error message was displayed
if ! grep -q "ERROR: Manifest file not found" test/tmp/validate-02-stderr.txt; then
    echo "FAIL: Expected error message not found"
    echo "Stderr output:"
    cat test/tmp/validate-02-stderr.txt
    exit 1
fi

echo "PASS: Validate correctly fails with missing manifest"