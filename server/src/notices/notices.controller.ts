import { Controller, Delete, Get, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { NoticesService } from './notices.service';

@Controller('notices')
@UseGuards(JwtAuthGuard)
export class NoticesController {
  constructor(private readonly notices: NoticesService) {}

  @Get()
  list() {
    return this.notices.list();
  }

  @Post('read')
  markRead() {
    return this.notices.markRead();
  }

  @Delete()
  clear() {
    return this.notices.clear();
  }
}
