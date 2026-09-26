const BUILT_IN_SUPER_ADMINS = new Set([
  "anhtsizoo00@gmail.com",
  "trainingbot.ai2@gmail.com",
]);

function splitEmails(value) {
  return String(value || "")
    .split(",")
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);
}

function authError(message, status = 401) {
  const error = new Error(message);
  error.status = status;
  return error;
}

async function verifyGoogleIdToken(context, idToken) {
  const token = String(idToken || "").trim();
  if (!token) throw authError("Missing Google ID token", 401);

  const expectedAudience = String(context.env.GOOGLE_CLIENT_ID || "").trim();
  if (!expectedAudience) {
    throw authError("Google Admin authentication is not configured", 503);
  }

  const url = new URL("https://oauth2.googleapis.com/tokeninfo");
  url.searchParams.set("id_token", token);

  let response;
  try {
    response = await fetch(url.toString(), { headers: { Accept: "application/json" } });
  } catch (_) {
    throw authError("Google authentication service is unavailable", 503);
  }

  if (!response.ok) throw authError("Google session is invalid or expired", 401);

  const info = await response.json();
  if (String(info.aud || "") !== expectedAudience) {
    throw authError("Google token audience is invalid", 401);
  }

  const verified = info.email_verified === true || String(info.email_verified) === "true";
  if (!verified || !info.email) throw authError("Google email is not verified", 403);

  const exp = Number(info.exp || 0);
  if (exp && exp * 1000 <= Date.now()) throw authError("Google session has expired", 401);

  return info;
}

function roleForEmail(context, email) {
  const normalized = String(email || "").trim().toLowerCase();
  const superAdmins = splitEmails(context.env.SUPER_ADMIN_EMAILS);
  const admins = splitEmails(context.env.ADMIN_EMAILS);

  if (BUILT_IN_SUPER_ADMINS.has(normalized)) return "super_admin";
  if (superAdmins.includes(normalized)) return "super_admin";
  if (admins.includes(normalized)) return "admin";
  return null;
}

function toProfile(info, role) {
  const email = String(info.email || "");
  return {
    id: String(info.sub || email),
    email,
    username: email.includes("@") ? email.split("@")[0] : email,
    display_name: info.name || email,
    avatar_url: info.picture || null,
    is_active: true,
    is_verified: true,
    role,
    role_slug: role,
    is_admin: role === "admin" || role === "super_admin",
    is_super_admin: role === "super_admin",
  };
}

export async function authenticateGoogleAdmin(context, idToken) {
  const info = await verifyGoogleIdToken(context, idToken);
  const role = roleForEmail(context, info.email);
  if (!role) throw authError("This Google account is not allowed to access Admin", 403);
  return { info, role, profile: toProfile(info, role) };
}

export async function authenticateAdminRequest(context) {
  const header = context.request.headers.get("authorization") || "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) throw authError("Admin authentication required", 401);
  return authenticateGoogleAdmin(context, match[1]);
}

export function authErrorResponse(error) {
  const status = Number(error && error.status) || 401;
  return Response.json(
    {
      error: {
        code: status === 403 ? "AUTH_FORBIDDEN" : "AUTH_INVALID",
        message: error instanceof Error ? error.message : String(error),
      },
    },
    { status, headers: { "Cache-Control": "no-store" } },
  );
}
