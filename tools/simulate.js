// Balance simulator: plays a simple greedy player through the real game tables and prints
// how long each milestone takes. Run:  cd tools && npm install && node simulate.js [hours]
// It loads the Luau modules from src/shared in a Lua VM with small stubs for Roblox types.
const { lua, lauxlib, lualib, to_luastring } = require('fengari');
const fs = require('fs');
const path = require('path');

const HOURS = Number(process.argv[2] || 6);
const shared = path.join(__dirname, '..', 'src', 'shared');
const MODULES = ['Config', 'Format', 'Cards', 'Packs', 'Combos', 'Deck', 'Upgrades', 'Rebirth'];

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

local cash, time, tier, slotLevel, packsOpened = 0, 0, 1, 0, 0
local owned, deck = {}, {}
local STEP = 10

local function clock()
  local h = math.floor(time / 3600)
  local m = math.floor(time % 3600 / 60)
  local s = math.floor(time % 60)
  return string.format("%dh %02dm %02ds", h, m, s)
end
local function log(text) print(string.format("%-12s %s", clock(), text)) end
local deckScore = 0 -- cached: scoring the deck is the slow part
local function income() return deckScore * Upgrades.StoreTiers[tier].mult end
local function rebuildDeck(slots)
  deck = Deck.autoFill(owned, slots)
  deckScore = Deck.score(deck)
end
local function openPack(pack)
  for _, key in ipairs(Packs.open(pack, 0, rng)) do owned[key] = (owned[key] or 0) + 1 end
  packsOpened = packsOpened + 1
end
local function bestBooster(budget)
  local best = nil
  for _, pack in ipairs(Packs.List) do
    if pack.kind == "booster" and pack.storeTier <= tier and pack.cost <= budget and (best == nil or pack.cost > best.cost) then
      best = pack
    end
  end
  return best
end
local function ownedCount() local n = 0 for _, c in pairs(owned) do n = n + c end return n end

openPack(Packs.ById[Packs.StarterId]) -- the free starter pack
rebuildDeck(Config.BaseSlots)
log("start: free pack opened, earning " .. Format.cash(income()) .. "/s")

local rebirthLevel = Rebirth.Levels[1]
local rebirthLogged = false
local dirty, sinceRebuild = false, 0
while time < HOURS * 3600 do
  time = time + STEP
  cash = cash + income() * STEP
  local changed = false

  local nextTier = Upgrades.StoreTiers[tier + 1]
  if nextTier and cash >= nextTier.cost then
    cash = cash - nextTier.cost
    tier = tier + 1
    log("store tier " .. tier .. " (" .. nextTier.name .. "), earning " .. Format.cash(income()) .. "/s")
  end

  -- spend up to half the cash on the best booster available
  local budget, bought = cash * 0.5, 0
  local pack = bestBooster(budget)
  while pack and bought < 10 and budget >= pack.cost do
    budget = budget - pack.cost
    cash = cash - pack.cost
    openPack(pack)
    bought = bought + 1
    changed = true
  end

  -- buy a deck slot when there are spare cards to put in it
  local slotDef = Upgrades.Defs.slots
  while slotLevel < slotDef.max and cash >= slotDef.cost(slotLevel) and ownedCount() > Config.BaseSlots + slotLevel do
    cash = cash - slotDef.cost(slotLevel)
    slotLevel = slotLevel + 1
    changed = true
    if (Config.BaseSlots + slotLevel) % 8 == 0 then
      log((Config.BaseSlots + slotLevel) .. " deck slots")
    end
  end

  -- rebuild the deck at most once a simulated minute
  dirty = dirty or changed
  sinceRebuild = sinceRebuild + STEP
  if dirty and sinceRebuild >= 60 then
    rebuildDeck(Config.BaseSlots + slotLevel)
    dirty, sinceRebuild = false, 0
  end

  if not rebirthLogged and cash >= rebirthLevel.cash then
    local hasCards = true
    for _, id in ipairs(rebirthLevel.cards) do
      local found = false
      for key in pairs(owned) do
        local def = Cards.parse(key)
        if def and def.id == id then found = true end
      end
      hasCards = hasCards and found
    end
    if hasCards then
      rebirthLogged = true
      log("first rebirth's cash and cards met (aura not simulated)")
    end
  end
end
log("end: tier " .. tier .. ", " .. (Config.BaseSlots + slotLevel) .. " slots, " .. packsOpened .. " packs, earning " .. Format.cash(income()) .. "/s")
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
