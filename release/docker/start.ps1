$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw '请先安装并启动 Docker：https://www.docker.com/products/docker-desktop/'
}

if (-not (Test-Path '.env')) {
    $secret = ([guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N'))
    $envText = "JWT_SECRET=$secret`nWEB_PORT=8080`nAPI_PORT=13000`n"
    [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot '.env'), $envText)
    Write-Host '已生成 .env；端口可在里面修改。'
}

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

docker load -i flowdo-server-image.tar.gz
if ($LASTEXITCODE -ne 0) {
    throw '加载 FlowDo 服务端镜像失败。'
}
docker load -i flowdo-web-image.tar.gz
if ($LASTEXITCODE -ne 0) {
    throw '加载 FlowDo 网页端镜像失败。'
}

docker compose up -d
if ($LASTEXITCODE -ne 0) { throw '启动 FlowDo 失败。' }

Write-Host 'FlowDo 已启动：'
Write-Host "  网页端：http://<本机 IP>:${webPort}"
Write-Host "  API：   http://<本机 IP>:${apiPort}"
Write-Host '  数据库：只在容器网络内，不对外开放'
Write-Host ''
Write-Host '第一次使用先创建账号：'
Write-Host "  docker compose exec api npm run user:create -- user@example.com '至少8位密码'"
