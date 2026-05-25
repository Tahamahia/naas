import { Hono } from 'hono';
import { formatResponse, generateId } from '../utils/helpers';
import { authenticate, requireRoles } from '../middleware/auth';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

// POST /api/reports — student reports an issue
router.post('/', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { reported_user_id, reported_course_id, reason, description } = await c.req.json();

  const id = generateId();
  await db.prepare(
    'INSERT INTO reports (id, reporter_id, reported_user_id, reported_course_id, reason, description) VALUES (?, ?, ?, ?, ?, ?)'
  ).bind(id, user.userId, reported_user_id || null, reported_course_id || null, reason, description || null).run();

  return c.json(formatResponse(true, { id }, 'Report submitted'), 201);
});

// GET /api/reports (admin only)
router.get('/', authenticate, requireRoles('super_admin', 'admin'), async (c) => {
  const db = c.env.DB;
  const { status } = c.req.query();

  let query = `SELECT r.*, rep.email as reporter_email, rep.full_name as reporter_name
               FROM reports r JOIN users rep ON r.reporter_id = rep.id`;
  const params: any[] = [];

  if (status) { query += ' WHERE r.status = ?'; params.push(status); }
  query += ' ORDER BY r.created_at DESC';

  const reports = await db.prepare(query).bind(...params).all();
  return c.json(formatResponse(true, reports.results));
});

// POST /api/reports/:id/resolve (admin only)
router.post('/:id/resolve', authenticate, requireRoles('super_admin', 'admin'), async (c) => {
  const admin = c.get('user');
  const db = c.env.DB;
  const { id } = c.req.param();
  const { action } = await c.req.json();

  await db.prepare(
    'UPDATE reports SET status = ?, resolved_by = ?, resolved_at = datetime(\'now\') WHERE id = ?'
  ).bind(action === 'resolve' ? 'resolved' : 'dismissed', admin.userId, id).run();

  return c.json(formatResponse(true, null, 'Report updated'));
});

export default router;
