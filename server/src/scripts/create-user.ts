import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

function usage(): never {
  console.error("用法：npm run user:create -- <邮箱> '<至少 8 位的密码>'");
  process.exit(2);
}

async function main() {
  const [, , rawEmail, password] = process.argv;
  if (!rawEmail || !password) {
    usage();
  }

  const email = rawEmail.toLowerCase().trim();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new Error('邮箱格式不对');
  }
  if (password.length < 8) {
    throw new Error('密码至少要 8 位');
  }

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    throw new Error(`账号 ${email} 已经存在`);
  }

  const passwordHash = await bcrypt.hash(password, 10);
  await prisma.user.create({ data: { email, passwordHash } });
  console.log(`账号 ${email} 已创建`);
}

main()
  .catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
