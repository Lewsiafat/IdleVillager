#!/bin/sh
# 找到 IdleVillager.app 並以 open 啟動，確保同時只有一個 IdleVillager.app 在執行。
# 查找順序：環境變數 IDLEVILLAGER_APP、plugin 安裝時建置的 dist、/Applications、~/Applications。
# HERDR_PLUGIN_ROOT 由 Herdr 傳入；直接執行本腳本時改用 repo 根目錄。
#
# `herdr plugin update` 會把 plugin 建置到新的安裝目錄，舊版 App 仍在舊目錄執行。open 只會沿用
# 同一路徑的實例，所以這裡先結束其他路徑的 IdleVillager.app，再開新的，讓更新生效且不會出現兩個圖示。
# 只比對 `IdleVillager.app/Contents/MacOS/IdleVillager`，`swift run` 啟動的開發版不受影響。
set -eu
ROOT=${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}

TARGET=""
for candidate in \
    "${IDLEVILLAGER_APP:-}" \
    "$ROOT/dist/IdleVillager.app" \
    "/Applications/IdleVillager.app" \
    "$HOME/Applications/IdleVillager.app"; do
    if [ -n "$candidate" ] && [ -d "$candidate" ]; then
        TARGET=$(cd "$candidate" && pwd -P)
        break
    fi
done

if [ -z "$TARGET" ]; then
    echo "IdleVillager.app not found. Reinstall the plugin, install the app to /Applications, or set IDLEVILLAGER_APP." >&2
    exit 1
fi

EXECUTABLE="$TARGET/Contents/MacOS/IdleVillager"
ALREADY_RUNNING=""
# 先結束所有其他路徑的實例，最後才決定要不要開新的；中途 exit 會漏掉排在後面的舊實例。
for pid in $(pgrep -f "IdleVillager.app/Contents/MacOS/IdleVillager" || true); do
    command=$(ps -o command= -p "$pid" || true)
    if [ "$command" = "$EXECUTABLE" ]; then
        ALREADY_RUNNING=$pid
        continue
    fi
    echo "stopping other IdleVillager instance (pid $pid): $command"
    kill "$pid" 2>/dev/null || true
    # 最多等 5 秒讓舊實例結束，避免新舊兩個圖示同時出現。
    i=0
    while kill -0 "$pid" 2>/dev/null && [ $i -lt 10 ]; do
        sleep 0.5
        i=$((i + 1))
    done
done

if [ -n "$ALREADY_RUNNING" ]; then
    echo "already running $TARGET (pid $ALREADY_RUNNING)"
    exit 0
fi

echo "launching $TARGET"
exec open -g "$TARGET"
