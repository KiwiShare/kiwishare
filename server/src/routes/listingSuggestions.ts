import Router from 'koa-router';
import { authenticateToken } from '../middleware/auth';
import {
  generateListingSuggestion,
  InvalidListingSuggestionError,
  LISTING_CATEGORIES,
  LISTING_CONDITIONS,
  ListingCategory,
  ListingCondition,
  ListingSuggestionInput,
  ListingSuggestionUnavailableError
} from '../services/listingSuggestion';

const router = new Router();
const RATE_LIMIT_WINDOW_MS = 60_000;
const RATE_LIMIT_REQUESTS = 5;
const rateLimits = new Map<string, number[]>();

class SuggestionInputError extends Error {}

function optionalText(
  value: unknown,
  fieldName: string,
  maximumLength: number
): string | undefined {
  if (value == null || value === '') return undefined;
  if (typeof value !== 'string') {
    throw new SuggestionInputError(`${fieldName} must be text.`);
  }
  const text = value.trim();
  if (text.length > maximumLength) {
    throw new SuggestionInputError(
      `${fieldName} must be ${maximumLength} characters or fewer.`
    );
  }
  return text || undefined;
}

function parseInput(body: unknown): ListingSuggestionInput {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    throw new SuggestionInputError('Listing details are required.');
  }
  const record = body as Record<string, unknown>;
  const title = optionalText(record.title, 'Title', 120);
  const description = optionalText(record.description, 'Description', 1000);
  const category = optionalText(record.category, 'Category', 50);
  const condition = optionalText(record.condition, 'Condition', 20);
  const location = optionalText(record.location, 'Location', 120);

  if (category && !LISTING_CATEGORIES.includes(category as ListingCategory)) {
    throw new SuggestionInputError('Category is not allowed.');
  }
  if (condition && !LISTING_CONDITIONS.includes(condition as ListingCondition)) {
    throw new SuggestionInputError('Condition is not allowed.');
  }
  if (!title && !description && !category && !condition) {
    throw new SuggestionInputError(
      'Add a title, description, category, or condition before asking for help.'
    );
  }

  return {
    ...(title ? { title } : {}),
    ...(description ? { description } : {}),
    ...(category ? { category: category as ListingCategory } : {}),
    ...(condition ? { condition: condition as ListingCondition } : {}),
    ...(location ? { location } : {})
  };
}

function consumeRateLimit(userId: string, now = Date.now()): boolean {
  if (rateLimits.size >= 1_000) {
    for (const [storedUserId, timestamps] of rateLimits) {
      if (
        timestamps.every(
          (timestamp) => now - timestamp >= RATE_LIMIT_WINDOW_MS
        )
      ) {
        rateLimits.delete(storedUserId);
      }
    }
  }
  const active = (rateLimits.get(userId) ?? []).filter(
    (timestamp) => now - timestamp < RATE_LIMIT_WINDOW_MS
  );
  if (active.length >= RATE_LIMIT_REQUESTS) {
    rateLimits.set(userId, active);
    return false;
  }
  active.push(now);
  rateLimits.set(userId, active);
  return true;
}

export function resetListingSuggestionRateLimitsForTests() {
  rateLimits.clear();
}

router.post('/listing-suggestions', authenticateToken, async (ctx) => {
  let input: ListingSuggestionInput;
  try {
    input = parseInput(ctx.request.body);
  } catch (error) {
    if (!(error instanceof SuggestionInputError)) throw error;
    ctx.status = 400;
    ctx.body = { status: 'error', message: error.message };
    return;
  }

  const userId = String(ctx.state.user.id);
  if (!consumeRateLimit(userId)) {
    ctx.set('Retry-After', '60');
    ctx.status = 429;
    ctx.body = {
      status: 'error',
      message: 'Too many AI suggestion requests. Please wait a minute.'
    };
    return;
  }

  try {
    const suggestion = await generateListingSuggestion(input);
    ctx.status = 200;
    ctx.body = { status: 'success', suggestion };
  } catch (error) {
    if (error instanceof InvalidListingSuggestionError) {
      ctx.status = 502;
      ctx.body = {
        status: 'error',
        message: 'The AI returned an invalid suggestion. Please try again.'
      };
      return;
    }
    if (error instanceof ListingSuggestionUnavailableError) {
      ctx.status = 503;
      ctx.body = {
        status: 'error',
        message: 'AI suggestions are temporarily unavailable. Please try again later.'
      };
      return;
    }
    throw error;
  }
});

export default router;
