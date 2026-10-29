import { Global, Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AuthController } from './auth.controller.js';
import { AuthService } from './auth.service.js';
import { MockSmsProvider, SMS_PROVIDER } from './sms.provider.js';

/// Global so the auth guard (used by every feature module) can inject
/// AuthService without each module importing AuthModule.
@Global()
@Module({
  imports: [
    JwtModule.register({
      global: true,
      // Dev fallback secret; production must set JWT_SECRET.
      secret: process.env.JWT_SECRET ?? 'meeto-dev-secret-change-me',
    }),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    { provide: SMS_PROVIDER, useClass: MockSmsProvider },
  ],
  exports: [AuthService],
})
export class AuthModule {}
