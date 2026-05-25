import { Hono } from 'hono';
import { z } from 'zod';
import { formatResponse, generateId } from '../utils/helpers';
import { authenticate, requireRoles } from '../middleware/auth';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

const applySchema = z.object({
  bio: z.string().min(10).max(2000),
  qualification: z.string().min(2).max(500),
  id_document_url: z.string().url(),
  certificate_url: z.string().url(),
  photo_url: z.string().url(),
  iban: z.string().optional(),
  bank_name: z.string().optional(),
  account_holder: z.string().optional(),
});

// POST /api/teachers/apply — student applies to become teacher
router.post('/apply', authenticate, async (c) => {
  const user = c.get('user');
  if (user.role === 'teacher' || user.role === 'admin' || user.role === 'super_admin') {
    return c.json(formatResponse(false, null, 'You are already a teacher or admin'), 400);
  }

  const db = c.env.DB;
  const body = await c.req.json();
  const parsed = applySchema.safeParse(body);
  if (!parsed.success) {
    return c.json(formatResponse(false, null, parsed.error.errors[0].message), 400);
  }

  const existing = await db.prepare('SELECT id FROM teachers WHERE user_id = ?').bind(user.userId).first();
  if (existing) {
    return c.json(formatResponse(false, null, 'Application already submitted'), 409);
  }

  const id = generateId();
  const { bio, qualification, id_document_url, certificate_url, photo_url, iban, bank_name, account_holder } = parsed.data;

  await db.prepare(
    `INSERT INTO teachers (id, user_id, bio, qualification, id_document_url, certificate_url, photo_url, iban, bank_name, account_holder)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).bind(id, user.userId, bio, qualification, id_document_url, certificate_url, photo_url,
    iban || null, bank_name || null, account_holder || null).run();

  return c.json(formatResponse(true, null, 'Application submitted successfully. Awaiting admin approval.'), 201);
});

// GET /api/teachers/pending — admin views pending applications
router.get('/pending', authenticate, requireRoles('super_admin', 'admin'), async (c) => {
  const db = c.env.DB;
  const pending = await db.prepare(
    `SELECT t.*, u.email, u.full_name, u.phone, u.avatar_url
     FROM teachers t JOIN users u ON t.user_id = u.id
     WHERE t.status = 'pending' ORDER BY t.created_at DESC`
  ).all();

  return c.json(formatResponse(true, pending.results));
});

// POST /api/teachers/:id/approve — admin approves teacher
router.post('/:id/approve', authenticate, requireRoles('super_admin', 'admin'), async (c) => {
  const admin = c.get('user');
  const db = c.env.DB;
  const { id } = c.req.param();

  const teacher = await db.prepare('SELECT user_id FROM teachers WHERE id = ?').bind(id).first() as any;
  if (!teacher) return c.json(formatResponse(false, null, 'Application not found'), 404);

  await db.prepare(
    `UPDATE teachers SET status = 'approved', approved_by = ?, approved_at = datetime('now')
     WHERE id = ?`
  ).bind(admin.userId, id).run();

  await db.prepare("UPDATE users SET role = 'teacher' WHERE id = ?").bind(teacher.user_id!).run();

  return c.json(formatResponse(true, null, 'Teacher approved'));
});

// POST /api/teachers/:id/reject — admin rejects teacher
router.post('/:id/reject', authenticate, requireRoles('super_admin', 'admin'), async (c) => {
  const db = c.env.DB;
  const { id } = c.req.param();
  const { reason } = await c.req.json();

  await db.prepare(
    "UPDATE teachers SET status = 'rejected', rejection_reason = ? WHERE id = ?"
  ).bind(reason || null, id).run();

  return c.json(formatResponse(true, null, 'Teacher rejected'));
});

// GET /api/teachers/:id — public teacher profile
router.get('/:id', async (c) => {
  const db = c.env.DB;
  const { id } = c.req.param();

  const teacher = await db.prepare(
    `SELECT t.id, t.bio, t.qualification, t.photo_url, t.status,
            u.full_name, u.email, u.avatar_url
     FROM teachers t JOIN users u ON t.user_id = u.id
     WHERE t.id = ?`
  ).bind(id).first();

  if (!teacher) return c.json(formatResponse(false, null, 'Teacher not found'), 404);

  const courses = await db.prepare(
    `SELECT id, title, price, thumbnail_url, average_rating, total_students, duration_days
     FROM courses WHERE teacher_id = ? AND status = 'published'`
  ).bind(id).all();

  return c.json(formatResponse(true, { ...teacher as any, courses: courses.results }));
});

// GET /api/teachers/my/profile — current teacher's own profile
router.get('/my/profile', authenticate, async (c) => {
  const user = c.get('user');
  if (user.role !== 'teacher') return c.json(formatResponse(false, null, 'Not a teacher'), 403);

  const db = c.env.DB;
  const teacher = await db.prepare(
    `SELECT t.*, u.full_name, u.email, u.phone, u.avatar_url, u.wallet_balance
     FROM teachers t JOIN users u ON t.user_id = u.id
     WHERE t.user_id = ?`
  ).bind(user.userId).first();

  return c.json(formatResponse(true, teacher));
});

// PUT /api/teachers/my/profile — update teacher profile & bank info
router.put('/my/profile', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const body = await c.req.json();
  const { bio, qualification, iban, bank_name, account_holder } = body;

  await db.prepare(
    `UPDATE teachers SET bio = COALESCE(?, bio), qualification = COALESCE(?, qualification),
     iban = COALESCE(?, iban), bank_name = COALESCE(?, bank_name),
     account_holder = COALESCE(?, account_holder)
     WHERE user_id = ?`
  ).bind(bio || null, qualification || null, iban || null, bank_name || null, account_holder || null, user.userId).run();

  return c.json(formatResponse(true, null, 'Profile updated'));
});

// GET /api/teachers/my/earnings — teacher earnings dashboard
router.get('/my/earnings', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;

  const teacher = await db.prepare(
    'SELECT id, total_earned, total_withdrawn, commission_fixed, commission_percent FROM teachers WHERE user_id = ?'
  ).bind(user.userId).first() as any;

  if (!teacher) return c.json(formatResponse(false, null, 'Teacher not found'), 404);

  const balance = teacher.total_earned! - teacher.total_withdrawn!;

  const recentTransactions = await db.prepare(
    `SELECT t.type, t.amount, t.description, t.status, t.created_at
     FROM transactions t WHERE t.reference_id = ? AND t.type = 'commission'
     ORDER BY t.created_at DESC LIMIT 20`
  ).bind(teacher.id!).all();

  return c.json(formatResponse(true, {
    total_earned: teacher.total_earned,
    total_withdrawn: teacher.total_withdrawn,
    available_balance: balance,
    commission_fixed: teacher.commission_fixed,
    commission_percent: teacher.commission_percent,
    recent_transactions: recentTransactions.results,
  }));
});

export default router;
