# Aura Packs

Roblox incremental card-pack tycoon, written in Luau, synced with Rojo (`default.project.json`).
The backlog for agents is in `docs/AGENT_PLAN.md`.

## Layout

- `src/shared/` → `ReplicatedStorage.Shared`. Data tables and pure logic used by both sides:
  `Config`, `Cards`, `Packs`, `Upgrades`, `Rebirth`, `Quests`, `Perks`, `Synergy`, `Battle`, `Format`, `CardView` (builds a card's GUI).
- `src/server/` → `ServerScriptService.Server`. `init.server.luau` holds the remotes and game
  rules; `PlayerData.luau` is the only code that touches DataStores; `Plots.luau` builds the map
  and each player's store out of parts.
- `src/client/` → `StarterPlayerScripts.Client`. All UI, built from code.

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
- No stealing and no PvP (owner's decision). Cards only change hands through trading and the
  market, both in `init.server.luau`; any new way to move cards between players needs the same
  care (re-check ownership at the moment of the swap, never yield in the middle).
- Sets are parodies of anime genres (owner's decision). Cards use plain descriptive nicknames
  ("Stretch Pirate", "Green Swordsman"). Never use a real character's name, official title or
  epithet, catchphrase, logo, or art that copies a character's design — renaming alone does not
  make a lookalike safe, and Roblox removes games for it.
- A card's id is its name slugified (`stretch_pirate`) and is what gets saved. Renaming or
  removing a card orphans owned copies, so add a migration when that matters.
- Booster structure: packs are lists of slots (`Packs.luau`). Sell prices are a share of the set's
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
