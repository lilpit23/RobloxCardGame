// Balance simulator: plays a simple greedy player through the real game tables and prints
// how long each store tier and each rebirth takes. Run:  cd tools && npm install && node simulate.js [hours]
// It loads the Luau modules from src/shared in a Lua VM with small stubs for Roblox types.
const { lua, lauxlib, lualib, to_luastring } = require('fengari');
const fs = require('fs');
const path = require('path');

const HOURS = Number(process.argv[2] || 6);
const shared = path.join(__dirname, '..', 'src', 'shared');
const MODULES = ['Config', 'Format', 'Cards', 'Perks', 'Packs', 'Combos', 'Deck', 'Upgrades', 'Rebirth'];

const program = `
local sources, HOURS = ...
math.floor = function(x) return x - x % 1 end -- the VM's own floor overflows on big numbers
table.find = function(t, v) for i, x in ipairs(t) do if x == v then return i end end end
table.clone = function(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end
local C3 = {} C3.__index = C3 function C3:Lerp() return self end
Color3 = { fromRGB = function() return setmetatable({}, C3) end, new = function() return setmetatable({}, C3) end }
local loaded = {}
local function scriptStub()
  return setmetatable({}, { __index = function(_, k)
    if k == "Parent" then return setmetatable({}, { __index = function(_, n) return { __mod = n } end }) end
  end })
end
function require(m)
  local n = m.__mod
  if not loaded[n] then
    loaded[n] = assert(load(sources[n], n, "t", setmetatable({ script = scriptStub() }, { __index = _G })))()
  end
  return loaded[n]
end
local Cards, Packs, Deck = require({ __mod = "Cards" }), require({ __mod = "Packs" }), require({ __mod = "Deck" })
local Upgrades, Rebirth, Format, Config = require({ __mod = "Upgrades" }), require({ __mod = "Rebirth" }), require({ __mod = "Format" }), require({ __mod = "Config" })
local rng = { NextNumber = function() return math.random() end, NextInteger = function(_, a, b) return math.random(a, b) end }

local cash, time, tier, packsOpened = 0, 0, 1, 0
local rebirths, runStart = 0, 0
local function slots() return Upgrades.slotCount(tier - 1, rebirths, 0) end
local packCounts = {} -- packs opened this run per pack id (prices rise with it)
local owned, deck = {}, {}
local STEP = 10

local function clock(t)
  t = t or time
  return string.format("%dh %02dm", math.floor(t / 3600), math.floor(t % 3600 / 60))
end
local function log(text) print(string.format("%-9s %s", clock(), text)) end
local function priceOf(pack) return Packs.price(pack, packCounts[pack.id], 1, nil) end
local deckScore = 0 -- cached: scoring the deck is the slow part
local function income()
  return deckScore * Upgrades.StoreTiers[tier].mult * Rebirth.incomeMult(rebirths)
end
local function rebuildDeck()
  deck = Deck.autoFill(owned, slots())
  deckScore = Deck.score(deck)
end
local function openPack(pack)
  for _, key in ipairs(Packs.open(pack, rebirths, rng)) do owned[key] = (owned[key] or 0) + 1 end
  packsOpened = packsOpened + 1
  packCounts[pack.id] = (packCounts[pack.id] or 0) + 1
end
local function ownsId(id)
  for key in pairs(owned) do
    local def = Cards.parse(key)
    if def and def.id == id then return true end
  end
  return false
end
-- the booster of the set holding a rebirth card the bot still lacks (nil if it has them all)
local function wantedBooster()
  local level = Rebirth.Levels[rebirths + 1]
  if level == nil then return nil end
  for _, id in ipairs(level.cards) do
    if not ownsId(id) then
      local pack = Packs.ById[Cards.ById[id].set .. "_booster"]
      if pack.storeTier <= tier then return pack end
    end
  end
  return nil
end
local function bestBooster(budget)
  local best = nil
  for _, pack in ipairs(Packs.List) do
    if pack.kind == "booster" and pack.storeTier <= tier and priceOf(pack) <= budget and (best == nil or pack.cost > best.cost) then
      best = pack
    end
  end
  return best
end

openPack(Packs.ById[Packs.StarterId]) -- the free starter pack
rebuildDeck()
log("start: free pack opened, earning " .. Format.cash(income()) .. "/s")

local dirty, sinceRebuild = false, 0
while time < HOURS * 3600 do
  time = time + STEP
  local cap = Rebirth.cashCap(rebirths)
  cash = math.min(cap, cash + income() * STEP)
  local changed = false

  local nextTier = Upgrades.StoreTiers[tier + 1]
  if nextTier and cash >= nextTier.cost then
    cash = cash - nextTier.cost
    tier = tier + 1
    rebuildDeck()
    log("  store tier " .. tier .. " (" .. nextTier.name .. "), " .. slots() .. " slots, earning " .. Format.cash(income()) .. "/s")
  end

  -- spend half of what was just earned on packs and save the rest for the next store tier
  -- or rebirth; alternate between the best booster and the set holding a card the next
  -- rebirth needs
  local budget, bought = math.min(cash, math.max(income() * STEP * 0.5, 100)), 0
  while bought < 10 do
    local wanted = wantedBooster()
    local pack = (wanted and bought % 2 == 0 and priceOf(wanted) <= budget) and wanted or bestBooster(budget)
    if pack == nil then break end
    local price = priceOf(pack)
    -- a sensible player stops buying a pack once inflation has made it cost more than two
    -- minutes of income, and saves for the next store tier or rebirth instead
    if price > math.max(income() * 120, 200) and cash < cap * 0.9 then break end
    budget = budget - price
    cash = cash - price
    openPack(pack)
    bought = bought + 1
    changed = true
  end

  dirty = dirty or changed
  sinceRebuild = sinceRebuild + STEP
  if dirty and sinceRebuild >= 60 then
    rebuildDeck()
    dirty, sinceRebuild = false, 0
  end

  -- rebirth as soon as the cash and the cards are there (aura is not simulated)
  local level = Rebirth.Levels[rebirths + 1]
  if level and cash >= level.cash and wantedBooster() == nil then
    local ready = true
    for _, id in ipairs(level.cards) do ready = ready and ownsId(id) end
    if ready then
      rebirths = rebirths + 1
      log("REBIRTH " .. rebirths .. " after " .. clock(time - runStart) .. " in this run (tier " .. tier .. ", " .. slots() .. " slots, " .. Format.cash(income()) .. "/s)")
      -- keep the best cards the vault can hold; everything else resets
      local kept = {}
      for index = 1, math.min(#deck, Rebirth.vaultSlots(rebirths - 1)) do
        kept[deck[index]] = (kept[deck[index]] or 0) + 1
      end
      owned, packCounts = kept, {}
      cash, tier, runStart = 0, 1, time
      openPack(Packs.ById[Packs.StarterId])
      rebuildDeck()
    end
  end
end
log("end: " .. rebirths .. " rebirths, tier " .. tier .. ", " .. slots() .. " slots, " .. packsOpened .. " packs, earning " .. Format.cash(income()) .. "/s")
`;

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
if (lauxlib.luaL_loadstring(L, to_luastring(program)) !== 0) throw new Error(lua.lua_tojsstring(L, -1));
lua.lua_newtable(L);
for (const name of MODULES) {
  lua.lua_pushstring(L, to_luastring(fs.readFileSync(path.join(shared, name + '.luau'), 'utf8')));
  lua.lua_setfield(L, -2, to_luastring(name));
}
lua.lua_pushnumber(L, HOURS);
if (lua.lua_pcall(L, 2, 0, 0) !== 0) console.error('Simulation failed:', lua.lua_tojsstring(L, -1));
