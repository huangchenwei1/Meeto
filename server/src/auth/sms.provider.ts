import { Injectable, Logger } from '@nestjs/common';

/// Injection token for the SMS channel, mirroring PAYMENT_PROVIDER: the
/// real gateway (e.g. Twilio / Semaphore for PH numbers) slots in behind
/// this interface without touching auth logic.
export const SMS_PROVIDER = Symbol('SMS_PROVIDER');

export interface SmsProvider {
  sendOtp(phone: string, code: string): Promise<void>;
}

/// DEMO provider: no SMS is sent; the code is logged server-side and, in
/// non-production, echoed back by the API so clients can display it.
@Injectable()
export class MockSmsProvider implements SmsProvider {
  private readonly logger = new Logger(MockSmsProvider.name);

  async sendOtp(phone: string, code: string): Promise<void> {
    this.logger.log(`MOCK SMS to ${phone}: your Meeto code is ${code}`);
  }
}
