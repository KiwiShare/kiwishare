export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // Keep production on one canonical browser origin so Google Identity
    // Services only needs the apex domain registered as an authorized origin.
    if (url.hostname === 'www.kiwishare.online') {
      url.hostname = 'kiwishare.online';
      return Response.redirect(url.toString(), 308);
    }

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
