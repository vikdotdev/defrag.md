#!/bin/sh
# Test new command with missing database name

set -e
cd "$(dirname "$0")/.."

echo "Testing: New command - missing database name"

# Test new without database name (should fail)
if ./zig-out/bin/defrag new 2>test/tmp/new-02-stderr.txt; then
    echo "FAIL: new should fail without database name"
    exit 1
fi

# Check error message
if ! grep -q "Missing required argument" test/tmp/new-02-stderr.txt; then
    echo "FAIL: Expected 'Missing required argument' error"
    cat test/tmp/new-02-stderr.txt
    exit 1
fi

echo "PASS: New command - missing database name"
