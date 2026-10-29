import { Type } from 'class-transformer';
import { IsInt, Min } from 'class-validator';

export class WithdrawalInputDto {
  @IsInt()
  @Min(1)
  @Type(() => Number)
  amountMinor!: number;
}
