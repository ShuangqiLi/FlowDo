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
ensure_image nginx:1.27-alpine docker.m.daocloud.io/library/nginx:1.27-alpine

if ! command -v flutter >/dev/null 2>&1; then
  echo "没找到 flutter，网页端镜像没法从源码构建。"
  echo "装一个 Flutter SDK，或者直接用 Releases 里的 FlowDo-docker-*.zip 部署包。"
  exit 1
fi

echo "正在构建网页端..."
(cd app && flutter build web --release --no-web-resources-cdn)
docker build -f web/Dockerfile -t flowdo-web:latest .

echo "正在启动服务端..."
docker build -t flowdo-server:latest ./server
docker compose up -d

echo "等待 API 就绪..."
ok=0
for _ in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:13000/health >/dev/null 2>&1; then
    ok=1
    break
  fi
  sleep 2
done

if [ "$ok" -ne 1 ]; then
  echo "容器已启动，但健康检查还没通过。可稍后再打开 http://127.0.0.1:13000/health"
  docker compose ps
  exit 1
fi

echo
echo "FlowDo 已就绪"
echo "  网页端：http://127.0.0.1:8080"
echo "  API：   http://127.0.0.1:13000"
echo "  健康：  http://127.0.0.1:13000/health"
echo "第一次使用先创建账号："
echo "  docker compose exec api npm run user:create -- user@example.com '至少8位密码'"
echo "停掉：docker compose down"
