#!/bin/sh
# 把 SwiftPM 的 IdleVillagerApp 執行檔包成 IdleVillager.app（實測用，未簽章，只做 ad-hoc 簽章）。
# 用法：distribution/make-app.sh [輸出目錄，預設 dist]
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:-"$ROOT/dist"}

cd "$ROOT"
# 版號唯一來源是 herdr-plugin.toml 的 version；可用 IDLEVILLAGER_VERSION 覆寫（例如測試用）。
MANIFEST_VERSION=$(sed -n 's/^version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' herdr-plugin.toml | head -1)
VERSION=${IDLEVILLAGER_VERSION:-$MANIFEST_VERSION}
if [ -z "$VERSION" ]; then
    echo "Cannot read version from herdr-plugin.toml" >&2
    exit 1
fi
swift build -c release --product IdleVillagerApp
BIN=$(swift build -c release --show-bin-path)

APP="$OUT/IdleVillager.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/IdleVillagerApp" "$APP/Contents/MacOS/IdleVillager"

# resource bundle 放在 Contents/Resources，codesign 才會通過；放在 .app 根目錄會出現
# 「unsealed contents present in the bundle root」錯誤，連 ad-hoc 簽章都失敗。
# App 不使用 SwiftPM 產生的 Bundle.module（它不查 Contents/Resources，找不到就 fatalError），
# 改用 IdleVillagerCore 的 ResourceBundleLocator 尋找這個位置（見 docs/08-distribution.md）。
cp -R "$BIN/IdleVillager_IdleVillagerApp.bundle" "$APP/Contents/Resources/"
# IdleVillagerCore 的 resource bundle 放介面字串表（en.lproj、zh-Hant.lproj），同樣放在 Contents/Resources，
# 由 L10n 透過 ResourceBundleLocator 找到。少了它介面會顯示字串 key，所以缺檔時 cp 失敗、建置中止。
cp -R "$BIN/IdleVillager_IdleVillagerCore.bundle" "$APP/Contents/Resources/"

# CFBundleLocalizations 宣告 App 支援的介面語言，讓系統元件（例如設定視窗標題）跟著同一個語言，
# 也讓 macOS「語言與地區」可以為 IdleVillager 個別指定語言；不支援的系統語言以 CFBundleDevelopmentRegion（英文）呈現。
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>io.github.lewsiafat.IdleVillager</string>
  <key>CFBundleName</key><string>IdleVillager</string>
  <key>CFBundleExecutable</key><string>IdleVillager</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>zh-Hant</string>
  </array>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep -s - "$APP"

# Herdr plugin 安裝與更新每次都是全新 checkout，.build 快取不會再被用到，刪掉可省下約 186 MB。
# 由 herdr-plugin.toml 的 [[build]] 設定 IDLEVILLAGER_CLEAN_BUILD=1；本機開發時不刪。
if [ "${IDLEVILLAGER_CLEAN_BUILD:-0}" = "1" ]; then
    rm -rf "$ROOT/.build"
fi
echo "$APP"
