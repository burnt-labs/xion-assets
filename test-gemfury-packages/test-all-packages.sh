#!/bin/bash

# Test script for verifying xiond package installations across all package formats
# Usage: 
#   ./test-all-packages.sh [version]                    # Use same version for all formats
#   DEB_VERSION=21.0.1 ./test-all-packages.sh           # Use separate versions per format
#   DEB_VERSION=21.0.1 RPM_VERSION=21.0.1 APK_VERSION=21.0.1 ./test-all-packages.sh
# Example: ./test-all-packages.sh 21.0.1

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Use individual version env vars, fall back to argument, then default
# Note: RPM_VERSION should include release number (e.g., "21.0.1-1") when using Gemfury
DEFAULT_VERSION=${1:-21.0.1}
DEB_VERSION=${DEB_VERSION:-${DEFAULT_VERSION}}
RPM_VERSION=${RPM_VERSION:-${DEFAULT_VERSION}}
APK_VERSION=${APK_VERSION:-${DEFAULT_VERSION}}

# Extract base version for comparison (xiond version command outputs base version without release number)
# For RPM, if version is "21.0.1-1", we compare against "21.0.1"
RPM_BASE_VERSION=$(echo $RPM_VERSION | cut -d'-' -f1)

FAILED=0

echo "=========================================="
echo "Testing xiond package installation"
echo "Target versions:"
echo "  DEB: ${DEB_VERSION}"
echo "  RPM: ${RPM_VERSION}"
echo "  APK: ${APK_VERSION}"
echo "=========================================="
echo ""

# Test DEB
echo "=== Testing DEB (Ubuntu/Debian - apt) ==="
echo "Target version: ${DEB_VERSION}"
if docker build -f Dockerfile.test-deb --build-arg XIOND_VERSION=${DEB_VERSION} -t xiond-test-deb:${DEB_VERSION} . 2>&1; then
    INSTALLED_VERSION=$(docker run --rm xiond-test-deb:${DEB_VERSION} xiond version 2>/dev/null)
    # Strip 'v' prefix if present for comparison
    INSTALLED_VERSION_CLEAN=${INSTALLED_VERSION#v}
    if [ "$INSTALLED_VERSION_CLEAN" = "$DEB_VERSION" ]; then
        echo "✓ DEB installation successful - Version: $INSTALLED_VERSION"
        echo "Installed version matches expected: $DEB_VERSION"
        echo ""
        echo "Detailed version information:"
        docker run --rm xiond-test-deb:${DEB_VERSION} xiond version --long
    else
        echo "✗ DEB version mismatch - Expected: $DEB_VERSION, Got: $INSTALLED_VERSION"
        FAILED=$((FAILED + 1))
    fi
else
    echo "✗ DEB installation failed (see error output above)"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test RPM
echo "=== Testing RPM (Rocky Linux - yum) ==="
echo "Target package version: ${RPM_VERSION}"
if docker build -f Dockerfile.test-rpm --build-arg XIOND_VERSION=${RPM_VERSION} -t xiond-test-rpm:${RPM_VERSION} . 2>&1; then
    INSTALLED_VERSION=$(docker run --rm xiond-test-rpm:${RPM_VERSION} xiond version 2>/dev/null)
    # Strip 'v' prefix if present for comparison
    INSTALLED_VERSION_CLEAN=${INSTALLED_VERSION#v}
    # xiond version outputs base version (without release number), so compare against base version
    if [ "$INSTALLED_VERSION_CLEAN" = "$RPM_BASE_VERSION" ]; then
        echo "✓ RPM installation successful - Package: ${RPM_VERSION}, Binary: $INSTALLED_VERSION"
        echo "Installed version matches expected: $RPM_BASE_VERSION"
        echo ""
        echo "Detailed version information:"
        docker run --rm xiond-test-rpm:${RPM_VERSION} xiond version --long
    else
        echo "✗ RPM version mismatch - Expected base: $RPM_BASE_VERSION, Got: $INSTALLED_VERSION"
        FAILED=$((FAILED + 1))
    fi
else
    echo "✗ RPM installation failed (see error output above)"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test APK
echo "=== Testing APK (Alpine Linux - apk) ==="
echo "Target version: ${APK_VERSION}"
if docker build -f Dockerfile.test-apk --build-arg XIOND_VERSION=${APK_VERSION} -t xiond-test-apk:${APK_VERSION} . 2>&1; then
    INSTALLED_VERSION=$(docker run --rm xiond-test-apk:${APK_VERSION} xiond version 2>/dev/null)
    # Strip 'v' prefix if present for comparison
    INSTALLED_VERSION_CLEAN=${INSTALLED_VERSION#v}
    if [ "$INSTALLED_VERSION_CLEAN" = "$APK_VERSION" ]; then
        echo "✓ APK installation successful - Version: $INSTALLED_VERSION"
        echo "Installed version matches expected: $APK_VERSION"
        echo ""
        echo "Detailed version information:"
        docker run --rm xiond-test-apk:${APK_VERSION} xiond version --long
    else
        echo "✗ APK version mismatch - Expected: $APK_VERSION, Got: $INSTALLED_VERSION"
        FAILED=$((FAILED + 1))
    fi
else
    echo "✗ APK installation failed (see error output above)"
    FAILED=$((FAILED + 1))
fi
echo ""

# Summary
echo "=========================================="
if [ $FAILED -eq 0 ]; then
    echo "✓ All package formats verified successfully!"
    echo "=========================================="
    exit 0
else
    echo "✗ ${FAILED} package format(s) failed"
    echo "=========================================="
    exit 1
fi

