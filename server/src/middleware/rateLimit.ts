import { Context, Next } from 'koa';

interface RateLimitRecord {
  count: number;
  resetTime: number;
}

const rateLimitStore = new Map<string, RateLimitRecord>();

export function rateLimit(limit: number, windowMs: number) {
  return async (ctx: Context, next: Next) => {
    // Disable rate limiting in test environment to avoid test flakiness
    if (process.env.NODE_ENV === 'test') {
      return await next();
    }

    const ip = ctx.ip || (ctx.headers['x-forwarded-for'] as string) || 'unknown';
    const now = Date.now();
    const record = rateLimitStore.get(ip);

    if (!record || now > record.resetTime) {
      rateLimitStore.set(ip, {
        count: 1,
        resetTime: now + windowMs
      });
    } else {
      record.count++;
      if (record.count > limit) {
        ctx.status = 429;
        ctx.body = {
          status: 'error',
          message: 'Too many requests. Please try again later.'
        };
        ctx.set('Retry-After', Math.ceil((record.resetTime - now) / 1000).toString());
        return;
      }
    }

    await next();
  };
}
