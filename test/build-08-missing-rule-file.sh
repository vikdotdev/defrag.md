#!/bin/sh
# Test build command with missing rule file (lenient behavior)

set -e
cd "$(dirname "$0")/.."

echo "Testing: Build with missing rule file"

# Test build with manifest that references non-existent rule
# Build should succeed but warn about missing rule
./zig-out/bin/defrag --config test/config.json build --manifest test/fixtures/missing_rule/manifest --out test/tmp/build-08-missing-rule.md 2>test/tmp/build-08-stderr.txt

# Check that warning was displayed
if ! grep -q "WARNING: Fragment not found: nonexistent-rule" test/tmp/build-08-stderr.txt; then
    echo "FAIL: Expected warning message not found"
    echo "Stderr output:"
    cat test/tmp/build-08-stderr.txt
    exit 1
fi

# Check that output file was created (with remaining rules)
if [ ! -f "test/tmp/build-08-missing-rule.md" ]; then
    echo "FAIL: Output file should have been created with existing rules"
    exit 1
fi

# Check that existing rule was included in output
if ! grep -q "Rule: missing_rule/existing-rule" test/tmp/build-08-missing-rule.md; then
    echo "FAIL: Existing rule should be in output"
    cat test/tmp/build-08-missing-rule.md
    exit 1
fi

echo "PASS: Build warns about missing rule file but continues"