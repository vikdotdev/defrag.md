#!/bin/bash
set -e
cd "$(dirname "$0")/.."

echo "Building..."
zig build

echo ""
echo "Running tests..."
echo ""

mkdir -p test/tmp

passed=0
failed=0

for test in test/build-*.sh test/validate-*.sh test/new-*.sh; do
    name=$(basename "$test")
    if bash "$test" > test/tmp/test-output.txt 2>&1; then
        echo "PASS: $name"
        passed=$((passed + 1))
    else
        echo "FAIL: $name"
        cat test/tmp/test-output.txt
        echo ""
        failed=$((failed + 1))
    fi
done

echo ""
echo "Results: $passed passed, $failed failed"

if [ $failed -gt 0 ]; then
    exit 1
fi
