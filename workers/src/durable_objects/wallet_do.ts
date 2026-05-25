// Durable Object for atomic wallet transactions
import type { Env } from '../index';

export class WalletDO {
  private state: DurableObjectState;
  private env: Env;

  constructor(state: DurableObjectState, env: Env) {
    this.state = state;
    this.env = env;
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const userId = url.searchParams.get('userId')!;

    if (request.method === 'GET') {
      const balance = (await this.state.storage.get<number>(`balance:${userId}`)) || 0;
      return new Response(JSON.stringify({ balance }));
    }

    if (request.method === 'POST') {
      const body: { action?: string; amount?: number; description?: string } = await request.json();
      const { action, amount, description } = body;
      if (!action || !amount) return new Response(JSON.stringify({ error: 'Missing action or amount' }), { status: 400 });

      const balanceKey = `balance:${userId}`;
      const currentBalance = (await this.state.storage.get<number>(balanceKey)) || 0;

      if (action === 'debit' && currentBalance < amount) {
        return new Response(JSON.stringify({ error: 'Insufficient balance' }), { status: 400 });
      }

      const newBalance = action === 'credit' ? currentBalance + amount : currentBalance - amount;
      await this.state.storage.put(balanceKey, newBalance);

      // Log the operation in DB via environment binding
      const db = this.env.DB;
      const txId = crypto.randomUUID();
      await db.prepare(
        'INSERT INTO transactions (id, user_id, type, amount, balance_before, balance_after, description, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
      ).bind(txId, userId, action === 'credit' ? 'deposit_gateway' : 'payment',
        action === 'credit' ? amount : -amount, currentBalance, newBalance,
        description || 'Wallet operation', 'completed').run();

      return new Response(JSON.stringify({ success: true, balance: newBalance }));
    }

    return new Response('Method not allowed', { status: 405 });
  }
}
