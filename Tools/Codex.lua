-- BiSTools / Tools / Codex.lua - BiS> CODEX, the engine (8 Nov 2026), `/bist codex`. The window: CodexWindow.lua.
--
-- Arn, 8 Nov 2026: "a unit Id compendium encyclopedia britannica style 3d models abilities etc, loot drops maybe,
-- spells, usual all available in game stuff nothing scraped from websites to keep it lean ... Like those old
-- visualization encyclopedias, that way whenever we make a game we have everything. Index already and we can api call
-- bis tools for information on 3d models".
--
-- WHAT IS SHIPPED: ids only (Tools/CodexData.lua, made by dev/codexdata.py): which creature stands in which dungeon,
-- its model id, boss or not, and for a few bosses the spell ids we could confirm. WHAT COMES LIVE, from the game:
--   names     C_TooltipInfo.GetHyperlink("unit:Creature-0-0-0-0-<npc>-0").lines[1].leftText - nil on the FIRST ask
--             (the client fetches it from the server), there on the next (CONFIRMED live 8 Nov, CODEX-RESEARCH.md
--             probe 1). Asked, then asked again C.ASK_GAP later; kept in the saved table, so once per creature ever.
--   spells    C_Spell.GetSpellName / GetSpellTexture at once; GetSpellDescription is empty until
--             C_Spell.RequestLoadSpellData and a moment after (CONFIRMED live, probe 6).
--   met       a creature you target or see a nameplate of: its name, level, rank, type, family (any may be hidden on
--             Forever: asked "secret?" first, skipped when it is), and how many times you met it (one per spawn).
--   seen cast UNIT_SPELLCAST_START / _CHANNEL_START on the target or a nameplate: the spell id, when it reads plain
--             (UNVERIFIED on Forever - an enemy's cast may be hidden; then nothing is learned).
--   dropped   LOOT_OPENED: GetLootSourceInfo(slot) names the corpse (npc id = field 6 of its GUID), GetLootSlotLink the
--             item. UNVERIFIED on Forever; every call pcalled and plain-checked. The combat log is never used.
-- LEAN: the learners run only while the tool is on (events registered in OnEnable, dropped in OnDisable). A creature
-- seen again in the same spawn costs a GUID and a check; a write happens only when something new is learned; the
-- saved tables hold one row per creature (and per item it dropped), never one per sighting. No ticker.
local _, NS = ...
local R = NS.Registry
local C = {}
NS.Codex = C
C.DATA = NS.CodexData

C.ASK_GAP, C.ASK_TRIES = 1, 3     -- the name: asked again a second later, at most three times a session
C.LOAD_WAIT = 1                   -- a spell's words: looked at again this long after the load request
C.MET_MAX = 4000                  -- creatures in the book, at most (one row each)
C.CASTS_MAX = 12                  -- spells learned per creature, at most
C.LOOT_SLOTS = 30
C.pending = {}                    -- npc -> tries, the names still being fetched
C.gaveUp = {}                     -- npc -> true: three asks, no name (this session)
C.last = {}                       -- npc -> the GUID last met (one row per creature: a new spawn = a new meeting)
C.lastLoot = {}                   -- npc -> the corpse GUID last counted
C.spellAsked = {}                 -- spell id -> true: its words were asked for this session

local function plain(v)
  if issecretvalue then
    local ok, s = pcall(issecretvalue, v)
    if not ok or s then return nil end
  end
  return v
end
C.Plain = plain

--- The tool's saved table, with its books written (never read off nil), or nil before ADDON_LOADED.
function C.DB()
  local tool = C.tool
  if not (tool and NS.DB() and NS.DB().tools) then return nil end
  local db = R:DBFor(tool)
  for _, k in ipairs({ "names", "met", "seen", "casts" }) do
    if type(db[k]) ~= "table" then db[k] = {} end
  end
  return db
end

function C.Ready() return C.DB() ~= nil end

--- The npc id in a creature's GUID ("Creature-0-4410-389-12-11520-00004A1B2C" -> 11520), or nil (a player, a pet,
--- a hidden GUID).
function C.NpcFromGUID(guid)
  guid = plain(guid)
  if type(guid) ~= "string" then return nil end
  local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
  if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
  return tonumber(id)
end

-- ------------------------------------------------------------------ names

--- One ask of the client for a creature's name; the answer is kept. nil while the client is still fetching it.
-- FOREVER ONLY: the TBC census (2.5.6) has C_TooltipInfo but not its GetHyperlink, so on that client no name ever
-- arrives and the book shows "creature <id>" (TBC is done - no fallback built). The fence does not see this call
-- through the local; it belongs in _bisdev/audit/wanted.py OPTIONAL with that reason (a bisdev follow-up).
function C.AskNow(npc)
  local TI = C_TooltipInfo
  if not (TI and TI.GetHyperlink) then return nil end
  local ok, data = pcall(TI.GetHyperlink, "unit:Creature-0-0-0-0-" .. npc .. "-0")
  if not ok or type(plain(data)) ~= "table" then return nil end
  local okL, name = pcall(function() return data.lines[1].leftText end)
  name = okL and plain(name) or nil
  if type(name) ~= "string" or name == "" then return nil end
  local db = C.DB()
  if db then db.names[npc] = name end
  return name
end

function C.Schedule()
  if C.timerOn or not next(C.pending) then return end
  C.timerOn = true
  C_Timer.After(C.ASK_GAP, function() C.Flush() end)
end

--- The second (and third) asks: everything still pending, once each; the window repaints when a name came in.
function C.Flush()
  C.timerOn = false
  local got = false
  local list = {}
  for npc in pairs(C.pending) do list[#list + 1] = npc end
  for _, npc in ipairs(list) do      -- cost: once a second while names are coming in, each asked at most 3 times
    local tries = C.pending[npc]
    if C.AskNow(npc) then
      C.pending[npc], got = nil, true
    elseif tries >= C.ASK_TRIES then
      C.pending[npc], C.gaveUp[npc] = nil, true
    else
      C.pending[npc] = tries + 1
    end
  end
  C.Schedule()
  if got and C.UI and C.UI.IsOpen() then C.UI.Paint() end
  if got and C.Drive and C.Drive.IsOpen() then C.Drive.Paint() end
  return got
end

--- A creature's name: the book's at once, or nil - and then the client is asked (a second ask follows by itself).
function C.Name(npc)
  if type(npc) ~= "number" then return nil end
  local db = C.DB()
  if not db then return nil end
  local n = db.names[npc]
  if n then return n end
  if C.pending[npc] or C.gaveUp[npc] then return nil end
  n = C.AskNow(npc)
  if n then return n end
  C.pending[npc] = 1
  C.Schedule()
  return nil
end

--- Ask for every name in a list that the book does not have yet (the index, a search): one ask each now, one later.
function C.Warm(list)
  for _, npc in ipairs(list) do C.Name(npc) end
end

-- ------------------------------------------------------------------ spells

--- A spell as the client describes it: { id, name, icon, desc }. desc is nil while the client loads its words - they
--- are asked for once, and the window looks again C.LOAD_WAIT later.
function C.Spell(id)
  local getName = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
  local getIcon = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
  local getDesc = (C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription
  local s = { id = id }
  if getName then local ok, v = pcall(getName, id) s.name = ok and plain(v) or nil end
  if getIcon then local ok, v = pcall(getIcon, id) s.icon = ok and plain(v) or nil end
  if getDesc then local ok, v = pcall(getDesc, id) s.desc = ok and plain(v) or nil end
  if type(s.name) ~= "string" then s.name = nil end
  if type(s.desc) ~= "string" or s.desc == "" then
    s.desc = nil
    local req = C_Spell and C_Spell.RequestLoadSpellData
    if req and not C.spellAsked[id] then
      C.spellAsked[id] = true
      pcall(req, id)
      C_Timer.After(C.LOAD_WAIT, function()
        if C.UI and C.UI.IsOpen() then C.UI.Paint() end
        if C.Drive and C.Drive.IsOpen() then C.Drive.Paint() end
      end)
    end
  end
  return s
end

--- An item's name and quality, when the client has them (else nil, and it is asked to load them).
function C.Item(id)
  local I = C_Item
  local name, q
  if I and I.GetItemNameByID then local ok, v = pcall(I.GetItemNameByID, id) name = ok and plain(v) or nil end
  if I and I.GetItemQualityByID then local ok, v = pcall(I.GetItemQualityByID, id) q = ok and plain(v) or nil end
  if type(name) ~= "string" then
    name = nil
    if I and I.RequestLoadItemDataByID then pcall(I.RequestLoadItemDataByID, id) end
  end
  return name, type(q) == "number" and q or nil
end

-- ------------------------------------------------------------------ what the book knows

--- Everything known about a creature, as a fresh table: { id, name, display, level, type, family, rank, dungeon,
--- boss, spells = { ids }, seen = { [item] = n }, met = n }. nil for an id neither shipped nor met.
function C.Creature(npc)
  local db = C.DB()
  if not db or type(npc) ~= "number" then return nil end
  local s, m = C.DATA.creatures[npc], db.met[npc]
  if not s and not m then return nil end
  local c = { id = npc, name = db.names[npc], display = s and s.display or nil, dungeon = s and s.d or nil,
              boss = s and s.boss or false, met = m and m.n or 0, spells = {}, seen = {} }
  if m then c.level, c.rank, c.type, c.family = m.level, m.rank, m.type, m.family end
  local had = {}
  for _, id in ipairs(s and s.spells or {}) do c.spells[#c.spells + 1] = id had[id] = true end
  local learned = {}
  for id in pairs(db.casts[npc] or {}) do if not had[id] then learned[#learned + 1] = id end end
  table.sort(learned)
  for _, id in ipairs(learned) do c.spells[#c.spells + 1] = id end
  for item, n in pairs(db.seen[npc] or {}) do c.seen[item] = n end
  return c
end

--- Every creature the book has: shipped first (in the Contents' order), then the ones only met, by id.
function C.All()
  local out, had = {}, {}
  for _, v in ipairs(C.DATA.volumes) do
    for _, d in ipairs(v.list) do
      for _, npc in ipairs(C.DATA.dungeons[d].list) do
        if not had[npc] then had[npc] = true out[#out + 1] = npc end
      end
    end
  end
  local db, extra = C.DB(), {}
  for npc in pairs(db and db.met or {}) do if not had[npc] then extra[#extra + 1] = npc end end
  table.sort(extra)
  for _, npc in ipairs(extra) do out[#out + 1] = npc end
  return out
end

--- A name's index letter: "A".."Z", or "?" (no name yet, or not a letter).
function C.Letter(name)
  local l = type(name) == "string" and name:sub(1, 1):upper() or ""
  return l:match("^%u$") and l or "?"
end

--- The index: the creatures under one letter ("?" = no name yet), or whose name holds `search`; sorted by name.
function C.Index(letter, search)
  local db = C.DB()
  if not db then return {} end
  local want = type(search) == "string" and search:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""
  local out = {}
  for _, npc in ipairs(C.All()) do
    local n = db.names[npc]
    if want ~= "" then
      if n and n:lower():find(want, 1, true) then out[#out + 1] = npc end
    elseif C.Letter(n) == letter then
      out[#out + 1] = npc
    end
  end
  table.sort(out, function(a, b)
    local na, nb = db.names[a], db.names[b]
    if na and nb and na ~= nb then return na < nb end
    if na ~= nb then return na ~= nil end
    return a < b
  end)
  return out
end

-- ------------------------------------------------------------------ the learners

--- A creature in front of you (the target, a nameplate): met once per spawn, its facts read the first time.
function C.Learn(unit)
  local db = C.DB()
  if not db then return false end
  local okG, guid = pcall(UnitGUID, unit)
  guid = okG and plain(guid) or nil
  local npc = C.NpcFromGUID(guid)
  if not npc or C.last[npc] == guid then return false end       -- the same spawn again: nothing new
  C.last[npc] = guid
  local row = db.met[npc]
  if not row then
    C.metCount = C.metCount or C.CountMet(db)
    if C.metCount >= C.MET_MAX then return false end
    row = { n = 0 }
    db.met[npc] = row
    C.metCount = C.metCount + 1
  end
  row.n = (row.n or 0) + 1
  if not row.read then
    local function ask(fn)
      if not fn then return nil end
      local ok, v = pcall(fn, unit)
      return ok and plain(v) or nil
    end
    local name, level = ask(UnitName), ask(UnitLevel)
    local rank, ctype, family = ask(UnitClassification), ask(UnitCreatureType), ask(UnitCreatureFamily)
    if type(name) == "string" and name ~= "" and not db.names[npc] then db.names[npc] = name end
    if type(level) == "number" and level > 0 then row.level = level end
    if type(rank) == "string" and rank ~= "" then row.rank = rank end
    if type(ctype) == "string" and ctype ~= "" then row.type = ctype end
    if type(family) == "string" and family ~= "" then row.family = family end
    if row.level then row.read = true end                      -- a hidden level: read again at the next meeting
  end
  return true
end

function C.CountMet(db)
  local n = 0
  for _ in pairs(db.met) do n = n + 1 end
  return n
end

--- A spell a creature was seen casting (the target or a nameplate): kept when the id reads plain.
function C.LearnCast(unit, spellID)
  if type(unit) ~= "string" or not (unit == "target" or unit:find("^nameplate%d")) then return false end
  spellID = plain(spellID)
  if type(spellID) ~= "number" then return false end
  local db = C.DB()
  if not db then return false end
  local okG, guid = pcall(UnitGUID, unit)
  local npc = C.NpcFromGUID(okG and guid or nil)
  if not npc then return false end
  local t = db.casts[npc]
  if t and t[spellID] then return false end
  if not t then t = {} db.casts[npc] = t end
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  if n >= C.CASTS_MAX then return false end
  t[spellID] = true
  return true
end

--- The loot window: each item written against the creature whose corpse it came from (once per corpse).
function C.LearnLoot()
  local db = C.DB()
  if not db then return 0 end
  local okN, n = pcall(GetNumLootItems)
  n = okN and plain(n) or nil
  if type(n) ~= "number" or n < 1 then return 0 end
  local fresh, counted, wrote = {}, {}, 0
  for slot = 1, math.min(n, C.LOOT_SLOTS) do
    local okL, link = pcall(GetLootSlotLink, slot)
    link = okL and plain(link) or nil
    local item = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
    if item then
      local src = { pcall(GetLootSourceInfo, slot) }
      for i = 2, #src, 2 do                                  -- ok, guid1, quantity1, guid2, quantity2, ...
        local guid = plain(src[i])
        local npc = C.NpcFromGUID(guid)
        if npc then
          if fresh[guid] == nil then fresh[guid] = C.lastLoot[npc] ~= guid end
          local key = guid .. ":" .. item
          if fresh[guid] and not counted[key] then
            counted[key] = true
            db.seen[npc] = db.seen[npc] or {}
            db.seen[npc][item] = (db.seen[npc][item] or 0) + 1
            wrote = wrote + 1
          end
        end
      end
    end
  end
  for guid in pairs(fresh) do
    local npc = C.NpcFromGUID(guid)
    if npc then C.lastLoot[npc] = guid end
  end
  return wrote
end

-- ------------------------------------------------------------------ events (only while the tool is on)
C.EVENTS = { "PLAYER_TARGET_CHANGED", "NAME_PLATE_UNIT_ADDED", "LOOT_OPENED", "UNIT_SPELLCAST_START",
             "UNIT_SPELLCAST_CHANNEL_START" }
C.ev = CreateFrame("Frame")
C.ev:SetScript("OnEvent", function(_, event, a, _, c)
  if event == "PLAYER_TARGET_CHANGED" then C.Learn("target")
  elseif event == "NAME_PLATE_UNIT_ADDED" then if type(a) == "string" then C.Learn(a) end
  elseif event == "LOOT_OPENED" then C.LearnLoot()
  else C.LearnCast(a, c) end
end)

function C.Listen(on)
  C.listening = on and true or false
  for _, e in ipairs(C.EVENTS) do
    if on then pcall(C.ev.RegisterEvent, C.ev, e) else pcall(C.ev.UnregisterEvent, C.ev, e) end
  end
end

function C.Listening() return C.listening == true end
