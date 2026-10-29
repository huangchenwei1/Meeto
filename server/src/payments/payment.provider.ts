import { Injectable } from '@nestjs/common';

export const PAYMENT_PROVIDER = Symbol('PAYMENT_PROVIDER');

export interface ChargeInput {
  orderId: string;
  payerId: string;
  amountMinor: number;
}

export interface ChargeResult {
  externalRef: string;
}

/// Payment channel abstraction. Production implementations (GCash / Maya /
/// cards) slot in behind this interface via the PAYMENT_PROVIDER token;
/// order logic never changes.
export interface PaymentProvider {
  charge(input: ChargeInput): Promise<ChargeResult>;
  refund(externalRef: string, amountMinor: number): Promise<void>;
}

/// Demo provider: every charge succeeds instantly, refunds are no-ops.
@Injectable()
export class MockPaymentProvider implements PaymentProvider {
  private sequence = 0;

  charge(input: ChargeInput): Promise<ChargeResult> {
    return Promise.resolve({
      externalRef: `mock-charge-${input.orderId}-${++this.sequence}`,
    });
  }

  refund(): Promise<void> {
    return Promise.resolve();
  }
}
