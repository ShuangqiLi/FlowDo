#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"

if ! command -v docker >/dev/null 2>&1; then
  echo "请先安装并启动 Docker：https://docs.docker.com/engine/install/"
  exit 1
fi

if [ ! -f .env ]; then
  if command -v openssl >/dev/null 2>&1; then
    secret="$(openssl rand -hex 32)"
  else
    secret="$(date +%s)-$(hostname)-flowdo-change-this-secret"
  fi
  printf 'JWT_SECRET=%s\nCORS_ORIGIN=*\nDOMAIN=\n' "$secret" > .env
  echo "已生成 .env。公网部署请填写 DOMAIN=api.example.com 后再运行。"
fi

set -a
# shellcheck disable=SC1091
. /dev/stdin <<EOF
$(tr -d '\r' < .env)
EOF
set +a

docker load -i flowdo-server-image.tar.gz

if [ -n "${DOMAIN:-}" ]; then
  docker compose --profile https up -d
  echo "FlowDo 服务端已在公网启动：https://${DOMAIN}"
  echo "健康检查：https://${DOMAIN}/health"
  echo "客户端登录页把 API 地址填成：https://${DOMAIN}"
  echo "安全组只放行 80、443。API 和数据库都不对公网开放。"
else
  docker compose up -d
  port="${API_PORT:-13000}"
  echo "未设置 DOMAIN，API 只绑在本机 127.0.0.1:${port}，外网连不上。"
  echo "健康检查：http://127.0.0.1:${port}/health"
  echo "公网部署：在 .env 写入 DOMAIN=api.example.com（A 记录指到这台机器），"
  echo "安全组放行 80、443，再运行一次本脚本，走 HTTPS。"
fi
