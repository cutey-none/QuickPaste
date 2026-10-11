#!/usr/bin/env bash
# 生成可拖到 Applications 安装的只读 DMG，并附带 SHA-256 校验文件。
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)"
ARCH="$(uname -m)"
NAME="QuickPaste_${VERSION}_${ARCH}.dmg"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/quickpaste-dmg.XXXXXX")"
MOUNT="$WORK/mount"
cleanup() {
    if mount | grep -Fq " on $MOUNT "; then
        hdiutil detach "$MOUNT" -quiet || hdiutil detach "$MOUNT" -force -quiet || true
    fi
    rm -rf "$WORK"
}
trap cleanup EXIT

mkdir -p "$WORK/staging"
ditto build/QuickPaste.app "$WORK/staging/QuickPaste.app"
ln -s /Applications "$WORK/staging/Applications"
hdiutil create -volname QuickPaste -srcfolder "$WORK/staging" \
    -format UDRW -fs HFS+ "$WORK/writable.dmg" -quiet
hdiutil attach "$WORK/writable.dmg" -mountpoint "$MOUNT" -nobrowse -quiet

# 本地构建设置 Finder 拖拽布局；CI 无图形会话时保留标准目录视图。
if [[ "${CI:-false}" != "true" ]]; then
    if ! osascript - "$MOUNT" <<'APPLESCRIPT'
on run argv
    tell application "Finder"
        set installerFolder to POSIX file (item 1 of argv) as alias
        set installerDisk to disk (name of installerFolder)
        open installerFolder
        tell installerDisk
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set bounds of container window to {200, 200, 740, 540}
            set viewOptions to icon view options of container window
            set arrangement of viewOptions to not arranged
            set icon size of viewOptions to 96
            set position of item "QuickPaste.app" to {140, 150}
            set position of item "Applications" to {400, 150}
            close container window
        end tell
        update installerFolder without registering applications
        delay 2
    end tell
end run
APPLESCRIPT
    then
        echo "Finder 布局未设置；DMG 仍可正常拖拽安装。" >&2
    fi
fi

hdiutil detach "$MOUNT" -quiet
hdiutil convert "$WORK/writable.dmg" -format UDZO -o "$WORK/$NAME" -quiet
hdiutil verify "$WORK/$NAME"
mv -f "$WORK/$NAME" "build/$NAME"
(cd build && shasum -a 256 "$NAME" > "$NAME.sha256")
echo "已生成 build/$NAME 和 build/$NAME.sha256"
