#!/bin/bash
echo "=== Clipd Pre-flight Checks ==="

echo -n "Xcode version: "
xcodebuild -version | head -1

echo -n "Bundle ID: "
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" Clipd/Info.plist 2>/dev/null || echo "not found"

echo -n "Entitlements: "
ls Clipd/Clipd.entitlements 2>/dev/null && echo "✓" || echo "✗ missing"

echo -n "Git status: "
if [ -z "$(git status --porcelain)" ]; then
    echo "✓ clean"
else
    echo "✗ dirty working directory"
fi

echo "=== Done ==="
