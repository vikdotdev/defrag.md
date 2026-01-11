#!/bin/sh
# Test validate command with nested fragments

set -e
cd "$(dirname "$0")/.."

echo "Testing: Validate with nested fragments"

# Test validate with manifest that has nested fragments - should succeed
if ! ./zig-out/bin/defrag --config test/config.json validate --manifest test/fixtures/invalid_nesting/manifest >test/tmp/validate-04-output.txt 2>&1; then
    echo "FAIL: Validate should have succeeded"
    echo "Output:"
    cat test/tmp/validate-04-output.txt
    exit 1
fi

# Check that validation succeeded
if ! grep -q "is valid!" test/tmp/validate-04-output.txt; then
    echo "FAIL: Validation success message not found"
    echo "Output:"
    cat test/tmp/validate-04-output.txt
    exit 1
fi

# Check that all rules were found
if ! grep -q "Valid rules: 2" test/tmp/validate-04-output.txt; then
    echo "FAIL: Expected 2 valid rules"
    echo "Output:"
    cat test/tmp/validate-04-output.txt
    exit 1
fi

echo "PASS: Validate with nested fragments"