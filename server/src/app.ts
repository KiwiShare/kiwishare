import Koa from 'koa';
import bodyParser from 'koa-bodyparser';
import { errorHandler } from './middleware/error';
import corsMiddleware from './middleware/cors';
import loggerMiddleware from './middleware/logger';
import apiRouter from './routes/api';

import Router from 'koa-router';

const app = new Koa();
const rootRouter = new Router();
const defaultBodyParser = bodyParser();
const listingSuggestionBodyParser = bodyParser({ jsonLimit: '12mb' });

// Hook in root endpoints
rootRouter.get('/', (ctx) => {
  ctx.status = 200;
  ctx.body = {
    status: 'success',
    message: 'KiwiShare API Server is running...',
    timestamp: new Date()
  };
});

rootRouter.get('/health', (ctx) => {
  ctx.status = 200;
  ctx.body = 'OK';
});

// Hook in logger, cors, body parser, and centralized error filter
app.use(loggerMiddleware);
app.use(corsMiddleware);
app.use(async (ctx, next) => {
  const parser =
    ctx.method === 'POST' && ctx.path === '/api/listing-suggestions'
      ? listingSuggestionBodyParser
      : defaultBodyParser;
  await parser(ctx, next);
});
app.use(errorHandler);

// Enable security headers to prevent tech-stack finger printing
app.use(async (ctx, next) => {
  ctx.remove('X-Powered-By');
  await next();
});

// Configure base API routes
app.use(rootRouter.routes());
app.use(rootRouter.allowedMethods());
app.use(apiRouter.routes());
app.use(apiRouter.allowedMethods());

export default app;
