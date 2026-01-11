#!/bin/sh
# Test simple nested hierarchy

set -e
cd "$(dirname "$0")/.."

echo "Testing: Simple nested hierarchy"

# Test build with nested fixture
./zig-out/bin/defrag --config test/config.json build --manifest test/fixtures/nested/manifest --out test/tmp/build-05-nested.md

# Check that output file was created
if [ ! -f "test/tmp/build-05-nested.md" ]; then
    echo "FAIL: Output file not created"
    exit 1
fi

# Create expected output based on nested fixture
cat > test/tmp/build-05-expected.md <<'EOF'
# Rule: nested/parent
## Parent Rule

This is the parent rule content.

### Parent Section

Some parent content here.

## Rule: nested/child1
### First Child

This is the first child rule.

#### Child Section

Content for first child.

## Rule: nested/child2
### Second Child

This is the second child rule.

#### Another Section

Content for second child.
EOF

# Compare actual vs expected
if ! diff -q "test/tmp/build-05-nested.md" "test/tmp/build-05-expected.md" >/dev/null 2>&1; then
    echo "FAIL: Output does not match expected"
    echo "Expected:"
    cat "test/tmp/build-05-expected.md"
    echo ""
    echo "Actual:"
    cat "test/tmp/build-05-nested.md"
    echo ""
    echo "Diff:"
    diff "test/tmp/build-05-expected.md" "test/tmp/build-05-nested.md" || true
    exit 1
fi

echo "PASS: Simple nested hierarchy"