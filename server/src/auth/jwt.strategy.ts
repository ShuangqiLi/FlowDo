import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { INSTANCE_ID } from '../instance/constants';

export type AccessTokenPayload = {
  sub: string;
  type: 'access';
};

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(config: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.getOrThrow<string>('JWT_SECRET'),
    });
  }

  validate(payload: AccessTokenPayload) {
    if (payload.type !== 'access' || payload.sub !== INSTANCE_ID) {
      throw new UnauthorizedException('登录过期了，重新登一下吧');
    }
    return { instanceId: payload.sub };
  }
}
