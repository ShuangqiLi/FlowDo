import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { ArchiveModule } from './archive/archive.module';
import { AuthModule } from './auth/auth.module';
import { BriefingModule } from './briefing/briefing.module';
import { HealthController } from './health.controller';
import { PrismaModule } from './prisma/prisma.module';
import { TasksModule } from './tasks/tasks.module';
import { UsersModule } from './users/users.module';

@Module({
  controllers: [HealthController],
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ScheduleModule.forRoot(),
    PrismaModule,
    AuthModule,
    UsersModule,
    TasksModule,
    BriefingModule,
    ArchiveModule,
  ],
})
export class AppModule {}
