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
  printf 'JWT_SECRET=%s\nCORS_ORIGIN=*\n' "$secret" > .env
fi

docker load -i flowdo-server-image.tar.gz
docker compose up -d

echo "FlowDo 服务端已启动：http://127.0.0.1:3000"
echo "健康检查：http://127.0.0.1:3000/health"
