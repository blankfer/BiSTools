-- BiSTools / Tools / TargetFarming.lua
-- Remembers the last mob you killed (or a name you typed). Click it and the
-- scanner ticks: every half second it looks for a fresh copy nearby (alive, not
-- in combat, not tapped) and drops the skull on it. Click again to stop.
-- Optional key targets whatever wears the skull.
local _, NS = ...
local T = NS.T
local SKULL = 8   -- mouseover finds wear the skull
local SCAN_MARKS = 7   -- the scanner deals 1..7 (star..cross) to every free copy it sees

-- everything for this tool hangs off one table (locals budget rule)
local F = { rows = {} }
F.MOUSE_GAP = 0.1      -- seconds between scans a mouseover may start (the ticker keeps its own 0.5)

local SHADE = { frame = "0d0b18", header = "141127", field = "17132e", hair = "2a2446", edge = "3a3260" }
local function hx(hex)
  return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end
function F.color(name)
  if SHADE[name] then return hx(SHADE[name]) end
  return T.rgb(name)
end
function F.tex(parent, layer, name, a)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND")
  t:SetAllPoints()
  local r, g, b = F.color(name)
  t:SetColorTexture(r, g, b, a or 1)
  return t
end
function F.fs(parent, text, size, color)
  local s = parent:CreateFontString(nil, "OVERLAY")
  s:SetFont(STANDARD_TEXT_FONT, size or 12, "")
  local r, g, b = F.color(color or "ink")
  s:SetTextColor(r, g, b, 1)
  s:SetText(text or "")
  return s
end
-- ---------------------------------------------------------------- kills
function F.OwnGUID(guid)
  return guid and (guid == UnitGUID("player") or (UnitExists("pet") and guid == UnitGUID("pet")))
end

function F.Record(db, name, guid)
  local last = db.last
  if last and last.name == name then
    last.count = last.count + 1
    last.guid = guid or last.guid
  else
    db.last = { name = name, count = 1, guid = guid }
  end
  return db.last
end

-- ---------------------------------------------------------------- scan
-- A VALUE THE CLIENT WILL LET US LOOK AT, OR NIL (6 Oct 2026). On WoW Forever a unit's raid mark
-- comes back as a SECRET number - in the open world, measured by Arn's BugGrabber: "attempt to
-- compare local 'm' (a secret number value)" from the scanner, and the same from the farm spots
-- one kill later. A secret refuses comparison, arithmetic and being a table key; even `==` taints.
-- So the question "is it secret" comes FIRST, before anything else touches the value.
function F.Plain(v)
  if issecretvalue then
    local ok, secret = pcall(issecretvalue, v)
    if not ok or secret then return nil end
  end
  return v
end

--- A unit's raid mark as a plain number, or nil when it has none OR the client will not say.
--- Every read of a mark in BiSTools goes through here.
function F.Mark(u)
  local ok, m = pcall(GetRaidTargetIndex, u)
  if not ok then return nil end
  m = F.Plain(m)
  if type(m) ~= "number" then return nil end
  return m
end

--- A unit's name, plain, or nil (nameplate names can be secret inside an instance).
function F.Name(u)
  local n = F.Plain(UnitName(u))
  if type(n) ~= "string" then return nil end
  return n
end

-- WHAT THE FARM KEY HAS MARKED, BY GUID (6 Oct 2026). Forever hides every mark, so the addon cannot
-- see that the skull is already out. Arn: "if something is already marked skull it'll look for
-- another target without a mark and put another marker". So the key keeps its OWN record of what it
-- handed out - guid -> mark - and the next press takes the next free mark: skull, cross, square,
-- moon, triangle, diamond, circle, star. A kill frees its mark. The game moves a mark to whoever
-- gets it last, so giving a mark away takes it from whoever had it here too. Session only: a
-- /reload forgets, which costs one skull handed out twice, never a wrong mob.
F.placed = {}
F.MARK_ORDER = { 8, 7, 6, 5, 4, 3, 2, 1 }

--- The mark the key should give this mob: the one it already has from us, else the first free one.
function F.NextMark(guid)
  if guid and F.placed[guid] then return F.placed[guid] end
  local held = {}
  for _, m in pairs(F.placed) do held[m] = true end
  for _, m in ipairs(F.MARK_ORDER) do
    if not held[m] then return m end
  end
  return SKULL                       -- all eight out: the skull moves, as it always did
end

function F.Placed(guid, mark)
  if not guid or not mark then return end
  for g, m in pairs(F.placed) do
    if m == mark and g ~= guid then F.placed[g] = nil end
  end
  F.placed[guid] = mark
end

function F.Plates()
  if not C_NamePlate or not C_NamePlate.GetNamePlates then return {} end
  return C_NamePlate.GetNamePlates()
end

-- Every flag here can be a secret BOOLEAN on Forever, and `not secret` is refused outright - so
-- each is asked about first, and one the client will not tell us makes the unit NOT clean: a
-- skull on a mob we could not check is worse than no skull.
function F.Secret(v)
  if not issecretvalue then return false end
  local ok, s = pcall(issecretvalue, v)
  return (not ok) or (s and true or false)
end

function F.Clean(u)
  for _, fn in ipairs({ UnitExists, function(x) return UnitCanAttack("player", x) end }) do
    local v = fn(u)
    if F.Secret(v) or not v then return false end       -- must be a plain yes
  end
  local flags = { UnitIsDead, UnitAffectingCombat }
  if UnitIsTapDenied then flags[#flags + 1] = UnitIsTapDenied end
  for _, fn in ipairs(flags) do
    local v = fn(u)
    if F.Secret(v) then return false end                 -- cannot tell: not clean
    if v then return false end
  end
  return true
end

-- ---------------------------------------------------------------- sound
-- db.sound: "first"  = voice line on the first find, quiet ping after
--           "always" = voice line on every find
--           "off"    = nothing (the default since 22 Oct 2026 - Arn: "lets turn that one off by default";
--                      the whisper ping kept going off in Orgrimmar)
F.VOICE_LINE = "Skull"
F.MARK_NAMES = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
F.PING = 3081 -- TELL_MESSAGE (whisper ping): audible over combat, not a siren
F.SOUND_MODES = { "first", "always", "off" }
function F.Speak(text)
  local FC = _G.FojjiCore
  if FC and FC.Speak and FC:Speak(text) then return "fojji" end
  if C_VoiceChat and C_VoiceChat.SpeakText then
    C_VoiceChat.SpeakText(0, text, Enum and Enum.VoiceTtsDestination and Enum.VoiceTtsDestination.LocalPlayback or 1, 1, 100)
    return "tts"
  end
  PlaySound(F.PING, "Master")
  return "ping"
end
function F.Found(db, line)
  db.finds = (db.finds or 0) + 1
  local mode = db.sound or "off"
  if mode == "off" then return end
  if mode == "always" or db.finds == 1 then F.Speak(line or F.VOICE_LINE) else PlaySound(F.PING, "Master") end
end
function F.SetSound(db, mode)
  for _, m in ipairs(F.SOUND_MODES) do
    if m == mode then db.sound = m return true end
  end
  return false
end

-- one pass: returns unit token that now carries the skull (or nil)
--
-- ON FOREVER THE SCANNER MARKS NOTHING (6 Oct 2026). Arn's BugGrabber: "AddOn 'BiSTools' tried to
-- call the protected function 'SetRaidTarget()'", from this function on the ticker. There, an addon
-- may not set a mark at all; Blizzard's /tm in a secure macro may - the same split as pings (an
-- addon's C_Ping call forbidden, /ping in a secure button fine, measured 1 Oct). So on a restricted
-- client the scan only FINDS: it returns the clean copy, the window and the sound say so, and the
-- farm key (F.TargetButton) targets it and marks it with your key press.
function F.Scan(name, db)
  local canMark = not F.Restricted()
  -- the mouse first: hovering works from any distance, nameplates do not
  if UnitExists("mouseover") and F.Name("mouseover") == name and F.Clean("mouseover") then
    -- already wearing anything (scanner mark, hand mark, skull)? leave it alone
    if canMark and not F.Mark("mouseover") then
      SetRaidTarget("mouseover", SKULL)
      if db then F.Found(db, "Skull") end
    end
    return "mouseover"
  end
  -- plates: every clean copy gets its own mark from 1..7. Marks already on a
  -- clean copy stay put; the rest get the lowest mark nobody clean is wearing.
  local first, used, unmarked = nil, {}, {}
  if db and F.Spots then
    for m in pairs(F.Spots.BoundMarks(db, name)) do used[m] = true end -- spot marks are not the scanner's to deal
  end
  for _, plate in ipairs(F.Plates()) do
    local u = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
    if u and F.Name(u) == name and F.Clean(u) then
      local m = F.Mark(u)
      if m and m >= 1 and m <= SCAN_MARKS then
        used[m] = true
        first = first or u
      else
        unmarked[#unmarked + 1] = u
      end
    end
  end
  if not canMark then
    -- Forever: every mark reads as "cannot say", so all copies land in `unmarked`. Prefer one the
    -- farm key has NOT marked yet (F.placed, our own record), so a skull already handed out is not
    -- handed to the same mob again and the next press marks a fresh copy.
    for _, u in ipairs(unmarked) do
      local g = F.Plain(UnitGUID(u))
      if not (g and F.placed[g]) then return u end
    end
    return first or unmarked[1]
  end
  local dealt = 0
  for _, u in ipairs(unmarked) do
    local m
    for i = 1, SCAN_MARKS do if not used[i] then m = i break end end
    if not m then break end
    used[m] = true
    SetRaidTarget(u, m)
    dealt = dealt + 1
    first = first or u
  end
  if dealt > 0 and db then F.Found(db, F.MARK_NAMES[dealt == 1 and F.Mark(unmarked[1]) or 0] or "Target") end
  return first
end

function F.Tick(db)
  if not db.active then return F.Stop() end
  local was = F.marked
  F.marked = F.Scan(db.active, db)
  -- on Forever nothing was marked, so the scan's own "found" never fired: say it here, once per
  -- copy coming into view, and the farm key does the marking
  if F.marked and not was and F.Restricted() then F.Found(db, "Target") end
  if F.Spots then F.Spots.Sync(db) F.Spots.Warn(db) end
end

function F.Start(db)
  if F.ticker then F.ticker:Cancel() end
  F.ticker = C_Timer.NewTicker(db.interval or 0.5, function() F.Tick(db) end)
  F.Tick(db)
end

function F.Stop()
  if F.ticker then F.ticker:Cancel() F.ticker = nil end
  F.marked = nil
end

function F.SetActive(db, name)
  if name and db.active == name then name = nil end
  db.active = name
  db.finds = 0
  if name then
    if not NS.Registry:Enabled("farm") then db.active = nil return end
    F.Start(db)
    F.Log("farming " .. name, "accent")
  else
    F.Stop()
  end
  F.Refresh(db)
  -- what is SHOWN follows the farmed mob (S.Shown): clicking it again clears the pins and the
  -- Spawns window at once, not a tick later; clicking it back brings everything back
  if F.Pins then F.Pins.Update(db) end
  if F.Spots and F.Spots.frame and F.Spots.frame:IsShown() then F.Spots.Refresh(db) end
  if F.Arrow and F.Arrow.Refresh then F.Arrow.Refresh(db) end
end

-- ---------------------------------------------------------------- the prompt
-- Window events go to the header prompt, never chat (chat is for slash answers).
function F.Log(text, colour)
  if F.con then F.con:Say(text, colour) else NS.Print("%s", text) end
end

-- standing slots: name (always), what is being farmed, how many spots are learned
function F.PaintSlots(db)
  local c = F.con
  if not c then return end
  c:Set("active", db.active and ("farming " .. db.active) or nil, "gold")
  local spots = 0
  if F.Spots and db.active and db.spots and db.spots[db.active] then spots = #db.spots[db.active] end
  c:Set("spots", spots > 0 and (spots .. (spots == 1 and " spot" or " spots")) or nil, "good")
end

-- ---------------------------------------------------------------- target key
-- One secure button. PreClick (out of combat) points it at the skulled unit;
-- in combat it falls back to /targetexact <name>.
function F.TargetButton()
  if F.tbtn then return F.tbtn end
  local b = CreateFrame("Button", "BiSToolsFarmTarget", UIParent, "SecureActionButtonTemplate")
  b:RegisterForClicks("AnyDown")
  b:SetAttribute("type", "macro")
  b:SetAttribute("macrotext", "")
  b:SetScript("PreClick", function(self)
    if InCombatLockdown() then return end
    local db = F.db
    local u = db and db.active and (F.marked or F.Scan(db.active))
    if u and F.Clean(u) and F.Restricted() then
      -- Forever: the addon may not mark, so the KEY does it - Blizzard's /tm in a secure macro,
      -- run by this key press. The spot's own mark when you stand at one, else the skull.
      --
      -- `/tm !N`, read off RestedXP (RXPGuides/Targeting.lua, 6 Oct 2026): on Forever the "!" sets
      -- the mark WITHOUT toggling it off when the unit already wears it (retail spells it "~").
      -- So the key never reads the current mark - which may be a secret on this client (RestedXP
      -- checks IsSecretValue before it compares one) and would throw in a comparison.
      local want = (F.Spots and F.Spots.Want and F.Spots.Want(db)) or F.NextMark(F.Plain(UnitGUID(u)))
      F.Placed(F.Plain(UnitGUID(u)), want)
      local macro = "/target " .. u .. "\n/tm !" .. want
      self:SetAttribute("type", "macro")
      self:SetAttribute("unit", nil)
      self:SetAttribute("macrotext", macro)
    elseif u and F.Clean(u) then
      self:SetAttribute("type", "target")
      self:SetAttribute("unit", u)
    else
      self:SetAttribute("type", "macro")
      self:SetAttribute("unit", nil)
      self:SetAttribute("macrotext", db and db.active and ("/targetexact " .. db.active) or "")
    end
  end)
  F.tbtn = b
  return b
end

function F.ApplyKey(db)
  local b = F.TargetButton()
  if InCombatLockdown() then F.keyDirty = true return end
  F.keyDirty = false
  ClearOverrideBindings(b)
  if db.key then SetOverrideBindingClick(b, true, db.key, "BiSToolsFarmTarget") end
end

-- ---------------------------------------------------------------- window
-- Innervate chrome: 16px header, tiny logo, 9pt title, 12x12 boxed buttons.
--   +------------------------------+
--   | [skull] Target Farming  _  x |
--   |  Vekh'nir Dreadhawk      x24 |   <- last thing you killed; click = farm it
--   |  Typed Name                  |   <- only when you searched for one
--   |  [ mob name...             ] |
--   +------------------------------+
F.W, F.HEADER, F.ROW, F.FIELD, F.PAD = 170, 16, 16, 16, 4
F.HEAD_A, F.BODY_A = 0.5, 0.45

function F.border(frame, name, a)
  local b = {}
  for _, side in ipairs({ "top", "bottom", "left", "right" }) do
    local t = frame:CreateTexture(nil, "OVERLAY")
    local r, g, bl = F.color(name)
    t:SetColorTexture(r, g, bl, a or 1)
    b[side] = t
  end
  b.top:SetPoint("TOPLEFT") b.top:SetPoint("TOPRIGHT") b.top:SetHeight(1)
  b.bottom:SetPoint("BOTTOMLEFT") b.bottom:SetPoint("BOTTOMRIGHT") b.bottom:SetHeight(1)
  b.left:SetPoint("TOPLEFT") b.left:SetPoint("BOTTOMLEFT") b.left:SetWidth(1)
  b.right:SetPoint("TOPRIGHT") b.right:SetPoint("BOTTOMRIGHT") b.right:SetWidth(1)
  function b:set(n, alpha)
    local r, g, bl = F.color(n)
    for _, side in ipairs({ "top", "bottom", "left", "right" }) do self[side]:SetColorTexture(r, g, bl, alpha or 1) end
  end
  return b
end

function F.HeaderButton(head, x, label, tip, tip2, onclick, colour)
  local b = CreateFrame("Button", nil, head)
  b:SetSize(12, 12)
  b:SetPoint("RIGHT", head, "RIGHT", x, 0)
  F.tex(b, "BACKGROUND", "field", 0.9)
  local edge = F.border(b, "edge", 1)
  local t = F.fs(b, label, 8, colour or "muted")
  t:SetPoint("CENTER")
  b.edge, b.label = edge, t
  b:SetScript("OnClick", function() onclick() end)
  b:SetScript("OnEnter", function(self)
    edge:set(colour or "accent", 1)
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(tip)
      if tip2 then GameTooltip:AddLine(tip2, 1, 1, 1, true) end
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function()
    edge:set("edge", 1)
    if GameTooltip then GameTooltip:Hide() end
  end)
  return b
end

function F.Build(db)
  if F.frame then return F.frame end
  F.db = db
  local f = CreateFrame("Frame", "BiSToolsFarm", UIParent)
  F.frame = f
  f:SetSize(F.W, F.HEADER)
  f:SetFrameStrata("MEDIUM")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint(1)
    db.pos = { point or "CENTER", x or 0, y or 0, rel or point or "CENTER" }
  end)
  F.tex(f, "BACKGROUND", "frame", F.BODY_A)
  F.border(f, "edge", 0.35)

  local head = CreateFrame("Frame", nil, f)
  F.head = head
  head:SetPoint("TOPLEFT") head:SetPoint("TOPRIGHT")
  head:SetHeight(F.HEADER)
  F.tex(head, "BACKGROUND", "header", F.HEAD_A)
  local hair = head:CreateTexture(nil, "BORDER")
  hair:SetPoint("BOTTOMLEFT") hair:SetPoint("BOTTOMRIGHT") hair:SetHeight(1)
  do local r, g, b = F.color("edge") hair:SetColorTexture(r, g, b, 1) end

  -- the title is the prompt (the law, bis-theme 1.1.0; Summon has worn it since 8 Sep,
  -- the farm window kept its logo + title until 11 Sep): "BiS> Farm_" cycling the
  -- state slots, events said over them. Header budget: 4 + prompt (<= W-43-8 = 119 px)
  -- ... buttons from the right x@-3, _@-17, t@-31 -> the strip is 43 px. No logo.
  F.title = F.fs(head, "", 8, "ink")
  F.title:SetPoint("LEFT", head, "LEFT", 4, 0)
  F.con = BiSTheme.Console(F.title, { width = F.W - 43 - 8 })
  F.con:Set("name", "Farm", "accent")
  -- the words fade; something has to tick Paint while the window is up (OnUpdate only
  -- runs while shown, so a hidden window costs nothing)
  local acc = 0
  f:SetScript("OnUpdate", function(_, dt)
    acc = acc + (dt or 0)
    if acc >= 0.1 then acc = 0 if F.con then F.con:Paint() end end
  end)

  F.closeBtn = F.HeaderButton(head, -3, "x", "Close", "/bist farm reopens it. The scanner keeps going.",
    function() F.Toggle(db, false) end, "warn")
  F.collapseBtn = F.HeaderButton(head, -17, "_", "Collapse", "Just the title bar.",
    function() F.SetCollapsed(db, not db.collapsed) end)
  F.spotsBtn = F.HeaderButton(head, -31, "t", "Spawn timers", "Where you killed it and when it comes back. /bist farm spots",
    function() if F.Spots then F.Spots.Toggle(db) end end)

  local body = CreateFrame("Frame", nil, f)
  body:SetPoint("TOPLEFT", head, "BOTTOMLEFT")
  body:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT")
  body:SetHeight(1)
  F.body = body

  -- search field: its own little well with an edge, like Innervate's inputs
  local well = CreateFrame("Frame", nil, body)
  well:SetHeight(F.FIELD)
  F.tex(well, "BACKGROUND", "field", 0.9)
  F.wellEdge = F.border(well, "edge", 1)
  F.well = well
  local eb = CreateFrame("EditBox", "BiSToolsFarmName", well)
  eb:SetAllPoints()
  eb:SetTextInsets(4, 4, 0, 0)
  eb:SetFont(STANDARD_TEXT_FONT, 9, "")
  eb:SetAutoFocus(false)
  eb:SetMaxLetters(48)
  do local r, g, b = F.color("ink") eb:SetTextColor(r, g, b, 1) end
  local ph = F.fs(well, "mob name...", 9, "dim")
  ph:SetPoint("LEFT", 4, 0)
  F.placeholder = ph
  eb:SetScript("OnEditFocusGained", function() ph:Hide() F.wellEdge:set("accent", 1) end)
  eb:SetScript("OnEditFocusLost", function(self)
    if self:GetText() == "" then ph:Show() end
    F.wellEdge:set("edge", 1)
  end)
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  eb:SetScript("OnEnterPressed", function(self)
    local name = (self:GetText() or ""):match("^%s*(.-)%s*$")
    self:SetText("")
    self:ClearFocus()
    if name ~= "" then F.Search(db, name) end
  end)
  F.edit = eb

  local pos = db.pos
  f:SetPoint(pos[1], UIParent, pos[4] or pos[1], pos[2], pos[3])
  f:Hide()
  F.Refresh(db)
  return f
end

-- a row: 3px accent bar when it is the active one, name left, count right
function F.Row(i, db)
  local r = F.rows[i]
  if r then return r end
  r = CreateFrame("Button", "BiSToolsFarmRow" .. i, F.body)
  r:SetHeight(F.ROW)
  r.bg = F.tex(r, "BACKGROUND", "surface", 0)
  r.bar = r:CreateTexture(nil, "ARTWORK")
  r.bar:SetPoint("TOPLEFT") r.bar:SetPoint("BOTTOMLEFT") r.bar:SetWidth(3)
  do local rr, g, b = F.color("accent") r.bar:SetColorTexture(rr, g, b, 1) end
  r.name = F.fs(r, "", 9, "ink")
  r.name:SetPoint("LEFT", 8, 0)
  r.count = F.fs(r, "", 8, "muted")
  r.count:SetPoint("RIGHT", -6, 0)
  r:SetScript("OnEnter", function(self) F.PaintRow(self, db, true) end)
  r:SetScript("OnLeave", function(self) F.PaintRow(self, db, false) end)
  r:SetScript("OnClick", function(self) if self.mob then F.SetActive(db, self.mob) end end)
  F.rows[i] = r
  return r
end

function F.PaintRow(r, db, hover)
  local active = r.mob and r.mob == db.active
  local rr, g, b
  if active then rr, g, b = F.color("accentSoft") r.bg:SetColorTexture(rr, g, b, 1)
  elseif hover then rr, g, b = F.color("sunken") r.bg:SetColorTexture(rr, g, b, 1)
  else rr, g, b = F.color("surface") r.bg:SetColorTexture(rr, g, b, 0) end
  if active then r.bar:Show() else r.bar:Hide() end
  rr, g, b = F.color(active and "accent" or "ink")
  r.name:SetTextColor(rr, g, b, 1)
end

-- what the body shows: the last kill, then the searched name if it is a different mob
function F.Entries(db)
  local out = {}
  if db.last then out[#out + 1] = db.last end
  if db.custom and not (db.last and db.last.name == db.custom) then
    out[#out + 1] = { name = db.custom, count = db.customKills or 0 }
  end
  -- then RestedXP's Active Targets, if it is installed (FarmGuide.lua), minus what is already here
  if F.Guide then
    local already = {}
    for _, e in ipairs(out) do already[e.name] = true end
    for _, e in ipairs(F.Guide.Entries(db, already)) do out[#out + 1] = e end
  end
  return out
end

function F.Refresh(db)
  if not F.frame then return end
  F.PaintSlots(db)
  local entries = db.collapsed and {} or F.Entries(db)
  local y = 0
  for i = 1, math.max(#entries, #F.rows) do
    local r = F.Row(i, db)
    local e = entries[i]
    if e then
      r.mob = e.name
      r.name:SetText(e.name)
      -- a guide row says where it came from, where a kill row says how many
      r.count:SetText(e.guide and T.text("muted", "RXP") or (e.count > 1 and ("x" .. e.count) or ""))
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", F.body, "TOPLEFT", 0, -y)
      r:SetPoint("TOPRIGHT", F.body, "TOPRIGHT", 0, -y)
      F.PaintRow(r, db, false)
      r:Show()
      y = y + F.ROW
    else
      r.mob = nil
      r:Hide()
    end
  end
  if db.collapsed then
    F.well:Hide()
  else
    F.well:Show()
    F.well:ClearAllPoints()
    F.well:SetPoint("TOPLEFT", F.body, "TOPLEFT", F.PAD, -(y + F.PAD))
    F.well:SetPoint("TOPRIGHT", F.body, "TOPRIGHT", -F.PAD, -(y + F.PAD))
    y = y + F.PAD + F.FIELD + F.PAD
  end
  F.body:SetHeight(math.max(y, 1))
  F.frame:SetHeight(F.HEADER + y)
end

-- typed name: remember it, farm it
function F.Search(db, name)
  if db.custom ~= name then db.customKills = 0 end
  db.custom = name
  if db.active ~= name then F.SetActive(db, name) else F.Refresh(db) end
end

-- ---------------------------------------------------------------- right-click a mob
-- Arn, 13 Oct 2026, right-clicking a Dalaran Summoner's portrait: track it "not just type their
-- name or wait till you kill one". The same road as the recap's "BiS: add rival" (Recap.lua,
-- read off Olympus, MIT): Menu.ModifyMenu("MENU_UNIT_" .. kind, fn) adds a line, nothing of the
-- game's is replaced. An NPC's portrait menu is TARGET (or FOCUS); a player's are the rival's
-- kinds, so the two never share a menu. Which tag Forever uses for an NPC: UNVERIFIED - if the
-- line never shows, that is the first thing to check.
F.MENUS = { "TARGET", "FOCUS" }

--- The mob a menu is about, or nil: a plain-no to "a player?", a plain-yes to "can I attack it?",
--- and a name the game will show. Anything hidden gets no line.
function F.MenuMob(ctx)
  if type(ctx) ~= "table" then return nil end
  local okU, u = pcall(function() return ctx.unit end)
  u = okU and F.Plain(u) or nil
  if type(u) ~= "string" then return nil end
  if F.Plain(UnitIsPlayer(u)) ~= false then return nil end
  if F.Plain(UnitCanAttack("player", u)) ~= true then return nil end
  return F.Name(u)
end

function F.MenuLines(db, root, ctx)
  if not (NS.Registry:Enabled("farm") and root and root.CreateButton) then return end
  -- never inside an instance: a line there taints the game's menu, whose frame rects are secret
  -- there, and Blizzard's layout breaks (Arn's BugGrabber in a battleground, 13 Oct - Recap.lua
  -- RC.MenuSafe has the whole story). The farm is an open-world tool anyway.
  local RC = NS.Recap
  if RC and RC.MenuSafe and not RC.MenuSafe() then return end
  local name = F.MenuMob(ctx)
  if not name then return end
  if RC and RC.Section then RC.Section(root) elseif root.CreateDivider then root:CreateDivider() end
  if db.active == name then
    root:CreateButton("Stop farming", function() F.Clear(db) end)
  else
    root:CreateButton("Track in farm", function()
      F.Search(db, name)                       -- what /bist farm add <name> does
      F.Toggle(db, true)
    end)
  end
end

function F.HookMenus(db)
  if F.menusHooked then return true end
  if not (Menu and type(Menu.ModifyMenu) == "function") then return false end
  for _, kind in ipairs(F.MENUS) do
    pcall(Menu.ModifyMenu, "MENU_UNIT_" .. kind, function(_, root, ctx) F.MenuLines(db, root, ctx) end)
  end
  F.menusHooked = true
  return true
end

function F.SetCollapsed(db, on)
  db.collapsed = on and true or false
  F.Refresh(db)
end

function F.Clear(db)
  F.placed = {}                      -- a fresh farm starts its marks at the skull again
  db.last = nil
  db.custom = nil
  db.customKills = 0
  F.SetActive(db, nil)
end

function F.Toggle(db, want)
  F.Build(db)
  if want == nil then want = not F.frame:IsShown() end
  db.shown = want and true or false
  if want then F.frame:Show() F.Refresh(db) else F.frame:Hide() end
end

-- ---------------------------------------------------------------- events
-- WHERE A KILL COMES FROM, PER CLIENT (6 Oct 2026). On WoW Forever, REGISTERING
-- COMBAT_LOG_EVENT_UNFILTERED is itself a protected action: Arn's BugGrabber, "AddOn 'BiSTools'
-- tried to call the protected function 'Frame:RegisterEvent()'", twice per login, from F.Hook. A
-- pcall cannot catch it - the refusal arrives later as an event - so the only fix is never to ask.
-- On a client that hides values (C_Secrets says so, the same test BiSHealing makes) the kill comes
-- from the plain PARTY_KILL event instead, the road Overlord Forever takes for the same reason.
function F.Restricted()
  local ok, v = pcall(function()
    return C_Secrets and C_Secrets.HasSecretRestrictions and C_Secrets.HasSecretRestrictions()
  end)
  if ok and type(v) == "boolean" and not (issecretvalue and issecretvalue(v)) then return v end
  return C_Secrets ~= nil and C_Secrets.HasSecretRestrictions ~= nil
end

local plain = F.Plain

-- The kill itself, whichever road it came by: a creature, by name, with its GUID.
function F.OnKill(db, dstName, dstGUID)
  -- whatever it was, it no longer wears the mark the farm key gave it: that mark is free again
  if type(dstGUID) == "string" then F.placed[dstGUID] = nil end
  -- locked on something? then only that mob counts; the page does not
  -- swap to whatever else you killed on the way
  if db.active and dstName ~= db.active then return end
  if db.active and db.custom == dstName and not (db.last and db.last.name == dstName) then
    db.customKills = (db.customKills or 0) + 1
  else
    F.Record(db, dstName, dstGUID)
  end
  if F.Spots then
    -- the mark it died wearing tells the spot apart better than where you stood
    local mark
    local tg = UnitExists("target") and plain(UnitGUID("target"))
    if tg and tg == dstGUID then mark = F.Mark("target") end
    F.Spots.Kill(db, dstName, mark)
  end
  F.Refresh(db)
end

-- PARTY_KILL arrives in one of two shapes, and Overlord handles both because nobody has written
-- down which this client uses: (attackerGUID, targetGUID), or the old (unitToken) of the victim.
-- Any argument may be a secret value, so each is asked about before anything reads it.
function F.FromPartyKill(db, a1, a2)
  local s1 = plain(a1)
  if type(s1) ~= "string" then return end
  local guid, name
  if s1:find("%-") then
    -- the GUID shape: only our own kills (or the pet's) count, as with the combat log
    if not F.OwnGUID(s1) then return end
    guid = plain(a2)
    if type(guid) ~= "string" or not guid:find("^Creature") then return end
    if UnitNameFromGUID then
      local ok, n = pcall(UnitNameFromGUID, guid)
      n = ok and plain(n) or nil
      -- "Unknown" is the client's placeholder for a name it has not resolved yet
      if type(n) == "string" and n ~= "" and n ~= (UNKNOWNOBJECT or "Unknown") then name = n end
    end
    if not name and UnitExists("target") and plain(UnitGUID("target")) == guid then
      name = plain(UnitName("target"))
    end
  else
    -- the unit-token shape: the victim is that unit; the killer is somebody in the group
    guid = plain(UnitGUID(s1))
    if type(guid) ~= "string" or not guid:find("^Creature") then return end
    name = plain(UnitName(s1))
  end
  if type(name) ~= "string" or name == "" then return end
  F.OnKill(db, name, guid)
end

function F.OnEvent(db, event, ...)
  if event == "PARTY_KILL" then
    F.FromPartyKill(db, ...)
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    local _, sub, _, srcGUID, _, _, _, dstGUID, dstName = CombatLogGetCurrentEventInfo()
    if sub == "PARTY_KILL" and F.OwnGUID(srcGUID) and dstName
      and dstGUID and dstGUID:find("^Creature") then
      F.OnKill(db, dstName, dstGUID)
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if F.keyDirty then F.ApplyKey(db) end
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    -- one scan per F.MOUSE_GAP at most (7 Oct 2026, the cost pass): sweeping the mouse across a
    -- pack fires this for every mob, and each scan reads every nameplate and the map
    local now = (GetTime and GetTime()) or 0
    if db.active and F.ticker and now - (F.mouseTickAt or -1) >= F.MOUSE_GAP then
      F.mouseTickAt = now
      F.Tick(db)
    end
  elseif event == "PLAYER_TARGET_CHANGED" then
    if db.active and F.Spots then F.Spots.Sync(db) end
  end
end

function F.Hook(db)
  if F.Restricted() then
    -- never even ask for the combat log here; an unknown event name would throw, so it is pcalled
    pcall(F.events.RegisterEvent, F.events, "PARTY_KILL")
  else
    F.events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  end
  F.events:RegisterEvent("PLAYER_REGEN_ENABLED")
  F.events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
  F.events:RegisterEvent("PLAYER_TARGET_CHANGED")
  F.ApplyKey(db)
  if db.shown then F.Toggle(db, true) end
  if db.active then F.Start(db) end
end

NS.Registry:Register({
  name = "farm",
  desc = "click a kill; skull auto-follows a free copy nearby",
  usage = "/bist farm [clear | add <name> | key <KEY>|none | sound first|always|off | spots [clear] | pins on|off|why | arrow on|off | guide on|off | radius <yd> | burst <sec> | prune <sec>|off]",
  -- shown = false since 1.0: a new install's farm window waits for a click in the Hub (it opened at every login;
  -- an existing save keeps its own value - Registry R:Forever10 froze it)
  defaults = { last = nil, custom = nil, shown = false, collapsed = false, pos = { "CENTER", 300, 0 },
    active = nil, interval = 0.5, key = nil, sound = "off", finds = 0 },
  quiet = { shown = false },
  OnInit = function(self, db)
    -- ONCE: the old default "first" was written into every saved table, so a new default alone changes nobody.
    -- "first" becomes "off"; "always" (somebody chose it) stays. Back on: /bist farm sound first
    if not db.soundOff1 then
      if db.sound == "first" then db.sound = "off" end
      db.soundOff1 = true
    end
    F.db = db
    F.events = CreateFrame("Frame")
    F.events:SetScript("OnEvent", function(_, ev, ...) F.OnEvent(db, ev, ...) end)
  end,
  OnLogin = function(self, db) F.Hook(db) F.HookMenus(db) end,
  -- the Hub: open the window; recenter drags it to the middle (Arn: "no idea
  -- where the farm window is at")
  IsOpen = function(self, db) return F.frame ~= nil and F.frame:IsShown() end,
  OnClose = function(self, db) F.Toggle(db, false) end,
  OnOpen = function(self, db, recenter)
    F.Toggle(db, true)
    if recenter and F.frame then
      db.pos = { "CENTER", 0, 0, "CENTER" }
      db.collapsed = false
      F.frame:ClearAllPoints() F.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
      if F.frame.Raise then F.frame:Raise() end
      F.Refresh(db)
    end
  end,
  options = {
    -- the crosshair on the mob you farm (green) and on RestedXP's targets (blue) - drawn by the recap
    -- tool's nameplate marks, in the style picked there (Arn, 12 Oct)
    { kind = "toggle", label = "crosshair on the mob", help = "A green crosshair on fresh copies of the mob you farm, and blue on RestedXP's targets, in the crosshair style picked under recap.", get = function(db) return db.cross ~= false end,
      set = function(db, on)
        db.cross = on and true or false
        if not on and NS.Recap then NS.Recap.ClearKind("farm") NS.Recap.ClearKind("guide") end
      end },
    { kind = "seg", label = "find sound", help = "The sound when a fresh copy of your mob turns up: first - only the first after a quiet spell; always - every time; off - silent.", values = F.SOUND_MODES,
      get = function(db) return db.sound or "off" end, set = function(db, v) F.SetSound(db, v) end },
    { kind = "step", label = "spot radius", help = "How close two kills must be to count as the same spawn spot. Bigger joins nearby spawns into one timer; smaller splits them.", min = 5, max = 60, step = 5, unit = "yd",
      get = function(db) return F.Spots and F.Spots.Radius(db) or 20 end,
      set = function(db, v) if F.Spots then F.Spots.SetRadius(db, v) end end,
      show = function(db) return (F.Spots and F.Spots.Radius(db) or 20) .. " yd" end },
    { kind = "step", label = "burst window", help = "A kill this soon after a spot's last kill is ANOTHER mob standing there (a multi-pull), so it gets its own spot and timer.", min = 5, max = 300, step = 5,
      get = function(db) return F.Spots and F.Spots.Burst(db) or 60 end,
      set = function(db, v) if F.Spots then F.Spots.SetBurst(db, v) end end,
      show = function(db) return (F.Spots and F.Spots.Burst(db) or 60) .. " s" end },
    { kind = "step", label = "prune after", help = "A spot that has sat 'up' this long with no kill folds into its nearest neighbour - usually a duplicate spawn point. Off keeps them all.", min = 0, max = 3600, step = 60,
      get = function(db) return F.Spots and F.Spots.Prune(db) or 600 end,
      set = function(db, v) if F.Spots then F.Spots.SetPrune(db, v) end end,
      show = function(db) local p = F.Spots and F.Spots.Prune(db) or 600 return p == 0 and "off" or (p .. " s") end },
  },
  OnEnable = function(self, db) F.Hook(db) end,
  OnDisable = function(self, db)
    F.events:UnregisterAllEvents()
    if F.Spots then F.Spots.Hide() end
    if F.Pins then F.Pins.Stop() end
    if F.Arrow then F.Arrow.Hide() end
    F.Stop()
    if F.tbtn and not InCombatLockdown() then ClearOverrideBindings(F.tbtn) end
    if F.frame then F.frame:Hide() end
  end,
  OnSlash = function(self, db, args)
    local cmd, rest = args:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "clear" then return F.Clear(db) end
    if cmd == "spots" and F.Spots then
      if rest:lower() == "clear" then return F.Spots.Clear(db) end
      return F.Spots.Toggle(db)
    end
    if cmd == "pins" and F.Pins then
      local r = rest:lower()
      if r == "why" then return F.Pins.Why(db) end
      local on = F.Pins.Set(db, (r == "on" and true) or (r == "off" and false) or nil)
      return NS.Print("map pins %s", on and T.text("accent", "on") or "off")
    end
    if cmd == "guide" and F.Guide then
      local r = rest:lower()
      local on = F.Guide.Set(db, (r == "on" and true) or (r == "off" and false) or nil)
      return NS.Print("RestedXP targets %s%s", on and T.text("accent", "on") or "off",
        F.Guide.hooked and "" or " (RestedXP not found)")
    end
    if cmd == "arrow" and F.Arrow then
      local r = rest:lower()
      local on = F.Arrow.Set(db, (r == "on" and true) or (r == "off" and false) or nil)
      return NS.Print("spawn arrow %s", on and T.text("accent", "on") or "off")
    end
    if cmd == "burst" and F.Spots then
      if rest ~= "" then F.Spots.SetBurst(db, rest) end
      return NS.Print("burst window: %s s (%d-%d) - kills closer than this at one spot are different mobs",
        T.text("accent", F.Spots.Burst(db)), F.Spots.B_MIN, F.Spots.B_MAX)
    end
    if cmd == "prune" and F.Spots then
      if rest ~= "" then F.Spots.SetPrune(db, rest) end
      local p = F.Spots.Prune(db)
      return NS.Print("prune: %s - a spot sat up this long with no kill folds into its neighbour",
        p == 0 and T.text("warn", "off") or T.text("accent", p .. " s"))
    end
    if cmd == "radius" and F.Spots then
      local r = rest ~= "" and F.Spots.SetRadius(db, rest)
      return NS.Print("spot radius: %s yd (%d-%d)", T.text("accent", F.Spots.Radius(db)), F.Spots.R_MIN, F.Spots.R_MAX)
    end
    if cmd == "sound" then
      if rest ~= "" and not F.SetSound(db, rest:lower()) then
        return NS.Print("sound first | always | off")
      end
      return NS.Print("sound: %s", T.text("accent", db.sound or "off"))
    end
    if cmd == "add" and rest ~= "" then F.Toggle(db, true) return F.Search(db, rest) end
    if cmd == "key" then
      if rest == "" then return NS.Print("target key: %s", db.key or "none") end
      db.key = rest:lower() ~= "none" and rest:upper() or nil
      F.ApplyKey(db)
      return NS.Print("target key %s", db.key and T.text("accent", db.key) or "cleared")
    end
    F.Toggle(db)
  end,
})
NS.Farm = F
