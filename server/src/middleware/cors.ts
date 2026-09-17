import { Context, Next } from 'koa';

const whitelist = [
  'https://kiwishare.online',
  'https://www.kiwishare.online',
  'http://kiwishare.online',
  'http://www.kiwishare.online',
  'http://localhost:3000',
  'http://localhost:5173',
  'http://localhost:5174',
  'http://localhost:4173',
  'http://127.0.0.1:3000',
  'http://127.0.0.1:5173',
  'http://127.0.0.1:5174'
];

const allowedSuffixes = [
  '.kiwishare.online',
  'kiwishare.online',
  '.usercontent.goog',
  '.vercel.app',
  '.run.app'
];

export async function corsMiddleware(ctx: Context, next: Next) {
  const origin = ctx.headers.origin;

  if (origin) {
    const isWhitelisted = whitelist.includes(origin);
    const isAllowedSuffix = allowedSuffixes.some(suffix => {
      try {
        const url = new URL(origin);
        return url.hostname.endsWith(suffix) || url.hostname === suffix;
      } catch {
        return origin.endsWith(suffix);
      }
    });

    if (isWhitelisted || isAllowedSuffix || process.env.NODE_ENV !== 'production') {
      ctx.set('Access-Control-Allow-Origin', origin);
    }
  } else {
    ctx.set('Access-Control-Allow-Origin', '*');
  }

  const reqHeaders = ctx.get('Access-Control-Request-Headers');
  if (reqHeaders) {
    ctx.set('Access-Control-Allow-Headers', reqHeaders);
  } else {
    ctx.set('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization, x-client-platform');
  }
  ctx.set('Access-Control-Allow-Methods', 'GET, HEAD, POST, PUT, PATCH, DELETE, OPTIONS');
  ctx.set('Access-Control-Allow-Credentials', 'true');

  if (ctx.method === 'OPTIONS') {
    ctx.status = 204;
    return;
  }

  await next();
}
export default corsMiddleware;
