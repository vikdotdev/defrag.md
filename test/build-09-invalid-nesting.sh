#!/bin/sh
# Test build command with nested fragments

set -e
cd "$(dirname "$0")/.."

echo "Testing: Build with nested fragments"

# Test build with manifest that has nested fragments - should succeed
if ! ./zig-out/bin/defrag --config test/config.json build --manifest test/fixtures/invalid_nesting/manifest --out test/tmp/build-09-invalid-nesting.md 2>test/tmp/build-09-stderr.txt; then
    echo "FAIL: Build should have succeeded"
    echo "Stderr output:"
    cat test/tmp/build-09-stderr.txt
    exit 1
fi

# Check that output file was created
if [ ! -f "test/tmp/build-09-invalid-nesting.md" ]; then
    echo "FAIL: Output file should have been created"
    exit 1
fi

# Check content is present
if ! grep -q "Rule: invalid_nesting/parent" test/tmp/build-09-invalid-nesting.md; then
    echo "FAIL: Parent rule should be in output"
    exit 1
fi

if ! grep -q "Rule: invalid_nesting/deep-child" test/tmp/build-09-invalid-nesting.md; then
    echo "FAIL: Deep child rule should be in output"
    exit 1
fi

echo "PASS: Build with nested fragments"