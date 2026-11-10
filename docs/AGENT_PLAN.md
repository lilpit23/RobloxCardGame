# Aura Packs — agent work plan

A backlog sized so that one agent can take one task, finish it in one session, and open one pull
request. Tasks in the same track touch the same files, so run **one agent per track at a time**;
different tracks can run in parallel.

## Rules for every task

- Read `CLAUDE.md` first. The server decides everything; the client only asks and draws.
- Branch from `main`, one task per branch, one pull request per task.
- Nobody has run this game in Roblox Studio yet. Until task T1 lands, the only checks available are
  a syntax parse and running the pure logic modules outside Roblox. Say in the pull request what
  was and was not verified; never claim a playtest that did not happen.
- Every new remote: rate limit first line, validate type → range → permission, never trust a price
  or amount from the client.
- Every new saved field: add it to `newData()` in `PlayerData.luau`; if an existing field changes
  shape, bump `CURRENT_VERSION` and add a migration.
- Numbers that affect balance go in `src/shared/Config.luau` or the data tables, not inline.
- Tick the task's box in this file in the same pull request.

## Status

Done so far: core loop (packs → display → collect → buy), aura, 5 store tiers, stands, luck,
collection book, stealing + store lock, session-locked saving with retries, remote rate limits,
card fusion (3 copies → next variant), offline earnings.

## Track T — tooling and tests (do T1 first; it unblocks real verification)

- [ ] **T1 Toolchain + CI.** Add `rokit.toml` (rojo, selene, stylua, luau-lsp), `selene.toml` with
  the roblox standard library, `stylua.toml` (tabs, 120 columns), and a GitHub Actions workflow
  that runs stylua check, selene, `luau-lsp analyze`, and `rojo build`, uploading the `.rbxlx` as a
  build artifact. Done when: the workflow is green on `main`.
- [ ] **T2 Strict typing.** Add `--!strict` and type annotations file by file, starting with
  `src/shared`. Add `src/shared/Types.luau` for the profile, card, pack and remote payload shapes.
  Done when: `luau-lsp analyze` reports no errors.
- [ ] **T3 Unit tests.** Tests for the pure modules (`Cards`, `Packs`, `Upgrades`, `Format`) run in
  CI with Lune or TestEZ: key parsing rejects bad keys, pack odds sum correctly, luck never lowers
  a rarity's odds, costs are increasing, number formatting at boundaries.
- [ ] **T4 Balance simulator.** A script that simulates a player (buy best affordable pack, display
  best cards, buy cheapest upgrade) and prints time-to-each-store-tier. Done when: output is in the
  pull request and any tier taking under 2 minutes or over 3 hours is flagged.
- [ ] **T5 Studio-only QA remotes.** Gated by `RunService:IsStudio()`: grant cash/aura, grant a
  card, reset profile. Never present on live servers.

## Track S — server structure and safety

- [ ] **S1 Split the server script.** Move `init.server.luau` into modules: `Remotes`, `Economy`
  (cards, selling, fusion), `PackService`, `UpgradeService`, `StealService`, `IncomeLoop`. No
  behaviour change. Done when: `init.server.luau` only wires modules together.
- [ ] **S2 Security audit.** Run the `roblox-dev:roblox-reviewer` agent over `src/` and fix every
  confirmed finding. Specific things to check: a thief using speed hacks, stealing while the victim
  is mid-save, card loss if the server crashes while a card is being carried.
- [ ] **S3 Move saving to ProfileStore.** Replace the hand-written session lock in `PlayerData`
  with ProfileStore via Wally, keeping the same `load / get / save / release` interface.
- [ ] **S4 Global leaderboards.** OrderedDataStore boards for total cash earned and aura, shown on
  two boards in the street, refreshed every 2 minutes.

## Track G — gameplay depth (pick in order; each is independent of the others)

- [ ] **G1 Open many.** Buy 3 or 10 packs at once; the reveal shows a grid with the best pull
  highlighted. One remote call, one state update.
- [ ] **G2 Rebirth.** Reset cash, cards on display, stands and store tier in exchange for a
  permanent income multiplier and a rebirth counter on the store sign. Aura, luck and the
  collection book are kept.
- [ ] **G3 Collection rewards.** Completing every card of a rarity (and every variant of a card)
  grants a permanent income bonus, shown in the collection book.
- [ ] **G4 Daily reward + playtime rewards.** A 7-day streak calendar and a free pack every
  15 minutes of play.
- [ ] **G5 Quests.** Three rotating goals (open N packs, pull an Epic, steal a card, collect $X)
  that pay aura.
- [ ] **G6 Auto-collect upgrade.** An aura upgrade that collects stand cash automatically every few
  seconds.
- [ ] **G7 Auto-sell filter.** Player picks rarities to sell automatically when pulled.
- [ ] **G8 Trading.** Two-sided trade window with confirm + 5-second lock-in, fully server-held.
  High dupe risk: needs S2 done first and its own review.
- [ ] **G9 Limited-time packs and luck events.** A server-wide "2x luck for 10 minutes" event and a
  weekend-only pack, driven by a schedule table.
- [ ] **G10 More cards.** Grow to ~60 cards with a second themed set; keep names and characters
  original (no characters from existing anime).

## Track U — interface and feel

- [ ] **U1 Sound and effects.** Pack rip, card flip, rarity stingers, cash collect; particle burst
  and camera shake on Legendary and better; floating "+$" text when collecting.
- [ ] **U2 First-minute tutorial.** Arrows and short prompts: open free pack → display → collect →
  buy a pack. Shown once, saved in the profile.
- [ ] **U3 Phone layout.** Check every panel at 667×375; touch targets at least 44 px; HUD must not
  cover the jump button or the Roblox top bar.
- [ ] **U4 Card art.** Replace emoji with uploaded images through the `image` field in
  `Cards.luau`. Needs the owner to upload art and supply asset IDs.
- [ ] **U5 Card detail popup.** Tap a card for a large view with stats, odds source packs, and
  sell / display / fuse actions (replaces the three small buttons per cell).
- [ ] **U6 Split the client script.** One module per panel plus a small state store; no behaviour
  change.

## Track W — world

- [ ] **W1 Street and lobby.** Road, lamps, trees, a central plaza with the leaderboards (S4) and a
  giant spinning pack.
- [ ] **W2 Store visuals per tier.** Real storefront models per tier instead of walls and pillars;
  shelves, a counter, a neon sign.
- [ ] **W3 Card stands as 3D display cases** with a glow coloured by rarity and a beam for Mythic
  and Secret cards.

## Track M — monetisation (owner decisions needed first)

Needs the owner to create the passes/products in the Creator Dashboard and supply IDs.

- [ ] **M1 Game passes.** 2x cash, auto-collect, +4 stands, VIP sign. Checked on the server with
  `MarketplaceService`.
- [ ] **M2 Developer products.** Aura bundles and a luck boost, granted in `ProcessReceipt` with
  purchase IDs recorded in the profile so a receipt is never granted twice.
- [ ] **M3 Paid-random-item compliance.** If any pack can be bought with Robux, directly or
  through bought aura, use `PolicyService` to hide it where paid random items are restricted, and
  keep odds visible (they already are).

## Suggested order

1. T1, then S2 and T3 in parallel.
2. U1 + U2 (the first minute decides whether players stay), G1, G2.
3. S1 and U6 before the scripts grow further.
4. Everything else by what playtests show.
