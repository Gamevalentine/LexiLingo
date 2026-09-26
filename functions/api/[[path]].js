import {
  authenticateAdminRequest,
  authenticateGoogleAdmin,
  authErrorResponse,
} from "../_shared/admin_auth.js";
import {
  handleAdminContent,
  handlePublicContent,
  loadTutorConfig,
} from "../_shared/content_store.js";

const AI_MODEL = "@cf/meta/llama-3.1-8b-instruct-fast";

function json(data, status = 200) {
  return Response.json(data, {
    status,
    headers: { "Cache-Control": "no-store" },
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
  if (typeof result === "string") return result.trim();
  if (result && typeof result.response === "string") return result.response.trim();
  if (result && result.result && typeof result.result.response === "string") {
    return result.result.response.trim();
  }
  return "";
}

async function runTutorAI(context, payload) {
  if (!context.env.AI) throw new Error("Workers AI binding AI is not configured");

  const message = String(payload.message || "").trim();
  if (!message) throw new Error("Message is empty");

  const config = await loadTutorConfig(context);
  const nativeLanguage = String(payload.native_language || "vi");
  const learnerLevel = String(payload.learner_level || "B1");
  const normalizedMessage = message.toLowerCase();
  const conversationPractice =
    normalizedMessage.includes("luyện hội thoại") ||
    normalizedMessage.includes("luyen hoi thoai") ||
    normalizedMessage.includes("practice english conversation") ||
    normalizedMessage.includes("conversation practice") ||
    normalizedMessage.includes("speak english with me") ||
    normalizedMessage.includes("nói tiếng anh với") ||
    normalizedMessage.includes("noi tieng anh voi");

  const system = [
    String(config.system_prompt || ""),
    "Learner CEFR level: " + learnerLevel + ".",
    "Learner native language code: " + nativeLanguage + ".",
    conversationPractice
      ? "CONVERSATION PRACTICE MODE: Reply in English only unless the learner explicitly asks for Vietnamese. Start with a natural short English response and one simple question. Do not offer a Vietnamese menu of topics."
      : "",
  ].filter(Boolean).join("\n");

  const rawHistory = Array.isArray(payload.conversation_history) ? payload.conversation_history : [];
  const historyLimit = Math.max(0, Math.min(30, Number(config.chat_memory_turns || 12)));
  const history = rawHistory
    .slice(-historyLimit)
    .map((item) => ({
      role: item && item.role === "assistant" ? "assistant" : "user",
      content: String((item && item.content) || "").trim().slice(0, 1800),
    }))
    .filter((item) => item.content.length > 0);

  const model =
    typeof config.model_name === "string" && config.model_name.startsWith("@cf/")
      ? config.model_name
      : AI_MODEL;

  const result = await context.env.AI.run(model, {
    messages: [
      { role: "system", content: system },
      ...history,
      { role: "user", content: message },
    ],
    temperature: Number(config.temperature || 0.7),
    max_tokens: Number(config.max_tokens || 1200),
    top_p: Number(config.top_p || 0.9),
  });

  const text = aiText(result);
  if (!text) throw new Error("Workers AI returned an empty response");
  return { text, model };
}

function makeSession(userId) {
  const now = new Date().toISOString();
  return {
    session_id: crypto.randomUUID(),
    user_id: userId || "guest",
    created_at: now,
    updated_at: now,
    title: "Trợ lý AI",
    message_count: 0,
  };
}

function makeAiMessage(payload, text, model) {
  return {
    message_id: crypto.randomUUID(),
    session_id: String(payload.session_id || ""),
    lexi_response: text,
    response: text,
    corrections: [],
    linked_concepts: [],
    suggested_practice: null,
    native_hint: null,
    scores: null,
    audio_base64: null,
    metadata: { provider: "cloudflare-workers-ai", model: model || AI_MODEL },
  };
}

function sseEvent(name, data) {
  return "event: " + name + "\ndata: " + JSON.stringify(data) + "\n\n";
}

async function handleLexi(context, lexiPath) {
  const request = context.request;
  const method = request.method.toUpperCase();

  if (lexiPath === "sessions" && method === "POST") {
    const body = await readJson(request);
    return json(makeSession(String(body.user_id || "guest")));
  }

  if (/^sessions\/user\/[^/]+$/.test(lexiPath) && method === "GET") return json({ sessions: [] });

  if (/^sessions\/[^/]+\/messages\/metadata$/.test(lexiPath) && method === "GET") {
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

  if (/^sessions\/[^/]+\/messages\/paged$/.test(lexiPath) && method === "GET") {
    return json({ messages: [], pagination: { has_more: false, next_cursor: null, returned: 0 } });
  }

  if (/^sessions\/[^/]+\/messages$/.test(lexiPath) && method === "GET") return json({ messages: [] });
  if (/^sessions\/[^/]+\/rename$/.test(lexiPath) && method === "POST") return json({ ok: true });
  if (/^sessions\/[^/]+\/delete$/.test(lexiPath) && method === "POST") return json({ ok: true });

  if (lexiPath === "chat" && method === "POST") {
    const payload = await readJson(request);
    try {
      const answer = await runTutorAI(context, payload);
      return json(makeAiMessage(payload, answer.text, answer.model));
    } catch (error) {
      return json(
        { error: { code: "AI_UNAVAILABLE", message: error instanceof Error ? error.message : String(error) } },
        503,
      );
    }
  }

  if (lexiPath === "stream" && method === "POST") {
    const payload = await readJson(request);
    try {
      const answer = await runTutorAI(context, payload);
      const message = makeAiMessage(payload, answer.text, answer.model);
      const chunks = answer.text.match(/.{1,36}(?:\s+|$)/g) || [answer.text];
      let body = sseEvent("thinking", {});
      for (const chunk of chunks) body += sseEvent("chunk", { text: chunk });
      body += sseEvent("done", message);
      return new Response(body, {
        status: 200,
        headers: {
          "Content-Type": "text/event-stream; charset=utf-8",
          "Cache-Control": "no-cache, no-transform",
          Connection: "keep-alive",
        },
      });
    } catch (error) {
      return new Response(
        sseEvent("error", { error: error instanceof Error ? error.message : String(error) }),
        {
          status: 200,
          headers: {
            "Content-Type": "text/event-stream; charset=utf-8",
            "Cache-Control": "no-cache, no-transform",
          },
        },
      );
    }
  }

  return json({ error: { code: "NOT_FOUND", message: "Unknown Lexi endpoint" } }, 404);
}

async function handleAuth(context, rest) {
  const method = context.request.method.toUpperCase();

  if (rest === "v1/auth/google" && method === "POST") {
    const body = await readJson(context.request);
    try {
      const admin = await authenticateGoogleAdmin(context, body.id_token);
      return json({
        access_token: String(body.id_token || ""),
        refresh_token: "",
        token_type: "bearer",
        user_id: admin.profile.id,
        username: admin.profile.username,
        email: admin.profile.email,
        role: admin.role,
      });
    } catch (error) {
      return authErrorResponse(error);
    }
  }

  if (rest === "v1/auth/me" && method === "GET") {
    try {
      const admin = await authenticateAdminRequest(context);
      return json(admin.profile);
    } catch (error) {
      return authErrorResponse(error);
    }
  }

  return null;
}

export async function onRequest(context) {
  const rawPath = Array.isArray(context.params.path)
    ? context.params.path.join("/")
    : context.params.path || "";
  const rest = String(rawPath).replace(/^\/+/, "");

  const auth = await handleAuth(context, rest);
  if (auth) return auth;

  if (rest.startsWith("v1/admin/")) {
    try {
      await authenticateAdminRequest(context);
    } catch (error) {
      return authErrorResponse(error);
    }
    return handleAdminContent(context, rest.slice("v1/admin/".length));
  }

  if (rest.startsWith("v1/lexi/")) {
    return handleLexi(context, rest.slice("v1/lexi/".length));
  }

  const publicContent = await handlePublicContent(context, rest);
  if (publicContent) return publicContent;

  return json(
    {
      error: {
        code: "LEGACY_API_DISABLED",
        message: "This guest web feature is not available in the Cloudflare-only build yet.",
      },
    },
    410,
  );
}
