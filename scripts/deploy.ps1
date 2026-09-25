# 本机启动随随办办服务端（PostgreSQL + API）
# 用法：powershell -ExecutionPolicy Bypass -File .\scripts\deploy.ps1

$ErrorActionPreference = 'Continue'
Set-Location (Split-Path $PSScriptRoot -Parent)

function Test-Docker {
    try {
        docker info | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Ensure-Image {
    param(
        [string]$Local,
        [string]$Mirror
    )
    $id = docker images -q $Local
    if ($id) {
        return
    }
    Write-Host "拉取镜像 $Local ..."
    docker pull $Mirror
    if ($LASTEXITCODE -eq 0) {
        docker tag $Mirror $Local
        return
    }
    docker pull $Local
    if ($LASTEXITCODE -ne 0) {
        throw "无法拉取 $Local，请确认 Docker 已启动且网络可用。"
    }
}

if (-not (Test-Docker)) {
    Write-Host "没找到正在运行的 Docker。请先安装并打开 Docker Desktop："
    Write-Host "https://www.docker.com/products/docker-desktop/"
    exit 1
}

Ensure-Image 'postgres:16-alpine' 'docker.m.daocloud.io/library/postgres:16-alpine'
Ensure-Image 'node:22-alpine' 'docker.m.daocloud.io/library/node:22-alpine'
Ensure-Image 'nginx:1.27-alpine' 'docker.m.daocloud.io/library/nginx:1.27-alpine'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "没找到 flutter，网页端镜像没法从源码构建。"
    Write-Host "装一个 Flutter SDK，或者直接用 Releases 里的 FlowDo-docker-*.zip 部署包。"
    exit 1
}

Write-Host "正在构建网页端..."
Push-Location app
flutter build web --release --no-web-resources-cdn
$built = $LASTEXITCODE
Pop-Location
if ($built -ne 0) {
    throw "flutter build web 失败。"
}
docker build -f web/Dockerfile -t flowdo-web:latest .
if ($LASTEXITCODE -ne 0) {
    throw "网页端 docker build 失败。"
}

Write-Host "正在启动服务端..."
docker build -t flowdo-server:latest ./server
if ($LASTEXITCODE -ne 0) {
    throw "docker build 失败。"
}
docker compose up -d
if ($LASTEXITCODE -ne 0) {
    throw "docker compose 启动失败。"
}

$health = 'http://127.0.0.1:13000/health'
Write-Host "等待 API 就绪..."
$ok = $false
for ($i = 0; $i -lt 60; $i++) {
    try {
        $res = Invoke-WebRequest -Uri $health -UseBasicParsing -TimeoutSec 2
        if ($res.StatusCode -ge 200 -and $res.StatusCode -lt 300) {
            $ok = $true
            break
        }
    } catch {
        Start-Sleep -Seconds 2
    }
}

if (-not $ok) {
    Write-Host "容器已启动，但健康检查还没通过。可稍后再打开 $health"
    docker compose ps
    exit 1
}

Write-Host ""
Write-Host "FlowDo 已就绪"
Write-Host "  网页端：http://127.0.0.1:8080"
Write-Host "  API：   http://127.0.0.1:13000"
Write-Host "  健康：  $health"
Write-Host "第一次使用先创建账号："
Write-Host "  docker compose exec api npm run user:create -- user@example.com '至少8位密码'"
Write-Host "停掉：docker compose down"
