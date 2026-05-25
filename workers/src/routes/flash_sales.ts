import { Hono } from 'hono';
import { formatResponse, generateId } from '../utils/helpers';
import { authenticate, requireRoles } from '../middleware/auth';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

// GET /api/flash-sales — active flash sales
router.get('/', async (c) => {
  const db = c.env.DB;
  const sales = await db.prepare(
    `SELECT fs.*, c.title, c.thumbnail_url, u.full_name as teacher_name
     FROM flash_sales fs JOIN courses c ON fs.course_id = c.id
     JOIN teachers t ON c.teacher_id = t.id JOIN users u ON t.user_id = u.id
     WHERE fs.is_active = 1 AND datetime('now') BETWEEN fs.starts_at AND fs.ends_at
     ORDER BY fs.ends_at ASC`
  ).all();
  return c.json(formatResponse(true, sales.results));
});

// POST /api/flash-sales — admin creates flash sale
router.post('/', authenticate, requireRoles('super_admin', 'admin'), async (c) => {
  const db = c.env.DB;
  const body = await c.req.json();
  const { course_id, sale_price, starts_at, ends_at } = body;

  const course = await db.prepare('SELECT id, price FROM courses WHERE id = ?').bind(course_id).first() as any;
  if (!course) return c.json(formatResponse(false, null, 'Course not found'), 404);

  const id = generateId();
  await db.prepare(
    'INSERT INTO flash_sales (id, course_id, original_price, sale_price, starts_at, ends_at) VALUES (?, ?, ?, ?, ?, ?)'
  ).bind(id, course_id, course.price!, sale_price, starts_at, ends_at).run();

  return c.json(formatResponse(true, { id }, 'Flash sale created'), 201);
});

export default router;
