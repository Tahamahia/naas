import { Hono } from 'hono';
import { formatResponse } from '../utils/helpers';
import { authenticate } from '../middleware/auth';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

// GET /api/subscriptions/my — student's subscriptions
router.get('/my', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;

  const { status } = c.req.query();
  let query = `SELECT s.id, s.course_id, s.amount, s.start_date, s.end_date, s.status, s.created_at,
               c.title, c.thumbnail_url, c.total_lessons, c.duration_days,
               u.full_name as teacher_name,
               COALESCE(cp.progress_percent, 0) as progress_percent,
               s.is_free
               FROM subscriptions s
               JOIN courses c ON s.course_id = c.id
               JOIN teachers t ON c.teacher_id = t.id
               JOIN users u ON t.user_id = u.id
               LEFT JOIN course_progress cp ON cp.user_id = s.user_id AND cp.course_id = s.course_id
               WHERE s.user_id = ?`;
  const params: any[] = [user.userId];

  if (status) {
    query += ' AND s.status = ?';
    params.push(status);
  }

  query += ' ORDER BY s.created_at DESC';

  const subs = await db.prepare(query).bind(...params).all();
  return c.json(formatResponse(true, subs.results));
});

// GET /api/subscriptions/teacher/students — teacher's students
router.get('/teacher/students', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;

  const teacher = await db.prepare('SELECT id FROM teachers WHERE user_id = ?').bind(user.userId).first() as any;
  if (!teacher) return c.json(formatResponse(false, null, 'Teacher profile not found'), 404);

  const students = await db.prepare(
    `SELECT DISTINCT u.id, u.full_name, u.email, u.avatar_url, s.course_id, c.title as course_title,
            s.status, s.start_date, s.end_date
     FROM subscriptions s
     JOIN users u ON s.user_id = u.id
     JOIN courses c ON s.course_id = c.id
     WHERE c.teacher_id = ?
     ORDER BY s.created_at DESC`
  ).bind(teacher.id!).all();

  return c.json(formatResponse(true, students.results));
});

// GET /api/subscriptions/:id — subscription detail
router.get('/:id', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { id } = c.req.param();

  const sub = await db.prepare(
    `SELECT s.*, c.title, c.description, c.thumbnail_url, c.total_lessons, c.duration_days
     FROM subscriptions s JOIN courses c ON s.course_id = c.id
     WHERE s.id = ? AND s.user_id = ?`
  ).bind(id, user.userId).first();

  if (!sub) return c.json(formatResponse(false, null, 'Subscription not found'), 404);

  // Check expiry
  const s = sub as any;
  if (s.end_date && s.status === 'active') {
    const endDate = new Date(s.end_date + 'Z');
    if (new Date() > endDate) {
      await db.prepare("UPDATE subscriptions SET status = 'expired' WHERE id = ?").bind(id).run();
      s.status = 'expired';
    }
  }

  return c.json(formatResponse(true, sub));
});

// POST /api/subscriptions/:id/renew — renew expired subscription
router.post('/:id/renew', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { id } = c.req.param();

  const sub = await db.prepare(
    'SELECT s.*, c.price, c.duration_days FROM subscriptions s JOIN courses c ON s.course_id = c.id WHERE s.id = ? AND s.user_id = ?'
  ).bind(id, user.userId).first() as any;

  if (!sub) return c.json(formatResponse(false, null, 'Subscription not found'), 404);
  if (sub.is_free) return c.json(formatResponse(false, null, 'Free courses cannot expire'), 400);

  const price = sub.price; // Use original price or current? Let's use current course price
  const u = await db.prepare('SELECT wallet_balance FROM users WHERE id = ?').bind(user.userId).first() as any;

  if (u.wallet_balance < price) {
    return c.json(formatResponse(false, null, 'Insufficient balance'), 400);
  }

  const endDate = sub.duration_days
    ? new Date(Date.now() + sub.duration_days * 86400000).toISOString()
    : null;

  await db.prepare(
    "UPDATE subscriptions SET status = 'active', start_date = datetime('now'), end_date = ?, amount = ? WHERE id = ?"
  ).bind(endDate, price, id).run();

  await db.prepare('UPDATE users SET wallet_balance = wallet_balance - ? WHERE id = ?')
    .bind(price, user.userId).run();

  return c.json(formatResponse(true, null, 'Subscription renewed'));
});

export default router;
