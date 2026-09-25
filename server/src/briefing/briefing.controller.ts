import { Controller, Get, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { BriefingService } from './briefing.service';

@Controller('briefing')
@UseGuards(JwtAuthGuard)
export class BriefingController {
  constructor(private readonly briefing: BriefingService) {}

  @Get('today')
  today(@CurrentUser() user: AuthUser) {
    return this.briefing.today(user.userId);
  }
}
