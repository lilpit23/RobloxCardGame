# Aura Packs — agent work plan

A backlog sized so that one agent can take one task, finish it in one session, and open one pull
request. Tasks in the same track touch the same files, so run **one agent per track at a time**;
different tracks can run in parallel.

## Rules for every task

- Read `CLAUDE.md` first. The server decides everything; the client only asks and draws.
- Branch from `main`, one task per branch, one pull request per task.
- CI (lint, type check, place-file build) must be green. Nobody has playtested this game in Roblox
  Studio yet, so say in the pull request what was and was not verified; never claim a playtest
  that did not happen.
- Every new remote: rate limit first line, validate type → range → permission, never trust a price
  or amount from the client.
- Every new saved field: add it to `newData()` in `PlayerData.luau`; if an existing field changes
  shape, bump `CURRENT_VERSION` and add a migration.
- Numbers that affect balance go in `src/shared/Config.luau` or the data tables, not inline.
- Tick the task's box in this file in the same pull request.

## Status

Done so far: core loop (packs → display → collect → buy), aura, 5 store tiers, stands, luck,
collection book, session-locked saving with retries, remote rate limits,
card fusion (3 copies → next variant), offline earnings, rebirth with card requirements and a
vault that carries cards into the next run, CI, bulk pack opening, auto collector, collection
income bonus, first-minute hints, Neon Arcade set, daily quests and login reward, card types with
display synergies, PvE battle tower, Aura Shrine perks, lucky events, pull flash and sounds, trading and an in-server market (stealing was removed), 64-slot deck, card effects, combos, Luck stat.

## Track C — cards and sets (trading-card-game structure)

Done: four numbered sets from public-domain stories (Storybook Friends, High Seas, Journey to
the West, Midnight Classics; 37 cards each), per-set colour and emblem on cards and packs, Booster
and Elite packs built from slots, binder-style collection book, set completion bonus.

- [ ] **C1 New sets.** More public-domain sets with their own boosters: Olympus (Greek myth),
  Round Table (King Arthur), Sherwood (Robin Hood), Grimm fairy tales, Jungle Book, a full Oz
  set. Confirm US public-domain status for each source and extend store tiers or rebirth gating
  so they unlock later.
- [ ] **C2 Bigger sets.** Grow each set toward 60+ cards; keep the slot odds and re-run the
  sell-back check (cards in an average pack must sell for well under the pack price).
- [ ] **C3 Card art.** Anime-style illustrations per card via the image field, one consistent
  style per set. Draw from the original books, not from film or TV versions.
- [ ] **C4 Special card treatments.** Full-art and alternate-art versions as extra secret numbers.
- [ ] **C5 Limited sets.** A time-limited promo set tied to events.
- [ ] **C6 Balance pass.** Early game is fast now that every booster holds a rare; tune set
  multipliers, pack prices and stand costs with the simulator (T4).

## Track D — deck, effects, combos and luck

Done: 4-to-64-slot active deck with one cash register, six card effects with their own bonuses,
type / set / effect / story combos (`Combos.luau`), a Luck stat with eight sources (`Luck.luau`).

- [ ] **D1 Smarter auto-fill.** "Auto-fill Deck" picks the highest earners; make it account for
  combos (try completing story and type combos when that earns more).
- [ ] **D2 More effects.** Frozen (earns while offline), Fiery (bonus that ramps the longer it
  stays in the deck), Cursed (big cash, lowers luck). Each needs a distinct trade-off.
- [ ] **D3 Combo book.** A panel listing every story combo, which cards it needs, and which you
  own, so players can chase them.
- [ ] **D4 Deck layouts.** Save and swap named decks (cash deck, aura deck, luck deck for opening
  packs).
- [ ] **D5 Stand visuals.** Effect particles on deck cards in the store (slime drips, shadow
  smoke, gold sparkle); check performance with 64 slots x 8 players.
- [ ] **D6 Balance.** Deck slot prices, combo sizes and the luck cap all need playtest tuning.

## Track T — tooling and tests (do T1 first; it unblocks real verification)

- [x] **T1 Toolchain + CI.** Done: selene, `luau-lsp analyze` and `rojo build` run in GitHub
  Actions. Follow-up: run `stylua src` once and add `stylua --check src` to the workflow.
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
  (cards, selling, fusion), `PackService`, `UpgradeService`, `TradeService`, `MarketService`, `IncomeLoop`. No
  behaviour change. Done when: `init.server.luau` only wires modules together.
- [ ] **S2 Security audit.** Run the `roblox-dev:roblox-reviewer` agent over `src/` and fix every
  confirmed finding. Specific things to check: trades and market purchases (ownership re-checked
  at the swap, no yields mid-swap), listings across rebirth and rejoin, remote spam.
- [ ] **S3 Move saving to ProfileStore.** Replace the hand-written session lock in `PlayerData`
  with ProfileStore via Wally, keeping the same `load / get / save / release` interface.
- [ ] **S4 Global leaderboards.** OrderedDataStore boards for total cash earned and aura, shown on
  two boards in the street, refreshed every 2 minutes.

## Track G — gameplay depth (pick in order; each is independent of the others)

- [x] **G1 Open many.** Done (x3 / x10 with a grid reveal).
- [x] **G2 Rebirth + vault.** Done: `src/shared/Rebirth.luau`. Follow-ups: tune the six levels with
  the balance simulator (T4), a rebirth animation, rebirth count on the leaderboard.
- [ ] **G3 Collection rewards.** Partly done: +1% income per discovered card. Still to do: bigger
  one-off rewards for completing a whole rarity or every variant of a card.
- [ ] **G4 Playtime rewards.** Daily login streak is done. Still to do: a free pack every 15 minutes
  of play.
- [x] **G5 Quests.** Done: three daily quests paid in aura (`src/shared/Quests.luau`). Follow-up: more
  quest types (trade a card, win a tower floor, list a card on the market).
- [x] **G6 Auto-collect upgrade.** Done (Auto Collector, bought with aura).
- [ ] **G7 Auto-sell filter.** Player picks rarities to sell automatically when pulled.
- [x] **G8 Trading + market.** Done: two-sided trades with double confirm, and cash listings other
  players in the server can buy. Follow-ups: card pictures in the trade window, a cross-server
  market (MemoryStore), a sales tax to drain cash, trade history. Needs the S2 audit.
- [ ] **G9 Limited-time packs.** Lucky events are done. Still to do: a weekend-only pack driven by a
  schedule table, and a Golden Pack that drops in the street for whoever reaches it first.
- [x] **G10 More cards.** Done: Neon Arcade set (24 cards) with Neon, Arcade and Glitch packs, plus the
  Omega Pack. Follow-up: a set filter in the collection book, and rebirths that need Neon cards.

## Track B — battles (PvE only; the owner has ruled out PvP and stealing for now)

Done: card types with a five-way advantage cycle, `Battle.simulate` (pure, server-run), a 50-floor
PvE tower that auto-picks the player's three strongest cards, playback UI.

- [ ] **B1 Team picker.** Let the player choose and save a three-card battle team instead of the
  automatic strongest three, so type matchups become a decision. Validate ownership on the server.
- [ ] **B4 Abilities.** One simple ability per type (Warrior: first hit doubles; Beast: heals on
  KO; Mystic: hits the back row; Tech: shield; Star: buffs allies) to give fights more texture.
- [ ] **B5 Bosses and raids.** Every tenth tower floor is a boss with a unique card reward; a
  co-op server-wide raid boss everyone attacks during an event.
- On hold until the owner asks: PvP duels, staked duels, ranked ladder.

## Track U — interface and feel

- [ ] **U1 Sound and effects.** Partly done: screen flash on Legendary+ pulls and four built-in
  sounds (`Config.Sounds`, not yet heard in Studio). Still to do: proper sound assets, particles,
  camera shake, floating "+$" text when collecting.
- [ ] **U2 First-minute tutorial.** Partly done: text hints at the top of the screen. Still to do:
  arrows pointing at the button / pad the hint is about.
- [ ] **U3 Phone layout.** Check every panel at 667×375; touch targets at least 44 px; HUD must not
  cover the jump button or the Roblox top bar.
- [ ] **U4 Card art.** Replace emoji with uploaded images through the `image` field in
  `Cards.luau`. Needs the owner to upload art and supply asset IDs.
- [ ] **U5 Card detail popup.** Tap a card for a large view with stats, odds source packs, and
  sell / display / fuse actions (replaces the three small buttons per cell).
- [ ] **U6 Split the client script.** One module per panel plus a small state store; no behaviour
  change.

## Track W — world

- [ ] **W1 Street and lobby.** Partly done: road, pavements, lamps, trees, banner over the spawn.
  Still to do: a plaza with leaderboards (S4) and a public market stall.
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

1. S2 and T3 in parallel.
2. U1 + U2 (the first minute decides whether players stay), G1, G2.
3. S1 and U6 before the scripts grow further.
4. Everything else by what playtests show.
