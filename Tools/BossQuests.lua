-- BiSTools / Tools / BossQuests.lua - the QUESTS tab of BiS> BOSSES (21 Nov 2026).
--
-- Arn, in Maraudon: "im in mauradon and need to target the khans", "outside the dungeon there are some too", "smartly read
-- what quest we are on and target them", "rfd has some quest outside and amabassador". Sketch A of
-- https://claude.ai/artifact/Wxkqj8rSEWemgydxo2mNEF - "A, only where i am, yes" (two tabs; the quests of this place only;
-- who in your party is on it too).
--
-- WHAT IT READS - never a creature's name (measured 21 Nov on Arn's deck: inside a dungeon a living creature's UnitName
-- and UnitGUID are SECRET, its level and rank are not):
--   the quest log   C_QuestLog.GetInfo (a header is the place: "Maraudon") and GetQuestObjectives (measured: plain inside;
--                   "0/14 Crushridge Mauler slain" = type monster, "0/10 Shadowshard Fragment" = type item, `finished`)
--   who else        C_QuestLog.IsUnitOnQuest("party1", id) (measured: plain inside and in a fight). A client that answers
--                   yes for quest 1 - there is none - is not believed (BQ.Trust)
--   item quests     the log names the item, never who carries it. BQ.OWN below (our own runs: the loot table), else the
--                   QuestieDB addon when it is installed: LibQuestieDB, its own door for other addons, asked at run time
--                   out of a fight - none of its rows are shipped here
-- DONE is the objective's own `finished` (or the item in your bags), so a hidden name never matters.
--
-- WHERE YOU ARE: inside, the dungeon's quests; in the zone of its entrance (BQ.ZONES, or a zone called like the dungeon:
-- Maraudon's outer cave), the same quests - the khans and Razorfen Downs' camps stand outside. Nothing anywhere else.
--
-- WHAT IT COSTS: nothing outside those places (QUEST_LOG_UPDATE and GROUP_ROSTER_UPDATE are registered only in one); in
-- one, a burst of quest events is one look BQ.WAIT later.
local _, NS = ...
local BQ = {}
NS.BossQuests = BQ

BQ.WAIT = 0.5
BQ.MAX_NAMES = 4          -- names one row's macro tries (an item many creatures carry)
BQ.LOG_MAX = 120          -- entries walked in the log (headers too)
BQ.CONTRACT = 4           -- LibQuestieDB's
BQ.EVENTS = { "QUEST_LOG_UPDATE", "GROUP_ROSTER_UPDATE" }

-- Ours, from our own runs (the combat log and the loot table, 21 Nov): one khan is ONE creature with two names - the
-- spirit until the Amulet of Spirits is used, the khan after - and its gem comes off it. `map` the dungeon, `out` true =
-- it stands outside the entrance, `item` in your bags = done, `all` = the finished thing (every gem in it), `say` = the
-- words of its objective in the log.
BQ.OWN = {
  [7067] = { map = 349, all = 17758, {
      { names = { "Spirit of Kolk", "Kolk" }, npc = 12240, item = 17761, out = true, note = "USE AMULET" },
      { names = { "Spirit of Gelk", "Gelk" }, npc = 12239, item = 17762, out = true, note = "USE AMULET" },
      { names = { "Spirit of Magra", "Magra" }, npc = 12241, item = 17763, out = true, note = "USE AMULET" },
      { names = { "Spirit of Maraudos", "Maraudos" }, npc = 12242, item = 17764, note = "USE AMULET" },
      { names = { "Spirit of Veng", "Veng" }, npc = 12243, item = 17765, note = "USE AMULET" },
  } },
  [6521] = { map = 129, {
      { names = { "Ambassador Malcin" }, npc = 12865, say = "Malcin", out = true },
  } },
}
-- the entrance's zone -> its dungeons (the game's own map ids; 1413 and 1443 met in our games, the rest the classic ones)
BQ.ZONES = {
  [1413] = { 43, 47, 129 }, [1418] = { 70 }, [1420] = { 189, 2999 }, [1421] = { 33 }, [1422] = { 289 }, [1423] = { 329 },
  [1426] = { 90 }, [1427] = { 230, 229 }, [1428] = { 230, 229 }, [1435] = { 109 }, [1436] = { 36 }, [1437] = { 2998 },
  [1440] = { 48 }, [1443] = { 349 }, [1444] = { 429 }, [1446] = { 209 }, [1453] = { 34 }, [1454] = { 389 },
}
BQ.ALSO = { [109] = { "The Temple of Atal'Hakkar" }, [34] = { "The Stockade" } }     -- the log's other name for a place

local function plain(v)
  if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
  return v
end
local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a = pcall(fn, ...)
  if not ok then return nil end
  return plain(a)
end
local function words(v) v = plain(v) return type(v) == "string" and v or nil end
local function number(v) v = plain(v) return type(v) == "number" and v or nil end

--- A place's name the way we compare it: lower case, no leading "the".
function BQ.Norm(s)
  s = words(s)
  if not s then return nil end
  return (s:lower():gsub("^the ", ""))
end

-- ------------------------------------------------------------------ where

--- The place for these dungeons: which quest headers and zones count as it.
function BQ.Place(ids, inside, zone)
  local D = NS.BossData or {}
  local p = { ids = {}, heads = {}, inside = inside and true or false, zone = zone }
  for _, id in ipairs(ids) do
    local d = D[id]
    if d then
      p.ids[#p.ids + 1] = id
      p.heads[BQ.Norm(d.name)] = id
      for _, n in ipairs(BQ.ALSO[id] or {}) do p.heads[BQ.Norm(n)] = id end
    end
  end
  if #p.ids == 0 then return nil end
  p.key = (inside and "in:" or "out:") .. table.concat(p.ids, ",")
  return p
end

--- Outside: the dungeons whose entrance is in this zone (by its map, or a zone called like one), or nil. The second answer
--- is true when the game has no map for us yet (a loading screen): ask again.
function BQ.Outside()
  local ids, seen = {}, {}
  local function add(id) if not seen[id] then seen[id] = true ids[#ids + 1] = id end end
  local map = C_Map and ask(C_Map.GetBestMapForUnit, "player")
  local zone
  local m, hops = number(map), 0
  while m and hops < 4 do
    for _, id in ipairs(BQ.ZONES[m] or {}) do add(id) end
    local ok, info = pcall(C_Map.GetMapInfo, m)
    info = ok and type(info) == "table" and info or nil
    if hops == 0 and info then zone = words(info.name) end
    m = info and number(info.parentMapID) or nil
    hops = hops + 1
    if #ids > 0 then break end
  end
  local here = BQ.Norm(ask(GetRealZoneText))
  local sub = BQ.Norm(ask(GetSubZoneText))
  for id, d in pairs(NS.BossData or {}) do
    local n = BQ.Norm(d.name)
    if n and (n == here or n == sub) then add(id) end
  end
  table.sort(ids)
  if #ids == 0 then return nil, map == nil end
  return BQ.Place(ids, false, zone or words(ask(GetRealZoneText)))
end

-- ------------------------------------------------------------------ the quest log

--- Every quest in the log: { id, title, header }.
function BQ.Log()
  local out, header = {}, nil
  local Q = C_QuestLog
  local n = Q and number(ask(Q.GetNumQuestLogEntries)) or 0
  for i = 1, math.min(n, BQ.LOG_MAX) do
    local ok, q = pcall(Q.GetInfo, i)
    if ok and type(q) == "table" then
      if plain(q.isHeader) then header = words(q.title)
      else
        local id = number(q.questID)
        if id and not plain(q.isHidden) then out[#out + 1] = { id = id, title = words(q.title) or "", header = header } end
      end
    end
  end
  return out
end

--- Who a kill objective names: "0/14 Crushridge Mauler slain" (measured) or "Crushridge Mauler slain: 0/14".
function BQ.Kill(text)
  text = words(text)
  if not text then return nil end
  text = text:gsub("^%s*%d+%s*/%s*%d+%s*", ""):gsub("%s*:%s*%d+%s*/%s*%d+%s*$", "")
  local name = text:match("^(.-)%s+slain$")
  return name ~= "" and name or nil
end

-- ------------------------------------------------------------------ QuestieDB, when it is there

function BQ.DB()
  local L = _G.LibQuestieDB
  if type(L) ~= "table" or type(L.RequireContract) ~= "function" then return nil end
  local ok, yes = pcall(L.RequireContract, BQ.CONTRACT)
  if not ok or yes ~= true then return nil end
  return L
end
local function field(L, ent, key, id)
  local e = L and L[ent]
  local fn = type(e) == "table" and e[key]
  if type(fn) ~= "function" or not id then return nil end
  local ok, v = pcall(fn, id)
  return ok and v or nil
end

--- Which of the place's dungeons this creature belongs to, by its zone's own name in the client.
function BQ.NpcPlace(L, npc, place)
  local area = number(field(L, "Npc", "zoneID", npc))
  if not area or area == 0 or not (C_Map and C_Map.GetAreaInfo) then return nil end
  return place.heads[BQ.Norm(ask(C_Map.GetAreaInfo, area)) or ""]
end

--- Names to try for an objective out of the creatures the book lists: the ones of this place first, else all, a few.
function BQ.Pick(L, npcs, place)
  local here, all, at = {}, {}, nil
  for _, id in ipairs(type(npcs) == "table" and npcs or {}) do
    local npc = number(type(id) == "table" and id[1] or id)
    local name = words(field(L, "Npc", "name", npc))
    if name then
      local p = BQ.NpcPlace(L, npc, place)
      if p then at = at or p here[#here + 1] = { name = name, npc = npc } end
      all[#all + 1] = { name = name, npc = npc }
    end
  end
  local from = #here > 0 and here or all
  local names, seen = {}, {}
  for _, x in ipairs(from) do
    if not seen[x.name] and #names < BQ.MAX_NAMES then seen[x.name] = true names[#names + 1] = x.name end
  end
  return names, from[1] and from[1].npc or nil, at
end

-- ------------------------------------------------------------------ the rows

local function have(item)
  local f = (C_Item and C_Item.GetItemCount) or GetItemCount
  return item and (number(ask(f, item)) or 0) or 0
end

--- Our own table's rows for one quest.
function BQ.FromOwn(rows, q, own, objs)
  local whole = own.all and have(own.all) > 0
  for k, t in ipairs(own[1]) do
    local e = { id = "q" .. q.id .. ":" .. k, q = true, quest = q.id, title = q.title, name = t.names[1], names = t.names,
      npc = t.npc, note = t.note, out = t.out, place = own.map, need = 1, have = 0 }
    if t.item then e.have = (whole or have(t.item) > 0) and 1 or 0 end
    for _, o in ipairs(objs) do
      local txt = t.say and words(o.text)
      if txt and txt:find(t.say, 1, true) then
        e.have, e.need = number(o.numFulfilled) or 0, number(o.numRequired) or 1
        if plain(o.finished) == true then e.have = e.need end
      end
    end
    e.done = e.have >= e.need
    rows[#rows + 1] = e
  end
end

--- The rows of one quest out of its objectives; `at` = the place its header names (nil = not by its header).
function BQ.FromLog(rows, q, objs, place, at, L)
  local book = field(L, "Quest", "objectives", q.id)
  local kills, items = 0, 0
  local unknown = 0
  for k, o in ipairs(objs) do
    local kind = words(o.type)
    local names, npc, where = nil, nil, nil
    if kind == "monster" then
      kills = kills + 1
      local row = type(book) == "table" and type(book[1]) == "table" and book[1][kills] or nil
      local id = row and number(row[1])
      local said = BQ.Kill(o.text)
      if id then
        names, npc, where = BQ.Pick(L, { id }, place)
        if said and (#names == 0 or names[1] ~= said) then names, npc = { said }, (names[1] == said) and npc or nil end
      elseif said then names = { said } end
    elseif kind == "item" then
      items = items + 1
      local row = type(book) == "table" and type(book[3]) == "table" and book[3][items] or nil
      local id = row and number(row[1])
      if id then names, npc, where = BQ.Pick(L, field(L, "Item", "npcDrops", id), place) end
    end
    where = at or where
    if where and names and #names > 0 then
      local need, got = number(o.numRequired) or 1, number(o.numFulfilled) or 0
      local done = plain(o.finished) == true
      rows[#rows + 1] = { id = "q" .. q.id .. ":" .. k, q = true, quest = q.id, title = q.title, name = names[1],
        names = names, npc = npc, place = where, need = need, have = done and need or got, done = done, what = words(o.text) }
    elseif at and (kind == "item" or kind == "monster") and plain(o.finished) ~= true then
      unknown = unknown + 1
    end
  end
  return unknown
end

--- Does this client's IsUnitOnQuest mean anything? A yes for quest 1 (there is none) is not believed.
function BQ.Trust(unit)
  local f = C_QuestLog and C_QuestLog.IsUnitOnQuest
  if type(f) ~= "function" then return false end
  local ok, v = pcall(f, unit, 1)
  return ok and plain(v) ~= true
end

--- Who in your party is on this quest too: { { name, class } } (names of players in your group are plain).
function BQ.Who(quest, units)
  local out = {}
  for _, u in ipairs(units) do
    if ask(C_QuestLog.IsUnitOnQuest, u.token, quest) == true then out[#out + 1] = u end
  end
  return out
end
function BQ.Party()
  local out = {}
  for i = 1, 4 do
    local t = "party" .. i
    if ask(UnitExists, t) and BQ.Trust(t) then
      local name = words(ask(UnitName, t))
      local ok, _, class = pcall(UnitClass, t)
      if name then out[#out + 1] = { token = t, name = name, class = ok and words(class) or nil } end
    end
  end
  return out
end

--- The place's quest rows, in the log's order; and how many objectives nobody can name.
function BQ.Rows(place)
  local rows, unknown = {}, 0
  if not place then return rows, 0 end
  local L = BQ.DB()
  local party = BQ.Party()
  for _, q in ipairs(BQ.Log()) do
    local ok, objs = pcall(C_QuestLog.GetQuestObjectives, q.id)
    objs = ok and type(objs) == "table" and objs or {}
    local own = BQ.OWN[q.id]
    local from = #rows
    local mine = false
    if own then for _, id in ipairs(place.ids) do if id == own.map then mine = true end end end
    if mine then BQ.FromOwn(rows, q, own, objs)
    elseif not own then
      unknown = unknown + BQ.FromLog(rows, q, objs, place, place.heads[BQ.Norm(q.header) or ""], L)
    end
    if #rows > from and #party > 0 then
      local who = BQ.Who(q.id, party)
      for i = from + 1, #rows do rows[i].who = who end
    end
  end
  return rows, unknown
end

--- What the phone's title says outside: the one dungeon the rows belong to, else the zone.
function BQ.Title(place, rows)
  local one
  for _, e in ipairs(rows) do
    if one and e.place ~= one then one = nil break end
    one = one or e.place
  end
  if not one and #place.ids == 1 then one = place.ids[1] end
  local d = one and NS.BossData and NS.BossData[one]
  return (d and (d.name .. ", outside")) or place.zone or "outside", one
end

-- ------------------------------------------------------------------ listening (only in a place: BF.Eyes)

local ev = CreateFrame("Frame")
BQ.events = ev
function BQ.Listen(on)
  for _, e in ipairs(BQ.EVENTS) do
    if on then pcall(ev.RegisterEvent, ev, e) else pcall(ev.UnregisterEvent, ev, e) end
  end
  BQ.listening = on and true or false
end
ev:SetScript("OnEvent", function()
  if BQ.pending or not BQ.listening then return end
  BQ.pending = true
  C_Timer.After(BQ.WAIT, function()
    BQ.pending = nil
    if BQ.listening and NS.Bosses then NS.Bosses.QuestsNow() end
  end)
end)
