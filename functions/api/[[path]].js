const UPSTREAM_ORIGIN = 'https://api.lexilingo.me';

export async function onRequest(context) {
  const { request, params } = context;
  const rest = Array.isArray(params.path) ? params.path.join('/') : (params.path || '');
  const incomingUrl = new URL(request.url);
  const upstreamUrl = new URL(`/api/${rest}`, UPSTREAM_ORIGIN);
  upstreamUrl.search = incomingUrl.search;

  const headers = new Headers(request.headers);
  // These headers describe the browser -> Pages request and should not be
  // forwarded as-is to the upstream API.
  headers.delete('host');
  headers.delete('origin');
  headers.delete('referer');
  headers.delete('content-length');
  headers.delete('cf-connecting-ip');
  headers.delete('cf-ipcountry');
  headers.delete('cf-ray');
  headers.delete('cf-visitor');

  const init = {
    method: request.method,
    headers,
    redirect: 'manual',
  };

  if (request.method !== 'GET' && request.method !== 'HEAD') {
    init.body = await request.arrayBuffer();
  }

  try {
    const upstream = await fetch(upstreamUrl.toString(), init);
    const responseHeaders = new Headers(upstream.headers);

    // The browser talks to this Function on the same origin, so upstream CORS
    // headers are unnecessary and can otherwise be misleading.
    responseHeaders.delete('access-control-allow-origin');
    responseHeaders.delete('access-control-allow-credentials');

    return new Response(upstream.body, {
      status: upstream.status,
      statusText: upstream.statusText,
      headers: responseHeaders,
    });
  } catch (error) {
    return Response.json(
      {
        error: {
          code: 'UPSTREAM_UNAVAILABLE',
          message: 'The LexiLingo API is temporarily unreachable.',
        },
      },
      { status: 502 },
    );
  }
}
