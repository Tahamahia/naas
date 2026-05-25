import { Hono } from 'hono';
import { formatResponse, generateId } from '../utils/helpers';
import { authenticate, requireRoles } from '../middleware/auth';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

// GET /api/live/upcoming — upcoming live sessions
router.get('/upcoming', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;

  let query = `SELECT ls.*, c.title as course_title, u.full_name as teacher_name
    FROM live_sessions ls
    JOIN courses c ON ls.course_id = c.id
    JOIN teachers t ON ls.teacher_id = t.id
    JOIN users u ON t.user_id = u.id
    WHERE ls.status = 'scheduled' AND ls.scheduled_at > datetime('now')`;

  if (user.role === 'teacher') {
    const teacher = await db.prepare('SELECT id FROM teachers WHERE user_id = ?').bind(user.userId).first() as any;
    if (teacher) query += ` AND ls.teacher_id = '${teacher.id}'`;
  } else if (user.role === 'student') {
    query += ` AND ls.course_id IN (SELECT course_id FROM subscriptions WHERE user_id = ? AND status = 'active')`;
  }

  query += ' ORDER BY ls.scheduled_at ASC';
  const results = user.role === 'student'
    ? await db.prepare(query).bind(user.userId).all()
    : await db.prepare(query).all();

  return c.json(formatResponse(true, results.results));
});

// POST /api/live — teacher creates live session
router.post('/', authenticate, requireRoles('teacher', 'admin', 'super_admin'), async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { course_id, title, description, scheduled_at, duration_minutes } = await c.req.json();

  const teacher = await db.prepare('SELECT id FROM teachers WHERE user_id = ?').bind(user.userId).first() as any;
  if (!teacher && user.role === 'teacher') return c.json(formatResponse(false, null, 'Teacher profile not found'), 404);

  const id = generateId();
  const teacherId = teacher?.id || user.userId;
  await db.prepare(
    'INSERT INTO live_sessions (id, course_id, teacher_id, title, description, scheduled_at, duration_minutes) VALUES (?, ?, ?, ?, ?, ?, ?)'
  ).bind(id, course_id, teacherId, title, description || null, scheduled_at, duration_minutes || null).run();

  // Notify all subscribers
  const subscribers = await db.prepare(
    "SELECT user_id FROM subscriptions WHERE course_id = ? AND status = 'active'"
  ).bind(course_id).all() as any;

  for (const sub of subscribers.results) {
    const notifId = generateId();
    await db.prepare(
      "INSERT INTO notifications (id, user_id, title, body, type, reference_id) VALUES (?, ?, ?, ?, 'announcement', ?)"
    ).bind(notifId, sub.user_id!, `جلسة مباشرة: ${title}`, `موعد الجلسة: ${scheduled_at}`, course_id).run();
  }

  return c.json(formatResponse(true, { id }, 'Live session created'), 201);
});

// POST /api/live/:id/start — start live session
router.post('/:id/start', authenticate, requireRoles('teacher'), async (c) => {
  const db = c.env.DB;
  const { id } = c.req.param();
  await db.prepare("UPDATE live_sessions SET status = 'live' WHERE id = ?").bind(id).run();
  return c.json(formatResponse(true, null, 'Live session started'));
});

// POST /api/live/:id/end — end live session
router.post('/:id/end', authenticate, requireRoles('teacher'), async (c) => {
  const db = c.env.DB;
  const { id } = c.req.param();
  const { recording_url } = await c.req.json();
  await db.prepare(
    "UPDATE live_sessions SET status = 'ended', recording_url = ? WHERE id = ?"
  ).bind(recording_url || null, id).run();
  return c.json(formatResponse(true, null, 'Live session ended'));
});

export default router;
