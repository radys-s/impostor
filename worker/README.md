# Impostor AI (Cloudflare Worker)

Word generator for the Impostor party game. The app sends a topic; the Worker
asks Cloudflare Workers AI for Czech secret words with an impostor hint and a
similar word, validates and dedupes them, and returns JSON. The app holds no
secret or API key. Topics and words are not logged or stored; only daily
counters per install ID live in KV for two days.

Model: `@cf/mistralai/mistral-small-3.1-24b-instruct` (Apache 2.0). Swap via
the `MODEL` variable (e.g. `@cf/google/gemma-3-12b-it`).

## API

`POST /words`, JSON body:

```json
{ "topic": "zvířata", "count": 30, "installId": "0b9f5c2e-6f1a-4c3d-9e8b-1a2b3c4d5e6f" }
```

- `topic`: string, 1–80 characters after trimming.
- `count`: integer 10–50, optional, default 30.
- `installId`: UUID the app generates once per install.

Success `200`:

```json
{ "words": [ { "word": "Lední medvěd", "hint": "zima", "similar": "tučňák" } ] }
```

- `word`: secret word, 1–3 words, nominative.
- `hint`: one vague word for the impostor; never equal to or part of `word`.
- `similar`: a related but different word for undercover mode; never equal to `word`.

At most `count` entries; can be fewer when the model produced too few valid
ones (the Worker retries once when it gets less than half).

Errors: `{"error": {"code", "message"}}` with a Czech `message` the app can
show as is.

| Status | code | Meaning |
|---|---|---|
| 400 | `bad_request` | invalid JSON, topic, count or install ID |
| 403 | `forbidden` | browser origin other than localhost |
| 404 | `not_found` | unknown path |
| 405 | `bad_request` | method other than POST |
| 413 | `too_large` | body over 4 KB |
| 429 | `quota_install` | this install used its daily requests |
| 429 | `quota_global` | daily cap for everybody, or the free Workers AI allocation is used up (error 4006) |
| 502 | `ai_failed` | model failed twice or returned nothing usable |
| 503 | `service_busy` | temporary KV throttling; try shortly |

## Limits and cost

`wrangler.toml` `[vars]`:

- `WORDS_PER_INSTALL` = 15 requests per install per UTC day.
- `GLOBAL_DAILY_CAP` = 150 reserved model calls per UTC day for everybody.
  Each accepted request reserves two calls upfront (first try and retry), so
  150 permits about 75 requests per day.

KV is eventually consistent and allows one write per key per second, so
counters can undercount concurrent requests, and install IDs can be changed.
These limits are soft abuse protection for a public repo, not authentication.
The cost boundary is the Workers **Free** plan: it has no payment method and
cannot be charged. When the daily 10,000 Neurons run out, Workers AI fails with
error 4006; the Worker marks the day as exhausted in KV and answers
`429 quota_global` without calling the model until the next UTC day.

CORS: native apps send no `Origin` and are always allowed. Browser requests
are allowed only from `localhost`, `127.0.0.1` and `[::1]` on any port (Flutter
web preview). Other origins get `403`.

## Develop

```bash
npm install
npm test
npm run typecheck
```

`wrangler dev` and `wrangler deploy` need the `workerd` and `esbuild`
postinstall scripts. If npm reports them as not covered by `allowScripts`,
approve them once:

```bash
npm approve-scripts workerd esbuild
```

## Deploy (Workers Free plan, new account)

1. Create a Cloudflare account on the **Free** plan. Do not add a payment method.
2. Log in from this folder:

   ```bash
   npx wrangler login
   ```

3. Create the KV namespace:

   ```bash
   npx wrangler kv namespace create QUOTA
   ```

4. Replace `REPLACE_WITH_KV_NAMESPACE_ID` in `wrangler.toml` with the returned
   `id`. The id is not a secret.
5. Deploy:

   ```bash
   npx wrangler deploy
   ```

6. Smoke test (replace the URL with the one wrangler printed):

   ```bash
   curl -s -X POST https://impostor-ai.<subdomain>.workers.dev/words -H "Content-Type: application/json" -d "{\"topic\":\"zvířata\",\"count\":10,\"installId\":\"0b9f5c2e-6f1a-4c3d-9e8b-1a2b3c4d5e6f\"}"
   ```

7. Put the Worker URL into the Flutter app configuration.

Redeploy after changes with `npx wrangler deploy`.
