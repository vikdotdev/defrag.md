#!/bin/sh
# Test complex nested hierarchy

set -e
cd "$(dirname "$0")/.."

echo "Testing: Complex nested hierarchy"

# Test build with complex nested fixture
./zig-out/bin/defrag --config test/config.json build --manifest test/fixtures/nested_complex/manifest --out test/tmp/build-06-nested-complex.md

# Check that output file was created
if [ ! -f "test/tmp/build-06-nested-complex.md" ]; then
    echo "FAIL: Output file not created"
    exit 1
fi

# Create expected output - complex nested structure with multiple levels
cat > test/tmp/build-06-expected.md <<'EOF'
# Rule: nested_complex/intro
## Introduction

This is the introduction.

# Rule: nested_complex/section1
## Section One

Main content for section 1.

## Rule: nested_complex/section1-sub1
### Subsection 1.1

Content for section 1, subsection 1.

## Rule: nested_complex/section1-sub2
### Subsection 1.2

Content for section 1, subsection 2.

### Rule: nested_complex/section1-sub2-detail
#### Detail 1.2.1

Detailed content nested three levels deep.

# Rule: nested_complex/section2
## Section Two

Main content for section 2.

## Rule: nested_complex/section2-sub1
### Subsection 2.1

Content for section 2, subsection 1.

### Rule: nested_complex/section2-sub1-detail1
#### Detail 2.1.1

First detail under subsection 2.1.

### Rule: nested_complex/section2-sub1-detail2
#### Detail 2.1.2

Second detail under subsection 2.1.

## Rule: nested_complex/section2-sub2
### Subsection 2.2

Content for section 2, subsection 2.

# Rule: nested_complex/conclusion
## Conclusion

This is the conclusion.
EOF

# Compare actual vs expected
if ! diff -q "test/tmp/build-06-nested-complex.md" "test/tmp/build-06-expected.md" >/dev/null 2>&1; then
    echo "FAIL: Output does not match expected"
    echo "Expected:"
    cat "test/tmp/build-06-expected.md"
    echo ""
    echo "Actual:"
    cat "test/tmp/build-06-nested-complex.md"
    echo ""
    echo "Diff:"
    diff "test/tmp/build-06-expected.md" "test/tmp/build-06-nested-complex.md" || true
    exit 1
fi

echo "PASS: Complex nested hierarchy"