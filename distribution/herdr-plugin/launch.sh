#!/bin/sh
# 找到 IdleVillager.app 並以 open 啟動。App 已經在執行時，open 只會沿用既有實例，不會開第二個。
# 查找順序：環境變數 IDLEVILLAGER_APP、plugin 自己建置的 dist、repo 根目錄的 dist（本機 link 開發用）、/Applications。
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)

for candidate in \
    "${IDLEVILLAGER_APP:-}" \
    "$HERE/dist/IdleVillager.app" \
    "$HERE/../../dist/IdleVillager.app" \
    "/Applications/IdleVillager.app" \
    "$HOME/Applications/IdleVillager.app"; do
    if [ -n "$candidate" ] && [ -d "$candidate" ]; then
        echo "launching $candidate"
        exec open -g "$candidate"
    fi
done

echo "IdleVillager.app not found. Install it to /Applications or set IDLEVILLAGER_APP." >&2
exit 1
