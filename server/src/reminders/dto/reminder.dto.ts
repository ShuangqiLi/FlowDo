import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { ReminderCalendar, ReminderKind, ReminderRecurrence } from '@prisma/client';

export class ReminderDto {
  @IsString({ message: '提醒写几个字吧' })
  @MinLength(1, { message: '提醒写几个字吧' })
  @MaxLength(200, { message: '提醒太长啦，精简一点' })
  title!: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000, { message: '备注太长啦' })
  note?: string | null;

  @IsEnum(ReminderCalendar, { message: '选公历或者农历' })
  calendar!: ReminderCalendar;

  @IsEnum(ReminderRecurrence, { message: '这个重复方式还不认识' })
  recurrence!: ReminderRecurrence;

  @IsOptional()
  @IsEnum(ReminderKind, { message: '这个提醒类型还不认识' })
  kind?: ReminderKind;

  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: '日期要写成 YYYY-MM-DD' })
  date?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(12)
  lunarMonth?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(30)
  lunarDay?: number;

  @IsOptional()
  @IsBoolean()
  leapMonth?: boolean;
}
