import { IsEmail, IsString } from 'class-validator';

export class LoginDto {
  @IsEmail({}, { message: '这看起来不像邮箱地址哦' })
  email!: string;

  @IsString({ message: '密码还没填呢' })
  password!: string;
}

export class RefreshDto {
  @IsString({ message: '登录过期了，重新登一下吧' })
  refreshToken!: string;
}
