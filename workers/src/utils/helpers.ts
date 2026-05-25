export function generateId(): string {
  const chars = 'abcdef0123456789';
  let result = '';
  const array = new Uint8Array(16);
  crypto.getRandomValues(array);
  for (let i = 0; i < 16; i++) {
    result += chars[array[i] % 16];
  }
  return result;
}

export function generateCode(length: number = 8): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = '';
  const array = new Uint8Array(length);
  crypto.getRandomValues(array);
  for (let i = 0; i < length; i++) {
    result += chars[array[i] % chars.length];
  }
  return result;
}

export function generateOTP(): string {
  const array = new Uint8Array(6);
  crypto.getRandomValues(array);
  return Array.from(array).map(n => n % 10).join('');
}

export function calculateExpiry(days: number): string {
  const date = new Date();
  date.setDate(date.getDate() + days);
  return date.toISOString();
}

export function now(): string {
  return new Date().toISOString();
}

export function formatResponse(success: boolean, data?: any, message?: string) {
  return {
    success,
    data: data || null,
    message: message || (success ? 'Success' : 'Error'),
  };
}
