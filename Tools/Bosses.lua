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

BF.W, BF.H = 343, 240              -- 1.43:1, the family's window shape
BF.SCALE = 1.45                    -- every window starts at 1.2 ("so small cant read"); this one, Arn 8 Nov: "lil small"
BF.ROWS, BF.ROW = 8, 16
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
BF.STATE_WORD = { down = "DOWN", near = "IN SIGHT", marked = "MARKED", far = "", group = "GROUP" }

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
    if not e.group and not (BF.run and BF.run.down[e.id]) then
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
    c.all = c.all + 1
    if r and r.down[e.id] then
      c.down = c.down + 1
    else
      if BF.near[e.name] then c.near = c.near + 1 end
      if r and r.marked[e.id] then c.marked = c.marked + 1 end
    end
  end
  return c
end

-- ------------------------------------------------------------------ the macros (the suite runs them)

--- The lines that look for one boss: clear, search, mark (when it has one), ping (find, or shift on a row).
function BF.Lines(e, ping)
  local out = { "/cleartarget", "/targetexact " .. e.name }
  local m = BF.mark and BF.mark[e.id]
  if m then out[#out + 1] = "/tm [exists] !" .. m end
  if ping == "always" then out[#out + 1] = "/ping [exists] " .. BF.PING
  elseif ping == "shift" then out[#out + 1] = "/ping [mod:shift,exists] " .. BF.PING end
  return table.concat(out, "\n")
end

--- A row's macro: that boss, pinged when shift is held, your old target back when it is not in sight.
function BF.RowMacro(e)
  if not e or e.group then return "" end
  return BF.Lines(e, "shift") .. "\n/targetlasttarget [noexists]"
end

--- The bosses a press may look for, standing and targetable, from `from` round the list.
function BF.Standing(from)
  local list, out = BF.list or {}, {}
  local n = #list
  for i = 0, n - 1 do
    local e = list[((from or 1) - 1 + i) % n + 1]
    if e and not e.group and not (BF.run and BF.run.down[e.id]) then out[#out + 1] = e end
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
  for _, e in ipairs(standing) do if BF.near[e.name] then return e end end
  return standing[1]
end

function BF.FindMacro()
  local e = BF.FindNext()
  if not e then return "", nil end
  return BF.Lines(e, "always") .. "\n/targetlasttarget [noexists]", e
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

--- After a press: if your target is the boss, it is MARKED (and its creature id learned for the screen).
function BF.Took(e)
  if not e or e.group then return false end
  local got = targetName() == e.name
  if got and BF.run then
    BF.run.marked[e.id] = true
    BF.LearnUnit("target")
    BF.Say(e.name .. (BF.mark and BF.mark[e.id] and " marked" or " targeted"), "good")
  elseif not got then
    BF.Say(e.name .. " is not in sight", "ink2")
  end
  BF.Paint()
  return got
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
  if ask(UnitIsDead, unit) == true then BF.Down(e, "seen") end
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
  BF.near[e.name] = nil
  local c = BF.Counts()
  BF.Say(e.name .. " down - " .. c.down .. " of " .. c.all, "good")
  BF.lastHow = how
  BF.Write()
  BF.Paint()
  return true
end

--- Into a place (or out of one): the list, the run, the eyes on or off.
function BF.Enter()
  local db = BF.db
  if not db then return end
  local map, data = nil, nil
  if R:Enabled("bosses") then map, data = BF.Here() end
  if map ~= BF.map then
    BF.map, BF.data = map, data
    BF.list, BF.byName, BF.near = data and data.bosses or nil, {}, {}
    BF.page, BF.allAt, BF.findAt = 1, 1, 1
    for _, e in ipairs(BF.list or {}) do BF.byName[e.name] = e end
    BF.Eyes(map ~= nil)
    if map then
      local was = db.run
      BF.run = BF.Run(db, map)
      BF.Scan()
      if db.auto ~= false and BF.run ~= was and not fighting() then BF.Toggle(true) end
    else
      BF.run = nil
      if BF.frame and BF.frame:IsShown() and not fighting() then BF.frame:Hide() end
    end
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
  f.caption = K().fs(sc, "", 8, "ink")
  f.caption:SetPoint("BOTTOM", sc, "BOTTOM", 0, 3)
  f.caption:SetWidth(w - 6)
  f.caption:SetWordWrap(false)
  f.nopic = K().fs(sc, "", 7, "ink2")
  f.nopic:SetPoint("TOP", sc, "TOP", 0, -4)
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

function BF.BuildGauge(f, x, y)
  local g = CreateFrame("Frame", nil, f)
  g:SetSize(56, 52)
  g:SetPoint("TOPLEFT", x, y)
  f.gauge = g
  local cx, cy, rad = 28, -28, 23
  local face = g:CreateTexture(nil, "BACKGROUND")
  face:SetTexture(BF.ROUND)
  face:SetSize(rad * 2 + 4, rad * 2 + 4)
  face:SetPoint("CENTER", g, "TOPLEFT", cx, cy)
  face:SetVertexColor(rgb("frame"))
  -- eleven ticks from -135 to +135 degrees (up is 0), the last three amber... no: the far end is the good end
  for i = 0, 10 do
    local a = math.rad(-135 + i * 27)
    local r1 = (i % 5 == 0) and rad - 6 or rad - 3
    local l = line(g, "ARTWORK", i == 10 and "good" or "ink2", 0.9, (i % 5 == 0) and 2 or 1)
    l:SetStartPoint("TOPLEFT", g, cx + math.sin(a) * r1, cy + math.cos(a) * r1)
    l:SetEndPoint("TOPLEFT", g, cx + math.sin(a) * rad, cy + math.cos(a) * rad)
  end
  f.needle = line(g, "OVERLAY", "gold", 1, 2)
  local hub = g:CreateTexture(nil, "OVERLAY")
  hub:SetTexture(BF.ROUND)
  hub:SetSize(6, 6)
  hub:SetPoint("CENTER", g, "TOPLEFT", cx, cy)
  hub:SetVertexColor(rgb("gold"))
  f.gaugeAt = { cx = cx, cy = cy, rad = rad - 4 }
  local lbl = K().fs(g, "DOWN", 7, "dim")
  lbl:SetPoint("CENTER", g, "TOPLEFT", cx, cy - 13)
  return g
end

--- The needle: 0 bosses down points at -135 degrees, all of them at +135.
function BF.NeedleAngle(down, all)
  if not all or all <= 0 then return math.rad(-135) end
  return math.rad(-135 + 270 * math.min(1, down / all))
end

function BF.Build()
  if BF.frame then return BF.frame end
  local k = K()
  local f = CreateFrame("Frame", "BiSToolsBosses", UIParent)
  BF.frame = f
  f:SetSize(BF.W, BF.H)
  f:SetPoint("CENTER", 0, 80)
  f:SetFrameStrata("DIALOG")
  f:SetScale(BF.SCALE)
  if UISpecialFrames then table.insert(UISpecialFrames, "BiSToolsBosses") end   -- Escape closes it (out of fights:
  f:EnableMouse(true)                                                              -- it is off the list while dimmed)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) if not fighting() then self:StartMoving() end end)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  k.tex(f, "BACKGROUND", "frame", 0.97)
  k.border(f, "edge", 1)
  f.title = k.fs(f, "BiS> BOSSES", 10, "accent")
  f.title:SetPoint("TOPLEFT", 8, -7)
  f.place = k.fs(f, "", 9, "ink")
  f.place:SetPoint("LEFT", f.title, "RIGHT", 8, 0)
  f.place:SetWidth(170)
  f.place:SetJustifyH("LEFT")
  f.place:SetWordWrap(false)
  f.close = key(f, "x", 16, 14, nil, function() BF.Toggle(false) end)
  f.close:SetPoint("TOPRIGHT", -4, -4)
  f.build = k.fs(f, "", 7, "dim")                    -- the fingerprint: faint, which copy this is
  f.build:SetJustifyH("RIGHT")
  f.build:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
  f.build:SetAlpha(0.6)
  -- the list: a row a boss, its mark, its name, what is known
  local x0, w = 8, 198
  f.rows = {}
  for i = 1, BF.ROWS do
    local r = secure(nil, f)
    r:SetSize(w, BF.ROW - 1)
    r:SetPoint("TOPLEFT", x0, -24 - (i - 1) * BF.ROW)
    k.tex(r, "BACKGROUND", "field", 0.6)
    r.bar = r:CreateTexture(nil, "ARTWORK")
    r.bar:SetPoint("TOPLEFT")
    r.bar:SetPoint("BOTTOMLEFT")
    r.bar:SetWidth(2)
    r.bar:SetColorTexture(rgb("accent"))
    r.bar:SetAlpha(0)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(12, 12)
    r.icon:SetPoint("LEFT", 4, 0)
    r.num = k.fs(r, "", 7, "dim")
    r.num:SetPoint("LEFT", 4, 0)
    r.name = k.fs(r, "", 9, "ink")
    r.name:SetPoint("LEFT", 20, 0)
    r.name:SetWidth(w - 20 - 54)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)                         -- one line: a long name is cut, never wrapped over the next row
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
  f.prev = key(f, "<", 22, 14, nil, function() BF.Turn(-1) end)
  f.prev:SetPoint("TOPLEFT", x0, -24 - BF.ROWS * BF.ROW - 2)
  f.next = key(f, ">", 22, 14, nil, function() BF.Turn(1) end)
  f.next:SetPoint("LEFT", f.prev, "RIGHT", 4, 0)
  f.pageNo = k.fs(f, "", 7, "dim")
  f.pageNo:SetPoint("LEFT", f.next, "RIGHT", 6, 0)
  f.say = k.fs(f, "", 8, "ink2")
  f.say:SetPoint("LEFT", f.pageNo, "RIGHT", 8, 0)
  f.say:SetWidth(w - 64)
  f.say:SetJustifyH("LEFT")
  f.say:SetWordWrap(false)
  -- the right: the screen (the sunset, the boss in 3D), the gauge and its readout
  local rx, rw = x0 + w + 8, BF.W - (x0 + w + 8) - 8
  BF.BuildScreen(f, rx, -24, rw, 92)
  BF.BuildGauge(f, rx - 2, -120)
  f.readDown = k.fs(f, "", 12, "ink")
  f.readDown:SetPoint("TOPLEFT", rx + 58, -124)
  f.readNear = k.fs(f, "", 7, "gold")
  f.readNear:SetPoint("TOPLEFT", rx + 58, -142)
  f.readMark = k.fs(f, "", 7, "accent")
  f.readMark:SetPoint("TOPLEFT", rx + 58, -152)
  f.readKind = k.fs(f, "", 7, "dim")
  f.readKind:SetPoint("TOPLEFT", rx + 58, -162)
  -- the tape: one segment a boss, the colour of what is known
  f.tape = CreateFrame("Frame", nil, f)
  f.tape:SetSize(BF.W - 16, 8)
  f.tape:SetPoint("TOPLEFT", 8, -182)
  k.tex(f.tape, "BACKGROUND", "field", 0.9)
  f.segs = {}
  for i = 1, BF.TAPE_MAX do
    local s = f.tape:CreateTexture(nil, "ARTWORK")
    s:SetColorTexture(rgb("line2"))
    s:Hide()
    f.segs[i] = s
  end
  -- the keys: MARK ALL and FIND are secure (Blizzard's own commands), RESET is ours
  f.all = key(f, "MARK ALL", 100, 20, "BiSToolsBossAll")
  f.all:SetPoint("TOPLEFT", 8, -196)
  f.all:SetScript("PostClick", function(self) BF.AfterAll(self) end)
  f.all.tip = function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Target every boss in sight and mark it")
    GameTooltip:AddLine("A long list takes two presses", 1, 1, 1)
    GameTooltip:Show()
  end
  f.find = key(f, "FIND", 100, 20, "BiSToolsBossFindKey")
  f.find:SetPoint("LEFT", f.all, "RIGHT", 6, 0)
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
  f.reset = key(f, "RESET", 60, 20, nil, function() BF.Reset() end)
  f.reset:SetPoint("LEFT", f.find, "RIGHT", 6, 0)
  f.help = k.fs(f, BF.HELP, 7, "dim")
  f.help:SetPoint("BOTTOMLEFT", 8, 6)
  -- the screen's clock: only while shown (the client runs no OnUpdate for a hidden frame)
  local acc = 0
  f.tick = function(_, elapsed)
    acc = acc + (elapsed or 0)
    if acc < 1 / BF.FPS then return end
    BF.t = (BF.t or 0) + acc * 0.5
    acc = 0
    BF.GridAt(BF.t)
  end
  f:SetScript("OnUpdate", f.tick)
  f:SetScript("OnHide", function() BF.focus = nil end)
  f:Hide()
  return f
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

--- The screen: the boss under the mouse, else the next one to find - in 3D over the sunset, or the sunset alone.
function BF.Screen()
  local f = BF.frame
  if not (f and f.screen) then return end
  local e = BF.focus or BF.FindNext() or (BF.list and BF.list[1])
  f.caption:SetText(e and e.name or "")
  local m = f.model
  if not m then return end
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
    f.nopic:SetText(e and (e.group and "A FIGHT OF SEVERAL" or "NO PICTURE YET") or "")
    BF.showing, BF.missAt = nil, t
    return
  end
  f.nopic:SetText("")
  local want = display and ("d" .. display) or ("n" .. npc)
  BF.showing = want
  m:Show()
  BF.Dress(m, npc, display, 1)
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
  local wseg = n > 0 and ((BF.W - 16) - gap * (n - 1)) / n or 0
  for i = 1, BF.TAPE_MAX do
    local s = f.segs[i]
    local e = list[i]
    if i <= n and e then
      s:ClearAllPoints()
      s:SetPoint("TOPLEFT", f.tape, "TOPLEFT", (i - 1) * (wseg + gap), 0)
      s:SetSize(wseg, 8)
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
  f.place:SetText(BF.data and BF.data.name or "not in a dungeon")
  f.build:SetText(NS.Stamp and NS.Stamp() or "")
  local page = BF.page or 1
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
      r.name:SetText(e.name)
      r.name:SetTextColor(rgb(st == "down" and "dim" or "ink"))
      r.state:SetText(BF.STATE_WORD[st] or "")
      r.state:SetTextColor(rgb(BF.STATE_INK[st] or "ink2"))
      r:Show()
    else
      r:Hide()
    end
  end
  local pages = BF.Pages()
  f.pageNo:SetText(pages > 1 and (page .. "/" .. pages) or "")
  f.prev:SetShown(pages > 1)
  f.next:SetShown(pages > 1)
  local c = BF.Counts()
  f.readDown:SetText(c.down .. " / " .. c.all)
  f.readNear:SetText(c.near .. " IN SIGHT")
  f.readMark:SetText(c.marked .. " MARKED")
  f.readKind:SetText(BF.data and (BF.data.kind == "raid" and "RAID" or "DUNGEON") or "")
  local a = BF.NeedleAngle(c.down, c.all)
  local g = f.gaugeAt
  f.needle:SetStartPoint("TOPLEFT", f.gauge, g.cx, g.cy)
  f.needle:SetEndPoint("TOPLEFT", f.gauge, g.cx + math.sin(a) * g.rad, g.cy + math.cos(a) * g.rad)
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
BF.FIGHT_ALPHA = 0.35
BF.FIGHT_HELP = "FIGHT · screen quiet, keys locked - back after the fight"
BF.HELP = "click: target + mark   shift: + ping   FIND: one at a time   esc: close"

function BF.Clickables(f)
  local list = { f.close, f.prev, f.next, f.all, f.find, f.reset }
  for _, r in ipairs(f.rows or {}) do list[#list + 1] = r end
  return list
end

local function escapeList(on)
  local list = UISpecialFrames
  if type(list) ~= "table" then return end
  for i = #list, 1, -1 do if list[i] == "BiSToolsBosses" then table.remove(list, i) end end
  if on then list[#list + 1] = "BiSToolsBosses" end
end

--- Dim (a fight starts) or wake (it ended). Out of the lockdown only; returns false when refused.
function BF.Dim(on)
  local f = BF.frame
  if not f or fighting() then return false end
  f.dimmed = on and true or false
  f:SetAlpha(on and BF.FIGHT_ALPHA or 1)
  f:EnableMouse(not on)
  for _, b in ipairs(BF.Clickables(f)) do if b and b.EnableMouse then b:EnableMouse(not on) end end
  escapeList(not on)
  f:SetScript("OnUpdate", (not on) and f.tick or nil)
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
  if not (BF.db and BF.map) then return end
  BF.run = BF.Run(BF.db, BF.map, true)
  BF.allAt, BF.findAt = 1, 1
  BF.Say("a fresh run", "gold")
  BF.Write()
  BF.Paint()
end

-- ------------------------------------------------------------------ the door: a button in the BiS> tools box

function BF.ShowBox()
  return (R:Enabled("bosses") and BF.db and BF.db.button ~= false and BF.map ~= nil and not fighting()) and true or false
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

--- The eyes are open only inside a place of the list.
function BF.Eyes(on)
  for _, e in ipairs(BF.EYES) do
    if on then pcall(ev.RegisterEvent, ev, e) else pcall(ev.UnregisterEvent, ev, e) end
  end
  BF.eyes = on and true or false
end

function BF.OnEvent(event, a1, a2, _, _, a5)
  if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then return BF.Enter() end
  if not BF.map then return end
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
  elseif event == "ENCOUNTER_START" then
    BF.fight = plain(a1)
  elseif event == "ENCOUNTER_END" then
    BF.fight = nil
    local id, name, success = plain(a1), plain(a2), plain(a5)
    if success == 1 or success == true then
      for _, e in ipairs(BF.list or {}) do
        if e.id == id or e.name == name then BF.Down(e, "fight") break end
      end
    end
  elseif event == "PLAYER_REGEN_DISABLED" then
    -- the fight starts: the window stays, dimmed and unclickable (BF.Dim) - it no longer steps away
    if BF.frame and BF.frame:IsShown() then BF.Dim(true) end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if BF.dirty then BF.Write() end
    if BF.keyDirty and BF.db then BF.ApplyKey(BF.db) end
    if BF.frame and BF.frame.dimmed then BF.Dim(false) end
    if BF.back then BF.back = nil BF.Toggle(true) end
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
  OnEnable = function(_, db) BF.db = db BF.map = false BF.Enter() BF.ApplyKey(db) end,
  OnDisable = function()
    if BF.frame and not fighting() then BF.frame:Hide() end
    BF.Eyes(false)
    BF.map, BF.list, BF.run = nil, nil, nil
    if BF.fkey and not InCombatLockdown() then ClearOverrideBindings(BF.fkey) end
    if NS.Box and NS.Box.Refresh then NS.Box.Refresh() end
  end,
  OnOpen = function(_, db, recenter)
    BF.db = db
    if recenter then
      if BF.frame then BF.frame:ClearAllPoints() BF.frame:SetPoint("CENTER", 0, 80) end
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
