import { Hono } from 'hono';
import { formatResponse, generateId } from '../utils/helpers';
import { authenticate, requireRoles } from '../middleware/auth';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

// GET /api/bundles
router.get('/', async (c) => {
  const db = c.env.DB;
  const bundles = await db.prepare(
    `SELECT b.*, GROUP_CONCAT(bc.course_id) as course_ids
     FROM bundles b LEFT JOIN bundle_courses bc ON b.id = bc.bundle_id
     WHERE b.is_active = 1 GROUP BY b.id ORDER BY b.created_at DESC`
  ).all();
  return c.json(formatResponse(true, bundles.results));
});

// GET /api/bundles/:id
router.get('/:id', async (c) => {
  const db = c.env.DB;
  const { id } = c.req.param();

  const bundle = await db.prepare('SELECT * FROM bundles WHERE id = ?').bind(id).first() as any;
  if (!bundle) return c.json(formatResponse(false, null, 'Bundle not found'), 404);

  const courses = await db.prepare(
    `SELECT c.*, u.full_name as teacher_name
     FROM bundle_courses bc JOIN courses c ON bc.course_id = c.id
     JOIN teachers t ON c.teacher_id = t.id JOIN users u ON t.user_id = u.id
     WHERE bc.bundle_id = ?`
  ).bind(id).all();

  return c.json(formatResponse(true, { ...bundle, courses: courses.results }));
});

// POST /api/bundles
router.post('/', authenticate, requireRoles('super_admin', 'admin'), async (c) => {
  const db = c.env.DB;
  const body = await c.req.json();
  const { title, description, price, discount_percent, course_ids } = body;

  const id = generateId();
  await db.prepare(
    'INSERT INTO bundles (id, title, description, price, discount_percent) VALUES (?, ?, ?, ?, ?)'
  ).bind(id, title, description || null, price, discount_percent || 0).run();

  if (course_ids && Array.isArray(course_ids)) {
    for (const courseId of course_ids) {
      const bcId = generateId();
      await db.prepare('INSERT INTO bundle_courses (id, bundle_id, course_id) VALUES (?, ?, ?)')
        .bind(bcId, id, courseId).run();
    }
  }

  return c.json(formatResponse(true, { id }, 'Bundle created'), 201);
});

// POST /api/bundles/:id/purchase
router.post('/:id/purchase', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { id } = c.req.param();

  const bundle = await db.prepare('SELECT * FROM bundles WHERE id = ? AND is_active = 1').bind(id).first() as any;
  if (!bundle) return c.json(formatResponse(false, null, 'Bundle not found'), 404);

  const courses = await db.prepare('SELECT course_id FROM bundle_courses WHERE bundle_id = ?').bind(id).all() as any;
  if (courses.results.length === 0) return c.json(formatResponse(false, null, 'Bundle is empty'), 400);

  const u = await db.prepare('SELECT wallet_balance FROM users WHERE id = ?').bind(user.userId).first() as any;
  if (u.wallet_balance < bundle.price!) {
    return c.json(formatResponse(false, { balance: u.wallet_balance, required: bundle.price }, 'Insufficient balance'), 400);
  }

  const endDate = null;
  const subs: any[] = [];

  for (const { course_id } of courses.results) {
    const course = await db.prepare('SELECT price, duration_days FROM courses WHERE id = ?').bind(course_id).first() as any;
    const subId = generateId();
    const courseEndDate = course?.duration_days
      ? new Date(Date.now() + course.duration_days * 86400000).toISOString()
      : null;

    await db.prepare(
      "INSERT INTO subscriptions (id, user_id, course_id, amount, end_date, status) VALUES (?, ?, ?, ?, ?, 'active')"
    ).bind(subId, user.userId, course_id, 0, courseEndDate).run();

    await db.prepare('UPDATE courses SET total_students = total_students + 1 WHERE id = ?').bind(course_id).run();
    subs.push({ course_id, subscription_id: subId });
  }

  await db.prepare('UPDATE users SET wallet_balance = wallet_balance - ? WHERE id = ?')
    .bind(bundle.price!, user.userId).run();

  const txId = generateId();
  await db.prepare(
    "INSERT INTO transactions (id, user_id, type, amount, balance_before, balance_after, description, status) VALUES (?, ?, 'payment', ?, ?, ?, ?, 'completed')"
  ).bind(txId, user.userId, -bundle.price!, u.wallet_balance, u.wallet_balance - bundle.price!,
    `Bundle: ${bundle.title}`).run();

  return c.json(formatResponse(true, { subscriptions: subs, total: bundle.price }, 'Bundle purchased'));
});

export default router;
