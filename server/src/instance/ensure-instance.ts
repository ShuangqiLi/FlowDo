import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { DEFAULT_PASSWORD, DEFAULT_SPACE_NAME, INSTANCE_ID } from './constants';

/** 空库补上唯一实例和「默认」空间。已有实例时只保证当前空间还在。 */
export async function ensureInstance(prisma: PrismaClient): Promise<void> {
  const existing = await prisma.instance.findUnique({
    where: { id: INSTANCE_ID },
  });
  if (!existing) {
    const space = await prisma.space.create({
      data: { name: DEFAULT_SPACE_NAME },
    });
    await prisma.instance.create({
      data: {
        id: INSTANCE_ID,
        passwordHash: await bcrypt.hash(DEFAULT_PASSWORD, 10),
        mustChangePassword: true,
        activeSpaceId: space.id,
      },
    });
    console.log('[flowdo] 已创建实例，使用初始密码登录后会要求立刻修改');
    return;
  }

  if (existing.activeSpaceId) {
    const active = await prisma.space.findUnique({
      where: { id: existing.activeSpaceId },
    });
    if (active) {
      return;
    }
  }

  const space =
    (await prisma.space.findFirst({ orderBy: { createdAt: 'asc' } })) ??
    (await prisma.space.create({ data: { name: DEFAULT_SPACE_NAME } }));
  await prisma.instance.update({
    where: { id: INSTANCE_ID },
    data: { activeSpaceId: space.id },
  });
}
