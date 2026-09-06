import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const categories = ["food", "clothing", "maintenance", "familyFun", "other"] as const;
type Category = (typeof categories)[number];

type BudgetInput = Record<string, number>;

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const encryptionSecret = Deno.env.get("AI_TOKEN_ENCRYPTION_KEY");
const googleCloudProjectId = Deno.env.get("GEMINI_GOOGLE_CLOUD_PROJECT_ID");
const configuredModel = Deno.env.get("GEMINI_MODEL") || "gemini-3.8-flash";
const admin = serviceKey ? createClient(supabaseUrl, serviceKey) : null;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

const numberValue = (value: unknown): number => {
  const number = typeof value === "number" ? value : Number(value ?? 0);
  return Number.isFinite(number) ? Math.max(0, Math.round(number)) : 0;
};

const cleanInput = (body: Record<string, unknown>): BudgetInput => {
  const result: BudgetInput = {};
  for (const key of [
    "income",
    "rent",
    "utilities",
    "food",
    "transport",
    "debt",
    "health",
    "clothing",
    "maintenance",
    "familyFun",
    "other",
    "savingsTarget",
    "actualThisMonth",
  ]) {
    result[key] = numberValue(body[key]);
  }
  return result;
};

const systemPrompt = `
أنت مدير المنزل الاقتصادي داخل NUS.
مهمتك بناء خطة شهرية واقعية من الدخل الحقيقي للمستخدم والتزاماته والمبالغ التي أدخلها بنفسه وسجل الصرف الفعلي لهذا الشهر.

قواعد إلزامية:
1. لا تخترع الدخل ولا تغيّر أي مبلغ أدخله المستخدم كقيمة معلومة.
2. اقترح قيمًا فقط للبنود التي قيمتها صفر.
3. الأولوية للإيجار والمرافق والمواصلات والديون والصحة، ثم الغذاء والاحتياجات الأساسية، ثم البنود المرنة.
4. راعِ الغلاء والتضخم، لكن لا تفترض أسعارًا دقيقة من غير بيانات المستخدم.
5. احتفظ باحتياطي فقط عندما يسمح الحساب. احترم savingsTarget إذا كان ممكنًا رياضيًا، وإلا فسّر التعارض.
6. مجموع البنود الجديدة + الاحتياطي لا يتجاوز المتاح بعد البنود المعلومة.
7. actualThisMonth دليل على السلوك الحالي وليس إثباتًا لاتجاه طويل الأمد.
8. كن محافظًا: اترك مساحة للطوارئ ولا تفترض أن المتاح كله يجب أن يُنفق.
9. العملة جنيه مصري. استخدم أعدادًا صحيحة فقط.
10. أعد JSON فقط وفق المخطط المطلوب.
11. managerMessage و recommendation باللهجة المصرية الواضحة والعملية، بدون لغة مصرفية معقدة.
`;

const responseSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    food: { type: "integer", minimum: 0 },
    clothing: { type: "integer", minimum: 0 },
    maintenance: { type: "integer", minimum: 0 },
    familyFun: { type: "integer", minimum: 0 },
    other: { type: "integer", minimum: 0 },
    reserve: { type: "integer", minimum: 0 },
    managerMessage: { type: "string" },
    recommendation: { type: "string" },
  },
  required: [
    "food",
    "clothing",
    "maintenance",
    "familyFun",
    "other",
    "reserve",
    "managerMessage",
    "recommendation",
  ],
};

async function deriveKey(secret: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(secret));
  return crypto.subtle.importKey("raw", digest, "AES-GCM", false, ["encrypt", "decrypt"]);
}

function decodeBase64(value: string) {
  const binary = atob(value);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function encodeBase64(value: Uint8Array) {
  return btoa(String.fromCharCode(...value));
}

async function decryptToken(value: string) {
  if (!encryptionSecret) throw new Error("AI token encryption is not configured.");
  const packed = decodeBase64(value);
  const iv = packed.slice(0, 12);
  const ciphertext = packed.slice(12);
  const key = await deriveKey(encryptionSecret);
  const plaintext = await crypto.subtle.decrypt({ name: "AES-GCM", iv }, key, ciphertext);
  return new TextDecoder().decode(plaintext);
}

async function encryptToken(value: string) {
  if (!encryptionSecret) throw new Error("AI token encryption is not configured.");
  const key = await deriveKey(encryptionSecret);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = new Uint8Array(await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    new TextEncoder().encode(value),
  ));
  const packed = new Uint8Array(iv.length + ciphertext.length);
  packed.set(iv, 0);
  packed.set(ciphertext, iv.length);
  return encodeBase64(packed);
}

async function refreshGoogleAccessToken(connection: Record<string, unknown>) {
  const refreshEncrypted = connection.refresh_token_encrypted;
  if (typeof refreshEncrypted !== "string" || refreshEncrypted.length === 0) return null;
  const clientId = Deno.env.get("GEMINI_GOOGLE_CLIENT_ID");
  const clientSecret = Deno.env.get("GEMINI_GOOGLE_CLIENT_SECRET");
  if (!clientId || !clientSecret) throw new Error("Gemini OAuth client is not configured.");
  const refreshToken = await decryptToken(refreshEncrypted);
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type: "refresh_token",
    }),
  });
  if (!response.ok) {
    throw new Error("Gemini access token refresh failed.");
  }
  return response.json();
}

async function getGeminiAccessToken(userId: string) {
  if (!admin) throw new Error("Server database client is not configured.");
  if (!googleCloudProjectId) throw new Error("Gemini Google Cloud project is not configured.");

  const { data: connection, error } = await admin
    .from("user_ai_connections")
    .select("id,provider,status,model,access_token_encrypted,refresh_token_encrypted,token_expires_at")
    .eq("user_id", userId)
    .eq("provider", "gemini")
    .maybeSingle();

  if (error) throw error;
  if (!connection || connection.status !== "connected" || typeof connection.access_token_encrypted !== "string") {
    return null;
  }

  const expiresAt = connection.token_expires_at ? Date.parse(String(connection.token_expires_at)) : 0;
  const shouldRefresh = expiresAt > 0 && expiresAt <= Date.now() + 60_000;
  if (!shouldRefresh) {
    return { token: await decryptToken(connection.access_token_encrypted), model: connection.model || configuredModel };
  }

  const refreshed = await refreshGoogleAccessToken(connection);
  if (!refreshed?.access_token) throw new Error("Gemini did not return a refreshed access token.");
  const accessToken = String(refreshed.access_token);
  await admin.from("user_ai_connections").update({
    access_token_encrypted: await encryptToken(accessToken),
    token_expires_at: refreshed.expires_in
      ? new Date(Date.now() + Number(refreshed.expires_in) * 1000).toISOString()
      : null,
    last_error: null,
  }).eq("id", connection.id);

  return { token: accessToken, model: connection.model || configuredModel };
}

function sanitizeRecommendation(
  recommendation: Record<string, unknown>,
  input: BudgetInput,
  available: number,
) {
  const safe: Record<Category | "reserve", number> = {
    food: numberValue(recommendation.food),
    clothing: numberValue(recommendation.clothing),
    maintenance: numberValue(recommendation.maintenance),
    familyFun: numberValue(recommendation.familyFun),
    other: numberValue(recommendation.other),
    reserve: numberValue(recommendation.reserve),
  };

  let allocation = categories
    .filter((key) => input[key] === 0)
    .reduce((sum, key) => sum + safe[key], 0) + safe.reserve;

  if (allocation > available && allocation > 0) {
    const scale = available / allocation;
    for (const key of categories) {
      if (input[key] === 0) safe[key] = Math.floor(safe[key] * scale);
    }
    safe.reserve = Math.floor(safe.reserve * scale);
  }

  allocation = categories
    .filter((key) => input[key] === 0)
    .reduce((sum, key) => sum + safe[key], 0) + safe.reserve;

  if (allocation > available) {
    let overflow = allocation - available;
    for (const key of ["other", "familyFun", "clothing", "maintenance", "food"] as Category[]) {
      if (input[key] !== 0 || overflow <= 0) continue;
      const reduction = Math.min(safe[key], overflow);
      safe[key] -= reduction;
      overflow -= reduction;
    }
    if (overflow > 0) safe.reserve = Math.max(0, safe.reserve - overflow);
  }

  const missing = new Set(categories.filter((key) => input[key] === 0));
  return {
    food: missing.has("food") ? safe.food : input.food,
    clothing: missing.has("clothing") ? safe.clothing : input.clothing,
    maintenance: missing.has("maintenance") ? safe.maintenance : input.maintenance,
    familyFun: missing.has("familyFun") ? safe.familyFun : input.familyFun,
    other: missing.has("other") ? safe.other : input.other,
    reserve: input.savingsTarget > 0
      ? Math.min(input.savingsTarget, Math.max(0, available))
      : safe.reserve,
    managerMessage: String(recommendation.managerMessage || "مدير المنزل حلّل دخلك والتزاماتك ووزّع البنود الناقصة على المتاح."),
    recommendation: String(recommendation.recommendation || "الخطة محسوبة على دخلك الحالي وتقدر تعدّلها بإدخال أرقامك الفعلية."),
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ ok: false, error: "POST is required." }, 405);
  if (!admin) return json({ ok: false, error: "NUS AI server is not configured." }, 503);

  const auth = req.headers.get("Authorization");
  if (!auth) return json({ ok: false, error: "Authentication required." }, 401);
  const jwt = auth.replace(/^Bearer\s+/i, "");
  const { data: userData, error: userError } = await admin.auth.getUser(jwt);
  if (userError || !userData.user) return json({ ok: false, error: "Authentication required." }, 401);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return json({ ok: false, error: "Invalid JSON request." }, 400);
  }

  const input = cleanInput(body);
  if (input.income <= 0) return json({ ok: false, error: "Monthly income must be greater than zero." }, 400);

  const knownMandatory = input.rent + input.utilities + input.transport + input.debt + input.health;
  const knownFlexible = categories.reduce((sum, key) => sum + (input[key] > 0 ? input[key] : 0), 0);
  const available = Math.max(0, input.income - knownMandatory - knownFlexible);
  const userId = userData.user.id;

  let gemini: { token: string; model: string } | null;
  try {
    gemini = await getGeminiAccessToken(userId);
  } catch (error) {
    console.error("Gemini credential resolution failed", error);
    return json({ ok: false, error: "تعذر تجهيز اتصال Gemini. راجع اتصال حسابك وحاول مرة أخرى." }, 502);
  }

  if (!gemini) {
    return json({ ok: false, error: "اربط حساب Gemini الخاص بك من شاشة الذكاء الاصطناعي أولاً." }, 409);
  }

  const requestContext = {
    currency: "EGP",
    input,
    knownMandatory,
    knownFlexible,
    availableForMissingCategoriesAndReserve: available,
    missingCategories: categories.filter((key) => input[key] === 0),
  };

  const prompt = `${systemPrompt}\n\nبيانات المستخدم:\n${JSON.stringify(requestContext)}`;
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(gemini.model)}:generateContent`;

  let response: Response;
  try {
    response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${gemini.token}`,
        "Content-Type": "application/json",
        "x-goog-user-project": googleCloudProjectId!,
      },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.2,
          responseMimeType: "application/json",
          responseSchema,
        },
      }),
    });
  } catch (error) {
    console.error("Gemini request failed", error);
    return json({ ok: false, error: "تعذر الوصول إلى Gemini الآن." }, 502);
  }

  if (!response.ok) {
    const details = await response.text();
    console.error("Gemini household budget request rejected", response.status, details.slice(0, 1000));
    return json({ ok: false, error: "Gemini رفض طلب التخطيط المالي. راجع صلاحية اتصال Gemini." }, 502);
  }

  const payload = await response.json();
  const content = payload?.candidates?.[0]?.content?.parts?.find((part: Record<string, unknown>) => typeof part?.text === "string")?.text;
  if (typeof content !== "string") {
    return json({ ok: false, error: "Gemini returned no recommendation." }, 502);
  }

  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(content);
  } catch (_) {
    return json({ ok: false, error: "Gemini returned malformed recommendation data." }, 502);
  }

  const recommendation = sanitizeRecommendation(parsed, input, available);

  const { error: runError } = await admin.from("user_ai_runs").insert({
    user_id: userId,
    provider: "gemini",
    model: gemini.model,
    purpose: "household_budget_plan",
    request_context: requestContext,
    response: recommendation,
  });
  if (runError) {
    console.error("Failed to persist user_ai_run", runError);
    return json({ ok: false, error: "تم إنشاء التحليل لكن تعذر حفظه في سجل حسابك." }, 500);
  }

  return json({ ok: true, provider: "gemini", model: gemini.model, recommendation });
});
