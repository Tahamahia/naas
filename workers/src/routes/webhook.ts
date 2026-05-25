import { Hono } from 'hono';
import { formatResponse } from '../utils/helpers';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

// POST /api/webhook/bunny — Bunny.net video processing webhook
router.post('/bunny', async (c) => {
  const body = await c.req.json();
  const db = c.env.DB;

  // Bunny Stream sends: { VideoGuid, Status, Length, ThumbnailUrl }
  const { VideoGuid, Status, Length } = body;

  if (VideoGuid && Status === 3) {
    // Video is ready
    await db.prepare(
      "UPDATE lessons SET video_status = 'ready', video_duration = ? WHERE video_url LIKE ?"
    ).bind(Length || 0, `%${VideoGuid}%`).run();
  } else if (VideoGuid && Status === 4) {
    // Video failed
    await db.prepare(
      "UPDATE lessons SET video_status = 'failed' WHERE video_url LIKE ?"
    ).bind(`%${VideoGuid}%`).run();
  }

  return c.json(formatResponse(true, null, 'Webhook received'));
});

// POST /api/webhook/payment — payment gateway webhook (future)
router.post('/payment', async (c) => {
  const body = await c.req.json();
  const db = c.env.DB;

  const { transaction_id, status, amount, reference } = body;

  if (transaction_id && status === 'completed') {
    const tx = await db.prepare('SELECT * FROM transactions WHERE id = ?').bind(transaction_id).first() as any;
    if (tx && tx.status === 'pending') {
      await db.prepare("UPDATE transactions SET status = 'completed' WHERE id = ?").bind(transaction_id).run();
      await db.prepare('UPDATE users SET wallet_balance = wallet_balance + ? WHERE id = ?')
        .bind(Math.abs(tx.amount), tx.user_id).run();
    }
  }

  return c.json(formatResponse(true, null, 'Webhook received'));
});

export default router;
