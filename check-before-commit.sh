#!/bin/bash

echo "🔍 Pre-commit safety check..."

# Check for REAL API keys (not placeholders)
if git diff --cached | grep -i "sk-ant-api" | grep -v "xxxxx" | grep -v "replace-with-your-key" > /dev/null; then
    echo "❌ ERROR: Real API key detected in staged changes!"
    echo "Found:"
    git diff --cached | grep -i "sk-ant-api" | grep -v "xxxxx"
    exit 1
fi

# Check for .env files (not .env.example)
if git diff --cached --name-only | grep "\.env$" | grep -v "\.env\.example" > /dev/null; then
    echo "❌ ERROR: .env file is staged!"
    echo "Found:"
    git diff --cached --name-only | grep "\.env$"
    exit 1
fi

# Check for data directories
if git diff --cached --name-only | grep -E "(\.cubestore|metastore|/data/)" > /dev/null; then
    echo "⚠️  WARNING: Data files detected in staged changes"
    git diff --cached --name-only | grep -E "(\.cubestore|metastore|/data/)"
    echo "Press Ctrl+C to cancel or Enter to continue."
    read
fi

echo "✅ Safety check passed!"
echo ""
echo "Files to be committed:"
git diff --cached --name-status
