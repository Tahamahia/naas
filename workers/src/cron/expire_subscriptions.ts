// Cron job: runs daily to expire subscriptions
// Scheduled via wrangler.toml: [triggers] crons = ["0 0 * * *"]

import type { Env } from '../index';

export async function expireSubscriptions(env: Env): Promise<void> {
  const db = env.DB;

  // Expire subscriptions past end_date
  const result = await db.prepare(
    "UPDATE subscriptions SET status = 'expired' WHERE status = 'active' AND end_date IS NOT NULL AND end_date < datetime('now')"
  ).run();

  console.log(`Expired ${result.meta.changes || 0} subscriptions`);

  // Send notifications for expired subscriptions
  const expired = await db.prepare(
    `SELECT s.id, s.user_id, c.title FROM subscriptions s
     JOIN courses c ON s.course_id = c.id
     WHERE s.status = 'expired' AND s.end_date >= datetime('now', '-1 day') AND s.end_date < datetime('now')`
  ).all() as any;

  for (const sub of expired.results) {
    const notifId = crypto.randomUUID();
    await db.prepare(
      "INSERT INTO notifications (id, user_id, title, body, type, reference_id) VALUES (?, ?, ?, ?, 'reminder', ?)"
    ).bind(notifId, sub.user_id!, 'انتهى اشتراكك', `انتهت مدة اشتراكك في "${sub.title!}". جدد الآن`, sub.id!).run();
  }
}
