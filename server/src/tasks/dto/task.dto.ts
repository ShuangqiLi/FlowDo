import { TaskPriority, TaskStatus } from '../task.enums';
import { IsEnum, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateTaskDto {
  @IsString({ message: '标题空空的，写几个字吧' })
  @MinLength(1, { message: '标题空空的，写几个字吧' })
  @MaxLength(200, { message: '标题太长啦，精简一点' })
  title!: string;

  @IsOptional()
  @IsString({ message: '记录要用文字来写哦' })
  @MaxLength(20000, { message: '记太多了，先删一点再存' })
  body?: string;

  @IsOptional()
  @IsEnum(TaskPriority, { message: '优先级只能是高、中、低' })
  priority?: TaskPriority;
}

export class UpdateTaskDto {
  @IsOptional()
  @IsString({ message: '标题空空的，写几个字吧' })
  @MinLength(1, { message: '标题空空的，写几个字吧' })
  @MaxLength(200, { message: '标题太长啦，精简一点' })
  title?: string;

  @IsOptional()
  @IsString({ message: '记录要用文字来写哦' })
  @MaxLength(20000, { message: '记太多了，先删一点再存' })
  body?: string | null;

  @IsOptional()
  @IsEnum(TaskPriority, { message: '优先级只能是高、中、低' })
  priority?: TaskPriority;

  @IsOptional()
  @IsEnum(TaskStatus, { message: '这个状态我还不认识' })
  status?: TaskStatus;
}
