#!/usr/bin/env sh
# FlowDo 一键启动。
#
# 同一个脚本两种用法：
#   - 放在发版包里（旁边有 flowdo-*-image.tar.gz）：加载镜像后启动；
#   - 放在源码仓库根目录（旁边有 server/ 和 web/）：先从源码构建镜像再启动，需要 Flutter SDK。
# 起来后会等 API 和网页端都 healthy，没成功就报错退出。
set -eu
cd "$(dirname "$0")"

fail() {
  echo "错误：$*" >&2
  exit 1
}

command -v docker >/dev/null 2>&1 || fail "没找到 docker。请先安装并启动 Docker：https://docs.docker.com/engine/install/"
docker info >/dev/null 2>&1 || fail "Docker 没在运行，先把它启动起来。"
docker compose version >/dev/null 2>&1 || fail "缺少 docker compose 插件（Docker 20.10+ 自带）。"

if [ -f flowdo-server-image.tar.gz ] && [ -f flowdo-web-image.tar.gz ]; then
  mode=package
elif [ -f server/Dockerfile ] && [ -f web/Dockerfile ]; then
  mode=source
else
  fail "这里既没有镜像包（flowdo-*-image.tar.gz），也不是源码仓库根目录。"
fi

# 第一次运行生成 .env：随机 JWT 密钥和默认端口。端口想改就改这个文件再重跑。
if [ ! -f .env ]; then
  if command -v openssl >/dev/null 2>&1; then
    secret="$(openssl rand -hex 32)"
  else
    secret="$(date +%s)-$(hostname)-$$-flowdo"
  fi
  printf 'JWT_SECRET=%s\nWEB_PORT=8080\nAPI_PORT=13000\n' "$secret" > .env
  echo "已生成 .env（端口可在里面修改）。"
fi

# compose 里进程环境变量优先于 .env，这里读端口也照这个顺序。
read_env() {
  awk -F= -v key="$1" '$1 == key {print $2}' .env | tr -d '\r' | tail -n 1
}
web_port="${WEB_PORT:-$(read_env WEB_PORT)}"
api_port="${API_PORT:-$(read_env API_PORT)}"
web_port="${web_port:-8080}"
api_port="${api_port:-13000}"

# 基础镜像本机没有时先拉一遍；先试国内镜像源，不通再走官方。
ensure_image() {
  name="$1"
  if docker image inspect "$name" >/dev/null 2>&1; then
    return 0
  fi
  echo "拉取 $name ..."
  mirror="docker.m.daocloud.io/library/$name"
  if docker pull -q "$mirror" >/dev/null 2>&1; then
    docker tag "$mirror" "$name"
    docker rmi "$mirror" >/dev/null 2>&1 || true
  else
    docker pull -q "$name" >/dev/null || fail "拉不到 $name，请检查网络。"
  fi
}

# 包里每个镜像旁边有一个 .id 文件（镜像 ID）。本机已经有同一个 ID 就不用再解一遍几十上百兆的 tar。
load_image() {
  name="$1"
  tarball="$2"
  idfile="${tarball%.tar.gz}.id"
  if [ -f "$idfile" ]; then
    want="$(tr -d '[:space:]' < "$idfile")"
    have="$(docker image inspect -f '{{.Id}}' "$name" 2>/dev/null || true)"
    if [ -n "$want" ] && [ "$want" = "$have" ]; then
      echo "$name 已是包里这个版本，跳过加载。"
      return 0
    fi
  fi
  echo "加载 $name ..."
  docker load -q -i "$tarball" >/dev/null
}

ensure_image postgres:16-alpine

if [ "$mode" = package ]; then
  # 两个镜像互不相干，一起解。
  load_image flowdo-server:latest flowdo-server-image.tar.gz &
  server_pid=$!
  load_image flowdo-web:latest flowdo-web-image.tar.gz &
  web_pid=$!
  wait "$server_pid" || fail "加载服务端镜像失败。"
  wait "$web_pid" || fail "加载网页端镜像失败。"
else
  command -v flutter >/dev/null 2>&1 || fail "没找到 flutter，网页端没法从源码构建。装一个 Flutter SDK，或者改用 Releases 里的 FlowDo-v*.zip。"
  ensure_image node:22-alpine
  ensure_image nginx:1.27-alpine
  echo "构建网页端..."
  (cd app && flutter build web --release --no-web-resources-cdn) || fail "flutter build web 失败。"
  docker build -f web/Dockerfile -t flowdo-web:latest . || fail "网页端镜像构建失败。"
  echo "构建服务端..."
  docker build -t flowdo-server:latest ./server || fail "服务端镜像构建失败。"
fi

docker compose up -d || fail "docker compose up 失败。"

# 等容器 healthy；API 起来前要先把数据库结构同步一遍，等它就绪再报"已启动"，免得刷开网页是 502。
wait_healthy() {
  service="$1"
  limit="$2"
  i=0
  while [ "$i" -lt "$limit" ]; do
    cid="$(docker compose ps -q "$service" 2>/dev/null || true)"
    if [ -n "$cid" ]; then
      status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid" 2>/dev/null || true)"
      case "$status" in
        healthy) return 0 ;;
        exited|dead|unhealthy|restarting) return 1 ;;
      esac
    fi
    printf '.'
    sleep 1
    i=$((i + 1))
  done
  return 1
}

report_failure() {
  echo
  docker compose ps
  echo "--- api 最近日志 ---"
  docker compose logs --no-color --tail 40 api 2>/dev/null || true
  fail "$1 没有就绪。看看上面的日志，修好后再跑一次本脚本。"
}

printf '等待 API 就绪'
wait_healthy api 120 || report_failure "API"
echo
printf '等待网页端就绪'
wait_healthy web 30 || report_failure "网页端"
echo

echo
echo "FlowDo 已就绪："
echo "  网页端：http://<本机 IP>:${web_port}"
echo "  API：   http://<本机 IP>:${api_port}/health"
echo "  数据库：只在容器网络内，不对外开放"
echo
echo "网页不开放注册，账号在这台机器上建（用户名 + 密码，没有别的要求）："
echo "  docker compose exec api npm run user:create -- user 'password'"
echo
echo "停止：docker compose down    升级后清掉旧镜像：docker image prune -f"
