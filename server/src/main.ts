import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module.js';
import { UPLOADS_DIR } from './uploads/uploads.module.js';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  app.useGlobalPipes(
    new ValidationPipe({ whitelist: true, transform: true }),
  );
  // Uploaded media (avatars, profile photos). Local disk for development;
  // production serves media from object storage/CDN instead.
  app.useStaticAssets(UPLOADS_DIR, { prefix: '/uploads/' });
  await app.listen(process.env.PORT ?? 3000);
}
await bootstrap();
