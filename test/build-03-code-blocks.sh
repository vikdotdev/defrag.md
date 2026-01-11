#!/bin/sh
# Test code block handling

set -e
cd "$(dirname "$0")/.."

echo "Testing: Code block handling"

# Test build with code blocks fixture
./zig-out/bin/defrag --config test/config.json build --manifest test/fixtures/with_code_blocks/manifest --out test/tmp/build-03-code-blocks.md

# Check that output file was created
if [ ! -f "test/tmp/build-03-code-blocks.md" ]; then
    echo "FAIL: Output file not created"
    exit 1
fi

# Create expected output - comments inside code blocks should be preserved
cat > test/tmp/build-03-expected.md <<'EOF'
# Rule: with_code_blocks/code-rule
## Code Rule

This rule has code blocks with comments.

### Example

``` python
# This is a comment in code
# It should be preserved as-is
def hello():
    pass
```

### Another Example

``` bash
# Another comment
echo "test"
```
EOF

# Compare actual vs expected
if ! diff -q "test/tmp/build-03-code-blocks.md" "test/tmp/build-03-expected.md" >/dev/null 2>&1; then
    echo "FAIL: Output does not match expected"
    echo "Expected:"
    cat "test/tmp/build-03-expected.md"
    echo ""
    echo "Actual:"
    cat "test/tmp/build-03-code-blocks.md"
    echo ""
    echo "Diff:"
    diff "test/tmp/build-03-expected.md" "test/tmp/build-03-code-blocks.md" || true
    exit 1
fi

echo "PASS: Code block handling"