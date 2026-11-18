# UX audit, November 2026

Goal: make Impostor more fun and smoother at a real table: fewer taps, no
accidental peeks, clearer screens. No new features.

Method: built the web target (`flutter build web --release`) from `main` at
`a462965` and walked every main journey in a browser at phone width
(360 × 740) in light and dark mode, and at desktop width (1280 × 800). I
counted taps, read every UI string as a Czech player would, and checked
keyboard use on desktop. Earlier passes (`cf717b8`, `16ee760`, `07133f8`)
already fixed the reveal flow, added the double-tap lock after hiding a card,
the "forgot my word" peek, the done card and presets; this audit builds on
them and does not undo them.

Screenshots of the state before the fixes are in
[`docs/screenshots/`](screenshots/) (`audit-*.png`).

## Tap counts before

| Journey | Taps (typing not counted) |
| --- | --- |
| First launch → first card dealt, 4 players | 9: context, players tile, **focus the name field**, 4 × Enter, Hotovo, Rozdat karty |
| Returning user → first card dealt | 2: context, Rozdat karty |
| One round, 4 players, verbal vote | 11: Rozdat karty / Další kolo, 2 per player (show, hide), Začít kolo, Odhalit impostora |
| Undo an accidental "remove player" | 3+ and typing: focus field, retype the name, drag it back to its seat |
| Custom pack with 10 words | 24: Témata, Nové téma, name field, 10 × (Slovo, Hotovo), Uložit |
| Keyboard only (desktop): get past the context picker | impossible: Tab and Enter do nothing |

## Friction points

Each item: what happens, the evidence, and the effort (S < half a day,
M ≈ a day, L more).

1. **The impostor's card is a different colour from everyone else's.**
   Civilians see a pale beige card (near black in dark mode). The impostor gets
   a full-screen red-pink gradient with a pulsing red glow; the detective
   (blue) and jester (yellow-green) cards also have their own colours. At a
   table, and above all in a dark room, the colour lights up the holder's face
   and can be seen from the side, so the role leaks without anyone reading the
   screen. Evidence: `audit-deal-light.png`, `audit-deal-dark.png`; after the
   fix: `role-card-after-light.png`, `role-card-after-dark.png`. Effort S.
2. **One tap on "Odhalit impostora" ends the round.** The round screen sits in
   the middle of the table for the whole discussion. Its big button is in the
   same spot as "Ukázat kartu" / "Mám to, skrýt" / "Začít kolo", which everyone
   has just tapped repeatedly. A stray tap or a quick triple tap from the last
   player reveals the impostor and the word, and there is no way back.
   Evidence: `audit-round.png`, `RoundScreen._finish`. Effort S.
3. **No keyboard access, and tiles do not announce themselves as buttons.**
   `Pressable` (used by every context tile, home tile, pack tile and the main
   gradient button) is a bare `GestureDetector`. It cannot take focus, shows no
   focus ring, and does not react to Enter or Space, so on desktop the app
   cannot be used past the first screen without a mouse. Screen readers get no
   button role for the context and home tiles. Evidence: `audit-desktop-tab.png`
   (Tab ×3 + Enter, nothing happens). Effort S–M.
4. **Players screen: name field is not focused, and removing has no undo.**
   Every visit starts with an extra tap into the field. The remove (×) button
   sits next to the drag handle; one slip deletes a player and getting them back
   means retyping and dragging them to their seat. Evidence:
   `audit-players-empty.png`, `audit-players.png`. Effort S.
5. **An extra "Všichni mají kartu → Začít kolo" stop every round.** After the
   last player hides their card, the app shows a done card that says "Aplikace
   řekne, kdo začíná" and needs another tap before it does. The round screen
   already shows who starts in large type. One extra tap per round, on the
   screen people see most. Evidence: `audit-deal-done.png`. Effort S
   (safe only together with item 2; otherwise the last player's double tap
   lands on the reveal button).
6. **The discussion timer stalls when the phone locks or the app is in the
   background**, because it counts ticks instead of comparing with a deadline.
   The screen is also allowed to auto-lock while the phone lies on the table,
   and time-up is signalled only by vibration and red digits, which are easy to
   miss in a loud room. Evidence: `_RoundScreenState._toggleTimer`.
   Effort S for the deadline, M with a wake lock (needs a new plugin).
7. **Adding words to a custom pack takes a dialog per word.** Enter in the
   "Tajné slovo" field does nothing; only the third, optional field submits.
   Ten words cost 20 taps. Effort S (Enter submits and reopens) to M (inline
   quick-add field like on the players screen).
8. **The AI plugin can be installed while its server is not set up.** The store
   card says "Server zatím není zapojený" yet offers "Přidat"; after installing,
   every attempt ends in an error. Evidence: `audit-store.png`. Effort S.
9. **Small or low-contrast text for arm's length.** Hints such as "Klepni na
   jméno a přejmenuj · táhni a změň pořadí" are 12 px grey; the selected
   ChoiceChip (pale yellow on beige) is hard to tell from the others in the
   Kamarádi theme; pack subtitles are grey on beige. Evidence:
   `audit-options.png`, `audit-players.png`. Effort M (touches the theme).
10. **Desktop width stretches everything edge to edge.** Tiles and buttons
    become 1,250 px wide bars. Evidence: `audit-desktop-tab.png`. Effort S
    (cap the content width).

Smaller notes, not ranked:

- The context picker opens on every launch (one extra tap for returning
  players). This is a deliberate product decision in the README, so it stays.
- "Někdo zapomněl slovo" is an eye icon without a label in the app bar; it
  works, but new players do not find it.
- Flutter web needs the hidden "Enable accessibility" button before a screen
  reader sees anything; that is standard Flutter behaviour.
- The pack list's "Nové téma" button covers the last pack's checkbox until
  you scroll to the very end.

## Ranking: impact ÷ effort

| Rank | Friction item | Fix | Impact | Effort | Do now |
| --- | --- | --- | --- | --- | --- |
| 1 | 1 | Same card for every role (no colour tell) | High: breaks the game | S | yes |
| 2 | 2 | Deliberate reveal (hold to reveal) | High: spoils a round | S | yes |
| 3 | 4 | Players: autofocus and undo remove | Medium: every setup | S | yes |
| 4 | 5 | Skip the done card, go straight to the round | Medium: every round | S | yes |
| 5 | 3 | Keyboard focus and button semantics in `Pressable` | Medium: desktop and screen readers | S–M | yes |
| 6 | 6 | Timer keeps time while the phone sleeps; clearer time-up | Medium (timer is opt-in) | S (M with wake lock) | next |
| 7 | 7 | Enter adds a word in the pack editor | Low–medium | S | next |
| 8 | 8 | Hide "Přidat" for AI when no server is set | Low | S | next |
| 9 | 9 | Contrast and minimum text size | Medium | M | next |
| 10 | 10 | Cap content width on desktop | Low | S | next |
