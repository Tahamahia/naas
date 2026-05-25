import { Hono } from 'hono';
import { formatResponse, generateId } from '../utils/helpers';
import { authenticate, requireRoles } from '../middleware/auth';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

// POST /api/announcements — teacher sends announcement
router.post('/', authenticate, requireRoles('teacher'), async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { course_id, title, body } = await c.req.json();

  const teacher = await db.prepare('SELECT id FROM teachers WHERE user_id = ?').bind(user.userId).first() as any;
  if (!teacher) return c.json(formatResponse(false, null, 'Teacher profile not found'), 404);

  const course = await db.prepare('SELECT id FROM courses WHERE id = ? AND teacher_id = ?')
    .bind(course_id, teacher.id!).first();
  if (!course) return c.json(formatResponse(false, null, 'Course not found or not yours'), 404);

  const id = generateId();
  await db.prepare(
    'INSERT INTO announcements (id, course_id, teacher_id, title, body) VALUES (?, ?, ?, ?, ?)'
  ).bind(id, course_id, teacher.id!, title, body).run();

  // Notify all subscribers
  const subscribers = await db.prepare(
    "SELECT user_id FROM subscriptions WHERE course_id = ? AND status = 'active'"
  ).bind(course_id).all() as any;

  for (const sub of subscribers.results) {
    const notifId = generateId();
    await db.prepare(
      "INSERT INTO notifications (id, user_id, title, body, type, reference_id) VALUES (?, ?, ?, ?, 'announcement', ?)"
    ).bind(notifId, sub.user_id!, title, body, course_id).run();
  }

  return c.json(formatResponse(true, { id }, 'Announcement sent'), 201);
});

// GET /api/announcements/:courseId — get course announcements
router.get('/:courseId', authenticate, async (c) => {
  const db = c.env.DB;
  const { courseId } = c.req.param();
  const announcements = await db.prepare(
    `SELECT a.*, u.full_name as teacher_name FROM announcements a
     JOIN teachers t ON a.teacher_id = t.id
     JOIN users u ON t.user_id = u.id
     WHERE a.course_id = ? ORDER BY a.created_at DESC`
  ).bind(courseId).all();
  return c.json(formatResponse(true, announcements.results));
});

export default router;
