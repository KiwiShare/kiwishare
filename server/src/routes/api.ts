import Router from 'koa-router';
import authRouter from './auth';
import usedItemsRouter from './usedItems';
import transactionsRouter from './transactions';
import usersRouter from './users';

const router = new Router({ prefix: '/api' });

// Register modular sub-routers
router.use(authRouter.routes());
router.use(authRouter.allowedMethods());

router.use(usedItemsRouter.routes());
router.use(usedItemsRouter.allowedMethods());

router.use(usersRouter.routes());
router.use(usersRouter.allowedMethods());

router.use(transactionsRouter.routes());
router.use(transactionsRouter.allowedMethods());

export default router;
