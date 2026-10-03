import { Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AboutSnapshot, SystemUpdateService } from './system-update.service';

@Controller('system')
@UseGuards(JwtAuthGuard)
export class SystemController {
  constructor(private readonly updates: SystemUpdateService) {}

  @Get('about')
  about(@Query('check') check?: string): Promise<AboutSnapshot> {
    return this.updates.about(check === '1' || check === 'true');
  }

  @Post('update')
  update(): Promise<{ started: true; target: string }> {
    return this.updates.start();
  }
}
