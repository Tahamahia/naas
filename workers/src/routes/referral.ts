import { Hono } from 'hono';
import { formatResponse, generateId } from '../utils/helpers';
import { authenticate } from '../middleware/auth';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

const REFERRAL_BONUS = 1.0; // 1 LYD per referral

// POST /api/referral/redeem — redeem a referral code
router.post('/redeem', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { code } = await c.req.json();

  if (!code) return c.json(formatResponse(false, null, 'Referral code required'), 400);

  const referrer = await db.prepare('SELECT id, full_name FROM users WHERE referral_code = ?').bind(code.toUpperCase()).first() as any;
  if (!referrer) return c.json(formatResponse(false, null, 'Invalid referral code'), 404);
  if (referrer.id === user.userId) return c.json(formatResponse(false, null, 'Cannot refer yourself'), 400);

  const alreadyReferred = await db.prepare(
    'SELECT id FROM referrals WHERE referred_id = ?'
  ).bind(user.userId).first();
  if (alreadyReferred) return c.json(formatResponse(false, null, 'Already referred by someone'), 409);

  const id = generateId();
  await db.prepare(
    "INSERT INTO referrals (id, referrer_id, referred_id, bonus, status) VALUES (?, ?, ?, ?, 'completed')"
  ).bind(id, referrer.id!, user.userId, REFERRAL_BONUS).run();

  // Award bonus to referrer
  await db.prepare('UPDATE users SET wallet_balance = wallet_balance + ? WHERE id = ?')
    .bind(REFERRAL_BONUS, referrer.id!).run();

  // Award bonus to new user
  await db.prepare('UPDATE users SET wallet_balance = wallet_balance + ? WHERE id = ?')
    .bind(REFERRAL_BONUS, user.userId).run();

  return c.json(formatResponse(true, { bonus: REFERRAL_BONUS }, 'Referral code applied! Both parties received bonus.'));
});

// GET /api/referral/stats — user's referral stats
router.get('/stats', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;

  const count = await db.prepare(
    'SELECT COUNT(*) as count FROM referrals WHERE referrer_id = ?'
  ).bind(user.userId).first() as any;

  const earnings = await db.prepare(
    'SELECT COALESCE(SUM(bonus), 0) as total FROM referrals WHERE referrer_id = ?'
  ).bind(user.userId).first() as any;

  const u = await db.prepare('SELECT referral_code FROM users WHERE id = ?').bind(user.userId).first() as any;

  return c.json(formatResponse(true, {
    referral_code: u?.referral_code,
    total_referrals: count?.count || 0,
    total_earned: earnings?.total || 0,
  }));
});

export default router;
