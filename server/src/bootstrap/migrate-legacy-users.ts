import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { randomUUID } from 'crypto';
import { DEFAULT_PASSWORD, DEFAULT_SPACE_NAME, INSTANCE_ID } from '../instance/constants';

type LegacyUser = {
  id: string;
  username: string;
  passwordHash: string;
  archiveAfterDays: number;
  focusLimit: number;
  deleteArchivedAfterDays: number;
  showArchiveTab: boolean;
  themeKey: string;
  voiceInputEnabled: boolean;
};

/**
 * 在 `prisma db push` 删掉 User 表之前，把每个旧账号收成一个任务空间。
 * 实例口令沿用按用户名排序后的第一个账号。已经有 Instance 表时什么都不做。
 */
export async function migrateLegacyUsers(prisma: PrismaClient): Promise<void> {
  const tables = await prisma.$queryRaw<Array<{ tablename: string }>>`
    SELECT tablename FROM pg_tables WHERE schemaname = 'public'
  `;
  const names = new Set(tables.map((row) => row.tablename));
  if (names.has('Instance') || !names.has('User')) {
    return;
  }

  const users = await prisma.$queryRaw<LegacyUser[]>`
    SELECT
      id,
      email AS username,
      "passwordHash",
      "archiveAfterDays",
      "focusLimit",
      "deleteArchivedAfterDays",
      "showArchiveTab",
      "themeKey",
      "voiceInputEnabled"
    FROM "User"
    ORDER BY email ASC
  `;

  await prisma.$transaction(async (tx) => {
    await tx.$executeRawUnsafe(`
      CREATE TABLE IF NOT EXISTS "Space" (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    `);
    await tx.$executeRawUnsafe(`
      CREATE TABLE IF NOT EXISTS "Instance" (
        id TEXT PRIMARY KEY,
        "passwordHash" TEXT NOT NULL,
        "mustChangePassword" BOOLEAN NOT NULL DEFAULT false,
        "activeSpaceId" TEXT,
        "archiveAfterDays" INTEGER NOT NULL DEFAULT 7,
        "focusLimit" INTEGER NOT NULL DEFAULT 3,
        "deleteArchivedAfterDays" INTEGER NOT NULL DEFAULT 30,
        "showArchiveTab" BOOLEAN NOT NULL DEFAULT true,
        "themeKey" TEXT NOT NULL DEFAULT 'mint',
        "voiceInputEnabled" BOOLEAN NOT NULL DEFAULT true,
        "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    `);

    const spaceByUser = new Map<string, string>();
    for (const user of users) {
      const spaceId = randomUUID();
      spaceByUser.set(user.id, spaceId);
      await tx.$executeRaw`
        INSERT INTO "Space" (id, name, "createdAt", "updatedAt")
        VALUES (${spaceId}, ${user.username}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      `;
    }

    let activeSpaceId: string;
    let passwordHash: string;
    let mustChangePassword = false;
    let settings = {
      archiveAfterDays: 7,
      focusLimit: 3,
      deleteArchivedAfterDays: 30,
      showArchiveTab: true,
      themeKey: 'mint',
      voiceInputEnabled: true,
    };
    const first = users[0];
    if (first) {
      activeSpaceId = spaceByUser.get(first.id)!;
      passwordHash = first.passwordHash;
      settings = {
        archiveAfterDays: first.archiveAfterDays,
        focusLimit: first.focusLimit,
        deleteArchivedAfterDays: first.deleteArchivedAfterDays,
        showArchiveTab: first.showArchiveTab,
        themeKey: first.themeKey,
        voiceInputEnabled: first.voiceInputEnabled,
      };
    } else {
      activeSpaceId = randomUUID();
      passwordHash = await bcrypt.hash(DEFAULT_PASSWORD, 10);
      mustChangePassword = true;
      await tx.$executeRaw`
        INSERT INTO "Space" (id, name, "createdAt", "updatedAt")
        VALUES (${activeSpaceId}, ${DEFAULT_SPACE_NAME}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      `;
    }

    if (names.has('Task')) {
      await tx.$executeRawUnsafe(
        `ALTER TABLE "Task" ADD COLUMN IF NOT EXISTS "spaceId" TEXT`,
      );
      for (const [userId, spaceId] of spaceByUser) {
        await tx.$executeRaw`
          UPDATE "Task" SET "spaceId" = ${spaceId} WHERE "userId" = ${userId}
        `;
      }
      await tx.$executeRaw`
        UPDATE "Task" SET "spaceId" = ${activeSpaceId} WHERE "spaceId" IS NULL
      `;
      await tx.$executeRawUnsafe(
        `ALTER TABLE "Task" ALTER COLUMN "spaceId" SET NOT NULL`,
      );
    }

    await tx.$executeRaw`
      INSERT INTO "Instance" (
        id, "passwordHash", "mustChangePassword", "activeSpaceId",
        "archiveAfterDays", "focusLimit", "deleteArchivedAfterDays",
        "showArchiveTab", "themeKey", "voiceInputEnabled",
        "createdAt", "updatedAt"
      ) VALUES (
        ${INSTANCE_ID}, ${passwordHash}, ${mustChangePassword}, ${activeSpaceId},
        ${settings.archiveAfterDays}, ${settings.focusLimit}, ${settings.deleteArchivedAfterDays},
        ${settings.showArchiveTab}, ${settings.themeKey}, ${settings.voiceInputEnabled},
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      )
    `;
  });

  const kept = users[0]?.username;
  console.log(
    `[flowdo] 已把 ${users.length} 个旧账号收成任务空间` +
      (kept ? `，登录密码沿用「${kept}」的密码` : ''),
  );
}

async function main() {
  const prisma = new PrismaClient();
  try {
    await migrateLegacyUsers(prisma);
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  main().catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exit(1);
  });
}
