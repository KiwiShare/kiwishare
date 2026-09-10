import { Context, Next } from 'koa';

export function resolveClientPlatform(ctx: Context): 'web' | 'mobile_ios' | 'mobile_android' | 'mobile' | 'unknown' {
  const headerPlatform = (ctx.get('x-client-platform') || '').toLowerCase().trim();
  if (['web', 'mobile_ios', 'mobile_android', 'mobile'].includes(headerPlatform)) {
    return headerPlatform as any;
  }

  const userAgent = (ctx.get('user-agent') || '').toLowerCase();
  if (userAgent.includes('dart') || userAgent.includes('flutter')) {
    if (userAgent.includes('iphone') || userAgent.includes('ios') || userAgent.includes('darwin')) {
      return 'mobile_ios';
    }
    if (userAgent.includes('android')) {
      return 'mobile_android';
    }
    return 'mobile';
  }

  if (userAgent.includes('mozilla') || userAgent.includes('chrome') || userAgent.includes('safari')) {
    return 'web';
  }

  return 'unknown';
}

export async function loggerMiddleware(ctx: Context, next: Next) {
  const start = Date.now();
  const platform = resolveClientPlatform(ctx);
  ctx.state.clientPlatform = platform;

  await next();
  const ms = Date.now() - start;
  console.log(`📝 [Koa Request][platform: ${platform}] ${ctx.method} ${ctx.url} - Status: ${ctx.status} - Duration: ${ms}ms`);
}

export default loggerMiddleware;

