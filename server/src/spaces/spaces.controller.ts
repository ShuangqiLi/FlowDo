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
import { SpaceNameDto } from './dto/space.dto';
import { SpacesService } from './spaces.service';

@Controller('spaces')
@UseGuards(JwtAuthGuard)
export class SpacesController {
  constructor(private readonly spaces: SpacesService) {}

  @Get()
  list() {
    return this.spaces.list();
  }

  @Post()
  create(@Body() dto: SpaceNameDto) {
    return this.spaces.create(dto);
  }

  @Get(':id/task-count')
  taskCount(@Param('id', ParseUUIDPipe) id: string) {
    return this.spaces.taskCount(id);
  }

  @Patch(':id')
  rename(@Param('id', ParseUUIDPipe) id: string, @Body() dto: SpaceNameDto) {
    return this.spaces.rename(id, dto);
  }

  @Delete(':id')
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.spaces.remove(id);
  }
}
