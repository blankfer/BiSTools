-- BiSTools / Tools / Alts.lua - MAIN & ALTS (14 Nov 2026), `/bist alts`.
--
-- Arn, 14 Nov 2026: "make chainheal ryangosling my main character and all interface changes propagate to all the other
-- characters like the name plates and all that on top of the keybinds" - then the shape: "an interface in the addon /
-- Select main / Select alt mains don't override / Select what main sends to alts that allow override". Of three
-- sketches (https://claude.ai/artifact/RBL13YL8ENtUdAsQdgiycU) he picked A: one list, a tag per character, the switches
-- on the right.
--
-- THE WINDOW ONLY PICKS. The game cannot write another character's files, so the copying is done on Arn's PC by the
-- companion (`_bisdev/forever/main-sync.ps1`, in the "BiS aura sync" task) while WoW is closed. This file's whole
-- contract with it is the second SavedVariable, `BiSToolsAlts` (account-wide, its own block in BiSTools.lua so the
-- companion rewrites that block and nothing else):
--   v = 1, stamp = GetServerTime() when the picks last changed, main = whole name ("Name Surname" on Forever),
--   keep = { [name] = true } (KEEP MINE: never touched), sends = { settings, editmode, chat, spots, addons = bool },
--   roster = { [name] = { class, level, seen } } (each character signs itself in at login),
--   copied = { at, to, names } (written by the companion after a copy).
--   EACH PICK BY ITS OWN TIME (14 Nov, the first live run: a click on an account that had not seen the main yet wiped
--   him): mainAt (the main set or cleared), keepAt = { [name] = time } (KEEP MINE on or off), sendsAt (a switch).
--   The companion merges by these, one pick at a time; `stamp` stays as the newest of them.
-- Everyone in the roster who is not the main and not kept GETS COPIES. The companion merges both accounts' blocks
-- (newest picks, every character), so after WoW has been closed once each account's window lists every character.
--
-- WHAT IT COSTS: one small write at login (and on a level up). No ticker, no event while the window is shut.
local _, NS = ...
local R = NS.Registry
local A = {}
NS.Alts = A

A.W, A.H = 640, 448            -- 1.43:1, the family's window shape
A.ROW, A.ROWS = 26, 13
A.LIST_W = 400
A.SENDS = {
  { key = "settings", label = "Nameplates & game settings", sub = "plates, soft target, bars" },
  { key = "editmode", label = "Edit Mode layout",           sub = "this character's own" },
  { key = "chat",     label = "Chat windows",               sub = "tabs and channels" },
  { key = "spots",    label = "Addon window spots",         sub = "where addon frames sit" },
  { key = "addons",   label = "Addons switched on",         sub = "the AddOns list" },
}
A.DEFAULT_SENDS = { settings = true, editmode = true, chat = true, spots = true, addons = false }
A.ROLE_WORD = { main = "MAIN", keep = "KEEP MINE", gets = "GETS COPIES" }
A.ROLE_COLOR = { main = "accent", keep = "good", gets = "muted" }
-- the click order: GETS COPIES -> KEEP MINE -> MAIN -> GETS COPIES. MAIN comes LAST, so marking an alt main never
-- passes through MAIN (which would take the main away from your real one on the way)
A.NEXT_ROLE = { gets = "keep", keep = "main", main = "gets" }
A.offset = 0
A.SEEN_EVERY = 86400           -- a character's "seen" time is written once a day at most (A.SignIn)

local function F() return NS.Farm end
local function plain(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end
local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, ...)
  if not ok then return nil end
  return plain(a), plain(b)
end
local function now()
  return ask(rawget(_G, "GetServerTime")) or ask(rawget(_G, "time")) or 0
end

--- The save, made whole: every key there, whatever an older (or empty) block held.
function A.Data()
  local d = rawget(_G, "BiSToolsAlts")
  if type(d) ~= "table" then d = {} _G.BiSToolsAlts = d end
  d.v = 1
  if type(d.keep) ~= "table" then d.keep = {} end
  if type(d.roster) ~= "table" then d.roster = {} end
  if type(d.sends) ~= "table" then d.sends = {} end
  if type(d.keepAt) ~= "table" then d.keepAt = {} end
  for k, v in pairs(A.DEFAULT_SENDS) do if d.sends[k] == nil then d.sends[k] = v end end
  if type(d.main) ~= "string" then d.main = nil end
  return d
end

--- This character's whole name ("Chainheal Ryangosling" - UnitName is the first name only on Forever).
function A.Me()
  local name = ask(rawget(_G, "GetUnitName"), "player", false) or ask(rawget(_G, "UnitName"), "player")
  return type(name) == "string" and name ~= "" and name or nil
end

--- THE ROSTER: this character signs itself in (class, level, when). Always, the tool on or off - it is one line in the
--- save, and a list that only fills while a switch is on would miss the alts logged in before it was turned on.
function A.SignIn()
  local me = A.Me()
  if not me then return nil end
  local d = A.Data()
  local _, class = ask(rawget(_G, "UnitClass"), "player")
  local e = d.roster[me] or {}
  local level = ask(rawget(_G, "UnitLevel"), "player") or e.level
  class = type(class) == "string" and class or e.class
  -- QUIET UNLESS SOMETHING CHANGED (the companion rewrites the block, with a backup, whenever its content differs): the
  -- time is written for a new character, a new level or class, and otherwise once a day at most
  local t = now()
  if not e.seen or e.level ~= level or e.class ~= class or t - (tonumber(e.seen) or 0) >= A.SEEN_EVERY then e.seen = t end
  e.class, e.level = class, level
  d.roster[me] = e
  return me
end

function A.Role(name, d)
  d = d or A.Data()
  if d.main and name == d.main then return "main" end
  if d.keep[name] then return "keep" end
  return "gets"
end

--- Give a character a role. One main only: a new main turns the old one into GETS COPIES. Every pick is stamped, so the
--- companion knows which account's picks are newest.
function A.SetRole(name, role, d)
  d = d or A.Data()
  if not (name and A.ROLE_WORD[role]) then return nil end
  local t = now()
  local wasMain, wasKeep = d.main, d.keep[name] and true or false
  if role == "main" then
    d.main = name
    d.keep[name] = nil
  elseif role == "keep" then
    if d.main == name then d.main = nil end
    d.keep[name] = true
  else
    if d.main == name then d.main = nil end
    d.keep[name] = nil
  end
  if d.main ~= wasMain then d.mainAt = t end
  if (d.keep[name] and true or false) ~= wasKeep then d.keepAt[name] = t end
  d.stamp = t
  return role
end

function A.Cycle(name)
  return A.SetRole(name, A.NEXT_ROLE[A.Role(name)])
end

function A.SetSend(key, on)
  local d = A.Data()
  if A.DEFAULT_SENDS[key] == nil then return nil end
  d.sends[key] = on and true or false
  d.stamp = now()
  d.sendsAt = d.stamp
  return d.sends[key]
end

--- The list, in order: the main first, then KEEP MINE, then the rest; highest level first within each, then by name.
function A.List(d)
  d = d or A.Data()
  local out = {}
  for name, e in pairs(d.roster) do
    if type(name) == "string" and type(e) == "table" then
      out[#out + 1] = { name = name, class = e.class, level = tonumber(e.level) or 0, role = A.Role(name, d) }
    end
  end
  local rank = { main = 1, keep = 2, gets = 3 }
  table.sort(out, function(a, b)
    if rank[a.role] ~= rank[b.role] then return rank[a.role] < rank[b.role] end
    if a.level ~= b.level then return a.level > b.level end
    return a.name < b.name
  end)
  return out
end

--- The foot's words: the last copy, or what happens next.
function A.Status(d)
  d = d or A.Data()
  if not d.main then return "Pick your main: click its tag until it says MAIN." end
  local c = d.copied
  local gets = 0
  for _, e in ipairs(A.List(d)) do if e.role == "gets" then gets = gets + 1 end end
  local when = ""
  if type(c) == "table" and tonumber(c.at) then
    local df = rawget(_G, "date")
    when = ("   last copy: %s, to %d"):format(df and df("%d %b %H:%M", c.at) or tostring(c.at), tonumber(c.to) or 0)
  end
  return ("Copies to %d character%s when WoW closes.%s"):format(gets, gets == 1 and "" or "s", when)
end

local function classColor(class)
  local c = class and rawget(_G, "RAID_CLASS_COLORS") and RAID_CLASS_COLORS[class]
  if c and c.r then return c.r, c.g, c.b end
  return F().color("ink")
end

-- ------------------------------------------------------------------ the window

local function glowRow(parent, w, h)
  local K = F()
  local r = CreateFrame("Button", nil, parent)
  r:SetSize(w, h)
  -- ROWS GLOW ON HOVER (the family's rule, asked three times): a wash and a bar on the left
  r.lit = K.tex(r, "BACKGROUND", "accent", 0)
  r.bar = r:CreateTexture(nil, "ARTWORK")
  r.bar:SetPoint("TOPLEFT")
  r.bar:SetPoint("BOTTOMLEFT")
  r.bar:SetWidth(2)
  do local rr, g, b = K.color("accent") r.bar:SetColorTexture(rr, g, b, 1) end
  r.bar:SetAlpha(0)
  r:SetScript("OnEnter", function(self) self.lit:SetAlpha(0.14) self.bar:SetAlpha(1) end)
  r:SetScript("OnLeave", function(self) self.lit:SetAlpha(0) self.bar:SetAlpha(0) end)
  return r
end

function A.Build()
  if A.frame then return A.frame end
  local K = F()
  local f = CreateFrame("Frame", "BiSToolsAltsWindow", UIParent)   -- (never "BiSToolsAlts": that is the save)
  f:SetSize(A.W, A.H)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetScript("OnHide", f.StopMovingOrSizing)           -- a drag still on ends with the window (8 Nov rule)
  K.tex(f, "BACKGROUND", "frame", 0.96)
  K.border(f, "edge", 1)
  -- the title bar: an accent tick, BiS> MAIN & ALTS, the close box
  local tick = f:CreateTexture(nil, "ARTWORK")
  tick:SetSize(3, 14)
  tick:SetPoint("TOPLEFT", 10, -9)
  do local rr, g, b = K.color("accent") tick:SetColorTexture(rr, g, b, 1) end
  f.title = K.fs(f, "BiS> MAIN & ALTS", 11, "accent")
  f.title:SetPoint("LEFT", tick, "RIGHT", 8, 0)
  f.close = CreateFrame("Button", nil, f)
  f.close:SetSize(18, 18)
  f.close:SetPoint("TOPRIGHT", -6, -6)
  f.close.edge = K.border(f.close, "edge", 1)
  f.close.label = K.fs(f.close, "x", 10, "muted")
  f.close.label:SetPoint("CENTER")
  f.close:SetScript("OnClick", function() A.Toggle(false) end)
  f.close:SetScript("OnEnter", function(self) self.edge:set("accent", 1) end)
  f.close:SetScript("OnLeave", function(self) self.edge:set("edge", 1) end)
  local hair = f:CreateTexture(nil, "ARTWORK")
  hair:SetPoint("TOPLEFT", 1, -30)
  hair:SetPoint("TOPRIGHT", -1, -30)
  hair:SetHeight(1)
  do local rr, g, b = K.color("hair") hair:SetColorTexture(rr, g, b, 1) end
  -- left: the characters
  f.listLabel = K.fs(f, "CHARACTERS  -  CLICK THE TAG", 9, "accent")
  f.listLabel:SetPoint("TOPLEFT", 16, -40)
  f.rows = {}
  for i = 1, A.ROWS do
    local r = glowRow(f, A.LIST_W - 16, A.ROW)
    r:SetPoint("TOPLEFT", 10, -54 - (i - 1) * A.ROW)
    r.name = K.fs(r, "", 11, "ink")
    r.name:SetJustifyH("LEFT")
    r.name:SetPoint("LEFT", 8, 0)
    r.name:SetWidth(A.LIST_W - 16 - 8 - 150)
    r.level = K.fs(r, "", 10, "muted")
    r.level:SetJustifyH("RIGHT")
    r.level:SetWidth(30)
    r.level:SetPoint("RIGHT", -110, 0)
    r.chip = CreateFrame("Frame", nil, r)
    r.chip:SetSize(96, 18)
    r.chip:SetPoint("RIGHT", -6, 0)
    r.chip.fill = K.tex(r.chip, "BACKGROUND", "accent", 0)
    r.chip.edge = K.border(r.chip, "muted", 1)
    r.chip.word = K.fs(r.chip, "", 9, "muted")
    r.chip.word:SetPoint("CENTER")
    r:RegisterForClicks("AnyUp")
    r:SetScript("OnClick", function(self) if self.entry then A.Cycle(self.entry.name) A.Paint() end end)
    f.rows[i] = r
  end
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function(_, delta)
    local n = #A.List()
    A.offset = math.max(0, math.min(math.max(0, n - A.ROWS), A.offset - delta * 3))
    A.Paint()
  end)
  local split = f:CreateTexture(nil, "ARTWORK")
  split:SetPoint("TOPLEFT", A.LIST_W, -31)
  split:SetPoint("BOTTOMLEFT", A.LIST_W, 31)
  split:SetWidth(1)
  do local rr, g, b = K.color("hair") split:SetColorTexture(rr, g, b, 1) end
  -- right: what the main sends
  f.sendLabel = K.fs(f, "MAIN SENDS", 9, "accent")
  f.sendLabel:SetPoint("TOPLEFT", A.LIST_W + 16, -40)
  f.sends = {}
  for i, s in ipairs(A.SENDS) do
    local r = glowRow(f, A.W - A.LIST_W - 20, 36)
    r:SetPoint("TOPLEFT", A.LIST_W + 10, -54 - (i - 1) * 38)
    r.key = s.key
    r.tog = CreateFrame("Frame", nil, r)
    r.tog:SetSize(30, 14)
    r.tog:SetPoint("LEFT", 8, 0)
    K.tex(r.tog, "BACKGROUND", "field", 1)
    r.tog.edge = K.border(r.tog, "edge", 1)
    r.tog.knob = r.tog:CreateTexture(nil, "ARTWORK")
    r.tog.knob:SetSize(10, 8)
    r.label = K.fs(r, s.label, 11, "ink")
    r.label:SetPoint("TOPLEFT", 48, -5)
    r.sub = K.fs(r, s.sub, 9, "dim")
    r.sub:SetPoint("TOPLEFT", 48, -20)
    r:SetScript("OnClick", function(self) A.SetSend(self.key, not A.Data().sends[self.key]) A.Paint() end)
    f.sends[i] = r
  end
  f.already = K.fs(f, "Keybinds and macros already match on both accounts.", 9, "dim")
  f.already:SetPoint("TOPLEFT", A.LIST_W + 18, -54 - #A.SENDS * 38 - 8)
  f.already:SetWidth(A.W - A.LIST_W - 30)
  f.already:SetJustifyH("LEFT")
  f.join = K.fs(f, "A character joins the list the first time you log it in.", 9, "dim")
  f.join:SetPoint("TOPLEFT", f.already, "BOTTOMLEFT", 0, -6)
  f.join:SetWidth(A.W - A.LIST_W - 30)
  f.join:SetJustifyH("LEFT")
  -- the foot
  local hair2 = f:CreateTexture(nil, "ARTWORK")
  hair2:SetPoint("BOTTOMLEFT", 1, 30)
  hair2:SetPoint("BOTTOMRIGHT", -1, 30)
  hair2:SetHeight(1)
  do local rr, g, b = K.color("hair") hair2:SetColorTexture(rr, g, b, 1) end
  f.dot = f:CreateTexture(nil, "ARTWORK")
  f.dot:SetSize(7, 7)
  f.dot:SetPoint("BOTTOMLEFT", 14, 12)
  f.status = K.fs(f, "", 10, "muted")
  f.status:SetPoint("LEFT", f.dot, "RIGHT", 8, 0)
  f.status:SetJustifyH("LEFT")
  f.status:SetWidth(A.W - 40)
  f:Hide()
  if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "BiSToolsAltsWindow") end   -- Escape closes it
  A.frame = f
  return f
end

function A.Paint()
  local f = A.frame
  if not (f and f:IsShown()) then return end
  local K = F()
  local d = A.Data()
  local list = A.List(d)
  for i, r in ipairs(f.rows) do
    local e = list[A.offset + i]
    r.entry = e
    if e then
      r.name:SetText(e.name)
      r.name:SetTextColor(classColor(e.class))
      r.level:SetText(e.level > 0 and tostring(e.level) or "")
      local c = A.ROLE_COLOR[e.role]
      r.chip.word:SetText(A.ROLE_WORD[e.role])
      do local rr, g, b = K.color(c) r.chip.word:SetTextColor(rr, g, b, 1) end
      r.chip.edge:set(e.role == "gets" and "edge" or c, 1)
      r.chip.fill:SetAlpha(e.role == "main" and 0.16 or 0)
      r:Show()
    else
      r:Hide()
    end
  end
  for _, r in ipairs(f.sends) do
    local on = d.sends[r.key] == true
    r.on = on
    r.tog.knob:ClearAllPoints()
    r.tog.knob:SetPoint(on and "RIGHT" or "LEFT", on and -2 or 2, 0)
    local rr, g, b = K.color(on and "accent" or "dim")
    r.tog.knob:SetColorTexture(rr, g, b, 1)
    r.tog.edge:set(on and "accent" or "edge", 1)
  end
  f.status:SetText(A.Status(d))
  do local rr, g, b = K.color(d.main and "good" or "gold") f.dot:SetColorTexture(rr, g, b, 1) end
end

function A.IsOpen() return A.frame ~= nil and A.frame:IsShown() end

function A.Toggle(want)
  local f = A.Build()
  if want == nil then want = not f:IsShown() end
  if want then A.SignIn() f:Show() A.Paint() else f:Hide() end
  return f:IsShown()
end

-- the sign-in: at login and on a level up, whatever the switch says (A.SignIn's note)
do
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_LOGIN")
  ev:RegisterEvent("PLAYER_LEVEL_UP")
  ev:SetScript("OnEvent", function() A.SignIn() if A.IsOpen() then A.Paint() end end)
  A.events = ev
end

R:Register({
  name = "alts",
  desc = "pick your main; when WoW closes your alts take its nameplates, layout and chat",
  usage = "/bist alts",
  slashWhenOff = true,
  defaultOff = true,          -- new after 1.0: an existing save starts it off too (the codex rule)
  defaults = {},
  options = {
    { kind = "button", label = "main & alts", button = "open",
      help = "Pick your main and the alts that keep their own setup. Everyone else takes the main's nameplates, Edit Mode layout, chat windows and addon window spots - copied on your PC by the BiS companion when WoW closes.",
      action = function() A.Toggle(true) end },
  },
  OnOpen = function(_, _, recenter)
    if recenter then
      if A.frame then A.frame:ClearAllPoints() A.frame:SetPoint("CENTER") end
      return
    end
    A.Toggle(true)
  end,
  IsOpen = function() return A.IsOpen() end,
  OnClose = function() A.Toggle(false) end,
  OnDisable = function() if A.frame then A.frame:Hide() end end,
  OnSlash = function()
    if not R:Enabled("alts") then R:SetEnabled("alts", true) end
    A.Toggle()
  end,
})
