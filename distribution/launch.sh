#!/bin/sh
# 找到 IdleVillager.app 並以 open 啟動。App 已經在執行時，open 只會沿用既有實例，不會開第二個。
# 查找順序：環境變數 IDLEVILLAGER_APP、plugin 安裝時建置的 dist、/Applications、~/Applications。
# HERDR_PLUGIN_ROOT 由 Herdr 傳入；直接執行本腳本時改用 repo 根目錄。
set -eu
ROOT=${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}

for candidate in \
    "${IDLEVILLAGER_APP:-}" \
    "$ROOT/dist/IdleVillager.app" \
    "/Applications/IdleVillager.app" \
    "$HOME/Applications/IdleVillager.app"; do
    if [ -n "$candidate" ] && [ -d "$candidate" ]; then
        echo "launching $candidate"
        exec open -g "$candidate"
    fi
done

echo "IdleVillager.app not found. Reinstall the plugin, install the app to /Applications, or set IDLEVILLAGER_APP." >&2
exit 1
