#!/bin/sh
# Test build with multiple nesting levels

set -e
cd "$(dirname "$0")/.."

echo "Testing: Build with multiple nesting levels"

# Test build with various nesting levels
./zig-out/bin/defrag --config test/config.json build --manifest test/fixtures/multiple_level_jumps/manifest --out test/tmp/build-13-multiple-jumps.md 2>test/tmp/build-13-stderr.txt

# Check that output file was created
if [ ! -f "test/tmp/build-13-multiple-jumps.md" ]; then
    echo "FAIL: Output file not created"
    exit 1
fi

# Create expected output with nesting levels
cat > test/tmp/build-13-expected.md <<'EOF'
# Rule: multiple_level_jumps/level1
## level1 Rule

Test rule content.

## Rule: multiple_level_jumps/jump-from-1-to-3
### jump-from-1-to-3 Rule

Test rule content.

## Rule: multiple_level_jumps/level2
### level2 Rule

Test rule content.

### Rule: multiple_level_jumps/jump-from-2-to-4
#### jump-from-2-to-4 Rule

Test rule content.

### Rule: multiple_level_jumps/level3
#### level3 Rule

Test rule content.

#### Rule: multiple_level_jumps/jump-from-3-to-5
##### jump-from-3-to-5 Rule

Test rule content.

# Rule: multiple_level_jumps/back-to-1
## back-to-1 Rule

Test rule content.

## Rule: multiple_level_jumps/big-jump-from-1-to-5
### big-jump-from-1-to-5 Rule

Test rule content.
EOF

# Compare actual vs expected
if ! diff -q "test/tmp/build-13-multiple-jumps.md" "test/tmp/build-13-expected.md" >/dev/null 2>&1; then
    echo "FAIL: Output does not match expected"
    echo "Expected:"
    cat "test/tmp/build-13-expected.md"
    echo ""
    echo "Actual:"
    cat "test/tmp/build-13-multiple-jumps.md"
    echo ""
    echo "Diff:"
    diff "test/tmp/build-13-expected.md" "test/tmp/build-13-multiple-jumps.md" || true
    exit 1
fi

echo "PASS: Build with multiple nesting levels"