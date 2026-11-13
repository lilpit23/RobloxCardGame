// Plays tower duels with a simple bot to show how far different collections climb.
// Usage: cd tools && npm install && node duel-sim.js
const {lua,lauxlib,lualib,to_luastring}=require('fengari');const fs=require('fs');
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
const dir=require('path').join(__dirname,'..','src','shared')+'/';
const pre=`
table.find=function(t,v) for i,x in ipairs(t) do if x==v then return i end end end
table.clone=function(t) local c={} for k,v in pairs(t) do c[k]=v end return c end
math.clamp=function(x,a,b) return math.max(a,math.min(b,x)) end
local C3={} C3.__index=C3 function C3:Lerp() return self end
Color3={fromRGB=function() return setmetatable({},C3) end,new=function() return setmetatable({},C3) end}
local loaded={} local sources=...
local function mk() return setmetatable({},{__index=function(_,k) if k=="Parent" then return setmetatable({},{__index=function(_,n) return {__mod=n} end}) end end}) end
function require(m) local n=m.__mod if not loaded[n] then local env=setmetatable({script=mk()},{__index=_G}) loaded[n]=assert(load(sources[n],n,"t",env))() end return loaded[n] end
local Cards=require({__mod="Cards"}) local Duel=require({__mod="Duel"})
local rng={NextNumber=function() return math.random() end,NextInteger=function(_,a,b) return math.random(a,b) end}
local roles={} for _,d in ipairs(Cards.List) do local r=Duel.card(d.id).role roles[r]=(roles[r] or 0)+1 end
for r,n in pairs(roles) do io.write(r,"=",n," ") end print()
local function bot(state)
  local a=Duel.suggest(Duel.view(state))
  if a.kind=="play" then return Duel.play(state,a.hand,a.target,rng) end
  return Duel.pass(state,rng)
end
local function winrate(profile,floor,n)
  local deck=Duel.usableDeck(profile,Duel.autoDeck(profile)) local w,rounds=0,0
  for i=1,n do local s=Duel.new(floor,deck,rng) while not s.over do assert(bot(s)) end if s.win then w=w+1 end rounds=rounds+s.round end
  return w/n,rounds/n,deck
end
print("daily challenge (bot win rate):")
for day=0,13 do local c=Duel.challenge(day) local w,rounds=0,0
  for i=1,60 do local st=Duel.new(c.floor,c.deck,rng,"daily",Duel.enemies(c.floor,c.power,c.set)) while not st.over do assert(bot(st)) end if st.win then w=w+1 end rounds=rounds+st.round end
  print("  day "..day.." "..c.set.." floor "..c.floor.." deck "..#c.deck..": "..math.floor(w/60*100).."% "..string.format("%.0f",rounds/60).."r") end
local function top(profile,label)
  local best=0 local line={} firstfail=nil
  for floor=1,50 do local w,r=winrate(profile,floor,30) if w>=0.5 then best=floor end if floor%5==0 or floor<4 then line[#line+1]=floor..":"..math.floor(w*100).."%/"..string.format("%.0f",r).."r" end if w==0 and floor>best+3 then break end if w<0.5 and not firstfail then firstfail=floor end end
  local deck=Duel.autoDeck(profile) local costs={} for _,k in ipairs(deck) do costs[#costs+1]=Duel.card(k).cost end
  print(label,"deck "..#deck.." hp "..Duel.deckHealth(deck),"first wall "..tostring(firstfail).." max "..best,table.concat(line," "))
end
-- starter: 5 commons
top({inventory={honey_bee=1},slots={},vault={}},"1 card")
local inv={} local n=0 for _,d in ipairs(Cards.List) do if d.set=="storybook" and d.rarity=="Common" and n<5 then inv[d.id]=1 n=n+1 end end
top({inventory=inv,slots={},vault={}},"5 commons")
for s,setId in ipairs(Cards.SetOrder) do
  local inv={} for _,d in ipairs(Cards.List) do if table.find(Cards.SetOrder,d.set)<=s and Cards.Rarities[d.rarity].order<=5 then inv[d.id]=2 end end
  top({inventory=inv,slots={},vault={}},"sets<="..s.." up to Legendary x2")
end
local inv={} for _,d in ipairs(Cards.List) do inv[d.id..":prism"]=3 end
top({inventory=inv,slots={},vault={}},"everything prism")
local inv={} for _,d in ipairs(Cards.List) do inv[d.id..":gold"]=1 end
top({inventory=inv,slots={},vault={}},"everything gold x1")
`;
lauxlib.luaL_loadstring(L,to_luastring(pre));
lua.lua_newtable(L);for(const n of ['Cards','Format','Duel','Config']){lua.lua_pushstring(L,to_luastring(fs.readFileSync(dir+n+'.luau','utf8')));lua.lua_setfield(L,-2,to_luastring(n));}
if(lua.lua_pcall(L,1,0,0)!==0)console.log('ERR',lua.lua_tojsstring(L,-1));
