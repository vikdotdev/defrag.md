#!/bin/sh
# Test handling of files without EOF newline

set -e
cd "$(dirname "$0")/.."

echo "Testing: Files without EOF newline"

# Test build with no_eof_newline fixture
./zig-out/bin/defrag --config test/config.json build --manifest test/fixtures/no_eof_newline/manifest --out test/tmp/build-04-no-eof-newline.md

# Check that output file was created
if [ ! -f "test/tmp/build-04-no-eof-newline.md" ]; then
    echo "FAIL: Output file not created"
    exit 1
fi

# Create expected output - headings should be normalized and content preserved
cat > test/tmp/build-04-expected.md <<'EOF'
# Rule: no_eof_newline/no-newline-rule
## No Newline Rule

This rule file does not end with a newline character.

### Content

Some content here.
EOF

# Compare actual vs expected
if ! diff -q "test/tmp/build-04-no-eof-newline.md" "test/tmp/build-04-expected.md" >/dev/null 2>&1; then
    echo "FAIL: Output does not match expected"
    echo "Expected:"
    cat "test/tmp/build-04-expected.md"
    echo ""
    echo "Actual:"
    cat "test/tmp/build-04-no-eof-newline.md"
    echo ""
    echo "Diff:"
    diff "test/tmp/build-04-expected.md" "test/tmp/build-04-no-eof-newline.md" || true
    exit 1
fi

echo "PASS: Files without EOF newline"