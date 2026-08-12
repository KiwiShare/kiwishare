import { Context, Next } from 'koa';

export async function loggerMiddleware(ctx: Context, next: Next) {
  const start = Date.now();
  await next();
  const ms = Date.now() - start;
  console.log(`📝 [Koa Request] ${ctx.method} ${ctx.url} - Status: ${ctx.status} - Duration: ${ms}ms`);
}

export default loggerMiddleware;
