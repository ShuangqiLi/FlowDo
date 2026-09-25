$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw '请先安装并启动 Docker：https://www.docker.com/products/docker-desktop/'
}

if (-not (Test-Path '.env')) {
    $secret = ([guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N'))
    $envText = "JWT_SECRET=$secret`nCORS_ORIGIN=*`nDOMAIN=`n"
    [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot '.env'), $envText)
    Write-Host '已生成 .env。公网部署请填写 DOMAIN=api.example.com 后再运行。'
}

$domain = $null
$port = '3000'
Get-Content '.env' | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
    $name, $value = $_.Split('=', 2)
    $name = $name.Trim()
    $value = $value.Trim()
    if ($name -eq 'DOMAIN' -and $value) { $domain = $value }
    if ($name -eq 'API_PORT' -and $value) { $port = $value }
}

docker load -i flowdo-server-image.tar.gz
if ($LASTEXITCODE -ne 0) {
    throw '加载 FlowDo 服务端镜像失败。'
}

if ($domain) {
    docker compose --profile https up -d
    if ($LASTEXITCODE -ne 0) { throw '启动 FlowDo 服务端失败。' }
    Write-Host "FlowDo 服务端已在公网启动：https://$domain"
    Write-Host "健康检查：https://$domain/health"
    Write-Host "客户端登录页把 API 地址填成：https://$domain"
    Write-Host '安全组只放行 80、443。API 和数据库都不对公网开放。'
} else {
    docker compose up -d
    if ($LASTEXITCODE -ne 0) { throw '启动 FlowDo 服务端失败。' }
    Write-Host "未设置 DOMAIN，API 只绑在本机 127.0.0.1:${port}，外网连不上。"
    Write-Host "健康检查：http://127.0.0.1:${port}/health"
    Write-Host '公网部署：在 .env 写入 DOMAIN=api.example.com（A 记录指到这台机器），'
    Write-Host '安全组放行 80、443，再运行一次本脚本，走 HTTPS。'
}
