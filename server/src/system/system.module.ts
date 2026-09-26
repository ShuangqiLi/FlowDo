import { Module } from '@nestjs/common';
import { SystemController } from './system.controller';
import { SystemUpdateService } from './system-update.service';

@Module({
  controllers: [SystemController],
  providers: [SystemUpdateService],
})
export class SystemModule {}
