#!/bin/sh
# Test comment handling in manifests

set -e
cd "$(dirname "$0")/.."

echo "Testing: Comment handling"

# Use basic fixture which has commented rule
./zig-out/bin/defrag --config test/config.json build --manifest test/fixtures/basic/manifest --out test/tmp/build-02-comments.md

# Check that output file was created
if [ ! -f "test/tmp/build-02-comments.md" ]; then
    echo "FAIL: Output file not created"
    exit 1
fi

# Create expected output - should be identical to basic build test since we're using same fixture
cat > test/tmp/build-02-expected.md <<'EOF'
# Rule: basic/rule1
## Rule One

This is the first rule.

### Details

Some basic content here.

# Rule: basic/rule2
## Rule Two

This is the second rule.

### Guidelines

  - Point one
  - Point two
  - Point three
EOF

# Compare actual vs expected - this verifies that commented rules are properly ignored
if ! diff -q "test/tmp/build-02-comments.md" "test/tmp/build-02-expected.md" >/dev/null 2>&1; then
    echo "FAIL: Output does not match expected (commented rule may have been included)"
    echo "Expected:"
    cat "test/tmp/build-02-expected.md"
    echo ""
    echo "Actual:"
    cat "test/tmp/build-02-comments.md"
    echo ""
    echo "Diff:"
    diff "test/tmp/build-02-expected.md" "test/tmp/build-02-comments.md" || true
    exit 1
fi

echo "PASS: Comment handling"