#!/bin/bash
set -e

VERSION=${1:?Usage: ./release.sh <version>}

echo "Releasing Clipd v$VERSION..."

# Update version in pbxproj
sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = $VERSION;/" Clipd.xcodeproj/project.pbxproj

# Update CHANGELOG
sed -i '' "s/## \[Unreleased\]/## \[Unreleased\]\n\n## \[$VERSION\] - $(date +%Y-%m-%d)/" CHANGELOG.md

# Commit and tag
git add -A
git commit -m "chore: release v$VERSION"
git tag "v$VERSION"

echo "✓ Tagged v$VERSION"
echo "Push with: git push origin master --tags"
