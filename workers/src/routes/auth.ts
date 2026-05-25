import { Hono } from 'hono';
import { z } from 'zod';
import { generateAccessToken, generateRefreshToken, verifyRefreshToken } from '../utils/jwt';
import { hashPassword, verifyPassword } from '../utils/crypto';
import { formatResponse, generateId } from '../utils/helpers';
import { authenticate } from '../middleware/auth';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6).max(100),
  full_name: z.string().min(2).max(100),
  phone: z.string().optional(),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string(),
});

router.post('/register', async (c) => {
  const body = await c.req.json();
  const parsed = registerSchema.safeParse(body);
  if (!parsed.success) return c.json(formatResponse(false, null, parsed.error.errors[0].message), 400);

  const { email, password, full_name, phone } = parsed.data;
  const db = c.env.DB;

  const existing = await db.prepare('SELECT id FROM users WHERE email = ?').bind(email).first();
  if (existing) return c.json(formatResponse(false, null, 'Email already registered'), 409);

  const id = generateId();
  const passwordHash = await hashPassword(password);
  const referralCode = generateId().substring(0, 8).toUpperCase();

  await db.prepare(
    'INSERT INTO users (id, email, password_hash, full_name, phone, referral_code) VALUES (?, ?, ?, ?, ?, ?)'
  ).bind(id, email, passwordHash, full_name, phone || null, referralCode).run();

  const user = await db.prepare('SELECT id, email, full_name, role FROM users WHERE id = ?').bind(id).first() as any;
  const payload = { userId: user.id!, email: user.email!, role: user.role! as any };
  const accessToken = await generateAccessToken(payload);
  const refreshToken = await generateRefreshToken(payload);

  return c.json(formatResponse(true, { user, accessToken, refreshToken }, 'Registration successful'), 201);
});

router.post('/login', async (c) => {
  const body = await c.req.json();
  const parsed = loginSchema.safeParse(body);
  if (!parsed.success) return c.json(formatResponse(false, null, 'Invalid email or password'), 400);

  const { email, password } = parsed.data;
  const db = c.env.DB;

  const user = await db.prepare(
    'SELECT id, email, password_hash, full_name, role, status, phone, avatar_url, wallet_balance, points, referral_code, lang FROM users WHERE email = ?'
  ).bind(email).first() as any;

  if (!user || user.status !== 'active') return c.json(formatResponse(false, null, 'Invalid email or password'), 401);

  const valid = await verifyPassword(password, user.password_hash!);
  if (!valid) return c.json(formatResponse(false, null, 'Invalid email or password'), 401);

  const payload = { userId: user.id!, email: user.email!, role: user.role! as any };
  const accessToken = await generateAccessToken(payload);
  const refreshToken = await generateRefreshToken(payload);

  return c.json(formatResponse(true, {
    user: {
      id: user.id, email: user.email, full_name: user.full_name, role: user.role,
      phone: user.phone, avatar_url: user.avatar_url, wallet_balance: user.wallet_balance,
      points: user.points, referral_code: user.referral_code, lang: user.lang, status: user.status,
    },
    accessToken, refreshToken,
  }, 'Login successful'));
});

router.post('/refresh', async (c) => {
  const { refreshToken } = await c.req.json();
  if (!refreshToken) return c.json(formatResponse(false, null, 'Refresh token required'), 400);

  try {
    const payload = await verifyRefreshToken(refreshToken);
    const newPayload = { userId: payload.userId, email: payload.email, role: payload.role };
    const newAccessToken = await generateAccessToken(newPayload);
    const newRefreshToken = await generateRefreshToken(newPayload);
    return c.json(formatResponse(true, { accessToken: newAccessToken, refreshToken: newRefreshToken }, 'Token refreshed'));
  } catch {
    return c.json(formatResponse(false, null, 'Invalid refresh token'), 401);
  }
});

router.get('/me', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const u = await db.prepare(
    'SELECT id, email, full_name, phone, avatar_url, role, status, wallet_balance, points, referral_code, lang FROM users WHERE id = ?'
  ).bind(user.userId).first();
  if (!u) return c.json(formatResponse(false, null, 'User not found'), 404);
  return c.json(formatResponse(true, u));
});

router.put('/profile', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const body = await c.req.json();
  const { full_name, phone, avatar_url, lang } = body;

  await db.prepare(
    "UPDATE users SET full_name = COALESCE(?, full_name), phone = COALESCE(?, phone), avatar_url = COALESCE(?, avatar_url), lang = COALESCE(?, lang), updated_at = datetime('now') WHERE id = ?"
  ).bind(full_name || null, phone || null, avatar_url || null, lang || null, user.userId).run();

  return c.json(formatResponse(true, null, 'Profile updated'));
});

router.put('/fcm-token', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { fcm_token } = await c.req.json();
  await db.prepare('UPDATE users SET fcm_token = ? WHERE id = ?').bind(fcm_token, user.userId).run();
  return c.json(formatResponse(true, null, 'FCM token updated'));
});

export default router;
