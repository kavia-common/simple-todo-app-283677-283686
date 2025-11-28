#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/simple-todo-app-283677-283686/todo_native_app"
cd "$WORKSPACE"
# Run build then start to perform full validation. Uses ANDROID_EMULATOR_RUN=true to enable runtime steps.
# Build: capture APK path printed by build script
bash .init/build.sh >/tmp/build.out 2>&1 || (cat /tmp/build.out >&2; exit 1)
APK_PATH=$(grep -m1 '^APK_PATH=' /tmp/build.out | sed -E 's/^APK_PATH=//')
if [ -z "${APK_PATH:-}" ]; then echo "build did not report APK_PATH" >&2; exit 2; fi
if [ ! -f "$APK_PATH" ]; then echo "APK missing: $APK_PATH" >&2; exit 3; fi
# Start (may skip emulator if ANDROID_EMULATOR_RUN!=true)
bash .init/start.sh "$APK_PATH"
