import { IsEmail, IsString, MinLength } from 'class-validator';

export class RegisterDto {
  @IsEmail({}, { message: '这看起来不像邮箱地址哦' })
  email!: string;

  @IsString({ message: '密码还没填呢' })
  @MinLength(8, { message: '密码再长一点吧，至少 8 位' })
  password!: string;
}

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
