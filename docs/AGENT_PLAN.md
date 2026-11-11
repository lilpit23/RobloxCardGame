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
display synergies, PvE battle tower, Aura Shrine perks, lucky events, pull flash and sounds, trading and an in-server market (stealing was removed), 64-slot deck, card effects, combos, Luck stat, cul-de-sac map, season pass, gifts, featured set,
promo cards, pack-opening animation, showcase, store (passes and products), balance simulator.

## Track C — cards and sets (trading-card-game structure)

Done: four numbered sets from public-domain stories (Storybook Friends, High Seas, Journey to
the West, Midnight Classics; 37 cards each), per-set colour and emblem on cards and packs, Booster
and Elite packs built from slots, binder-style collection book, set completion bonus.

- [ ] **C1 New sets.** Olympus and Knights and Outlaws are done (six sets, seven store tiers). More
  public-domain ideas: Grimm fairy tales, Jungle Book, Norse myth, Arabian Nights, a full Oz set.
  Confirm US public-domain status for each source.
- [ ] **C2 Bigger sets.** Grow each set toward 60+ cards; keep the slot odds and re-run the
  sell-back check (cards in an average pack must sell for well under the pack price).
- [ ] **C3 Card art.** Card faces now have a picture window, set bands, effect tints and a foil
  streak, but the picture is still an emoji. Needs original illustrations (an artist or an image
  tool), uploaded to Roblox, with ids added as the fourth entry of each card row in `Cards.luau`.
- [ ] **C4 Special card treatments.** Full Art effect is done. Still to do: alternate-art cards as
  extra secret numbers, serial-numbered Prismatics (needs a global counter), and card grading
  (needs per-card data: cards are currently stackable counts, so a graded card has nowhere to
  keep its grade).
- [ ] **C5 Limited sets.** A time-limited promo set tied to events.
- [ ] **C6 Balance pass.** First pass done with the simulator (store tiers, deck slots and rebirth
  prices raised). A greedy bot still reaches tier 5 in well under an hour; tune further once
  real play times are known.

## Track D — deck, effects, combos and luck

Done: 4-to-64-slot active deck with one cash register, six card effects with their own bonuses,
type / set / effect / story combos (`Combos.luau`), a Luck stat with eight sources (`Luck.luau`).

- [x] **D1 Smarter auto-fill.** Done: `Deck.autoFill` swaps in story combos when they earn more.
  Follow-up: also weigh type and set combos, and aura / luck goals.
- [ ] **D2 More effects.** Frozen (earns while offline), Fiery (bonus that ramps the longer it
  stays in the deck), Cursed (big cash, lowers luck). Each needs a distinct trade-off.
- [x] **D3 Combo book.** Done: a Combos tab in the collection book.
- [ ] **D4 Deck layouts.** Save and swap named decks (cash deck, aura deck, luck deck for opening
  packs).
- [ ] **D5 Stand visuals.** Effect particles on deck cards in the store (slime drips, shadow
  smoke, gold sparkle); check performance with 64 slots x 8 players.
- [ ] **D6 Balance.** Deck slot prices, combo sizes and the luck cap all need playtest tuning.

## Track P — pacing (the owner played it and found it far too fast)

Done: wallet cap that rises with each rebirth, pack prices that rise 1.8% per pack in a run,
flatter rarity and effect multipliers, Auto Packer perk, simulator models the cap and inflation.

- [ ] **P1 Tune against real play.** Ask the owner how long the first rebirth took and adjust
  `Rebirth.Levels`, `Packs.InflationPerPack`, store tier and slot prices. Target: first rebirth in
  1.5 to 2.5 hours of normal play, each later rebirth a little longer.
- [ ] **P2 Simulate later rebirths.** The simulator stops at the first rebirth; extend it to carry
  the vault and bonuses through several rebirths.
- [ ] **P3 More long-term goals.** Achievements are done (permanent +3% income each). Still to do:
  a prestige layer above rebirth, tower floors beyond 50, set mastery (own every effect of every
  card in a set).
- [x] **P4 Slow the tower.** Done: tower cash is limited to 5% of the wallet cap.

## Track T — tooling and tests (do T1 first; it unblocks real verification)

- [x] **T1 Toolchain + CI.** Done: selene, `luau-lsp analyze` and `rojo build` run in GitHub
  Actions. Follow-up: run `stylua src` once and add `stylua --check src` to the workflow.
- [ ] **T2 Strict typing.** Add `--!strict` and type annotations file by file, starting with
  `src/shared`. Add `src/shared/Types.luau` for the profile, card, pack and remote payload shapes.
  Done when: `luau-lsp analyze` reports no errors.
- [ ] **T3 Unit tests.** Tests for the pure modules (`Cards`, `Packs`, `Upgrades`, `Format`) run in
  CI with Lune or TestEZ: key parsing rejects bad keys, pack odds sum correctly, luck never lowers
  a rarity's odds, costs are increasing, number formatting at boundaries.
- [x] **T4 Balance simulator.** Done: `tools/simulate.js`. Follow-ups: simulate aura, luck and
  rebirths, and a slower "human" pace (one pack every few seconds).
- [ ] **T5 Studio-only QA remotes.** Gated by `RunService:IsStudio()`: grant cash/aura, grant a
  card, reset profile. Never present on live servers.

## Track S — server structure and safety

- [ ] **S1 Split the server script.** Still to do, and now urgent: `init.server.luau` is ~1,500
  lines. Move it into modules (`Remotes`, `Economy`, `PackService`, `UpgradeService`,
  `TradeService`, `MarketService`, `SeasonService`, `IncomeLoop`) behind a shared context table.
  No behaviour change; do it only once someone can playtest before and after.
- [ ] **S2 Security audit.** Run the `roblox-dev:roblox-reviewer` agent over `src/` and fix every
  confirmed finding. Specific things to check: trades and market purchases (ownership re-checked
  at the swap, no yields mid-swap), listings across rebirth and rejoin, remote spam.
- [ ] **S3 Move saving to ProfileStore.** Replace the hand-written session lock in `PlayerData`
  with ProfileStore via Wally, keeping the same `load / get / save / release` interface.
- [ ] **S4 Global leaderboards.** An in-server "Top Stores" board is done. Still to do:
  OrderedDataStore boards across all servers for cash earned, aura and rebirths.

## Track G — gameplay depth (pick in order; each is independent of the others)

- [x] **G1 Open many.** Done (x3 / x10 with a grid reveal).
- [x] **G2 Rebirth + vault.** Done: `src/shared/Rebirth.luau`. Follow-ups: tune the six levels with
  the balance simulator (T4), a rebirth animation, rebirth count on the leaderboard.
- [ ] **G3 Collection rewards.** Partly done: +1% income per discovered card. Still to do: bigger
  one-off rewards for completing a whole rarity or every variant of a card.
- [x] **G4 Playtime rewards.** Done: a free booster every 15 minutes, daily login streak.
- [x] **G5 Quests.** Done: three daily quests paid in aura (`src/shared/Quests.luau`). Follow-up: more
  quest types (trade a card, win a tower floor, list a card on the market).
- [x] **G6 Auto-collect upgrade.** Done (Auto Collector, bought with aura).
- [ ] **G7 Auto-sell filter.** Player picks rarities to sell automatically when pulled.
- [x] **G8 Trading + market.** Done: two-sided trades with double confirm, and cash listings other
  players in the server can buy. Follow-ups: card pictures in the trade window, a cross-server
  market (MemoryStore), a sales tax to drain cash, trade history. Needs the S2 audit.
- [ ] **G9 Limited-time content.** Lucky events and the weekly featured set are done. (A monthly season pass and promo cards
  were built and then removed at the owner's request: the rewards were too strong.) Still to do: a Golden Pack that drops in the plaza for whoever reaches it.
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

- [ ] **U1 Sound and effects.** Pack wobble-and-burst, screen shake, flashes and server-wide pull
  announcements are done. Still to do: real sound assets (the four built-in sounds are unheard),
  particles, floating "+$" text at the register.
- [ ] **U2 First-minute tutorial.** Partly done: text hints at the top of the screen. Still to do:
  arrows pointing at the button / pad the hint is about.
- [ ] **U3 Phone layout.** The HUD menu is now two columns. Still to do: check every panel at
  667x375, touch targets at least 44 px, HUD clear of the jump button and the Roblox top bar.
- [ ] **U4 Card art.** Replace emoji with uploaded images through the `image` field in
  `Cards.luau`. Needs the owner to upload art and supply asset IDs.
- [ ] **U5 Card detail popup.** Tap a card for a large view with stats, odds source packs, and
  sell / display / fuse actions (replaces the three small buttons per cell).
- [ ] **U6 Split the client script.** One module per panel plus a small state store; no behaviour
  change.

## Track W — world

- [x] **W1 Map layout.** Done: cul-de-sac of eight stores around a plaza, road, tunnel through a
  ridge, PvE arena with the Battle Tower and its gate (`docs/map-layout.png`).
- [ ] **W4 Tower defense mode.** The arena is ready for it (lane, two monster gates, tower), but
  the PvE there is still the automatic Battle Tower fight. Build real tower defense: waves walk
  from the monster gates along lanes to the tower, the player places cards from their deck as
  defenders on pads, cards attack by type, rewards per wave. Decide solo instances vs shared
  arena first, and keep it PvE only.
- [ ] **W5 Map polish.** Fountain and four roadside shops are done. Still to do: terrain or meshes
  for the ridge instead of blocks, a fast-travel pad between a store and the arena, houses and
  street furniture behind the stores.
- [x] **W2 Store buildings per tier.** Done: a card shop that gains a storey per upgrade
  (`buildDecor` in `Plots.luau`, sketch in `docs/store-tiers.png`). Follow-up: stairs and usable
  upper floors, interior props, meshes instead of blocks.
- [ ] **W3 Card stands as 3D display cases** with a glow coloured by rarity and a beam for Mythic
  and Secret cards.

## Track M — monetisation (owner decisions needed first)

Needs the owner to create the passes/products in the Creator Dashboard and supply IDs.

- [ ] **M1 Game passes.** Code is done for seven passes (2x Cash, 2x Aura, Auto Collector, +8 Deck
  Slots, Bigger Vault, Lucky Clover, VIP). The owner must create them and put the ids in
  `Config.Monetization`; then test a purchase.
- [ ] **M2 Developer products.** Code is done (Luck Potion, Cash Potion, Time Warp, three aura
  bundles; receipt-safe). Needs ids and a test purchase, including the retry path when a save
  fails.
- [x] **M3 Paid-random-item compliance.** Aura bundles are hidden when PolicyService says paid random
  items are restricted. Pack odds are always shown.

## Suggested order

1. S2 and T3 in parallel.
2. U1 + U2 (the first minute decides whether players stay), G1, G2.
3. S1 and U6 before the scripts grow further.
4. Everything else by what playtests show.
