import assert from 'node:assert/strict';
import { afterEach, beforeEach, test } from 'node:test';

import { authApi, watchlistApi } from '../src/api/client.ts';
import {
  formatPublicTrustScore,
  parseNonNegativeSafeInteger,
} from '../src/utils/trustScore.ts';

const originalFetch = globalThis.fetch;
const originalLocalStorage = globalThis.localStorage;
let storedValues;

beforeEach(() => {
  storedValues = new Map();
  globalThis.localStorage = {
    getItem: (key) => storedValues.get(key) ?? null,
    setItem: (key, value) => storedValues.set(key, String(value)),
    removeItem: (key) => storedValues.delete(key),
  };
});

afterEach(() => {
  globalThis.fetch = originalFetch;
  globalThis.localStorage = originalLocalStorage;
});

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

test('login sends Web identity and returns the server-owned session', async () => {
  globalThis.fetch = async (url, options) => {
    assert.equal(url, '/api/auth/login');
    assert.equal(options.method, 'POST');
    assert.equal(options.headers.get('x-client-platform'), 'web');
    assert.equal(options.headers.has('Authorization'), false);
    assert.deepEqual(JSON.parse(options.body), {
      email: 'buyer@example.com',
      password: 'example-password',
      platform: 'web',
    });
    return jsonResponse({ status: 'success', token: 'server-token', user: { id: 'buyer' } });
  };

  const session = await authApi.login({ email: 'buyer@example.com', password: 'example-password' });
  assert.equal(session.token, 'server-token');
  assert.equal(session.user.id, 'buyer');
});

test('failed login rejects instead of returning a successful session', async () => {
  globalThis.fetch = async () => jsonResponse({ message: 'Invalid credentials' }, 401);

  await assert.rejects(
    authApi.login({ email: 'buyer@example.com', password: 'wrong-password' }),
    /Invalid credentials/,
  );
});

test('Watchlist transport and HTTP failures reject instead of becoming empty data', async () => {
  storedValues.set('kiwishare_token', 'current-user-token');
  globalThis.fetch = async (url, options) => {
    assert.equal(url, '/api/watchlist/ids');
    assert.equal(options.headers.get('Authorization'), 'Bearer current-user-token');
    throw new TypeError('Network unavailable');
  };
  await assert.rejects(watchlistApi.getWatchlistIds(), /Network unavailable/);

  globalThis.fetch = async () => jsonResponse({ message: 'Watchlist unavailable' }, 503);
  await assert.rejects(watchlistApi.getWatchlist(), /Watchlist unavailable/);
  await assert.rejects(watchlistApi.addToWatchlist('item-1'), /Watchlist unavailable/);
});

test('Watchlist accepts a genuinely empty page and preserves pagination metadata', async () => {
  globalThis.fetch = async (url) => {
    assert.equal(url, '/api/watchlist?limit=50&cursor=next-page');
    return jsonResponse({
      status: 'success',
      count: 0,
      items: [],
      pagination: { hasMore: false, nextCursor: null },
    });
  };

  const page = await watchlistApi.getWatchlist('next-page');
  assert.deepEqual(page.items, []);
  assert.deepEqual(page.pagination, { hasMore: false, nextCursor: null });
});

test('public Trust Score shows exact values through 200 and 200+ above it', () => {
  for (const score of [0, 100, 195, 200]) {
    assert.equal(formatPublicTrustScore(score), String(score));
  }
  for (const score of [201, 205, 235]) {
    assert.equal(formatPublicTrustScore(score), '200+');
  }
});

test('administrator precise-score input keeps safe values above 200 exact', () => {
  for (const score of [0, 200, 205, 235, 1000]) {
    assert.equal(parseNonNegativeSafeInteger(String(score)), score);
  }
  for (const invalid of ['', ' ', '-1', '12.5', '235abc', '1e3', '9007199254740992']) {
    assert.equal(parseNonNegativeSafeInteger(invalid), null);
  }
});
