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
  printf 'JWT_SECRET=%s\nWEB_PORT=8080\nAPI_PORT=13000\n' "$secret" > .env
  echo "已生成 .env；端口可在里面修改。"
fi

docker load -i flowdo-server-image.tar.gz
docker load -i flowdo-web-image.tar.gz

docker compose up -d

web_port="$(awk -F= '$1 == "WEB_PORT" {print $2}' .env | tr -d '\r' | tail -n 1)"
api_port="$(awk -F= '$1 == "API_PORT" {print $2}' .env | tr -d '\r' | tail -n 1)"
web_port="${web_port:-8080}"
api_port="${api_port:-13000}"

echo "FlowDo 已启动："
echo "  网页端：http://<本机 IP>:${web_port}"
echo "  API：   http://<本机 IP>:${api_port}"
echo "  数据库：只在容器网络内，不对外开放"
echo
echo "第一次使用先创建账号："
echo "  docker compose exec api npm run user:create -- user@example.com '至少8位密码'"
