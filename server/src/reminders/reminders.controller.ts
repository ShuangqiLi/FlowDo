import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ReminderDto } from './dto/reminder.dto';
import { RemindersService } from './reminders.service';

@Controller('reminders')
@UseGuards(JwtAuthGuard)
export class RemindersController {
  constructor(private readonly reminders: RemindersService) {}

  @Get()
  list() {
    return this.reminders.list();
  }

  @Post()
  create(@Body() dto: ReminderDto) {
    return this.reminders.create(dto);
  }

  @Patch(':id')
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: ReminderDto) {
    return this.reminders.update(id, dto);
  }

  @Post(':id/ack')
  acknowledge(@Param('id', ParseUUIDPipe) id: string) {
    return this.reminders.acknowledge(id);
  }

  @Delete(':id')
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.reminders.remove(id);
  }
}
