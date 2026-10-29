import { Body, Controller, Post } from '@nestjs/common';
import { AuthService } from './auth.service.js';
import { RefreshDto, RegisterDto, RequestOtpDto, VerifyOtpDto } from './auth.dto.js';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('otp/request')
  requestOtp(@Body() dto: RequestOtpDto) {
    return this.auth.requestOtp(dto.phone);
  }

  @Post('otp/verify')
  verifyOtp(@Body() dto: VerifyOtpDto) {
    return this.auth.verifyOtp(dto.phone, dto.code);
  }

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.auth.register(
      dto.registrationToken,
      dto.name,
      dto.gender,
      dto.role,
    );
  }

  @Post('refresh')
  refresh(@Body() dto: RefreshDto) {
    return this.auth.refresh(dto.refreshToken);
  }
}
