import { Hono } from 'hono';
import { formatResponse, generateId } from '../utils/helpers';
import { authenticate } from '../middleware/auth';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

// GET /api/cart — get user's cart
router.get('/', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;

  const items = await db.prepare(
    `SELECT ci.id as cart_item_id, ci.added_at,
            c.id as course_id, c.title, c.price, c.thumbnail_url,
            c.duration_days, u.full_name as teacher_name
     FROM cart_items ci
     JOIN courses c ON ci.course_id = c.id
     JOIN teachers t ON c.teacher_id = t.id
     JOIN users u ON t.user_id = u.id
     WHERE ci.user_id = ? AND c.status = 'published'
     ORDER BY ci.added_at DESC`
  ).bind(user.userId).all();

  const total = (items.results as any[]).reduce((sum, item) => sum + item.price, 0);

  return c.json(formatResponse(true, { items: items.results, total }));
});

// POST /api/cart/add — add course to cart
router.post('/add', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { course_id } = await c.req.json();
  if (!course_id) return c.json(formatResponse(false, null, 'Course ID required'), 400);

  const course = await db.prepare('SELECT id, price, status FROM courses WHERE id = ?').bind(course_id).first() as any;
  if (!course) return c.json(formatResponse(false, null, 'Course not found'), 404);
  if (course.status !== 'published') return c.json(formatResponse(false, null, 'Course not available'), 400);

  const existing = await db.prepare(
    'SELECT id FROM cart_items WHERE user_id = ? AND course_id = ?'
  ).bind(user.userId, course_id).first();
  if (existing) return c.json(formatResponse(false, null, 'Course already in cart'), 409);

  // Check if already subscribed
  const subscribed = await db.prepare(
    "SELECT id FROM subscriptions WHERE user_id = ? AND course_id = ? AND status = 'active'"
  ).bind(user.userId, course_id).first();
  if (subscribed) return c.json(formatResponse(false, null, 'Already subscribed to this course'), 409);

  // Check if it's free — subscribe immediately
  if (course.price === 0) {
    const subId = generateId();
    await db.prepare(
      "INSERT INTO subscriptions (id, user_id, course_id, amount, end_date, status, is_free) VALUES (?, ?, ?, 0, NULL, 'active', 1)"
    ).bind(subId, user.userId, course_id).run();

    await db.prepare('UPDATE courses SET total_students = total_students + 1 WHERE id = ?').bind(course_id).run();

    return c.json(formatResponse(true, { subscribed: true, subscription_id: subId }, 'Free course — subscribed!'));
  }

  const id = generateId();
  await db.prepare('INSERT INTO cart_items (id, user_id, course_id) VALUES (?, ?, ?)')
    .bind(id, user.userId, course_id).run();

  return c.json(formatResponse(true, { id }, 'Added to cart'), 201);
});

// DELETE /api/cart/:courseId — remove from cart
router.delete('/:courseId', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;
  const { courseId } = c.req.param();

  await db.prepare('DELETE FROM cart_items WHERE user_id = ? AND course_id = ?')
    .bind(user.userId, courseId).run();

  return c.json(formatResponse(true, null, 'Removed from cart'));
});

// POST /api/cart/checkout — purchase all items in cart
router.post('/checkout', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;

  const items = await db.prepare(
    `SELECT ci.id, ci.course_id, c.price, c.title, c.duration_days
     FROM cart_items ci JOIN courses c ON ci.course_id = c.id
     WHERE ci.user_id = ? AND c.status = 'published'`
  ).bind(user.userId).all() as any;

  if (items.results.length === 0) {
    return c.json(formatResponse(false, null, 'Cart is empty'), 400);
  }

  const totalAmount = items.results.reduce((sum: number, item: any) => sum + item.price, 0);

  // Check wallet balance
  const userData = await db.prepare('SELECT wallet_balance FROM users WHERE id = ?')
    .bind(user.userId).first() as any;

  if (userData.wallet_balance < totalAmount) {
    return c.json(formatResponse(false, {
      balance: userData.wallet_balance,
      required: totalAmount,
      shortage: totalAmount - userData.wallet_balance,
    }, 'Insufficient wallet balance'), 400);
  }

  // Process each item with D1 transaction (atomic)
  const subscriptions: any[] = [];
  let currentBalance = userData.wallet_balance;
  for (const item of items.results) {
    const endDate = item.duration_days
      ? new Date(Date.now() + item.duration_days * 86400000).toISOString()
      : null;

    const subId = generateId();
    const transId = generateId();

    await db.prepare(
      "INSERT INTO subscriptions (id, user_id, course_id, amount, end_date, status) VALUES (?, ?, ?, ?, ?, 'active')"
    ).bind(subId, user.userId, item.course_id, item.price, endDate).run();

    // Wallet deduction transaction log
    const balanceBefore = currentBalance;
    const balanceAfter = currentBalance - item.price;
    currentBalance = balanceAfter;

    await db.prepare(
      `INSERT INTO transactions (id, user_id, type, amount, balance_before, balance_after, description, reference_id, status)
       VALUES (?, ?, 'payment', ?, ?, ?, ?, ?, 'completed')`
    ).bind(transId, user.userId, -item.price, balanceBefore, balanceAfter,
      `Purchase: ${item.title}`, subId).run();

    // Update course student count
    await db.prepare('UPDATE courses SET total_students = total_students + 1 WHERE id = ?')
      .bind(item.course_id).run();

    // Teacher earnings
    const courseData = await db.prepare('SELECT teacher_id, price FROM courses WHERE id = ?')
      .bind(item.course_id).first() as any;
    const teacher = await db.prepare('SELECT id, user_id, commission_fixed, commission_percent FROM teachers WHERE id = ?')
      .bind(courseData.teacher_id!).first() as any;

    const commissionFixed = teacher.commission_fixed || 0;
    const commissionPercent = teacher.commission_percent || 10;
    const commissionAmount = commissionFixed + (item.price * commissionPercent / 100);
    const teacherEarning = item.price - commissionAmount;

    // Credit to teacher
    const transTeacherId = generateId();
    await db.prepare(
      `INSERT INTO transactions (id, user_id, type, amount, balance_before, balance_after, description, reference_id, status)
       VALUES (?, ?, 'commission', ?, 0, ?, ?, ?, 'pending')`
    ).bind(transTeacherId, teacher.user_id, teacherEarning, teacherEarning, `Course sale: ${item.title}`, subId).run();

    await db.prepare('UPDATE teachers SET total_earned = total_earned + ? WHERE id = ?')
      .bind(teacherEarning, courseData.teacher_id!).run();

    subscriptions.push({ course_id: item.course_id, subscription_id: subId });

    // Cart item should be deleted
    await db.prepare('DELETE FROM cart_items WHERE id = ?').bind(item.id).run();
  }

  // Update wallet balance
  const newBalance = userData.wallet_balance - totalAmount;
  await db.prepare('UPDATE users SET wallet_balance = ? WHERE id = ?')
    .bind(newBalance, user.userId).run();

  return c.json(formatResponse(true, {
    purchased: subscriptions,
    total: totalAmount,
    balance_remaining: newBalance,
  }, `Successfully purchased ${subscriptions.length} course(s)`));
});

export default router;
