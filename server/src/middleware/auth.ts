import { Context, Next } from 'koa';
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'kiwishare_super_secret_key_123_abc';

export interface DecodedToken {
  id: string;
  email: string;
}

async function authenticate(
  ctx: Context,
  next: Next,
  options: { allowExpired: boolean }
) {
  const authHeader = ctx.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    ctx.status = 401;
    ctx.body = { status: 'error', message: 'Access denied. Missing authorization token.' };
    return;
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, JWT_SECRET, {
      ignoreExpiration: options.allowExpired
    }) as DecodedToken;
    ctx.state.user = decoded; // Store identity in Koa state context
  } catch (err) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Invalid or expired authorization token.' };
    return;
  }

  await next();
}

export async function authenticateToken(ctx: Context, next: Next) {
  await authenticate(ctx, next, { allowExpired: false });
}

// Device cleanup must remain possible after the client discovers that its
// session has expired. This still verifies the JWT signature and is used only
// by the endpoint that removes an exact token owned by the signed user.
export async function authenticateTokenAllowExpired(ctx: Context, next: Next) {
  await authenticate(ctx, next, { allowExpired: true });
}
