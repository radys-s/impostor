# Impostor

Free Czech party game for one phone passed around the table. Everyone sees the
secret word except the impostor. No ads, no in-app purchases, no account.

The app is an assistant, not a judge: by default it deals cards, picks who
starts, runs the timer and reveals the impostor. Nobody is scored.

## Features

- Startup context picker on every launch: **Rodina**, **Kamarádi** (13+),
  **Mix všeho** (18+), **Freaky** (18+). The context filters word packs and
  re-tints the whole app. Change it any time from the home screen.
- 34 built-in Czech packs (2 300+ words), each tagged `family`, `friends` or `adult`.
- Custom packs: create, edit, copy a built-in pack.
- Variants: impostor hint, undercover (similar word), several or a random number
  of impostors, chaos (sometimes nobody or everybody), discussion timer.
- Works fully offline.

### Plugin store (the only online part)

| Plugin | What it adds |
| --- | --- |
| Skóre a žebříček (`skore`) | Points per round and a leaderboard |
| Tajné hlasování (`hlasovani`) | Secret pass-the-phone voting; app decides the winner |
| AI témata (`ai-temata`) | Generate words for any topic via the `worker/` Cloudflare Worker |
| Word packs | Downloaded from `store/catalog.json` in this repo |

Feature plugins ship inside the app and are only switched on from the store.
Word packs are fetched from `https://raw.githubusercontent.com/radys-s/impostor/main/`.

## Development

```bash
flutter pub get
flutter analyze
flutter test
python tool/validate_packs.py
flutter build web --release
```

Flutter 3.47.2. Optional build defines: `--dart-define=AI_URL=https://…`
(AI worker) and `--dart-define=STORE_URL=https://…/` (store base URL).

## iPhone (unsigned IPA for sideloading)

Run the **iPhone beta for local sideloading** workflow (`workflow_dispatch`)
on GitHub Actions. It builds on macOS without Apple credentials, verifies the
bundle (`cz.radys.impostor`, iPhoneOS, arm64) and uploads
`impostor-1.0.0-unsigned.ipa` plus `SHA256.txt`. Re-sign and install it with
iLoader on Windows.

## AI worker

See `worker/README.md`. Deploying needs your own Cloudflare account
(`npx wrangler login`), a KV namespace id in `worker/wrangler.toml`, then
`npx wrangler deploy`. Put the worker URL into `AI_URL` in the iOS workflow.
