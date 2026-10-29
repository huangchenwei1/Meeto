import {
  BadRequestException,
  Controller,
  Module,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { randomUUID } from 'node:crypto';
import { existsSync, mkdirSync } from 'node:fs';
import { extname, join } from 'node:path';
import { diskStorage } from 'multer';
import { AuthGuard } from '../common/auth.guard.js';

/// Local-disk media storage for development; production swaps this for
/// object storage (S3/GCS) behind the same endpoint. Files are served
/// statically under /uploads (configured in main.ts) and stored as
/// root-relative URLs so a host/CDN change never rewrites data.
export const UPLOADS_DIR = join(process.cwd(), 'uploads');

const ALLOWED_MIME = new Set<string>([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
]);

@Controller('uploads')
@UseGuards(AuthGuard)
export class UploadsController {
  @Post()
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: (_req, _file, cb) => {
          if (!existsSync(UPLOADS_DIR)) {
            mkdirSync(UPLOADS_DIR, { recursive: true });
          }
          cb(null, UPLOADS_DIR);
        },
        filename: (_req, file, cb) => {
          cb(null, `${randomUUID()}${extname(file.originalname) || '.jpg'}`);
        },
      }),
      limits: { fileSize: 8 * 1024 * 1024 },
      fileFilter: (_req, file, cb) => {
        cb(null, ALLOWED_MIME.has(file.mimetype));
      },
    }),
  )
  upload(@UploadedFile() file?: Express.Multer.File): { url: string } {
    if (!file) {
      throw new BadRequestException('Expected an image file field "file"');
    }
    return { url: `/uploads/${file.filename}` };
  }
}

@Module({ controllers: [UploadsController] })
export class UploadsModule {}
