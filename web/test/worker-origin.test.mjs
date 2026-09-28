import assert from 'node:assert/strict';
import test from 'node:test';

import worker from '../../worker.js';

test('redirects www production traffic to the canonical apex origin', async () => {
  let assetFetches = 0;
  const env = {
    ASSETS: {
      fetch: async () => {
        assetFetches += 1;
        return new Response('unexpected');
      },
    },
  };

  const response = await worker.fetch(
    new Request('https://www.kiwishare.online/login?next=%2Fprofile'),
    env,
  );

  assert.equal(response.status, 308);
  assert.equal(
    response.headers.get('location'),
    'https://kiwishare.online/login?next=%2Fprofile',
  );
  assert.equal(assetFetches, 0);
});

test('serves the canonical origin through Cloudflare assets', async () => {
  const env = {
    ASSETS: {
      fetch: async (request) => {
        assert.equal(new URL(request.url).hostname, 'kiwishare.online');
        return new Response('ok', { status: 200 });
      },
    },
  };

  const response = await worker.fetch(
    new Request('https://kiwishare.online/login'),
    env,
  );

  assert.equal(response.status, 200);
  assert.equal(response.headers.get('x-kiwishare-edge'), 'cloudflare-worker');
});
