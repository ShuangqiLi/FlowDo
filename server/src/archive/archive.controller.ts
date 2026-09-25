import { Controller, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ArchiveService } from './archive.service';

@Controller('archive')
export class ArchiveController {
  constructor(private readonly archive: ArchiveService) {}

  @Post('run')
  @UseGuards(JwtAuthGuard)
  async run() {
    const archived = await this.archive.runArchive();
    const deleted = await this.archive.runPurge();
    return { archived, deleted };
  }
}
