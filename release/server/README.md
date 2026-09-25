# FlowDo 服务端

此包包含 Linux AMD64 Docker 镜像和 PostgreSQL 编排文件，不需要 Node.js。

## 启动

需要先安装并启动 Docker。

- Windows：右键用 PowerShell 运行 `start.ps1`
- macOS / Linux：运行 `chmod +x start.sh && ./start.sh`

启动后 API 地址为 `http://127.0.0.1:3000`，健康检查为
`http://127.0.0.1:3000/health`。首次启动会自动生成 `.env`。

停止服务：

```sh
docker compose down
```

数据保存在 Docker volume `flowdo_data` 中；运行 `docker compose down -v`
会永久删除数据。
