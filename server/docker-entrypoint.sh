#!/bin/sh
# 容器入口：先把数据库结构推平，再启动 API。
#
# 直接用 node 跑 Prisma CLI，不经过 npx（npx 每次要解析包、还会联网查 npm 新版本，
# 在没有外网的内网机器上会白等好几秒）。CHECKPOINT_DISABLE 关掉 Prisma 自己的联网统计。
set -eu
cd /app

echo "[flowdo] 同步数据库结构..."
node node_modules/prisma/build/index.js db push --skip-generate

echo "[flowdo] 启动 API..."
# exec 让 node 成为 1 号进程，docker stop 的信号能直接送到，停得更快。
exec node dist/main
