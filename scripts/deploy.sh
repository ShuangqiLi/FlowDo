#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! docker info >/dev/null 2>&1; then
  echo "没找到正在运行的 Docker。请先安装并打开 Docker Desktop："
  echo "https://www.docker.com/products/docker-desktop/"
  exit 1
fi

ensure_image() {
  local local_name="$1"
  local mirror="$2"
  if docker image inspect "$local_name" >/dev/null 2>&1; then
    return
  fi
  echo "拉取镜像 $local_name ..."
  if docker pull "$mirror"; then
    docker tag "$mirror" "$local_name"
  else
    docker pull "$local_name"
  fi
}

ensure_image postgres:16-alpine docker.m.daocloud.io/library/postgres:16-alpine
ensure_image node:22-alpine docker.m.daocloud.io/library/node:22-alpine

echo "正在启动服务端..."
docker build -t flowdo-server:latest ./server
docker compose up -d

echo "等待 API 就绪..."
ok=0
for _ in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:3000/health >/dev/null 2>&1; then
    ok=1
    break
  fi
  sleep 2
done

if [ "$ok" -ne 1 ]; then
  echo "容器已启动，但健康检查还没通过。可稍后再打开 http://127.0.0.1:3000/health"
  docker compose ps
  exit 1
fi

echo
echo "服务端已就绪"
echo "  API：  http://127.0.0.1:3000"
echo "  健康： http://127.0.0.1:3000/health"
echo "App 里把 API 地址填成上面这个即可。"
echo "停掉：docker compose down"
