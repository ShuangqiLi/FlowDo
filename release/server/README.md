# FlowDo 服务端

此包包含 Linux AMD64 Docker 镜像、PostgreSQL 和 Caddy HTTPS 反代，不需要 Node.js。
`Caddyfile` 与 `docker-compose.yml` 和仓库根目录是同一套文件，发版时拷进来。

API 默认只绑在本机 `127.0.0.1:3000`。公网请用域名走 HTTPS，不要把 3000 对公网放行。

## 公网部署

需要一个域名。安全组 / 防火墙只放行 **80、443**。

1. 域名加 A 记录，指到这台机器的公网 IP。
2. 安装并启动 Docker。
3. 运行 `start.ps1` 或 `chmod +x start.sh && ./start.sh`（会生成 `.env`）。
4. 编辑 `.env`：

```
DOMAIN=api.example.com
CORS_ORIGIN=*
```

5. 再运行一次启动脚本。

客户端登录页把 API 填成 `https://api.example.com`。

## 本机检查

没有 `DOMAIN` 时，只能在这台机器访问：

```
http://127.0.0.1:3000/health
```

## 停止

```sh
docker compose down
```

若启用过 HTTPS：

```sh
docker compose --profile https down
```

数据在 Docker volume `flowdo_data` 里。带 `-v` 会永久删除数据。
