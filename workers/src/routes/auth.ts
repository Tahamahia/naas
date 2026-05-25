import { Hono } from 'hono';
import { hash, compare } from 'bcryptjs';
import { z } from 'zod';
import { generateAccessToken, generateRefreshToken, verifyRefreshToken } from '../utils/jwt';
import { formatResponse, generateId, generateOTP } from '../utils/helpers';
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

// POST /api/auth/register
router.post('/register', async (c) => {
  const body = await c.req.json();
  const parsed = registerSchema.safeParse(body);
  if (!parsed.success) {
    return c.json(formatResponse(false, null, parsed.error.errors[0].message), 400);
  }

  const { email, password, full_name, phone } = parsed.data;
  const db = c.env.DB;

  const existing = await db.prepare('SELECT id FROM users WHERE email = ?').bind(email).first();
  if (existing) {
    return c.json(formatResponse(false, null, 'Email already registered'), 409);
  }

  const id = generateId();
  const passwordHash = await hash(password, 10);
  const referralCode = generateId().substring(0, 8).toUpperCase();

  await db.prepare(
    `INSERT INTO users (id, email, password_hash, full_name, phone, referral_code)
     VALUES (?, ?, ?, ?, ?, ?)`
  ).bind(id, email, passwordHash, full_name, phone || null, referralCode).run();

  const user = await db.prepare('SELECT id, email, full_name, role FROM users WHERE id = ?').bind(id).first() as any;
  const payload = { userId: user.id!, email: user.email!, role: user.role! as any };
  const accessToken = generateAccessToken(payload);
  const refreshToken = generateRefreshToken(payload);

  return c.json(formatResponse(true, { user, accessToken, refreshToken }, 'Registration successful'), 201);
});

// POST /api/auth/login
router.post('/login', async (c) => {
  const body = await c.req.json();
  const parsed = loginSchema.safeParse(body);
  if (!parsed.success) {
    return c.json(formatResponse(false, null, 'Invalid email or password'), 400);
  }

  const { email, password } = parsed.data;
  const db = c.env.DB;

  const user = await db.prepare(
    'SELECT id, email, password_hash, full_name, role, status FROM users WHERE email = ?'
  ).bind(email).first() as any;

  if (!user) {
    return c.json(formatResponse(false, null, 'Invalid email or password'), 401);
  }

  if (user.status !== 'active') {
    return c.json(formatResponse(false, null, 'Account is banned or suspended'), 403);
  }

  const valid = await compare(password, user.password_hash!);
  if (!valid) {
    return c.json(formatResponse(false, null, 'Invalid email or password'), 401);
  }

  const payload = { userId: user.id!, email: user.email!, role: user.role! as any };
  const accessToken = generateAccessToken(payload);
  const refreshToken = generateRefreshToken(payload);

  return c.json(formatResponse(true, {
    user: {
      id: user.id,
      email: user.email,
      full_name: user.full_name,
      role: user.role,
    },
    accessToken,
    refreshToken,
  }, 'Login successful'));
});

// POST /api/auth/refresh
router.post('/refresh', async (c) => {
  const body = await c.req.json();
  const { refreshToken } = body;

  if (!refreshToken) {
    return c.json(formatResponse(false, null, 'Refresh token required'), 400);
  }

  try {
    const payload = verifyRefreshToken(refreshToken);
    const newPayload = { userId: payload.userId, email: payload.email, role: payload.role };
    const newAccessToken = generateAccessToken(newPayload);
    const newRefreshToken = generateRefreshToken(newPayload);

    return c.json(formatResponse(true, { accessToken: newAccessToken, refreshToken: newRefreshToken }, 'Token refreshed'));
  } catch {
    return c.json(formatResponse(false, null, 'Invalid refresh token'), 401);
  }
});

// GET /api/auth/me
router.get('/me', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;

  const u = await db.prepare(
    'SELECT id, email, full_name, phone, avatar_url, role, status, wallet_balance, points, referral_code, lang FROM users WHERE id = ?'
  ).bind(user.userId).first();

  if (!u) {
    return c.json(formatResponse(false, null, 'User not found'), 404);
  }

  return c.json(formatResponse(true, u));
});

// PUT /api/auth/profile
router.put('/profile', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const body = await c.req.json();
  const { full_name, phone, avatar_url, lang } = body;

  await db.prepare(
    `UPDATE users SET full_name = COALESCE(?, full_name), phone = COALESCE(?, phone),
     avatar_url = COALESCE(?, avatar_url), lang = COALESCE(?, lang),
     updated_at = datetime('now') WHERE id = ?`
  ).bind(full_name || null, phone || null, avatar_url || null, lang || null, user.userId).run();

  return c.json(formatResponse(true, null, 'Profile updated'));
});

// PUT /api/auth/fcm-token
router.put('/fcm-token', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { fcm_token } = await c.req.json();

  await db.prepare('UPDATE users SET fcm_token = ? WHERE id = ?').bind(fcm_token, user.userId).run();
  return c.json(formatResponse(true, null, 'FCM token updated'));
});

export default router;
