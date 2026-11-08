-- BiSTools / Tools / CodexWindow.lua - BiS> CODEX, the book (8 Nov 2026). The engine: Codex.lua.
--
-- The look Arn picked (the mockup, 8 Nov): an illustrated encyclopedia - plates of figures with small red numbers,
-- numbered captions, chapter-red headings in a serif, running heads and page numbers, a Contents page by volumes -
-- "but also incorporating cockpit style": the paper sits inside a dark instrument housing (the BiSTheme colours) with
-- raised keys, an A-Z row and an LCD strip that says where you are.
--   Contents        both pages: Volume I Dungeons, Volume II Raids, the index. Click a dungeon.
--   a dungeon       left: its plate (up to C.UI.FIG figures, the creatures' own 3D models, numbered), our own line
--                   about it, the numbered captions; right: the picked figure's page.
--   a creature      its 3D model (TURN STAND ATTACK CAST DEATH), the data plate (level, type, rank, found,
--                   creature id, model id, met), its abilities (the client's own words), what it was seen to drop.
--   A-Z / search    every creature shipped or met, by its live name; right: the picked one's page.
-- PREV / NEXT turn the pages of the whole book. 600 x 420 (1.43:1), scale 1.2, Escape closes it.
-- WHAT IT COSTS: nothing while closed - no ticker; a model that has not drawn is asked again C.UI.RETRY later, only
-- while the window is up; TURN spins the big model by OnUpdate only while it is on and the window is up.
local _, NS = ...
local R, T = NS.Registry, NS.T
local C = NS.Codex
local X = {}
C.UI = X

X.W, X.H, X.SCALE = 600, 420, 1.2
X.PAGE_W, X.PAGE_H = 292, 352
X.FIG = 5                          -- figures on a plate
X.TOC_L, X.TOC_R = 21, 23          -- Contents lines on the left and the right page
X.IDX = 21                         -- index lines a page
X.ABIL, X.LOOT = 3, 3
X.RETRY, X.RETRY_TRIES = 0.5, 3    -- a model that did not draw: asked again, while the window is up
X.TURN_SPEED = 0.9                 -- radians a second
-- the client's animation ids (CONFIRMED in BiS Shell: 0 stand, 4 walk, 17 attack, 1 death); CAST is UNVERIFIED - 53
-- is the retail "spell cast omni", not yet seen on Forever
X.ANIM = { STAND = 0, ATTACK = 17, CAST = 53, DEATH = 1 }
X.ANIM_KEYS = { { "TURN", 32 }, { "STAND", 36 }, { "ATTACK", 42 }, { "CAST", 32 }, { "DEATH", 38 } }
X.DATA_ROWS = { "LEVEL", "TYPE", "RANK", "FOUND", "CREATURE", "MODEL", "MET" }
X.LETTERS = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U",
              "V", "W", "X", "Y", "Z", "?" }
-- the client's fonts: Morpheus for the book's headings, Friz Quadrata for its text
X.HEAD_FONT, X.BODY_FONT = "Fonts\\MORPHEUS.TTF", "Fonts\\FRIZQT__.TTF"
X.QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
-- THE BOOK'S OWN INKS (the paper is not a theme colour - it is the page). Quality colours darkened for cream paper.
X.INK = { paper = "efe7d6", edge = "d9ccb2", shade = "b9a77f", ink = "2a2118", soft = "6b5c48", rubric = "8c1d18" }
X.QUALITY = { [0] = "6b6b6b", [1] = "2a2118", [2] = "1e7a1e", [3] = "1d5fb8", [4] = "7a2fb3", [5] = "b35900" }
X.RANKS = { worldboss = "WORLD BOSS", rareelite = "RARE ELITE", elite = "ELITE", rare = "RARE", normal = "NORMAL",
            trivial = "TRIVIAL", minus = "MINOR" }

local function K() return NS.Farm end
local function hx(hex)
  return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end
local function ink(name) return hx(X.INK[name] or X.INK.ink) end

-- ------------------------------------------------------------------ words that fit

--- How wide a line is, the way the client measures Friz at our sizes (capitals and digits wide, spaces narrow): the
--- same weights the suite's fit check was calibrated on in game, so a trimmed line fits there too.
function X.Width(text, size)
  local t = tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  local px = 0
  for ch in t:gmatch("[%z\1-\127\192-\247][\128-\191]*") do
    if #ch > 1 or ch:match("%l") then px = px + 0.55 elseif ch:match("[%u%d]") then px = px + 0.75 else px = px + 0.3 end
  end
  return px * (size or 9)
end

--- The text cut to w pixels (".." at the end when it was cut).
function X.Trim(text, size, w)
  text = tostring(text or "")
  if X.Width(text, size) <= w then return text end
  local cut = text
  while #cut > 0 and X.Width(cut .. "..", size) > w do       -- cost: string arithmetic only, at most a line's length
    cut = cut:sub(1, -2)
  end
  cut = cut:gsub("[\192-\247][\128-\191]*$", ""):gsub("%s+$", "")
  return cut .. ".."
end

--- Set a one-line label, cut to fit w.
function X.Set(fs, text, w)
  fs:SetText(X.Trim(text, fs.codexSize or 8, w))
end

-- ------------------------------------------------------------------ the parts

--- A font string on the paper, in one of the book's inks.
local function pfs(parent, size, colour, font)
  local s = parent:CreateFontString(nil, "OVERLAY")
  if s:SetFont(font or X.BODY_FONT, size, "") == false then s:SetFont(STANDARD_TEXT_FONT, size, "") end
  s:SetTextColor(ink(colour))
  s:SetJustifyH("LEFT")
  s:SetWordWrap(false)
  s.codexSize = size
  return s
end

local function strip(parent, layer, r, g, b, a)
  local t = parent:CreateTexture(nil, layer)
  t:SetColorTexture(r, g, b, a or 1)
  return t
end

--- THE POP (the family rule, Arn 6 Nov): an accent wash over the whole thing and a bar down its left edge, under the
--- mouse. b.wash / b.bar; b.keep = the bar stays lit (the picked one).
local function pop(b)
  local k = K()
  b.wash = k.tex(b, "ARTWORK", "accent", 0.35)
  b.wash:SetAlpha(0)
  local r, g, bl = k.color("accent")
  b.bar = strip(b, "OVERLAY", r, g, bl, 1)
  b.bar:SetPoint("TOPLEFT") b.bar:SetPoint("BOTTOMLEFT") b.bar:SetWidth(2)
  b.bar:SetAlpha(0)
  function b:Pop(on)
    self.hover = on and true or false
    self.wash:SetAlpha(on and 1 or (self.keep and 0.4 or 0))
    self.bar:SetAlpha((on or self.keep) and 1 or 0)
  end
end

--- A raised key on the housing (the cockpit's buttons): lit = an amber line along its foot and gold words.
function X.Key(parent, label, w, h, onclick, tip)
  local k = K()
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, h)
  b.bg = k.tex(b, "BACKGROUND", "surface", 1)
  local r, g, bl = k.color("line2")
  b.top = strip(b, "BORDER", r, g, bl, 1)
  b.top:SetPoint("TOPLEFT") b.top:SetPoint("TOPRIGHT") b.top:SetHeight(1)
  r, g, bl = k.color("bg")
  b.bot = strip(b, "BORDER", r, g, bl, 1)
  b.bot:SetPoint("BOTTOMLEFT") b.bot:SetPoint("BOTTOMRIGHT") b.bot:SetHeight(2)
  r, g, bl = k.color("gold")
  b.lit = strip(b, "OVERLAY", r, g, bl, 1)
  b.lit:SetPoint("BOTTOMLEFT") b.lit:SetPoint("BOTTOMRIGHT") b.lit:SetHeight(2)
  b.lit:SetAlpha(0)
  pop(b)
  b.label = k.fs(b, label, 7, "ink2")
  b.label:SetPoint("CENTER", 0, 0)
  b.tip = tip
  function b:Lit(on)
    self.on = on and true or false
    self.lit:SetAlpha(self.on and 1 or 0)
    self.label:SetTextColor(k.color(self.on and "gold" or "ink2"))
  end
  b:SetScript("OnClick", function(self) if onclick then onclick(self) end end)
  b:SetScript("OnEnter", function(self)
    self:Pop(true)
    if self.tip and GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(self.tip, 1, 1, 1, true)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function(self) self:Pop(false) if GameTooltip then GameTooltip:Hide() end end)
  return b
end

--- A clickable line on the paper (Contents, index, an ability): pops like everything else.
local function paperRow(parent, w, h, onclick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, h)
  pop(b)
  b:SetScript("OnClick", function(self) if self.click and onclick then onclick(self) end end)
  b:SetScript("OnEnter", function(self)
    if not self.click then return end
    self:Pop(true)
    if self.tip and GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      for i, line in ipairs(self.tip) do
        if i == 1 then GameTooltip:AddLine(line) else GameTooltip:AddLine(line, 1, 1, 1, true) end
      end
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function(self) self:Pop(false) if GameTooltip then GameTooltip:Hide() end end)
  return b
end

local function rule(parent, y, x, w)
  local r, g, b = ink("edge")
  local t = strip(parent, "BORDER", r, g, b, 1)
  t:SetPoint("TOPLEFT", x or 10, y)
  t:SetSize(w or (X.PAGE_W - 20), 1)
  return t
end

local function subFrame(page)
  local s = CreateFrame("Frame", nil, page)
  s:SetSize(X.PAGE_W, X.PAGE_H)
  s:SetPoint("TOPLEFT")
  s:Hide()
  return s
end

local function model(parent, w, h)
  local ok, m = pcall(CreateFrame, "DressUpModel", nil, parent)
  if not ok or not m then return nil end
  m:SetSize(w, h)
  if m.EnableMouse then m:EnableMouse(false) end     -- a click on a figure is the figure's (its button), never the model's
  return m
end

local function field(parent, name, w, hint)
  local k = K()
  local well = CreateFrame("Frame", nil, parent)
  well:SetSize(w, 16)
  k.tex(well, "BACKGROUND", "field", 0.95)
  well.edge = k.border(well, "edge", 1)
  local eb = CreateFrame("EditBox", name, well)
  eb:SetAllPoints()
  eb:SetTextInsets(4, 4, 0, 0)
  eb:SetFont(STANDARD_TEXT_FONT, 8, "")
  eb:SetAutoFocus(false)
  eb:SetMaxLetters(40)
  eb:SetTextColor(k.color("good"))
  local ph = k.fs(well, hint, 8, "dim")
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

-- ------------------------------------------------------------------ the window

function X.Build()
  if X.frame then return X.frame end
  local k = K()
  local f = CreateFrame("Frame", "BiSToolsCodex", UIParent)
  X.frame = f
  f:SetSize(X.W, X.H)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetScale(X.SCALE)
  if UISpecialFrames then table.insert(UISpecialFrames, "BiSToolsCodex") end   -- Escape closes it
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetScript("OnHide", function() X.Turn(false) end)
  k.tex(f, "BACKGROUND", "frame", 0.97)
  k.border(f, "edge", 1)
  f:Hide()

  -- the bar: lamp, name, the two book keys, the LCD, close
  local gr, gg, gb = k.color("good")
  f.lampOn = strip(f, "ARTWORK", gr, gg, gb, 1)
  f.lampOn:SetSize(6, 6)
  f.lampOn:SetPoint("TOPLEFT", 8, -11)
  f.title = k.fs(f, T.text("accent", "BiS>") .. " CODEX", 10, "ink")
  f.title:SetPoint("TOPLEFT", 18, -8)
  f.keys = {}
  f.keys.contents = X.Key(f, "CONTENTS", 58, 16, function() X.Contents() end, "The volumes and their dungeons.")
  f.keys.contents:SetPoint("TOPLEFT", 90, -6)
  f.keys.index = X.Key(f, "A-Z", 34, 16, function() X.OpenIndex(X.letter or "A") end,
    "Every creature in the book, by name: the ones shipped and the ones you have met.")
  f.keys.index:SetPoint("TOPLEFT", 152, -6)
  local lcd = CreateFrame("Frame", nil, f)
  lcd:SetSize(372, 16)
  lcd:SetPoint("TOPLEFT", 192, -6)
  k.tex(lcd, "BACKGROUND", "bg", 1)
  k.border(lcd, "line2", 1)
  f.lcd = k.fs(lcd, "", 8, "good")
  f.lcd:SetPoint("LEFT", 6, 0)
  f.lcd.codexSize = 8
  f.close = X.Key(f, "x", 20, 16, function() X.Toggle(false) end, "Close the Codex.")
  f.close:SetPoint("TOPRIGHT", -8, -6)

  -- A to Z (and ? for the names the game has not told us yet)
  f.az = {}
  for i, l in ipairs(X.LETTERS) do
    local b = X.Key(f, l, 19, 13, function() X.OpenIndex(l) end,
      l == "?" and "Creatures whose names the game has not sent yet." or ("Creatures whose names start with " .. l .. "."))
    b:SetPoint("TOPLEFT", 8 + (i - 1) * 21, -26)
    b.letter = l
    f.az[i] = b
  end

  -- the paper: two pages and the gutter between them
  local paper = CreateFrame("Frame", nil, f)
  paper:SetSize(X.PAGE_W * 2, X.PAGE_H)
  paper:SetPoint("TOPLEFT", 8, -44)
  local pr, pg, pb = ink("paper")
  local bgp = strip(paper, "BACKGROUND", pr, pg, pb, 1)
  bgp:SetAllPoints()
  local sr, sg, sb = ink("shade")
  local g1 = strip(paper, "BORDER", sr, sg, sb, 0.35)
  g1:SetPoint("TOPLEFT", X.PAGE_W - 8, 0) g1:SetSize(8, X.PAGE_H)
  local g2 = strip(paper, "BORDER", sr, sg, sb, 0.2)
  g2:SetPoint("TOPLEFT", X.PAGE_W, 0) g2:SetSize(6, X.PAGE_H)
  local er, eg, eb = ink("edge")
  local gut = strip(paper, "ARTWORK", er, eg, eb, 1)
  gut:SetPoint("TOPLEFT", X.PAGE_W, 0) gut:SetSize(1, X.PAGE_H)
  f.paper = paper
  f.pages = {}
  for i = 1, 2 do
    local p = CreateFrame("Frame", nil, paper)
    p:SetSize(X.PAGE_W, X.PAGE_H)
    p:SetPoint("TOPLEFT", (i - 1) * X.PAGE_W, 0)
    p.headL = pfs(p, 7, "soft")
    p.headL:SetPoint("TOPLEFT", 10, -6)
    p.headR = pfs(p, 7, "soft")
    p.headR:SetPoint("TOPRIGHT", -10, -6)
    p.headR:SetJustifyH("RIGHT")
    rule(p, -17)
    p.folio = pfs(p, 7, "soft")
    if i == 1 then p.folio:SetPoint("BOTTOMLEFT", 10, 6) else
      p.folio:SetPoint("BOTTOMRIGHT", -10, 6) p.folio:SetJustifyH("RIGHT") end
    f.pages[i] = p
  end
  X.BuildContents(f)
  X.BuildDungeon(f)
  X.BuildCreature(f)
  X.BuildIndex(f)

  -- the foot: turn the pages, search, what the game is doing, the build
  f.prev = X.Key(f, "< PREV", 50, 16, function() X.Flip(-1) end, "The page before.")
  f.prev:SetPoint("BOTTOMLEFT", 8, 4)
  f.next = X.Key(f, "NEXT >", 50, 16, function() X.Flip(1) end, "The next page.")
  f.next:SetPoint("BOTTOMLEFT", 62, 4)
  f.find = field(f, "BiSToolsCodexFind", 180, "search a name")
  f.find:SetPoint("BOTTOMLEFT", 120, 4)
  f.find.box:SetScript("OnTextChanged", function(self)
    local t = self:GetText() or ""
    if t ~= "" then X.Search(t) elseif X.view == "index" and X.search then X.OpenIndex(X.letter or "A") end
  end)
  f.find.box:SetScript("OnEnterPressed", function(self)
    local list = X.list or {}
    if X.view == "index" and #list >= 1 then X.Select(list[1]) end
    self:ClearFocus()
  end)
  f.lamp = strip(f, "ARTWORK", gr, gg, gb, 1)
  f.lamp:SetSize(6, 6)
  f.lamp:SetPoint("BOTTOMLEFT", 310, 9)
  f.status = k.fs(f, "", 7, "dim")
  f.status:SetPoint("BOTTOMLEFT", 320, 7)
  f.build = k.fs(f, "", 7, "dim")                    -- the fingerprint: faint, which copy this is
  f.build:SetPoint("BOTTOMRIGHT", -8, 7)
  f.build:SetJustifyH("RIGHT")
  f.build:SetAlpha(0.6)
  X.models = { f.hero }
  for _, fig in ipairs(f.figs) do X.models[#X.models + 1] = fig.m end
  return f
end

-- Contents: both pages, one line a dungeon
function X.BuildContents(f)
  f.tocL, f.tocR = subFrame(f.pages[1]), subFrame(f.pages[2])
  f.tocL.big = pfs(f.tocL, 16, "rubric", X.HEAD_FONT)
  f.tocL.big:SetPoint("TOPLEFT", 10, -24)
  f.tocL.big:SetText("CONTENTS")
  f.toc = {}
  local function lines(sub, n, y0)
    for i = 1, n do
      local r = paperRow(sub, X.PAGE_W - 20, 12, function(self) X.OpenEntry(self.entry) end)
      r:SetPoint("TOPLEFT", 10, y0 - (i - 1) * 13)
      r.name = pfs(r, 8, "ink")
      r.name:SetPoint("LEFT", 4, 0)
      r.num = pfs(r, 7, "soft")
      r.num:SetPoint("RIGHT", -4, 0)
      r.num:SetJustifyH("RIGHT")
      f.toc[#f.toc + 1] = r
    end
  end
  lines(f.tocL, X.TOC_L, -50)
  lines(f.tocR, X.TOC_R, -24)
end

-- a dungeon's left page: title, our line, the plate, the captions
function X.BuildDungeon(f)
  local d = subFrame(f.pages[1])
  f.dun = d
  d.title = pfs(d, 13, "rubric", X.HEAD_FONT)
  d.title:SetPoint("TOPLEFT", 10, -22)
  d.about = pfs(d, 8, "ink")
  d.about:SetPoint("TOPLEFT", 10, -40)
  d.about:SetWidth(X.PAGE_W - 20)
  d.about:SetWordWrap(true)
  f.figs = {}
  local fw = math.floor((X.PAGE_W - 20) / X.FIG)
  for i = 1, X.FIG do
    local b = CreateFrame("Button", nil, d)
    b:SetSize(fw, 96)
    b:SetPoint("TOPLEFT", 10 + (i - 1) * fw, -76)
    pop(b)
    b.m = model(b, fw, 82)
    if b.m then b.m:SetPoint("TOP", 0, 0) end
    b.num = pfs(b, 8, "rubric")
    b.num:SetPoint("BOTTOM", 0, 2)
    b.num:SetJustifyH("CENTER")
    b.num:SetText(tostring(i))
    b:SetScript("OnClick", function(self) if self.npc then X.Select(self.npc) end end)
    b:SetScript("OnEnter", function(self)
      self:Pop(true)
      if GameTooltip and self.npc then
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(C.Name(self.npc) or ("creature " .. self.npc))
        GameTooltip:AddLine("click: its page", 1, 1, 1)
        GameTooltip:Show()
      end
    end)
    b:SetScript("OnLeave", function(self) self:Pop(false) if GameTooltip then GameTooltip:Hide() end end)
    f.figs[i] = b
  end
  f.caps = {}
  for i = 1, X.FIG do
    local c = pfs(d, 8, "ink")
    c:SetPoint("TOPLEFT", 10, -178 - (i - 1) * 13)
    f.caps[i] = c
  end
  d.foot = pfs(d, 7, "soft")
  d.foot:SetPoint("TOPLEFT", 10, -250)
  d.foot:SetWidth(X.PAGE_W - 20)
  d.foot:SetWordWrap(true)
end

-- a creature's page (the right page, on a spread and in the index)
function X.BuildCreature(f)
  local k = K()
  local p = subFrame(f.pages[2])
  f.page = p
  f.name = pfs(p, 12, "rubric", X.HEAD_FONT)
  f.name:SetPoint("TOPLEFT", 10, -22)
  f.hero = model(p, 130, 128)
  if f.hero then f.hero:SetPoint("TOPLEFT", 10, -38) end
  -- the data plate: a piece of the cockpit printed on the page
  local dp = CreateFrame("Frame", nil, p)
  dp:SetSize(136, 110)
  dp:SetPoint("TOPLEFT", 146, -38)
  k.tex(dp, "BACKGROUND", "frame", 1)
  k.border(dp, "edge", 1)
  dp.head = k.fs(dp, "DATA PLATE", 7, "ink")
  dp.head:SetPoint("TOPLEFT", 5, -4)
  dp.v = {}
  local lr, lg, lb = k.color("line")
  for i, key in ipairs(X.DATA_ROWS) do
    local y = -16 - (i - 1) * 13
    local sep = strip(dp, "BORDER", lr, lg, lb, 1)
    sep:SetPoint("TOPLEFT", 4, y + 1) sep:SetSize(128, 1)
    local l = k.fs(dp, key, 6, "dim")
    l:SetPoint("TOPLEFT", 5, y - 2)
    local v = k.fs(dp, "", 7, "good")
    v:SetPoint("TOPRIGHT", -5, y - 2)
    v:SetJustifyH("RIGHT")
    v.codexSize = 7
    dp.v[key] = v
  end
  f.data = dp
  f.anim = {}
  local x = 10
  for _, a in ipairs(X.ANIM_KEYS) do
    local name, w = a[1], a[2]
    local b = X.Key(p, name, w, 14, function() X.Animate(name) end,
      name == "TURN" and "Turn the model round, slowly (again: stop)." or
      (name == "CAST" and "Its casting move (the move's number is a guess on Forever - say if it looks wrong)." or
       ("Play its " .. name:lower() .. " move.")))
    b:SetPoint("TOPLEFT", x, -170)
    x = x + w + 4
    f.anim[name] = b
  end
  f.abHead = pfs(p, 10, "rubric", X.HEAD_FONT)
  f.abHead:SetPoint("TOPLEFT", 10, -190)
  rule(p, -202)
  f.abil = {}
  for i = 1, X.ABIL do
    local r = paperRow(p, X.PAGE_W - 20, 24, function() end)
    r:SetPoint("TOPLEFT", 10, -205 - (i - 1) * 25)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(16, 16)
    r.icon:SetPoint("LEFT", 3, 0)
    r.name = pfs(r, 8, "ink")
    r.name:SetPoint("TOPLEFT", 23, -2)
    r.desc = pfs(r, 7, "soft")
    r.desc:SetPoint("TOPLEFT", 23, -13)
    f.abil[i] = r
  end
  f.none = pfs(p, 8, "soft")
  f.none:SetPoint("TOPLEFT", 10, -208)
  f.lootHead = pfs(p, 10, "rubric", X.HEAD_FONT)
  f.lootHead:SetPoint("TOPLEFT", 10, -284)
  f.lootHead:SetText("SEEN TO DROP")
  rule(p, -296)
  f.loot = {}
  for i = 1, X.LOOT do
    local l = pfs(p, 8, "ink")
    l:SetPoint("TOPLEFT", 10, -300 - (i - 1) * 11)
    f.loot[i] = l
  end
  f.noLoot = pfs(p, 8, "soft")
  f.noLoot:SetPoint("TOPLEFT", 10, -300)
  -- the right page when nothing is picked
  f.hint = pfs(f.pages[2], 8, "soft")
  f.hint:SetPoint("TOPLEFT", 10, -30)
  f.hint:SetWidth(X.PAGE_W - 20)
  f.hint:SetWordWrap(true)
end

-- the index's left page
function X.BuildIndex(f)
  local s = subFrame(f.pages[1])
  f.ixL = s
  s.big = pfs(s, 16, "rubric", X.HEAD_FONT)
  s.big:SetPoint("TOPLEFT", 10, -22)
  s.sub = pfs(s, 7, "soft")
  s.sub:SetPoint("TOPLEFT", 10, -42)
  f.idx = {}
  for i = 1, X.IDX do
    local r = paperRow(s, X.PAGE_W - 20, 12, function(self) X.Select(self.npc) end)
    r:SetPoint("TOPLEFT", 10, -54 - (i - 1) * 13)
    r.name = pfs(r, 8, "ink")
    r.name:SetPoint("LEFT", 4, 0)
    r.where = pfs(r, 7, "soft")
    r.where:SetPoint("RIGHT", -4, 0)
    r.where:SetJustifyH("RIGHT")
    f.idx[i] = r
  end
end

-- ------------------------------------------------------------------ models

function X.Drawn(m)
  if not (m and m.GetModelFileID) then return false end
  local ok, file = pcall(m.GetModelFileID, m)
  file = ok and C.Plain(file) or nil
  return type(file) == "number" and file > 0
end

--- Ask a model for a creature: by its model id when we ship one (drawn from the client's files), else by npc id (the
--- client fetches an unmet creature first: nothing the first time, the next ask lands).
function X.Ask(m)
  local s = C.DATA.creatures[m.npc]
  pcall(m.ClearModel, m)
  if s and s.display then pcall(m.SetDisplayInfo, m, s.display) else pcall(m.SetCreature, m, m.npc) end
  if m.SetPortraitZoom then pcall(m.SetPortraitZoom, m, 0) end
  if m.SetFacing then pcall(m.SetFacing, m, m.face or 0.35) end
  if m.anim and m.SetAnimation then pcall(m.SetAnimation, m, m.anim) end
  m.drawn = X.Drawn(m)
  return m.drawn
end

--- Put a creature on a model: SHOWN FIRST (a hidden model may never load), then asked; asked again a moment later
--- while it has not drawn and the window is up.
function X.Dress(m, npc, face)
  if not m then return end
  m:Show()
  if m.npc == npc and m.drawn then return end
  m.npc, m.tries, m.face = npc, 0, face
  if not X.Ask(m) then X.Retry() end
end

function X.Retry()
  if X.retrying then return end
  X.retrying = true
  C_Timer.After(X.RETRY, function()
    X.retrying = false
    if not X.IsOpen() then return end
    local again = false
    for _, m in ipairs(X.models or {}) do
      if m.npc and not m.drawn and m:IsVisible() and (m.tries or 0) < X.RETRY_TRIES then
        m.tries = (m.tries or 0) + 1
        if not X.Ask(m) then again = true end
      end
    end
    if again then X.Retry() end
    X.PaintStatus()
  end)
end

--- TURN spins the big model (OnUpdate only while on and shown); the rest play a move.
function X.Turn(on)
  local m = X.frame and X.frame.hero
  X.turning = on and true or false
  if not m then return end
  if X.turning then
    m:SetScript("OnUpdate", function(self, dt)
      self.face = ((self.face or 0) + (dt or 0) * X.TURN_SPEED) % (2 * math.pi)
      pcall(self.SetFacing, self, self.face)
    end)
  else
    m:SetScript("OnUpdate", nil)
  end
  if X.frame.anim and X.frame.anim.TURN then X.frame.anim.TURN:Lit(X.turning) end
end

function X.Animate(name)
  local m = X.frame and X.frame.hero
  if name == "TURN" then return X.Turn(not X.turning) end
  if not m then return end
  m.anim = X.ANIM[name] or 0
  if m.SetAnimation then pcall(m.SetAnimation, m, m.anim) end
  for key, b in pairs(X.frame.anim) do if key ~= "TURN" then b:Lit(key == name) end end
end

-- ------------------------------------------------------------------ where am I in the book

--- Page numbers: Contents 1-2, then a spread per plate of each dungeon, in the Contents' order, then the index.
function X.Folios()
  if X.folio then return X.folio end
  local out, n = { dungeons = {} }, 3
  for _, v in ipairs(C.DATA.volumes) do
    for _, d in ipairs(v.list) do
      out.dungeons[d] = n
      n = n + 2 * math.max(1, math.ceil(#C.DATA.dungeons[d].list / X.FIG))
    end
  end
  out.index = n
  X.folio = out
  return out
end

--- Every place in the book, in order: { dungeon id, volume } - for PREV / NEXT and the Contents.
function X.Order()
  if X.order then return X.order end
  local out = {}
  for _, v in ipairs(C.DATA.volumes) do
    for _, d in ipairs(v.list) do out[#out + 1] = { d = d, v = v } end
  end
  X.order = out
  return out
end

function X.VolumeOf(d)
  for _, e in ipairs(X.Order()) do if e.d == d then return e.v end end
end

function X.Plates(d) return math.max(1, math.ceil(#C.DATA.dungeons[d].list / X.FIG)) end

function X.Contents()
  X.view, X.sel = "contents", nil
  X.Paint()
end

function X.OpenDungeon(d, plate)
  local dd = C.DATA.dungeons[d]
  if not dd then return false end
  X.view, X.dungeon = "dungeon", d
  X.plate = math.max(1, math.min(plate or 1, X.Plates(d)))
  local last = math.min(#dd.list, X.plate * X.FIG)
  X.sel = dd.list[last]
  if not X.IsOpen() then X.Toggle(true) end
  X.Paint()
  return true
end

function X.OpenEntry(e)
  if not e then return end
  if e.dungeon then X.OpenDungeon(e.dungeon) elseif e.index then X.OpenIndex("A") end
end

function X.OpenIndex(letter, keepSearch)
  X.view, X.letter, X.offset = "index", letter or "A", 0
  if not keepSearch then X.search = nil end
  C.Warm(C.All())
  X.list = C.Index(X.letter, X.search)
  X.sel = X.list[1]
  X.Paint()
end

function X.Search(text)
  text = tostring(text or "")
  if text:gsub("%s", "") == "" then return X.OpenIndex(X.letter or "A") end
  X.search = text
  return X.OpenIndex(X.letter or "A", true)
end

function X.Select(npc)
  if type(npc) ~= "number" then return end
  X.sel = npc
  if X.frame and X.frame.hero then X.frame.hero.anim = nil end
  X.Paint()
end

--- PREV / NEXT: through the whole book - Contents, each dungeon's plates in order, then the index's pages and letters.
function X.Flip(dir)
  local order = X.Order()
  if X.view == "contents" then
    if dir > 0 then X.OpenDungeon(order[1].d) end
    return
  end
  if X.view == "dungeon" then
    local p = X.plate + dir
    if p >= 1 and p <= X.Plates(X.dungeon) then return X.OpenDungeon(X.dungeon, p) end
    for i, e in ipairs(order) do
      if e.d == X.dungeon then
        local nx = order[i + dir]
        if nx then return X.OpenDungeon(nx.d, dir > 0 and 1 or X.Plates(nx.d)) end
        if dir < 0 then return X.Contents() end
        return X.OpenIndex("A")
      end
    end
    return
  end
  -- the index: its pages, then the next letter
  local n = #(X.list or {})
  local off = X.offset + dir * X.IDX
  if off >= 0 and off < n then X.offset = off return X.Paint() end
  if X.search then return end
  for i, l in ipairs(X.LETTERS) do
    if l == X.letter then
      local nl = X.LETTERS[i + dir]
      if nl then return X.OpenIndex(nl) end
      if dir < 0 then local last = order[#order] return X.OpenDungeon(last.d, X.Plates(last.d)) end
      return
    end
  end
end

--- Open the book at a creature's page: its dungeon's plate when we ship it, else the index under its letter.
function X.Show(npc)
  local db = C.DB()
  if not db or type(npc) ~= "number" then return nil, "not ready" end
  local s = C.DATA.creatures[npc]
  if not s and not db.met[npc] then return nil, "unknown" end
  local f = X.Build()
  -- the page is set first and painted ONCE (a paint asks the client for every spell and item on it)
  if s then
    local list, at = C.DATA.dungeons[s.d].list, 1
    for i, id in ipairs(list) do if id == npc then at = i end end
    X.view, X.dungeon, X.plate = "dungeon", s.d, math.ceil(at / X.FIG)
  else
    X.view, X.letter, X.search, X.offset = "index", C.Letter(db.names[npc]), nil, 0
    local list = C.Index(X.letter)
    for i, id in ipairs(list) do if id == npc then X.offset = math.floor((i - 1) / X.IDX) * X.IDX end end
  end
  X.sel = npc
  if f.hero then f.hero.anim = nil end
  f:Show()
  X.Paint()
  return true
end

-- ------------------------------------------------------------------ painting

function X.IsOpen() return X.frame ~= nil and X.frame:IsShown() end

function X.Toggle(want)
  local f = X.Build()
  if want == nil then want = not f:IsShown() end
  if want then
    f:Show()
    X.view = X.view or "contents"
    X.Paint()
  else
    f:Hide()
  end
  return f:IsShown()
end

local function upper(s) return s and tostring(s):upper() or nil end

function X.PaintStatus()
  local f = X.frame
  if not f then return end
  local k = K()
  local word, colour
  if next(C.pending) then word, colour = "ASKING THE GAME FOR NAMES", "gold"
  elseif f.hero and f.page:IsShown() and f.hero.npc and not f.hero.drawn then word, colour = "MODEL ASKED", "gold"
  elseif f.hero and f.page:IsShown() and f.hero.drawn then word, colour = "MODEL LOADED", "good"
  else word, colour = "READY", "good" end
  f.status:SetText(word)
  f.lamp:SetColorTexture(k.color(colour))
end

function X.Paint()
  local f = X.frame
  if not (f and f:IsShown()) then return end
  local v = X.view or "contents"
  f.tocL:SetShown(v == "contents")
  f.tocR:SetShown(v == "contents")
  f.dun:SetShown(v == "dungeon")
  f.ixL:SetShown(v == "index")
  local creature = (v == "dungeon" or v == "index") and X.sel ~= nil
  f.page:SetShown(creature)
  f.hint:SetShown(v == "index" and not creature)
  f.keys.contents:Lit(v == "contents")
  f.keys.index:Lit(v == "index")
  for _, b in ipairs(f.az) do b:Lit(v == "index" and not X.search and b.letter == X.letter) end
  if v == "contents" then X.PaintContents(f)
  elseif v == "dungeon" then X.PaintDungeon(f)
  else X.PaintIndex(f) end
  if creature then X.PaintCreature(f, X.sel) end
  f.build:SetText(NS.Stamp())
  X.PaintStatus()
end

function X.LCD(text)
  X.Set(X.frame.lcd, upper(text), 372 - 12)
end

function X.TocEntries()
  local out, folio = {}, X.Folios()
  local db = C.DB()
  local met = 0
  for _ in pairs(db and db.met or {}) do met = met + 1 end
  for _, v in ipairs(C.DATA.volumes) do
    out[#out + 1] = { head = "VOLUME " .. v.numeral .. "  -  " .. v.title }
    for _, d in ipairs(v.list) do
      local dd = C.DATA.dungeons[d]
      out[#out + 1] = { dungeon = d, text = dd.title, right = "lvl " .. dd.level .. "    " .. folio.dungeons[d],
                        tip = { dd.name, dd.where .. ", level " .. dd.level .. ": " .. #dd.list .. " creatures" } }
    end
  end
  out[#out + 1] = { head = "THE INDEX" }
  out[#out + 1] = { index = true, text = "A TO Z, BY NAME", right = folio.index,
                    tip = { "The index", #C.All() .. " creatures in the book, " .. met .. " met by you" } }
  return out, met
end

function X.PaintContents(f)
  local entries, met = X.TocEntries()
  for i, r in ipairs(f.toc) do
    local e = entries[i]
    r.entry = e
    r.click = e and (e.dungeon or e.index) and true or false
    r.keep = false
    r.tip = e and e.tip or nil
    r:Pop(false)
    if e then
      r.name:SetTextColor(ink(e.head and "rubric" or "ink"))
      X.Set(r.name, e.head or e.text, X.PAGE_W - 20 - 60)
      r.num:SetText(e.right and tostring(e.right) or "")
      r:Show()
    else
      r:Hide()
    end
  end
  local p1, p2 = f.pages[1], f.pages[2]
  p1.headL:SetText("BiS> CODEX")
  p1.headR:SetText("CONTENTS")
  p2.headL:SetText("CONTENTS")
  p2.headR:SetText("everything here comes from the game")
  p1.folio:SetText("1")
  p2.folio:SetText("2")
  X.LCD(("CONTENTS - %d places - %d creatures - %d met"):format(#X.Order(), #C.All(), met))
  f.prev:Lit(false)
  f.next:Lit(false)
end

function X.Rank(c)
  local r = c.rank and X.RANKS[c.rank]
  if c.boss then return r and r ~= "NORMAL" and ("BOSS, " .. r) or "BOSS" end
  return r or "-"
end

function X.PaintDungeon(f)
  local d, dd = X.dungeon, C.DATA.dungeons[X.dungeon]
  local vol = X.VolumeOf(d)
  local first = (X.plate - 1) * X.FIG
  local db = C.DB()
  local p1 = f.pages[1]
  X.Set(p1.headL, dd.title .. " - " .. dd.where, 190)
  p1.headR:SetText("level " .. dd.level)
  X.Set(f.dun.title, upper(dd.name), X.PAGE_W - 20)
  f.dun.about:SetText(dd.about)
  local metHere = 0
  for _, npc in ipairs(dd.list) do if db.met[npc] then metHere = metHere + 1 end end
  for i = 1, X.FIG do
    local npc = dd.list[first + i]
    local fig, cap = f.figs[i], f.caps[i]
    fig.npc = npc
    fig.keep = npc ~= nil and npc == X.sel
    fig:Pop(false)
    if npc then
      fig:Show()
      X.Dress(fig.m, npc, 0.35)
      local c = C.Creature(npc)
      local name = c.name or C.Name(npc) or ("creature " .. npc)
      local what = c.boss and "Boss" or "Seen here"
      if c.level then what = what .. ", level " .. c.level end
      X.Set(cap, i .. "   " .. name .. ".  " .. what .. (c.met > 0 and (", met " .. c.met) or "") .. ".", X.PAGE_W - 20)
      cap:Show()
    else
      fig:Hide()
      cap:Hide()
    end
  end
  local plates = X.Plates(d)
  f.dun.foot:SetText(("Plate %d of %d.  %d creatures here, %d of them met.  Click a figure for its page."):format(
    X.plate, plates, #dd.list, metHere))
  local base = X.Folios().dungeons[d] + 2 * (X.plate - 1)
  p1.folio:SetText(tostring(base))
  f.pages[2].folio:SetText(tostring(base + 1))
  X.LCD(("VOL. %s - %s - %s - PLATE %d OF %d"):format(vol and vol.numeral or "?", vol and vol.title or "",
    dd.title, X.plate, plates))
  f.prev:Lit(false)
  f.next:Lit(false)
end

function X.PaintIndex(f)
  local list = C.Index(X.letter, X.search)
  X.list = list
  if X.offset >= #list then X.offset = 0 end
  local s = f.ixL
  if X.search then
    X.Set(s.big, "SEARCH", 120)
    X.Set(s.sub, ("\"%s\": %d found"):format(X.search, #list), X.PAGE_W - 20)
  else
    s.big:SetText(X.letter == "?" and "NOT YET NAMED" or X.letter)
    X.Set(s.sub, ("%d names - page %d of %d"):format(#list, math.floor(X.offset / X.IDX) + 1,
      math.max(1, math.ceil(#list / X.IDX))), X.PAGE_W - 20)
  end
  for i, r in ipairs(f.idx) do
    local npc = list[X.offset + i]
    r.npc = npc
    r.click = npc ~= nil
    r.keep = npc ~= nil and npc == X.sel
    r:Pop(false)
    if npc then
      local c = C.Creature(npc)
      X.Set(r.name, c.name or ("creature " .. npc), 160)
      local dd = c.dungeon and C.DATA.dungeons[c.dungeon]
      local where = dd and dd.name or "met in the wild"
      if c.met > 0 then where = where .. "  - met " .. c.met end
      X.Set(r.where, where, 98)
      r.tip = { c.name or ("creature " .. npc), "click: its page" }
      r:Show()
    else
      r:Hide()
    end
  end
  local p1 = f.pages[1]
  p1.headL:SetText("THE INDEX")
  p1.headR:SetText(X.search and "search" or ("under " .. X.letter))
  local folio = X.Folios().index + 2 * math.floor(X.offset / X.IDX)
  p1.folio:SetText(tostring(folio))
  f.pages[2].folio:SetText(tostring(folio + 1))
  f.pages[2].headL:SetText("")
  f.pages[2].headR:SetText("")
  f.hint:SetText(#list == 0 and "Nothing here yet. Names arrive from the game as the book asks for them, and every "
    .. "creature you target or see joins the book." or "Pick a name on the left.")
  if X.search then X.LCD(("SEARCH - %s - %d found"):format(X.search, #list))
  else X.LCD(("INDEX - %s - %d names"):format(X.letter == "?" and "not yet named" or X.letter, #list)) end
  f.prev:Lit(false)
  f.next:Lit(false)
end

function X.PaintCreature(f, npc)
  local c = C.Creature(npc)
  if not c then f.page:Hide() return end
  local name = c.name or C.Name(npc)
  local p2 = f.pages[2]
  if X.view == "dungeon" then
    local at = 1
    for i, id in ipairs(C.DATA.dungeons[X.dungeon].list) do if id == npc then at = i end end
    p2.headL:SetText(("Fig. %d, plate %d"):format((at - 1) % X.FIG + 1, X.plate))
  else
    p2.headL:SetText("The index")
  end
  X.Set(p2.headR, upper(name or ("creature " .. npc)), 170)
  X.Set(f.name, upper(name or ("creature " .. npc)), X.PAGE_W - 20)
  local hero = f.hero
  if hero and hero.npc ~= npc then hero.anim = nil X.Turn(false) end
  X.Dress(hero, npc, 0.5)
  for key, b in pairs(f.anim) do if key ~= "TURN" then b:Lit(hero and hero.anim == X.ANIM[key] and hero.anim ~= nil) end end
  -- the data plate
  local dd = c.dungeon and C.DATA.dungeons[c.dungeon]
  local v = f.data.v
  local function put(key, text) X.Set(v[key], text, 82) end
  put("LEVEL", c.level and tostring(c.level) or "-")
  put("TYPE", upper(c.type and (c.family and (c.type .. " - " .. c.family) or c.type) or "-"))
  put("RANK", X.Rank(c))
  put("FOUND", upper(dd and dd.name or "the wild"))
  put("CREATURE", tostring(npc))
  put("MODEL", c.display and tostring(c.display) or "BY CREATURE")
  put("MET", c.met == 0 and "NOT YET" or (c.met == 1 and "ONCE" or (c.met .. " TIMES")))
  -- abilities: shipped ones first, then the ones seen cast
  local n = #c.spells
  f.abHead:SetText(n > X.ABIL and ("ABILITIES  (%d OF %d)"):format(X.ABIL, n) or "ABILITIES")
  for i, r in ipairs(f.abil) do
    local id = c.spells[i]
    if id then
      local s = C.Spell(id)
      r.icon:SetTexture(s.icon or X.QUESTION)
      X.Set(r.name, s.name or ("spell " .. id), X.PAGE_W - 20 - 26)
      X.Set(r.desc, s.desc or "(the game is fetching its words)", X.PAGE_W - 20 - 26)
      r.click = true
      r.tip = { (s.name or "spell") .. "  (" .. id .. ")", s.desc or "the game is fetching its words" }
      r:Pop(false)
      r:Show()
    else
      r.click = false
      r:Hide()
    end
  end
  f.none:SetShown(n == 0)
  X.Set(f.none, "Learned when seen: none seen cast yet.", X.PAGE_W - 20)
  -- seen to drop: the most often first
  local drops = {}
  for item, cnt in pairs(c.seen) do drops[#drops + 1] = { item = item, n = cnt } end
  table.sort(drops, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.item < b.item end)
  for i, l in ipairs(f.loot) do
    local e = drops[i]
    if e then
      local iname, q = C.Item(e.item)
      local tail = e.n == 1 and "  - once" or ("  - " .. e.n .. " times")
      local plainName = X.Trim(iname or ("item " .. e.item), 8, X.PAGE_W - 20 - X.Width(tail, 8))
      l:SetText("|cff" .. (X.QUALITY[q or 1] or X.QUALITY[1]) .. plainName .. "|r" .. tail)
      l:Show()
    else
      l:Hide()
    end
  end
  f.lootHead:SetText(#drops > X.LOOT and ("SEEN TO DROP  (%d OF %d)"):format(X.LOOT, #drops) or "SEEN TO DROP")
  f.noLoot:SetShown(#drops == 0)
  X.Set(f.noLoot, "Nothing seen to drop yet. Loot one and it is written here.", X.PAGE_W - 20)
end

-- ------------------------------------------------------------------ the tool

R:Register({
  name = "codex",
  short = "cdx",
  desc = "an illustrated book of creatures: their 3D models, abilities and what they drop",
  usage = "/bist codex [name | creature id]",
  -- new after 1.0: a save from before 1.0 never had it, so the 1.0 freeze must not write it ON (the pups lesson)
  defaultOff = true,
  slashWhenOff = true,              -- /bist codex is the player's own click: it switches the tool on, like the Hub
  options = {
    { kind = "button", label = "the Codex", button = "open",
      help = "The book: every dungeon's creatures in 3D, their abilities in the game's own words, and what you have seen them drop. While the tool is on it learns every creature you target or see.",
      action = function() X.Toggle(true) end },
  },
  OnInit = function(tool) C.tool = tool if R:Enabled("codex") then C.Listen(true) end end,
  OnEnable = function() C.Listen(true) end,
  OnDisable = function() C.Listen(false) if X.frame then X.frame:Hide() end end,
  OnOpen = function(_, _, recenter)
    if recenter then
      if X.frame then X.frame:ClearAllPoints() X.frame:SetPoint("CENTER") end
      return
    end
    X.Toggle(true)
  end,
  IsOpen = function() return X.IsOpen() end,
  OnClose = function() X.Toggle(false) end,
  OnSlash = function(_, _, args)
    if not R:Enabled("codex") then R:SetEnabled("codex", true) end
    args = tostring(args or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local id = tonumber(args)
    if id then
      local ok, why = X.Show(id)
      if not ok then NS.Print("codex: no creature %d in the book yet (%s)", id, tostring(why)) end
      return
    end
    if args ~= "" then
      X.Toggle(true)
      if X.frame.find then X.frame.find.box:SetText(args) X.frame.find.hint:Hide() end
      return X.Search(args)
    end
    X.Toggle()
  end,
})
