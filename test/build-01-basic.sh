#!/bin/sh
# Test basic build functionality

set -e
cd "$(dirname "$0")/.."

echo "Testing: Basic build functionality"

# Test build with basic fixture (no code blocks)
./zig-out/bin/defrag --config test/config.json build --manifest test/fixtures/basic/manifest --out test/tmp/build-01-basic.md

# Check that output file was created
if [ ! -f "test/tmp/build-01-basic.md" ]; then
    echo "FAIL: Output file not created"
    exit 1
fi

# Create expected output based on basic fixture
cat > test/tmp/build-01-expected.md <<'EOF'
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

# Compare actual vs expected
if ! diff -q "test/tmp/build-01-basic.md" "test/tmp/build-01-expected.md" >/dev/null 2>&1; then
    echo "FAIL: Output does not match expected"
    echo "Expected:"
    cat "test/tmp/build-01-expected.md"
    echo ""
    echo "Actual:"
    cat "test/tmp/build-01-basic.md"
    echo ""
    echo "Diff:"
    diff "test/tmp/build-01-expected.md" "test/tmp/build-01-basic.md" || true
    exit 1
fi

echo "PASS: Basic build functionality"