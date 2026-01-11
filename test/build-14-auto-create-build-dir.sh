#!/bin/sh
# Test automatic creation of build/ directory when using default output

set -e
cd "$(dirname "$0")/.."

echo "Testing: Automatic creation of build/ directory"

# Remove build directory if it exists
rm -rf build

# Test build with default output (no --out flag) - should auto-create build/ directory
./zig-out/bin/defrag --config test/config.json build --manifest test/fixtures/basic/manifest

# Check that build directory was created
if [ ! -d "build" ]; then
    echo "FAIL: build/ directory was not created"
    exit 1
fi

# Check that output file was created (using new naming: collection.prefix.md)
if [ ! -f "build/basic.manifest.md" ]; then
    echo "FAIL: build/basic.manifest.md was not created"
    exit 1
fi

# Test that custom directories are auto-created
rm -rf /tmp/test-nonexistent-dir
if ! ./zig-out/bin/defrag --config test/config.json build --manifest test/fixtures/basic/manifest --out /tmp/test-nonexistent-dir/custom.md; then
    echo "FAIL: Build should have succeeded and created directory"
    exit 1
fi

# Check that custom output file was created
if [ ! -f "/tmp/test-nonexistent-dir/custom.md" ]; then
    echo "FAIL: Custom output file was not created"
    exit 1
fi

# Cleanup
rm -rf /tmp/test-nonexistent-dir

echo "PASS: Automatic creation of build/ directory"