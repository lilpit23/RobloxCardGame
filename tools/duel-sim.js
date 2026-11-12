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
  local best,bi,bt=-1,nil,nil
  local low,li=math.huge,nil
  for i,e in ipairs(state.enemies) do if e.hp>0 and e.hp<low then low,li=e.hp,i end end
  for i,key in ipairs(state.hand) do local c=Duel.card(key)
    if c.cost<=state.energy then
      local score=0 local t=li
      if c.role=="attack" then
        for j,e in ipairs(state.enemies) do if e.hp>0 then local d=c.amount*(Cards.typeBeats(c.type,e.type) and 1.3 or (Cards.typeBeats(e.type,c.type) and .75 or 1)) local s=math.min(d,e.hp)+(d>=e.hp and e.attack*3 or 0) if s>score then score,t=s,j end end end
      elseif c.role=="blast" then for j,e in ipairs(state.enemies) do if e.hp>0 then score=score+math.min(c.amount,e.hp) end end
      elseif c.role=="heal" then score=math.min(c.amount,state.maxHp-state.hp)*1.2
      elseif c.role=="shield" then local a=0 for _,e in ipairs(state.enemies) do if e.hp>0 then a=math.max(a,e.attack*(e.winding and 2.5 or 1)) end end score=(#state.shields==0) and a*c.amount*1.5 or 0
      elseif c.role=="charge" then score=(#state.charges==0) and 1 or 0
      else score=0.5 end
      if score>best then best,bi,bt=score,i,t end
    end
  end
  if bi and best>0 then return Duel.play(state,bi,bt,rng) end
  return Duel.pass(state,rng)
end
local function winrate(profile,floor,n)
  local deck=Duel.usableDeck(profile,Duel.autoDeck(profile)) local w,rounds=0,0
  for i=1,n do local s=Duel.new(floor,deck,rng) while not s.over do assert(bot(s)) end if s.win then w=w+1 end rounds=rounds+s.round end
  return w/n,rounds/n,deck
end
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
