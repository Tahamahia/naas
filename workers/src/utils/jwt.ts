// Cloudflare Workers compatible JWT using jose library
import { SignJWT, jwtVerify } from 'jose';

const getSecretKey = () => {
  const secret = typeof JWT_SECRET !== 'undefined' ? JWT_SECRET : 'naas-secret-key';
  return new TextEncoder().encode(secret);
};

const getRefreshKey = () => {
  const secret = typeof REFRESH_SECRET !== 'undefined' ? REFRESH_SECRET : 'naas-refresh-secret';
  return new TextEncoder().encode(secret);
};

declare const JWT_SECRET: string;
declare const REFRESH_SECRET: string;

export interface JWTPayload {
  userId: string;
  email: string;
  role: 'super_admin' | 'admin' | 'teacher' | 'student';
}

export async function generateAccessToken(payload: JWTPayload): Promise<string> {
  return new SignJWT({ ...payload })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('24h')
    .sign(getSecretKey());
}

export async function generateRefreshToken(payload: JWTPayload): Promise<string> {
  return new SignJWT({ ...payload })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('30d')
    .sign(getRefreshKey());
}

export async function verifyAccessToken(token: string): Promise<JWTPayload> {
  const { payload } = await jwtVerify(token, getSecretKey());
  return payload as unknown as JWTPayload;
}

export async function verifyRefreshToken(token: string): Promise<JWTPayload> {
  const { payload } = await jwtVerify(token, getRefreshKey());
  return payload as unknown as JWTPayload;
}
