import { describe, expect, it } from "vitest";

import worker, {
  allowedOrigin,
  handle,
  isAllocationExhausted,
  type Env,
} from "../src/index";
import { reserve, type QuotaStore } from "../src/quota";
import {
  extractEntries,
  normalizeKey,
  parseWordsRequest,
  validateWords,
} from "../src/schema";

const INSTALL = "0b9f5c2e-6f1a-4c3d-9e8b-1a2b3c4d5e6f";
const NOW = new Date("2026-10-17T12:00:00Z");

class MemoryKv implements QuotaStore {
  data = new Map<string, string>();
  async get(key: string) {
    return this.data.get(key) ?? null;
  }
  async put(key: string, value: string) {
    this.data.set(key, value);
  }
}

type Reply = unknown | Error;

function makeEnv(replies: Reply[], vars: Partial<Env> = {}) {
  const calls: { model: string; input: Record<string, unknown> }[] = [];
  const kv = new MemoryKv();
  const env: Env = {
    AI: {
      async run(model, input) {
        calls.push({ model, input });
        const next = replies.shift();
        if (next instanceof Error) throw next;
        return next;
      },
    },
    QUOTA: kv,
    ...vars,
  };
  return { env, calls, kv };
}

function post(
  body: unknown,
  headers: Record<string, string> = {},
  path = "/words",
): Request {
  return new Request(`https://ai.example${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", ...headers },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

/** n distinct valid entries. */
function entries(n: number, offset = 0) {
  const nouns = [
    "pes", "kočka", "kůň", "kráva", "ovce", "koza", "prase", "slepice",
    "kachna", "husa", "králík", "myš", "liška", "vlk", "medvěd", "jelen",
    "srna", "zajíc", "ježek", "veverka", "sova", "orel", "čáp", "vrabec",
    "kapr", "štika", "pstruh", "žába", "had", "ještěrka", "motýl", "včela",
    "mravenec", "pavouk", "slon", "žirafa", "lev", "tygr", "zebra", "opice",
    "velbloud", "tučňák", "delfín", "žralok", "velryba", "krokodýl", "papoušek",
    "klokan", "koala", "panda", "nosorožec", "hroch", "lama", "bobr", "vydra",
    "jezevec", "kuna", "rys", "los", "bizon",
  ];
  return nouns.slice(offset, offset + n).map((word, i) => ({
    word,
    hint: "zvíře",
    similar: nouns[(offset + i + 1) % nouns.length],
  }));
}

const reply = (list: unknown[]) => ({
  response: JSON.stringify({ words: list }),
});

const goodBody = { topic: "zvířata", count: 10, installId: INSTALL };

describe("parseWordsRequest", () => {
  it("accepts a valid request and defaults count to 30", () => {
    expect(parseWordsRequest({ topic: "  zvířata ", installId: INSTALL }))
      .toEqual({ topic: "zvířata", count: 30, installId: INSTALL });
  });

  it("rejects bad input with Czech messages", () => {
    const bad: unknown[] = [
      null,
      [],
      { topic: "x" },
      { topic: "x", installId: "nope" },
      { topic: "", installId: INSTALL },
      { topic: "   ", installId: INSTALL },
      { topic: 5, installId: INSTALL },
      { topic: "a".repeat(81), installId: INSTALL },
      { topic: "x", installId: INSTALL, count: 9 },
      { topic: "x", installId: INSTALL, count: 51 },
      { topic: "x", installId: INSTALL, count: 12.5 },
      { topic: "x", installId: INSTALL, count: "20" },
    ];
    for (const b of bad) {
      const r = parseWordsRequest(b);
      expect(typeof r, JSON.stringify(b)).toBe("string");
      expect(r as string).toMatch(/[áčéěíňóřšťúůýž]|Zadej|Neplatný/i);
    }
  });

  it("accepts boundary values", () => {
    const ok = (b: object) =>
      parseWordsRequest({ topic: "a".repeat(80), installId: INSTALL, ...b });
    expect(ok({ count: 10 })).toMatchObject({ count: 10 });
    expect(ok({ count: 50 })).toMatchObject({ count: 50 });
  });

  it("collapses control characters in the topic", () => {
    const r = parseWordsRequest({ topic: "a\nb\tc", installId: INSTALL });
    expect(r).toMatchObject({ topic: "a b c" });
  });
});

describe("extractEntries", () => {
  const list = [{ word: "pes", hint: "zvíře", similar: "vlk" }];

  it("reads an object, a bare array and the words wrapper", () => {
    expect(extractEntries({ words: list })).toEqual(list);
    expect(extractEntries(list)).toEqual(list);
    expect(extractEntries(JSON.stringify(list))).toEqual(list);
  });

  it("strips fences and surrounding chatter", () => {
    const raw =
      "Jasně, tady jsou slova:\n```json\n" +
      JSON.stringify({ words: list }) +
      "\n```\nHodně štěstí!";
    expect(extractEntries(raw)).toEqual(list);
  });

  it("salvages complete objects from truncated output", () => {
    const raw =
      '{"words":[{"word":"pes","hint":"zvíře","similar":"vlk"},' +
      '{"word":"kočka","hint":"mazlíček","similar":"rys"},{"word":"ků';
    expect(extractEntries(raw)).toEqual([
      list[0],
      { word: "kočka", hint: "mazlíček", similar: "rys" },
    ]);
  });

  it("returns null for garbage", () => {
    expect(extractEntries("nevím")).toBeNull();
    expect(extractEntries(42)).toBeNull();
    expect(extractEntries(undefined)).toBeNull();
  });
});

describe("validateWords", () => {
  it("dedupes case- and diacritics-insensitively", () => {
    const out = validateWords(
      {
        words: [
          { word: "Kočka", hint: "zvíře", similar: "pes" },
          { word: "kocka", hint: "zvíře", similar: "rys" },
          { word: "KOČKA ", hint: "zvíře", similar: "lev" },
          { word: "Pes", hint: "zvíře", similar: "vlk" },
        ],
      },
      10,
    );
    expect(out?.map((w) => w.word)).toEqual(["Kočka", "Pes"]);
  });

  it("drops entries whose hint or similar equals or reveals the word", () => {
    const out = validateWords(
      [
        { word: "Pizza", hint: "pizza", similar: "těstoviny" },
        { word: "Pizza", hint: "jídlo", similar: "PIZZA" },
        { word: "Lední medvěd", hint: "medvěd", similar: "tučňák" },
        { word: "Šťáva", hint: "nápoj", similar: "stava" },
        { word: "Hranolky", hint: "jídlo", similar: "chipsy" },
      ],
      10,
    );
    expect(out).toEqual([
      { word: "Hranolky", hint: "jídlo", similar: "chipsy" },
    ]);
  });

  it("enforces shape: 1-3 word secret, one-word hint", () => {
    const out = validateWords(
      [
        { word: "Velká černá kočka v noci", hint: "zvíře", similar: "pes" },
        { word: "Pes", hint: "domácí zvíře", similar: "vlk" },
        { word: "Pes", hint: "", similar: "vlk" },
        { word: "Pes", hint: "zvíře" },
        { word: "<script>", hint: "kód", similar: "html" },
        { word: "1234", hint: "číslo", similar: "5678" },
        "pes",
        { word: "„Karlův most“.", hint: "Praha", similar: "Staroměstská věž" },
      ],
      10,
    );
    expect(out).toEqual([
      { word: "Karlův most", hint: "Praha", similar: "Staroměstská věž" },
    ]);
  });

  it("accepts Czech key aliases", () => {
    expect(
      validateWords([{ slovo: "Pes", napoveda: "zvíře", podobne: "vlk" }], 10),
    ).toEqual([{ word: "Pes", hint: "zvíře", similar: "vlk" }]);
  });

  it("caps at count and returns null when nothing is usable", () => {
    expect(validateWords({ words: entries(40) }, 25)).toHaveLength(25);
    expect(validateWords({ words: [] }, 10)).toBeNull();
    expect(validateWords("bla", 10)).toBeNull();
  });

  it("normalizeKey folds case, diacritics and punctuation", () => {
    expect(normalizeKey("  Žluťoučký-KŮŇ! ")).toBe("zlutoucky kun");
  });
});

describe("quota", () => {
  it("reserves per install and two calls globally", async () => {
    const kv = new MemoryKv();
    const limits = { perInstall: 2, global: 100 };
    expect(await reserve(kv, limits, INSTALL, NOW)).toBe("ok");
    expect(await reserve(kv, limits, INSTALL, NOW)).toBe("ok");
    expect(await reserve(kv, limits, INSTALL, NOW)).toBe("install");
    expect(kv.data.get("g:2026-10-17")).toBe("4");
    // Next UTC day starts fresh.
    const tomorrow = new Date("2026-10-18T00:00:01Z");
    expect(await reserve(kv, limits, INSTALL, tomorrow)).toBe("ok");
  });

  it("stops everybody at the global cap", async () => {
    const kv = new MemoryKv();
    const limits = { perInstall: 10, global: 3 };
    const other = "11111111-2222-4333-8444-555555555555";
    expect(await reserve(kv, limits, INSTALL, NOW)).toBe("ok");
    expect(await reserve(kv, limits, other, NOW)).toBe("global");
  });
});

describe("POST /words", () => {
  it("returns validated words and asks the model in Czech with JSON", async () => {
    const { env, calls } = makeEnv([reply(entries(15))]);
    const res = await handle(post(goodBody), env, NOW);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { words: unknown[] };
    expect(body.words).toHaveLength(10);
    expect(body.words[0]).toEqual({ word: "pes", hint: "zvíře", similar: "kočka" });
    expect(calls).toHaveLength(1);
    expect(calls[0].model).toBe("@cf/mistralai/mistral-small-3.1-24b-instruct");
    const input = calls[0].input as {
      messages: { role: string; content: string }[];
      guided_json: unknown;
    };
    expect(input.guided_json).toBeTruthy();
    expect(input.messages[0].content).toContain("česky");
    expect(input.messages[1].content).toContain("zvířata");
    expect(res.headers.get("Access-Control-Allow-Origin")).toBeNull();
  });

  it("uses the MODEL variable", async () => {
    const { env, calls } = makeEnv([reply(entries(15))], {
      MODEL: "@cf/google/gemma-3-12b-it",
    });
    await handle(post(goodBody), env, NOW);
    expect(calls[0].model).toBe("@cf/google/gemma-3-12b-it");
  });

  it("returns 400 with a Czech message for bad input, without quota use", async () => {
    const { env, calls, kv } = makeEnv([]);
    for (const b of [
      { ...goodBody, topic: "" },
      { ...goodBody, count: 5 },
      { ...goodBody, installId: "x" },
      "{not json",
    ]) {
      const res = await handle(post(b), env, NOW);
      expect(res.status).toBe(400);
      const body = (await res.json()) as { error: { code: string; message: string } };
      expect(body.error.code).toBe("bad_request");
      expect(body.error.message.length).toBeGreaterThan(0);
    }
    expect(calls).toHaveLength(0);
    expect(kv.data.size).toBe(0);
  });

  it("rejects oversize bodies, wrong method and unknown paths", async () => {
    const { env } = makeEnv([]);
    const big = { ...goodBody, pad: "x".repeat(5_000) };
    expect((await handle(post(big), env, NOW)).status).toBe(413);
    expect(
      (await handle(new Request("https://ai.example/words"), env, NOW)).status,
    ).toBe(405);
    expect((await handle(post(goodBody, {}, "/v1/x"), env, NOW)).status).toBe(404);
  });

  it("retries once on garbage and returns 502 when both fail", async () => {
    const { env, calls } = makeEnv([{ response: "nevím" }, new Error("boom")]);
    const res = await handle(post(goodBody), env, NOW);
    expect(res.status).toBe(502);
    expect(((await res.json()) as { error: { code: string } }).error.code)
      .toBe("ai_failed");
    expect(calls).toHaveLength(2);
  });

  it("retries a thin answer and keeps the better attempt", async () => {
    const { env, calls } = makeEnv([reply(entries(3)), reply(entries(12, 20))]);
    const res = await handle(post(goodBody), env, NOW);
    const body = (await res.json()) as { words: { word: string }[] };
    expect(calls).toHaveLength(2);
    expect(body.words).toHaveLength(10);
    expect(body.words[0].word).toBe("sova");
  });

  it("returns a thin answer when the retry is worse", async () => {
    const { env } = makeEnv([reply(entries(3)), { response: "" }]);
    const res = await handle(post(goodBody), env, NOW);
    expect(res.status).toBe(200);
    expect(((await res.json()) as { words: unknown[] }).words).toHaveLength(3);
  });

  it("answers 429 quota_install after WORDS_PER_INSTALL requests", async () => {
    const replies = Array.from({ length: 3 }, () => reply(entries(15)));
    const { env, calls } = makeEnv(replies, { WORDS_PER_INSTALL: "2" });
    expect((await handle(post(goodBody), env, NOW)).status).toBe(200);
    expect((await handle(post(goodBody), env, NOW)).status).toBe(200);
    const res = await handle(post(goodBody), env, NOW);
    expect(res.status).toBe(429);
    expect(((await res.json()) as { error: { code: string } }).error.code)
      .toBe("quota_install");
    expect(calls).toHaveLength(2);
  });

  it("answers 429 quota_global at GLOBAL_DAILY_CAP", async () => {
    const { env, calls } = makeEnv([reply(entries(15))], {
      GLOBAL_DAILY_CAP: "3",
    });
    expect((await handle(post(goodBody), env, NOW)).status).toBe(200);
    const other = { ...goodBody, installId: "11111111-2222-4333-8444-555555555555" };
    const res = await handle(post(other), env, NOW);
    expect(res.status).toBe(429);
    expect(((await res.json()) as { error: { code: string } }).error.code)
      .toBe("quota_global");
    expect(calls).toHaveLength(1);
  });

  it("marks the day exhausted after error 4006 and stops calling the model", async () => {
    const err = new Error(
      "4006: you have used up your daily free allocation of 10,000 neurons",
    );
    const { env, calls, kv } = makeEnv([err]);
    const res = await handle(post(goodBody), env, NOW);
    expect(res.status).toBe(429);
    expect(((await res.json()) as { error: { code: string } }).error.code)
      .toBe("quota_global");
    expect(kv.data.get("x:2026-10-17")).toBe("1");
    expect(calls).toHaveLength(1);
    const again = await handle(post(goodBody), env, NOW);
    expect(again.status).toBe(429);
    expect(calls).toHaveLength(1);
  });

  it("does not treat echoed user content as error 4006", () => {
    expect(isAllocationExhausted(new Error("4006: daily free allocation"))).toBe(true);
    expect(
      isAllocationExhausted(new Error("bad input: 4006: daily free allocation")),
    ).toBe(false);
  });
});

describe("CORS", () => {
  it("allows native apps and localhost origins only", () => {
    expect(allowedOrigin(null)).toBe(true);
    expect(allowedOrigin("http://localhost:5555")).toBe(true);
    expect(allowedOrigin("http://127.0.0.1:8080")).toBe(true);
    expect(allowedOrigin("http://localhost")).toBe(true);
    expect(allowedOrigin("https://evil.example")).toBe(false);
    expect(allowedOrigin("http://localhost.evil.example")).toBe(false);
  });

  it("answers preflight for localhost and 403 for other sites", async () => {
    const { env } = makeEnv([]);
    const pre = await handle(
      new Request("https://ai.example/words", {
        method: "OPTIONS",
        headers: { Origin: "http://localhost:5555" },
      }),
      env,
      NOW,
    );
    expect(pre.status).toBe(204);
    expect(pre.headers.get("Access-Control-Allow-Origin")).toBe(
      "http://localhost:5555",
    );
    const evil = await handle(
      post(goodBody, { Origin: "https://evil.example" }),
      env,
      NOW,
    );
    expect(evil.status).toBe(403);
    expect(evil.headers.get("Access-Control-Allow-Origin")).toBeNull();
  });

  it("maps KV throttling to 503 service_busy via the default export", async () => {
    const { env } = makeEnv([]);
    env.QUOTA = {
      async get() {
        throw new Error("KV GET failed: 429 Too Many Requests");
      },
      async put() {},
    };
    const res = await worker.fetch(post(goodBody), env);
    expect(res.status).toBe(503);
  });
});
