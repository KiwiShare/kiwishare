import { Context, Next } from 'koa';
import config from '../config';

const whitelist = [
  'https://kiwishare.online',
  'https://www.kiwishare.online',
  'http://localhost:3000',
  'http://localhost:5173',
  'http://127.0.0.1:3000',
  'http://127.0.0.1:5173',
];

const allowedSuffixes = [
  '.usercontent.goog',
  '.vercel.app',
  '.run.app'
];

export async function corsMiddleware(ctx: Context, next: Next) {
  const origin = ctx.headers.origin;

  if (origin) {
    const isWhitelisted = whitelist.includes(origin);
    const isAllowedSuffix = allowedSuffixes.some(suffix => origin.endsWith(suffix));
    const isLocalhost =
      origin.startsWith('http://localhost:') ||
      origin.startsWith('http://127.0.0.1:') ||
      origin.startsWith('https://localhost:') ||
      origin.startsWith('https://127.0.0.1:');

    if (isWhitelisted || isAllowedSuffix || isLocalhost || config.get('env') !== 'production') {
      ctx.set('Access-Control-Allow-Origin', origin);
      ctx.set('Access-Control-Allow-Credentials', 'true');
    } else {
      ctx.set('Access-Control-Allow-Origin', origin);
      ctx.set('Access-Control-Allow-Credentials', 'true');
    }
  } else {
    ctx.set('Access-Control-Allow-Origin', '*');
  }

  // Dynamically allow requested headers or use an exhaustive fallback
  const reqHeaders = ctx.get('Access-Control-Request-Headers');
  if (reqHeaders) {
    ctx.set('Access-Control-Allow-Headers', reqHeaders);
  } else {
    ctx.set(
      'Access-Control-Allow-Headers',
      'Origin, X-Requested-With, Content-Type, Accept, Authorization, x-user-id, x-client-platform, x-platform, x-request-id, x-correlation-id, x-client-id, x-device-id, x-api-version, *'
    );
  }

  ctx.set('Access-Control-Allow-Methods', 'GET, HEAD, PUT, POST, DELETE, PATCH, OPTIONS');
  ctx.set('Access-Control-Max-Age', '86400');

  if (ctx.method === 'OPTIONS') {
    ctx.status = 204;
    return;
  }

  await next();
}

export default corsMiddleware;
