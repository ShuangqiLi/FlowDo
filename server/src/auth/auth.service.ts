import { BadRequestException, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import type { SignOptions } from 'jsonwebtoken';
import { INSTANCE_ID } from '../instance/constants';
import { PrismaService } from '../prisma/prisma.service';
import { ChangePasswordDto, LoginDto, SetupPasswordDto } from './dto/auth.dto';
import { needsPasswordSetup } from './password-setup';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async status() {
    const instance = await this.prisma.instance.findUnique({
      where: { id: INSTANCE_ID },
    });
    return { needsSetup: needsPasswordSetup(instance) };
  }

  async setup(dto: SetupPasswordDto) {
    const instance = await this.prisma.instance.findUnique({
      where: { id: INSTANCE_ID },
    });
    if (!needsPasswordSetup(instance)) {
      throw new BadRequestException('密码已经设过了，直接登录就行');
    }
    await this.prisma.instance.update({
      where: { id: INSTANCE_ID },
      data: {
        passwordHash: await bcrypt.hash(dto.password, 10),
        mustChangePassword: false,
      },
    });
    return {
      ...(await this.issueTokens()),
      mustChangePassword: false,
    };
  }

  async login(dto: LoginDto) {
    const instance = await this.prisma.instance.findUnique({
      where: { id: INSTANCE_ID },
    });
    if (!instance || needsPasswordSetup(instance)) {
      throw new BadRequestException('先设一个密码再进来');
    }
    const ok = await bcrypt.compare(dto.password, instance.passwordHash);
    if (!ok) {
      throw new UnauthorizedException('密码好像对不上，再试试？');
    }
    return {
      ...(await this.issueTokens()),
      mustChangePassword: instance.mustChangePassword,
    };
  }

  async refresh(refreshToken: string) {
    try {
      const payload = await this.jwt.verifyAsync<{
        sub: string;
        type: string;
      }>(refreshToken, {
        secret: this.config.getOrThrow<string>('JWT_SECRET'),
      });
      if (payload.type !== 'refresh' || payload.sub !== INSTANCE_ID) {
        throw new UnauthorizedException('登录过期了，重新登一下吧');
      }
      const instance = await this.prisma.instance.findUnique({
        where: { id: INSTANCE_ID },
      });
      if (!instance) {
        throw new UnauthorizedException('登录过期了，重新登一下吧');
      }
      return this.issueTokens();
    } catch (error) {
      if (error instanceof UnauthorizedException) {
        throw error;
      }
      throw new UnauthorizedException('登录过期了，重新登一下吧');
    }
  }

  async changePassword(dto: ChangePasswordDto) {
    const instance = await this.prisma.instance.findUnique({
      where: { id: INSTANCE_ID },
    });
    if (!instance) {
      throw new UnauthorizedException('登录过期了，重新登一下吧');
    }
    const ok = await bcrypt.compare(dto.currentPassword, instance.passwordHash);
    if (!ok) {
      throw new BadRequestException('现在的密码好像对不上');
    }
    if (dto.currentPassword === dto.newPassword) {
      throw new BadRequestException('新密码和现在的一样，换一个吧');
    }
    await this.prisma.instance.update({
      where: { id: INSTANCE_ID },
      data: {
        passwordHash: await bcrypt.hash(dto.newPassword, 10),
        mustChangePassword: false,
      },
    });
    return { ok: true };
  }

  private async issueTokens() {
    const secret = this.config.getOrThrow<string>('JWT_SECRET');
    const accessExpires = (this.config.get('JWT_ACCESS_EXPIRES') ??
      '30m') as SignOptions['expiresIn'];
    const refreshExpires = (this.config.get('JWT_REFRESH_EXPIRES') ??
      '7d') as SignOptions['expiresIn'];
    const accessToken = await this.jwt.signAsync(
      { sub: INSTANCE_ID, type: 'access' },
      { secret, expiresIn: accessExpires },
    );
    const refreshToken = await this.jwt.signAsync(
      { sub: INSTANCE_ID, type: 'refresh' },
      { secret, expiresIn: refreshExpires },
    );
    return { accessToken, refreshToken };
  }
}
