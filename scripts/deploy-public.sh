#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -z "${DOMAIN:-}" ]; then
  echo "请设置域名，例如："
  echo "  DOMAIN=api.example.com JWT_SECRET='长随机串' ./scripts/deploy-public.sh"
  exit 1
fi

if [ -z "${JWT_SECRET:-}" ] || [ "$JWT_SECRET" = "change-me-in-production" ]; then
  echo "请设置足够长的 JWT_SECRET，不要用默认值。"
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "请先安装并启动 Docker。"
  exit 1
fi

if ! docker image inspect caddy:2-alpine >/dev/null 2>&1; then
  docker pull docker.m.daocloud.io/library/caddy:2-alpine && \
    docker tag docker.m.daocloud.io/library/caddy:2-alpine caddy:2-alpine || \
    docker pull caddy:2-alpine
fi

if ! docker image inspect postgres:16-alpine >/dev/null 2>&1; then
  docker pull docker.m.daocloud.io/library/postgres:16-alpine && \
    docker tag docker.m.daocloud.io/library/postgres:16-alpine postgres:16-alpine || \
    docker pull postgres:16-alpine
fi

if ! docker image inspect node:22-alpine >/dev/null 2>&1; then
  docker pull docker.m.daocloud.io/library/node:22-alpine && \
    docker tag docker.m.daocloud.io/library/node:22-alpine node:22-alpine || \
    docker pull node:22-alpine
fi

export DOMAIN JWT_SECRET
export CORS_ORIGIN="${CORS_ORIGIN:-*}"

echo "正在以 https://$DOMAIN 启动..."
docker compose -f docker-compose.yml -f docker-compose.public.yml up --build -d

echo
echo "DNS 的 A 记录请指向这台机器公网 IP，并放行 80/443。"
echo "API：https://$DOMAIN"
echo "健康检查：https://$DOMAIN/health"
echo "App 里把 API 地址填成 https://$DOMAIN"
echo "停掉：docker compose -f docker-compose.yml -f docker-compose.public.yml down"
