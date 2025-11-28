#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/simple-todo-app-283677-283686/todo_native_app"
cd "$WORKSPACE"
[ -f /etc/profile.d/android_sdk.sh ] && source /etc/profile.d/android_sdk.sh || true
[ -f /etc/profile.d/flutter.sh ] && source /etc/profile.d/flutter.sh || true
# Load APK path from argument or environment
APK_PATH="${1:-${APK_PATH:-}}"
if [ -z "$APK_PATH" ]; then echo "Usage: start <apk_path>" >&2; exit 1; fi
if [ ! -f "$APK_PATH" ]; then echo "APK not found: $APK_PATH" >&2; exit 2; fi
# If emulator is disabled, just print APK and exit
EMULATOR_ALLOWED=${ANDROID_EMULATOR_RUN:-false}
if [ "$EMULATOR_ALLOWED" != "true" ]; then echo "Emulator run disabled; APK at $APK_PATH"; exit 0; fi
# Ensure adb available
if ! command -v adb >/dev/null 2>&1; then echo "adb not found in PATH" >&2; exit 10; fi
# Start emulator if possible (scripts expect ANDROID_SDK_ROOT or ANDROID_HOME set)
SDK_ROOT=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/opt/android-sdk}}
SDKMANAGER="$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"
AVDMANAGER="$SDK_ROOT/cmdline-tools/latest/bin/avdmanager"
EMULATOR_BIN="$SDK_ROOT/emulator/emulator"
if [ ! -x "$AVDMANAGER" ] || [ ! -x "$EMULATOR_BIN" ]; then echo "emulator tools missing" >&2; exit 11; fi
SYSIMG="system-images;android-${ANDROID_COMPILE_SDK:-33};default;x86_64"
if [ ! -d "$SDK_ROOT/system-images/android-${ANDROID_COMPILE_SDK:-33}/default/x86_64" ]; then
  yes | "$SDKMANAGER" --sdk_root="$SDK_ROOT" "$SYSIMG" >/dev/null 2>&1 || (echo "failed to install system image" >&2; exit 12)
fi
AVD_NAME=ci_avd
if "$AVDMANAGER" list avd | grep -q "Name: $AVD_NAME"; then
  echo no | "$AVDMANAGER" delete avd -n "$AVD_NAME" >/dev/null 2>&1 || true
fi
echo no | "$AVDMANAGER" create avd -n "$AVD_NAME" -k "$SYSIMG" --force >/dev/null 2>&1 || true
LOG=/tmp/emulator.log
"$EMULATOR_BIN" -avd "$AVD_NAME" -no-window -gpu swiftshader_indirect -no-audio -no-snapshot -wipe-data >"$LOG" 2>&1 &
EMU_PID=$!
cleanup(){ set +e; DEVICE_ID=$(adb devices | awk 'NR>1 && NF>=2 {print $1; exit}') || true; if [ -n "${DEVICE_ID:-}" ]; then adb -s "$DEVICE_ID" emu kill >/dev/null 2>&1 || true; fi; kill "$EMU_PID" 2>/dev/null || true; }
trap cleanup EXIT
adb wait-for-device
SECS=0; TIMEOUT=300
while [ $SECS -lt $TIMEOUT ]; do
  DEVICE_ID=$(adb devices | awk 'NR>1 && NF>=2 {print $1; exit}') || true
  if [ -n "${DEVICE_ID:-}" ]; then
    BOOT=$(adb -s "$DEVICE_ID" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)
    if [ "$BOOT" = "1" ]; then break; fi
  fi
  sleep 2; SECS=$((SECS+2))
done
if [ $SECS -ge $TIMEOUT ]; then echo "emulator failed to boot within timeout" >&2; exit 13; fi
DEVICE_ID=$(adb devices | awk 'NR>1 && NF>=2 {print $1; exit}')
adb -s "$DEVICE_ID" install -r "$APK_PATH" >/dev/null 2>&1 || (echo "adb install failed" >&2; exit 14)
# Determine package name
PKG_NAME=""
if command -v aapt >/dev/null 2>&1; then
  PKG_NAME=$(aapt dump badging "$APK_PATH" 2>/dev/null | awk -F"'" '/package: name=/{print $2; exit}' || true)
elif command -v aapt2 >/dev/null 2>&1; then
  PKG_NAME=$(aapt2 dump badging "$APK_PATH" 2>/dev/null | sed -nE "s/package: name='([^']+)'.*/\1/p" | head -n1 || true)
else
  PKG_NAME=$(unzip -p "$APK_PATH" AndroidManifest.xml 2>/dev/null | strings | grep -Eo 'package="[^"]+"' | sed -E 's/package="([^"]+)"/\1/' | head -n1 || true)
fi
if [ -z "${PKG_NAME}" ]; then echo "failed to determine package name" >&2; exit 15; fi
TS_START=$(date --iso-8601=seconds 2>/dev/null || date +%s)
echo "APK_PATH=$APK_PATH"
echo "PACKAGE=$PKG_NAME"
# Resolve launchable activity
LAUNCHABLE=$(adb -s "$DEVICE_ID" shell cmd package resolve-activity --brief $PKG_NAME 2>/dev/null | tail -n1 | tr -d '\r' || true)
if [ -n "$LAUNCHABLE" ]; then
  MAIN_ACTIVITY=$LAUNCHABLE
  adb -s "$DEVICE_ID" shell am start -n "$MAIN_ACTIVITY" >/dev/null 2>&1 || (echo "am start failed" >&2; exit 16)
else
  adb -s "$DEVICE_ID" shell monkey -p "$PKG_NAME" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || (echo "monkey launch failed" >&2; exit 17)
fi
sleep 3
# Verify process
if adb -s "$DEVICE_ID" shell pidof "$PKG_NAME" >/dev/null 2>&1; then
  TS_LAUNCHED=$(date --iso-8601=seconds 2>/dev/null || date +%s)
  echo "LAUNCH=success"
  echo "TS_START=$TS_START"
  echo "TS_LAUNCHED=$TS_LAUNCHED"
else
  LOGS=$(adb -s "$DEVICE_ID" logcat -d -t 200 2>/dev/null || true)
  echo "LAUNCH=unknown"
  echo "log_excerpt:"; printf "%s
" "$LOGS" | sed -n '1,40p'
fi
# Force-stop
adb -s "$DEVICE_ID" shell am force-stop "$PKG_NAME" >/dev/null 2>&1 || true
# exit (cleanup trap will stop emulator)
