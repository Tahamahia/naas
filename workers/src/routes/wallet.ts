import { Hono } from 'hono';
import { formatResponse, generateId } from '../utils/helpers';
import { authenticate, requireRoles } from '../middleware/auth';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

// GET /api/wallet/balance
router.get('/balance', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;

  const u = await db.prepare('SELECT wallet_balance, points FROM users WHERE id = ?')
    .bind(user.userId).first();

  const transactions = await db.prepare(
    'SELECT id, type, amount, description, status, created_at FROM transactions WHERE user_id = ? ORDER BY created_at DESC LIMIT 20'
  ).bind(user.userId).all();

  return c.json(formatResponse(true, { balance: (u as any)?.wallet_balance, points: (u as any)?.points, transactions: transactions.results }));
});

// POST /api/wallet/deposit/manual — manual deposit (student sends screenshot)
router.post('/deposit/manual', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { amount, reference_number, proof_url } = await c.req.json();

  if (!amount || amount <= 0) return c.json(formatResponse(false, null, 'Invalid amount'), 400);

  const id = generateId();
  const u = await db.prepare('SELECT wallet_balance FROM users WHERE id = ?').bind(user.userId).first() as any;

  await db.prepare(
    `INSERT INTO transactions (id, user_id, type, amount, balance_before, balance_after, description, status)
     VALUES (?, ?, 'deposit_manual', ?, ?, ?, ?, 'pending')`
  ).bind(id, user.userId, amount, u.wallet_balance, u.wallet_balance,
    `Manual deposit: ${reference_number || 'No ref'}`).run();

  // Note: We DO NOT update wallet_balance here. That happens only when admin confirms.

  return c.json(formatResponse(true, { id, amount }, 'Deposit recorded. Pending admin confirmation.'));
});

// POST /api/wallet/deposit/confirm — admin confirms deposit
router.post('/deposit/confirm', authenticate, requireRoles('super_admin', 'admin'), async (c) => {
  const db = c.env.DB;
  const { transaction_id } = await c.req.json();

  const tx = await db.prepare('SELECT * FROM transactions WHERE id = ? AND status = ?').bind(transaction_id, 'pending').first() as any;
  if (!tx) return c.json(formatResponse(false, null, 'Pending transaction not found'), 404);

  // Update user balance
  await db.prepare('UPDATE users SET wallet_balance = wallet_balance + ? WHERE id = ?')
    .bind(tx.amount, tx.user_id).run();

  // Update transaction status and balance_after
  await db.prepare(
    `UPDATE transactions SET balance_after = (SELECT wallet_balance FROM users WHERE id = ?), status = 'completed'
     WHERE id = ?`
  ).bind(tx.user_id, transaction_id).run();

  return c.json(formatResponse(true, null, 'Deposit confirmed'));
});

// POST /api/wallet/deposit/reject
router.post('/deposit/reject', authenticate, requireRoles('super_admin', 'admin'), async (c) => {
  const db = c.env.DB;
  const { transaction_id } = await c.req.json();

  const tx = await db.prepare('SELECT * FROM transactions WHERE id = ? AND status = ?').bind(transaction_id, 'pending').first() as any;
  if (!tx) return c.json(formatResponse(false, null, 'Pending transaction not found'), 404);

  // Since it was pending, the balance was never added, so we only update the transaction status
  await db.prepare("UPDATE transactions SET status = 'cancelled' WHERE id = ?").bind(transaction_id).run();

  return c.json(formatResponse(true, null, 'Deposit rejected'));
});

// POST /api/wallet/refund — student requests refund (within 24h)
router.post('/refund', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { subscription_id, reason } = await c.req.json();

  if (!subscription_id) return c.json(formatResponse(false, null, 'Subscription ID required'), 400);

  const sub = await db.prepare(
    'SELECT * FROM subscriptions WHERE id = ? AND user_id = ? AND status = ?'
  ).bind(subscription_id, user.userId, 'active').first() as any;

  if (!sub) return c.json(formatResponse(false, null, 'Active subscription not found'), 404);

  // Check 24h window
  const createdAt = new Date(sub.created_at + 'Z');
  const now = new Date();
  const diffHours = (now.getTime() - createdAt.getTime()) / 3600000;

  if (diffHours > 24) {
    return c.json(formatResponse(false, null, 'Refund period has expired (24 hours)'), 400);
  }

  const refundId = generateId();
  await db.prepare(
    'INSERT INTO refund_requests (id, subscription_id, user_id, course_id, amount, reason, status) VALUES (?, ?, ?, ?, ?, ?, ?)'
  ).bind(refundId, sub.id!, user.userId, sub.course_id!, sub.amount!, reason || null, 'pending').run();

  return c.json(formatResponse(true, { id: refundId }, 'Refund request submitted'));
});

// POST /api/wallet/refund/process — admin processes refund
router.post('/refund/process', authenticate, requireRoles('super_admin', 'admin'), async (c) => {
  const admin = c.get('user');
  const db = c.env.DB;
  const { refund_id, action } = await c.req.json();

  const refund = await db.prepare(
    'SELECT * FROM refund_requests WHERE id = ? AND status = ?'
  ).bind(refund_id, 'pending').first() as any;

  if (!refund) return c.json(formatResponse(false, null, 'Pending refund not found'), 404);

  if (action === 'approve') {
    // Return money to student wallet
    await db.prepare('UPDATE users SET wallet_balance = wallet_balance + ? WHERE id = ?')
      .bind(refund.amount!, refund.user_id!).run();

    // Expire subscription
    await db.prepare("UPDATE subscriptions SET status = 'refunded' WHERE id = ?")
      .bind(refund.subscription_id!).run();

    // Deduct from teacher
    const sub = await db.prepare(
      'SELECT course_id FROM subscriptions WHERE id = ?'
    ).bind(refund.subscription_id!).first() as any;
    const course = await db.prepare('SELECT teacher_id FROM courses WHERE id = ?')
      .bind(sub.course_id!).first() as any;
    await db.prepare('UPDATE teachers SET total_earned = total_earned - ? WHERE id = ?')
      .bind(refund.amount!, course.teacher_id!).run();
    await db.prepare('UPDATE courses SET total_students = total_students - 1 WHERE id = ?')
      .bind(sub.course_id!).run();

    // Log transaction
    const txId = generateId();
    await db.prepare(
      `INSERT INTO transactions (id, user_id, type, amount, balance_before, balance_after, description, status)
       VALUES (?, ?, 'refund', ?, 0, ?, ?, 'completed')`
    ).bind(txId, refund.user_id!, refund.amount!, refund.amount!, `Refund: ${refund.reason || 'No reason'}`).run();

    await db.prepare(
      'UPDATE refund_requests SET status = ?, processed_by = ?, processed_at = datetime(\'now\') WHERE id = ?'
    ).bind('approved', admin.userId, refund_id).run();

    return c.json(formatResponse(true, null, 'Refund approved'));
  } else {
    await db.prepare(
      'UPDATE refund_requests SET status = ?, processed_by = ?, processed_at = datetime(\'now\') WHERE id = ?'
    ).bind('rejected', admin.userId, refund_id).run();

    return c.json(formatResponse(true, null, 'Refund rejected'));
  }
});

export default router;
