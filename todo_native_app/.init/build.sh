#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/simple-todo-app-283677-283686/todo_native_app"
cd "$WORKSPACE"
# Build debug APK (flutter preferred when pubspec.yaml present)
if [ -f pubspec.yaml ] && [ -x /opt/flutter/bin/flutter ]; then
  /opt/flutter/bin/flutter build apk --debug --no-shrink || (echo "flutter build failed" >&2; exit 61)
  echo "APK_PATH=$WORKSPACE/build/app/outputs/flutter-apk/app-debug.apk"
elif [ -f android/gradlew ]; then
  (cd android && ./gradlew assembleDebug --no-daemon -q) || (echo "gradle build failed" >&2; exit 62)
  echo "APK_PATH=$WORKSPACE/android/app/build/outputs/apk/debug/app-debug.apk"
else
  echo "No Android build target found" >&2; exit 63
fi
