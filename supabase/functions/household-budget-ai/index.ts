import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "npm:@supabase/server";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const categories = ["food", "clothing", "maintenance", "familyFun", "other"] as const;
type Category = (typeof categories)[number];

type BudgetInput = Record<string, number>;

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

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

const systemPrompt = `
You are the economic household manager inside NUS.
Your job is to build a realistic monthly household spending plan from the user's actual income, known obligations, known category amounts, and this month's actual spending.

Rules:
1. Never invent income. Never change a value the user explicitly entered as a known category.
2. Only recommend amounts for categories whose input is zero.
3. Protect housing/rent, utilities, transportation, debt, and health before lifestyle spending.
4. Treat food and household essentials as high priority but optimize them for inflation and the available income.
5. Keep a reserve only when mathematically possible. Honor an explicit savingsTarget when it fits; otherwise explain the conflict.
6. The returned five missing-category amounts plus reserve must fit inside the amount remaining after known mandatory categories and known user-entered flexible categories.
7. Use actualThisMonth as evidence of recent behavior: call out overspending patterns when relevant, but do not pretend one month proves a long-term trend.
8. Be conservative. Do not assume the user can spend all residual money. Prefer a usable weekly cap.
9. Currency is Egyptian pounds (EGP). Round all amounts to whole pounds.
10. Return ONLY valid JSON matching the requested schema.
11. managerMessage and recommendation should be concise, practical Egyptian Arabic, not formal financial jargon.
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

const main = withSupabase({ auth: "user" }, async (req, ctx) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ ok: false, error: "POST is required." }, 405);

  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) {
    return json({
      ok: false,
      error: "AI provider is not configured on the NUS server. Set OPENAI_API_KEY in Supabase Function Secrets.",
    }, 503);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return json({ ok: false, error: "Invalid JSON request." }, 400);
  }

  const input = cleanInput(body);
  if (input.income <= 0) {
    return json({ ok: false, error: "Monthly income must be greater than zero." }, 400);
  }

  const knownMandatory = input.rent + input.utilities + input.transport + input.debt + input.health;
  const knownFlexible = categories.reduce(
    (sum, key) => sum + (input[key] > 0 ? input[key] : 0),
    0,
  );
  const available = Math.max(0, input.income - knownMandatory - knownFlexible);

  const userPrompt = {
    userId: ctx.userClaims?.sub,
    currency: "EGP",
    input,
    knownMandatory,
    knownFlexible,
    availableForMissingCategoriesAndReserve: available,
    missingCategories: categories.filter((key) => input[key] === 0),
  };

  const model = Deno.env.get("OPENAI_MODEL") || "gpt-4o-mini";

  const openAiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      temperature: 0.2,
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "household_budget_recommendation",
          strict: true,
          schema: responseSchema,
        },
      },
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: JSON.stringify(userPrompt) },
      ],
    }),
  });

  if (!openAiResponse.ok) {
    const details = await openAiResponse.text();
    console.error("OpenAI household budget request failed", openAiResponse.status, details.slice(0, 500));
    return json({ ok: false, error: "The AI provider rejected the household budget request." }, 502);
  }

  const completion = await openAiResponse.json();
  const content = completion?.choices?.[0]?.message?.content;
  if (typeof content !== "string") {
    return json({ ok: false, error: "The AI provider returned no recommendation." }, 502);
  }

  let recommendation: Record<string, unknown>;
  try {
    recommendation = JSON.parse(content);
  } catch (_) {
    return json({ ok: false, error: "The AI provider returned malformed recommendation data." }, 502);
  }

  // Server-side safety gate: AI may advise, but it cannot violate the budget.
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

  if (allocation > available) {
    const scale = available / allocation;
    for (const key of categories) {
      if (input[key] === 0) safe[key] = Math.floor(safe[key] * scale);
    }
    safe.reserve = Math.floor(safe.reserve * scale);
    allocation = categories
      .filter((key) => input[key] === 0)
      .reduce((sum, key) => sum + safe[key], 0) + safe.reserve;
  }

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
  const result = {
    food: missing.has("food") ? safe.food : input.food,
    clothing: missing.has("clothing") ? safe.clothing : input.clothing,
    maintenance: missing.has("maintenance") ? safe.maintenance : input.maintenance,
    familyFun: missing.has("familyFun") ? safe.familyFun : input.familyFun,
    other: missing.has("other") ? safe.other : input.other,
    reserve: input.savingsTarget > 0 ? Math.min(input.savingsTarget, Math.max(0, available)) : safe.reserve,
    managerMessage: String(recommendation.managerMessage || "مدير المنزل حلّل دخلك والتزاماتك ووزّع البنود الناقصة على المتاح."),
    recommendation: String(recommendation.recommendation || "الخطة محسوبة على دخلك الحالي وتقدر تعدّلها بإدخال أرقامك الفعلية."),
  };

  return json({ ok: true, model, recommendation: result });
});

Deno.serve(main);
