import 'dotenv/config';
import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';

// Local storage directory for zero-downtime serving & dev fallback
const UPLOAD_DIR = path.join(__dirname, '../../public/uploads/images');
if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

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

/**
 * Uploads a file buffer to Cloudflare R2 bucket `kiwishare` with local caching
 */
export async function uploadToR2(
  fileBuffer: Buffer,
  fileName: string,
  contentType: string = 'image/jpeg'
): Promise<{ url: string; key: string; bucket: string }> {
  const ext = fileName.split('.').pop() || 'jpg';
  const fileBasename = `${Date.now()}_${crypto.randomBytes(6).toString('hex')}.${ext}`;
  const uniqueKey = `images/${fileBasename}`;

  // 1. Save local copy for direct high-speed serving
  try {
    const localFilePath = path.join(UPLOAD_DIR, fileBasename);
    await fs.promises.writeFile(localFilePath, fileBuffer);
  } catch (err: any) {
    console.warn(`[Local Cache Warning] ${err.message}`);
  }

  // 2. Upload to Cloudflare R2 S3 bucket if credentials configured
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
    : `/api/images/${fileBasename}`;

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
  expiresInSeconds: number = 3600
): Promise<{ uploadUrl: string; publicUrl: string; key: string }> {
  const ext = fileName.split('.').pop() || 'jpg';
  const fileBasename = `${Date.now()}_${crypto.randomBytes(6).toString('hex')}.${ext}`;
  const uniqueKey = `images/${fileBasename}`;

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
    : `/api/images/${fileBasename}`;

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
