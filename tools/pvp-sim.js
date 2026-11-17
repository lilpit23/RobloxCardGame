// Plays player duels between bots to check their length and how much rarity decides them.
// Usage: cd tools && npm install && node pvp-sim.js
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
-- a deck of 20 cards: maxOrder = rarest rarity allowed, setId = only that set (nil = any)
local function deck(maxOrder, typeId)
  local pool={} for _,d in ipairs(Cards.List) do local o=Cards.Rarities[d.rarity].order
    if o<=maxOrder and o>=math.max(1,maxOrder-2) and (typeId==nil or d.type==typeId) then pool[#pool+1]=d.id end end
  local out={} for i=1,20 do out[i]=pool[math.random(1,#pool)] end return out
end
local function bot(view)
  -- PvP cards: rate by the PvP numbers, using the shared suggester for the shape of the move
  local a=Duel.suggest(view) return a
end
local Training=require({__mod="Training"})
local function trained(level) local t={} for _,id in ipairs(Training.Order) do t[id]=math.min(level,Training.Defs[id].max) end local st=Training.stats(t) st.levels=Training.total(t) return st end
local function match(da,db,ta,tb)
  local s=Duel.pvpNew(da,"A",db,"B",rng,ta,tb)
  while not s.over do
    for side=1,2 do assert(Duel.pvpChoose(s,side,bot(Duel.pvpView(s,side)))) end
    Duel.pvpResolve(s,rng)
  end
  return s.winner,s.round
end
local function series(label,ma,ta,mb,tb,n,traina,trainb)
  local w={[0]=0,0,0} local rounds=0
  for i=1,n do local x,r=match(deck(ma,ta),deck(mb,tb),traina,trainb) w[x]=w[x]+1 rounds=rounds+r end
  print(string.format("%-36s A wins %3d%%  B wins %3d%%  draws %2d%%  avg %.1f rounds",label,w[1]*100//n,w[2]*100//n,w[0]*100//n,rounds/n))
end
series("Commons vs Commons",2,nil,2,nil,300)
series("Rares vs Rares",3,nil,3,nil,300)
series("Commons vs Legendaries",2,nil,5,nil,300)
series("Rares vs Epics",3,nil,4,nil,300)
series("Legendaries vs Secrets",5,nil,7,nil,300)
series("Epics: training 2 vs none",4,nil,4,nil,300,trained(2),nil)
series("Epics: full training vs none",4,nil,4,nil,300,trained(5),nil)
series("Commons+full training vs Secrets",2,nil,7,nil,300,trained(5),nil)
for level,settings in ipairs(Duel.PracticeLevels) do
  local st=Duel.practiceTraining(level,Training)
  local w=0 for i=1,300 do local s=Duel.pvpNew(Duel.practiceDeck(2,rng),"P",Duel.practiceDeck(level,rng),"Bot",rng,nil,st)
    while not s.over do assert(Duel.pvpChoose(s,1,bot(Duel.pvpView(s,1)))) assert(Duel.pvpChoose(s,2,Duel.botMove(s,2,level,rng))) Duel.pvpResolve(s,rng) end
    if s.winner==1 then w=w+1 end end
  print(string.format("%-36s player wins %3d%%","auto deck vs "..settings.name.." bot",w*100//300))
end
for _,t in ipairs(Cards.TypeOrder) do series("mono "..t.." vs mixed (Epic)",4,t,4,nil,300) end
`;
lauxlib.luaL_loadstring(L,to_luastring(pre));
lua.lua_newtable(L);for(const n of ['Cards','Format','Duel','Config','Training','Battle']){lua.lua_pushstring(L,to_luastring(fs.readFileSync(dir+n+'.luau','utf8')));lua.lua_setfield(L,-2,to_luastring(n));}
if(lua.lua_pcall(L,1,0,0)!==0)console.log('ERR',lua.lua_tojsstring(L,-1));
