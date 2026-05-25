import { Hono } from 'hono';
import { formatResponse, generateId } from '../utils/helpers';
import { authenticate, requireRoles } from '../middleware/auth';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

// GET /api/categories
router.get('/', async (c) => {
  const db = c.env.DB;
  const categories = await db.prepare(
    'SELECT * FROM categories ORDER BY sort_order ASC'
  ).all();

  return c.json(formatResponse(true, categories.results));
});

// POST /api/categories (admin only)
router.post('/', authenticate, requireRoles('super_admin', 'admin'), async (c) => {
  const db = c.env.DB;
  const body = await c.req.json();
  const { name, icon, color, parent_id, sort_order } = body;

  const id = generateId();
  await db.prepare(
    'INSERT INTO categories (id, name, icon, color, parent_id, sort_order) VALUES (?, ?, ?, ?, ?, ?)'
  ).bind(id, name, icon || null, color || null, parent_id || null, sort_order || 0).run();

  return c.json(formatResponse(true, { id }, 'Category created'), 201);
});

// PUT /api/categories/:id
router.put('/:id', authenticate, requireRoles('super_admin', 'admin'), async (c) => {
  const db = c.env.DB;
  const { id } = c.req.param();
  const body = await c.req.json();
  const { name, icon, color, parent_id, sort_order } = body;

  await db.prepare(
    `UPDATE categories SET name = COALESCE(?, name), icon = COALESCE(?, icon),
     color = COALESCE(?, color), parent_id = ?, sort_order = COALESCE(?, sort_order)
     WHERE id = ?`
  ).bind(name || null, icon || null, color || null, parent_id || null, sort_order || null, id).run();

  return c.json(formatResponse(true, null, 'Category updated'));
});

// DELETE /api/categories/:id
router.delete('/:id', authenticate, requireRoles('super_admin', 'admin'), async (c) => {
  const db = c.env.DB;
  const { id } = c.req.param();

  await db.prepare('DELETE FROM categories WHERE id = ?').bind(id).run();
  return c.json(formatResponse(true, null, 'Category deleted'));
});

export default router;
