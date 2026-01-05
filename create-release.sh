#!/bin/bash
# Script to create GitHub release for nemeton v0.1.0-rc2

set -e  # Exit on error

echo "🚀 Creating GitHub Release for nemeton v0.1.0-rc2..."
echo

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo "❌ Error: GitHub CLI (gh) is not installed."
    echo "Please run: sudo apt install gh"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Error: Not authenticated with GitHub."
    echo "Please run: gh auth login"
    exit 1
fi

# Navigate to repository directory
cd "$(dirname "$0")"

# Verify we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Error: Not in a git repository."
    exit 1
fi

# Verify tag exists
if ! git tag | grep -q "^v0.1.0-rc2$"; then
    echo "❌ Error: Tag v0.1.0-rc2 not found."
    echo "Available tags:"
    git tag
    exit 1
fi

# Verify release notes file exists
if [ ! -f "RELEASE_NOTES_v0.1.0-rc2.md" ]; then
    echo "❌ Error: RELEASE_NOTES_v0.1.0-rc2.md not found."
    exit 1
fi

echo "✅ All checks passed. Creating release..."
echo

# Create the release
gh release create v0.1.0-rc2 \
  --title "nemeton v0.1.0-rc2 - Release Candidate 2" \
  --notes-file RELEASE_NOTES_v0.1.0-rc2.md \
  --prerelease

echo
echo "✅ Release created successfully!"
echo
echo "🔗 View release at: https://github.com/pobsteta/nemeton/releases/tag/v0.1.0-rc2"
echo
