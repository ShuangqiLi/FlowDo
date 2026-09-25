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

Write-Host "正在启动服务端..."
docker compose up --build -d
if ($LASTEXITCODE -ne 0) {
    throw "docker compose 启动失败。"
}

$health = 'http://127.0.0.1:3000/health'
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
Write-Host "服务端已就绪"
Write-Host "  API：  http://127.0.0.1:3000"
Write-Host "  健康： $health"
Write-Host "App 里把 API 地址填成上面这个即可。"
Write-Host "停掉：docker compose down"
