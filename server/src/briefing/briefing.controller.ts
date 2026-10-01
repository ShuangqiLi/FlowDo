import { BadRequestException, Controller, Get, ParseIntPipe, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { BriefingService } from './briefing.service';

@Controller('briefing')
@UseGuards(JwtAuthGuard)
export class BriefingController {
  constructor(private readonly briefing: BriefingService) {}

  @Get('today')
  today() {
    return this.briefing.today();
  }

  @Get('month')
  month(
    @Query('year', new ParseIntPipe({ exceptionFactory: () => new BadRequestException('年份不太对') }))
    year: number,
    @Query('month', new ParseIntPipe({ exceptionFactory: () => new BadRequestException('月份不太对') }))
    month: number,
  ) {
    return this.briefing.month(year, month);
  }
}
