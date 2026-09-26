import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

function usage(): never {
  console.error("用法：npm run user:create -- <用户名> '<密码>'");
  console.error("例如：npm run user:create -- user 'password'");
  process.exit(2);
}

// 账号只能在部署机上建，不对外开放注册，所以这里不设复杂规则：
// 用户名不为空且不含空白，密码不为空即可。
async function main() {
  const [, , rawUsername, password] = process.argv;
  if (!rawUsername || !password) {
    usage();
  }

  const username = rawUsername.trim();
  if (!username) {
    throw new Error('用户名不能为空');
  }
  if (/\s/.test(username)) {
    throw new Error('用户名里不能有空格');
  }

  const existing = await prisma.user.findUnique({ where: { username } });
  if (existing) {
    throw new Error(`账号 ${username} 已经存在`);
  }

  const passwordHash = await bcrypt.hash(password, 10);
  await prisma.user.create({ data: { username, passwordHash } });
  console.log(`账号 ${username} 已创建`);
}

main()
  .catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
