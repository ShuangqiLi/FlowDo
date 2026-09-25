import { IsBoolean, IsIn, IsInt, IsOptional, Max, Min } from 'class-validator';

export class UpdateMeDto {
  @IsOptional()
  @IsInt({ message: '归档天数请填整数' })
  @Min(0, { message: '归档天数不能是负数哦' })
  @Max(365, { message: '先别设超过 365 天' })
  archiveAfterDays?: number;

  @IsOptional()
  @IsInt({ message: '聚焦上限请填整数' })
  @Min(1, { message: '至少得盯 1 件吧' })
  @Max(20, { message: '一次盯太多啦，最多 20 件' })
  focusLimit?: number;

  @IsOptional()
  @IsInt({ message: '清理天数请填整数' })
  @Min(0, { message: '清理天数不能是负数哦，0 表示永不自动清掉' })
  @Max(365, { message: '先别设超过 365 天' })
  deleteArchivedAfterDays?: number;

  @IsOptional()
  @IsBoolean({ message: '显示归档请用开或关' })
  showArchiveTab?: boolean;

  @IsOptional()
  @IsIn(['mint', 'hazeBlue', 'warmOrange', 'lightPurple'], {
    message: '还没有这个主题哦',
  })
  themeKey?: string;
}
