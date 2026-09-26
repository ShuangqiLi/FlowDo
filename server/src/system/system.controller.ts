import { Controller, Get, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AboutSnapshot, SystemUpdateService } from './system-update.service';

@Controller('system')
@UseGuards(JwtAuthGuard)
export class SystemController {
  constructor(private readonly updates: SystemUpdateService) {}

  @Get('about')
  about(): Promise<AboutSnapshot> {
    return this.updates.about();
  }

  @Post('update')
  update(): Promise<{ started: true; target: string }> {
    return this.updates.start();
  }
}
