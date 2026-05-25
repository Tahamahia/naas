import { Hono } from 'hono';
import { formatResponse } from '../utils/helpers';
import { authenticate, requireRoles } from '../middleware/auth';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

// GET /api/gamification/badges — all badges
router.get('/badges', async (c) => {
  const db = c.env.DB;
  const badges = await db.prepare('SELECT * FROM badges ORDER BY points ASC').all();
  return c.json(formatResponse(true, badges.results));
});

// GET /api/gamification/my-badges — user's earned badges
router.get('/my-badges', authenticate, async (c) => {
  const user = c.get('user');
  const db = c.env.DB;

  const badges = await db.prepare(
    `SELECT b.*, ub.earned_at FROM badges b
     JOIN user_badges ub ON b.id = ub.badge_id
     WHERE ub.user_id = ? ORDER BY ub.earned_at DESC`
  ).bind(user.userId).all();

  return c.json(formatResponse(true, badges.results));
});

// GET /api/gamification/leaderboard — top students by points
router.get('/leaderboard', async (c) => {
  const db = c.env.DB;
  const { period = 'all' } = c.req.query();

  let query = `SELECT id, full_name, avatar_url, points,
    RANK() OVER (ORDER BY points DESC) as rank
    FROM users WHERE points > 0 ORDER BY points DESC LIMIT 50`;

  if (period === 'monthly') {
    query = `SELECT u.id, u.full_name, u.avatar_url,
      SUM(CASE WHEN strftime('%Y-%m', t.created_at) = strftime('%Y-%m', 'now') THEN t.points ELSE 0 END) as points
      FROM users u LEFT JOIN transactions t ON u.id = t.user_id
      GROUP BY u.id ORDER BY points DESC LIMIT 50`;
  }

  const leaderboard = await db.prepare(query).all();
  return c.json(formatResponse(true, leaderboard.results));
});

// POST /api/gamification/award-points — award points (internal)
router.post('/award-points', authenticate, requireRoles('admin', 'super_admin'), async (c) => {
  const db = c.env.DB;
  const { user_id, points, reason } = await c.req.json();

  await db.prepare('UPDATE users SET points = points + ? WHERE id = ?').bind(points, user_id).run();

  // Check badge criteria (simplified — check common badges)
  const user = await db.prepare('SELECT points FROM users WHERE id = ?').bind(user_id).first() as any;
  const badges = await db.prepare('SELECT * FROM badges ORDER BY points ASC').all() as any;

  for (const badge of badges.results) {
    if (user.points! >= badge.points!) {
      const existing = await db.prepare(
        'SELECT id FROM user_badges WHERE user_id = ? AND badge_id = ?'
      ).bind(user_id, badge.id!).first();
      if (!existing) {
        await db.prepare(
          'INSERT INTO user_badges (id, user_id, badge_id) VALUES (?, ?, ?)'
        ).bind(crypto.randomUUID(), user_id, badge.id!).run();
      }
    }
  }

  return c.json(formatResponse(true, { points_awarded: points, total: user.points }, 'Points awarded'));
});

export default router;
