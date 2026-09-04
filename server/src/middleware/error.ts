import { Context, Next } from 'koa';

export async function errorHandler(ctx: Context, next: Next) {
  try {
    await next();
  } catch (err: any) {
    // Log the error internally for developer auditing
    console.error(`[API Error Log] Path: ${ctx.path} | Error: ${err.message || err}`);

    // Shield client from sensitive internal stack traces (OWASP Mitigation)
    ctx.status = err.status || 500;
    ctx.body = {
      status: 'error',
      message: err.status && err.status < 500 
        ? err.message 
        : 'Internal Server Error. Please contact support if this persists.'
    };
  }
}
