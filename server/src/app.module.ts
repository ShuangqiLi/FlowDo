import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { ArchiveModule } from './archive/archive.module';
import { AuthModule } from './auth/auth.module';
import { BriefingModule } from './briefing/briefing.module';
import { HealthController } from './health.controller';
import { NoticesModule } from './notices/notices.module';
import { InstanceModule } from './instance/instance.module';
import { PrismaModule } from './prisma/prisma.module';
import { SpacesModule } from './spaces/spaces.module';
import { SystemModule } from './system/system.module';
import { TasksModule } from './tasks/tasks.module';
import { UsersModule } from './users/users.module';

@Module({
  controllers: [HealthController],
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ScheduleModule.forRoot(),
    PrismaModule,
    InstanceModule,
    AuthModule,
    UsersModule,
    SpacesModule,
    TasksModule,
    NoticesModule,
    BriefingModule,
    ArchiveModule,
    SystemModule,
  ],
})
export class AppModule {}
