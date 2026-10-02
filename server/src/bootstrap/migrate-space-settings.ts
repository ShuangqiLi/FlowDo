import { PrismaClient } from '@prisma/client';

/**
 * 在 `prisma db push` 之前：
 * 1. 若 Instance 还带着主题/归档字段而 Space 没有，先把值拷到每个空间；
 * 2. 丢掉 Reminder 表（提醒事项已下线）。
 */
export async function migrateSpaceSettings(prisma: PrismaClient): Promise<void> {
  const columns = await prisma.$queryRaw<Array<{ table_name: string; column_name: string }>>`
    SELECT table_name, column_name
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name IN ('Instance', 'Space', 'Reminder')
  `;
  const byTable = new Map<string, Set<string>>();
  for (const row of columns) {
    const set = byTable.get(row.table_name) ?? new Set<string>();
    set.add(row.column_name);
    byTable.set(row.table_name, set);
  }

  if (byTable.has('Reminder')) {
    await prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS "Reminder" CASCADE`);
    console.log('[flowdo] 已去掉提醒事项表');
  }

  const instanceCols = byTable.get('Instance');
  const spaceCols = byTable.get('Space');
  if (!instanceCols || !spaceCols) {
    return;
  }
  if (!instanceCols.has('themeKey') || spaceCols.has('themeKey')) {
    return;
  }

  await prisma.$executeRawUnsafe(`
    ALTER TABLE "Space"
      ADD COLUMN IF NOT EXISTS "archiveAfterDays" INTEGER NOT NULL DEFAULT 7,
      ADD COLUMN IF NOT EXISTS "focusLimit" INTEGER NOT NULL DEFAULT 3,
      ADD COLUMN IF NOT EXISTS "deleteArchivedAfterDays" INTEGER NOT NULL DEFAULT 30,
      ADD COLUMN IF NOT EXISTS "showArchiveTab" BOOLEAN NOT NULL DEFAULT true,
      ADD COLUMN IF NOT EXISTS "themeKey" TEXT NOT NULL DEFAULT 'mint'
  `);

  await prisma.$executeRawUnsafe(`
    UPDATE "Space" AS s
    SET
      "archiveAfterDays" = i."archiveAfterDays",
      "focusLimit" = i."focusLimit",
      "deleteArchivedAfterDays" = i."deleteArchivedAfterDays",
      "showArchiveTab" = i."showArchiveTab",
      "themeKey" = i."themeKey"
    FROM "Instance" AS i
    WHERE i.id = 'default'
  `);

  console.log('[flowdo] 已把主题、聚焦和归档设置拷到各个任务空间');
}

async function main() {
  const prisma = new PrismaClient();
  try {
    await migrateSpaceSettings(prisma);
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
