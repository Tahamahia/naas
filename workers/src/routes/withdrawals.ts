import { Hono } from 'hono';
import { formatResponse, generateId } from '../utils/helpers';
import { authenticate, requireRoles } from '../middleware/auth';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

// POST /api/withdrawals — teacher requests withdrawal
router.post('/', authenticate, requireRoles('teacher'), async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { amount } = await c.req.json();

  if (!amount || amount <= 0) return c.json(formatResponse(false, null, 'Invalid amount'), 400);

  const teacher = await db.prepare(
    'SELECT id, total_earned, total_withdrawn, iban, bank_name, account_holder FROM teachers WHERE user_id = ?'
  ).bind(user.userId).first() as any;

  if (!teacher) return c.json(formatResponse(false, null, 'Teacher profile not found'), 404);

  const available = teacher.total_earned! - teacher.total_withdrawn!;
  if (amount > available) {
    return c.json(formatResponse(false, { available }, 'Insufficient available balance'), 400);
  }

  if (!teacher.iban) {
    return c.json(formatResponse(false, null, 'Please update your bank information (IBAN) first'), 400);
  }

  const id = generateId();
  await db.prepare(
    'INSERT INTO withdrawals (id, teacher_id, amount, iban, bank_name, account_holder) VALUES (?, ?, ?, ?, ?, ?)'
  ).bind(id, teacher.id!, amount, teacher.iban!, teacher.bank_name!, teacher.account_holder!).run();

  return c.json(formatResponse(true, { id }, 'Withdrawal request submitted. Pending admin processing.'), 201);
});

// GET /api/withdrawals/my — teacher's withdrawal history
router.get('/my', authenticate, requireRoles('teacher'), async (c) => {
  const user = c.get('user');
  const db = c.env.DB;

  const teacher = await db.prepare('SELECT id FROM teachers WHERE user_id = ?').bind(user.userId).first() as any;
  if (!teacher) return c.json(formatResponse(false, null, 'Teacher not found'), 404);

  const withdrawals = await db.prepare(
    'SELECT * FROM withdrawals WHERE teacher_id = ? ORDER BY created_at DESC'
  ).bind(teacher.id!).all();

  return c.json(formatResponse(true, withdrawals.results));
});

// GET /api/withdrawals/pending — admin: view pending withdrawals
router.get('/pending', authenticate, requireRoles('super_admin', 'admin'), async (c) => {
  const db = c.env.DB;

  const pending = await db.prepare(
    `SELECT w.*, u.full_name, u.email
     FROM withdrawals w
     JOIN teachers t ON w.teacher_id = t.id
     JOIN users u ON t.user_id = u.id
     WHERE w.status = 'pending'
     ORDER BY w.created_at ASC`
  ).all();

  return c.json(formatResponse(true, pending.results));
});

// POST /api/withdrawals/:id/process — admin processes withdrawal
router.post('/:id/process', authenticate, requireRoles('super_admin', 'admin'), async (c) => {
  const admin = c.get('user');
  const db = c.env.DB;
  const { id } = c.req.param();
  const { action, notes, proof_url } = await c.req.json();

  const withdrawal = await db.prepare(
    'SELECT * FROM withdrawals WHERE id = ? AND status = ?'
  ).bind(id, 'pending').first() as any;

  if (!withdrawal) return c.json(formatResponse(false, null, 'Pending withdrawal not found'), 404);

  if (action === 'approve') {
    await db.prepare(
      "UPDATE withdrawals SET status = 'completed', processed_by = ?, processed_at = datetime('now'), proof_url = ?, notes = ? WHERE id = ?"
    ).bind(admin.userId, proof_url || null, notes || null, id).run();

    await db.prepare('UPDATE teachers SET total_withdrawn = total_withdrawn + ? WHERE id = ?')
      .bind(withdrawal.amount!, withdrawal.teacher_id!).run();

    return c.json(formatResponse(true, null, 'Withdrawal approved and marked as paid'));
  } else {
    await db.prepare(
      "UPDATE withdrawals SET status = 'rejected', processed_by = ?, processed_at = datetime('now'), notes = ? WHERE id = ?"
    ).bind(admin.userId, notes || null, id).run();

    return c.json(formatResponse(true, null, 'Withdrawal rejected'));
  }
});

export default router;
