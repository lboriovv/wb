#!/usr/bin/env bash
set -euo pipefail

# Быстрый цикл для прототипа: собрать → установить → открыть сценарий → снять кадр.
# Примеры:
#   ./scripts/preview.sh services
#   ./scripts/preview.sh services/mosenergo -demoFill 1
#   ./scripts/preview.sh transfer/by-phone -demoAmount 4000

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$PROJECT_DIR/.build"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/WBSandbox.app"
BUNDLE_ID="app.brighty.WBSandbox"
SCREEN="${1:-pip}"
shift || true
SCREENSHOT="$PROJECT_DIR/.build/preview.png"

if ! xcrun simctl list devices booted | grep -q '(Booted)'; then
  xcrun simctl boot "WB-iPhone14" 2>/dev/null || xcrun simctl boot "iPhone 17 Pro"
  open -a Simulator
  xcrun simctl bootstatus booted -b
fi

xcodebuild \
  -project "$PROJECT_DIR/WBSandbox.xcodeproj" \
  -scheme WBSandbox \
  -configuration Debug \
  -sdk iphonesimulator \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build >/dev/null

xcrun simctl install booted "$APP_PATH"
xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch booted "$BUNDLE_ID" -demoOpen "$SCREEN" "$@" >/dev/null
sleep 1
xcrun simctl io booted screenshot "$SCREENSHOT"

echo "Открыт: $SCREEN"
echo "Скриншот: $SCREENSHOT"
