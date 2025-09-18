#!/bin/bash

# Script to push ControlD Manager to both GitHub accounts
# Usage: ./push_to_both.sh "commit message"

COMMIT_MSG="${1:-Update ControlD Manager}"

echo "🚀 Pushing ControlD Manager to both GitHub repositories..."
echo "📝 Commit message: $COMMIT_MSG"
echo ""

# Add all changes
echo "📦 Adding changes..."
git add .

# Commit changes
echo "💾 Committing changes..."
git commit -m "$COMMIT_MSG"

if [ $? -eq 0 ]; then
    echo "✅ Commit successful"
else
    echo "ℹ️  No new changes to commit"
fi

echo ""

# Push to pencarsa repository
echo "🔄 Pushing to pencarsa/controldmanager (personal)..."
gh auth switch --user pencarsa > /dev/null 2>&1
git push pencarsa main

if [ $? -eq 0 ]; then
    echo "✅ Successfully pushed to pencarsa/controldmanager"
else
    echo "❌ Failed to push to pencarsa/controldmanager"
fi

echo ""

# Push to Roche repository  
echo "🔄 Pushing to Roche-RDT-PT/controldmanager (Roche org)..."
gh auth switch --user pencarsa_roche > /dev/null 2>&1
git push pencarsa_roche main

if [ $? -eq 0 ]; then
    echo "✅ Successfully pushed to Roche-RDT-PT/controldmanager"
else
    echo "❌ Failed to push to Roche-RDT-PT/controldmanager"
fi

echo ""
echo "🎉 Push complete!"
echo ""
echo "📍 Repository URLs:"
echo "   Personal: https://github.com/pencarsa/controldmanager"
echo "   Roche:    https://github.com/Roche-RDT-PT/controldmanager"