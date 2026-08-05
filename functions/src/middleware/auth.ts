import { Context, Next } from 'koa';
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'kiwishare_super_secret_key_123_abc';

export interface DecodedToken {
  id: string;
  email: string;
}

export async function authenticateToken(ctx: Context, next: Next) {
  const authHeader = ctx.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    ctx.status = 401;
    ctx.body = { status: 'error', message: 'Access denied. Missing authorization token.' };
    return;
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, JWT_SECRET) as DecodedToken;
    ctx.state.user = decoded; // Store identity in Koa state context
    await next();
  } catch (err) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Invalid or expired authorization token.' };
  }
}
