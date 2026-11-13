# Aura Packs

Roblox incremental card-pack tycoon, written in Luau, synced with Rojo (`default.project.json`).
The backlog for agents is in `docs/AGENT_PLAN.md`.

## Layout

- `src/shared/` → `ReplicatedStorage.Shared`. Data tables and pure logic used by both sides:
  `Config`, `Cards`, `Packs`, `Upgrades`, `Rebirth`, `Quests`, `Perks`, `Combos`, `Luck`, `Deck`, `Season`, `Achievements`, `Battle`, `Duel` (turn-based tower duels), `Titles`, `Staff`, `Format`, `CardView` (builds a card's GUI).
- `src/server/` → `ServerScriptService.Server`. `init.server.luau` holds the remotes and game
  rules; `PlayerData.luau` is the only code that touches DataStores; `Monetization.luau` handles game
  passes and product receipts; `Plots.luau` builds the map
  and each player's store out of parts.
- `src/client/` → `StarterPlayerScripts.Client`. All UI, built from code.

Map (all in `Plots.luau`, see `docs/map-layout.png`): a cul-de-sac plaza at the origin with the
plots in a ring facing it, a road along +X, a tunnel through a ridge, then the PvE arena and tower.
If you change the layout numbers, change them in `tools/make-map.js` too and re-run it.

Nothing is built by hand in Studio: the map, plots and UI are all created by scripts. Keep it that
way so the repo stays the whole game.

## Rules

- Server-authoritative. Clients send requests; the server validates, changes the profile, then
  sends the new state with `pushState`. Prices, odds and rewards come from server-side tables.
- Every remote handler starts with `allow(player, name, rate, burst)` and validates its arguments.
- Gameplay code changes the in-memory profile from `PlayerData.get(player)`; it never calls
  DataStores. New saved fields go in `newData()`; shape changes need a migration.
- A card key is `"id"` or `"id:variant"`. Always check it with `Cards.parse` before use.
- Call `touch(player, true)` after changing inventory, slots, collection or upgrades (the client
  rebuilds its open panel), `touch(player, false)` for cash/aura only.
- Big collections: `pushState` only sends `inventory` and `collection` after `cardsChanged(data)`
  was called, so change them through `addCard` / `takeCard` (or call `cardsChanged` yourself).
  On the client, any list that grows with the collection must use `fillLazily` / `newCardCell`,
  which build a row or card only while it is on screen.
- Tower duels: the rules are in `Duel.luau` and the live duel is `session.duel` on the server;
  the client only gets `Duel.view` and the event list. Battling never uses up cards. After
  changing duel numbers run `node tools/duel-sim.js`. The enemy figures and camera of a duel
  are built on the client (`buildStage`); the server only moves the player to their duel pad.
- Admins: `isAdmin(player)` on the server (the owner, or a user id in the shared admin list
  kept by `PlayerData.setAdmin`). Only `isOwner` may change that list. Every admin-only remote
  must check `isAdmin` on the server; hiding the tab on the client is not protection.
- Global leaderboards use OrderedDataStores, and like every DataStore call they live in
  `PlayerData.luau`. Titles are data in `Titles.luau`; earned ones are saved in `data.titles`.
- No stealing, no PvP, and no trading or market either (owner's decisions; trading and the
  market were removed). Cards never move between players.
- A new set every rebirth: a set's packs unlock by rebirth count (`pack.rebirths`,
  `Packs.unlocked`), not by store tier. The store tier only gives the income multiplier and
  shelves. Rebirth costs in `Rebirth.luau` assume this, and each level's required cards must
  come from sets already open in that run.
- Deck slots are the store's shelves: `Upgrades.slotCount(storeLevel, rebirths, bonus)` is the
  only place the count is decided (store tier, capped per rebirth until the fifth). There is no
  deck-slot upgrade. `Plots.luau` puts 16 shelves on the ground floor and 8 on each storey.
- Staff (`Staff.luau`): Megan, Harshdeep, Alabaster, Fimby and Darius each run one or two of
  the permanent aura perks in `Perks.luau` and join after a set number of rebirths. A new
  permanent perk must be given to one of them. Their desks are drawn by `Plots.setStaff`.
- Sets are built from public-domain stories (owner's decision), so real character names are
  fine. Each set lists its `sources` in `Cards.luau`. Base cards and art on the original books,
  not on later films, shows or games: things an adaptation added (Disney's red-shirted Pooh, the
  ruby slippers from the 1939 Oz film, a film's monster make-up) can still be protected, and
  some names are trademarked for merchandise. Before adding a set, check the work is public
  domain in the US, and say so in the pull request. Never add characters from works still under
  copyright, renamed or not. Real people are only acceptable when they are long dead:
  ancient history (Glory of Rome) or, by the owner's decision, American history where the
  person died about a century ago or more (Pax Americana; the latest is 1926). Roblox bans
  depicting current or recent government officials and candidates, and living or recently dead
  people also have likeness rights. No modern politicians, ever. Show real people respectfully:
  no caricature, and they are never tower enemies (`Duel.TowerSets`).
- A card's id is its name slugified (`winnie_the_pooh`) and is what gets saved. Renaming or
  removing a card orphans owned copies, so add a migration when that matters.
- The active deck is `data.slots` (4 to 64 slots, shown as rows of cards in the store). Its cash
  goes to one register per store (`session.pending`). Deck bonuses come only from `Combos.evaluate`
  and luck only from `Luck.sources`; add new bonus sources there so server and client agree.
- The weekly event (`Season.event()`) is applied in `storeMult`, `auraMult`, `Luck.sources` and
  the tower rewards. New weekly bonuses go in `Season.Events` and are applied in those places.
- Card effects are `Cards.Variants` (Shiny, Slimy, Lucky, Shadow, Golden, Prismatic).
- Pacing levers, in order of strength: the wallet cap (`Rebirth.cashCap`; all cash must go
  through `addCash`), pack price inflation (`Packs.price`, counts in `data.packCounts`, capped at `Packs.MaxInflation` times the base price), the deck slots each store tier and rebirth allow (`Upgrades.TierSlots`,
  `Upgrades.RebirthSlots`), store tier prices, and the rarity / effect income multipliers in `Cards.luau`. The
  multipliers stack, so small changes there move the whole game.
- Staff perk levels are gated by rebirths (`Perks.maxLevel`); keep new permanent perks behind
  the same gate so aura stays useful all game.
- Money: passes and products live in `Config.Monetization` (id 0 = not on sale). Product grants
  must stay receipt-safe (`data.receipts`, save before returning PurchaseGranted). Anything
  bought with Robux that can turn into random cards must respect `session.restricted`.
- After changing prices or incomes, run `tools/simulate.js` and include its output in the pull
  request.
- Booster structure: packs are lists of slots (`Packs.luau`). `Packs.slotOdds` is the only place
  odds are computed: it scales luck per set (`Packs.SetLuckScale`) and applies the 1% Common
  floor, and both the roll and the odds shown to players use it. Sell prices are a share of the set's
  Booster price (`Cards.Rarities[...].sell`); the cards in an average pack must sell for well
  under the pack price, including at maximum luck and discount.

## Verifying

- CI (`.github/workflows/ci.yml`) runs on every push and pull request: `selene src` (lint),
  `rojo build` (place file, uploaded as the `AuraPacks` artifact) and `luau-lsp analyze` (types).
  Check it with `gh run list` / `gh run view --log-failed` and fix failures before finishing.
- Tool versions are pinned in `rokit.toml`. They may not be installable inside an agent container;
  CI is the source of truth.
- The pure modules in `src/shared` can be run outside Roblox with stubs for `Color3` and `Random`.
- Nobody has playtested the game in Roblox Studio from this repo yet. CI passing means the code
  lints, type-checks and builds — not that it plays correctly. Report honestly what was checked.
