#!/bin/sh
# Test new command with existing database

set -e
cd "$(dirname "$0")/.."

echo "Testing: New command - database exists"

# Create an existing database
mkdir -p test/tmp/existing-db

# Test new with existing database (should fail)
if ./zig-out/bin/defrag new test/tmp/existing-db 2>test/tmp/new-03-stderr.txt; then
    echo "FAIL: new should fail when database exists"
    exit 1
fi

# Check error message
if ! grep -q "already exists" test/tmp/new-03-stderr.txt; then
    echo "FAIL: Expected 'already exists' error"
    cat test/tmp/new-03-stderr.txt
    exit 1
fi

echo "PASS: New command - database exists"
