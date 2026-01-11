#!/bin/sh
# Test validate command with missing rule file

set -e
cd "$(dirname "$0")/.."

echo "Testing: Validate with missing rule file"

# Test validate with manifest that references non-existent rule
if ./zig-out/bin/defrag --config test/config.json validate --manifest test/fixtures/missing_rule/manifest >test/tmp/validate-03-output.txt 2>&1; then
    echo "FAIL: Validate should have failed with missing rule file"
    exit 1
fi

# Check that validation found missing rules
if ! grep -q "Missing rules: 1" test/tmp/validate-03-output.txt; then
    echo "FAIL: Expected missing rules count not found"
    echo "Output:"
    cat test/tmp/validate-03-output.txt
    exit 1
fi

# Check that the missing rule name is mentioned
if ! grep -q "nonexistent-rule" test/tmp/validate-03-output.txt; then
    echo "FAIL: Missing rule name not mentioned in output"
    echo "Output:"
    cat test/tmp/validate-03-output.txt
    exit 1
fi

# Check that validation failed
if ! grep -q "has 1 missing rule(s)" test/tmp/validate-03-output.txt; then
    echo "FAIL: Validation failure message not found"
    echo "Output:"
    cat test/tmp/validate-03-output.txt
    exit 1
fi

echo "PASS: Validate correctly fails with missing rule file"