import { Hono } from 'hono';
import { formatResponse } from '../utils/helpers';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

// GET /api/search?q=...&category=...
router.get('/', async (c) => {
  const db = c.env.DB;
  const { q, category, level, min_price, max_price, sort, page = '1', limit = '20' } = c.req.query();

  let query = `SELECT c.id, c.title, c.subtitle, c.price, c.thumbnail_url, c.average_rating,
               c.total_students, c.level, c.duration_days, c.total_lessons,
               u.full_name as teacher_name, t.photo_url as teacher_photo,
               cat.name as category_name
               FROM courses c
               JOIN teachers t ON c.teacher_id = t.id
               JOIN users u ON t.user_id = u.id
               LEFT JOIN categories cat ON c.category_id = cat.id
               WHERE c.status = 'published'`;
  const params: any[] = [];

  if (q) {
    query += ' AND (c.title LIKE ? OR c.subtitle LIKE ? OR c.description LIKE ? OR u.full_name LIKE ?)';
    const searchTerm = `%${q}%`;
    params.push(searchTerm, searchTerm, searchTerm, searchTerm);
  }
  if (category) { query += ' AND c.category_id = ?'; params.push(category); }
  if (level) { query += ' AND c.level = ?'; params.push(level); }
  if (min_price) { query += ' AND c.price >= ?'; params.push(Number(min_price)); }
  if (max_price) { query += ' AND c.price <= ?'; params.push(Number(max_price)); }

  if (sort === 'price_asc') query += ' ORDER BY c.price ASC';
  else if (sort === 'price_desc') query += ' ORDER BY c.price DESC';
  else if (sort === 'rating') query += ' ORDER BY c.average_rating DESC';
  else if (sort === 'students') query += ' ORDER BY c.total_students DESC';
  else if (sort === 'newest') query += ' ORDER BY c.created_at DESC';
  else query += ' ORDER BY c.total_students DESC';

  const offset = (Number(page) - 1) * Number(limit);
  query += ' LIMIT ? OFFSET ?';
  params.push(Number(limit), offset);

  const courses = await db.prepare(query).bind(...params).all();

  // Count results
  let countQuery = `SELECT COUNT(*) as count FROM courses c
    JOIN teachers t ON c.teacher_id = t.id
    JOIN users u ON t.user_id = u.id
    WHERE c.status = 'published'`;
  const countParams: any[] = [];

  if (q) {
    countQuery += ' AND (c.title LIKE ? OR c.subtitle LIKE ? OR c.description LIKE ? OR u.full_name LIKE ?)';
    const searchTerm = `%${q}%`;
    countParams.push(searchTerm, searchTerm, searchTerm, searchTerm);
  }
  if (category) { countQuery += ' AND c.category_id = ?'; countParams.push(category); }
  if (level) { countQuery += ' AND c.level = ?'; countParams.push(level); }

  const countResult = await db.prepare(countQuery).bind(...countParams).first() as any;

  return c.json(formatResponse(true, {
    results: courses.results,
    total: countResult?.count || 0,
    page: Number(page),
    limit: Number(limit),
  }));
});

export default router;
