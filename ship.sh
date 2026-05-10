#!/usr/bin/env bash
# ship.sh — commit, sync, push (optionally create release tag)
# Usage:
#   ./ship.sh "fix: something"          → commit + push to main
#   ./ship.sh "fix: something" 1.0.2    → commit + push + tag v1.0.2 (creates Release)

set -e

MSG="${1}"
VERSION="${2}"

if [ -z "$MSG" ]; then
  echo "Usage: ./ship.sh \"commit message\" [version]"
  echo "  ./ship.sh \"fix: something\""
  echo "  ./ship.sh \"release: v1.0.2\" 1.0.2"
  exit 1
fi

echo "→ Staging all changes..."
git add -A

# Nothing to commit? Still allow tagging
if git diff --cached --quiet; then
  echo "  (nothing to commit, working tree clean)"
else
  echo "→ Committing: $MSG"
  git commit -m "$MSG"
fi

echo "→ Pulling remote changes (rebase)..."
git pull --rebase origin main

echo "→ Pushing to main..."
git push origin main

if [ -n "$VERSION" ]; then
  TAG="v${VERSION}"
  echo "→ Creating tag $TAG..."
  git tag "$TAG"
  echo "→ Pushing tag $TAG → triggers GitHub Release..."
  git push origin "$TAG"
  echo ""
  echo "✅ Release $TAG queued! Watch: https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]//' | sed 's/.git$//')/actions"
else
  echo ""
  echo "✅ Pushed! Build running at: https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]//' | sed 's/.git$//')/actions"
fi
