import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") || "gemini-3.8-flash";
const ADMIN = SERVICE_KEY ? createClient(SUPABASE_URL, SERVICE_KEY) : null;
const MAX_OBJECTIVE_LENGTH = 4000;
const MAX_CONTEXT_ITEMS = 8;
const MAX_CONTEXT_SUMMARY_LENGTH = 20000;
const GEMINI_TIMEOUT_MS = 30000;
const MAX_PROVIDER_DIAGNOSTIC_BODY_LENGTH = 800;
const DAILY_LIMIT = 10;

type JsonObject = Record<string, unknown>;

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });

async function getAuthenticatedUser(req: Request) {
  if (!ADMIN) return null;
  const header = req.headers.get("Authorization");
  if (!header) return null;
  const jwt = header.replace(/^Bearer\s+/i, "").trim();
  if (!jwt) return null;
  const { data, error } = await ADMIN.auth.getUser(jwt);
  if (error) return null;
  return data.user ?? null;
}

function validateRequest(body: unknown) {
  if (!body || typeof body !== "object") return "Invalid JSON request.";
  const record = body as JsonObject;
  if (typeof record.objective !== "string" || !record.objective.trim()) return "Advisor objective is required.";
  if (record.objective.length > MAX_OBJECTIVE_LENGTH) return "Advisor objective is too long.";
  if (!Array.isArray(record.context) || record.context.length < 1 || record.context.length > MAX_CONTEXT_ITEMS) return "Advisor context is invalid.";
  for (const item of record.context) {
    if (!item || typeof item !== "object") return "Advisor context item is invalid.";
    const entry = item as JsonObject;
    if (entry.domain !== "financial_engine") return "Advisor accepts Financial Engine context only.";
    if (typeof entry.entityId !== "string" || !/^monthly:\d{4}-(0[1-9]|1[0-2])$/.test(entry.entityId)) return "Advisor context entity is invalid.";
    if (typeof entry.summary !== "string" || !entry.summary.trim()) return "Advisor context summary is required.";
    if (entry.summary.length > MAX_CONTEXT_SUMMARY_LENGTH) return "Advisor context summary is too long.";
  }
  return null;
}

async function reserveQuota(userId: string) {
  if (!ADMIN) throw new Error("Database client unavailable.");
  const { data, error } = await ADMIN.rpc("reserve_ai_quota", { p_user_id: userId, p_limit: DAILY_LIMIT, p_ttl_seconds: 120 });
  if (error) throw error;
  return typeof data === "string" && data.trim() ? data : null;
}

async function finalizeQuota(userId: string, reservationId: string) {
  if (!ADMIN) return false;
  const { data, error } = await ADMIN.rpc("finalize_ai_quota", { p_user_id: userId, p_reservation_id: reservationId });
  return !error && data === true;
}

async function releaseQuota(userId: string, reservationId: string) {
  if (!ADMIN) return;
  await ADMIN.rpc("release_ai_quota", { p_user_id: userId, p_reservation_id: reservationId });
}

const schema = {
  type: "object",
  additionalProperties: false,
  properties: {
    summary: { type: "string" },
    advice: { type: "array", items: { type: "string" }, maxItems: 8 },
    warnings: { type: "array", items: { type: "string" }, maxItems: 8 },
  },
  required: ["summary", "advice", "warnings"],
};

function asStringArray(value: unknown) {
  if (!Array.isArray(value) || value.length > 8) return null;
  const result: string[] = [];
  for (const item of value) {
    if (typeof item !== "string" || !item.trim()) return null;
    result.push(item.trim());
  }
  return result;
}

function sanitizeProviderText(value: string) {
  return value
    .replace(/-----BEGIN [^-]+-----[\s\S]*?-----END [^-]+-----/gi, "[REDACTED_BLOCK]")
    .replace(/(?:x-goog-api-key|api[-_ ]?key|authorization|bearer|access[-_ ]?token|refresh[-_ ]?token|cookie|set-cookie)\s*[:=]\s*[^,\s;]+/gi, "$1=[REDACTED]")
    .replace(/\bAIza[0-9A-Za-z_-]{20,}\b/g, "[REDACTED_KEY]")
    .replace(/\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/g, "[REDACTED_TOKEN]")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, MAX_PROVIDER_DIAGNOSTIC_BODY_LENGTH);
}

async function getProviderDiagnostic(response: Response) {
  const contentType = response.headers.get("content-type") ?? "";
  let rawBody = "";
  try {
    rawBody = await response.text();
  } catch {
    rawBody = "";
  }

  const sanitizedBody = sanitizeProviderText(rawBody);
  let sanitizedErrorType = "http_error";
  let sanitizedErrorMessage = sanitizedBody || "Provider returned an HTTP error without a readable body.";

  if (contentType.toLowerCase().includes("application/json")) {
    try {
      const parsed = JSON.parse(rawBody) as JsonObject;
      const errorValue = parsed.error;
      if (errorValue && typeof errorValue === "object") {
        const providerError = errorValue as JsonObject;
        const providerCode = typeof providerError.code === "number" ? providerError.code : null;
        const providerStatus = typeof providerError.status === "string" ? providerError.status : null;
        const providerMessage = typeof providerError.message === "string" ? providerError.message : null;
        sanitizedErrorType = providerStatus ?? (providerCode !== null ? `http_${providerCode}` : "provider_api_error");
        sanitizedErrorMessage = sanitizeProviderText(providerMessage ?? "Provider returned a structured error without a message.");
      }
    } catch {
      // Keep the sanitized text fallback for non-JSON or malformed JSON bodies.
    }
  }

  return { contentType, sanitizedErrorType, sanitizedErrorMessage };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ ok: false, error: "POST is required." }, 405);
  if (!ADMIN) return json({ ok: false, error: "خدمة المستشار المالي غير مُهيأة على الخادم." }, 503);
  if (!GEMINI_API_KEY) return json({ ok: false, error: "خدمة المستشار المالي غير مُهيأة على الخادم." }, 503);

  const user = await getAuthenticatedUser(req);
  if (!user) return json({ ok: false, error: "Authentication required." }, 401);

  let body: JsonObject;
  try {
    body = await req.json() as JsonObject;
  } catch {
    return json({ ok: false, error: "Invalid JSON request." }, 400);
  }

  const validationError = validateRequest(body);
  if (validationError) return json({ ok: false, error: validationError }, 400);

  let reservationId: string | null = null;
  try {
    reservationId = await reserveQuota(user.id);
  } catch (error) {
    console.error("financial-advisor-ai quota reservation failed", { error: error instanceof Error ? error.name : "unknown" });
    return json({ ok: false, error: "تعذر التحقق من حد الاستخدام اليومي. حاول مرة أخرى." }, 503);
  }

  if (!reservationId) {
    return json({
      ok: false,
      error: "لقد وصلت إلى الحد المجاني اليومي للمستشار الذكي. يمكنك المحاولة مرة أخرى غدًا.",
      code: "DAILY_QUOTA_EXCEEDED",
      limit: DAILY_LIMIT,
    }, 429);
  }

  const context = body.context as JsonObject[];
  const prompt = `أنت المستشار المالي للمنزل داخل NUS. بيانات السياق التالية هي الحقائق المالية الوحيدة المسموح باستخدامها، وهي آتية من Financial Engine الحالي. لا تخترع أو تعدّل أو تقدّر أي رقم. لا تحسب أرقامًا جديدة غير موجودة صراحة في السياق. لا تستخدم FX أو أسعارًا خارجية أو تحويل عملات. لا تنشئ معاملات ولا تدّعي تنفيذ أي إجراء ولا تعدّل أي بيانات مالية. ميّز بوضوح بين FACTS وADVICE. إذا كانت البيانات غير كافية، قل ذلك صراحة. احترم لغة المستخدم والتطبيق: العربية تكون عربية طبيعية مناسبة للواجهة الحالية، والإنجليزية تكون طبيعية بالإنجليزية. أعد JSON فقط وفق العقد: summary وadvice وwarnings. لا تنشئ قائمة facts من عندك؛ الخادم سيعيد حقائق Financial Engine حرفيًا. سؤال المستخدم: ${body.objective}. السياق: ${JSON.stringify(context)}`;

  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(GEMINI_MODEL)}:generateContent`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), GEMINI_TIMEOUT_MS);

  try {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": GEMINI_API_KEY },
      signal: controller.signal,
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { responseMimeType: "application/json", responseSchema: schema },
      }),
    });
    clearTimeout(timeout);

    if (response.status === 429) {
      await releaseQuota(user.id, reservationId);
      return json({ ok: false, error: "تم الوصول إلى حد استخدام Gemini مؤقتًا. حاول بعد قليل." }, 429);
    }
    if (response.status === 401 || response.status === 403) {
      await releaseQuota(user.id, reservationId);
      console.error("financial-advisor-ai provider authentication failed", { status: response.status });
      return json({ ok: false, error: "صلاحية خدمة Gemini غير متاحة حاليًا." }, 502);
    }
    if (!response.ok) {
      const diagnostic = await getProviderDiagnostic(response);
      await releaseQuota(user.id, reservationId);
      console.error("financial-advisor-ai GEMINI_PROVIDER_DIAGNOSTIC", {
        status: response.status,
        contentType: diagnostic.contentType,
        sanitizedErrorType: diagnostic.sanitizedErrorType,
        sanitizedErrorMessage: diagnostic.sanitizedErrorMessage,
      });
      return json({ ok: false, error: "خدمة Gemini غير متاحة حاليًا." }, 502);
    }

    let payload: JsonObject;
    try { payload = await response.json() as JsonObject; }
    catch { await releaseQuota(user.id, reservationId); return json({ ok: false, error: "Gemini returned malformed response data." }, 422); }

    const candidates = Array.isArray(payload.candidates) ? payload.candidates as JsonObject[] : [];
    const content = candidates.length > 0 && candidates[0] && typeof candidates[0].content === "object" ? candidates[0].content as JsonObject : null;
    const parts = content && Array.isArray(content.parts) ? content.parts as JsonObject[] : [];
    const textPart = parts.find((part) => part && typeof part.text === "string");
    const rawText = textPart && typeof textPart.text === "string" ? textPart.text : null;
    if (!rawText) { await releaseQuota(user.id, reservationId); return json({ ok: false, error: "Gemini returned no advisor response." }, 422); }

    let result: JsonObject;
    try { result = JSON.parse(rawText) as JsonObject; }
    catch { await releaseQuota(user.id, reservationId); return json({ ok: false, error: "Gemini returned malformed advisor JSON." }, 422); }

    const summary = typeof result.summary === "string" ? result.summary.trim() : "";
    const advice = asStringArray(result.advice);
    const warnings = asStringArray(result.warnings);
    if (!summary || !advice || !warnings) {
      await releaseQuota(user.id, reservationId);
      return json({ ok: false, error: "Gemini response does not match the advisor contract." }, 422);
    }

    const finalized = await finalizeQuota(user.id, reservationId);
    if (!finalized) {
      console.error("financial-advisor-ai quota finalization failed", { userId: user.id });
      return json({ ok: false, error: "تعذر تثبيت استخدام المستشار. حاول مرة أخرى." }, 503);
    }

    return json({
      ok: true,
      id: crypto.randomUUID(),
      provider: "gemini",
      model: GEMINI_MODEL,
      generatedAt: new Date().toISOString(),
      summary,
      facts: context.map((item) => String(item.summary)),
      advice,
      warnings,
    });
  } catch (error) {
    clearTimeout(timeout);
    await releaseQuota(user.id, reservationId);
    const timedOut = error instanceof DOMException && error.name === "AbortError";
    console.error("financial-advisor-ai provider request failed", { reason: timedOut ? "timeout" : error instanceof Error ? error.name : "unknown" });
    return json({ ok: false, error: timedOut ? "انتهت مهلة خدمة المستشار المالي." : "تعذر الوصول إلى Gemini الآن." }, timedOut ? 504 : 502);
  }
});
