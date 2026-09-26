import { writeFileSync } from 'node:fs';
import { recreateService } from './docker-engine';

const deployDir = process.env.FLOWDO_DEPLOY_DIR;

function rememberFailure(message: string): void {
  if (!deployDir) {
    return;
  }
  writeFileSync(
    `${deployDir}/.flowdo-update-status.json`,
    JSON.stringify({
      phase: 'failed',
      message,
      target: process.env.FLOWDO_UPDATE_TARGET ?? null,
    }),
  );
}

// 由更新流程拉起的一次性容器执行：等接口把响应送出，再换掉接口容器自己。
async function main(): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, 1500));
  try {
    await recreateService('api', 'flowdo-server:latest');
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    rememberFailure(message);
    console.error(message);
    process.exitCode = 1;
  }
}

const entry = process.argv[1]?.replaceAll('\\', '/');
if (entry?.endsWith('/system/apply-update.js') || entry?.endsWith('/system/apply-update.ts')) {
  void main();
}
