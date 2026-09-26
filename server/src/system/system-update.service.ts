import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { execFile } from 'node:child_process';
import {
  chmodSync,
  copyFileSync,
  createWriteStream,
  existsSync,
  mkdirSync,
  readFileSync,
  rmSync,
  unlinkSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { promisify } from 'node:util';
import {
  docker,
  dockerSock,
  inspectSelf,
  loadImage,
  recreateService,
} from './docker-engine';
import { compareVersions } from './version';

const execFileAsync = promisify(execFile);
const latestUrl = 'https://api.github.com/repos/ShuangqiLi/FlowDo/releases/latest';
const releaseFiles = [
  'docker-compose.yml',
  'start.sh',
  'start.ps1',
  'README.md',
  'flowdo-server-image.tar.gz',
  'flowdo-web-image.tar.gz',
  'flowdo-server-image.id',
  'flowdo-web-image.id',
];

type Phase = 'idle' | 'downloading' | 'applying' | 'failed';

type Release = {
  tag_name: string;
  assets: { name: string; browser_download_url: string }[];
};

export type AboutSnapshot = {
  version: string;
  latest: string | null;
  updateAvailable: boolean;
  reachable: boolean;
  canUpdate: boolean;
  phase: Phase;
  message: string | null;
  target: string | null;
};

@Injectable()
export class SystemUpdateService {
  private readonly logger = new Logger(SystemUpdateService.name);
  private phase: Phase = 'idle';
  private message: string | null = null;
  private target: string | null = null;
  private latestCache: {
    at: number;
    latest: string | null;
    reachable: boolean;
    downloadUrl: string | null;
  } | null = null;

  async about(): Promise<AboutSnapshot> {
    const version = currentVersion();
    const failure = readFailure();
    const remote = await this.latest();
    const updateAvailable =
      remote.reachable &&
      remote.latest != null &&
      compareVersions(version, remote.latest) < 0;
    return {
      version,
      latest: remote.latest,
      updateAvailable,
      reachable: remote.reachable,
      canUpdate: existsSync(dockerSock),
      phase: failure?.phase ?? this.phase,
      message: failure?.message ?? this.message,
      target: failure?.target ?? this.target,
    };
  }

  async start(): Promise<{ started: true; target: string }> {
    if (this.phase === 'downloading' || this.phase === 'applying') {
      throw new ConflictException('已经在更新了');
    }
    if (!existsSync(dockerSock)) {
      throw new ServiceUnavailableException(
        '这台部署没把 Docker 交给服务端，请在部署目录重新运行启动脚本',
      );
    }
    const version = currentVersion();
    const remote = await this.latest();
    if (!remote.reachable || !remote.latest || !remote.downloadUrl) {
      throw new ServiceUnavailableException('现在连不上 GitHub，查不了新版本');
    }
    if (compareVersions(version, remote.latest) >= 0) {
      throw new BadRequestException('已经是最新的');
    }

    this.phase = 'downloading';
    this.target = remote.latest;
    this.message = `正在下载 ${remote.latest}`;
    void this.apply(remote.latest, remote.downloadUrl).catch((error: unknown) => {
      const text = error instanceof Error ? error.message : String(error);
      this.logger.error(text);
      this.phase = 'failed';
      this.message = text;
    });
    return { started: true, target: remote.latest };
  }

  private async apply(version: string, downloadUrl: string): Promise<void> {
    const root = join(tmpdir(), 'flowdo-update');
    rmSync(root, { recursive: true, force: true });
    mkdirSync(root, { recursive: true });
    const zipPath = join(root, 'release.zip');
    const extractDir = join(root, 'pkg');
    mkdirSync(extractDir);

    await download(downloadUrl, zipPath);
    await execFileAsync('unzip', ['-o', '-q', zipPath, '-d', extractDir]);

    const deployDir = process.env.FLOWDO_DEPLOY_DIR ?? '/deploy';
    if (existsSync(deployDir)) {
      for (const name of releaseFiles) {
        const from = join(extractDir, name);
        if (!existsSync(from)) {
          continue;
        }
        copyFileSync(from, join(deployDir, name));
      }
      const startScript = join(deployDir, 'start.sh');
      if (existsSync(startScript)) {
        chmodSync(startScript, 0o755);
      }
    }

    this.phase = 'applying';
    this.message = '正在更换网页和接口，网页会短时间打不开';
    await loadImage(join(extractDir, 'flowdo-web-image.tar.gz'));
    await loadImage(join(extractDir, 'flowdo-server-image.tar.gz'));
    await recreateService('web', 'flowdo-web:latest');
    await startApiRestarter(version);
    rmSync(root, { recursive: true, force: true });
  }

  private async latest(): Promise<{
    latest: string | null;
    reachable: boolean;
    downloadUrl: string | null;
  }> {
    const now = Date.now();
    const ttl = this.latestCache?.reachable ? 5 * 60 * 1000 : 20 * 1000;
    if (this.latestCache && now - this.latestCache.at < ttl) {
      return this.latestCache;
    }
    try {
      const response = await fetch(latestUrl, {
        headers: {
          'User-Agent': 'FlowDo',
          Accept: 'application/vnd.github+json',
        },
        signal: AbortSignal.timeout(8000),
      });
      if (!response.ok) {
        throw new Error(`GitHub 返回 ${response.status}`);
      }
      const body = (await response.json()) as Release;
      const version = body.tag_name.replace(/^v/i, '');
      const asset = body.assets.find((item) => item.name === `FlowDo-v${version}.zip`);
      this.latestCache = {
        at: now,
        latest: version,
        reachable: true,
        downloadUrl: asset?.browser_download_url ?? null,
      };
    } catch (error) {
      const text = error instanceof Error ? error.message : String(error);
      this.logger.warn(`检查更新失败：${text}`);
      this.latestCache = {
        at: now,
        latest: null,
        reachable: false,
        downloadUrl: null,
      };
    }
    return this.latestCache;
  }
}

function currentVersion(): string {
  const raw = readFileSync(join(process.cwd(), 'package.json'), 'utf8');
  const parsed = JSON.parse(raw) as { version: string };
  return parsed.version;
}

function readFailure(): { phase: Phase; message: string; target: string | null } | null {
  const deployDir = process.env.FLOWDO_DEPLOY_DIR ?? '/deploy';
  const file = join(deployDir, '.flowdo-update-status.json');
  if (!existsSync(file)) {
    return null;
  }
  try {
    const parsed = JSON.parse(readFileSync(file, 'utf8')) as {
      phase?: Phase;
      message?: string;
      target?: string | null;
    };
    unlinkSync(file);
    if (parsed.phase !== 'failed' || !parsed.message) {
      return null;
    }
    return { phase: 'failed', message: parsed.message, target: parsed.target ?? null };
  } catch {
    return null;
  }
}

async function download(url: string, dest: string): Promise<void> {
  const response = await fetch(url, {
    headers: { 'User-Agent': 'FlowDo' },
    redirect: 'follow',
    signal: AbortSignal.timeout(10 * 60 * 1000),
  });
  if (!response.ok || !response.body) {
    throw new Error(`下载新版本失败（${response.status}）`);
  }
  const file = createWriteStream(dest);
  const reader = response.body.getReader();
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) {
        break;
      }
      if (value && !file.write(value)) {
        await new Promise<void>((resolve) => file.once('drain', () => resolve()));
      }
    }
  } catch (error) {
    file.destroy();
    throw error;
  }
  await new Promise<void>((resolve, reject) => {
    file.end(() => resolve());
    file.on('error', reject);
  });
}

/** 换接口容器会把自己停掉，所以交给一个独立容器来做，响应先送出去。 */
async function startApiRestarter(target: string): Promise<void> {
  await docker('DELETE', '/v1.44/containers/flowdo-apply-update?force=1').catch(() => undefined);
  const self = await inspectSelf();
  const sock = self.Mounts?.find((mount) => mount.Destination === '/var/run/docker.sock');
  const deploy = self.Mounts?.find((mount) => mount.Destination === '/deploy');
  const binds = [`${sock?.Source ?? '/var/run/docker.sock'}:/var/run/docker.sock`];
  const env = [`FLOWDO_UPDATE_TARGET=${target}`];
  if (deploy) {
    binds.push(`${deploy.Source}:/deploy`);
    env.push('FLOWDO_DEPLOY_DIR=/deploy');
  }
  const created = await docker<{ Id: string }>(
    'POST',
    '/v1.44/containers/create?name=flowdo-apply-update',
    {
      Image: 'flowdo-server:latest',
      Entrypoint: ['node', 'dist/system/apply-update.js'],
      Cmd: [],
      Env: env,
      WorkingDir: '/app',
      HostConfig: { AutoRemove: true, Binds: binds },
    },
  );
  await docker('POST', `/v1.44/containers/${created.Id}/start`);
}
