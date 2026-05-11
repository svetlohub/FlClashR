#!/bin/bash
set -e
echo "Deploying Raketa UI redesign..."
git add lib/views/simple_home.dart .github/workflows/build-android.yml
git commit -m "perf: zero-animation UI redesign — remove AnimationController, static glow, single APK"
git pull --rebase origin main --quiet 2>/dev/null || true
git push origin main
echo "✅ Pushed! Building at: https://github.com/svetlohub/FlClashR/actions"
