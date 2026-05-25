import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { formatResponse } from './utils/helpers';

import authRoutes from './routes/auth';
import categoryRoutes from './routes/categories';
import teacherRoutes from './routes/teachers';
import courseRoutes from './routes/courses';
import cartRoutes from './routes/cart';
import walletRoutes from './routes/wallet';
import subscriptionRoutes from './routes/subscriptions';
import withdrawalRoutes from './routes/withdrawals';
import reviewRoutes from './routes/reviews';
import adminRoutes from './routes/admin';
import notificationRoutes from './routes/notifications';
import wishlistRoutes from './routes/wishlist';
import progressRoutes from './routes/progress';
import searchRoutes from './routes/search';
import bundleRoutes from './routes/bundles';
import flashSaleRoutes from './routes/flash_sales';
import gamificationRoutes from './routes/gamification';
import referralRoutes from './routes/referral';
import liveRoutes from './routes/live';
import announcementRoutes from './routes/announcements';
import couponRoutes from './routes/coupons';
import reportRoutes from './routes/reports';
import uploadRoutes from './routes/upload';
import webhookRoutes from './routes/webhook';
import { expireSubscriptions } from './cron/expire_subscriptions';
import { WalletDO } from './durable_objects/wallet_do';

export interface Env {
  DB: D1Database;
  ASSETS: R2Bucket;
  CACHE: KVNamespace;
  WALLET: DurableObjectNamespace;
  JWT_SECRET: string;
  REFRESH_SECRET: string;
  BUNNY_API_KEY: string;
  BUNNY_LIBRARY_ID: string;
  BUNNY_CDN_HOSTNAME: string;
}

const app = new Hono<{ Bindings: Env }>();

// Middleware
app.use('*', cors({
  origin: '*',
  allowHeaders: ['Content-Type', 'Authorization'],
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  exposeHeaders: ['Content-Length'],
  maxAge: 86400,
}));

// Health check
app.get('/api/health', (c) => {
  return c.json(formatResponse(true, { status: 'ok', timestamp: new Date().toISOString() }));
});

// Routes
app.route('/api/auth', authRoutes);
app.route('/api/categories', categoryRoutes);
app.route('/api/teachers', teacherRoutes);
app.route('/api/courses', courseRoutes);
app.route('/api/cart', cartRoutes);
app.route('/api/wallet', walletRoutes);
app.route('/api/subscriptions', subscriptionRoutes);
app.route('/api/withdrawals', withdrawalRoutes);
app.route('/api/reviews', reviewRoutes);
app.route('/api/admin', adminRoutes);
app.route('/api/notifications', notificationRoutes);
app.route('/api/wishlist', wishlistRoutes);
app.route('/api/progress', progressRoutes);
app.route('/api/search', searchRoutes);
app.route('/api/bundles', bundleRoutes);
app.route('/api/flash-sales', flashSaleRoutes);
app.route('/api/gamification', gamificationRoutes);
app.route('/api/referral', referralRoutes);
app.route('/api/live', liveRoutes);
app.route('/api/announcements', announcementRoutes);
app.route('/api/coupons', couponRoutes);
app.route('/api/reports', reportRoutes);
app.route('/api/upload', uploadRoutes);
app.route('/api/webhook', webhookRoutes);

// 404 catch-all
app.notFound((c) => {
  return c.json(formatResponse(false, null, 'Route not found'), 404);
});

// Error handler
app.onError((err, c) => {
  console.error('Error:', err);
  return c.json(formatResponse(false, null, 'Internal server error'), 500);
});

// Durable Object export
export { WalletDO };

// Worker entry point
export default {
  fetch: app.fetch,
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
    switch (event.cron) {
      case '0 0 * * *':
        ctx.waitUntil(expireSubscriptions(env));
        break;
    }
  },
};
