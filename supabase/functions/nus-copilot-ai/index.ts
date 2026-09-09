import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") || "gemini-3.8-flash";
const ADMIN = SERVICE_KEY ? createClient(SUPABASE_URL, SERVICE_KEY) : null;
const DAILY_LIMIT = 10;
const MAX_OBJECTIVE_LENGTH = 4000;
const MAX_CONTEXT_ITEMS = 8;
const MAX_CONTEXT_SUMMARY_LENGTH = 4000;
const GEMINI_TIMEOUT_MS = 30000;
const ALLOWED_DOMAINS = new Set(["household", "calendar", "shopping", "finance", "tasks"]);

type JsonObject = Record<string, unknown>;
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });

async function authenticatedUser(req: Request) {
  if (!ADMIN) return null;
  const header = req.headers.get("Authorization") ?? "";
  const jwt = header.replace(/^Bearer\s+/i, "").trim();
  if (!jwt) return null;
  const { data, error } = await ADMIN.auth.getUser(jwt);
  return error ? null : data.user ?? null;
}
function validate(body: unknown) {
  if (!body || typeof body !== "object") return "Invalid JSON request.";
  const record = body as JsonObject;
  if (typeof record.objective !== "string" || !record.objective.trim()) return "Copilot objective is required.";
  if (record.objective.length > MAX_OBJECTIVE_LENGTH) return "Copilot objective is too long.";
  if (!Array.isArray(record.context) || record.context.length < 1 || record.context.length > MAX_CONTEXT_ITEMS) return "Copilot context is invalid.";
  for (const item of record.context) {
    if (!item || typeof item !== "object") return "Copilot context item is invalid.";
    const entry = item as JsonObject;
    if (typeof entry.domain !== "string" || !ALLOWED_DOMAINS.has(entry.domain)) return "Copilot context domain is not allowed.";
    if (typeof entry.entityId !== "string" || !entry.entityId.trim() || entry.entityId.length > 120) return "Copilot context entity is invalid.";
    if (typeof entry.summary !== "string" || !entry.summary.trim() || entry.summary.length > MAX_CONTEXT_SUMMARY_LENGTH) return "Copilot context summary is invalid.";
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
  if (ADMIN) await ADMIN.rpc("release_ai_quota", { p_user_id: userId, p_reservation_id: reservationId });
}
function strings(value: unknown) {
  if (!Array.isArray(value) || value.length > 8) return null;
  const result: string[] = [];
  for (const item of value) {
    if (typeof item !== "string" || !item.trim()) return null;
    result.push(item.trim());
  }
  return result;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ ok: false, error: "POST is required." }, 405);
  if (!ADMIN || !GEMINI_API_KEY) return json({ ok: false, error: "خدمة NUS Copilot غير مُهيأة على الخادم." }, 503);
  const user = await authenticatedUser(req);
  if (!user) return json({ ok: false, error: "Authentication required." }, 401);
  let body: JsonObject;
  try { body = await req.json() as JsonObject; } catch { return json({ ok: false, error: "Invalid JSON request." }, 400); }
  const error = validate(body);
  if (error) return json({ ok: false, error }, 400);

  const reservationId = await reserveQuota(user.id);
  if (!reservationId) return json({ ok: false, error: "لقد وصلت إلى الحد المجاني اليومي لـNUS Copilot.", code: "DAILY_QUOTA_EXCEEDED", limit: DAILY_LIMIT }, 429);

  const context = body.context as JsonObject[];
  const prompt = `أنت NUS Copilot، مساعد شخصي منزلي. استخدم السياق المقدم فقط. لا تختلق حقائق أو أرقامًا. لا تنفذ أي إجراء، ولا تقترح تغييرًا ماليًا يحتاج كتابة دون تأكيد صريح. احترم لغة السؤال. اكتب ردًا عمليًا وواضحًا وقصيرًا نسبيًا. أعد JSON فقط: summary string، advice array of strings، warnings array of strings. السياق: ${JSON.stringify(context)}. السؤال: ${body.objective}`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), GEMINI_TIMEOUT_MS);

  try {
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(GEMINI_MODEL)}:generateContent`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": GEMINI_API_KEY },
      signal: controller.signal,
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { responseFormat: { text: { mimeType: "APPLICATION_JSON", schema: {
          type: "object", additionalProperties: false,
          properties: { summary: { type: "string" }, advice: { type: "array", items: { type: "string" }, maxItems: 8 }, warnings: { type: "array", items: { type: "string" }, maxItems: 8 } },
          required: ["summary", "advice", "warnings"],
        } } } },
      }),
    });
    clearTimeout(timeout);
    if (!response.ok) {
      await response.text().catch(() => "");
      await releaseQuota(user.id, reservationId);
      return json({ ok: false, error: response.status === 429 ? "تم الوصول إلى حد استخدام Gemini مؤقتًا. حاول بعد قليل." : "خدمة NUS Copilot غير متاحة حاليًا." }, response.status === 429 ? 429 : 502);
    }
    let payload: JsonObject;
    try { payload = await response.json() as JsonObject; } catch { await releaseQuota(user.id, reservationId); return json({ ok: false, error: "Gemini returned malformed response data." }, 422); }
    const candidates = Array.isArray(payload.candidates) ? payload.candidates as JsonObject[] : [];
    const content = candidates[0] && typeof candidates[0].content === "object" ? candidates[0].content as JsonObject : null;
    const parts = content && Array.isArray(content.parts) ? content.parts as JsonObject[] : [];
    const textPart = parts.find((part) => typeof part?.text === "string" && part.text.trim());
    if (!textPart || typeof textPart.text !== "string") { await releaseQuota(user.id, reservationId); return json({ ok: false, error: "Gemini returned no Copilot response." }, 422); }
    let result: JsonObject;
    try { result = JSON.parse(textPart.text) as JsonObject; } catch { await releaseQuota(user.id, reservationId); return json({ ok: false, error: "Gemini returned malformed Copilot JSON." }, 422); }
    const summary = typeof result.summary === "string" ? result.summary.trim() : "";
    const advice = strings(result.advice);
    const warnings = strings(result.warnings);
    if (!summary || !advice || !warnings) { await releaseQuota(user.id, reservationId); return json({ ok: false, error: "Gemini response does not match the Copilot contract." }, 422); }
    if (!await finalizeQuota(user.id, reservationId)) return json({ ok: false, error: "تعذر تثبيت استخدام Copilot. حاول مرة أخرى." }, 503);
    return json({ ok: true, id: crypto.randomUUID(), provider: "gemini", model: GEMINI_MODEL, generatedAt: new Date().toISOString(), summary, facts: context.map((item) => String(item.summary)), advice, warnings });
  } catch (error) {
    clearTimeout(timeout);
    await releaseQuota(user.id, reservationId);
    return json({ ok: false, error: error instanceof DOMException && error.name === "AbortError" ? "انتهت مهلة NUS Copilot." : "تعذر الوصول إلى NUS Copilot الآن." }, error instanceof DOMException && error.name === "AbortError" ? 504 : 502);
  }
});
