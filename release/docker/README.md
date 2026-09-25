# FlowDo 部署包

此包包含服务端镜像、网页端镜像、完整 `web-build/` 静态产物和 Docker Compose，
不需要 Node.js，也不需要 Flutter。客户端只有网页端，浏览器打开就能用。

网页端默认开在 `8080`，API 默认开在 `13000`，数据库不映射到宿主机。
端口都能在 `.env` 里改。本项目只考虑可信内网 HTTP 部署，不要把端口暴露到公网。

## 启动

1. 安装并启动 Docker。
2. 运行 `start.ps1` 或 `chmod +x start.sh && ./start.sh`（会生成 `.env`）。
3. 在部署机创建账号（网页不开放注册）：

```bash
docker compose exec api npm run user:create -- user@example.com '至少8位密码'
```

4. 手机或电脑浏览器打开 `http://<部署机 IP>:8080`，输入账号密码登录。

Web nginx 会把 API 请求同源转给 API 容器，客户端没有 API 地址设置。

## 本机检查

```
http://127.0.0.1:8080          # 网页端
http://127.0.0.1:13000/health  # API
```

## 停止

```sh
docker compose down
```

数据在 Docker volume `flowdo_data` 里。带 `-v` 会永久删除数据。
