import { Hono } from 'hono';
import { formatResponse, generateId } from '../utils/helpers';
import { authenticate } from '../middleware/auth';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

// PUT /api/progress/:lessonId — update watch progress
router.put('/:lessonId', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { lessonId } = c.req.param();
  const { progress_seconds, total_seconds, completed } = await c.req.json();

  const lesson = await db.prepare(
    'SELECT l.id, s.course_id FROM lessons l JOIN sections s ON l.section_id = s.id WHERE l.id = ?'
  ).bind(lessonId).first() as any;
  if (!lesson) return c.json(formatResponse(false, null, 'Lesson not found'), 404);

  // Check subscription
  const sub = await db.prepare(
    "SELECT id FROM subscriptions WHERE user_id = ? AND course_id = ? AND status = 'active'"
  ).bind(user.userId, lesson.course_id!).first();
  if (!sub) return c.json(formatResponse(false, null, 'Not subscribed'), 403);

  const existing = await db.prepare(
    'SELECT id FROM watch_history WHERE user_id = ? AND lesson_id = ?'
  ).bind(user.userId, lessonId).first();

  if (existing) {
    await db.prepare(
      `UPDATE watch_history SET progress_seconds = COALESCE(?, progress_seconds),
       total_seconds = COALESCE(?, total_seconds), completed = COALESCE(?, completed),
       last_watched = datetime('now') WHERE user_id = ? AND lesson_id = ?`
    ).bind(progress_seconds ?? null, total_seconds ?? null, completed ?? null, user.userId, lessonId).run();
  } else {
    const id = generateId();
    await db.prepare(
      'INSERT INTO watch_history (id, user_id, lesson_id, progress_seconds, total_seconds, completed) VALUES (?, ?, ?, ?, ?, ?)'
    ).bind(id, user.userId, lessonId, progress_seconds || 0, total_seconds || 0, completed ? 1 : 0).run();
  }

  // Update course progress
  const completedLessons = await db.prepare(
    'SELECT COUNT(*) as count FROM watch_history WHERE user_id = ? AND completed = 1 AND lesson_id IN (SELECT l.id FROM lessons l JOIN sections s ON l.section_id = s.id WHERE s.course_id = ?)'
  ).bind(user.userId, lesson.course_id!).first() as any;

  const totalLessons = await db.prepare(
    'SELECT COUNT(*) as count FROM lessons l JOIN sections s ON l.section_id = s.id WHERE s.course_id = ?'
  ).bind(lesson.course_id!).first() as any;

  const total = totalLessons?.count || 1;
  const done = completedLessons?.count || 0;
  const percent = Math.round((done / total) * 100);

  const existingProgress = await db.prepare(
    'SELECT id FROM course_progress WHERE user_id = ? AND course_id = ?'
  ).bind(user.userId, lesson.course_id!).first();

  if (existingProgress) {
    await db.prepare(
      'UPDATE course_progress SET completed_lessons = ?, total_lessons = ?, progress_percent = ?, last_activity = datetime(\'now\') WHERE user_id = ? AND course_id = ?'
    ).bind(done, total, percent, user.userId, lesson.course_id!).run();
  } else {
    const pid = generateId();
    await db.prepare(
      'INSERT INTO course_progress (id, user_id, course_id, completed_lessons, total_lessons, progress_percent) VALUES (?, ?, ?, ?, ?, ?)'
    ).bind(pid, user.userId, lesson.course_id!, done, total, percent).run();
  }

  return c.json(formatResponse(true, { completed: done, total, percent }));
});

// GET /api/progress/course/:courseId — course progress
router.get('/course/:courseId', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { courseId } = c.req.param();

  let progress = await db.prepare(
    'SELECT * FROM course_progress WHERE user_id = ? AND course_id = ?'
  ).bind(user.userId, courseId).first();

  if (!progress) {
    const total = await db.prepare(
      'SELECT COUNT(*) as count FROM lessons l JOIN sections s ON l.section_id = s.id WHERE s.course_id = ?'
    ).bind(courseId).first() as any;
    progress = { completed_lessons: 0, total_lessons: total?.count || 0, progress_percent: 0 };
  }

  const watched = await db.prepare(
    'SELECT lesson_id, completed, progress_seconds FROM watch_history WHERE user_id = ? AND lesson_id IN (SELECT l.id FROM lessons l JOIN sections s ON l.section_id = s.id WHERE s.course_id = ?)'
  ).bind(user.userId, courseId).all();

  return c.json(formatResponse(true, { ...progress as any, details: watched.results }));
});

export default router;
