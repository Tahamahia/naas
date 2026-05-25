import { Hono } from 'hono';
import { formatResponse, generateId } from '../utils/helpers';
import { authenticate } from '../middleware/auth';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

// GET /api/wishlist
router.get('/', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;

  const items = await db.prepare(
    `SELECT w.id, w.added_at, c.id as course_id, c.title, c.price, c.thumbnail_url,
            c.average_rating, c.total_students, u.full_name as teacher_name
     FROM wishlist_items w
     JOIN courses c ON w.course_id = c.id
     JOIN teachers t ON c.teacher_id = t.id
     JOIN users u ON t.user_id = u.id
     WHERE w.user_id = ? AND c.status = 'published'
     ORDER BY w.added_at DESC`
  ).bind(user.userId).all();

  return c.json(formatResponse(true, items.results));
});

// POST /api/wishlist/add
router.post('/add', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { course_id } = await c.req.json();

  const existing = await db.prepare(
    'SELECT id FROM wishlist_items WHERE user_id = ? AND course_id = ?'
  ).bind(user.userId, course_id).first();
  if (existing) return c.json(formatResponse(false, null, 'Already in wishlist'), 409);

  const id = generateId();
  await db.prepare('INSERT INTO wishlist_items (id, user_id, course_id) VALUES (?, ?, ?)')
    .bind(id, user.userId, course_id).run();

  return c.json(formatResponse(true, { id }, 'Added to wishlist'), 201);
});

// DELETE /api/wishlist/:courseId
router.delete('/:courseId', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { courseId } = c.req.param();

  await db.prepare('DELETE FROM wishlist_items WHERE user_id = ? AND course_id = ?')
    .bind(user.userId, courseId).run();

  return c.json(formatResponse(true, null, 'Removed from wishlist'));
});

export default router;
