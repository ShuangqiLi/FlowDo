# FlowDo 一键启动（Windows）。
#
# 同一个脚本两种用法：
#   - 放在发版包里（旁边有 flowdo-*-image.tar.gz）：加载镜像后启动；
#   - 放在源码仓库根目录（旁边有 server\ 和 web\）：先从源码构建镜像再启动，需要 Flutter SDK。
# 起来后会等 API 和网页端都 healthy，再按同目录的 .user 把数据库账号对齐，没成功就报错退出。
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

# 旧版卷名被项目名加了前缀。新卷还不存在时，停掉数据库再整卷拷过去；旧卷先留着。
docker volume inspect flowdo_flowdo_data 2>$null | Out-Null
$hasOld = ($LASTEXITCODE -eq 0)
docker volume inspect flowdo_data 2>$null | Out-Null
$hasNew = ($LASTEXITCODE -eq 0)
if ($hasOld -and $hasNew) {
    Write-Host '数据卷 flowdo_data 和旧的 flowdo_flowdo_data 都在，不自动覆盖。'
    Write-Host '确认新卷没问题后可删旧卷：docker volume rm flowdo_flowdo_data'
} elseif ($hasOld) {
    Write-Host '把数据卷 flowdo_flowdo_data 迁到 flowdo_data ...'
    docker compose stop db 2>$null | Out-Null
    docker volume create flowdo_data | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail '创建数据卷 flowdo_data 失败。' }
    # postgres 镜像的入口脚本会接管命令，所以指定 --entrypoint。
    docker run --rm --entrypoint cp -v flowdo_flowdo_data:/from -v flowdo_data:/to postgres:16-alpine -a /from/. /to/
    if ($LASTEXITCODE -ne 0) { Fail '迁移数据卷失败。' }
    Write-Host '旧卷还留着，确认数据无误后可删：docker volume rm flowdo_flowdo_data'
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

# 数据库里的账号以本目录 .user 为准：一行一个「用户名 密码」。
# 没有的新建，密码不同的更新，文件里没有的删除（任务随账号一起删）。
# 文件不存在时什么都不改，避免升级时误清空。
function Sync-Users {
    if (-not (Test-Path '.user')) {
        Write-Host '还没有 .user，数据库里的账号这次没动。'
        Write-Host '在本目录建 .user，一行一个「用户名 密码」（# 开头是注释），存盘后再跑一次本脚本。'
        return
    }

    $js = Join-Path $env:TEMP "flowdo-sync-users-$PID.js"
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($js, @'
const fs = require('fs');
const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const file = process.argv[2];
if (!file) {
  console.error('内部错误：没有账号文件路径');
  process.exit(2);
}

const wanted = new Map();
let lineNo = 0;
for (const raw of fs.readFileSync(file, 'utf8').split('\n')) {
  lineNo += 1;
  const line = raw.replace(/\r$/, '').trim();
  if (!line || line.startsWith('#')) continue;
  const match = line.match(/^(\S+)\s+(\S.*)$/);
  if (!match) {
    console.error('.user 第 ' + lineNo + ' 行格式不对，要写成：用户名 密码');
    process.exit(2);
  }
  const username = match[1];
  const password = match[2].trim();
  if (!password) {
    console.error('.user 第 ' + lineNo + ' 行没有密码');
    process.exit(2);
  }
  if (wanted.has(username)) {
    console.error('.user 里用户名 ' + username + ' 写了多次');
    process.exit(2);
  }
  wanted.set(username, password);
}

const prisma = new PrismaClient();

async function main() {
  const existing = await prisma.user.findMany({
    select: { id: true, username: true, passwordHash: true },
  });
  const byName = new Map(existing.map((user) => [user.username, user]));
  const notes = [];
  // 一条事务里做完：中途失败就全部回滚，不会出现建了一半、删了一半。
  await prisma.$transaction(
    async (tx) => {
      for (const [username, password] of wanted) {
        const user = byName.get(username);
        if (!user) {
          await tx.user.create({
            data: { username, passwordHash: await bcrypt.hash(password, 10) },
          });
          notes.push('创建 ' + username);
          continue;
        }
        if (!(await bcrypt.compare(password, user.passwordHash))) {
          await tx.user.update({
            where: { id: user.id },
            data: { passwordHash: await bcrypt.hash(password, 10) },
          });
          notes.push('更新 ' + username + ' 的密码');
        }
      }
      for (const user of existing) {
        if (!wanted.has(user.username)) {
          await tx.user.delete({ where: { id: user.id } });
          notes.push('删除 ' + user.username + '（任务一并删除）');
        }
      }
    },
    { timeout: 120000 },
  );
  notes.forEach((note) => console.log(note));
  const created = notes.filter((note) => note.startsWith('创建 ')).length;
  const updated = notes.filter((note) => note.startsWith('更新 ')).length;
  const deleted = notes.filter((note) => note.startsWith('删除 ')).length;
  console.log(
    '账号已与 .user 对齐：新建 ' + created + '，改密码 ' + updated + '，删除 ' + deleted,
  );
}

main()
  .catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
'@, $utf8)

    # 脚本放进 /tmp 时 node 找不到 /app/node_modules，所以指一下 NODE_PATH。
    docker compose cp $js api:/tmp/flowdo-sync-users.js
    if ($LASTEXITCODE -ne 0) { Remove-Item $js -ErrorAction SilentlyContinue; Fail '没能把同步脚本拷进 API 容器。' }
    docker compose cp .user api:/tmp/flowdo.user
    if ($LASTEXITCODE -ne 0) {
        docker compose exec -T api rm -f /tmp/flowdo-sync-users.js 2>$null | Out-Null
        Remove-Item $js -ErrorAction SilentlyContinue
        Fail '没能把 .user 拷进 API 容器。'
    }
    docker compose exec -T -e NODE_PATH=/app/node_modules api node /tmp/flowdo-sync-users.js /tmp/flowdo.user
    $code = $LASTEXITCODE
    docker compose exec -T api rm -f /tmp/flowdo-sync-users.js /tmp/flowdo.user 2>$null | Out-Null
    Remove-Item $js -ErrorAction SilentlyContinue
    if ($code -ne 0) { Fail '按 .user 同步账号失败，数据库没改。修一下 .user 再跑一次本脚本。' }
}

Write-Host -NoNewline '等待 API 就绪'
if (-not (Wait-Healthy 'api' 120)) { Report-Failure 'API' }
Write-Host ''
Write-Host -NoNewline '等待网页端就绪'
if (-not (Wait-Healthy 'web' 30)) { Report-Failure '网页端' }
Write-Host ''

Sync-Users

Write-Host ''
Write-Host 'FlowDo 已就绪：'
Write-Host "  网页端：http://<本机 IP>:${webPort}"
Write-Host "  API：   http://<本机 IP>:${apiPort}/health"
Write-Host '  数据库：只在容器网络内，不对外开放'
Write-Host ''
Write-Host '账号只认本目录的 .user：一行一个「用户名 密码」。改完再跑一次本脚本。'
Write-Host '停止：docker compose down    升级后清掉旧镜像：docker image prune -f'
