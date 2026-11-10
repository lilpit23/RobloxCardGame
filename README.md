# Aura Packs

A Roblox incremental / tycoon game: open anime card packs, put the cards on display in your store,
collect the cash they earn, buy better packs, upgrade the store, and fill the collection book.
Rare cards also radiate **aura**, a second currency for Aura Packs, luck and permanent perks.

## The loop

1. You spawn at your own store plot with one free Starter Pack.
2. Open it (🎴 Packs button, or the Pack Shop counter in your store) — 5 cards per booster.
3. Put cards on your display stands (🃏 My Cards → Display, or "Display Best").
4. Each stand builds up cash; walk over the green pad in front of it to collect.
5. Spend cash on better packs, more stands, and store upgrades (income multiplier + new packs).
6. Epic and better cards earn aura every second and a burst of aura when pulled.
7. Three copies of the same card fuse into its next variant (Holo → Gold → Prismatic), and your
   store keeps earning a share of its income for up to 4 hours while you are offline.
8. **Rebirth:** once you have enough cash and aura *and* own the specific cards a rebirth asks
   for, you can reset your run (cash, aura, cards, stands, luck, store) for permanent bonuses:
   +50% income, +10% luck and one more vault slot each time. Cards you put in the **vault**
   beforehand survive the reset, so you start the next run with them.
9. Quality of life: open 3 or 10 packs at once, buy the Auto Collector (aura) so you never walk
   over pads again, and earn +1% income for every card you discover in the collection book.
10. **Sets and booster packs, like a real card game.** Four numbered sets built from
    public-domain stories, 37 cards each (148 cards, 592 with variants):
    **Storybook Friends** (Winnie-the-Pooh, Alice, Oz, Peter Pan), **High Seas** (Treasure Island,
    Moby-Dick, Captain Nemo, Sinbad), **Journey to the West** (Sun Wukong and company) and
    **Midnight Classics** (Dracula, Frankenstein, Sherlock Holmes). Every set has its own colour
    and emblem, a 5-card **Booster** (3 commons, 1 uncommon, 1 guaranteed rare-or-better) and a
    pricier **Elite** pack. Later sets cost more and earn more. The collection book is a binder
    page per set with card numbers (secret cards are numbered past the set size), and completing
    a set gives +25% income.
11. **Daily quests and a daily reward:** three quests a day (open packs, pull rares, sell, fuse,
    earn cash) pay aura, and a login streak reward grows up to day 7.
12. **Card types and synergies:** every card is a Warrior, Beast, Mystic, Tech or Star. Display
    3, 5 or 8 of one type for +15%, +35% or +60% income.
13. **Battle Tower:** your three strongest cards fight a 50-floor tower for aura and cash. Each
    type deals +30% damage to the next one in the cycle.
14. **Aura Shrine:** permanent perks bought with aura that survive rebirth (starting cash, cheaper
    packs, more aura, better offline earnings, extra vault slots).
15. **Lucky events:** every 20 minutes the whole server gets better pack odds for 5 minutes.
16. **Trading and the market:** trade cards with another player (both sides offer cards and both
    confirm), or list a card for a cash price so anyone in the server can buy it. There is no
    stealing and no PvP.

## Setup

Everything — map, plots, UI — is created by the scripts. There is nothing to build in Studio.

**Easiest — download the built place:** every push builds the game. On GitHub open **Actions**,
pick the latest green **CI** run, download the **AuraPacks** artifact, unzip it and open
`AuraPacks.rbxlx` in Roblox Studio.

**With Rojo:**

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
| `src/shared/Config.luau` | Slots, pack size, sell price, market and trade limits, events, sounds |
| `src/shared/Cards.luau` | Sets and their card lists, rarities, variants, sell prices, aura rates |
| `src/shared/Packs.luau` | Pack slots and odds, which store tier unlocks each set |
| `src/shared/Upgrades.luau` | Store tiers, stand prices, luck prices |
| `src/shared/Perks.luau` | Aura Shrine perks: prices, levels, effects |
| `src/shared/Synergy.luau` | Display synergy thresholds and bonuses |
| `src/shared/Battle.luau` | Battle rules, tower enemy strength, tower rewards |
| `src/shared/Quests.luau` | Quest types, goals and rewards, daily reward size |
| `src/shared/Rebirth.luau` | Rebirth requirements (cash, aura, cards), bonuses, vault size |

Cards show an emoji as placeholder art. To use real art, upload an image and add
`image = "rbxassetid://123456"` to that card's row in `Cards.luau`.

## Working on the game

`CLAUDE.md` has the project rules and `docs/AGENT_PLAN.md` is the task backlog.

## Art

`assets/` holds a game icon, a thumbnail and a cover for every pack, generated by
`tools/make-art.js`. See `assets/README.md` for how to upload them and wire them into the game.
