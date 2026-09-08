import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const googleClientId = Deno.env.get("GEMINI_GOOGLE_CLIENT_ID");
const googleClientSecret = Deno.env.get("GEMINI_GOOGLE_CLIENT_SECRET");
const callbackUrl = Deno.env.get("GEMINI_OAUTH_CALLBACK_URL");
// Prefer a dedicated encryption secret. The service-role key is a server-only fallback
// so legacy deployments do not become permanently unable to save a user-owned key.
const encryptionKey = Deno.env.get("AI_TOKEN_ENCRYPTION_KEY") ?? serviceKey;
const defaultModel = Deno.env.get("GEMINI_MODEL") || "gemini-3.8-flash";
const admin = serviceKey ? createClient(supabaseUrl, serviceKey) : null;
const STATE_TTL_MS = 10 * 60 * 1000;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

async function getUser(req: Request) {
  if (!admin) return null;
  const auth = req.headers.get("Authorization");
  if (!auth) return null;
  const jwt = auth.replace(/^Bearer\s+/i, "").trim();
  if (!jwt) return null;
  const { data } = await admin.auth.getUser(jwt);
  return data.user ?? null;
}

async function deriveKey(secret: string) {
  const material = new TextEncoder().encode(secret);
  return crypto.subtle.importKey(
    "raw",
    await crypto.subtle.digest("SHA-256", material),
    "AES-GCM",
    false,
    ["encrypt", "decrypt"],
  );
}

async function encryptToken(value: string) {
  if (!encryptionKey) throw new Error("AI token encryption is not configured.");
  const key = await deriveKey(encryptionKey);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const data = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    new TextEncoder().encode(value),
  );
  const bytes = new Uint8Array(data);
  const packed = new Uint8Array(iv.length + bytes.length);
  packed.set(iv, 0);
  packed.set(bytes, iv.length);
  return btoa(String.fromCharCode(...packed));
}

async function exchangeGoogleCode(code: string) {
  if (!googleClientId || !googleClientSecret || !callbackUrl) {
    throw new Error("Gemini OAuth is not configured on the NUS server.");
  }
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code,
      client_id: googleClientId,
      client_secret: googleClientSecret,
      redirect_uri: callbackUrl,
      grant_type: "authorization_code",
    }),
  });
  if (!response.ok) throw new Error("Google OAuth token exchange failed.");
  return await response.json();
}

async function verifyGeminiApiKey(apiKey: string, model: string) {
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}`,
    {
      method: "GET",
      headers: { "x-goog-api-key": apiKey },
    },
  );
  if (response.status === 401 || response.status === 403) {
    return { ok: false as const, status: 401 };
  }
  if (!response.ok) {
    return { ok: false as const, status: 502 };
  }
  return { ok: true as const };
}

const appCallback = (status: "success" | "error", message: string) => {
  const params = new URLSearchParams({ status, message });
  return Response.redirect(`nus://ai-callback?${params.toString()}`, 302);
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const url = new URL(req.url);

  if (req.method === "GET" && url.pathname.endsWith("/callback")) {
    const code = url.searchParams.get("code");
    const state = url.searchParams.get("state");
    const error = url.searchParams.get("error");
    if (error || !code || !state || !admin) {
      return appCallback("error", "فشل تفويض Gemini.");
    }

    const { data: pending } = await admin
      .from("user_ai_connections")
      .select("id,user_id,metadata")
      .eq("provider", "gemini")
      .eq("status", "disconnected")
      .contains("metadata", { oauthState: state })
      .maybeSingle();

    if (!pending) return appCallback("error", "انتهت صلاحية رابط التفويض أو أنه غير صالح.");

    const issuedAt = Date.parse(String(pending.metadata?.issuedAt ?? ""));
    if (!Number.isFinite(issuedAt) || Date.now() - issuedAt > STATE_TTL_MS) {
      await admin.from("user_ai_connections").update({
        status: "error",
        last_error: "Gemini OAuth state expired.",
      }).eq("id", pending.id);
      return appCallback("error", "انتهت صلاحية طلب ربط Gemini. ابدأ الربط من NUS مرة أخرى.");
    }

    try {
      const token = await exchangeGoogleCode(code);
      const accessToken = typeof token.access_token === "string" ? token.access_token : "";
      const refreshToken = typeof token.refresh_token === "string" ? token.refresh_token : "";
      if (!accessToken) throw new Error("Google returned no access token.");

      await admin.from("user_ai_connections").update({
        status: "connected",
        model: defaultModel,
        access_token_encrypted: await encryptToken(accessToken),
        refresh_token_encrypted: refreshToken ? await encryptToken(refreshToken) : null,
        token_expires_at: token.expires_in
          ? new Date(Date.now() + Number(token.expires_in) * 1000).toISOString()
          : null,
        metadata: { authMode: "oauth" },
        last_error: null,
      }).eq("id", pending.id);

      return appCallback("success", "تم ربط Gemini بحساب NUS.");
    } catch (e) {
      await admin.from("user_ai_connections").update({
        status: "error",
        last_error: e instanceof Error ? e.message : "OAuth callback failed.",
      }).eq("id", pending.id);
      return appCallback("error", "تعذر إكمال ربط Gemini.");
    }
  }

  const user = await getUser(req);
  if (!user) return json({ ok: false, error: "Authentication required." }, 401);
  if (!admin) return json({ ok: false, error: "AI server configuration is incomplete." }, 503);

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch (_) {}

  if (body.provider !== "gemini") {
    return json({ ok: false, error: "Unsupported AI provider." }, 400);
  }

  if (body.action === "save_api_key") {
    const apiKey = typeof body.apiKey === "string" ? body.apiKey.trim() : "";
    if (apiKey.length < 20 || apiKey.length > 512) {
      return json({ ok: false, error: "Gemini API key is invalid." }, 400);
    }

    const model = typeof body.model === "string" && body.model.trim()
      ? body.model.trim()
      : defaultModel;
    const verification = await verifyGeminiApiKey(apiKey, model);
    if (!verification.ok) {
      return json({
        ok: false,
        error: verification.status === 401
          ? "مفتاح Gemini غير صالح أو غير مسموح به."
          : "تعذر التحقق من مفتاح Gemini الآن.",
      }, verification.status === 401 ? 400 : 502);
    }

    const { data: existing, error: existingError } = await admin
      .from("user_ai_connections")
      .select("id")
      .eq("user_id", user.id)
      .eq("provider", "gemini")
      .maybeSingle();
    if (existingError) return json({ ok: false, error: "تعذر تحميل اتصال Gemini." }, 503);

    const values = {
      user_id: user.id,
      provider: "gemini",
      status: "connected",
      model,
      access_token_encrypted: await encryptToken(apiKey),
      refresh_token_encrypted: null,
      token_expires_at: null,
      metadata: { authMode: "api_key" },
      last_error: null,
    };

    const { error: saveError } = existing
      ? await admin.from("user_ai_connections").update({
          status: values.status,
          model: values.model,
          access_token_encrypted: values.access_token_encrypted,
          refresh_token_encrypted: values.refresh_token_encrypted,
          token_expires_at: values.token_expires_at,
          metadata: values.metadata,
          last_error: values.last_error,
        }).eq("id", existing.id).eq("user_id", user.id)
      : await admin.from("user_ai_connections").insert(values);

    if (saveError) return json({ ok: false, error: "تعذر حفظ اتصال Gemini بأمان." }, 503);
    return json({ ok: true, provider: "gemini", model, authMode: "api_key" });
  }

  if (body.action !== "start") {
    return json({ ok: false, error: "Unsupported AI provider action." }, 400);
  }

  if (!googleClientId || !callbackUrl || !googleClientSecret) {
    return json({
      ok: false,
      error: "Gemini OAuth is not configured on the NUS server. Use the Gemini API-key connection in AI Settings.",
      apiKeyAvailable: true,
    }, 503);
  }

  const stateBytes = crypto.getRandomValues(new Uint8Array(24));
  const state = btoa(String.fromCharCode(...stateBytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  const { data: existing } = await admin
    .from("user_ai_connections")
    .select("id")
    .eq("user_id", user.id)
    .eq("provider", "gemini")
    .maybeSingle();

  const metadata = { oauthState: state, issuedAt: new Date().toISOString() };
  if (existing) {
    await admin.from("user_ai_connections").update({
      status: "disconnected",
      metadata,
      last_error: null,
    }).eq("id", existing.id).eq("user_id", user.id);
  } else {
    await admin.from("user_ai_connections").insert({
      user_id: user.id,
      provider: "gemini",
      status: "disconnected",
      metadata,
    });
  }

  const params = new URLSearchParams({
    client_id: googleClientId,
    redirect_uri: callbackUrl,
    response_type: "code",
    access_type: "offline",
    prompt: "consent",
    scope: "https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/generative-language.retriever",
    state,
  });

  return json({
    ok: true,
    authorizationUrl: `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`,
  });
});
