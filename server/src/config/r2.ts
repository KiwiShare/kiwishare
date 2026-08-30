import 'dotenv/config';
import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  HeadObjectCommand
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import crypto from 'crypto';

export const R2_CONFIG = {
  get accountId() { return process.env.R2_ACCOUNT_ID || 'cdc04de9bc4c6a41b5003758e505a0d1'; },
  get bucketName() { return process.env.R2_BUCKET || 'kiwishare'; },
  get endpoint() { return process.env.R2_ENDPOINT || 'https://cdc04de9bc4c6a41b5003758e505a0d1.r2.cloudflarestorage.com'; },
  get accessKeyId() { return process.env.R2_ACCESS_KEY_ID || process.env.AWS_ACCESS_KEY_ID || ''; },
  get secretAccessKey() { return process.env.R2_SECRET_ACCESS_KEY || process.env.AWS_SECRET_ACCESS_KEY || ''; },
  get publicUrlBase() { return process.env.R2_PUBLIC_URL || 'https://assets.kiwishare.online'; },
};

export function getS3Client(): S3Client {
  return new S3Client({
    region: 'auto',
    endpoint: R2_CONFIG.endpoint,
    credentials: {
      accessKeyId: R2_CONFIG.accessKeyId || 'placeholder_key',
      secretAccessKey: R2_CONFIG.secretAccessKey || 'placeholder_secret',
    },
  });
}

export const r2S3Client = getS3Client();

export function normalizeR2Folder(folder?: unknown): string {
  if (folder == null || folder === '') {
    return 'images';
  }
  if (typeof folder !== 'string') {
    throw new Error('Invalid R2 upload folder.');
  }

  const normalized = folder.trim().replace(/^\/+|\/+$/g, '');
  const root = normalized.split('/')[0];
  if (
    !/^[A-Za-z0-9_-]+(?:\/[A-Za-z0-9_-]+)*$/.test(normalized) ||
    !['images', 'audio', 'test'].includes(root)
  ) {
    throw new Error('Invalid R2 upload folder.');
  }
  return normalized;
}

function createR2ObjectKey(fileName: string, folder?: unknown): string {
  const ext = fileName.split('.').pop()?.replace(/[^A-Za-z0-9]/g, '') || 'jpg';
  const fileBasename = `${Date.now()}_${crypto.randomBytes(6).toString('hex')}.${ext}`;
  return `${normalizeR2Folder(folder)}/${fileBasename}`;
}

/**
 * Uploads a file buffer directly to Cloudflare R2 bucket `kiwishare`
 */
export async function uploadToR2(
  fileBuffer: Buffer,
  fileName: string,
  contentType: string = 'image/jpeg',
  folder?: unknown
): Promise<{ url: string; key: string; bucket: string }> {
  const uniqueKey = createR2ObjectKey(fileName, folder);

  // Upload directly to Cloudflare R2 S3 bucket
  if (R2_CONFIG.accessKeyId && R2_CONFIG.secretAccessKey) {
    try {
      const client = getS3Client();
      const command = new PutObjectCommand({
        Bucket: R2_CONFIG.bucketName,
        Key: uniqueKey,
        Body: fileBuffer,
        ContentType: contentType,
      });
      await client.send(command);
      console.log(`✅ [R2 Upload Success] File ${uniqueKey} uploaded to Cloudflare R2 bucket ${R2_CONFIG.bucketName}!`);
    } catch (err: any) {
      console.warn(`❌ [R2 Upload Error] S3 send failed: ${err.message}`);
    }
  } else {
    console.warn(`⚠️ [R2 Notice] R2_ACCESS_KEY_ID / R2_SECRET_ACCESS_KEY is not set in server/.env. File saved locally but not pushed to Cloudflare R2.`);
  }

  // 3. Construct public browser-accessible URL
  // If public URL base is a full URL (e.g. r2.dev or custom domain), use that; else use /api/images
  const isAbsolute = R2_CONFIG.publicUrlBase.startsWith('http');
  const url = isAbsolute
    ? `${R2_CONFIG.publicUrlBase.replace(/\/$/, '')}/${uniqueKey}`
    : `/api/images/${uniqueKey}`;

  return {
    url,
    key: uniqueKey,
    bucket: R2_CONFIG.bucketName,
  };
}

/**
 * Generates an S3 presigned URL for direct client upload to Cloudflare R2
 */
export async function getPresignedUploadUrl(
  fileName: string,
  contentType: string = 'image/jpeg',
  expiresInSeconds: number = 3600,
  folder?: unknown
): Promise<{ uploadUrl: string; publicUrl: string; key: string }> {
  const uniqueKey = createR2ObjectKey(fileName, folder);

  const command = new PutObjectCommand({
    Bucket: R2_CONFIG.bucketName,
    Key: uniqueKey,
    ContentType: contentType,
  });

  let uploadUrl = `${R2_CONFIG.endpoint}/${R2_CONFIG.bucketName}/${uniqueKey}`;
  if (R2_CONFIG.accessKeyId && R2_CONFIG.secretAccessKey) {
    try {
      uploadUrl = await getSignedUrl(r2S3Client, command, { expiresIn: expiresInSeconds });
    } catch (err: any) {
      console.warn(`[R2 Presign Warning] ${err.message}.`);
    }
  }

  const isAbsolute = R2_CONFIG.publicUrlBase.startsWith('http');
  const publicUrl = isAbsolute
    ? `${R2_CONFIG.publicUrlBase.replace(/\/$/, '')}/${uniqueKey}`
    : `/api/images/${uniqueKey}`;

  return {
    uploadUrl,
    publicUrl,
    key: uniqueKey,
  };
}

/**
 * Fetches object stream from Cloudflare R2
 */
export async function getR2ObjectStream(key: string) {
  const command = new GetObjectCommand({
    Bucket: R2_CONFIG.bucketName,
    Key: key,
  });
  return r2S3Client.send(command);
}

/**
 * Reads trusted object metadata directly from R2 before a caller persists a
 * reference supplied by a client.
 */
export async function getR2ObjectMetadata(key: string): Promise<{
  contentLength: number | null;
  contentType: string | null;
}> {
  const result = await r2S3Client.send(
    new HeadObjectCommand({
      Bucket: R2_CONFIG.bucketName,
      Key: key
    })
  );
  return {
    contentLength: result.ContentLength ?? null,
    contentType: result.ContentType?.toLowerCase() ?? null
  };
}
