# Aura Packs

Roblox incremental card-pack tycoon, written in Luau, synced with Rojo (`default.project.json`).
The backlog for agents is in `docs/AGENT_PLAN.md`.

## Layout

- `src/shared/` → `ReplicatedStorage.Shared`. Data tables and pure logic used by both sides:
  `Config`, `Cards`, `Packs`, `Upgrades`, `Rebirth`, `Format`, `CardView` (builds a card's GUI).
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
- Characters and names must be original — no characters from existing anime or games.

## Verifying

The game has not yet been run in Roblox Studio from this repo, and there is no Luau toolchain
checked in (see task T1 in the plan). Until then: parse-check the files and run the pure modules in
`src/shared` outside Roblox with stubs for `Color3` and `Random`. Report honestly what was checked.
