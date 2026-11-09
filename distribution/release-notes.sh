#!/bin/sh
# 從 CHANGELOG.md 擷取指定版本的內容，輸出到 stdout，作為 GitHub Release 的 release note。
# 用法：distribution/release-notes.sh <版號>      例如 0.1.0 或 Unreleased
#       gh release create v0.1.0 --title "IdleVillager 0.1.0" --notes-file <(distribution/release-notes.sh 0.1.0)
# 找不到該版本或內容為空時，exit 1。
set -eu
if [ $# -ne 1 ]; then
    echo "usage: $0 <version>" >&2
    exit 2
fi
VERSION=${1#v}
ROOT=$(cd "$(dirname "$0")/.." && pwd)

# 遇到下一個版本標題或檔尾的連結定義（例如 `[0.1.0]: https://...`）就停止。
NOTES=$(awk -v version="$VERSION" '
    found && /^\[[^]]*\]: / { exit }
    /^## \[/ {
        if (found) exit
        if (index($0, "## [" version "]") == 1) { found = 1; next }
    }
    found { print }
' "$ROOT/CHANGELOG.md")

# 去掉開頭與結尾的空行。
NOTES=$(printf '%s\n' "$NOTES" | sed -e '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')

if [ -z "$NOTES" ]; then
    echo "No changelog entry for version $VERSION" >&2
    exit 1
fi
printf '%s\n' "$NOTES"
