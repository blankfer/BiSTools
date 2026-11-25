-- BiSTools / Tools / Bosses.lua - BiS> BOSSES, the boss finder (8 Nov 2026), `/bist bosses` (short `boss`).
--
-- Arn, 8 Nov: "boss finder in dungeons, we have all the bosses in wow forever bis tools boss smartly sees what dungeon
-- on me generates a list and does a couple of things, targets and puts a raid icon on each of them if I click a name
-- on that one, all button tries to target each one an assign a raid marker to them. A find mode pings them by
-- targeting them and pinging like our bis healing ping binds, cockpit view maybe some sort of gauge or synth wave or
-- progress bar".
--
-- WHERE AM I: GetInstanceInfo's 8th answer is the instance's map id; Tools/BossData.lua (the client's own
-- DungeonEncounter table) has every dungeon and raid by that id, its bosses in the game's order.
--
-- WHAT A PRESS DOES - all Blizzard's own commands in a secure macro, because on Forever an addon may not target
-- (TargetUnit is protected), may not mark (SetRaidTarget, BugGrabber 6 Oct) and may not ping (C_Ping, 1 Oct); a macro
-- the player's click runs may do all three (the farm key's /tm !N, BiS Healing's /ping):
--   /cleartarget                      -- so a boss NOT in sight leaves nothing targeted, and /tm marks nobody
--   /targetexact <boss>               -- the client's own search of what is around you
--   /tm [exists] !8                   -- its mark ("!" = set, never toggle off - RestedXP's way, live 6 Oct)
--   /ping [exists] attack             -- FIND only (or shift on a row): the party sees it
--   /targetlasttarget [noexists]      -- not found: your old target back
-- UNVERIFIED on Forever: `/tm` with a [condition] (the client's /tm reads its options like /cast does), and how long
-- a button's macro may be (BF.MACRO_MAX = 255, the macro window's own limit, to be safe).
-- Rows and keys are written OUT OF COMBAT only (a secure attribute cannot change in a fight); the window steps away
-- when a fight starts (it holds secure buttons, so it cannot hide in one) and comes back after.
--
-- WHAT IT KNOWS - never the combat log (forbidden on Forever):
--   IN SIGHT  a nameplate with that name is up (NAME_PLATE_UNIT_ADDED / _REMOVED)
--   MARKED    your press targeted it (PostClick reads your target's name)
--   DOWN      ENCOUNTER_END with success, or the boss seen dead (a plate, your target)
-- The run (`db.run`) lasts while you come back to the same place within BF.RUN_GAP; RESET starts it again.
--
-- WHAT IT COSTS: nothing outside a dungeon or raid of the list (the nameplate events are registered only inside one).
-- Inside: a nameplate coming up is one name read; one going away, one walk of the plates. The window's screen runs an
-- OnUpdate at BF.FPS only while it is shown.
local _, NS = ...
local R = NS.Registry
local BF = {}
NS.Bosses = BF

-- A PHONE (Arn, 21 Nov 2026, over a shot of the wide window: "this like a phone too"; sketch A of
-- https://claude.ai/artifact/BwkBfcV2HXsRUo5Nu89aVb - "A, drop, this one": the boss on top, the needle gauge gone, this
-- window only - the rest of the family stays 1.43:1). Every height comes from the ones above it, so no part can grow
-- into its neighbour; the suite measures the built boxes.
BF.W, BF.H = 240, 427              -- 9:16
BF.SCALE = 1.35                    -- as high as the probe deck's phone; its letters are a point bigger than the wide one's
BF.PAD = 8
BF.ROWS, BF.ROW = 8, 18
BF.SCREEN_H = 112                  -- the boss, edge to edge (top of the phone)
BF.TITLE_Y = BF.SCREEN_H + 5       -- the place's name
BF.BOX_Y, BF.BOX_H = BF.TITLE_Y + 17, 25          -- down / in sight / marked
BF.TAB_Y, BF.TAB_H = BF.BOX_Y + BF.BOX_H + 3, 17              -- BOSSES / QUESTS (BossQuests.lua)
BF.TAPE_Y, BF.TAPE_H = BF.TAB_Y + BF.TAB_H + 2, 3
BF.ROWS_Y = BF.TAPE_Y + BF.TAPE_H + 3
BF.PAGE_Y, BF.PAGE_H = BF.ROWS_Y + BF.ROWS * BF.ROW + 2, 13   -- < > and what the last press did
BF.FIND_Y, BF.FIND_H = BF.PAGE_Y + BF.PAGE_H + 4, 26
BF.KEYS_Y, BF.KEYS_H = BF.FIND_Y + BF.FIND_H + 4, 18          -- MARK ALL, RESET
BF.HELP_Y = BF.KEYS_Y + BF.KEYS_H + 4
BF.HOME = 3                        -- the home bar, from the bottom
BF.CHECK = "Interface\\RaidFrame\\ReadyCheck-Ready"
BF.CLOCK_EVERY = 1                 -- the clock at the top: looked at once a second, only while shown
BF.SPOT = { 300, 0 }               -- never dragged: right of your character, not over it
BF.MARKS = { 8, 7, 6, 5, 4, 3, 2, 1 }      -- skull, cross, square, moon, triangle, diamond, circle, star
BF.MARK_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
BF.MACRO_MAX = 255
BF.RUN_GAP = 3600                  -- back in the same place within an hour: the same run
BF.PING = "attack"
BF.FPS = 20
BF.GLOW = 0.35
BF.TAPE_MAX = 30                   -- Blackrock Depths has 21
BF.MODEL_TRIES = 4
BF.MODEL_WAIT = 0.6
BF.MISS_GAP = 2                    -- no picture for a boss: look again (the Codex may have its name by now) after this
BF.ICON = "Interface\\Icons\\Ability_Warrior_Challange"
BF.ROUND = "Interface\\AddOns\\BiSTools\\Media\\Round"
-- the screen's sunset: our own colours (a synthwave sky, Arn: "maybe some sort of gauge or synth wave")
BF.SKY = { { 0.09, 0.04, 0.20 }, { 0.20, 0.05, 0.33 }, { 0.38, 0.07, 0.42 }, { 0.62, 0.10, 0.45 }, { 0.90, 0.30, 0.42 } }
BF.SUN = { 1.00, 0.55, 0.35 }
BF.GRID = { 1.00, 0.25, 0.75 }
BF.STATE_INK = { down = "good", near = "gold", marked = "accent", far = "ink2", group = "slate" }
BF.STATE_WORD = { down = "DOWN", near = "IN SIGHT", marked = "FOUND", far = "", group = "GROUP" }
-- AN ENCOUNTER'S NAME IS NOT ALWAYS THE CREATURE'S (21 Nov: /targetexact wants the creature's): tried second. Infurnus and
-- The Butcher are unknown still.
BF.ALT = {
  ["Kirtonos"] = "Kirtonos the Herald", ["Ras Frostwhisperer"] = "Ras Frostwhisper", ["Geilhast"] = "Gelihast",
  ["Handler Ashka"] = "War Handler Ashka", ["Overseer Mugg"] = "Overlord Mugg",
}

local TAU = 2 * math.pi
local function K() return NS.Farm end
local function rgb(name) return K().color(name) end
local function plain(v)
  if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
  return v
end
local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a = pcall(fn, ...)
  return ok and plain(a) or nil
end
local function fighting() return (InCombatLockdown and InCombatLockdown()) and true or false end
local function now() return (time and time()) or 0 end

-- ------------------------------------------------------------------ where am I

--- The boss place you stand in: its map id and its data, or nil (outside, a battleground, a place not in the list).
function BF.Here()
  if not IsInInstance then return nil end
  local ok, inside, kind = pcall(IsInInstance)
  if not ok or plain(inside) ~= true then return nil end
  kind = plain(kind)
  if kind ~= "party" and kind ~= "raid" then return nil end
  if not GetInstanceInfo then return nil end
  local okI, _, _, _, _, _, _, _, map = pcall(GetInstanceInfo)
  map = okI and plain(map) or nil
  local data = type(map) == "number" and NS.BossData and NS.BossData[map] or nil
  if not data then return nil end
  return map, data
end

--- The run in this place: kept while you come back within BF.RUN_GAP, else a fresh one.
function BF.Run(db, map, fresh)
  local r = db.run
  local t = now()
  if fresh or type(r) ~= "table" or r.map ~= map or (t - (r.at or 0)) > BF.RUN_GAP then
    r = { map = map, at = t, down = {}, marked = {} }
    db.run = r
  end
  r.at = t
  r.down, r.marked = r.down or {}, r.marked or {}
  return r
end

-- ------------------------------------------------------------------ the list and its marks

--- Each boss's state word: down, near (in sight), marked, group (a fight of several, never targeted), far.
function BF.State(e)
  local r = BF.run
  if e.q then                                             -- a quest's row: its own count says done, never a name
    if e.done then return "down" end
    for _, n in ipairs(e.names) do if BF.near[n] then return "near" end end
    return BF.found[e.id] and "marked" or "far"
  end
  if r and r.down[e.id] then return "down" end
  if e.group then return "group" end
  if BF.near[e.name] then return "near" end
  if r and r.marked[e.id] then return "marked" end
  return "far"
end

--- The marks: every boss still standing that can be targeted by name gets one, in the game's order, skull first;
--- past eight, none.
function BF.Assign()
  local m, k = {}, 0
  for _, e in ipairs(BF.list or {}) do
    if not e.group and BF.State(e) ~= "down" then
      k = k + 1
      m[e.id] = BF.MARKS[k]
    end
  end
  BF.mark = m
  return m
end

--- Counts for the gauge: down, in sight and marked (of the ones still standing), all.
function BF.Counts()
  local c = { down = 0, near = 0, marked = 0, all = 0 }
  local r = BF.run
  for _, e in ipairs(BF.list or {}) do
    local st = BF.State(e)
    c.all = c.all + 1
    if st == "down" then
      c.down = c.down + 1
    else
      if st == "near" then c.near = c.near + 1 end
      if (e.q and BF.found[e.id]) or (not e.q and r and r.marked[e.id]) then c.marked = c.marked + 1 end
    end
  end
  return c
end

-- ------------------------------------------------------------------ the macros (the suite runs them)

--- The lines that look for one boss: clear, search, mark (when it has one), ping (find, or shift on a row).
function BF.Names(e)
  if e.names then return e.names end
  return BF.ALT[e.name] and { e.name, BF.ALT[e.name] } or { e.name }
end
function BF.Lines(e, ping, most)
  local out = { "/cleartarget" }
  for i, n in ipairs(BF.Names(e)) do
    if i > (most or 9) then break end
    out[#out + 1] = "/targetexact " .. (i > 1 and "[noexists] " or "") .. n
  end
  local m = BF.mark and BF.mark[e.id]
  if m then out[#out + 1] = "/tm [exists] !" .. m end
  -- the ping NAMES its unit (8 Nov, Arn: "bis tools boss no ping on shift click" - "/ping [mod:shift,exists]" pinged
  -- nothing; the family's working pings are all "/ping [@unit] kind", BiSHealing's [@mouseover] since 1 Oct)
  if ping == "always" then out[#out + 1] = "/ping [@target,exists] " .. BF.PING
  elseif ping == "shift" then out[#out + 1] = "/ping [mod:shift,@target,exists] " .. BF.PING end
  return table.concat(out, "\n")
end

--- The whole macro of one entry. FOUND WITHOUT A NAME (21 Nov: inside a dungeon a living creature's name is secret, so a
--- press could never tell it had hit - "not in sight" even when the skull went on): the last line but one clicks our own
--- plain button only when somebody is targeted. It stands after the work, and the line after it does nothing then - so a
--- client that will not run it loses nothing (UNVERIFIED live). As many names as fit in BF.MACRO_MAX.
function BF.One(e, ping)
  for most = 9, 1, -1 do
    local m = BF.Lines(e, ping, most) .. "\n/click [exists] BiSToolsBossHit\n/targetlasttarget [noexists]"
    if #m <= BF.MACRO_MAX then return m end
  end
  return ""
end

--- A row's macro: that boss, pinged when shift is held, your old target back when it is not in sight.
function BF.RowMacro(e)
  if not e or e.group then return "" end
  return BF.One(e, "shift")
end

--- The bosses a press may look for, standing and targetable, from `from` round the list.
function BF.Standing(from)
  local list, out = BF.list or {}, {}
  local n = #list
  for i = 0, n - 1 do
    local e = list[((from or 1) - 1 + i) % n + 1]
    if e and not e.group and BF.State(e) ~= "down" then out[#out + 1] = e end
  end
  return out
end

--- MARK ALL: as many standing bosses as fit in one macro, from BF.allAt round the list (the next press goes on from
--- the first one left out). Returns the macro and how many it looks for.
function BF.AllMacro()
  local lines, len, n = {}, 0, 0
  for _, e in ipairs(BF.Standing(BF.allAt)) do
    local l = BF.Lines(e)
    if len + #l + 1 > BF.MACRO_MAX then break end
    lines[#lines + 1] = l
    len, n = len + #l + 1, n + 1
  end
  local tail = "/targetlasttarget [noexists]"
  if n > 0 and len + #tail <= BF.MACRO_MAX then lines[#lines + 1] = tail end
  return table.concat(lines, "\n"), n
end

--- FIND: one boss a press - the ones in sight first, then round the list - targeted, marked and pinged.
function BF.FindNext()
  local standing = BF.Standing(BF.findAt)
  for _, e in ipairs(standing) do if BF.State(e) == "near" then return e end end
  return standing[1]
end

function BF.FindMacro()
  local e = BF.FindNext()
  if not e then return "", nil end
  return BF.One(e, "always"), e
end

--- Where an entry sits in the list (the next press goes on from the one after).
function BF.IndexOf(e)
  for i, x in ipairs(BF.list or {}) do if x == e then return i end end
  return nil
end

-- ------------------------------------------------------------------ the secure keys (written out of combat)

local function secure(name, parent)
  local b = CreateFrame("Button", name, parent or UIParent, "SecureActionButtonTemplate")
  b:RegisterForClicks("AnyDown")
  b:SetAttribute("type", "macro")
  b:SetAttribute("macrotext", "")
  return b
end

--- The FIND key a binding presses (`/bist bosses key <KEY>`): outside the window, so it works while the window is away.
function BF.FindKey()
  if BF.fkey then return BF.fkey end
  local b = secure("BiSToolsBossFind")
  b:SetScript("PostClick", function() BF.AfterFind() end)
  BF.fkey = b
  return b
end

--- Every macro the finder holds, written now - or after the fight (BF.dirty).
function BF.Write()
  if fighting() then BF.dirty = true return false end
  BF.dirty = nil
  BF.Assign()
  BF.Hit()
  local fm, fe = BF.FindMacro()
  BF.FindKey():SetAttribute("macrotext", fm)
  BF.findFor = fe
  local f = BF.frame
  if f then
    local am, an = BF.AllMacro()
    f.all:SetAttribute("macrotext", am)
    f.all.count = an
    f.find:SetAttribute("macrotext", fm)
    for i, row in ipairs(f.rows) do
      local e = BF.list and BF.list[(BF.page - 1) * BF.ROWS + i]
      row.entry = e
      row:SetAttribute("macrotext", BF.RowMacro(e))
    end
  end
  return true
end

function BF.ApplyKey(db)
  if InCombatLockdown() then BF.keyDirty = true return false end   -- a secure button is never made in a fight either
  local b = BF.FindKey()
  BF.keyDirty = nil
  ClearOverrideBindings(b)
  if db.key and R:Enabled("bosses") then SetOverrideBindingClick(b, true, db.key, "BiSToolsBossFind") end
  return true
end

-- ------------------------------------------------------------------ what a press found

local function targetName()
  if not (UnitExists and ask(UnitExists, "target")) then return nil end
  return ask(UnitName, "target")
end

--- The button the macro clicks when somebody is targeted (BF.One): a plain one of ours, it only remembers.
function BF.Hit()
  if BF.hit then return BF.hit end
  local b = CreateFrame("Button", "BiSToolsBossHit", UIParent)
  b:SetSize(1, 1)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetScript("OnClick", function() BF.heard = true end)
  BF.hit = b
  return b
end

--- Did the press find him? true / false, or nil = somebody is targeted but nobody may say who (inside, his name is
--- secret; it may be your old target back).
function BF.Got(e)
  local heard = BF.heard
  BF.heard = nil
  local name = targetName()
  if name then
    for _, n in ipairs(BF.Names(e)) do if n == name then return true end end
    return false
  end
  if heard then return true end
  if not (UnitExists and ask(UnitExists, "target")) then return false end
  return nil
end

--- After a press: found = FOUND (a boss's creature id learned for the screen when his name may be read).
function BF.Took(e)
  if not e or e.group then return false end
  local got = BF.Got(e)
  if got then
    if e.q then BF.found[e.id] = true elseif BF.run then BF.run.marked[e.id] = true end
    BF.LearnUnit("target")
    BF.Say(e.name .. (BF.mark and BF.mark[e.id] and " marked" or " targeted"), "good")
  elseif got == false then
    BF.Say(e.name .. " is not in sight", "ink2")
  else
    BF.Say("looked for " .. e.name, "ink2")
  end
  BF.Paint()
  return got and true or false
end

function BF.AfterAll(b)
  local n = b and b.count or 0
  local standing = BF.Standing(BF.allAt)
  local name = targetName()
  for i = 1, n do
    local e = standing[i]
    if e and e.name == name and BF.run then BF.run.marked[e.id] = true BF.LearnUnit("target") end
  end
  if n > 0 and #standing > n then
    local nextOne = standing[n + 1]
    BF.allAt = BF.IndexOf(nextOne) or 1
    BF.Say("marked " .. n .. " - press again for the rest", "gold")
  elseif n > 0 then
    BF.allAt = 1
    BF.Say("looked for all " .. n, "good")
  end
  BF.Write()
  BF.Paint()
end

function BF.AfterFind()
  local e = BF.findFor
  if not e then BF.Say("nothing left to find", "good") return end
  BF.Took(e)
  BF.findAt = (BF.IndexOf(e) or 0) + 1
  BF.Write()
end

-- ------------------------------------------------------------------ the eyes (nameplates, target, the end of a fight)

--- A boss's creature id from a unit's GUID, kept for the screen's model.
function BF.LearnUnit(unit)
  local db = BF.db
  if not db then return end
  local name = ask(UnitName, unit)
  local e = name and BF.byName and BF.byName[name]
  if not e then return end
  local C = NS.Codex
  local npc = C and C.NpcFromGUID and C.NpcFromGUID(ask(UnitGUID, unit))
  if npc then
    db.npcs = db.npcs or {}
    if db.npcs[name] ~= npc then BF.screenFor = nil end      -- a picture now: the screen looks again at once
    db.npcs[name] = npc
  end
  return e
end

--- One unit looked at: a boss of the list? In sight; dead = down.
function BF.Look(unit)
  local name = ask(UnitName, unit)
  local e = name and BF.byName and BF.byName[name]
  if not e then return nil end
  if unit:find("^nameplate") then BF.near[name] = true end
  BF.LearnUnit(unit)
  if not e.q and ask(UnitIsDead, unit) == true then BF.Down(e, "seen") end
  return e
end

--- Every nameplate again: who is in sight. `gone` = the plate going away (the client still lists it during
--- NAME_PLATE_UNIT_REMOVED), skipped.
function BF.Scan(gone)
  BF.near = {}
  if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
  local ok, plates = pcall(C_NamePlate.GetNamePlates)
  if not ok or type(plates) ~= "table" then return end
  for _, p in ipairs(plates) do
    local u = p.namePlateUnitToken or (p.UnitFrame and p.UnitFrame.unit)
    if u and u ~= gone then BF.Look(u) end
  end
end

--- A boss is down: its mark goes to the next, the gauge moves, one line says so.
function BF.Down(e, how)
  local r = BF.run
  if not (e and r) or r.down[e.id] then return false end
  r.down[e.id] = true
  r.at = now()                             -- a kill keeps the run alive (a /reload past BF.RUN_GAP forgot the dead, 21 Nov)
  BF.near[e.name] = nil
  local all, down = 0, 0
  for _, x in ipairs(BF.bosses or {}) do all = all + 1 if r.down[x.id] then down = down + 1 end end
  BF.Say(e.name .. " down - " .. down .. " of " .. all, "good")
  BF.lastHow = how
  BF.Write()
  BF.Paint()
  return true
end

BF.near, BF.found, BF.quests, BF.tab = {}, {}, {}, "boss"

--- The list of the open tab, and every name the eyes look for.
function BF.Index()
  BF.list = (BF.tab == "quest") and BF.quests or BF.bosses
  BF.byName = {}
  for _, e in ipairs(BF.quests or {}) do for _, n in ipairs(e.names) do BF.byName[n] = e end end
  for _, e in ipairs(BF.bosses or {}) do BF.byName[e.name] = e end
  BF.page = math.max(1, math.min(BF.Pages(), BF.page or 1))
end

--- The quest log read again for this place (out of a fight: the rows are secure buttons).
function BF.ReadQuests()
  local BQ = NS.BossQuests
  BF.quests, BF.unknown, BF.focus = {}, 0, nil
  if BQ and BF.spot then
    BF.quests, BF.unknown = BQ.Rows(BF.spot)
    if not BF.map then                                   -- outside: the title, and that dungeon's bosses for a look
      local one
      BF.outName, one = BQ.Title(BF.spot, BF.quests)
      BF.bosses = one and NS.BossData[one] and NS.BossData[one].bosses or nil
    end
  end
  BF.Index()
end

--- The log changed. In a fight the rows keep their places and only their counts move; the list itself waits.
function BF.QuestsNow()
  if not BF.spot then return end
  if fighting() then
    local by = {}
    for _, e in ipairs(NS.BossQuests.Rows(BF.spot)) do by[e.id] = e end
    for _, e in ipairs(BF.quests) do
      local x = by[e.id]
      if x then e.have, e.need, e.done, e.who = x.have, x.need, x.done, x.who end
    end
    BF.questsLate = true
    BF.Paint()
    return
  end
  BF.questsLate = nil
  local had = #BF.quests
  BF.ReadQuests()
  BF.Write()
  if not BF.map and had == 0 and #BF.quests > 0 and BF.db and BF.db.open and not BF.IsOpen() and not BF.DeckTakes() then BF.Toggle(true) end
  if NS.Box and NS.Box.Refresh then NS.Box.Refresh() end
  BF.Paint()
end

--- BOSSES or QUESTS. Not in a fight: the rows are secure.
function BF.SetTab(tab)
  if fighting() then return false end
  BF.tab = (tab == "quest") and "quest" or "boss"
  BF.page, BF.allAt, BF.findAt, BF.focus, BF.screenFor = 1, 1, 1, nil, nil
  BF.Index()
  BF.Say("", "ink2")
  BF.Write()
  BF.Paint()
  return true
end

--- THE PHONE TAKES IT (22 Nov 2026, Arn, the old boss phone open beside the deck's Bosses page: "it did pop it out with the new
--- deck that should not happen anymore"): with the deck on, the old phone never comes up by itself - not once a run, not
--- because it was open when you left. The deck's app does (DP.BossesHere); OLD PHONE there still opens this one by hand.
function BF.DeckTakes()
  local DP = NS.DeckPages
  return DP and DP.DeckOn and DP.DeckOn() or false
end

--- Into a place (or out of one): the list, the run, the eyes on or off. A place = a dungeon of the list, or the zone of
--- one's entrance (its quests only, BossQuests.lua).
function BF.Enter()
  local db = BF.db
  if not db then return end
  local BQ = NS.BossQuests
  local map, data, spot, soon = nil, nil, nil, nil
  if R:Enabled("bosses") then
    map, data = BF.Here()
    if map then spot = BQ and BQ.Place({ map }, true)
    elseif BQ and ask(IsInInstance) ~= true then spot, soon = BQ.Outside() end
  end
  -- a loading screen's end: the game has no map for you yet - look once more, a few times at most
  if soon and (BF.soonTries or 0) < 3 and C_Timer and C_Timer.After then
    BF.soonTries = (BF.soonTries or 0) + 1
    C_Timer.After(2, function() BF.Enter() end)
  elseif not soon then BF.soonTries = nil end
  local place = map and ("in:" .. map) or (spot and spot.key) or nil
  if place ~= BF.key then
    BF.key, BF.map, BF.data, BF.spot = place, map, data, spot
    BF.near, BF.found, BF.run = {}, {}, nil
    BF.bosses, BF.outName = data and data.bosses or nil, nil
    BF.page, BF.allAt, BF.findAt = 1, 1, 1
    BF.tab = (place and not map) and "quest" or "boss"
    local was = db.run
    if map then BF.run = BF.Run(db, map) end
    BF.CopyWatch(map ~= nil)                       -- (which copy this is: one sure reading, then off)
    BF.ReadQuests()
    BF.Eyes(place ~= nil)
    if place then BF.Scan() end
    if map then
      -- up by itself once a run; and back again if it was open when you left (a wipe's run back, a hearth) -
      -- leaving shuts it below without touching db.open; only your own close does
      local fresh = db.auto ~= false and BF.run ~= was
      if BF.DeckTakes() then
        if fresh and not fighting() then NS.DeckPages.BossesHere() end    -- (the phone's app, never the old phone)
      elseif (fresh or db.open) and not fighting() then BF.Toggle(true) end
    elseif place and #BF.quests > 0 and db.open and not BF.DeckTakes() then     -- outside the entrance: only if it was yours and open
      if not fighting() then BF.Toggle(true) end
    elseif BF.frame and BF.frame:IsShown() and not fighting() then BF.frame:Hide() end
    BF.Write()
    if NS.Box and NS.Box.Refresh then NS.Box.Refresh() end
  elseif map then
    BF.run = BF.Run(db, map)
  end
  BF.Paint()
end

-- ------------------------------------------------------------------ the window

local function line(parent, layer, colour, alpha, thick)
  local l = parent:CreateLine(nil, layer or "ARTWORK")
  l:SetThickness(thick or 1)
  l:SetTexture("Interface\\Buttons\\WHITE8X8")     -- a Line takes a texture and a tint (bislint line-paint)
  if type(colour) == "table" then l:SetVertexColor(colour[1], colour[2], colour[3], alpha or 1)
  else local r, g, b = rgb(colour) l:SetVertexColor(r, g, b, alpha or 1) end
  return l
end

local function pop(b, label)
  b.wash = b.wash or K().tex(b, "BORDER", "accent", 0)
  b:SetScript("OnEnter", function(self)
    self.wash:SetAlpha(BF.GLOW)
    if self.bar then self.bar:SetAlpha(1) end
    if self.edge and self.edge.set then self.edge:set("accent", 1) end
    if label then label:SetTextColor(rgb("ink")) end
    if self.hover then self.hover(self) end
    if self.tip then self.tip(self) end
  end)
  b:SetScript("OnLeave", function(self)
    self.wash:SetAlpha(0)
    if self.bar then self.bar:SetAlpha(0) end
    if self.edge and self.edge.set then self.edge:set("edge", 1) end
    if label then label:SetTextColor(rgb(self.ink or "ink2")) end
    if self.unhover then self.unhover(self) end
    if GameTooltip then GameTooltip:Hide() end
  end)
end
BF.Pop = pop

--- A cockpit key: raised face, a lit bar along its foot, its label; secure when it runs a macro.
local function key(parent, label, w, h, name, onclick)
  local b
  if name then b = secure(name, parent) else b = CreateFrame("Button", nil, parent) end
  b:SetSize(w, h)
  K().tex(b, "BACKGROUND", "field", 0.95)
  b.edge = K().border(b, "edge", 1)
  b.lit = b:CreateTexture(nil, "ARTWORK")
  b.lit:SetPoint("BOTTOMLEFT", 3, 2)
  b.lit:SetPoint("BOTTOMRIGHT", -3, 2)
  b.lit:SetHeight(2)
  b.lit:SetColorTexture(rgb("good"))
  b.lit:SetAlpha(0.25)
  b.label = K().fs(b, label, 9, "ink2")
  b.label:SetPoint("CENTER", 0, 1)
  if onclick then b:SetScript("OnClick", onclick) end
  pop(b, b.label)
  return b
end

function BF.BuildScreen(f, x, y, w, h)
  local sc = CreateFrame("Frame", nil, f)
  sc:SetSize(w, h)
  sc:SetPoint("TOPLEFT", x, y)
  if sc.SetClipsChildren then sc:SetClipsChildren(true) end
  f.screen = sc
  local horizon = math.floor(h * 0.58)
  -- the sky in bands, deep at the top, hot at the horizon
  local bands = #BF.SKY
  for i, c in ipairs(BF.SKY) do
    local t = sc:CreateTexture(nil, "BACKGROUND")
    t:SetColorTexture(c[1], c[2], c[3], 1)
    t:SetPoint("TOPLEFT", 0, -(i - 1) * horizon / bands)
    t:SetSize(w, horizon / bands + 1)
  end
  -- the sun on the horizon, cut by dark stripes
  local sun = sc:CreateTexture(nil, "BORDER")
  sun:SetTexture(BF.ROUND)
  sun:SetSize(44, 44)
  sun:SetPoint("CENTER", sc, "TOPLEFT", w / 2, -horizon + 8)
  sun:SetVertexColor(BF.SUN[1], BF.SUN[2], BF.SUN[3])
  f.sun = sun
  for i = 1, 3 do
    local s = sc:CreateTexture(nil, "ARTWORK")
    s:SetColorTexture(BF.SKY[4][1], BF.SKY[4][2], BF.SKY[4][3], 1)
    s:SetSize(46, i)
    s:SetPoint("CENTER", sc, "TOPLEFT", w / 2, -horizon + 8 - 4 * i)
  end
  -- the ground and its grid: rays from the middle of the horizon, and lines rolling toward you
  local ground = sc:CreateTexture(nil, "BORDER")
  ground:SetColorTexture(0.05, 0.02, 0.10, 1)
  ground:SetPoint("TOPLEFT", 0, -horizon)
  ground:SetSize(w, h - horizon)
  for i = -5, 5 do
    local l = line(sc, "ARTWORK", BF.GRID, 0.55, 1)
    l:SetStartPoint("TOPLEFT", sc, w / 2 + i * 6, -horizon)
    l:SetEndPoint("TOPLEFT", sc, w / 2 + i * 34, -h)
  end
  f.grid = {}
  for i = 1, 5 do
    local l = line(sc, "ARTWORK", BF.GRID, 0.6, 1)
    f.grid[i] = l
  end
  local hz = line(sc, "ARTWORK", BF.GRID, 0.9, 1)
  hz:SetStartPoint("TOPLEFT", sc, 0, -horizon)
  hz:SetEndPoint("TOPLEFT", sc, w, -horizon)
  f.horizon, f.screenW, f.screenH = horizon, w, h
  -- the boss in 3D, over the sunset (when the game has shown it to you once, or the Codex knows it)
  local okM, m = pcall(CreateFrame, "PlayerModel", nil, sc)
  if okM and m then
    m:SetAllPoints()
    m:SetFrameLevel((sc:GetFrameLevel() or 1) + 2)
    f.model = m
  end
  -- the words over it: their own layer ABOVE the model (the name on the screen's own layer printed behind the boss)
  local over = CreateFrame("Frame", nil, f)
  over:SetSize(w, h)
  over:SetPoint("TOPLEFT", x, y)
  over:SetFrameLevel((sc:GetFrameLevel() or 1) + 5)
  f.over = over
  f.caption = K().fs(over, "", 14, "ink")
  f.caption:SetPoint("BOTTOMLEFT", over, "BOTTOMLEFT", BF.PAD - 1, 4)
  f.caption:SetWidth(w - 76)
  f.caption:SetJustifyH("LEFT")
  f.caption:SetWordWrap(false)
  f.capState = K().fs(over, "", 8, "gold")
  f.capState:SetPoint("BOTTOMRIGHT", over, "BOTTOMRIGHT", -BF.PAD + 1, 6)
  f.capState:SetWidth(56)
  f.capState:SetJustifyH("RIGHT")
  f.capState:SetWordWrap(false)
  f.nopic = K().fs(over, "", 8, "ink2")
  f.nopic:SetPoint("TOP", over, "TOP", 0, -24)
  BF.t = 0
  BF.GridAt(0)
  return sc
end

--- The rolling lines: each one's place between the horizon and your feet, spaced like a floor going away.
function BF.GridAt(t)
  local f = BF.frame or {}
  if not f.grid then return end
  local deep = f.screenH - f.horizon
  for i, l in ipairs(f.grid) do
    local k = ((i - 1) + (t % 1)) / #f.grid          -- 0 at the horizon, 1 at your feet
    local yy = f.horizon + deep * k * k
    l:SetStartPoint("TOPLEFT", f.screen, 0, -yy)
    l:SetEndPoint("TOPLEFT", f.screen, f.screenW, -yy)
  end
end

--- Where the window stands: where it was dragged to (db.pos, in its own scale), else right of the middle.
function BF.Place()
  local f, pos = BF.frame, BF.db and BF.db.pos
  if not f then return end
  f:ClearAllPoints()
  if type(pos) == "table" and type(pos[1]) == "string" then
    f:SetPoint(pos[1], UIParent, pos[2] or pos[1], tonumber(pos[3]) or 0, tonumber(pos[4]) or 0)
  else
    f:SetPoint("CENTER", UIParent, "CENTER", BF.SPOT[1], BF.SPOT[2])
  end
end

function BF.Build()
  if BF.frame then return BF.frame end
  local k = K()
  local f = CreateFrame("Frame", "BiSToolsBosses", UIParent)
  BF.frame = f
  f:SetSize(BF.W, BF.H)
  f:SetFrameStrata("DIALOG")
  f:SetScale(BF.SCALE)
  BF.Place()
  -- NOT on the Escape list (8 Nov, Arn: "even if i am not clicked on the window if i hit esc it closes it"): in a dungeon
  -- Escape is pressed all run long to drop a target or stop a cast, and it shut the list each time. Its x, the skull and
  -- /bist bosses close it.
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    if fighting() then return end
    self:StartMoving()
    self.dragging = true
  end)
  -- WHERE YOU LEFT IT (8 Nov, Arn: "the bis bosses always open in the middle of the screen"): kept in db.pos
  f:SetScript("OnDragStop", function(self) BF.EndDrag(self) end)
  k.tex(f, "BACKGROUND", "frame", 0.97)
  k.border(f, "edge", 1)
  -- the screen first: the boss, edge to edge, and over it the phone's top line
  local P, W = BF.PAD, BF.W - 2 * BF.PAD
  BF.BuildScreen(f, 1, -1, BF.W - 2, BF.SCREEN_H - 1)
  local top = f.over
  local notch = top:CreateTexture(nil, "ARTWORK")
  notch:SetColorTexture(rgb("frame"))
  notch:SetSize(64, 10)
  notch:SetPoint("TOP", top, "TOP", 0, 0)
  f.clock = k.fs(top, "", 8, "ink")
  f.clock:SetPoint("TOPLEFT", top, "TOPLEFT", P - 1, -3)
  f.close = key(f, "x", 16, 14, nil, function() BF.Toggle(false) end)
  f.close:SetPoint("TOPRIGHT", -4, -4)
  f.close:SetFrameLevel((top:GetFrameLevel() or 1) + 2)
  -- whose list this is
  f.place = k.fs(f, "", 14, "ink")
  f.place:SetPoint("TOPLEFT", f, "TOPLEFT", P, -BF.TITLE_Y)
  f.place:SetWidth(W - 62)
  f.place:SetJustifyH("LEFT")
  f.place:SetWordWrap(false)
  f.title = k.fs(f, "BiS> BOSSES", 8, "accent")
  f.title:SetPoint("TOPRIGHT", f, "TOPRIGHT", -P, -BF.TITLE_Y - 4)
  -- the numbers, in boxes
  f.boxes = {}
  local bw = (W - 8) / 3
  local function box(i, word, ink)
    local b = CreateFrame("Frame", nil, f)
    b:SetSize(bw, BF.BOX_H)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", P + (i - 1) * (bw + 4), -BF.BOX_Y)
    k.tex(b, "BACKGROUND", "field", 0.9)
    local w = k.fs(b, word, 6, "dim")
    w:SetPoint("TOPLEFT", b, "TOPLEFT", 5, -3)
    local n = k.fs(b, "", 12, ink)
    n:SetPoint("TOPLEFT", b, "TOPLEFT", 5, -10)
    b.word = w
    f.boxes[i] = b
    return n
  end
  f.readDown = box(1, "DOWN", "good")
  f.readNear = box(2, "LEFT", "gold")
  f.readMark = box(3, "FOUND", "accent")
  -- the tabs: plain buttons (they only turn the page; what they change is written out of a fight)
  f.tabs = {}
  for i, which in ipairs({ "boss", "quest" }) do
    local b = key(f, "", W / 2 - 2, BF.TAB_H, nil, function() BF.SetTab(which) end)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", P + (i - 1) * (W / 2 + 2), -BF.TAB_Y)
    b.which = which
    b.tip = function(self)
      if not GameTooltip then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(which == "boss" and "The bosses of this place" or "Who your quests need here")
      if which == "quest" and (BF.unknown or 0) > 0 then
        GameTooltip:AddLine(BF.unknown .. " more need things nobody can name yet - the Questie addon knows most", 0.6, 0.6, 0.6, true)
      end
      GameTooltip:Show()
    end
    f.tabs[i] = b
  end
  -- the list: a row a boss, its mark, its name, what is known
  local x0, w = P, W
  f.rows = {}
  for i = 1, BF.ROWS do
    local r = secure(nil, f)
    r:SetSize(w, BF.ROW - 1)
    r:SetPoint("TOPLEFT", f, "TOPLEFT", x0, -BF.ROWS_Y - (i - 1) * BF.ROW)
    k.tex(r, "BACKGROUND", "field", 0.6)
    r.bar = r:CreateTexture(nil, "ARTWORK")
    r.bar:SetPoint("TOPLEFT")
    r.bar:SetPoint("BOTTOMLEFT")
    r.bar:SetWidth(2)
    r.bar:SetColorTexture(rgb("accent"))
    r.bar:SetAlpha(0)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(13, 13)
    r.icon:SetPoint("LEFT", 6, 0)
    r.num = k.fs(r, "", 8, "dim")
    r.num:SetPoint("LEFT", 6, 0)
    r.check = r:CreateTexture(nil, "ARTWORK")          -- down: a green tick in the mark's place
    r.check:SetTexture(BF.CHECK)
    r.check:SetSize(12, 12)
    r.check:SetPoint("LEFT", 6, 0)
    r.check:Hide()
    r.name = k.fs(r, "", 10, "ink")
    r.name:SetPoint("LEFT", 24, 0)
    r.name:SetWidth(w - 24 - 92)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)                         -- one line: a long name is cut, never wrapped over the next row
    r.who = k.fs(r, "", 8, "ink2")                    -- who in your party is on the quest too: initials
    r.who:SetPoint("RIGHT", -58, 0)
    r.who:SetWidth(34)
    r.who:SetJustifyH("RIGHT")
    r.who:SetWordWrap(false)
    r.state = k.fs(r, "", 7, "ink2")
    r.state:SetPoint("RIGHT", -4, 0)
    r.state:SetWidth(52)
    r.state:SetJustifyH("RIGHT")
    r.state:SetWordWrap(false)
    r:SetScript("PostClick", function(self) BF.Took(self.entry) end)
    r.hover = function(self) BF.focus = self.entry BF.Screen() end
    r.unhover = function() BF.focus = nil BF.Screen() end
    r.tip = function(self)
      local e = self.entry
      if not (e and GameTooltip) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(e.name)
      if e.q then
        GameTooltip:AddLine((e.title or "") .. "  " .. e.have .. " / " .. e.need, 1, 0.82, 0)
        for i = 2, #e.names do GameTooltip:AddLine("or: " .. e.names[i], 0.6, 0.6, 0.6) end
        for _, u in ipairs(e.who or {}) do GameTooltip:AddLine(u.name .. " is on it too", 0.6, 0.85, 1) end
      end
      if e.group then
        GameTooltip:AddLine("A fight of several - ticked off when it ends", 1, 1, 1)
      else
        GameTooltip:AddLine("click: target it and put its mark on it", 1, 1, 1)
        GameTooltip:AddLine("shift-click: and ping it for the party", 0.6, 0.6, 0.6)
      end
      GameTooltip:Show()
    end
    pop(r)
    r:Hide()
    f.rows[i] = r
  end
  -- under the list: what the last press did, left; the pages, right (more than eight bosses)
  f.next = key(f, ">", 20, BF.PAGE_H, nil, function() BF.Turn(1) end)
  f.next:SetPoint("TOPRIGHT", f, "TOPRIGHT", -P, -BF.PAGE_Y)
  f.prev = key(f, "<", 20, BF.PAGE_H, nil, function() BF.Turn(-1) end)
  f.prev:SetPoint("TOPRIGHT", f, "TOPRIGHT", -P - 24, -BF.PAGE_Y)
  f.pageNo = k.fs(f, "", 8, "dim")
  f.pageNo:SetPoint("TOPRIGHT", f, "TOPRIGHT", -P - 50, -BF.PAGE_Y - 2)
  f.say = k.fs(f, "", 8, "ink2")
  f.say:SetPoint("TOPLEFT", f, "TOPLEFT", P, -BF.PAGE_Y - 2)
  f.say:SetWidth(W - 78)
  f.say:SetJustifyH("LEFT")
  f.say:SetWordWrap(false)
  -- the tape: one segment a boss, the colour of what is known
  f.tape = CreateFrame("Frame", nil, f)
  f.tape:SetSize(W, BF.TAPE_H)
  f.tape:SetPoint("TOPLEFT", f, "TOPLEFT", P, -BF.TAPE_Y)
  k.tex(f.tape, "BACKGROUND", "field", 0.9)
  f.segs = {}
  for i = 1, BF.TAPE_MAX do
    local s = f.tape:CreateTexture(nil, "ARTWORK")
    s:SetColorTexture(rgb("line2"))
    s:Hide()
    f.segs[i] = s
  end
  -- the keys: MARK ALL and FIND are secure (Blizzard's own commands), RESET is ours
  f.all = key(f, "MARK ALL", W / 2 - 2, BF.KEYS_H, "BiSToolsBossAll")
  f.all:SetPoint("TOPLEFT", f, "TOPLEFT", P, -BF.KEYS_Y)
  f.all:SetScript("PostClick", function(self) BF.AfterAll(self) end)
  f.all.tip = function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Target every boss in sight and mark it")
    GameTooltip:AddLine("A long list takes two presses", 1, 1, 1)
    GameTooltip:Show()
  end
  f.find = key(f, "FIND", W, BF.FIND_H, "BiSToolsBossFindKey")      -- the biggest button on it
  f.find:SetPoint("TOPLEFT", f, "TOPLEFT", P, -BF.FIND_Y)
  f.find.label:SetFont(STANDARD_TEXT_FONT, 13, "")
  f.find:SetScript("PostClick", function() BF.AfterFind() end)
  f.find.lit:SetColorTexture(rgb("gold"))
  f.find.lit:SetAlpha(0.8)
  f.find.tip = function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Find the next boss")
    GameTooltip:AddLine("One a press: targeted, marked and pinged for the party", 1, 1, 1)
    GameTooltip:AddLine("/bist bosses key <KEY> binds it", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end
  f.reset = key(f, "RESET", W / 2 - 2, BF.KEYS_H, nil, function() BF.Reset() end)
  f.reset:SetPoint("TOPLEFT", f, "TOPLEFT", P + W / 2 + 2, -BF.KEYS_Y)
  f.help = k.fs(f, BF.HELP, 7, "dim")
  f.help:SetPoint("TOPLEFT", f, "TOPLEFT", P, -BF.HELP_Y)
  f.help:SetWidth(W)
  f.help:SetJustifyH("LEFT")
  f.help:SetWordWrap(false)
  f.home = k.tex(f, "ARTWORK", "ink2", 0.7)
  f.home:ClearAllPoints()
  f.home:SetSize(70, 3)
  f.home:SetPoint("BOTTOM", f, "BOTTOM", 0, BF.HOME)
  f.build = k.fs(f, "", 6, "dim")                    -- the fingerprint: faint, which copy this is
  f.build:SetJustifyH("RIGHT")
  f.build:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -P, BF.HOME + 4)
  f.build:SetAlpha(0.6)
  -- the screen's clock: only while shown (the client runs no OnUpdate for a hidden frame)
  local acc = 0
  f.tick = function(_, elapsed)
    acc = acc + (elapsed or 0)
    if acc < 1 / BF.FPS then return end
    BF.t = (BF.t or 0) + acc * 0.5
    local ua = UIParent and UIParent.GetAlpha and UIParent:GetAlpha()       -- the interface faded out (a picture being taken)
    BF.ModelAway(type(ua) == "number" and ua < 0.5)
    BF.clockIn = (BF.clockIn or 0) - acc
    acc = 0
    BF.GridAt(BF.t)
    if BF.clockIn <= 0 then BF.PaintClock(f) end
  end
  f:SetScript("OnUpdate", f.tick)
  -- hidden mid-drag (a zone change, the tool switched off): the drag ends with it
  f:SetScript("OnHide", function(self) BF.focus = nil BF.EndDrag(self) end)
  f:Hide()
  return f
end

--- The phone's clock (your own PC's time), written only when the minute changed.
function BF.PaintClock(f)
  BF.clockIn = BF.CLOCK_EVERY
  local t = date and date("%H:%M") or ""
  if f.clockSays ~= t then f.clockSays = t f.clock:SetText(t) end
end

function BF.Pages() return math.max(1, math.ceil(#(BF.list or {}) / BF.ROWS)) end

function BF.Turn(d)
  if fighting() then return end
  BF.page = math.max(1, math.min(BF.Pages(), (BF.page or 1) + d))
  BF.Write()
  BF.Paint()
end

function BF.Say(text, colour)
  BF.said, BF.saidInk = text, colour
  local f = BF.frame
  if f and f.say then
    f.say:SetText(text or "")
    f.say:SetTextColor(rgb(colour or "ink2"))
  end
end

--- The creature id behind a boss's name: met (its GUID, kept), or the Codex's book (its live name matches).
function BF.NpcOf(e)
  local db = BF.db
  local C = NS.Codex
  if e.q and e.npc then
    local s = C and C.DATA and C.DATA.creatures and C.DATA.creatures[e.npc]
    return e.npc, s and s.display or nil
  end
  local met = db and db.npcs and db.npcs[e.name]
  if met then                                  -- met: its own id, and the Codex's model id when the book has it
    local s = C and C.DATA and C.DATA.creatures and C.DATA.creatures[met]
    return met, s and s.display or nil
  end
  if not (C and C.DATA and C.Name) then return nil end
  for npc, s in pairs(C.DATA.creatures or {}) do
    if s.boss and C.Name(npc) == e.name then return npc, s.display end
  end
  return nil
end

--- An entry's word and its colour: its state, or a quest's count ("0 / 1").
function BF.Word(e, st)
  if e and e.q and st == "down" then return "DONE", "good" end
  if e and e.q and st == "far" then return e.have .. " / " .. e.need, "ink2" end
  return BF.STATE_WORD[st] or "", BF.STATE_INK[st] or "ink2"
end

--- The initials of the party on a quest, each in its class colour.
function BF.Initials(who)
  local out = {}
  for _, u in ipairs(who or {}) do
    local c = RAID_CLASS_COLORS and u.class and RAID_CLASS_COLORS[u.class]
    local l = u.name:match("^[%z\1-\127\194-\244][\128-\191]*") or "?"
    out[#out + 1] = c and c.colorStr and ("|c" .. c.colorStr .. l .. "|r") or l
  end
  return table.concat(out, " ")
end

--- The screen: the boss under the mouse, else the next one to find - in 3D over the sunset, or the sunset alone.
function BF.Screen()
  local f = BF.frame
  if not (f and f.screen) then return end
  local e = BF.focus or BF.FindNext() or (BF.list and BF.list[1])
  f.caption:SetText(e and e.name or "")
  local st = e and BF.State(e) or "far"
  local word, ink = BF.Word(e, st)
  if e and e.note and st ~= "down" then word, ink = e.note, "gold" end
  f.capState:SetText(word)
  f.capState:SetTextColor(rgb(ink))
  for _, r in ipairs(f.rows or {}) do                -- the row of the boss on the screen is lit
    local on = e ~= nil and r.entry == e
    r.bar:SetAlpha(on and 1 or 0)
    r.wash:SetAlpha(on and (BF.focus == e and BF.GLOW or BF.GLOW / 2) or 0)
  end
  local m = f.model
  if not m then return end
  if f.modelAway then m:Hide() BF.showing, BF.screenFor = nil, nil return end
  -- the same boss as last time: drawn, or missed a moment ago (the Codex's names come in by themselves) - leave it
  local t = GetTime and GetTime() or 0
  if e == BF.screenFor and (BF.showing or (t - (BF.missAt or 0)) < BF.MISS_GAP) then return end
  BF.screenFor = e
  local npc, display = nil, nil
  if e then npc, display = BF.NpcOf(e) end
  if e and e.group then npc, display = nil, nil end
  if not (npc or display) then
    m:ClearModel()
    m:Hide()
    f.nopic:SetText(e and (e.group and "A FIGHT OF SEVERAL" or "NO PICTURE YET")
      or (BF.tab == "quest" and "NO QUEST NEEDS ANYONE HERE") or "")
    BF.showing, BF.missAt = nil, t
    return
  end
  f.nopic:SetText("")
  local want = display and ("d" .. display) or ("n" .. npc)
  BF.showing = want
  m:Show()
  BF.Dress(m, npc, display, 1)
end

--- A 3D MODEL IGNORES ITS WINDOW'S ALPHA (solved.md; Arn's shots, 21 Nov: the boss stood bright at the screen's edge
--- through every fight, and in BiS Memories' pictures where the interface is faded out): away = hidden by hand.
function BF.ModelAway(on)
  local f = BF.frame
  on = on and true or false
  if not f or (f.modelAway or false) == on then return end
  f.modelAway = on
  BF.Screen()
end

--- Ask the model; a creature the client has not fetched draws nothing the first time, so look again.
function BF.Dress(m, npc, display, try)
  if display then m:SetDisplayInfo(display) else m:SetCreature(npc) end
  if m:GetModelFileID() ~= 0 then
    m:SetCamDistanceScale(1.6)
    m:SetAnimation(0)
    return true
  end
  if try >= BF.MODEL_TRIES then return false end
  local want = BF.showing
  C_Timer.After(BF.MODEL_WAIT, function()
    if BF.showing == want and BF.frame and BF.frame:IsShown() then BF.Dress(m, npc, display, try + 1) end
  end)
  return false
end

function BF.PaintTape(f)
  local list = BF.list or {}
  local n = math.min(#list, BF.TAPE_MAX)
  local gap = 2
  local wseg = n > 0 and ((BF.W - 2 * BF.PAD) - gap * (n - 1)) / n or 0
  for i = 1, BF.TAPE_MAX do
    local s = f.segs[i]
    local e = list[i]
    if i <= n and e then
      s:ClearAllPoints()
      s:SetPoint("TOPLEFT", f.tape, "TOPLEFT", (i - 1) * (wseg + gap), 0)
      s:SetSize(wseg, BF.TAPE_H)
      local st = BF.State(e)
      local r, g, b = rgb(st == "far" and "line2" or BF.STATE_INK[st])
      s:SetColorTexture(r, g, b, 1)
      s:Show()
    else
      s:Hide()
    end
  end
end

function BF.Paint()
  local f = BF.frame
  if not (f and f:IsShown()) then return end
  local list = BF.list or {}
  f.place:SetText(BF.data and BF.data.name or BF.outName or "not in a dungeon")
  f.build:SetText(NS.Stamp and NS.Stamp() or "")
  local page = BF.page or 1
  -- IN A FIGHT THE ROWS AND KEYS ARE SECURE BUTTONS: showing or hiding one is protected, even one already shown
  -- (Arn's BugGrabber, 8 Nov: "tried to call the protected function 'Button:Show()'" - a kill mid-fight repainted the
  -- list). Words and colours change now; which buttons show waits for the fight's end (BF.showLater).
  local locked = fighting()
  local function vis(b, on)
    if locked then
      if (b:IsShown() and true or false) ~= (on and true or false) then BF.showLater = true end
      return
    end
    if on then b:Show() else b:Hide() end
  end
  for i, r in ipairs(f.rows) do
    local idx = (page - 1) * BF.ROWS + i
    local e = list[idx]
    if e then
      local st = BF.State(e)
      local m = BF.mark and BF.mark[e.id]
      if m and st ~= "down" then
        r.icon:SetTexture(BF.MARK_ICON .. m)
        r.icon:Show()
        r.num:SetText("")
      else
        r.icon:Hide()
        r.num:SetText(tostring(idx))
      end
      if st == "down" then r.icon:Hide() r.num:SetText("") r.check:Show() else r.check:Hide() end
      r.name:SetText(e.name)
      r.name:SetTextColor(rgb(st == "down" and "dim" or "ink"))
      local word, ink = BF.Word(e, st)
      r.state:SetText(word)
      r.state:SetTextColor(rgb(ink))
      r.who:SetText(BF.Initials(e.who))
      vis(r, true)
    else
      vis(r, false)
    end
  end
  local pages = BF.Pages()
  f.pageNo:SetText(pages > 1 and (page .. "/" .. pages) or "")
  vis(f.prev, pages > 1)
  vis(f.next, pages > 1)
  local c = BF.Counts()
  f.readDown:SetText(c.down .. " / " .. c.all)
  f.boxes[1].word:SetText(BF.tab == "quest" and "DONE" or "DOWN")
  f.readNear:SetText(tostring(c.all - c.down))
  local left = { boss = 0, quest = 0 }
  for _, e in ipairs(BF.bosses or {}) do if BF.State(e) ~= "down" then left.boss = left.boss + 1 end end
  for _, e in ipairs(BF.quests or {}) do if not e.done then left.quest = left.quest + 1 end end
  for _, b in ipairs(f.tabs) do
    local on = b.which == BF.tab
    b.label:SetText((b.which == "boss" and "BOSSES " or "QUESTS ") .. left[b.which])
    b.ink = on and "ink" or "dim"
    b.label:SetTextColor(rgb(b.ink))
    b.lit:SetColorTexture(rgb(on and "accent" or "line2"))
    b.lit:SetAlpha(on and 1 or 0.4)
  end
  f.readMark:SetText(tostring(c.marked))
  BF.PaintClock(f)
  BF.PaintTape(f)
  if BF.said then f.say:SetText(BF.said) f.say:SetTextColor(rgb(BF.saidInk or "ink2")) end
  BF.Screen()
end

function BF.IsOpen() return BF.frame ~= nil and BF.frame:IsShown() end

-- IN A FIGHT IT STAYS, DIMMED (Arn, 8 Nov: "the boss window closed so many times during combat that it stopped opening
-- by itself and i forgot about it ... dim it during combat and make it unclickable"). It used to step away at every pull
-- and come back after; now it stays where it is at BF.FIGHT_ALPHA, still painting (DOWN, MARKED, the gauge), and takes no
-- click: every key's mouse is switched off in the one moment the client still allows it (PLAYER_REGEN_DISABLED, before
-- the lockdown), and back on after. Escape leaves it alone while dimmed - closing a frame of secure buttons mid-fight
-- is refused - so it comes off the Escape list for the fight.
-- AND QUIET (Arn, same day: "like a quiet cockpit screen would"): nothing moves - the grid stops rolling (its OnUpdate
-- comes off, so a fight costs the screen nothing) - and the help line says, in gold, why the keys do not answer.
-- WAY DIMMER (Arn, same day: "dim it way more incase someone has it over someting important and they cant move it
-- incombat they can still click stuff behind it"): barely there, and every part lets the mouse through to what is under it
BF.FIGHT_ALPHA = 0.12
BF.FIGHT_HELP = "FIGHT · screen quiet, keys locked - back after the fight"
BF.HELP = "click: target + mark   shift: + ping   FIND: the next one"

function BF.Clickables(f)
  local list = { f.close, f.prev, f.next, f.all, f.find, f.reset, f.tabs[1], f.tabs[2] }
  for _, r in ipairs(f.rows or {}) do list[#list + 1] = r end
  return list
end

--- The drag ends: the window lets go of the mouse, and where it stands is kept (plain numbers only - a secret
--- position is never written down).
function BF.EndDrag(f)
  if not (f and f.dragging) then return false end
  f.dragging = nil
  NS.LetGo(f)
  local ok, p, _, rp, x, y = pcall(f.GetPoint, f)
  local function plain(v) return (v ~= nil and not (issecretvalue and issecretvalue(v))) and v or nil end
  p, rp, x, y = plain(p), plain(rp), plain(x), plain(y)
  if ok and BF.db and type(p) == "string" and type(x) == "number" and type(y) == "number" then
    BF.db.pos = { p, type(rp) == "string" and rp or p, x, y }
  end
  return true
end

--- Dim (a fight starts) or wake (it ended). Out of the lockdown only; returns false when refused.
--- A FIGHT MID-DRAG (8 Nov, Arn: "we got into combat when i reloaded and moved the window" - it held on to his mouse and
--- nothing could be clicked, not even to quit): the window's mouse goes off below, so it would never hear the button
--- come up. The drag ENDS first, here, while the client still allows it (PLAYER_REGEN_DISABLED, before the lockdown).
function BF.Dim(on)
  local f = BF.frame
  if f and on then BF.EndDrag(f) end
  if not f or fighting() then return false end
  f.dimmed = on and true or false
  f:SetAlpha(on and BF.FIGHT_ALPHA or 1)
  f:EnableMouse(not on)
  for _, b in ipairs(BF.Clickables(f)) do if b and b.EnableMouse then b:EnableMouse(not on) end end
  -- the parts that never take a click are made sure of too: a model that caught the mouse would block what is behind
  if on then
    for _, p in ipairs({ f.screen, f.over, f.tape, f.boxes[1], f.boxes[2], f.boxes[3], f.model }) do if p and p.EnableMouse then p:EnableMouse(false) end end
  end
  f:SetScript("OnUpdate", (not on) and f.tick or nil)
  BF.ModelAway(on)
  if f.help then
    f.help:SetText(on and BF.FIGHT_HELP or BF.HELP)
    f.help:SetTextColor(rgb(on and "gold" or "dim"))
  end
  return true
end

--- Open or close. Never in a fight: the window holds secure buttons, and those cannot appear or go in one.
function BF.Toggle(want)
  local f = BF.Build()
  if want == nil then want = not f:IsShown() end
  if fighting() then
    NS.Print("BiS> bosses opens after the fight")
    return f:IsShown()
  end
  if BF.db then BF.db.open = want and true or false end   -- yours: it comes back with you after a death or a hearth
  if want then
    BF.Scan()
    BF.Write()
    f:Show()
    if f.Raise then f:Raise() end
    BF.Paint()
  else
    BF.back = nil
    f:Hide()
  end
  return f:IsShown()
end

--- RESET: a fresh run here - nothing down, nothing marked.
function BF.Reset()
  if not (BF.db and BF.key) then return end
  BF.found = {}
  if BF.map then BF.run = BF.Run(BF.db, BF.map, true) end
  BF.allAt, BF.findAt = 1, 1
  BF.Say("a fresh run", "gold")
  BF.Write()
  BF.Paint()
end

-- ------------------------------------------------------------------ the door: a button in the BiS> tools box

function BF.ShowBox()
  return (R:Enabled("bosses") and BF.db and BF.db.button ~= false and (BF.map ~= nil or (BF.key ~= nil and #BF.quests > 0)) and not fighting()) and true or false
end

function BF.BoxButton()
  if BF.box then return BF.box end
  local k = K()
  local b = CreateFrame("Button", "BiSToolsBossesBox", UIParent)
  b:SetSize(26, 26)
  k.tex(b, "BACKGROUND", "field", 0.95)
  b.edge = k.border(b, "accent", 1)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon:SetTexture(BF.MARK_ICON .. 8)
  b:SetScript("OnClick", function() BF.Toggle() end)
  b.wash = k.tex(b, "BORDER", "accent", 0)
  b:SetScript("OnEnter", function(self)
    self.wash:SetAlpha(BF.GLOW) self.edge:set("gold", 1)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("BiS> bosses")
    GameTooltip:AddLine("Every boss here: find them, target them, mark them", 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function(self)
    self.wash:SetAlpha(0) self.edge:set("accent", 1)
    if GameTooltip then GameTooltip:Hide() end
  end)
  b:Hide()
  BF.box = b
  return b
end

-- ------------------------------------------------------------------ events

BF.near = {}
BF.page, BF.allAt, BF.findAt = 1, 1, 1
local ev = CreateFrame("Frame")
BF.events = ev
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
                     "ENCOUNTER_START", "ENCOUNTER_END" }) do
  pcall(ev.RegisterEvent, ev, e)
end
BF.EYES = { "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED" }

--[[ WHICH COPY OF THE DUNGEON (22 Nov 2026, Arn: "had to restart the boss app, how did fojji determin it was a new dungeon" - FojjiCore
  said "this is a fresh copy"; learned from its idea, written our own way). A GUID of a thing in a dungeon carries the dungeon's id and
  the number of the copy it lives in: Kind-0-server-DUNGEON-COPY-... Inside, a creature's GUID is a secret - but YOUR OWN cast's GUID
  (UNIT_SPELLCAST_SUCCEEDED's second answer) and a corpse you loot (GetLootSourceInfo) are in this copy for sure. The run remembers
  its copy; a sure reading of another copy = the dungeon was reset: a fresh run by itself. A copy only changes across a loading screen,
  so the watch is armed at BF.Enter and switched off after its first plain reading. ]]
function BF.CopyOf(guid)
  guid = plain(guid)
  if type(guid) ~= "string" then return nil end
  local inst, copy = guid:match("^%a+%-%d+%-%d+%-(%d+)%-(%d+)")
  if not inst or not BF.map or tonumber(inst) ~= BF.map then return nil end
  return copy
end
--- A sure reading of this copy. Answers "same" | "fresh" | "learned" | nil.
function BF.Copy(guid)
  local c = BF.CopyOf(guid)
  local r = BF.run
  if not (c and r and BF.db) then return nil end
  BF.CopyWatch(false)
  if not r.copy then r.copy = c return "learned" end
  if r.copy == c then return "same" end
  BF.found = {}
  BF.run = BF.Run(BF.db, BF.map, true)
  BF.run.copy = c
  BF.allAt, BF.findAt = 1, 1
  BF.Say("a fresh copy of the dungeon: a new run", "gold")
  BF.Write()
  BF.Paint()
  return "fresh"
end
BF.COPY_EVENTS = { "LOOT_READY" }
function BF.CopyWatch(on)
  for _, e in ipairs(BF.COPY_EVENTS) do
    if on then pcall(ev.RegisterEvent, ev, e) else pcall(ev.UnregisterEvent, ev, e) end
  end
  if on and ev.RegisterUnitEvent then pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_SUCCEEDED", "player")
  elseif on then pcall(ev.RegisterEvent, ev, "UNIT_SPELLCAST_SUCCEEDED")
  else pcall(ev.UnregisterEvent, ev, "UNIT_SPELLCAST_SUCCEEDED") end
  BF.copyWatch = on and true or false
end

--- The eyes are open only inside a place of the list.
function BF.Eyes(on)
  for _, e in ipairs(BF.EYES) do
    if on then pcall(ev.RegisterEvent, ev, e) else pcall(ev.UnregisterEvent, ev, e) end
  end
  BF.eyes = on and true or false
  if NS.BossQuests then NS.BossQuests.Listen(on) end
end

function BF.OnEvent(event, a1, a2, _, _, a5)
  if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then return BF.Enter() end
  if not BF.key then return end
  if event == "NAME_PLATE_UNIT_ADDED" then
    if type(a1) == "string" and BF.Look(a1) then BF.Paint() end
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    local name = type(a1) == "string" and ask(UnitName, a1) or nil
    if name and BF.near[name] then             -- only a boss's plate going away needs a look round
      BF.Scan(a1)
      BF.Paint()
    end
  elseif event == "PLAYER_TARGET_CHANGED" then
    if BF.Look("target") then BF.Paint() end
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    if a1 == "player" then BF.Copy(a2) end
  elseif event == "LOOT_READY" then
    for i = 1, tonumber(ask(GetNumLootItems)) or 0 do
      local g = ask(GetLootSourceInfo, i)
      if g and BF.Copy(g) then break end
    end
  elseif event == "ENCOUNTER_START" then
    BF.fight = plain(a1)
  elseif event == "ENCOUNTER_END" then
    BF.fight = nil
    local id, name, success = plain(a1), plain(a2), plain(a5)
    if success == 1 or success == true then
      for _, e in ipairs(BF.map and BF.bosses or {}) do
        if e.id == id or e.name == name then BF.Down(e, "fight") break end
      end
    end
  elseif event == "PLAYER_REGEN_DISABLED" then
    -- the fight starts: the window stays, dimmed and unclickable (BF.Dim) - it no longer steps away
    if BF.frame and BF.frame:IsShown() then BF.Dim(true) end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if BF.questsLate then BF.QuestsNow() end
    if BF.dirty then BF.Write() end
    if BF.keyDirty and BF.db then BF.ApplyKey(BF.db) end
    if BF.frame and BF.frame.dimmed then BF.Dim(false) end
    if BF.back then BF.back = nil BF.Toggle(true) end
    if BF.showLater then BF.showLater = nil BF.Paint() end          -- the rows a mid-fight paint could not show or hide
  end
end
ev:SetScript("OnEvent", function(_, event, ...)
  if not R:Enabled("bosses") and event ~= "PLAYER_ENTERING_WORLD" and event ~= "ZONE_CHANGED_NEW_AREA" then return end
  BF.OnEvent(event, ...)
end)

R:Register({
  name = "bosses",
  short = "boss",
  desc = "boss finder: every boss where you are - target, mark and ping them",
  usage = "/bist bosses  |  /bist bosses key <KEY>|key off|reset",
  defaultOff = true,                 -- new after 1.0: the freeze must not write it on for an older save
  defaults = { auto = true, button = true },
  options = {
    { kind = "toggle", label = "open when you walk into a dungeon",
      help = "The boss list comes up by itself in a dungeon or raid it knows (once a run).",
      get = function(db) return db.auto ~= false end,
      set = function(db, v) db.auto = v and true or false end },
    { kind = "toggle", label = "button in the tools box in a dungeon",
      help = "Inside a dungeon or raid, the BiS> tools box shows a skull button that opens the list.",
      get = function(db) return db.button ~= false end,
      set = function(db, v) db.button = v and true or false if NS.Box and NS.Box.Refresh then NS.Box.Refresh() end end },
    { kind = "button", label = "the boss list", button = "open",
      help = "Every boss where you stand: click one to target and mark it, FIND for the next one, pinged.",
      action = function(db) BF.db = db BF.Toggle(true) end },
  },
  OnInit = function(_, db) BF.db = db end,
  OnLogin = function(_, db) BF.db = db BF.ApplyKey(db) end,
  OnEnable = function(_, db) BF.db = db BF.map, BF.key = false, false BF.Enter() BF.ApplyKey(db) end,
  OnDisable = function()
    if BF.frame and not fighting() then BF.frame:Hide() end
    BF.Eyes(false)
    BF.map, BF.key, BF.spot, BF.list, BF.bosses, BF.run = nil, nil, nil, nil, nil, nil
    BF.quests, BF.found = {}, {}
    if BF.fkey and not InCombatLockdown() then ClearOverrideBindings(BF.fkey) end
    if NS.Box and NS.Box.Refresh then NS.Box.Refresh() end
  end,
  OnOpen = function(_, db, recenter)
    BF.db = db
    if recenter then
      db.pos = nil                                  -- "reset window positions": back to the middle, for good
      BF.Place()
      return
    end
    BF.Toggle(true)
  end,
  IsOpen = function() return BF.IsOpen() end,
  OnClose = function() BF.Toggle(false) end,
  OnSlash = function(_, db, args)
    BF.db = db
    local cmd, rest = (args or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "key" then
      if rest == "" or rest:lower() == "off" then
        db.key = nil
        NS.Print("bosses: the FIND key is off")
      else
        db.key = rest:upper()
        NS.Print("bosses: %s finds the next boss", db.key)
      end
      BF.ApplyKey(db)
    elseif cmd == "reset" then
      BF.Reset()
      NS.Print("bosses: a fresh run")
    else
      BF.Toggle()
    end
  end,
})
