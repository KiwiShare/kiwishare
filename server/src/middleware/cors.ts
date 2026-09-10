import { Context, Next } from 'koa';

const whitelist = [
  'https://kiwishare.online',
  'https://www.kiwishare.online',
  'http://localhost:3000',
  'http://localhost:5173'
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

    if (isWhitelisted || isAllowedSuffix || process.env.NODE_ENV !== 'production') {
      ctx.set('Access-Control-Allow-Origin', origin);
    }
  } else {
    ctx.set('Access-Control-Allow-Origin', '*');
  }

  ctx.set('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  ctx.set('Access-Control-Allow-Methods', 'POST, GET, PUT, DELETE, OPTIONS');
  ctx.set('Access-Control-Allow-Credentials', 'true');

  if (ctx.method === 'OPTIONS') {
    ctx.status = 204;
    return;
  }

  await next();
}
export default corsMiddleware;
