#!/bin/sh
# 容器入口：先把数据库结构推平，再启动 API。
#
# 直接用 node 跑 Prisma CLI，不经过 npx（npx 每次要解析包、还会联网查 npm 新版本，
# 在没有外网的内网机器上会白等好几秒）。CHECKPOINT_DISABLE 关掉 Prisma 自己的联网统计。
set -eu
cd /app

# 群晖等环境里，服务名 `db` 会先解析到一个实际不通的 IPv6。
# Node 查询引擎会改试 IPv4，Prisma 同步结构用的 schema engine 不会，于是报
# P1001: Can't reach database server at `db:5432`。这里先解析成 IPv4。
if [ -n "${DATABASE_URL:-}" ]; then
  db_host=$(printf '%s' "$DATABASE_URL" | sed -n 's#.*@\([^:/?]*\).*#\1#p')
  case "$db_host" in
    ''|*[!0-9.]*)
      db_ip=$(node -e 'const dns=require("node:dns"); dns.lookup(process.argv[1], {family:4}, (err, addr) => { if (err) process.exit(1); process.stdout.write(addr); });' "$db_host" || true)
      if [ -n "$db_ip" ]; then
        DATABASE_URL=$(printf '%s' "$DATABASE_URL" | sed "s#@${db_host}:#@${db_ip}:#")
        export DATABASE_URL
        echo "[flowdo] 数据库 ${db_host} 解析为 ${db_ip}"
      fi
      ;;
  esac
fi

echo "[flowdo] 同步数据库结构..."
ok=0
i=1
while [ "$i" -le 5 ]; do
  if node node_modules/prisma/build/index.js db push --skip-generate --accept-data-loss; then
    ok=1
    break
  fi
  echo "[flowdo] 数据库还没连上，${i}/5 次，两秒后再试"
  i=$((i + 1))
  sleep 2
done
[ "$ok" = 1 ]

echo "[flowdo] 启动 API..."
# exec 让 node 成为 1 号进程，docker stop 的信号能直接送到，停得更快。
exec node dist/main
