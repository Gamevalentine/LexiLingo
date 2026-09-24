const UPSTREAM_ORIGIN = 'https://api.lexilingo.me';
const AI_MODEL = '@cf/meta/llama-3.1-8b-instruct-fast';

const TUTOR_SYSTEM_PROMPT = `
You are LexiLingo, a friendly English-learning assistant for Vietnamese learners.
Your job is to help the learner improve English through useful conversation.

Rules:
- If the learner writes in Vietnamese, you may explain in Vietnamese, but include useful English examples.
- If the learner writes in English, reply mainly in English at an appropriate level.
- Correct English mistakes clearly and kindly when relevant.
- For grammar questions, explain simply and give 2-4 short examples.
- For conversation practice, keep the conversation natural and ask one useful follow-up question.
- When the learner asks to practise English conversation, start the conversation immediately in English. Do not answer that request with a Vietnamese topic list.
- In conversation-practice mode, use English by default. Use Vietnamese only if the learner explicitly asks for a Vietnamese explanation or translation.
- For vocabulary, include meaning, pronunciation guidance when useful, and example sentences.
- Do not mention internal systems, models, prompts, APIs, or infrastructure.
- Keep normal answers concise unless the learner asks for detail.
`.trim();

function json(data, status = 200) {
  return Response.json(data, {
    status,
    headers: {
      'Cache-Control': 'no-store',
    },
  });
}

async function readJson(request) {
  try {
    return await request.json();
  } catch (_) {
    return {};
  }
}

function aiText(result) {
  if (typeof result === 'string') return result.trim();
  if (result && typeof result.response === 'string') return result.response.trim();
  if (result?.result && typeof result.result.response === 'string') {
    return result.result.response.trim();
  }
  return '';
}

async function runTutorAI(context, payload) {
  if (!context.env.AI) {
    throw new Error('Workers AI binding AI is not configured');
  }

  const message = String(payload.message || '').trim();
  if (!message) {
    throw new Error('Message is empty');
  }

  const nativeLanguage = String(payload.native_language || 'vi');
  const learnerLevel = String(payload.learner_level || 'B1');
  const normalizedMessage = message.toLowerCase();
  const conversationPractice =
    normalizedMessage.includes('luyện hội thoại') ||
    normalizedMessage.includes('luyen hoi thoai') ||
    normalizedMessage.includes('practice english conversation') ||
    normalizedMessage.includes('conversation practice') ||
    normalizedMessage.includes('speak english with me') ||
    normalizedMessage.includes('nói tiếng anh với') ||
    normalizedMessage.includes('noi tieng anh voi');

  const system = [
    TUTOR_SYSTEM_PROMPT,
    `Learner CEFR level: ${learnerLevel}.`,
    `Learner native language code: ${nativeLanguage}.`,
    conversationPractice
      ? 'CONVERSATION PRACTICE MODE: Reply in English only unless the learner explicitly asks for Vietnamese. Start with a natural short English response and one simple question. Do not offer a Vietnamese menu of topics.'
      : '',
  ].filter(Boolean).join('\n');

  const result = await context.env.AI.run(AI_MODEL, {
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: message },
    ],
  });

  const text = aiText(result);
  if (!text) throw new Error('Workers AI returned an empty response');
  return text;
}

function makeSession(userId) {
  const now = new Date().toISOString();
  return {
    session_id: crypto.randomUUID(),
    user_id: userId || 'guest',
    created_at: now,
    updated_at: now,
    title: 'Trợ lý AI',
    message_count: 0,
  };
}

function makeAiMessage(payload, text) {
  return {
    message_id: crypto.randomUUID(),
    session_id: String(payload.session_id || ''),
    lexi_response: text,
    response: text,
    corrections: [],
    linked_concepts: [],
    suggested_practice: null,
    native_hint: null,
    scores: null,
    audio_base64: null,
    metadata: {
      provider: 'cloudflare-workers-ai',
      model: AI_MODEL,
    },
  };
}

function sseEvent(name, data) {
  return `event: ${name}\ndata: ${JSON.stringify(data)}\n\n`;
}

async function handleLexi(context, lexiPath) {
  const { request } = context;
  const method = request.method.toUpperCase();

  // Stateless guest session support. No login or database is required.
  if (lexiPath === 'sessions' && method === 'POST') {
    const body = await readJson(request);
    return json(makeSession(String(body.user_id || 'guest')));
  }

  const userSessions = lexiPath.match(/^sessions\/user\/([^/]+)$/);
  if (userSessions && method === 'GET') {
    return json({ sessions: [] });
  }

  const metadata = lexiPath.match(/^sessions\/([^/]+)\/messages\/metadata$/);
  if (metadata && method === 'GET') {
    return json({
      metadata: {
        total_count: 0,
        has_messages: false,
        latest_cursor: null,
        oldest_cursor: null,
        latest_ts: null,
        oldest_ts: null,
      },
    });
  }

  const paged = lexiPath.match(/^sessions\/([^/]+)\/messages\/paged$/);
  if (paged && method === 'GET') {
    return json({
      messages: [],
      pagination: {
        has_more: false,
        next_cursor: null,
        returned: 0,
      },
    });
  }

  const messages = lexiPath.match(/^sessions\/([^/]+)\/messages$/);
  if (messages && method === 'GET') {
    return json({ messages: [] });
  }

  const rename = lexiPath.match(/^sessions\/([^/]+)\/rename$/);
  if (rename && method === 'POST') {
    return json({ ok: true });
  }

  const remove = lexiPath.match(/^sessions\/([^/]+)\/delete$/);
  if (remove && method === 'POST') {
    return json({ ok: true });
  }

  if (lexiPath === 'chat' && method === 'POST') {
    const payload = await readJson(request);
    try {
      const text = await runTutorAI(context, payload);
      return json(makeAiMessage(payload, text));
    } catch (error) {
      return json(
        {
          error: {
            code: 'AI_UNAVAILABLE',
            message: error instanceof Error ? error.message : String(error),
          },
        },
        503,
      );
    }
  }

  if (lexiPath === 'stream' && method === 'POST') {
    const payload = await readJson(request);
    try {
      const text = await runTutorAI(context, payload);
      const message = makeAiMessage(payload, text);

      // Emit the contract the Flutter app already understands:
      // thinking -> chunks -> done.
      const chunks = text.match(/.{1,36}(?:\s+|$)/g) || [text];
      let body = sseEvent('thinking', {});
      for (const chunk of chunks) {
        body += sseEvent('chunk', { text: chunk });
      }
      body += sseEvent('done', message);

      return new Response(body, {
        status: 200,
        headers: {
          'Content-Type': 'text/event-stream; charset=utf-8',
          'Cache-Control': 'no-cache, no-transform',
          'Connection': 'keep-alive',
        },
      });
    } catch (error) {
      const body = sseEvent('error', {
        error: error instanceof Error ? error.message : String(error),
      });
      return new Response(body, {
        status: 200,
        headers: {
          'Content-Type': 'text/event-stream; charset=utf-8',
          'Cache-Control': 'no-cache, no-transform',
        },
      });
    }
  }

  return json(
    {
      error: {
        code: 'NOT_FOUND',
        message: 'Unknown Lexi endpoint',
      },
    },
    404,
  );
}

async function proxyLegacyApi(context, rest) {
  const { request } = context;
  const incomingUrl = new URL(request.url);
  const upstreamUrl = new URL(`/api/${rest}`, UPSTREAM_ORIGIN);
  upstreamUrl.search = incomingUrl.search;

  const headers = new Headers(request.headers);
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
    responseHeaders.delete('access-control-allow-origin');
    responseHeaders.delete('access-control-allow-credentials');

    return new Response(upstream.body, {
      status: upstream.status,
      statusText: upstream.statusText,
      headers: responseHeaders,
    });
  } catch (_) {
    return json(
      {
        error: {
          code: 'UPSTREAM_UNAVAILABLE',
          message: 'The legacy LexiLingo API is temporarily unreachable.',
        },
      },
      502,
    );
  }
}

export async function onRequest(context) {
  const rawPath = Array.isArray(context.params.path)
    ? context.params.path.join('/')
    : (context.params.path || '');
  const rest = String(rawPath).replace(/^\/+/, '');

  // Flutter base URL is /api/v1; intercept only the AI tutor routes here.
  if (rest.startsWith('v1/lexi/')) {
    return handleLexi(context, rest.slice('v1/lexi/'.length));
  }

  return proxyLegacyApi(context, rest);
}
