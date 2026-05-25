import { Hono } from 'hono';
import { formatResponse, generateId } from '../utils/helpers';
import { authenticate } from '../middleware/auth';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

// GET /api/reviews/:courseId — course reviews
router.get('/:courseId', async (c) => {
  const db = c.env.DB;
  const { courseId } = c.req.param();

  const reviews = await db.prepare(
    `SELECT r.id, r.rating, r.comment, r.created_at,
            u.id as user_id, u.full_name, u.avatar_url
     FROM reviews r
     JOIN users u ON r.user_id = u.id
     WHERE r.course_id = ?
     ORDER BY r.created_at DESC`
  ).bind(courseId).all();

  return c.json(formatResponse(true, reviews.results));
});

// POST /api/reviews/:courseId — add review (must be subscribed)
router.post('/:courseId', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { courseId } = c.req.param();
  const { rating, comment } = await c.req.json();

  if (!rating || rating < 1 || rating > 5) {
    return c.json(formatResponse(false, null, 'Rating must be between 1 and 5'), 400);
  }

  // Check subscription
  const sub = await db.prepare(
    "SELECT id FROM subscriptions WHERE user_id = ? AND course_id = ? AND status = 'active'"
  ).bind(user.userId, courseId).first() as any;

  if (!sub) return c.json(formatResponse(false, null, 'You must be subscribed to review this course'), 403);

  // Check if already reviewed
  const existing = await db.prepare(
    'SELECT id FROM reviews WHERE user_id = ? AND course_id = ?'
  ).bind(user.userId, courseId).first();

  if (existing) return c.json(formatResponse(false, null, 'You already reviewed this course'), 409);

  const id = generateId();
  await db.prepare(
    'INSERT INTO reviews (id, user_id, course_id, subscription_id, rating, comment) VALUES (?, ?, ?, ?, ?, ?)'
  ).bind(id, user.userId, courseId, sub.id!, rating, comment || null).run();

  // Update course average rating
  const stats = await db.prepare(
    'SELECT AVG(rating) as avg, COUNT(*) as count FROM reviews WHERE course_id = ?'
  ).bind(courseId).first() as any;
  await db.prepare('UPDATE courses SET average_rating = ?, total_reviews = ? WHERE id = ?')
    .bind(stats.avg || 0, stats.count || 0, courseId).run();

  return c.json(formatResponse(true, { id }, 'Review added'), 201);
});

// DELETE /api/reviews/:id
router.delete('/:id', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { id } = c.req.param();

  const review = await db.prepare(
    'SELECT user_id, course_id FROM reviews WHERE id = ?'
  ).bind(id).first() as any;

  if (!review) return c.json(formatResponse(false, null, 'Review not found'), 404);
  if (review.user_id !== user.userId && user.role !== 'admin' && user.role !== 'super_admin') {
    return c.json(formatResponse(false, null, 'Forbidden'), 403);
  }

  await db.prepare('DELETE FROM reviews WHERE id = ?').bind(id).run();

  // Recalculate average
  const stats = await db.prepare(
    'SELECT AVG(rating) as avg, COUNT(*) as count FROM reviews WHERE course_id = ?'
  ).bind(review.course_id!).first() as any;
  await db.prepare('UPDATE courses SET average_rating = ?, total_reviews = ? WHERE id = ?')
    .bind(stats.avg || 0, stats.count || 0, review.course_id!).run();

  return c.json(formatResponse(true, null, 'Review deleted'));
});

export default router;
