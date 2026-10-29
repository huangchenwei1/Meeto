import { IsIn, IsNotEmpty, IsString, Matches } from 'class-validator';
import { Gender, RegistrableRoles, Role } from '../common/enums.js';

const PHONE_PATTERN = /^\+[1-9]\d{7,14}$/; // E.164

export class RequestOtpDto {
  @IsString()
  @Matches(PHONE_PATTERN, { message: 'phone must be E.164, e.g. +639171234567' })
  phone!: string;
}

export class VerifyOtpDto {
  @IsString()
  @Matches(PHONE_PATTERN, { message: 'phone must be E.164, e.g. +639171234567' })
  phone!: string;

  @IsString()
  @IsNotEmpty()
  code!: string;
}

export class RegisterDto {
  @IsString()
  @IsNotEmpty()
  registrationToken!: string;

  @IsString()
  @IsNotEmpty()
  name!: string;

  @IsIn(Object.values(Gender))
  gender!: Gender;

  @IsIn(RegistrableRoles)
  role!: Role;
}

export class RefreshDto {
  @IsString()
  @IsNotEmpty()
  refreshToken!: string;
}
