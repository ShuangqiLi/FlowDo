import { IsString, MaxLength, MinLength } from 'class-validator';

export class SpaceNameDto {
  @IsString({ message: '空间名字还没写呢' })
  @MinLength(1, { message: '空间名字还没写呢' })
  @MaxLength(40, { message: '空间名字太长啦' })
  name!: string;
}
