import { request as httpRequest } from 'node:http';
import { createReadStream, statSync } from 'node:fs';
import { hostname } from 'node:os';

export const dockerSock = process.env.DOCKER_SOCK ?? '/var/run/docker.sock';

type DockerInspect = {
  Name: string;
  Config: {
    Hostname: string;
    User: string;
    Env: string[] | null;
    Cmd: string[] | null;
    Entrypoint: string[] | null;
    Labels: Record<string, string> | null;
    WorkingDir: string;
    ExposedPorts: Record<string, unknown> | null;
    Healthcheck?: unknown;
  };
  HostConfig: Record<string, unknown> & {
    Binds?: string[] | null;
    Mounts?: unknown;
  };
  NetworkSettings: {
    Networks: Record<
      string,
      { Aliases?: string[] | null; IPAMConfig?: unknown; Links?: string[] | null }
    >;
  };
  Mounts?: { Source: string; Destination: string }[];
};

/// 我们用到的接口在 1.41 就都有了，这里只是上限：引擎更新也按这个版本说话。
const preferredApiVersion = '1.44';
const fallbackApiVersion = '1.41';

let negotiated: Promise<string> | null = null;

/**
 * 跟本机引擎商量 API 版本：取它支持的最高版本和 [preferredApiVersion] 里较小的那个。
 * 写死版本时，老一点的引擎（比如群晖自带的 Docker）会直接拒绝：
 * "client version 1.44 is too new. Maximum supported API version is 1.43"。
 */
export function apiVersion(): Promise<string> {
  negotiated ??= rawRequest<{ ApiVersion?: string }>('GET', '/version')
    .then((info) => pickApiVersion(info?.ApiVersion))
    .catch(() => {
      negotiated = null;
      return fallbackApiVersion;
    });
  return negotiated;
}

export function pickApiVersion(daemon: string | undefined): string {
  if (!daemon || !/^\d+\.\d+$/.test(daemon)) {
    return fallbackApiVersion;
  }
  return compareApi(daemon, preferredApiVersion) < 0 ? daemon : preferredApiVersion;
}

function compareApi(a: string, b: string): number {
  const [aMajor, aMinor] = a.split('.').map(Number);
  const [bMajor, bMinor] = b.split('.').map(Number);
  return aMajor - bMajor || aMinor - bMinor;
}

/** [path] 不带版本前缀，比如 `/containers/json`。 */
export async function docker<T>(
  method: string,
  path: string,
  body?: unknown,
): Promise<T> {
  return rawRequest<T>(method, `/v${await apiVersion()}${path}`, body);
}

function rawRequest<T>(
  method: string,
  path: string,
  body?: unknown,
): Promise<T> {
  const payload =
    body === undefined ? null : Buffer.from(JSON.stringify(body));
  return new Promise((resolve, reject) => {
    const req = httpRequest(
      {
        socketPath: dockerSock,
        path,
        method,
        headers: payload
          ? {
              'Content-Type': 'application/json',
              'Content-Length': payload.length,
            }
          : {},
      },
      (res) => {
        const chunks: Buffer[] = [];
        res.on('data', (chunk: Buffer) => chunks.push(chunk));
        res.on('end', () => {
          const text = Buffer.concat(chunks).toString('utf8');
          const status = res.statusCode ?? 500;
          if (status >= 300 && status !== 304) {
            reject(new Error(dockerError(text, status, method, path)));
            return;
          }
          if (!text) {
            resolve(undefined as T);
            return;
          }
          try {
            resolve(JSON.parse(text) as T);
          } catch {
            resolve(text as T);
          }
        });
      },
    );
    req.on('error', reject);
    req.setTimeout(0);
    if (payload) {
      req.end(payload);
    } else {
      req.end();
    }
  });
}

function dockerError(
  text: string,
  status: number,
  method: string,
  path: string,
): string {
  try {
    const parsed = JSON.parse(text) as { message?: string };
    if (parsed.message) {
      return parsed.message;
    }
  } catch {
    // 不是 JSON 就带上原文。
  }
  return text || `Docker ${method} ${path} 返回 ${status}`;
}

/** 把发版包里的镜像 tar（gzip 也行）装进本机 Docker。 */
export async function loadImage(filePath: string): Promise<void> {
  const size = statSync(filePath).size;
  const version = await apiVersion();
  return new Promise((resolve, reject) => {
    const req = httpRequest(
      {
        socketPath: dockerSock,
        path: `/v${version}/images/load`,
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-tar',
          'Content-Length': size,
        },
      },
      (res) => {
        const chunks: Buffer[] = [];
        res.on('data', (chunk: Buffer) => chunks.push(chunk));
        res.on('end', () => {
          const text = Buffer.concat(chunks).toString('utf8');
          if ((res.statusCode ?? 500) >= 300 || text.includes('"error"')) {
            reject(new Error(dockerError(text, res.statusCode ?? 500, 'POST', '/images/load')));
            return;
          }
          resolve();
        });
      },
    );
    req.on('error', reject);
    req.setTimeout(0);
    createReadStream(filePath).pipe(req);
  });
}

export async function inspectSelf(): Promise<DockerInspect> {
  return docker<DockerInspect>(
    'GET',
    `/containers/${hostname()}/json`,
  );
}

/**
 * 按原来的端口、环境变量和挂载重建一个 Compose 服务容器，镜像换成新加载的 tag。
 * 失败时把旧容器改回原名并重新启动。
 */
export async function recreateService(
  service: string,
  image: string,
): Promise<void> {
  const filters = encodeURIComponent(
    JSON.stringify({
      label: [
        'com.docker.compose.project=flowdo',
        `com.docker.compose.service=${service}`,
      ],
    }),
  );
  const list = await docker<{ Id: string; Names: string[] }[]>(
    'GET',
    `/containers/json?all=1&filters=${filters}`,
  );
  const found = list.find((item) => !item.Names.some((name) => name.endsWith('-old')));
  if (!found) {
    throw new Error(`找不到正在运行的 ${service} 容器`);
  }

  const info = await docker<DockerInspect>(
    'GET',
    `/containers/${found.Id}/json`,
  );
  const name = info.Name.replace(/^\//, '');
  await docker('POST', `/containers/${found.Id}/stop?t=20`);
  await docker(
    'POST',
    `/containers/${found.Id}/rename?name=${encodeURIComponent(`${name}-old`)}`,
  );

  try {
    const endpoints: Record<string, unknown> = {};
    for (const [network, cfg] of Object.entries(info.NetworkSettings.Networks ?? {})) {
      endpoints[network] = {
        ...(cfg.Aliases ? { Aliases: cfg.Aliases } : {}),
        ...(cfg.IPAMConfig ? { IPAMConfig: cfg.IPAMConfig } : {}),
        ...(cfg.Links ? { Links: cfg.Links } : {}),
      };
    }
    const hostConfig: Record<string, unknown> = { ...info.HostConfig };
    if (Array.isArray(hostConfig.Binds) && hostConfig.Binds.length > 0) {
      delete hostConfig.Mounts;
    } else {
      delete hostConfig.Binds;
    }
    delete hostConfig.ConsoleSize;

    const created = await docker<{ Id: string }>(
      'POST',
      `/containers/create?name=${encodeURIComponent(name)}`,
      {
        Hostname: info.Config.Hostname,
        User: info.Config.User,
        Env: info.Config.Env,
        Cmd: info.Config.Cmd,
        Entrypoint: info.Config.Entrypoint,
        Image: image,
        Labels: info.Config.Labels,
        WorkingDir: info.Config.WorkingDir,
        ExposedPorts: info.Config.ExposedPorts,
        Healthcheck: info.Config.Healthcheck,
        HostConfig: hostConfig,
        NetworkingConfig: { EndpointsConfig: endpoints },
      },
    );
    await docker('POST', `/containers/${created.Id}/start`);
    await docker('DELETE', `/containers/${found.Id}?force=1`);
  } catch (error) {
    await docker(
      'POST',
      `/containers/${found.Id}/rename?name=${encodeURIComponent(name)}`,
    ).catch(() => undefined);
    await docker('POST', `/containers/${found.Id}/start`).catch(() => undefined);
    throw error;
  }
}
