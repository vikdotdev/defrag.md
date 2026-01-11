#!/bin/sh
# Test new command

set -e
cd "$(dirname "$0")/.."

echo "Testing: New command"

# Clean up from previous runs
rm -rf test/tmp/testdb

# Test creating new database - capture output
./zig-out/bin/defrag new testdb > test/tmp/new-01-output.txt 2>&1
mv testdb test/tmp/

# Create expected output for new command
cat > test/tmp/new-01-expected.txt <<'EOF'
Creating new database: testdb
Created: testdb/default.manifest
Created: testdb/fragments/example.md

Next steps:
  1. Edit testdb/default.manifest
  2. Add fragments to testdb/fragments/
  3. Build with: defrag build testdb/default.manifest
EOF

# Compare actual vs expected
if ! diff -q "test/tmp/new-01-output.txt" "test/tmp/new-01-expected.txt" >/dev/null 2>&1; then
    echo "FAIL: New command output does not match expected"
    echo "Expected:"
    cat "test/tmp/new-01-expected.txt"
    echo ""
    echo "Actual:"
    cat "test/tmp/new-01-output.txt"
    echo ""
    echo "Diff:"
    diff "test/tmp/new-01-expected.txt" "test/tmp/new-01-output.txt" || true
    exit 1
fi

# Check that files were actually created
if [ ! -d "test/tmp/testdb" ] || [ ! -f "test/tmp/testdb/default.manifest" ] || [ ! -f "test/tmp/testdb/fragments/example.md" ]; then
    echo "FAIL: Required files/directories not created"
    exit 1
fi

# Verify manifest content
cat > test/tmp/new-01-expected-manifest <<'EOF'
[config]
heading_wrapper_template = "# Rule: {fragment_id}"

[fragments]
| example
EOF

if ! diff -q "test/tmp/testdb/default.manifest" "test/tmp/new-01-expected-manifest" >/dev/null 2>&1; then
    echo "FAIL: Generated manifest does not match expected"
    echo "Expected:"
    cat "test/tmp/new-01-expected-manifest"
    echo ""
    echo "Actual:"
    cat "test/tmp/testdb/default.manifest"
    exit 1
fi

echo "PASS: New command"
