import Router from 'koa-router';
import authRouter from './auth';
import usedItemsRouter from './usedItems';
import transactionsRouter from './transactions';
import usersRouter from './users';
import watchlistRouter from './watchlist';
import categoriesRouter from './categories';
import adminRouter from './admin';
import uploadRouter from './upload';
import chatRouter from './chat';
import notificationsRouter from './notifications';
import listingSuggestionsRouter from './listingSuggestions';
import meetupsRouter from './meetups';
import reportsRouter from './reports';

const router = new Router({ prefix: '/api' });
router.use(reportsRouter.routes());
router.use(reportsRouter.allowedMethods());

// Register modular sub-routers
router.use(authRouter.routes());
router.use(authRouter.allowedMethods());

router.use(usedItemsRouter.routes());
router.use(usedItemsRouter.allowedMethods());

router.use(usersRouter.routes());
router.use(usersRouter.allowedMethods());

router.use(transactionsRouter.routes());
router.use(transactionsRouter.allowedMethods());

router.use(watchlistRouter.routes());
router.use(watchlistRouter.allowedMethods());

router.use(categoriesRouter.routes());
router.use(categoriesRouter.allowedMethods());

router.use(adminRouter.routes());
router.use(adminRouter.allowedMethods());

router.use(uploadRouter.routes());
router.use(uploadRouter.allowedMethods());

router.use(chatRouter.routes());
router.use(chatRouter.allowedMethods());

router.use(notificationsRouter.routes());
router.use(notificationsRouter.allowedMethods());

router.use(listingSuggestionsRouter.routes());
router.use(listingSuggestionsRouter.allowedMethods());

router.use(meetupsRouter.routes());
router.use(meetupsRouter.allowedMethods());

export default router;
