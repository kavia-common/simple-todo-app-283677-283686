#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/simple-todo-app-283677-283686/todo_native_app"
cd "$WORKSPACE"
[ -f /etc/profile.d/android_sdk.sh ] && source /etc/profile.d/android_sdk.sh || true
[ -f /etc/profile.d/flutter.sh ] && source /etc/profile.d/flutter.sh || true
# Report versions if present (non-failing)
command -v node >/dev/null 2>&1 && node --version >/dev/null 2>&1 || true
command -v npm >/dev/null 2>&1 && npm --version >/dev/null 2>&1 || true
command -v yarn >/dev/null 2>&1 && yarn --version >/dev/null 2>&1 || true
# Install JS deps: prefer yarn when yarn.lock exists
if [ -f package.json ]; then
  if [ -f yarn.lock ] && command -v yarn >/dev/null 2>&1; then
    yarn install --non-interactive --silent || (echo "yarn install failed" >&2; exit 31)
  else
    npm ci --no-audit --no-fund --silent || (echo "npm ci failed" >&2; exit 32)
  fi
fi
# Flutter deps (use installed /opt/flutter)
if [ -f pubspec.yaml ] && [ -x /opt/flutter/bin/flutter ]; then
  /opt/flutter/bin/flutter pub get --no-precompile || (echo "flutter pub get failed" >&2; exit 33)
fi
# Ensure gradlew is executable
if [ -d android ] && [ -f android/gradlew ]; then
  chmod +x android/gradlew || true
fi
echo "dependencies step completed"
