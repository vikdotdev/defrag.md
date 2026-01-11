#!/bin/sh
# Test cross-database inclusion functionality

set -e
cd "$(dirname "$0")/.."

echo "Testing: Cross-database inclusion"

# Test build with cross-database includes
./zig-out/bin/defrag --config test/config-cross-database.json build --manifest test/fixtures/cross_database/main/manifest --out test/tmp/build-11-cross-database.md

# Check that output file was created
if [ ! -f "test/tmp/build-11-cross-database.md" ]; then
    echo "FAIL: Output file not created"
    exit 1
fi

# Create expected output
cat > test/tmp/build-11-expected.md <<'EOF'
# Rule: main/local-rule
## Local Rule

This is a rule local to the main database.

# Rule: shared/common-rule
## Common Shared Rule

This rule is shared across databases.

## Rule: shared/nested-shared
### Nested Shared Rule

This shared rule should appear as a nested item.

# Rule: main/another-local
## Another Local Rule

Another rule in the main database.
EOF

# Compare actual vs expected
if ! diff -q "test/tmp/build-11-cross-database.md" "test/tmp/build-11-expected.md" >/dev/null 2>&1; then
    echo "FAIL: Cross-database inclusion output does not match expected"
    echo "Expected:"
    cat "test/tmp/build-11-expected.md"
    echo ""
    echo "Actual:"
    cat "test/tmp/build-11-cross-database.md"
    echo ""
    echo "Diff:"
    diff "test/tmp/build-11-expected.md" "test/tmp/build-11-cross-database.md" || true
    exit 1
fi

echo "PASS: Cross-database inclusion"