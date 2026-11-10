# Aura Packs

A Roblox incremental / tycoon game: open anime card packs, put the cards on display in your store,
collect the cash they earn, buy better packs, upgrade the store, and fill the collection book.
Rare cards also radiate **aura**, a second currency for Aura Packs and luck upgrades.

## The loop

1. You spawn at your own store plot with one free Starter Pack.
2. Open it (🎴 Packs button, or the Pack Shop counter in your store) — 3 cards per pack.
3. Put cards on your display stands (🃏 My Cards → Display, or "Display Best").
4. Each stand builds up cash; walk over the green pad in front of it to collect.
5. Spend cash on better packs, more stands, and store upgrades (income multiplier + new packs).
6. Epic and better cards earn aura every second and a burst of aura when pulled.
7. Other players can steal a displayed card by holding the prompt on it and running it back to
   their own store. Catch them (get close) to take it back, or step on the red pad to lock your store.

## Setup

Everything — map, plots, UI — is created by the scripts. There is nothing to build in Studio.

**With Rojo** (recommended):

```bash
rojo build -o AuraPacks.rbxlx
```

Open `AuraPacks.rbxlx` in Roblox Studio, or run `rojo serve` and connect with the Rojo Studio plugin.

**Without Rojo:** in a new Baseplate place, recreate this layout by hand, pasting each file's contents:

| File | Create as | Where |
| --- | --- | --- |
| `src/shared/*.luau` | ModuleScripts (named like the files) | `ReplicatedStorage/Shared` (a Folder) |
| `src/server/init.server.luau` | Script named `Server` | `ServerScriptService` |
| `src/server/PlayerData.luau`, `Plots.luau` | ModuleScripts | inside the `Server` script |
| `src/client/init.client.luau` | LocalScript named `Client` | `StarterPlayer/StarterPlayerScripts` |

**Then in Studio:**

- Game Settings → Security → turn on **Enable Studio Access to API Services** so saving works in
  Studio (without it the game still runs, progress just is not saved).
- Set the experience's max players to **8** (one plot each; `PlotCount` in `Config.luau`).

## Tuning

| File | What it controls |
| --- | --- |
| `src/shared/Config.luau` | Slots, pack size, sell price, stealing rules (or turn stealing off) |
| `src/shared/Cards.luau` | Card list, rarities, variants (Holo / Gold / Prismatic), aura rates |
| `src/shared/Packs.luau` | Pack prices and odds |
| `src/shared/Upgrades.luau` | Store tiers, stand prices, luck prices |

Cards show an emoji as placeholder art. To use real art, upload an image and add
`image = "rbxassetid://123456"` to that card's row in `Cards.luau`.
