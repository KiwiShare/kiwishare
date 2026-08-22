import Router from 'koa-router';
import { uploadToR2, getPresignedUploadUrl, getR2ObjectStream, R2_CONFIG } from '../config/r2';
import { authenticateToken } from '../middleware/auth';

const router = new Router();

/**
 * POST /api/upload
 * Uploads an image directly to Cloudflare R2 bucket `kiwishare`
 */
router.post('/upload', authenticateToken, async (ctx) => {
  const { imageBase64, fileName, contentType } = ctx.request.body as any;

  if (!imageBase64) {
    ctx.status = 400;
    ctx.body = {
      status: 'error',
      message: 'Missing imageBase64 payload in request body.'
    };
    return;
  }

  try {
    // Strip data URL prefix if present (e.g. data:image/png;base64,...)
    const cleanBase64 = imageBase64.replace(/^data:image\/\w+;base64,/, '');
    const buffer = Buffer.from(cleanBase64, 'base64');
    const name = fileName || `kiwishare_item_${Date.now()}.jpg`;
    const mime = contentType || 'image/jpeg';

    const result = await uploadToR2(buffer, name, mime);

    ctx.status = 201;
    ctx.body = {
      status: 'success',
      message: 'Image uploaded successfully to Cloudflare R2.',
      url: result.url,
      key: result.key,
      bucket: result.bucket,
      storageEndpoint: R2_CONFIG.endpoint
    };
  } catch (err: any) {
    ctx.status = 500;
    ctx.body = {
      status: 'error',
      message: err.message || 'Failed to upload image.'
    };
  }
});

/**
 * POST /api/upload/presign
 * Generates an S3 presigned URL for direct client-side upload to Cloudflare R2
 */
router.post('/upload/presign', authenticateToken, async (ctx) => {
  const { fileName, contentType } = ctx.request.body as any;

  try {
    const name = fileName || `upload_${Date.now()}.jpg`;
    const mime = contentType || 'image/jpeg';

    const result = await getPresignedUploadUrl(name, mime);

    ctx.status = 200;
    ctx.body = {
      status: 'success',
      uploadUrl: result.uploadUrl,
      publicUrl: result.publicUrl,
      key: result.key,
      bucket: R2_CONFIG.bucketName,
      endpoint: R2_CONFIG.endpoint
    };
  } catch (err: any) {
    ctx.status = 500;
    ctx.body = {
      status: 'error',
      message: err.message || 'Failed to generate R2 presigned URL.'
    };
  }
});

/**
 * GET /api/images/:filename
 * Streams image files directly from Cloudflare R2
 */
router.get('/images/:filename+', async (ctx) => {
  const rawParam = ctx.params.filename || '';
  const filename = rawParam.replace(/^images\//, '');
  if (!filename) {
    ctx.status = 404;
    return;
  }

  try {
    const r2Stream = await getR2ObjectStream(`images/${filename}`);
    if (r2Stream.Body) {
      ctx.type = r2Stream.ContentType || 'image/jpeg';
      ctx.set('Cache-Control', 'public, max-age=31536000');
      ctx.body = r2Stream.Body as any;
      return;
    }
  } catch (err) {
    // Return 404
  }

  ctx.status = 404;
  ctx.body = { status: 'error', message: 'Image not found.' };
});

export default router;
