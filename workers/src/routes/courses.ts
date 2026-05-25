import { Hono } from 'hono';
import { z } from 'zod';
import { formatResponse, generateId } from '../utils/helpers';
import { authenticate, requireRoles } from '../middleware/auth';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

const courseSchema = z.object({
  title: z.string().min(3).max(200),
  subtitle: z.string().max(500).optional(),
  description: z.string().max(5000).optional(),
  price: z.number().min(0),
  duration_days: z.number().int().positive().optional(),
  category_id: z.string().optional(),
  thumbnail_url: z.string().optional(),
  intro_video_url: z.string().optional(),
  language: z.string().optional(),
  level: z.enum(['beginner', 'intermediate', 'advanced', 'all']).optional(),
  has_certificate: z.boolean().optional(),
  drip_type: z.enum(['none', 'days', 'schedule']).optional(),
  drip_delay_days: z.number().int().positive().optional(),
});

// GET /api/courses — browse published courses (with filters)
router.get('/', async (c) => {
  const db = c.env.DB;
  const { category, level, search, min_price, max_price, sort, page = '1', limit = '20' } = c.req.query();

  let query = `SELECT c.*, u.full_name as teacher_name, t.photo_url as teacher_photo
               FROM courses c
               JOIN teachers t ON c.teacher_id = t.id
               JOIN users u ON t.user_id = u.id
               WHERE c.status = 'published'`;
  const params: any[] = [];

  if (category) { query += ' AND c.category_id = ?'; params.push(category); }
  if (level) { query += ' AND c.level = ?'; params.push(level); }
  if (search) { query += ' AND (c.title LIKE ? OR c.description LIKE ?)'; params.push(`%${search}%`, `%${search}%`); }
  if (min_price) { query += ' AND c.price >= ?'; params.push(Number(min_price)); }
  if (max_price) { query += ' AND c.price <= ?'; params.push(Number(max_price)); }

  if (sort === 'price_asc') query += ' ORDER BY c.price ASC';
  else if (sort === 'price_desc') query += ' ORDER BY c.price DESC';
  else if (sort === 'rating') query += ' ORDER BY c.average_rating DESC';
  else if (sort === 'students') query += ' ORDER BY c.total_students DESC';
  else query += ' ORDER BY c.created_at DESC';

  const offset = (Number(page) - 1) * Number(limit);
  query += ' LIMIT ? OFFSET ?';
  params.push(Number(limit), offset);

  const courses = await db.prepare(query).bind(...params).all();
  return c.json(formatResponse(true, courses.results));
});

// GET /api/courses/teacher/mine — teacher's own courses
router.get('/teacher/mine', authenticate, requireRoles('teacher'), async (c) => {
  const user = c.get('user');
  const db = c.env.DB;

  const teacher = await db.prepare('SELECT id FROM teachers WHERE user_id = ?').bind(user.userId).first() as any;
  if (!teacher) return c.json(formatResponse(false, null, 'Teacher profile not found'), 404);

  const courses = await db.prepare(
    `SELECT * FROM courses WHERE teacher_id = ? ORDER BY updated_at DESC`
  ).bind(teacher.id!).all();

  return c.json(formatResponse(true, courses.results));
});

// GET /api/courses/:id — course details
router.get('/:id', async (c) => {
  const db = c.env.DB;
  const { id } = c.req.param();

  const course = await db.prepare(
    `SELECT c.*, u.full_name as teacher_name, t.photo_url as teacher_photo, cat.name as category_name
     FROM courses c
     JOIN teachers t ON c.teacher_id = t.id
     JOIN users u ON t.user_id = u.id
     LEFT JOIN categories cat ON c.category_id = cat.id
     WHERE c.id = ?`
  ).bind(id).first() as any;

  if (!course) return c.json(formatResponse(false, null, 'Course not found'), 404);

  const sections = await db.prepare(
    'SELECT * FROM sections WHERE course_id = ? ORDER BY sort_order ASC'
  ).bind(id).all();

  const sectionIds = (sections.results as any[]).map(s => s.id);
  let lessons: any[] = [];
  if (sectionIds.length > 0) {
    const placeholders = sectionIds.map(() => '?').join(',');
    lessons = (await db.prepare(
      `SELECT * FROM lessons WHERE section_id IN (${placeholders}) ORDER BY sort_order ASC`
    ).bind(...sectionIds).all()).results;
  }

  const lessonsBySection: any = {};
  for (const lesson of lessons) {
    if (!lessonsBySection[lesson.section_id]) lessonsBySection[lesson.section_id] = [];
    lessonsBySection[lesson.section_id].push(lesson);
  }

  return c.json(formatResponse(true, {
    ...course,
    sections: (sections.results as any[]).map(s => ({
      ...s,
      lessons: lessonsBySection[s.id] || [],
    })),
  }));
});

// POST /api/courses — teacher creates course
router.post('/', authenticate, requireRoles('teacher', 'admin', 'super_admin'), async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const body = await c.req.json();
  const parsed = courseSchema.safeParse(body);
  if (!parsed.success) return c.json(formatResponse(false, null, parsed.error.errors[0].message), 400);

  const teacher = await db.prepare('SELECT id FROM teachers WHERE user_id = ?').bind(user.userId).first() as any;
  if (!teacher) return c.json(formatResponse(false, null, 'Teacher profile not found'), 404);

  const id = generateId();
  const { title, subtitle, description, price, duration_days, category_id, thumbnail_url,
    intro_video_url, language, level, has_certificate, drip_type, drip_delay_days } = parsed.data;

  await db.prepare(
    `INSERT INTO courses (id, teacher_id, category_id, title, subtitle, description, price,
     duration_days, thumbnail_url, intro_video_url, language, level, has_certificate,
     drip_type, drip_delay_days)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).bind(id, teacher.id!, category_id || null, title, subtitle || null, description || null,
    price, duration_days || null, thumbnail_url || null, intro_video_url || null,
    language || 'ar', level || 'all', has_certificate ? 1 : 0,
    drip_type || 'none', drip_delay_days || null).run();

  return c.json(formatResponse(true, { id }, 'Course created'), 201);
});

// PUT /api/courses/:id — update course
router.put('/:id', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { id } = c.req.param();

  const course = await db.prepare('SELECT teacher_id FROM courses WHERE id = ?').bind(id).first() as any;
  if (!course) return c.json(formatResponse(false, null, 'Course not found'), 404);

  const teacher = await db.prepare('SELECT id FROM teachers WHERE user_id = ?').bind(user.userId).first() as any;
  const isOwner = teacher && course.teacher_id === teacher.id;
  const isAdmin = user.role === 'admin' || user.role === 'super_admin';
  if (!isOwner && !isAdmin) return c.json(formatResponse(false, null, 'Forbidden'), 403);

  const body = await c.req.json();
  const { title, subtitle, description, price, duration_days, category_id, thumbnail_url,
    language, level, status, drip_type, drip_delay_days } = body;

  await db.prepare(
    `UPDATE courses SET
     title = COALESCE(?, title), subtitle = COALESCE(?, subtitle),
     description = COALESCE(?, description), price = COALESCE(?, price),
     duration_days = ?, category_id = COALESCE(?, category_id),
     thumbnail_url = COALESCE(?, thumbnail_url), language = COALESCE(?, language),
     level = COALESCE(?, level), status = COALESCE(?, status),
     drip_type = COALESCE(?, drip_type), drip_delay_days = ?,
     updated_at = datetime('now')
     WHERE id = ?`
  ).bind(title || null, subtitle || null, description || null,
    price ?? null, duration_days ?? null, category_id || null,
    thumbnail_url || null, language || null, level || null,
    status || null, drip_type || null, drip_delay_days ?? null, id).run();

  return c.json(formatResponse(true, null, 'Course updated'));
});

// POST /api/courses/:id/sections — add section to course
router.post('/:id/sections', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { id } = c.req.param();
  const { title, description, sort_order } = await c.req.json();

  const course = await db.prepare('SELECT teacher_id FROM courses WHERE id = ?').bind(id).first() as any;
  if (!course) return c.json(formatResponse(false, null, 'Course not found'), 404);

  const teacher = await db.prepare('SELECT id FROM teachers WHERE user_id = ?').bind(user.userId).first() as any;
  const isOwner = teacher && course.teacher_id === teacher.id;
  const isAdmin = user.role === 'admin' || user.role === 'super_admin';
  if (!isOwner && !isAdmin) return c.json(formatResponse(false, null, 'Forbidden'), 403);

  const sectionId = generateId();
  await db.prepare(
    'INSERT INTO sections (id, course_id, title, description, sort_order) VALUES (?, ?, ?, ?, ?)'
  ).bind(sectionId, id, title || 'Untitled', description || null, sort_order || 0).run();

  return c.json(formatResponse(true, { id: sectionId }, 'Section added'), 201);
});

// POST /api/courses/:courseId/sections/:sectionId/lessons — add lesson
router.post('/:courseId/sections/:sectionId/lessons', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { courseId, sectionId } = c.req.param();
  const body = await c.req.json();

  const course = await db.prepare('SELECT teacher_id FROM courses WHERE id = ?').bind(courseId).first() as any;
  if (!course) return c.json(formatResponse(false, null, 'Course not found'), 404);

  const teacher = await db.prepare('SELECT id FROM teachers WHERE user_id = ?').bind(user.userId).first() as any;
  const isOwner = teacher && course.teacher_id === teacher.id;
  const isAdmin = user.role === 'admin' || user.role === 'super_admin';
  if (!isOwner && !isAdmin) return c.json(formatResponse(false, null, 'Forbidden'), 403);

  const lessonId = generateId();
  const { title, type, video_url, pdf_url, article_content, is_free, sort_order, drip_delay } = body;

  await db.prepare(
    `INSERT INTO lessons (id, section_id, title, type, video_url, pdf_url, article_content, is_free, sort_order, drip_delay)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).bind(lessonId, sectionId, title || 'Untitled', type || 'video',
    video_url || null, pdf_url || null, article_content || null,
    is_free ? 1 : 0, sort_order || 0, drip_delay || null).run();

  // Update course counters
  const total = await db.prepare('SELECT COUNT(*) as count FROM lessons l JOIN sections s ON l.section_id = s.id WHERE s.course_id = ?')
    .bind(courseId).first() as any;
  const duration = await db.prepare('SELECT COALESCE(SUM(video_duration), 0) as total FROM lessons l JOIN sections s ON l.section_id = s.id WHERE s.course_id = ?')
    .bind(courseId).first() as any;
  await db.prepare('UPDATE courses SET total_lessons = ?, total_duration = ?, updated_at = datetime(\'now\') WHERE id = ?')
    .bind(total?.count || 0, duration?.total || 0, courseId).run();

  return c.json(formatResponse(true, { id: lessonId }, 'Lesson added'), 201);
});

// PUT /api/lessons/:id — update lesson
router.put('/lessons/:id', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { id } = c.req.param();
  const body = await c.req.json();

  // Ownership check: verify the lesson belongs to the current teacher
  const isAdmin = user.role === 'admin' || user.role === 'super_admin';
  if (!isAdmin) {
    const lesson = await db.prepare(
      `SELECT c.teacher_id FROM lessons l
       JOIN sections s ON l.section_id = s.id
       JOIN courses c ON s.course_id = c.id
       WHERE l.id = ?`
    ).bind(id).first() as any;
    if (!lesson) return c.json(formatResponse(false, null, 'Lesson not found'), 404);
    const teacher = await db.prepare('SELECT id FROM teachers WHERE user_id = ?').bind(user.userId).first() as any;
    if (!teacher || lesson.teacher_id !== teacher.id) return c.json(formatResponse(false, null, 'Forbidden'), 403);
  }

  await db.prepare(
    `UPDATE lessons SET
     title = COALESCE(?, title), type = COALESCE(?, type),
     video_url = COALESCE(?, video_url), pdf_url = COALESCE(?, pdf_url),
     article_content = COALESCE(?, article_content), is_free = COALESCE(?, is_free),
     video_duration = COALESCE(?, video_duration), video_status = COALESCE(?, video_status),
     sort_order = COALESCE(?, sort_order), description = COALESCE(?, description),
     updated_at = datetime('now')
     WHERE id = ?`
  ).bind(body.title || null, body.type || null, body.video_url || null,
    body.pdf_url || null, body.article_content || null, body.is_free ?? null,
    body.video_duration ?? null, body.video_status || null,
    body.sort_order ?? null, body.description || null, id).run();

  return c.json(formatResponse(true, null, 'Lesson updated'));
});

// PUT /api/sections/:id — rename section
router.put('/sections/:id', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { id } = c.req.param();
  const { title } = await c.req.json();

  // Ownership check: verify the section belongs to the current teacher
  const isAdmin = user.role === 'admin' || user.role === 'super_admin';
  if (!isAdmin) {
    const section = await db.prepare(
      `SELECT c.teacher_id FROM sections s
       JOIN courses c ON s.course_id = c.id
       WHERE s.id = ?`
    ).bind(id).first() as any;
    if (!section) return c.json(formatResponse(false, null, 'Section not found'), 404);
    const teacher = await db.prepare('SELECT id FROM teachers WHERE user_id = ?').bind(user.userId).first() as any;
    if (!teacher || section.teacher_id !== teacher.id) return c.json(formatResponse(false, null, 'Forbidden'), 403);
  }

  await db.prepare('UPDATE sections SET title = COALESCE(?, title) WHERE id = ?').bind(title || null, id).run();
  return c.json(formatResponse(true, null, 'Section updated'));
});

// PUT /api/courses/:id/sections/reorder
router.put('/:id/sections/reorder', authenticate, async (c) => {
  const db = c.env.DB;
  const { sections } = await c.req.json(); // [{ id, sort_order }]
  for (const s of sections) {
    await db.prepare('UPDATE sections SET sort_order = ? WHERE id = ?').bind(s.sort_order, s.id).run();
  }
  return c.json(formatResponse(true, null, 'Sections reordered'));
});

// PUT /api/sections/:sectionId/lessons/reorder
router.put('/sections/:sectionId/lessons/reorder', authenticate, async (c) => {
  const db = c.env.DB;
  const { lessons } = await c.req.json(); // [{ id, sort_order }]
  for (const l of lessons) {
    await db.prepare('UPDATE lessons SET sort_order = ? WHERE id = ?').bind(l.sort_order, l.id).run();
  }
  return c.json(formatResponse(true, null, 'Lessons reordered'));
});

// POST /api/courses/:courseId/sections/:sectionId/bunny-video
router.post('/:courseId/sections/:sectionId/bunny-video', authenticate, async (c) => {
  const user = c.get('user');
  const env = c.env;
  const db = env.DB;
  const { courseId, sectionId } = c.req.param();
  const { title } = await c.req.json();

  const course = await db.prepare('SELECT teacher_id FROM courses WHERE id = ?').bind(courseId).first() as any;
  if (!course) return c.json(formatResponse(false, null, 'Course not found'), 404);

  // Ownership verification: only course owner or admin can upload videos
  const teacher = await db.prepare('SELECT id FROM teachers WHERE user_id = ?').bind(user.userId).first() as any;
  const isOwner = teacher && course.teacher_id === teacher.id;
  const isAdmin = user.role === 'admin' || user.role === 'super_admin';
  if (!isOwner && !isAdmin) return c.json(formatResponse(false, null, 'Forbidden'), 403);

  // 1. Create video in Bunny Stream
  const bunnyRes = await fetch(`https://video.bunnycdn.com/library/${env.BUNNY_STREAM_LIBRARY_ID}/videos`, {
    method: 'POST',
    headers: {
      'AccessKey': env.BUNNY_STREAM_API_KEY,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: JSON.stringify({ title: title || 'Untitled Lesson' }),
  });

  const bunnyData: any = await bunnyRes.json();
  if (!bunnyRes.ok || !bunnyData.guid) {
    return c.json(formatResponse(false, null, 'Failed to create video in Bunny Stream'), 500);
  }

  // 2. Create lesson in D1
  const lessonId = generateId();
  await db.prepare(
    `INSERT INTO lessons (id, section_id, title, type, video_url, video_status, sort_order)
     VALUES (?, ?, ?, 'video', ?, 'uploading', 0)`
  ).bind(lessonId, sectionId, title || 'Untitled', bunnyData.guid).run();

  // Return upload info — only the verified course owner reaches this point
  return c.json(formatResponse(true, {
    lessonId,
    guid: bunnyData.guid,
    libraryId: env.BUNNY_STREAM_LIBRARY_ID,
    uploadUrl: `https://video.bunnycdn.com/library/${env.BUNNY_STREAM_LIBRARY_ID}/videos/${bunnyData.guid}`,
    uploadKey: env.BUNNY_STREAM_API_KEY,
  }, 'Lesson created and ready for upload'), 201);
});

// DELETE /api/lessons/:id
router.delete('/lessons/:id', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { id } = c.req.param();

  // Ownership check
  const isAdmin = user.role === 'admin' || user.role === 'super_admin';
  if (!isAdmin) {
    const lesson = await db.prepare(
      `SELECT c.teacher_id FROM lessons l
       JOIN sections s ON l.section_id = s.id
       JOIN courses c ON s.course_id = c.id
       WHERE l.id = ?`
    ).bind(id).first() as any;
    if (!lesson) return c.json(formatResponse(false, null, 'Lesson not found'), 404);
    const teacher = await db.prepare('SELECT id FROM teachers WHERE user_id = ?').bind(user.userId).first() as any;
    if (!teacher || lesson.teacher_id !== teacher.id) return c.json(formatResponse(false, null, 'Forbidden'), 403);
  }

  await db.prepare('DELETE FROM lessons WHERE id = ?').bind(id).run();
  return c.json(formatResponse(true, null, 'Lesson deleted'));
});

// DELETE /api/sections/:id
router.delete('/sections/:id', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { id } = c.req.param();

  // Ownership check
  const isAdmin = user.role === 'admin' || user.role === 'super_admin';
  if (!isAdmin) {
    const section = await db.prepare(
      `SELECT c.teacher_id FROM sections s
       JOIN courses c ON s.course_id = c.id
       WHERE s.id = ?`
    ).bind(id).first() as any;
    if (!section) return c.json(formatResponse(false, null, 'Section not found'), 404);
    const teacher = await db.prepare('SELECT id FROM teachers WHERE user_id = ?').bind(user.userId).first() as any;
    if (!teacher || section.teacher_id !== teacher.id) return c.json(formatResponse(false, null, 'Forbidden'), 403);
  }

  await db.prepare('DELETE FROM lessons WHERE section_id = ?').bind(id).run();
  await db.prepare('DELETE FROM sections WHERE id = ?').bind(id).run();
  return c.json(formatResponse(true, null, 'Section deleted'));
});

// DELETE /api/courses/:id — delete course
router.delete('/:id', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { id } = c.req.param();

  const course = await db.prepare('SELECT teacher_id FROM courses WHERE id = ?').bind(id).first() as any;
  if (!course) return c.json(formatResponse(false, null, 'Course not found'), 404);

  const teacher = await db.prepare('SELECT id FROM teachers WHERE user_id = ?').bind(user.userId).first() as any;
  const isOwner = teacher && course.teacher_id === teacher.id;
  const isAdmin = user.role === 'admin' || user.role === 'super_admin';
  if (!isOwner && !isAdmin) return c.json(formatResponse(false, null, 'Forbidden'), 403);

  // Delete lessons for all sections of this course
  const sections = await db.prepare('SELECT id FROM sections WHERE course_id = ?').bind(id).all();
  const sectionIds = (sections.results as any[]).map(s => s.id);
  if (sectionIds.length > 0) {
    const placeholders = sectionIds.map(() => '?').join(',');
    await db.prepare(`DELETE FROM lessons WHERE section_id IN (${placeholders})`).bind(...sectionIds).run();
  }

  // Delete sections
  await db.prepare('DELETE FROM sections WHERE course_id = ?').bind(id).run();

  // Delete the course
  await db.prepare('DELETE FROM courses WHERE id = ?').bind(id).run();

  return c.json(formatResponse(true, null, 'Course deleted'));
});

export default router;
