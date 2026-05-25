import { Hono } from 'hono';
import { formatResponse } from '../utils/helpers';
import { authenticate, requireRoles } from '../middleware/auth';
import type { Env } from '../index';

const router = new Hono<{ Bindings: Env }>();

// POST /api/upload/image — upload image to R2
router.post('/image', authenticate, async (c) => {
  const body = await c.req.parseBody();
  const file = body['file'] as File;
  if (!file) return c.json(formatResponse(false, null, 'File required'), 400);

  const key = `images/${crypto.randomUUID()}-${file.name}`;
  await c.env.ASSETS.put(key, await file.arrayBuffer(), {
    httpMetadata: { contentType: file.type },
  });

  const url = `${new URL(c.req.url).origin}/files/${key}`;
  return c.json(formatResponse(true, { url, key }, 'Image uploaded'), 201);
});

// POST /api/upload/video — upload video to R2 (for later Bunny processing)
router.post('/video', authenticate, requireRoles('teacher'), async (c) => {
  const body = await c.req.parseBody();
  const file = body['file'] as File;
  if (!file) return c.json(formatResponse(false, null, 'File required'), 400);

  const key = `videos/${crypto.randomUUID()}-${file.name}`;
  await c.env.ASSETS.put(key, await file.arrayBuffer(), {
    httpMetadata: { contentType: file.type },
  });

  const url = `${new URL(c.req.url).origin}/files/${key}`;
  return c.json(formatResponse(true, { url, key }, 'Video uploaded'), 201);
});

// GET /files/:key — serve files from R2
router.get('/files/:key', async (c) => {
  const { key } = c.req.param();
  const object = await c.env.ASSETS.get(key);
  if (!object) return c.json(formatResponse(false, null, 'File not found'), 404);

  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set('etag', object.httpEtag);

  return new Response(object.body, { headers });
});

export default router;
