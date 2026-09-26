export default {
  async fetch(request, env) {
    const response = await env.ASSETS.fetch(request);
    const headers = new Headers(response.headers);
    headers.set('x-kiwishare-edge', 'cloudflare-worker');
    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers,
    });
  },
};
