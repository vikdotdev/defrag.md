#!/bin/sh
# Test build with nested fragments

set -e
cd "$(dirname "$0")/.."

echo "Testing: Build with nested fragments"

# Test build with nested fragments - should succeed
./zig-out/bin/defrag --config test/config.json build --manifest test/fixtures/nesting_warning/manifest --out test/tmp/build-12-nesting-warning.md 2>test/tmp/build-12-stderr.txt

# Check that output file was created
if [ ! -f "test/tmp/build-12-nesting-warning.md" ]; then
    echo "FAIL: Output file not created"
    exit 1
fi

# Create expected output
cat > test/tmp/build-12-expected.md <<'EOF'
# Rule: nesting_warning/parent
## Parent Rule

This is a parent rule.

## Rule: nesting_warning/deeply-nested
### Deeply Nested Rule

This should be treated as level 2, not 3.

# Rule: nesting_warning/another-parent
## Another Parent Rule

Another parent rule.
EOF

# Compare actual vs expected
if ! diff -q "test/tmp/build-12-nesting-warning.md" "test/tmp/build-12-expected.md" >/dev/null 2>&1; then
    echo "FAIL: Output does not match expected"
    echo "Expected:"
    cat "test/tmp/build-12-expected.md"
    echo ""
    echo "Actual:"
    cat "test/tmp/build-12-nesting-warning.md"
    echo ""
    echo "Diff:"
    diff "test/tmp/build-12-expected.md" "test/tmp/build-12-nesting-warning.md" || true
    exit 1
fi

echo "PASS: Build with nested fragments"