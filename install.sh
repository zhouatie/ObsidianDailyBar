#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "==> 正在编译打包 ObsidianDailyBar..."
./build-app.sh

TARGET_DIR="/Applications"
APP_NAME="ObsidianDailyBar.app"
DEST="$TARGET_DIR/$APP_NAME"

echo "==> 正在安装到 $DEST..."
# 如果正在运行，先退出
pkill -f "$DEST/Contents/MacOS/ObsidianDailyBar" || true
sleep 0.5

rm -rf "$DEST"
cp -R "$APP_NAME" "$DEST"

echo "==> 安装成功！"
echo "正在启动已安装的应用..."
open "$DEST"

echo ""
echo "🎉 安装完成！你现在可以通过以下几种优雅的方式随时使用："
echo "1. 【开机自启】：点击菜单栏设置齿轮 -> 勾选「开机自动启动」，每次开机自动常驻。"
echo "2. 【Raycast / 聚焦搜索 (Spotlight)】：按 Cmd+Space 搜 'Obsidian' 即可回车启动。"
echo "3. 【启动台】：直接在 Mac 的启动台 (Launchpad) 中点击打开。"
