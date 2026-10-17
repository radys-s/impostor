// Impostor AI proxy: topic -> Czech secret words with hints for the party game.
// Runs Workers AI; the app holds no secret. Topics and words are never logged
// or stored, only daily counters per install ID.

import { WORDS_SYSTEM, askCount, wordsUser } from "./prompts";
import { isExhausted, markExhausted, reserve, type QuotaStore } from "./quota";
import {
  parseWordsRequest,
  validateWords,
  wordsSchema,
  type WordEntry,
} from "./schema";

export interface AiBinding {
  run(model: string, input: Record<string, unknown>): Promise<unknown>;
}

export interface Env {
  AI: AiBinding;
  QUOTA: QuotaStore;
  MODEL?: string;
  WORDS_PER_INSTALL?: string;
  GLOBAL_DAILY_CAP?: string;
}

const DEFAULT_MODEL = "@cf/mistralai/mistral-small-3.1-24b-instruct";
const MAX_BODY = 4_096;
/** Browser origins allowed for the Flutter web preview (any local port). */
const LOCAL_ORIGIN_RE =
  /^https?:\/\/(?:localhost|127\.0\.0\.1|\[::1\])(?::\d{1,5})?$/;

type ErrorCode =
  | "bad_request"
  | "forbidden"
  | "not_found"
  | "too_large"
  | "quota_install"
  | "quota_global"
  | "service_busy"
  | "ai_failed";

function limitOf(v: string | undefined, fallback: number): number {
  const n = Number(v);
  return v !== undefined && v !== "" && Number.isInteger(n) && n >= 0
    ? n
    : fallback;
}

export function allowedOrigin(origin: string | null): boolean {
  if (origin === null) return true; // native app, curl
  return LOCAL_ORIGIN_RE.test(origin);
}

function corsHeaders(origin: string | null): Record<string, string> {
  if (origin === null) return {};
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Max-Age": "86400",
    Vary: "Origin",
  };
}

function json(body: unknown, status: number, origin: string | null): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      ...corsHeaders(origin),
    },
  });
}

function fail(
  code: ErrorCode,
  message: string,
  status: number,
  origin: string | null,
): Response {
  return json({ error: { code, message } }, status, origin);
}

const exhausted = (origin: string | null) =>
  fail(
    "quota_global",
    "AI má dnes vyčerpanou kapacitu. Zkus to zítra, nebo hraj s vestavěnými balíčky.",
    429,
    origin,
  );

async function readJson(
  request: Request,
  max: number,
): Promise<unknown | "too_large" | "bad"> {
  const declared = Number(request.headers.get("Content-Length"));
  if (Number.isFinite(declared) && declared > max) return "too_large";
  const reader = request.body?.getReader();
  if (!reader) return "bad";
  const parts: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const chunk = await reader.read();
    if (chunk.done) break;
    size += chunk.value.byteLength;
    if (size > max) {
      await reader.cancel();
      return "too_large";
    }
    parts.push(chunk.value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const part of parts) {
    bytes.set(part, offset);
    offset += part.byteLength;
  }
  try {
    return JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    return "bad";
  }
}

/**
 * Workers AI on the Free plan refuses calls once the daily 10,000 Neurons are
 * used (error 4006). The account is never charged; we just stop for the day.
 */
export function isAllocationExhausted(error: unknown): boolean {
  const text = error instanceof Error ? error.message : String(error);
  // Anchored to the start of the message: later parts of an error may echo
  // user content, which must not switch the AI off for everybody.
  return /^(?:[A-Za-z]*Error:\s*)?4006:[^\n]*daily free allocation/i.test(text);
}

/**
 * Calls the model at most twice. Retries on a throw, unusable output or fewer
 * than half of the requested words; keeps the better attempt. Returns null when
 * both attempts fail, "exhausted" when the free daily allocation is used up.
 */
async function generate(
  env: Env,
  topic: string,
  count: number,
  now: Date,
): Promise<WordEntry[] | null | "exhausted"> {
  const model = env.MODEL || DEFAULT_MODEL;
  const n = askCount(count);
  const input = {
    messages: [
      { role: "system", content: WORDS_SYSTEM },
      { role: "user", content: wordsUser(topic, n) },
    ],
    guided_json: wordsSchema(n),
    max_tokens: 2_500,
    temperature: 0.7,
  };
  let best: WordEntry[] | null = null;
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const out = (await env.AI.run(model, input)) as { response?: unknown };
      const words = validateWords(out?.response, count);
      if (words !== null && (best === null || words.length > best.length)) {
        best = words;
      }
      if (best !== null && best.length * 2 >= count) return best;
    } catch (error) {
      // Error details may contain user content; do not log them.
      if (isAllocationExhausted(error)) {
        try {
          await markExhausted(env.QUOTA, now);
        } catch {
          // The 429 still holds; the next call will just try the model again.
        }
        return best ?? "exhausted";
      }
    }
  }
  return best;
}

export async function handle(
  request: Request,
  env: Env,
  now: Date,
): Promise<Response> {
  const origin = request.headers.get("Origin");
  if (!allowedOrigin(origin)) {
    return fail("forbidden", "Přístup z tohoto webu není povolen.", 403, null);
  }
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(origin) });
  }
  if (new URL(request.url).pathname !== "/words") {
    return fail("not_found", "Neznámá adresa.", 404, origin);
  }
  if (request.method !== "POST") {
    return fail("bad_request", "Použij POST.", 405, origin);
  }

  const body = await readJson(request, MAX_BODY);
  if (body === "too_large") {
    return fail("too_large", "Požadavek je moc velký.", 413, origin);
  }
  if (body === "bad") {
    return fail("bad_request", "Neplatný požadavek.", 400, origin);
  }
  const parsed = parseWordsRequest(body);
  if (typeof parsed === "string") {
    return fail("bad_request", parsed, 400, origin);
  }

  if (await isExhausted(env.QUOTA, now)) return exhausted(origin);

  const quota = await reserve(
    env.QUOTA,
    {
      perInstall: limitOf(env.WORDS_PER_INSTALL, 15),
      global: limitOf(env.GLOBAL_DAILY_CAP, 150),
    },
    parsed.installId,
    now,
  );
  if (quota === "install") {
    return fail(
      "quota_install",
      "Dnešní limit AI témat je vyčerpaný. Zkus to zítra, nebo hraj s vestavěnými balíčky.",
      429,
      origin,
    );
  }
  if (quota === "global") return exhausted(origin);

  const words = await generate(env, parsed.topic, parsed.count, now);
  if (words === "exhausted") return exhausted(origin);
  if (words === null) {
    return fail(
      "ai_failed",
      "AI teď slova nevymyslela. Zkus to znovu nebo jiné téma.",
      502,
      origin,
    );
  }
  return json({ words }, 200, origin);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      return await handle(request, env, new Date());
    } catch (error) {
      const origin = request.headers.get("Origin");
      const kvBusy =
        error instanceof Error &&
        /^KV (?:PUT|GET) failed: 429\b/.test(error.message);
      return fail(
        kvBusy ? "service_busy" : "ai_failed",
        kvBusy
          ? "Služba je teď vytížená. Zkus to za chvíli."
          : "Služba teď nefunguje. Zkus to později.",
        kvBusy ? 503 : 500,
        allowedOrigin(origin) ? origin : null,
      );
    }
  },
};
