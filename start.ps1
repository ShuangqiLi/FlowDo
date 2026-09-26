# FlowDo 一键启动（Windows）。
#
# 同一个脚本两种用法：
#   - 放在发版包里（旁边有 flowdo-*-image.tar.gz）：加载镜像后启动；
#   - 放在源码仓库根目录（旁边有 server\ 和 web\）：先从源码构建镜像再启动，需要 Flutter SDK。
# 起来后会等 API 和网页端都 healthy，没成功就报错退出。
#
# 用法：右键「使用 PowerShell 运行」，或 powershell -ExecutionPolicy Bypass -File .\start.ps1
#
# 外部命令的成败都靠 $LASTEXITCODE 判断；Windows PowerShell 5.x 在 Stop 模式下会把
# docker 写到 stderr 的普通提示当成异常，所以这里用 Continue。
$ErrorActionPreference = 'Continue'
Set-Location $PSScriptRoot

function Fail([string]$Message) {
    Write-Host "错误：$Message" -ForegroundColor Red
    exit 1
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Fail '没找到 docker。请先安装并启动 Docker Desktop：https://www.docker.com/products/docker-desktop/'
}
docker info 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Fail 'Docker 没在运行，先把 Docker Desktop 打开。' }

if ((Test-Path 'flowdo-server-image.tar.gz') -and (Test-Path 'flowdo-web-image.tar.gz')) {
    $mode = 'package'
} elseif ((Test-Path 'server\Dockerfile') -and (Test-Path 'web\Dockerfile')) {
    $mode = 'source'
} else {
    Fail '这里既没有镜像包（flowdo-*-image.tar.gz），也不是源码仓库根目录。'
}

# 第一次运行生成 .env：随机 JWT 密钥和默认端口。端口想改就改这个文件再重跑。
if (-not (Test-Path '.env')) {
    $secret = ([guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N'))
    $envText = "JWT_SECRET=$secret`nWEB_PORT=8080`nAPI_PORT=13000`n"
    [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot '.env'), $envText)
    Write-Host '已生成 .env（端口可在里面修改）。'
}

# compose 里进程环境变量优先于 .env，这里读端口也照这个顺序。
$apiPort = '13000'
$webPort = '8080'
Get-Content '.env' | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
    $name, $value = $_.Split('=', 2)
    $name = $name.Trim()
    $value = $value.Trim()
    if ($name -eq 'API_PORT' -and $value) { $apiPort = $value }
    if ($name -eq 'WEB_PORT' -and $value) { $webPort = $value }
}
if ($env:API_PORT) { $apiPort = $env:API_PORT }
if ($env:WEB_PORT) { $webPort = $env:WEB_PORT }

# 基础镜像本机没有时先拉一遍；先试国内镜像源，不通再走官方。
function Ensure-Image([string]$Name) {
    docker image inspect $Name 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { return }
    Write-Host "拉取 $Name ..."
    $mirror = "docker.m.daocloud.io/library/$Name"
    docker pull -q $mirror 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        docker tag $mirror $Name
        docker rmi $mirror 2>$null | Out-Null
        return
    }
    docker pull -q $Name | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail "拉不到 $Name，请检查网络。" }
}

# 包里每个镜像旁边有一个 .id 文件（镜像 ID）。本机已经有同一个 ID 就不用再解一遍几十上百兆的 tar。
function Import-FlowDoImage([string]$Name, [string]$Tarball, [string]$Label) {
    $idFile = $Tarball -replace '\.tar\.gz$', '.id'
    if (Test-Path $idFile) {
        $want = (Get-Content $idFile -Raw).Trim()
        $have = docker image inspect -f '{{.Id}}' $Name 2>$null
        if ($want -and $have -and $want -eq $have.Trim()) {
            Write-Host "$Name 已是包里这个版本，跳过加载。"
            return
        }
    }
    Write-Host "加载 $Name ..."
    docker load -q -i $Tarball | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail "加载 FlowDo $Label 镜像失败。" }
}

Ensure-Image 'postgres:16-alpine'

if ($mode -eq 'package') {
    Import-FlowDoImage 'flowdo-server:latest' 'flowdo-server-image.tar.gz' '服务端'
    Import-FlowDoImage 'flowdo-web:latest' 'flowdo-web-image.tar.gz' '网页端'
} else {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        Fail '没找到 flutter，网页端没法从源码构建。装一个 Flutter SDK，或者改用 Releases 里的 FlowDo-v*.zip。'
    }
    Ensure-Image 'node:22-alpine'
    Ensure-Image 'nginx:1.27-alpine'
    Write-Host '构建网页端...'
    Push-Location app
    flutter build web --release --no-web-resources-cdn
    $built = $LASTEXITCODE
    Pop-Location
    if ($built -ne 0) { Fail 'flutter build web 失败。' }
    docker build -f web/Dockerfile -t flowdo-web:latest .
    if ($LASTEXITCODE -ne 0) { Fail '网页端镜像构建失败。' }
    Write-Host '构建服务端...'
    docker build -t flowdo-server:latest ./server
    if ($LASTEXITCODE -ne 0) { Fail '服务端镜像构建失败。' }
}

docker compose up -d
if ($LASTEXITCODE -ne 0) { Fail 'docker compose up 失败。' }

# 等容器 healthy；API 起来前要先把数据库结构同步一遍，等它就绪再报"已启动"，免得刷开网页是 502。
function Wait-Healthy([string]$Service, [int]$Limit) {
    for ($i = 0; $i -lt $Limit; $i++) {
        $cid = (docker compose ps -q $Service 2>$null)
        if ($cid) {
            $status = docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' $cid.Trim() 2>$null
            switch (($status | Out-String).Trim()) {
                'healthy' { return $true }
                'exited' { return $false }
                'dead' { return $false }
                'unhealthy' { return $false }
                'restarting' { return $false }
            }
        }
        Write-Host -NoNewline '.'
        Start-Sleep -Seconds 1
    }
    return $false
}

function Report-Failure([string]$What) {
    Write-Host ''
    docker compose ps
    Write-Host '--- api 最近日志 ---'
    docker compose logs --no-color --tail 40 api
    Fail "$What 没有就绪。看看上面的日志，修好后再跑一次本脚本。"
}

Write-Host -NoNewline '等待 API 就绪'
if (-not (Wait-Healthy 'api' 120)) { Report-Failure 'API' }
Write-Host ''
Write-Host -NoNewline '等待网页端就绪'
if (-not (Wait-Healthy 'web' 30)) { Report-Failure '网页端' }
Write-Host ''

Write-Host ''
Write-Host 'FlowDo 已就绪：'
Write-Host "  网页端：http://<本机 IP>:${webPort}"
Write-Host "  API：   http://<本机 IP>:${apiPort}/health"
Write-Host '  数据库：只在容器网络内，不对外开放'
Write-Host ''
Write-Host '网页不开放注册，账号在这台机器上建（用户名 + 密码，没有别的要求）：'
Write-Host "  docker compose exec api npm run user:create -- user 'password'"
Write-Host ''
Write-Host '停止：docker compose down    升级后清掉旧镜像：docker image prune -f'
