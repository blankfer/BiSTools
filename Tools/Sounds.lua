-- BiSTools / Tools / Sounds.lua - THE SOUND EXPLORER (5 Nov 2026), `/bist sounds`.
--
-- Arn, 5 Nov: "i want a sound explorer for wow sounds where i can play the sound i uploaded and then i click on a in
-- game sound to see if they sound similar" - then: "put the sound thing in bis tools not bishealing if its good we
-- keep it in there for peoplke to use as a tool".
--
-- Every sound the game names (its own SOUNDKIT table: NAME = kit id, one row per id), searchable by word or id, a box
-- for any kit id it does not name, and a box for YOUR OWN .ogg anywhere under Interface\AddOns - an addon's own sound
-- file plays on Forever (heard 23 Oct); only the game's file paths are silent. Click a row: hear it. Shift-click: a
-- star (kept); `/bist sounds favs` prints the stars with their ids. Everything plays on the effects channel.
--
-- WHAT IT COSTS: nothing until it is opened - no event, no ticker. The list is read from SOUNDKIT once, on first open.
local _, NS = ...
local R = NS.Registry
local X = {}
NS.Sounds = X

X.W, X.H = 430, 300          -- 1.43:1, the family's window shape
X.ROWS, X.ROW = 10, 18
X.FILES_MAX = 6              -- remembered paths of your own files
X.offset, X.filter = 0, ""

-- a few kits worth hearing that SOUNDKIT may not name (heard on Forever: 839, 3081, 8959)
X.EXTRA = {
  { name = "(options tick)", id = 856 }, { name = "(options untick)", id = 857 },
  { name = "(whisper bell)", id = 3081 }, { name = "(raid warning)", id = 8959 }, { name = "(heard 839)", id = 839 },
}

local function F() return NS.Farm end

--- Every named sound: { name, id }, by name, read once from the game's own SOUNDKIT table.
function X.All()
  if X.all then return X.all end
  local out, seen = {}, {}
  local kits = rawget(_G, "SOUNDKIT")
  if type(kits) == "table" then
    for name, id in pairs(kits) do
      if type(name) == "string" and type(id) == "number" and not seen[id] then
        seen[id] = true
        out[#out + 1] = { name = name, id = id }
      end
    end
  end
  for _, e in ipairs(X.EXTRA) do
    if not seen[e.id] then seen[e.id] = true out[#out + 1] = { name = e.name, id = e.id } end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  X.all = out
  return out
end

--- What the list shows now: your files first, a typed id, then the kits the search (or "stars only") leaves.
function X.Shown(db)
  db = db or X.db or {}
  local want = tostring(X.filter or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  local out = {}
  for _, p in ipairs(db.files or {}) do out[#out + 1] = { name = p, file = p } end
  if X.typed then out[#out + 1] = { name = "typed id", id = X.typed, typed = true } end
  local favs = db.favs or {}
  for _, e in ipairs(X.All()) do
    local fits = want == "" or e.name:lower():find(want, 1, true) or tostring(e.id) == want
    if fits and (not db.starsOnly or favs[e.id]) then out[#out + 1] = e end
  end
  return out
end

--- The game's file path for something typed: "BiSHealing\Media\click.ogg" -> Interface\AddOns\BiSHealing\Media\click.ogg
function X.Path(typed)
  local p = tostring(typed or ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("/", "\\")
  if p == "" then return nil end
  if not p:lower():find("^interface\\") then p = "Interface\\AddOns\\" .. p end
  return p
end

--- Hear a row (or a kit id): a kit through PlaySound, a file through PlaySoundFile; the effects channel.
function X.Play(e)
  if type(e) == "number" then e = { id = e } end
  if type(e) ~= "table" then return false end
  local ok, will
  if e.file then
    if not PlaySoundFile then return false end
    ok, will = pcall(PlaySoundFile, X.Path(e.file), "SFX")
    if not (ok and will) then
      NS.Print("sounds: %s did not play - is it under Interface\\AddOns, and was the game restarted since the file was put there?", tostring(e.file))
      return false
    end
  else
    if not (PlaySound and type(e.id) == "number") then return false end
    ok, will = pcall(PlaySound, e.id, "SFX")
  end
  X.last = e.file or e.id
  return ok and will ~= false
end

--- Remember a typed path at the top of the list (newest first, at most X.FILES_MAX).
function X.AddFile(db, typed)
  local p = tostring(typed or ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("/", "\\")
  if p == "" then return nil end
  db.files = db.files or {}
  for i = #db.files, 1, -1 do if db.files[i]:lower() == p:lower() then table.remove(db.files, i) end end
  table.insert(db.files, 1, p)
  while #db.files > X.FILES_MAX do table.remove(db.files) end
  return p
end

--- Star a kit (kept), or forget a remembered file.
function X.Star(db, e)
  if not e then return false end
  if e.file then
    for i = #(db.files or {}), 1, -1 do if db.files[i] == e.file then table.remove(db.files, i) end end
    NS.Print("sounds: forgot %s", e.file)
    return false
  end
  db.favs = db.favs or {}
  if db.favs[e.id] then
    db.favs[e.id] = nil
    NS.Print("sounds: unstarred %s (%d)", tostring(e.name), e.id)
    return false
  end
  db.favs[e.id] = e.typed and ("id " .. e.id) or e.name
  NS.Print("sounds: |cffffd100*|r %s (|cff4fd0cf%d|r) - /bist sounds favs lists your stars", tostring(e.name), e.id)
  return true
end

--- The stars, for chat: "NAME 1234", by name.
function X.Favs(db)
  local out = {}
  for id, name in pairs(db.favs or {}) do out[#out + 1] = { id = id, name = tostring(name) } end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

function X.ClickRow(r)
  local e = r and r.entry
  if not e then return end
  if IsShiftKeyDown and IsShiftKeyDown() then X.Star(X.db, e) else X.Play(e) end
  X.Paint()
end

-- ------------------------------------------------------------------ the window

local function button(parent, label, w, onclick)
  local K = F()
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, 18)
  K.tex(b, "BACKGROUND", "field", 0.9)
  b.edge = K.border(b, "edge", 1)
  b.label = K.fs(b, label, 9, "ink")
  b.label:SetPoint("CENTER")
  b:SetScript("OnClick", function(self) onclick(self) end)
  b:SetScript("OnEnter", function(self) self.edge:set("accent", 1) end)
  b:SetScript("OnLeave", function(self) self.edge:set("edge", 1) end)
  return b
end

local function field(parent, name, w, hint)
  local K = F()
  local well = CreateFrame("Frame", nil, parent)
  well:SetSize(w, 18)
  K.tex(well, "BACKGROUND", "field", 0.9)
  well.edge = K.border(well, "edge", 1)
  local eb = CreateFrame("EditBox", name, well)
  eb:SetAllPoints()
  eb:SetTextInsets(4, 4, 0, 0)
  eb:SetFont(STANDARD_TEXT_FONT, 9, "")
  eb:SetAutoFocus(false)
  eb:SetMaxLetters(120)
  do local r, g, b = K.color("ink") eb:SetTextColor(r, g, b, 1) end
  local ph = K.fs(well, hint, 9, "dim")
  ph:SetPoint("LEFT", 4, 0)
  eb:SetScript("OnEditFocusGained", function() ph:Hide() well.edge:set("accent", 1) end)
  eb:SetScript("OnEditFocusLost", function(self)
    if (self:GetText() or "") == "" then ph:Show() end
    well.edge:set("edge", 1)
  end)
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  well.box, well.hint = eb, ph
  return well
end

function X.Build(db)
  if X.frame then return X.frame end
  local K = F()
  local f = CreateFrame("Frame", "BiSToolsSounds", UIParent)
  f:SetSize(X.W, X.H)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  K.tex(f, "BACKGROUND", "frame", 0.95)
  K.border(f, "edge", 1)
  f.title = K.fs(f, "BiS> sounds", 10, "accent")
  f.title:SetPoint("TOPLEFT", 8, -6)
  f.close = button(f, "x", 16, function() X.Toggle(false) end)
  f.close:SetPoint("TOPRIGHT", -4, -4)
  -- line 1: search, stars only, a kit id
  f.find = field(f, "BiSToolsSoundsFind", 170, "search: bell, click, chime...")
  f.find:SetPoint("TOPLEFT", 8, -24)
  f.find.box:SetScript("OnTextChanged", function(self) X.filter = self:GetText() or "" X.offset = 0 X.Paint() end)
  f.stars = button(f, "stars only", 64, function() X.db.starsOnly = not X.db.starsOnly X.offset = 0 X.Paint() end)
  f.stars:SetPoint("LEFT", f.find, "RIGHT", 6, 0)
  f.id = field(f, "BiSToolsSoundsId", 70, "kit id")
  f.id:SetPoint("TOPRIGHT", -8, -24)
  f.id.box:SetScript("OnEnterPressed", function(self)
    local n = tonumber(self:GetText() or "")
    X.typed, X.offset = n, 0
    if n then X.Play(n) end
    self:ClearFocus()
    X.Paint()
  end)
  -- line 2: your own file
  f.file = field(f, "BiSToolsSoundsFile", X.W - 16 - 56, "your .ogg, in AddOns: BiSHealing\\Media\\click.ogg")
  f.file:SetPoint("TOPLEFT", 8, -46)
  local function playFile()
    local p = X.AddFile(X.db, f.file.box:GetText())
    if p then X.Play({ file = p }) end
    f.file.box:SetText("")
    f.file.box:ClearFocus()
    X.offset = 0
    X.Paint()
  end
  f.file.box:SetScript("OnEnterPressed", playFile)
  f.play = button(f, "play", 50, playFile)
  f.play:SetPoint("TOPRIGHT", -8, -46)
  -- the list
  f.rows = {}
  for i = 1, X.ROWS do
    local r = CreateFrame("Button", nil, f)
    r:SetSize(X.W - 16, X.ROW)
    r:SetPoint("TOPLEFT", 8, -70 - (i - 1) * X.ROW)
    r.lit = K.tex(r, "BACKGROUND", "surface", 0)
    r.star = K.fs(r, "", 9, "gold")
    r.star:SetPoint("LEFT", 2, 0)
    r.name = K.fs(r, "", 9, "ink")
    r.name:SetJustifyH("LEFT")
    r.name:SetPoint("LEFT", 14, 0)
    r.name:SetWidth(X.W - 16 - 14 - 70)
    r.id = K.fs(r, "", 9, "muted")
    r.id:SetJustifyH("RIGHT")
    r.id:SetPoint("RIGHT", -4, 0)
    r.id:SetWidth(60)
    r:RegisterForClicks("AnyUp")
    r:SetScript("OnClick", function(self) X.ClickRow(self) end)
    r:SetScript("OnEnter", function(self) self.lit:SetAlpha(0.6) end)
    r:SetScript("OnLeave", function(self) X.PaintRow(self) end)
    f.rows[i] = r
  end
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function(_, delta)
    local n = #X.Shown()
    X.offset = math.max(0, math.min(math.max(0, n - X.ROWS), X.offset - delta * 3))
    X.Paint()
  end)
  -- the foot
  f.count = K.fs(f, "", 9, "muted")
  f.count:SetPoint("BOTTOMLEFT", 8, 22)
  f.help = K.fs(f, "click: hear it   shift-click: star / forget a file   wheel: scroll", 9, "dim")
  f.help:SetPoint("BOTTOMLEFT", 8, 8)
  f:Hide()
  X.frame = f
  return f
end

function X.PaintRow(r)
  local e = r.entry
  local mine = e and X.last ~= nil and (e.file or e.id) == X.last
  r.lit:SetAlpha(mine and 0.35 or 0)
end

function X.Paint()
  local f, db = X.frame, X.db
  if not (f and db) then return end
  local list = X.Shown(db)
  local K = F()
  for i, r in ipairs(f.rows) do
    local e = list[X.offset + i]
    r.entry = e
    if e then
      r.name:SetText(e.name)
      r.id:SetText(e.file and "your file" or tostring(e.id))
      r.star:SetText((not e.file and db.favs and db.favs[e.id]) and "*" or "")
      local rr, g, b = K.color(e.file and "accent" or (e.typed and "gold" or "ink"))
      r.name:SetTextColor(rr, g, b, 1)
      X.PaintRow(r)
      r:Show()
    else
      r:Hide()
    end
  end
  local from = #list > 0 and (X.offset + 1) or 0
  f.count:SetText(("%d-%d of %d%s"):format(from, math.min(#list, X.offset + X.ROWS), #list, db.starsOnly and "   (stars only)" or ""))
  f.stars.edge:set(db.starsOnly and "gold" or "edge", 1)
end

function X.IsOpen() return X.frame ~= nil and X.frame:IsShown() end

function X.Toggle(want)
  local f = X.Build(X.db)
  if want == nil then want = not f:IsShown() end
  if want then f:Show() X.Paint() else f:Hide() end
  return f:IsShown()
end

R:Register({
  name = "sounds",
  desc = "hear every sound the game has, and your own .ogg files",
  usage = "/bist sounds [word | id | favs]",
  defaults = { favs = {}, files = {} },
  options = {
    { kind = "button", label = "the sound explorer", button = "open",
      help = "Every sound the game has, searchable, and your own .ogg files beside them. Shift-click a sound to star it; /bist sounds favs lists your stars.",
      action = function(db) X.db = db X.Toggle(true) end },
  },
  OnInit = function(_, db) X.db = db end,
  -- the Hub's click opens it; "reset window positions" (recenter) only puts it back in the middle - it never pops a
  -- window open that nobody asked for, and builds nothing that was never opened
  OnOpen = function(_, db, recenter)
    X.db = db
    if recenter then
      if X.frame then X.frame:ClearAllPoints() X.frame:SetPoint("CENTER") end
      return
    end
    X.Toggle(true)
  end,
  IsOpen = function() return X.IsOpen() end,
  OnClose = function() X.Toggle(false) end,
  OnDisable = function() if X.frame then X.frame:Hide() end end,
  OnSlash = function(_, db, args)
    X.db = db
    args = tostring(args or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if args == "favs" then
      local favs = X.Favs(db)
      if #favs == 0 then return NS.Print("sounds: no stars yet - shift-click a sound in /bist sounds") end
      for _, e in ipairs(favs) do NS.Print("sounds: * %s %d", e.name, e.id) end
      return
    end
    local n = tonumber(args)
    if n then X.typed = n X.Play(n) X.Toggle(true) return end
    local f = X.Build(db)
    if args ~= "" then
      X.filter, X.offset = args, 0
      f.find.box:SetText(args)
      f.find.hint:Hide()
      return X.Toggle(true)
    end
    X.Toggle()
  end,
})
