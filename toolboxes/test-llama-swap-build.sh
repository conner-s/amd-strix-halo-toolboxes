#!/bin/bash
# Test script for llama-swap build integration
# This script demonstrates how to build images with and without llama-swap

set -e

echo "=== Testing llama-swap build integration ==="
echo ""

# Test 1: Build Dockerfile.llama-swap standalone
echo "Test 1: Building llama-swap standalone..."
podman build --target llama-swap-builder -t test-llama-swap -f Dockerfile.llama-swap .
echo "✓ llama-swap Dockerfile builds successfully"
echo ""

# Test 2: Build vulkan-radv WITHOUT llama-swap (using --target runtime)
echo "Test 2: Building vulkan-radv WITHOUT llama-swap (using --target runtime)..."
podman build --target runtime -t test-vulkan-radv-no-swap -f Dockerfile.vulkan-radv .
echo "✓ vulkan-radv builds without llama-swap"
echo ""

# Test 3: Build vulkan-radv WITH llama-swap (complete build)
echo "Test 3: Building vulkan-radv WITH llama-swap (complete build)..."
podman build \
  --build-context llama-swap=Dockerfile.llama-swap \
  -f Dockerfile.vulkan-radv \
  -t test-vulkan-radv-with-swap .
echo "✓ vulkan-radv builds with llama-swap"
echo ""

# Test 4: Verify llama-swap is present in the with-swap image
echo "Test 4: Verifying llama-swap binary in the with-swap image..."
if podman run --rm test-vulkan-radv-with-swap test -f /usr/local/bin/llama-swap; then
    echo "✓ llama-swap binary found in with-swap image"
else
    echo "✗ llama-swap binary NOT found in with-swap image"
    exit 1
fi
echo ""

# Test 5: Verify llama-swap is NOT present in the without-swap image
echo "Test 5: Verifying llama-swap is NOT in the runtime-only image..."
if ! podman run --rm test-vulkan-radv-no-swap test -f /usr/local/bin/llama-swap; then
    echo "✓ llama-swap correctly absent from runtime-only build"
else
    echo "✗ llama-swap unexpectedly found in runtime-only build"
    exit 1
fi
echo ""

echo "=== All tests passed! ==="
