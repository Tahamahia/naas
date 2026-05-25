import { Context, Next } from 'hono';
import { verifyAccessToken, JWTPayload } from '../utils/jwt';
import { formatResponse } from '../utils/helpers';

declare module 'hono' {
  interface ContextVariableMap {
    user: JWTPayload;
  }
}

export async function authenticate(c: Context, next: Next) {
  const authHeader = c.req.header('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return c.json(formatResponse(false, null, 'Unauthorized: No token provided'), 401);
  }

  const token = authHeader.split(' ')[1];
  try {
    const payload = await verifyAccessToken(token);
    c.set('user', payload);
    await next();
  } catch (err) {
    return c.json(formatResponse(false, null, 'Unauthorized: Invalid token'), 401);
  }
}

export function requireRoles(...roles: string[]) {
  return async (c: Context, next: Next) => {
    const user = c.get('user');
    if (!user) return c.json(formatResponse(false, null, 'Unauthorized'), 401);
    if (!roles.includes(user.role)) {
      return c.json(formatResponse(false, null, 'Forbidden: Insufficient permissions'), 403);
    }
    await next();
  };
}
