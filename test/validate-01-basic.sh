#!/bin/sh
# Test validate command

set -e
cd "$(dirname "$0")/.."

echo "Testing: Validate command"

# Test validate on existing basic fixture (should pass) - capture output
./zig-out/bin/defrag --config test/config.json validate --manifest test/fixtures/basic/manifest > test/tmp/validate-01-output.txt

# Create expected output for successful validation
cat > test/tmp/validate-01-expected.txt <<'EOF'
Validating manifest: test/fixtures/basic/manifest
Database path: test/fixtures/basic

✓ rule1.md (level 1)
✓ rule2.md (level 1)

Validation Summary:
Total rules: 2
Valid rules: 2
Missing rules: 0

✓ Database 'basic' is valid!
EOF

# Compare actual vs expected
if ! diff -q "test/tmp/validate-01-output.txt" "test/tmp/validate-01-expected.txt" >/dev/null 2>&1; then
    echo "FAIL: Validate output does not match expected"
    echo "Expected:"
    cat "test/tmp/validate-01-expected.txt"
    echo ""
    echo "Actual:"
    cat "test/tmp/validate-01-output.txt"
    echo ""
    echo "Diff:"
    diff "test/tmp/validate-01-expected.txt" "test/tmp/validate-01-output.txt" || true
    exit 1
fi

# Test validate with non-existent manifest (should fail with specific error)
./zig-out/bin/defrag --config test/config.json validate --manifest test/fixtures/nonexistent/manifest > test/tmp/validate-01-error.txt 2>&1 || true

# Create expected error output
cat > test/tmp/validate-01-expected-error.txt <<'EOF'
ERROR: Manifest file not found: test/fixtures/nonexistent/manifest
EOF

# Compare actual vs expected error output
if ! diff -q "test/tmp/validate-01-error.txt" "test/tmp/validate-01-expected-error.txt" >/dev/null 2>&1; then
    echo "FAIL: Validate error output does not match expected"
    echo "Expected:"
    cat "test/tmp/validate-01-expected-error.txt"
    echo ""
    echo "Actual:"
    cat "test/tmp/validate-01-error.txt"
    echo ""
    echo "Diff:"
    diff "test/tmp/validate-01-expected-error.txt" "test/tmp/validate-01-error.txt" || true
    exit 1
fi

echo "PASS: Validate command"