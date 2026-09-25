import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import type { SignOptions } from 'jsonwebtoken';
import { PrismaService } from '../prisma/prisma.service';
import { LoginDto } from './dto/auth.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async login(dto: LoginDto) {
    const email = dto.email.toLowerCase().trim();
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) {
      throw new UnauthorizedException('邮箱或密码好像对不上，再试试？');
    }
    const ok = await bcrypt.compare(dto.password, user.passwordHash);
    if (!ok) {
      throw new UnauthorizedException('邮箱或密码好像对不上，再试试？');
    }
    return this.issueTokens(user.id, user.email);
  }

  async refresh(refreshToken: string) {
    try {
      const payload = await this.jwt.verifyAsync<{
        sub: string;
        email: string;
        type: string;
      }>(refreshToken, {
        secret: this.config.getOrThrow<string>('JWT_SECRET'),
      });
      if (payload.type !== 'refresh') {
        throw new UnauthorizedException('登录过期了，重新登一下吧');
      }
      const user = await this.prisma.user.findUnique({
        where: { id: payload.sub },
      });
      if (!user) {
        throw new UnauthorizedException('登录过期了，重新登一下吧');
      }
      return this.issueTokens(user.id, user.email);
    } catch {
      throw new UnauthorizedException('登录过期了，重新登一下吧');
    }
  }

  private async issueTokens(userId: string, email: string) {
    const secret = this.config.getOrThrow<string>('JWT_SECRET');
    const accessExpires = (this.config.get('JWT_ACCESS_EXPIRES') ??
      '30m') as SignOptions['expiresIn'];
    const refreshExpires = (this.config.get('JWT_REFRESH_EXPIRES') ??
      '7d') as SignOptions['expiresIn'];
    const accessToken = await this.jwt.signAsync(
      { sub: userId, email, type: 'access' },
      { secret, expiresIn: accessExpires },
    );
    const refreshToken = await this.jwt.signAsync(
      { sub: userId, email, type: 'refresh' },
      { secret, expiresIn: refreshExpires },
    );
    return { accessToken, refreshToken };
  }
}
