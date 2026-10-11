#!/usr/bin/env bash
# 从 logo 原图生成 macOS 各分辨率图标，无需额外依赖。
set -euo pipefail
cd "$(dirname "$0")/.."

ICONSET="$(mktemp -d "${TMPDIR:-/tmp}/quickpaste-icon.XXXXXX")/QuickPaste.iconset"
mkdir -p "$ICONSET"
trap 'rm -rf "$(dirname "$ICONSET")"' EXIT

for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Support/logo.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    retina=$((size * 2))
    sips -z "$retina" "$retina" Support/logo.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o Support/QuickPaste.icns
echo "已生成 Support/QuickPaste.icns"
