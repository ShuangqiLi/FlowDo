$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Install and start Docker Desktop first: https://www.docker.com/products/docker-desktop/'
}

if (-not (Test-Path '.env')) {
    $secret = ([guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N'))
    "JWT_SECRET=$secret`nCORS_ORIGIN=*" | Set-Content -Encoding utf8 '.env'
}

docker load -i flowdo-server-image.tar.gz
if ($LASTEXITCODE -ne 0) {
    throw 'Failed to load the FlowDo server image.'
}

docker compose up -d
if ($LASTEXITCODE -ne 0) {
    throw 'Failed to start the FlowDo server.'
}

Write-Host 'FlowDo server: http://127.0.0.1:3000'
Write-Host 'Health check: http://127.0.0.1:3000/health'
