#!/usr/bin/env bash
# 构建 release 版本并打包为 build/QuickPaste.app（ad-hoc 签名）
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

./scripts/build-icon.sh

APP="build/QuickPaste.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/QuickPaste" "$APP/Contents/MacOS/QuickPaste"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp Support/QuickPaste.icns "$APP/Contents/Resources/QuickPaste.icns"

codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
echo "已生成 $APP"
