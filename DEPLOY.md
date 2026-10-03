# FlowDo 部署

这份说明同时放在发版包 `FlowDo-vX.Y.Z.zip` 里。包里有：

| 文件 | 作用 |
|---|---|
| `docker-compose.yml` | 编排 PostgreSQL、API、网页端三个容器 |
| `flowdo-server-image.tar.gz` / `.id` | 服务端镜像和它的镜像 ID |
| `flowdo-web-image.tar.gz` / `.id` | 网页端镜像（nginx + Flutter Web 产物）和它的镜像 ID |
| `start.sh` / `start.ps1` | 一键启动脚本（Linux / macOS / NAS 用 `.sh`，Windows 用 `.ps1`） |
| `README.md` | 本文 |

部署机只需要 Docker（带 compose 插件），不需要 Node.js，也不需要 Flutter。
客户端只有网页端，浏览器打开就能用。本项目只面向可信内网 HTTP 部署，不要把端口暴露到公网。

## 启动

1. 安装并启动 Docker，把包解压到一个固定目录。
2. 运行启动脚本：

   ```sh
   chmod +x start.sh && ./start.sh        # Linux / macOS / NAS
   powershell -ExecutionPolicy Bypass -File .\start.ps1   # Windows，或右键「使用 PowerShell 运行」
   ```

   第一次运行会生成 `.env`（随机 JWT 密钥、`WEB_PORT=8080`、`API_PORT=13000`），
   然后加载镜像、拉起容器，并等 API 和网页端都通过健康检查。**没起来脚本会打印容器状态和
   API 日志并以非零退出**，不会假装成功。
3. 手机或电脑浏览器打开 `http://<部署机 IP>:8080`。登录只填密码。
   全新安装打开网页后直接设密码，再输一次确认，没有初始密码。密码只以哈希存在数据库里，之后在设置里改。

## 忘记密码

这台服务没有邮箱，密码也只存在数据库里，所以没有「发邮件找回」。
能登录部署机、能用 Docker 的人，可以把密码清掉，任务和设置都留着。清掉之后，打开网页会重新出现「设一个密码」。

在部署目录执行：

```sh
docker compose exec db psql -U flowdo -d flowdo -c "UPDATE \"Instance\" SET \"passwordHash\" = '', \"mustChangePassword\" = true WHERE id = 'default';"
```

然后刷新网页，设一个新密码并再确认一次。这一步等于把登录权交给能进这台机器的人，只适合可信内网。

网页端 nginx 会把 API 请求同源转给 API 容器，客户端没有任何地址设置。
想改端口就编辑 `.env` 里的 `WEB_PORT` / `API_PORT`，再跑一次启动脚本。

## 升级

登录后在设置 → 关于里可以看到当前版本。服务端能访问 GitHub 时，发现新版本可以在网页里直接更新：它会下载发版包、装上新镜像、重启网页和接口，数据库和 `.env` 不动。更新过程中网页会短时间打不开，完成后再打开即可。
这一步需要 API 容器能使用本机 Docker（`docker-compose.yml` 里已经挂了套接字）。没有这个挂载时，关于页会提示你改用启动脚本。网页里换的是镜像；端口、环境变量这类编排改动会写到部署目录，但要等下次跑启动脚本才生效。

也可以手动升级：把新包解开覆盖到同一目录（保留 `.env`），再跑一次 `start.sh` / `start.ps1`。
脚本会对比 `*.id` 里的镜像 ID，本机已有的镜像直接跳过加载；API 启动时会自动把数据库结构同步到新版本。
数据卷固定叫 `flowdo_data`。换下来的镜像会留成 `<none>`，想清掉：`docker image prune -f`。

## 语音输入

网页端的语音输入用的是浏览器自带的识别能力，浏览器只在 `https://` 或 `localhost` 下开放麦克风。
内网用 `http://<IP>:8080` 打开时，Chrome / Edge 可以在
`chrome://flags/#unsafely-treat-insecure-origin-as-secure`（Edge 是 `edge://flags/...`）里
填上 `http://<部署机 IP>:8080` 并重启浏览器；或者给它配一个 HTTPS 反向代理。
Chrome 的识别服务在谷歌，国内网络连不上时可以换 Edge。设置页里能看到浏览器当前给不给麦克风。

## 本机检查

```
http://127.0.0.1:8080          # 网页端
http://127.0.0.1:13000/health  # API
docker compose ps              # 三个容器应该都是 healthy / running
docker compose logs -f api     # 看 API 日志
```

## 停止与数据

```sh
docker compose down        # 停掉容器，数据保留
docker compose down -v     # 连数据卷 flowdo_data 一起删，数据永久丢失
```

## 从源码启动

同一个 `start.sh` / `start.ps1` 放在仓库根目录时会改为从源码构建镜像（需要本机装 Flutter SDK 和 Docker），
其余步骤一样。
