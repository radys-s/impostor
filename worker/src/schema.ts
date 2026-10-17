// Request and model-output validation. Pure functions, no Workers APIs.

export interface WordEntry {
  word: string;
  hint: string;
  similar: string;
}

export interface WordsRequest {
  topic: string;
  count: number;
  installId: string;
}

export const MAX_TOPIC = 80;
export const MIN_COUNT = 10;
export const MAX_COUNT = 50;
export const DEFAULT_COUNT = 30;
export const MAX_WORD_LEN = 40;
export const MAX_WORD_PARTS = 3;

const INSTALL_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const isObj = (v: unknown): v is Record<string, unknown> =>
  typeof v === "object" && v !== null && !Array.isArray(v);

/** Single line, trimmed, no control characters (prompt hygiene). */
export function cleanText(v: unknown, max: number): string | null {
  if (typeof v !== "string") return null;
  const s = v
    .replace(/[\u0000-\u001f\u007f]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  if (s.length === 0) return null;
  return s.length > max ? s.slice(0, max).trim() : s;
}

/** Comparison key: case- and diacritics-insensitive, whitespace collapsed. */
export function normalizeKey(s: string): string {
  return s
    .normalize("NFD")
    .replace(/\p{M}+/gu, "")
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim();
}

// ---- request ----

export function parseWordsRequest(body: unknown): WordsRequest | string {
  if (!isObj(body)) return "Neplatný požadavek.";
  if (typeof body.installId !== "string" || !INSTALL_RE.test(body.installId)) {
    return "Chybí identifikátor aplikace.";
  }
  if (typeof body.topic !== "string") return "Zadej téma.";
  const topic = cleanText(body.topic, Number.MAX_SAFE_INTEGER);
  if (topic === null) return "Zadej téma.";
  if (topic.length > MAX_TOPIC) {
    return `Téma může mít nejvýš ${MAX_TOPIC} znaků.`;
  }
  let count = DEFAULT_COUNT;
  if (body.count !== undefined && body.count !== null) {
    if (
      typeof body.count !== "number" ||
      !Number.isInteger(body.count) ||
      body.count < MIN_COUNT ||
      body.count > MAX_COUNT
    ) {
      return `Počet slov musí být celé číslo od ${MIN_COUNT} do ${MAX_COUNT}.`;
    }
    count = body.count;
  }
  return { topic, count, installId: body.installId.toLowerCase() };
}

// ---- model output ----

function tryParse(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return undefined;
  }
}

/**
 * Model text to a list of raw entries. Tolerates ```json fences, text around
 * the JSON, a bare array instead of `{words: [...]}`, and output cut off by
 * max_tokens (then the complete flat objects are salvaged one by one).
 */
export function extractEntries(raw: unknown): unknown[] | null {
  const pick = (v: unknown): unknown[] | null => {
    if (Array.isArray(v)) return v;
    if (isObj(v)) {
      for (const key of ["words", "slova", "items", "entries"]) {
        if (Array.isArray(v[key])) return v[key] as unknown[];
      }
    }
    return null;
  };
  const direct = pick(raw);
  if (direct) return direct;
  if (typeof raw !== "string") return null;

  const fenced = raw.match(/```(?:json)?\s*([\s\S]*?)(?:```|$)/);
  const text = fenced ? fenced[1] : raw;
  for (const [open, close] of [
    ["{", "}"],
    ["[", "]"],
  ]) {
    const start = text.indexOf(open);
    const end = text.lastIndexOf(close);
    if (start >= 0 && end > start) {
      const found = pick(tryParse(text.slice(start, end + 1)));
      if (found) return found;
    }
  }
  const salvaged = (text.match(/\{[^{}]*\}/g) ?? [])
    .map(tryParse)
    .filter(isObj);
  return salvaged.length > 0 ? salvaged : null;
}

function field(v: Record<string, unknown>, keys: string[]): unknown {
  for (const k of keys) if (v[k] !== undefined) return v[k];
  return undefined;
}

/** Trims quotes and sentence punctuation the model likes to add. */
function cleanWord(v: unknown): string | null {
  const s = cleanText(v, 200);
  if (s === null) return null;
  const t = s.replace(/^["'„“‚‘«»\s.,;:!?-]+|["'“”‘’«»\s.,;:!?-]+$/g, "");
  if (t.length === 0 || t.length > MAX_WORD_LEN) return null;
  // Letters (any script, incl. Czech diacritics), digits, space, hyphen, apostrophe.
  if (!/^[\p{L}\p{N}][\p{L}\p{N} '’-]*$/u.test(t)) return null;
  if (!/\p{L}/u.test(t)) return null;
  return t;
}

const parts = (s: string) => normalizeKey(s).split(" ").filter(Boolean);

function entry(v: unknown): WordEntry | null {
  if (!isObj(v)) return null;
  const word = cleanWord(field(v, ["word", "slovo"]));
  const hint = cleanWord(field(v, ["hint", "napoveda", "nápověda"]));
  const similar = cleanWord(field(v, ["similar", "podobne", "podobné"]));
  if (word === null || hint === null || similar === null) return null;
  const w = parts(word);
  const h = parts(hint);
  const s = parts(similar);
  if (w.length === 0 || w.length > MAX_WORD_PARTS) return null;
  if (h.length !== 1 || s.length === 0 || s.length > MAX_WORD_PARTS) {
    return null;
  }
  const wk = w.join(" ");
  if (h[0] === wk || s.join(" ") === wk) return null;
  // The hint must not give the word away by sharing a part with it.
  if (w.includes(h[0])) return null;
  return { word, hint, similar };
}

/**
 * Validates, dedupes (case/diacritics-insensitive) and caps the model's word
 * list. Returns null when nothing usable came back.
 */
export function validateWords(
  raw: unknown,
  count: number,
): WordEntry[] | null {
  const list = extractEntries(raw);
  if (list === null) return null;
  const seen = new Set<string>();
  const words: WordEntry[] = [];
  for (const v of list) {
    const e = entry(v);
    if (e === null) continue;
    const key = normalizeKey(e.word);
    if (seen.has(key)) continue;
    seen.add(key);
    words.push(e);
    if (words.length === count) break;
  }
  return words.length > 0 ? words : null;
}

// ---- guided_json schema for the model ----

export function wordsSchema(n: number) {
  return {
    type: "object",
    properties: {
      words: {
        type: "array",
        minItems: 1,
        maxItems: n,
        items: {
          type: "object",
          properties: {
            word: { type: "string" },
            hint: { type: "string" },
            similar: { type: "string" },
          },
          required: ["word", "hint", "similar"],
        },
      },
    },
    required: ["words"],
  };
}
