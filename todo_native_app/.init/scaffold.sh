#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/simple-todo-app-283677-283686/todo_native_app"
cd "$WORKSPACE"
[ -f /etc/profile.d/android_sdk.sh ] && source /etc/profile.d/android_sdk.sh || true
[ -f /etc/profile.d/java_home.sh ] && source /etc/profile.d/java_home.sh || true
# React Native: add safe start:android script and ensure gradlew executable
if [ -f package.json ] && (grep -q "react-native" package.json || grep -q "@react-native" package.json); then
  cp package.json package.json.bak 2>/dev/null || true
  node -e "const fs=require('fs');const p='package.json';let j=JSON.parse(fs.readFileSync(p));j.scripts=j.scripts||{};if(!j.scripts['start:android']){j.scripts['start:android']='react-native run-android';fs.writeFileSync(p,JSON.stringify(j,null,2));}console.log('ok');" || true
  [ -f android/gradlew ] && chmod +x android/gradlew || true
fi
# Flutter: install only if pubspec.yaml present or FLUTTER_VERSION requested
if [ -f pubspec.yaml ]; then
  REQ_FLUTTER=${FLUTTER_VERSION:-}
  if [ -x /opt/flutter/bin/flutter ]; then
    INST_VER=$(/opt/flutter/bin/flutter --version --machine 2>/dev/null | sed -nE 's/.*"flutterVersion":\s*"([^"]+)".*/\1/p' || true)
  else
    INST_VER=""
  fi
  if [ -z "$INST_VER" ] || { [ -n "$REQ_FLUTTER" ] && [ "$INST_VER" != "$REQ_FLUTTER" ]; }; then
    TARGET_USER=${SUDO_USER:-${USER:-root}}
    sudo mkdir -p /opt && sudo chown "$TARGET_USER":"$TARGET_USER" /opt
    FLUTTER_URL=${FLUTTER_SDK_URL:-"https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_latest_stable.tar.xz"}
    TMP_ARCH="/tmp/flutter_sdk.tar.xz"
    curl --fail --silent --show-error --retry 3 "$FLUTTER_URL" -o "$TMP_ARCH" || (echo "flutter download failed" >&2; exit 21)
    sudo tar -C /opt -xf "$TMP_ARCH" || (echo "flutter extract failed" >&2; exit 22)
    rm -f "$TMP_ARCH"
    # Normalize dir to /opt/flutter
    if [ ! -d /opt/flutter ] && ls /opt | grep -q flutter; then
      FLD=$(ls -d /opt/flutter_* 2>/dev/null | head -n1 || true)
      [ -n "$FLD" ] && sudo mv "/opt/$(basename "$FLD")" /opt/flutter || true
    fi
    sudo chown -R "$TARGET_USER":"$TARGET_USER" /opt/flutter || true
    sudo tee /etc/profile.d/flutter.sh >/dev/null <<'EOF'
export PATH="/opt/flutter/bin:\$PATH"
EOF
    sudo chmod 0755 /etc/profile.d/flutter.sh
  fi
  # Verify flutter binary for current run
  if [ -x /opt/flutter/bin/flutter ]; then
    /opt/flutter/bin/flutter --version >/dev/null 2>&1 || (echo "installed flutter not runnable" >&2; exit 23)
  fi
fi
# Create idempotent workspace start.sh if not present
START_SH="$WORKSPACE/start.sh"
if [ ! -f "$START_SH" ]; then
  cat > "$START_SH" <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/simple-todo-app-283677-283686/todo_native_app"
cd "$WORKSPACE"
[ -f /etc/profile.d/android_sdk.sh ] && source /etc/profile.d/android_sdk.sh || true
[ -f /etc/profile.d/flutter.sh ] && source /etc/profile.d/flutter.sh || true
if [ -f pubspec.yaml ]; then
  /opt/flutter/bin/flutter build apk --debug
elif [ -f android/gradlew ]; then
  (cd android && ./gradlew assembleDebug --no-daemon)
else
  echo "No recognized mobile project to start" >&2; exit 1
fi
BASH
  chmod +x "$START_SH"
fi
echo "scaffold step completed"
