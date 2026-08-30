import { Context, Next } from 'koa';
import jwt from 'jsonwebtoken';

const MINIMUM_JWT_SECRET_LENGTH = 32;
export const EXPIRED_TOKEN_CLEANUP_GRACE_SECONDS = 5 * 60;
const INSECURE_JWT_SECRETS = new Set([
  'kiwishare_super_secret_key_123_abc'
]);

export function getJwtSecret(): string {
  const secret = process.env.JWT_SECRET?.trim();
  if (
    !secret ||
    secret.length < MINIMUM_JWT_SECRET_LENGTH ||
    INSECURE_JWT_SECRETS.has(secret)
  ) {
    throw new Error(
      `JWT_SECRET must be set to a non-placeholder secret of at least ${MINIMUM_JWT_SECRET_LENGTH} characters.`
    );
  }
  return secret;
}

export interface DecodedToken {
  id: string;
  email: string;
  exp?: number;
  iat?: number;
}

export async function authenticateToken(ctx: Context, next: Next) {
  const authHeader = ctx.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    ctx.status = 401;
    ctx.body = { status: 'error', message: 'Access denied. Missing authorization token.' };
    return;
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, getJwtSecret()) as DecodedToken;
    ctx.state.user = decoded; // Store identity in Koa state context
  } catch (err) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Invalid or expired authorization token.' };
    return;
  }

  await next();
}

export async function authenticateTokenAllowExpired(ctx: Context, next: Next) {
  const authHeader = ctx.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    ctx.status = 401;
    ctx.body = { status: 'error', message: 'Access denied. Missing authorization token.' };
    return;
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, getJwtSecret(), { ignoreExpiration: true }) as DecodedToken;
    const nowSeconds = Math.floor(Date.now() / 1000);
    if (
      typeof decoded.exp !== 'number' ||
      decoded.exp + EXPIRED_TOKEN_CLEANUP_GRACE_SECONDS < nowSeconds
    ) {
      ctx.status = 403;
      ctx.body = {
        status: 'error',
        message: 'Invalid or expired authorization token.'
      };
      return;
    }
    ctx.state.user = decoded;
  } catch (err) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Invalid authorization token.' };
    return;
  }

  await next();
}
