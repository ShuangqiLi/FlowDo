import { Module } from '@nestjs/common';
import { BriefingController } from './briefing.controller';
import { BriefingService } from './briefing.service';

@Module({
  controllers: [BriefingController],
  providers: [BriefingService],
})
export class BriefingModule {}
