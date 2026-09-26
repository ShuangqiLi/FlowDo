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

export function docker<T>(
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
export function loadImage(filePath: string): Promise<void> {
  const size = statSync(filePath).size;
  return new Promise((resolve, reject) => {
    const req = httpRequest(
      {
        socketPath: dockerSock,
        path: '/v1.44/images/load',
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
    `/v1.44/containers/${hostname()}/json`,
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
    `/v1.44/containers/json?all=1&filters=${filters}`,
  );
  const found = list.find((item) => !item.Names.some((name) => name.endsWith('-old')));
  if (!found) {
    throw new Error(`找不到正在运行的 ${service} 容器`);
  }

  const info = await docker<DockerInspect>(
    'GET',
    `/v1.44/containers/${found.Id}/json`,
  );
  const name = info.Name.replace(/^\//, '');
  await docker('POST', `/v1.44/containers/${found.Id}/stop?t=20`);
  await docker(
    'POST',
    `/v1.44/containers/${found.Id}/rename?name=${encodeURIComponent(`${name}-old`)}`,
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
      `/v1.44/containers/create?name=${encodeURIComponent(name)}`,
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
    await docker('POST', `/v1.44/containers/${created.Id}/start`);
    await docker('DELETE', `/v1.44/containers/${found.Id}?force=1`);
  } catch (error) {
    await docker(
      'POST',
      `/v1.44/containers/${found.Id}/rename?name=${encodeURIComponent(name)}`,
    ).catch(() => undefined);
    await docker('POST', `/v1.44/containers/${found.Id}/start`).catch(() => undefined);
    throw error;
  }
}
