import Router from 'koa-router';
import authRouter from './auth';
import listingsRouter from './listings';
import transactionsRouter from './transactions';

const router = new Router({ prefix: '/api' });

// Register modular sub-routers
router.use(authRouter.routes());
router.use(authRouter.allowedMethods());

router.use(listingsRouter.routes());
router.use(listingsRouter.allowedMethods());

router.use(transactionsRouter.routes());
router.use(transactionsRouter.allowedMethods());

export default router;
