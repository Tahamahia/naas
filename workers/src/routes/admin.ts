import { Hono } from 'hono';
import { formatResponse, generateId } from '../utils/helpers';
import { hashPassword } from '../utils/crypto';
import { authenticate, requireRoles } from '../middleware/auth';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

// All admin routes require super_admin or admin role
router.use('*', authenticate, requireRoles('super_admin', 'admin'));

// GET /api/admin/dashboard — admin stats
router.get('/dashboard', async (c) => {
  const db = c.env.DB;

  const totalUsers = await db.prepare('SELECT COUNT(*) as count FROM users').first() as any;
  const totalTeachers = await db.prepare('SELECT COUNT(*) as count FROM teachers WHERE status = ?').bind('approved').first() as any;
  const pendingTeachers = await db.prepare('SELECT COUNT(*) as count FROM teachers WHERE status = ?').bind('pending').first() as any;
  const totalCourses = await db.prepare("SELECT COUNT(*) as count FROM courses WHERE status = 'published'").first() as any;
  const pendingCourses = await db.prepare("SELECT COUNT(*) as count FROM courses WHERE status = 'pending'").first() as any;
  const activeSubs = await db.prepare("SELECT COUNT(*) as count FROM subscriptions WHERE status = 'active'").first() as any;
  const totalRevenue = await db.prepare("SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE type = 'payment' AND status = 'completed'").first() as any;
  const totalDeposits = await db.prepare("SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE type = 'deposit_manual' AND status = 'completed'").first() as any;
  const pendingWithdrawals = await db.prepare("SELECT COUNT(*) as count FROM withdrawals WHERE status = 'pending'").first() as any;
  const pendingRefunds = await db.prepare("SELECT COUNT(*) as count FROM refund_requests WHERE status = 'pending'").first() as any;
  const totalReports = await db.prepare("SELECT COUNT(*) as count FROM reports WHERE status = 'pending'").first() as any;

  return c.json(formatResponse(true, {
    users: totalUsers?.count || 0,
    teachers: { approved: totalTeachers?.count || 0, pending: pendingTeachers?.count || 0 },
    courses: { published: totalCourses?.count || 0, pending: pendingCourses?.count || 0 },
    subscriptions: { active: activeSubs?.count || 0 },
    revenue: totalRevenue?.total || 0,
    deposits: totalDeposits?.total || 0,
    pending_withdrawals: pendingWithdrawals?.count || 0,
    pending_refunds: pendingRefunds?.count || 0,
    pending_reports: totalReports?.count || 0,
  }));
});

// GET /api/admin/users — list all users
router.get('/users', async (c) => {
  const db = c.env.DB;
  const { page = '1', limit = '20', role, status } = c.req.query();

  let query = 'SELECT id, email, full_name, phone, role, status, wallet_balance, points, email_verified, created_at FROM users WHERE 1=1';
  const params: any[] = [];

  if (role) { query += ' AND role = ?'; params.push(role); }
  if (status) { query += ' AND status = ?'; params.push(status); }

  query += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
  const offset = (Number(page) - 1) * Number(limit);
  params.push(Number(limit), offset);

  const users = await db.prepare(query).bind(...params).all();
  return c.json(formatResponse(true, users.results));
});

// POST /api/admin/users/:id/ban
router.post('/users/:id/ban', async (c) => {
  const db = c.env.DB;
  const { id } = c.req.param();
  await db.prepare("UPDATE users SET status = 'banned' WHERE id = ?").bind(id).run();
  return c.json(formatResponse(true, null, 'User banned'));
});

// POST /api/admin/users/:id/unban
router.post('/users/:id/unban', async (c) => {
  const db = c.env.DB;
  const { id } = c.req.param();
  await db.prepare("UPDATE users SET status = 'active' WHERE id = ?").bind(id).run();
  return c.json(formatResponse(true, null, 'User unbanned'));
});

// GET /api/admin/commission — get current commission rules
router.get('/commission', async (c) => {
  const db = c.env.DB;
  const rules = await db.prepare('SELECT * FROM commission_rules WHERE is_active = 1').all();
  return c.json(formatResponse(true, rules.results));
});

// POST /api/admin/commission — set commission rules
router.post('/commission', async (c) => {
  const db = c.env.DB;
  const { teacher_id, default_fixed, default_percent } = await c.req.json();

  if (teacher_id) {
    // Update specific teacher
    const existing = await db.prepare('SELECT id FROM commission_rules WHERE teacher_id = ?').bind(teacher_id).first();
    if (existing) {
      await db.prepare(
        'UPDATE commission_rules SET default_fixed = ?, default_percent = ?, updated_at = datetime(\'now\') WHERE teacher_id = ?'
      ).bind(default_fixed || 0, default_percent || 10, teacher_id).run();
      await db.prepare(
        'UPDATE teachers SET commission_fixed = ?, commission_percent = ? WHERE id = ?'
      ).bind(default_fixed || 0, default_percent || 10, teacher_id).run();
    } else {
      const id = generateId();
      await db.prepare(
        'INSERT INTO commission_rules (id, teacher_id, default_fixed, default_percent) VALUES (?, ?, ?, ?)'
      ).bind(id, teacher_id, default_fixed || 0, default_percent || 10).run();
      await db.prepare(
        'UPDATE teachers SET commission_fixed = ?, commission_percent = ? WHERE id = ?'
      ).bind(default_fixed || 0, default_percent || 10, teacher_id).run();
    }
  } else {
    // Update global
    await db.prepare(
      'UPDATE commission_rules SET default_fixed = ?, default_percent = ?, updated_at = datetime(\'now\') WHERE teacher_id IS NULL AND is_active = 1'
    ).bind(default_fixed || 0, default_percent || 10).run();
  }

  return c.json(formatResponse(true, null, 'Commission rules updated'));
});

// GET /api/admin/reports — view all reports
router.get('/reports', async (c) => {
  const db = c.env.DB;
  const { status } = c.req.query();

  let query = `SELECT r.*, reporter.email as reporter_email, reporter.full_name as reporter_name
               FROM reports r JOIN users reporter ON r.reporter_id = reporter.id`;
  const params: any[] = [];

  if (status) { query += ' WHERE r.status = ?'; params.push(status); }
  query += ' ORDER BY r.created_at DESC';

  const reports = await db.prepare(query).bind(...params).all();
  return c.json(formatResponse(true, reports.results));
});

// POST /api/admin/reports/:id/resolve
router.post('/reports/:id/resolve', async (c) => {
  const admin = c.get('user');
  const db = c.env.DB;
  const { id } = c.req.param();
  const { action } = await c.req.json();

  await db.prepare(
    'UPDATE reports SET status = ?, resolved_by = ?, resolved_at = datetime(\'now\') WHERE id = ?'
  ).bind(action === 'resolve' ? 'resolved' : 'dismissed', admin.userId, id).run();

  return c.json(formatResponse(true, null, 'Report updated'));
});

// GET /api/admin/transactions — all financial transactions
router.get('/transactions', async (c) => {
  const db = c.env.DB;
  const { page = '1', limit = '20', type } = c.req.query();

  let query = `SELECT t.*, u.full_name, u.email FROM transactions t JOIN users u ON t.user_id = u.id WHERE 1=1`;
  const params: any[] = [];

  if (type) { query += ' AND t.type = ?'; params.push(type); }
  query += ' ORDER BY t.created_at DESC LIMIT ? OFFSET ?';
  const offset = (Number(page) - 1) * Number(limit);
  params.push(Number(limit), offset);

  const txs = await db.prepare(query).bind(...params).all();
  return c.json(formatResponse(true, txs.results));
});

// GET /api/admin/admins — list admins (super_admin only)
router.get('/admins', requireRoles('super_admin'), async (c) => {
  const db = c.env.DB;
  const admins = await db.prepare(
    "SELECT id, email, full_name, role, created_at FROM users WHERE role IN ('super_admin', 'admin')"
  ).all();
  return c.json(formatResponse(true, admins.results));
});

// POST /api/admin/admins — create admin (super_admin only)
router.post('/admins', requireRoles('super_admin'), async (c) => {
  const db = c.env.DB;
  const { email, full_name, password } = await c.req.json();

  const existing = await db.prepare('SELECT id FROM users WHERE email = ?').bind(email).first();
  if (existing) return c.json(formatResponse(false, null, 'Email already exists'), 409);

  const id = generateId();
  const passwordHash = await hashPassword(password);
  await db.prepare(
    "INSERT INTO users (id, email, password_hash, full_name, role, email_verified) VALUES (?, ?, ?, ?, 'admin', 1)"
  ).bind(id, email, passwordHash, full_name).run();

  return c.json(formatResponse(true, { id }, 'Admin created'), 201);
});

// GET /api/admin/pending-deposits — list pending manual deposits
router.get('/pending-deposits', async (c) => {
  const db = c.env.DB;
  const deposits = await db.prepare(
    `SELECT t.*, u.full_name, u.email FROM transactions t
     JOIN users u ON t.user_id = u.id
     WHERE t.type = 'deposit_manual' AND t.status = 'pending'
     ORDER BY t.created_at DESC`
  ).all();
  return c.json(formatResponse(true, deposits.results));
});

// GET /api/admin/courses — list all courses for admin management
router.get('/courses', async (c) => {
  const db = c.env.DB;
  const { page = '1', limit = '50', status } = c.req.query();

  let query = `SELECT c.*, u.full_name as teacher_name FROM courses c
               JOIN teachers t ON c.teacher_id = t.id
               JOIN users u ON t.user_id = u.id WHERE 1=1`;
  const params: any[] = [];

  if (status) { query += ' AND c.status = ?'; params.push(status); }
  query += ' ORDER BY c.created_at DESC LIMIT ? OFFSET ?';
  const offset = (Number(page) - 1) * Number(limit);
  params.push(Number(limit), offset);

  const courses = await db.prepare(query).bind(...params).all();
  return c.json(formatResponse(true, courses.results));
});

// PUT /api/admin/courses/:id/status — change course status
router.put('/courses/:id/status', async (c) => {
  const db = c.env.DB;
  const { id } = c.req.param();
  const { status } = await c.req.json();

  const validStatuses = ['published', 'draft', 'pending', 'disabled'];
  if (!validStatuses.includes(status)) {
    return c.json(formatResponse(false, null, 'Invalid status'), 400);
  }

  await db.prepare(
    "UPDATE courses SET status = ?, updated_at = datetime('now') WHERE id = ?"
  ).bind(status, id).run();

  return c.json(formatResponse(true, null, 'Course status updated'));
});

export default router;
