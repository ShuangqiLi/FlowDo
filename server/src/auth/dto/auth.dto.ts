import { IsNotEmpty, IsString } from 'class-validator';

export class LoginDto {
  @IsString({ message: '用户名还没填呢' })
  @IsNotEmpty({ message: '用户名还没填呢' })
  username!: string;

  @IsString({ message: '密码还没填呢' })
  @IsNotEmpty({ message: '密码还没填呢' })
  password!: string;
}

export class RefreshDto {
  @IsString({ message: '登录过期了，重新登一下吧' })
  refreshToken!: string;
}
