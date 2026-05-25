import { sign, verify } from 'jsonwebtoken';

export interface JWTPayload {
  userId: string;
  email: string;
  role: 'super_admin' | 'admin' | 'teacher' | 'student';
}

function getSecret(): string {
  return typeof JWT_SECRET !== 'undefined' ? JWT_SECRET : 'naas-secret-key-change-in-production';
}

declare const JWT_SECRET: string;
declare const REFRESH_SECRET: string;

export function generateAccessToken(payload: JWTPayload): string {
  return sign(payload, getSecret(), { expiresIn: '24h' });
}

export function generateRefreshToken(payload: JWTPayload): string {
  return sign(payload, getSecret() + '-refresh', { expiresIn: '30d' });
}

export function verifyAccessToken(token: string): JWTPayload {
  return verify(token, getSecret()) as JWTPayload;
}

export function verifyRefreshToken(token: string): JWTPayload {
  return verify(token, getSecret() + '-refresh') as JWTPayload;
}
