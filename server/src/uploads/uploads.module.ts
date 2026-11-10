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
import { join } from 'node:path';
import { diskStorage } from 'multer';
import { AuthGuard } from '../common/auth.guard.js';

/// Local-disk media storage for development; production swaps this for
/// object storage (S3/GCS) behind the same endpoint. Files are served
/// statically under /uploads (configured in main.ts) and stored as
/// root-relative URLs so a host/CDN change never rewrites data.
export const UPLOADS_DIR = join(process.cwd(), 'uploads');

/// The stored extension is derived from the declared image mime, never
/// from the client-supplied filename: a file named "evil.html" would
/// otherwise be stored and statically served as HTML (stored XSS).
const MIME_EXT: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/heic': '.heic',
};

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
          cb(null, `${randomUUID()}${MIME_EXT[file.mimetype] ?? '.jpg'}`);
        },
      }),
      limits: { fileSize: 8 * 1024 * 1024 },
      fileFilter: (_req, file, cb) => {
        cb(null, file.mimetype in MIME_EXT);
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
