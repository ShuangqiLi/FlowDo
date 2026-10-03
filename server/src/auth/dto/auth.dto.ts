import { IsNotEmpty, IsString, MinLength } from 'class-validator';

export class LoginDto {
  @IsString({ message: '密码还没填呢' })
  @IsNotEmpty({ message: '密码还没填呢' })
  password!: string;
}

export class RefreshDto {
  @IsString({ message: '登录过期了，重新登一下吧' })
  refreshToken!: string;
}

export class SetupPasswordDto {
  @IsString({ message: '密码还没填呢' })
  @MinLength(1, { message: '密码还没填呢' })
  password!: string;
}

export class ChangePasswordDto {
  @IsString({ message: '现在的密码还没填呢' })
  @IsNotEmpty({ message: '现在的密码还没填呢' })
  currentPassword!: string;

  @IsString({ message: '新密码还没填呢' })
  @MinLength(1, { message: '新密码还没填呢' })
  newPassword!: string;
}
