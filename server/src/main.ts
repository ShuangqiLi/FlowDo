import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { PrismaClient } from '@prisma/client';
import { AppModule } from './app.module';
import { ensureInstance } from './instance/ensure-instance';

async function bootstrap() {
  const prisma = new PrismaClient();
  try {
    await ensureInstance(prisma);
  } finally {
    await prisma.$disconnect();
  }
  const app = await NestFactory.create(AppModule);
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
      // 一个字段只报一条，免得"用户名还没填呢"重复出现。
      stopAtFirstError: true,
    }),
  );
  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port, '0.0.0.0');
}
void bootstrap();
