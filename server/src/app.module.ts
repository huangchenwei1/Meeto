import { Module } from '@nestjs/common';
import { AdminModule } from './admin/admin.module.js';
import { AuthModule } from './auth/auth.module.js';
import { HostsModule } from './hosts/hosts.module.js';
import { LedgerModule } from './ledger/ledger.module.js';
import { NotificationsModule } from './notifications/notifications.module.js';
import { OrdersModule } from './orders/orders.module.js';
import { PostsModule } from './posts/posts.module.js';
import { PricingModule } from './pricing/pricing.module.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { UploadsModule } from './uploads/uploads.module.js';
import { UsersModule } from './users/users.module.js';
import { VerificationModule } from './verification/verification.module.js';

@Module({
  imports: [
    PrismaModule,
    NotificationsModule,
    AuthModule,
    PricingModule,
    UsersModule,
    PostsModule,
    HostsModule,
    OrdersModule,
    LedgerModule,
    AdminModule,
    UploadsModule,
    VerificationModule,
  ],
})
export class AppModule {}
