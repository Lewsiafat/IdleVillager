#!/bin/sh
# `herdr plugin install` 時執行：由原始碼建置 IdleVillager.app 到 plugin 目錄下的 dist/。
# 需要 Xcode Command Line Tools（Swift 6）。plugin 以 repo 子目錄安裝時，原始碼不在 plugin 目錄內，
# 這個做法是否可行要等實際用 `herdr plugin install` 驗證（見 docs/08-distribution.md）。
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
sh "$REPO/distribution/make-app.sh" "$HERE/dist"
