import Koa from 'koa';
import bodyParser from 'koa-bodyparser';
import { errorHandler } from './middleware/error';
import apiRouter from './routes/api';

const app = new Koa();

// Hook in body parser and centralized error/stack trace filter
app.use(bodyParser());
app.use(errorHandler);

// Enable security headers to prevent tech-stack finger printing
app.use(async (ctx, next) => {
  ctx.remove('X-Powered-By');
  await next();
});

// Configure base API routes
app.use(apiRouter.routes());
app.use(apiRouter.allowedMethods());

export default app;
