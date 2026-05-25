import { Hono } from 'hono';
import { formatResponse, generateId } from '../utils/helpers';
import { authenticate } from '../middleware/auth';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

// GET /api/notifications
router.get('/', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;

  const notifs = await db.prepare(
    'SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 50'
  ).bind(user.userId).all();

  const unread = await db.prepare(
    'SELECT COUNT(*) as count FROM notifications WHERE user_id = ? AND is_read = 0'
  ).bind(user.userId).first() as any;

  return c.json(formatResponse(true, {
    notifications: notifs.results,
    unread_count: unread?.count || 0,
  }));
});

// PUT /api/notifications/read-all — mark all as read
router.put('/read-all', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;

  await db.prepare('UPDATE notifications SET is_read = 1 WHERE user_id = ?').bind(user.userId).run();
  return c.json(formatResponse(true, null, 'All notifications marked as read'));
});

// PUT /api/notifications/:id/read
router.put('/:id/read', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { id } = c.req.param();

  await db.prepare('UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?').bind(id, user.userId).run();
  return c.json(formatResponse(true, null, 'Notification marked as read'));
});

export default router;
