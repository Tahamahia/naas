import { Hono } from 'hono';
import { formatResponse, generateId } from '../utils/helpers';
import { authenticate, requireRoles } from '../middleware/auth';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

// POST /api/coupons — teacher/admin creates coupon
router.post('/', authenticate, requireRoles('teacher', 'admin', 'super_admin'), async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { code, discount_type, discount_value, min_purchase, max_uses, course_id, expires_at } = await c.req.json();

  const id = generateId();
  let teacherId = null;

  if (user.role === 'teacher') {
    const teacher = await db.prepare('SELECT id FROM teachers WHERE user_id = ?').bind(user.userId).first() as any;
    if (!teacher) return c.json(formatResponse(false, null, 'Teacher profile not found'), 404);
    teacherId = teacher.id;
  }

  await db.prepare(
    'INSERT INTO coupons (id, teacher_id, code, discount_type, discount_value, min_purchase, max_uses, course_id, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
  ).bind(id, teacherId, code.toUpperCase(), discount_type, discount_value, min_purchase || 0, max_uses || null, course_id || null, expires_at || null).run();

  return c.json(formatResponse(true, { id, code: code.toUpperCase() }, 'Coupon created'), 201);
});

// POST /api/coupons/validate — validate a coupon
router.post('/validate', authenticate, async (c) => {
  const db = c.env.DB;
  const { code, course_id, amount } = await c.req.json();

  const coupon = await db.prepare(
    'SELECT * FROM coupons WHERE code = ? AND is_active = 1 AND (expires_at IS NULL OR expires_at > datetime(\'now\')) AND (max_uses IS NULL OR current_uses < max_uses)'
  ).bind(code.toUpperCase()).first() as any;

  if (!coupon) return c.json(formatResponse(false, null, 'Invalid or expired coupon'), 404);

  if (coupon.course_id && coupon.course_id !== course_id) {
    return c.json(formatResponse(false, null, 'Coupon not valid for this course'), 400);
  }

  if (amount < (coupon.min_purchase || 0)) {
    return c.json(formatResponse(false, null, `Minimum purchase: ${coupon.min_purchase}`), 400);
  }

  const discount = coupon.discount_type === 'percent'
    ? amount * coupon.discount_value / 100
    : Math.min(coupon.discount_value, amount);

  return c.json(formatResponse(true, { discount, coupon_id: coupon.id, code: coupon.code }, 'Coupon valid'));
});

// POST /api/coupons/:id/apply — apply coupon at checkout
router.post('/:code/apply', authenticate, async (c) => {
  const db = c.env.DB;
  const { code } = c.req.param();
  const { course_id, amount } = await c.req.json();

  const coupon = await db.prepare(
    'SELECT * FROM coupons WHERE code = ? AND is_active = 1 AND (expires_at IS NULL OR expires_at > datetime(\'now\')) AND (max_uses IS NULL OR current_uses < max_uses)'
  ).bind(code.toUpperCase()).first() as any;

  if (!coupon) return c.json(formatResponse(false, null, 'Invalid coupon'), 400);

  const discount = coupon.discount_type === 'percent'
    ? amount * coupon.discount_value / 100
    : Math.min(coupon.discount_value, amount);

  await db.prepare('UPDATE coupons SET current_uses = current_uses + 1 WHERE id = ?').bind(coupon.id).run();

  return c.json(formatResponse(true, { discount, final_amount: amount - discount }, 'Coupon applied'));
});

// GET /api/coupons/my — teacher's coupons
router.get('/my', authenticate, requireRoles('teacher'), async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const teacher = await db.prepare('SELECT id FROM teachers WHERE user_id = ?').bind(user.userId).first() as any;
  if (!teacher) return c.json(formatResponse(false, null, 'Teacher not found'), 404);

  const coupons = await db.prepare('SELECT * FROM coupons WHERE teacher_id = ? ORDER BY created_at DESC').bind(teacher.id!).all();
  return c.json(formatResponse(true, coupons.results));
});

export default router;
