-- BiSTools / Tools / CodexDrive.lua - BiS> CODEX AFTER DARK, the book full screen (8 Nov 2026).
--
-- Arn: "make a full screen ryan gosling drive treatment for the codex" - and, on the mockup
-- (https://claude.ai/artifact/DzLLZ6FGb5XomQ1SiDkuPZ): "Build it". The family style (a night drive in a luxury cockpit).
-- You sit behind the wheel at night; the creature stands in your headlights on a wet road.
--   the credit        its name in pink over the night road, like an opening title; under it boss or not, where
--   the headlights    the creature in 3D (drag it to turn; the switches on the dash: TURN STAND ATTACK CAST DEATH)
--   rear-view mirror  the page before - click it to go back
--   sun visor         what it was seen to drop, clipped up like tickets (shift-click: link it)
--   the cluster       amber gauges: its level; how many of this place's bosses you have met; times met on the
--                     odometer; BOSS / ELITE / MET lamps; type, creature and model ids on the LCD
--   the radio         the index: the tuning band is A to Z (+ ?), the green display the search, the knobs turn the
--                     atlas's pages, the presets CONTENTS / DUNGEONS / RAIDS / INDEX
--   abilities         its spells: the shipped ones, then the ones seen cast (casts in a fight are hidden on Forever)
--   the road atlas    on the passenger seat: the dungeon's creatures on a dotted route in room order (or the
--                     contents, or an index page) - click one to drive to it
--   the key           turn it to close (Escape too). A fight closes it at once; it does not open in one.
-- It shares the book's place with the window (C.UI's view / dungeon / letter / sel): close it and the window opens
-- where you were, if it was open. One design size (DR.W x DR.H, 16:9, places in DR.U = 1% of the width) scaled to
-- the largest 16:9 that fits the screen, a dark backdrop round it - the Clipper Lounge's way (BiS Memories).
-- WHAT IT COSTS: nothing while closed. Open: the rain is one OnUpdate at DR.FPS (DR.DROPS textures moved), the
-- model is asked again only while it has not drawn (C.UI.Retry), and a turn or a drag is an OnUpdate only while on.
local _, NS = ...
local C = NS.Codex
local X = C.UI
local DR = {}
C.Drive = DR

DR.W, DR.H = 1600, 900               -- the design size, 16:9
DR.U = DR.W / 100                    -- one unit = 1% of the width
DR.FPS = 20                          -- the rain's frames a second
DR.DROPS = 28
DR.ROWS = 10                         -- lines on an atlas page
DR.HISTORY = 20                      -- pages the mirror remembers
DR.TICKETS = 3
DR.ABIL = 4
DR.TURN_SPEED = 0.9
DR.DRAG = 0.012                      -- radians a pixel of drag
DR.SKY_BANDS = 28
DR.LETTERS = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U",
               "V", "W", "X", "Y", "Z", "?" }
DR.SERIF = "Fonts\\MORPHEUS.TTF"
DR.NARROW = "Fonts\\ARIALN.TTF"
DR.ROUND = "Interface\\AddOns\\BiSTools\\Media\\Round"
DR.WHITE = "Interface\\Buttons\\WHITE8X8"     -- a Line is painted with this + a tint (bislint line-paint)
-- the night's colours (hex): our own, the mockup's
DR.INK = { night = "07060f", ink = "efe6ff", dim = "9a8fb8", faint = "5c5378", pink = "ff3fa4", cyan = "3ff4ff",
           amber = "ffb340", amberDim = "7a5520", sodium = "ff9a3c", leather = "1a1210", leather2 = "2a1d18",
           chrome = "c9c3d6", paper = "efe4c8", paperInk = "3b2a1e", paperSoft = "8a6a48", rubric = "b0215f",
           green = "5dff9b", lcd = "0f1a10", panel = "0d0a12", red = "ff4d4d", road = "0c0a14", city = "160c28",
           cityTop = "22123a", rain = "c8dcff", glass = "1a1530" }
-- the sky, top to bottom (a band each, blended between these stops)
DR.SKY = { { 0, "05040c" }, { 0.45, "140a2a" }, { 0.78, "3a1240" }, { 1, "ff5a8a" } }
DR.HORIZON = 34                      -- where the sky meets the road (units from the top)
-- the city: { left, width, height } in units, standing on the horizon; a few lit windows each
DR.CITY = { { 0, 4, 4 }, { 3.5, 3, 7 }, { 6.2, 2.5, 5 }, { 8.4, 4, 9.5 }, { 12, 2.8, 6 }, { 14.6, 3.4, 11 },
            { 17.8, 2.6, 7.5 }, { 20.2, 4.2, 5.5 }, { 24, 3, 12.5 }, { 26.8, 2.4, 8 }, { 29, 3.6, 6.5 }, { 32.4, 2.8, 10 },
            { 35, 4, 7 }, { 38.8, 3, 5 }, { 61, 3.4, 6 }, { 64.2, 2.6, 9 }, { 66.6, 4, 13 }, { 70.4, 3, 7 },
            { 73.2, 2.8, 10.5 }, { 75.8, 3.8, 6 }, { 79.4, 2.6, 8.5 }, { 81.8, 4, 11.5 }, { 85.6, 3, 7.5 },
            { 88.4, 2.8, 5.5 }, { 91, 3.6, 9 }, { 94.4, 2.8, 6.5 }, { 97, 3, 8 } }
DR.LAMPS = { { 20, 30.4 }, { 27, 31.6 }, { 33, 32.8 }, { 80, 30.4 }, { 73, 31.6 }, { 67, 32.8 } }
-- the route on the atlas: where each of a page's dots sits (fractions of the strip)
DR.ROUTE = { { 0.04, 0.75 }, { 0.15, 0.3 }, { 0.26, 0.62 }, { 0.37, 0.25 }, { 0.48, 0.55 }, { 0.59, 0.2 },
             { 0.70, 0.6 }, { 0.80, 0.3 }, { 0.89, 0.7 }, { 0.97, 0.35 } }

local function fighting() return (InCombatLockdown and InCombatLockdown()) and true or false end
local function K() return NS.Farm end
local function rgb(hex)
  hex = DR.INK[hex] or hex
  return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end
local function px(u) return u * DR.U end

--- Pin a region: (x, y) units from the parent's top left, w x h units (either may be nil: keep its size).
local function at(r, parent, x, y, w, h)
  r:ClearAllPoints()
  r:SetPoint("TOPLEFT", parent, "TOPLEFT", px(x), -px(y))
  if w and h then r:SetSize(px(w), px(h)) end
  return r
end

local function fill(parent, layer, hex, a)
  local t = parent:CreateTexture(nil, layer)
  local r, g, b = rgb(hex)
  t:SetColorTexture(r, g, b, a or 1)
  return t
end

local function round(parent, layer, hex, a)
  local t = parent:CreateTexture(nil, layer)
  t:SetTexture(DR.ROUND)
  local r, g, b = rgb(hex)
  t:SetVertexColor(r, g, b, a or 1)
  return t
end

local function fs(parent, size, hex, face, justify)
  local s = parent:CreateFontString(nil, "OVERLAY")
  s:SetFont(face or STANDARD_TEXT_FONT, size, "")
  s:SetTextColor(rgb(hex or "ink"))
  if justify then s:SetJustifyH(justify) end
  s:SetWordWrap(false)
  return s
end

--- Words cut to fit `w` pixels at `size` (the window's own measure, so the suite's widths agree).
local function set(s, text, size, w)
  s:SetText(X.Trim(text or "", size, w))
end

--- A big line (a title, the credit): the largest size from `big` down to `small` at which it fits whole; cut at `small`.
local function shrink(s, text, face, big, small, w)
  local size = big
  while size > small and X.Width(text, size) > w do size = size - 2 end
  s:SetFont(face, size, "")
  s:SetText(X.Trim(text or "", size, w))
  return size
end

--- A frame edge: four strips of one colour.
local function edge(f, hex, a, t)
  t = t or 1
  local out = {}
  for i, spec in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                          { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
    local s = fill(f, "BORDER", hex, a)
    s:SetPoint(spec[1]) s:SetPoint(spec[2])
    if spec[3] then s:SetHeight(t) else s:SetWidth(t) end
    out[i] = s
  end
  return out
end

--- THE POP (the family rule): a wash and a bar down the left edge under the mouse; b.keep = the picked one stays lit.
local function pop(b)
  local k = K()
  b.wash = k.tex(b, "ARTWORK", "accent", 0.35)
  b.wash:SetAlpha(0)
  local r, g, bl = k.color("accent")
  b.bar = b:CreateTexture(nil, "OVERLAY")
  b.bar:SetColorTexture(r, g, bl, 1)
  b.bar:SetPoint("TOPLEFT") b.bar:SetPoint("BOTTOMLEFT") b.bar:SetWidth(3)
  b.bar:SetAlpha(0)
  function b:Pop(on)
    self.hover = on and true or false
    self.wash:SetAlpha(on and 1 or (self.keep and 0.4 or 0))
    self.bar:SetAlpha((on or self.keep) and 1 or 0)
  end
end

local function hoverTip(b, anchor)
  b:SetScript("OnEnter", function(self)
    if self.Pop then self:Pop(true) end
    local tip = self.tip
    if type(tip) == "function" then tip = tip(self) end
    if tip and GameTooltip then
      GameTooltip:SetOwner(self, anchor or "ANCHOR_TOP")
      for i, line in ipairs(type(tip) == "table" and tip or { tip }) do
        if i == 1 then GameTooltip:AddLine(line) else GameTooltip:AddLine(line, 1, 1, 1, true) end
      end
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function(self) if self.Pop then self:Pop(false) end if GameTooltip then GameTooltip:Hide() end end)
end

--- A dash switch / preset: chrome-grey, lit = pink with white words.
local function key(parent, label, w, h, onclick, tip, size)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(px(w), px(h))
  b.bg = fill(b, "BACKGROUND", "2e2938", 1)
  b.bg:SetAllPoints()
  b.foot = fill(b, "BORDER", "000000", 1)
  b.foot:SetPoint("BOTTOMLEFT") b.foot:SetPoint("BOTTOMRIGHT") b.foot:SetHeight(3)
  b.shine = fill(b, "BORDER", "4a4456", 1)
  b.shine:SetPoint("TOPLEFT") b.shine:SetPoint("TOPRIGHT") b.shine:SetHeight(2)
  pop(b)
  b.size = size or 13
  b.label = fs(b, b.size, "dim", DR.NARROW, "CENTER")
  b.label:SetPoint("CENTER", 0, 0)
  b.label:SetText(label)
  b.tip = tip
  function b:Lit(on)
    self.on = on and true or false
    local r, g, bl = rgb(self.on and "pink" or "2e2938")
    self.bg:SetColorTexture(r, g, bl, 1)
    self.label:SetTextColor(rgb(self.on and "ffffff" or "dim"))
  end
  b:SetScript("OnClick", function(self) if onclick then onclick(self) end end)
  hoverTip(b)
  return b
end

-- ------------------------------------------------------------------ where am I (the book's place, shared)

--- The creature on the road: the book's pick, else the first of its dungeon, else the book's first.
function DR.Current()
  if type(X.sel) == "number" and C.Creature(X.sel) then return X.sel end
  local d = X.dungeon and C.DATA.dungeons[X.dungeon]
  if d and d.list[1] then return d.list[1] end
  local all = C.All()
  return all[1]
end

--- Drive to a creature: the last one goes into the mirror. In a dungeon's atlas its dungeon follows it.
function DR.Pick(npc, noHistory)
  if type(npc) ~= "number" then return end
  local was = DR.Current()
  if not noHistory and was and was ~= npc then
    table.insert(DR.history, 1, was)
    DR.history[DR.HISTORY + 1] = nil
  end
  X.sel = npc
  local s = C.DATA.creatures[npc]
  if X.view == "dungeon" and s and s.d ~= X.dungeon then X.dungeon, DR.page = s.d, nil end
  if DR.hero then DR.hero.anim = nil DR.Spin(false) end
  DR.Paint()
end

function DR.Back()
  local npc = table.remove(DR.history, 1)
  if npc then DR.Pick(npc, true) end
end

function DR.OpenDungeon(d)
  local dd = C.DATA.dungeons[d]
  if not dd then return end
  X.view, X.dungeon, DR.page = "dungeon", d, nil
  local first = dd.list[1]
  for _, npc in ipairs(dd.list) do
    local s = C.DATA.creatures[npc]
    if s and s.boss then first = npc break end
  end
  DR.Pick(first)
end

function DR.Volume(id)
  for _, v in ipairs(C.DATA.volumes) do
    if v.id == id and v.list[1] then return DR.OpenDungeon(v.list[1]) end
  end
end

function DR.Contents()
  X.view, DR.page = "contents", nil
  DR.Paint()
end

function DR.Index(letter, search)
  X.view, X.letter, X.search, DR.page = "index", letter or X.letter or "A", search, nil
  C.Warm(C.All())
  DR.Paint()
end

function DR.Search(text)
  text = tostring(text or "")
  if text:gsub("%s", "") == "" then return DR.Index(X.letter or "A") end
  return DR.Index(X.letter or "A", text)
end

--- The atlas's lines for the place you are in: { npc | dungeon, text, right, head }.
function DR.Lines()
  local out = {}
  if X.view == "contents" then
    for _, v in ipairs(C.DATA.volumes) do
      for _, d in ipairs(v.list) do
        local dd = C.DATA.dungeons[d]
        out[#out + 1] = { dungeon = d, text = dd.name, right = "lvl " .. dd.level }
      end
    end
  elseif X.view == "index" then
    for _, npc in ipairs(C.Index(X.letter or "A", X.search)) do
      local c = C.Creature(npc)
      local dd = c and c.dungeon and C.DATA.dungeons[c.dungeon]
      out[#out + 1] = { npc = npc, text = (c and c.name) or ("creature " .. npc), right = dd and dd.title or "the wild" }
    end
  else
    local dd = X.dungeon and C.DATA.dungeons[X.dungeon]
    for i, npc in ipairs(dd and dd.list or {}) do
      local c = C.Creature(npc)
      local name = (c and c.name) or C.Name(npc) or ("creature " .. npc)
      out[#out + 1] = { npc = npc, n = i, text = name, boss = c and c.boss,
                        right = (c and c.boss) and "BOSS" or ((c and c.met > 0) and "met" or "") }
    end
  end
  return out
end

--- The atlas's page: the one holding the creature on the road, until the knobs turn it.
function DR.Pages(lines) return math.max(1, math.ceil(#lines / DR.ROWS)) end

function DR.PageOf(lines)
  if DR.page then return math.max(1, math.min(DR.page, DR.Pages(lines))) end
  local cur = DR.Current()
  for i, e in ipairs(lines) do
    if (e.npc and e.npc == cur) or (e.dungeon and e.dungeon == X.dungeon) then return math.ceil(i / DR.ROWS) end
  end
  return 1
end

function DR.Turn(dir)
  local lines = DR.Lines()
  DR.page = math.max(1, math.min(DR.PageOf(lines) + dir, DR.Pages(lines)))
  DR.Paint()
end

-- ------------------------------------------------------------------ the 3D on the road

function DR.Spin(on)
  local m = DR.hero
  DR.spinning = on and true or false
  if not m then return end
  if DR.spinning then
    m:SetScript("OnUpdate", function(self, dt)
      self.face = ((self.face or 0) + (dt or 0) * DR.TURN_SPEED) % (2 * math.pi)
      pcall(self.SetFacing, self, self.face)
    end)
  else
    m:SetScript("OnUpdate", nil)
  end
  if DR.pose and DR.pose.TURN then DR.pose.TURN:Lit(DR.spinning) end
end

function DR.Animate(name)
  local m = DR.hero
  if name == "TURN" then return DR.Spin(not DR.spinning) end
  if not m then return end
  m.anim = X.ANIM[name] or 0
  if m.SetAnimation then pcall(m.SetAnimation, m, m.anim) end
  for k, b in pairs(DR.pose) do if k ~= "TURN" then b:Lit(k == name) end end
end

-- drag to turn: an OnUpdate only while the button is down
local function dragStart(m)
  if DR.spinning then DR.Spin(false) end
  local x0 = GetCursorPosition()
  local f0 = m.face or 0
  m:SetScript("OnUpdate", function(self)
    local x = GetCursorPosition()
    self.face = (f0 + (x - x0) * DR.DRAG) % (2 * math.pi)
    pcall(self.SetFacing, self, self.face)
  end)
end
local function dragStop(m) m:SetScript("OnUpdate", nil) end

-- ------------------------------------------------------------------ building

local function buildNight(room)
  -- the sky, in bands blended between DR.SKY's stops
  local h = DR.HORIZON / DR.SKY_BANDS
  for i = 1, DR.SKY_BANDS do
    local t = (i - 0.5) / DR.SKY_BANDS
    local a, b = DR.SKY[1], DR.SKY[#DR.SKY]
    for j = 1, #DR.SKY - 1 do
      if t >= DR.SKY[j][1] and t <= DR.SKY[j + 1][1] then a, b = DR.SKY[j], DR.SKY[j + 1] end
    end
    local k = (t - a[1]) / math.max(0.0001, b[1] - a[1])
    local r1, g1, b1 = rgb(a[2])
    local r2, g2, b2 = rgb(b[2])
    local band = room:CreateTexture(nil, "BACKGROUND")
    band:SetColorTexture(r1 + (r2 - r1) * k, g1 + (g2 - g1) * k, b1 + (b2 - b1) * k, 1)
    at(band, room, 0, (i - 1) * h, 100, h + 0.05)
  end
  -- the city on the horizon, a few windows lit
  local city = CreateFrame("Frame", nil, room)
  at(city, room, 0, 0, 100, DR.HORIZON)
  for i, b in ipairs(DR.CITY) do
    local t = fill(city, "BORDER", (i % 3 == 0) and "cityTop" or "city", 1)
    at(t, city, b[1], DR.HORIZON - b[3], b[2], b[3])
    for w = 1, 2 do
      local lit = fill(city, "ARTWORK", (i + w) % 5 == 0 and "pink" or "amber", 0.55)
      at(lit, city, b[1] + b[2] * (0.25 + 0.35 * (w - 1)), DR.HORIZON - b[3] * (0.75 - 0.3 * (w - 1)), 0.25, 0.25)
    end
  end
  -- the road, and the headlights on it
  local road = fill(room, "BORDER", "road", 1)
  at(road, room, 0, DR.HORIZON, 100, 56.25 - DR.HORIZON)
  for _, x in ipairs({ 27, 43 }) do
    local beam = round(room, "ARTWORK", "fff0c8", 0.16)
    beam:SetBlendMode("ADD")
    at(beam, room, x, 24, 30, 15)
  end
  -- the sodium lamps
  for _, l in ipairs(DR.LAMPS) do
    local glow = round(room, "ARTWORK", "sodium", 0.35)
    glow:SetBlendMode("ADD")
    at(glow, room, l[1] - 1.2, l[2] - 1.2, 2.4, 2.4)
    local dot = round(room, "ARTWORK", "sodium", 1)
    at(dot, room, l[1] - 0.25, l[2] - 0.25, 0.5, 0.5)
  end
end

local function buildRain(room)
  local rain = CreateFrame("Frame", nil, room)
  at(rain, room, 0, 0, 100, DR.HORIZON + 3)
  rain:SetFrameLevel(room:GetFrameLevel() + 6)
  DR.rain = rain
  DR.drops = {}
  for i = 1, DR.DROPS do
    local d = fill(rain, "OVERLAY", "rain", 0.32)
    d.x = ((i * 37) % 100)
    d.y = ((i * 53) % math.floor(DR.HORIZON))
    d.v = 18 + (i % 5) * 4                 -- units a second
    at(d, rain, d.x, d.y, 0.1, 0.8)
    DR.drops[i] = d
  end
  local acc = 0
  rain.tick = function(_, dt)
    acc = acc + (dt or 0)
    if acc < 1 / DR.FPS then return end
    for _, d in ipairs(DR.drops) do
      d.y = d.y + d.v * acc
      if d.y > DR.HORIZON + 2 then d.y = d.y - DR.HORIZON - 2 d.x = (d.x + 41) % 100 end
      d:ClearAllPoints()
      d:SetPoint("TOPLEFT", rain, "TOPLEFT", px(d.x), -px(d.y))
    end
    acc = 0
  end
end

local function buildFrame(room)
  -- the roof and the pillars' shadow: dark bands at the edges of the glass
  at(fill(room, "ARTWORK", "000000", 1), room, 0, 0, 100, 1.4)
  for i = 1, 6 do
    local a = 0.9 - (i - 1) * 0.15
    at(fill(room, "ARTWORK", "000000", a), room, (i - 1) * 0.8, 0, 0.8, DR.HORIZON + 3)
    at(fill(room, "ARTWORK", "000000", a), room, 100 - i * 0.8, 0, 0.8, DR.HORIZON + 3)
  end
end

local function buildCredit(room)
  local c = CreateFrame("Frame", nil, room)
  at(c, room, 6, 5, 36, 10)
  c:SetFrameLevel(room:GetFrameLevel() + 8)
  c.name = fs(c, 64, "pink", DR.SERIF, "LEFT")
  c.name:SetPoint("TOPLEFT", 0, 0)
  c.glow = fs(c, 64, "pink", DR.SERIF, "LEFT")
  c.glow:SetPoint("TOPLEFT", 2, -2)
  c.glow:SetAlpha(0.25)
  c.sub = fs(c, 17, "ink", DR.NARROW, "LEFT")
  c.sub:SetPoint("TOPLEFT", 4, -px(5.4))
  DR.credit = c
end

local function buildHero(room)
  local ok, m = pcall(CreateFrame, "DressUpModel", "BiSToolsCodexDriveModel", room)
  if not ok or not m then return end
  at(m, room, 36, 7, 28, 32)
  m:SetFrameLevel(room:GetFrameLevel() + 5)
  m:EnableMouse(true)
  m:SetScript("OnMouseDown", dragStart)
  m:SetScript("OnMouseUp", dragStop)
  DR.hero = m
  X.models = X.models or {}
  X.models[#X.models + 1] = m
  local tag = fs(room, 12, "cyan", DR.NARROW, "CENTER")
  tag:SetPoint("TOP", room, "TOPLEFT", px(50), -px(35))
  tag:SetText("DRAG TO TURN")
  tag:SetAlpha(0.6)
  DR.tag = tag
end

local function buildMirror(room)
  local b = CreateFrame("Button", nil, room)
  at(b, room, 40, 1.2, 20, 5)
  b:SetFrameLevel(room:GetFrameLevel() + 9)
  fill(b, "BACKGROUND", "glass", 1):SetAllPoints()
  edge(b, "3a3644", 1, 4)
  pop(b)
  b.back = fs(b, 13, "dim", DR.NARROW, "LEFT")
  b.back:SetPoint("LEFT", px(1.2), 0)
  b.back:SetText("< BACK")
  b.who = fs(b, 18, "ink", DR.NARROW, "LEFT")
  b.who:SetPoint("LEFT", px(5.6), px(0.6))
  b.sub = fs(b, 11, "faint", DR.NARROW, "LEFT")
  b.sub:SetPoint("LEFT", px(5.6), -px(1.2))
  b:SetScript("OnClick", function() DR.Back() end)
  b.tip = function() return DR.history[1] and { "The page before", "click: back to it" } or { "Nothing behind you yet" } end
  hoverTip(b, "ANCHOR_BOTTOM")
  DR.mirror = b
end

local function buildVisor(room)
  local v = CreateFrame("Frame", nil, room)
  at(v, room, 69, 2.2, 25, 8)
  v:SetFrameLevel(room:GetFrameLevel() + 9)
  fill(v, "BACKGROUND", "leather2", 1):SetAllPoints()
  local seam = fill(v, "BORDER", "amberDim", 0.6)
  seam:SetPoint("BOTTOMLEFT", px(0.6), px(0.5)) seam:SetPoint("BOTTOMRIGHT", -px(0.6), px(0.5)) seam:SetHeight(1)
  v.lbl = fs(v, 11, "faint", DR.NARROW, "LEFT")
  v.lbl:SetPoint("BOTTOMLEFT", px(0.8), px(0.8))
  v.lbl:SetText("SEEN TO DROP")
  v.tickets = {}
  for i = 1, DR.TICKETS do
    local t = CreateFrame("Button", nil, v)
    at(t, v, 0.8 + (i - 1) * 8, 0.9 - (i % 2) * 0.3, 7.4, 4.6)
    fill(t, "BACKGROUND", "paper", 1):SetAllPoints()
    local clip = fill(t, "BORDER", "chrome", 1)
    clip:SetPoint("TOP", 0, px(0.4)) clip:SetSize(px(1.4), px(0.9))
    pop(t)
    t.name = fs(t, 13, "paperInk", nil, "LEFT")
    t.name:SetPoint("TOPLEFT", px(0.5), -px(0.9))
    t.sub = fs(t, 10, "paperSoft", DR.NARROW, "LEFT")
    t.sub:SetPoint("TOPLEFT", px(0.5), -px(2.7))
    t:SetScript("OnClick", function(self)
      if not self.item then return end
      if IsShiftKeyDown and IsShiftKeyDown() and self.link and _G.ChatEdit_InsertLink then _G.ChatEdit_InsertLink(self.link) end
    end)
    t:SetScript("OnEnter", function(self)
      self:Pop(true)
      if not (self.item and GameTooltip) then return end
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      -- by its link (SetItemByID is not on Forever's client - the fence); no link yet: its name
      if self.link and GameTooltip.SetHyperlink then GameTooltip:SetHyperlink(self.link) else GameTooltip:AddLine(self.name:GetText() or "") end
      GameTooltip:AddLine("shift-click: link it", 1, 1, 1)
      GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function(self) self:Pop(false) if GameTooltip then GameTooltip:Hide() end end)
    v.tickets[i] = t
  end
  v.none = fs(v, 13, "dim", DR.NARROW, "LEFT")
  v.none:SetPoint("TOPLEFT", px(1), -px(1.4))
  DR.visor = v
end

--- A round amber gauge: ticks, numbers and a needle (Lines), `min`..`max` over 240 degrees.
local function gauge(parent, x, y, d, title, marks)
  local g = CreateFrame("Frame", nil, parent)
  at(g, parent, x, y, d, d)
  local face = round(g, "BACKGROUND", "chrome", 1)
  face:SetAllPoints()
  local inner = round(g, "BORDER", "panel", 1)
  inner:SetPoint("TOPLEFT", px(0.35), -px(0.35)) inner:SetPoint("BOTTOMRIGHT", -px(0.35), px(0.35))
  local r = px(d) / 2
  g.r = r
  g.marks = marks
  local n = #marks
  for i, mk in ipairs(marks) do
    local a = math.rad(-120 + 240 * (i - 1) / (n - 1))
    local s, c = math.sin(a), math.cos(a)
    local tick = g:CreateLine(nil, "ARTWORK")
    tick:SetTexture(DR.WHITE)
    tick:SetVertexColor(rgb("amber"))
    tick:SetThickness(2)
    tick:SetStartPoint("CENTER", g, s * r * 0.70, c * r * 0.70)
    tick:SetEndPoint("CENTER", g, s * r * 0.84, c * r * 0.84)
    local lbl = fs(g, 12, "amber", nil, "CENTER")
    lbl:SetPoint("CENTER", g, "CENTER", s * r * 0.55, c * r * 0.55)
    lbl:SetText(tostring(mk))
  end
  g.needle = g:CreateLine(nil, "OVERLAY")
  g.needle:SetTexture(DR.WHITE)
  g.needle:SetVertexColor(rgb("pink"))
  g.needle:SetThickness(3)
  local hub = round(g, "OVERLAY", "chrome", 1)
  hub:SetPoint("CENTER") hub:SetSize(px(0.9), px(0.9))
  g.value = fs(g, 20, "ink", nil, "CENTER")
  g.value:SetPoint("CENTER", 0, -r * 0.42)
  g.title = fs(g, 12, "amber", DR.NARROW, "CENTER")
  g.title:SetPoint("TOP", g, "BOTTOM", 0, -px(0.3))
  g.title:SetText(title)
  function g:Point(frac)
    frac = math.max(0, math.min(1, frac or 0))
    local a = math.rad(-120 + 240 * frac)
    self.needle:SetStartPoint("CENTER", self, 0, 0)
    self.needle:SetEndPoint("CENTER", self, math.sin(a) * self.r * 0.78, math.cos(a) * self.r * 0.78)
    self.frac = frac
  end
  g:Point(0)
  return g
end

local function buildDash(room)
  local dash = CreateFrame("Frame", nil, room)
  at(dash, room, 0, 37, 100, 19.25)
  dash:SetFrameLevel(room:GetFrameLevel() + 10)
  DR.dash = dash
  fill(dash, "BACKGROUND", "leather", 1):SetAllPoints()
  local top = fill(dash, "BORDER", "leather2", 1)
  top:SetPoint("TOPLEFT") top:SetPoint("TOPRIGHT") top:SetHeight(px(3))
  local lip = fill(dash, "BORDER", "3a2a22", 1)
  lip:SetPoint("TOPLEFT") lip:SetPoint("TOPRIGHT") lip:SetHeight(3)
  for i = 0, 48 do     -- the stitching
    at(fill(dash, "ARTWORK", "amber", 0.22), dash, 2 + i * 2, 1, 1, 0.12)
  end
  return dash
end

local function buildCluster(dash)
  local cl = CreateFrame("Frame", nil, dash)
  at(cl, dash, 5, 3, 41, 15.6)
  fill(cl, "BACKGROUND", "panel", 1):SetAllPoints()
  edge(cl, "241b18", 1, 4)
  DR.level = gauge(cl, 1.6, 0.8, 11.5, "LEVEL", { 0, 10, 20, 30, 40, 50, 60 })
  DR.place = gauge(cl, 27.9, 0.8, 11.5, "BOSSES MET HERE", { 0, "", "", "", "ALL" })
  -- the odometer: times met
  DR.odo = {}
  for i = 1, 4 do
    local box = fill(cl, "BORDER", i == 4 and "c22222" or "ece4d4", 1)
    at(box, cl, 15.4 + (i - 1) * 2.6, 1.4, 2.3, 2.8)
    local digit = fs(cl, 22, i == 4 and "ffffff" or "111111", nil, "CENTER")
    digit:SetPoint("CENTER", box, "CENTER", 0, 0)
    DR.odo[i] = digit
  end
  local cap = fs(cl, 11, "dim", DR.NARROW, "CENTER")
  cap:SetPoint("TOP", cl, "TOPLEFT", px(20.5), -px(4.6))
  cap:SetText("TIMES MET")
  -- the lamps
  DR.lamps = {}
  for i, word in ipairs({ "BOSS", "ELITE", "MET" }) do
    local l = CreateFrame("Frame", nil, cl)
    at(l, cl, 14.6 + (i - 1) * 4.1, 6.4, 3.7, 1.7)
    l.bg = fill(l, "BACKGROUND", "0e0b12", 1)
    l.bg:SetAllPoints()
    edge(l, "241e2c", 1, 1)
    l.word = fs(l, 11, "2a2230", DR.NARROW, "CENTER")
    l.word:SetPoint("CENTER")
    l.word:SetText(word)
    l.hex = ({ "pink", "amber", "green" })[i]
    function l:Lit(on)
      local r, g, b = rgb(on and self.hex or "0e0b12")
      self.bg:SetColorTexture(r, g, b, 1)
      self.word:SetTextColor(rgb(on and "07060f" or "2a2230"))
    end
    DR.lamps[word] = l
  end
  -- the LCD
  local lcd = CreateFrame("Frame", nil, cl)
  at(lcd, cl, 13.8, 9, 13.4, 2.4)
  fill(lcd, "BACKGROUND", "lcd", 1):SetAllPoints()
  DR.lcd1 = fs(lcd, 13, "green", nil, "CENTER")
  DR.lcd1:SetPoint("CENTER", 0, 0)
  local lcd2 = CreateFrame("Frame", nil, cl)
  at(lcd2, cl, 13.8, 11.8, 13.4, 2.4)
  fill(lcd2, "BACKGROUND", "lcd", 1):SetAllPoints()
  DR.lcd2 = fs(lcd2, 13, "cyan", nil, "CENTER")
  DR.lcd2:SetPoint("CENTER", 0, 0)
  -- the pose switches, along the top of the dash
  DR.pose = {}
  for i, pk in ipairs(X.ANIM_KEYS) do
    local name = pk[1]
    local b = key(dash, name, 5.6, 1.9, function() DR.Animate(name) end,
      name == "TURN" and "Spin it round (or drag it)" or ("Play: " .. name:lower()), 12)
    b:SetPoint("TOPLEFT", dash, "TOPLEFT", px(9 + (i - 1) * 6.3), -px(0.6))
    DR.pose[name] = b
  end
end

local function buildRadio(dash)
  local rd = CreateFrame("Frame", nil, dash)
  at(rd, dash, 49, 2.6, 27, 10.8)
  fill(rd, "BACKGROUND", "1c1922", 1):SetAllPoints()
  edge(rd, "chrome", 1, 3)
  DR.radio = rd
  -- the band: A to Z (+ ?), each a click
  local band = CreateFrame("Frame", nil, rd)
  at(band, rd, 0.8, 0.8, 25.4, 2.8)
  fill(band, "BACKGROUND", "120c18", 1):SetAllPoints()
  DR.band = band
  DR.letters = {}
  local w = 25.4 / #DR.LETTERS
  for i, l in ipairs(DR.LETTERS) do
    local b = CreateFrame("Button", nil, band)
    at(b, band, (i - 1) * w, 0, w, 2.8)
    b.label = fs(b, 13, "amberDim", nil, "CENTER")
    b.label:SetPoint("BOTTOM", 0, px(0.3))
    b.label:SetText(l)
    b.letter = l
    b:SetScript("OnClick", function(self) DR.Index(self.letter) end)
    b:SetScript("OnEnter", function(self) self.label:SetTextColor(rgb("ffffff")) end)
    b:SetScript("OnLeave", function(self) self.label:SetTextColor(rgb(self.on and "amber" or "amberDim")) end)
    DR.letters[i] = b
  end
  DR.needle = fill(band, "OVERLAY", "red", 1)
  DR.needle:SetSize(2, px(2.2))
  -- the knobs (the atlas's pages) and the search between them
  local function knob(x, dir, tip)
    local b = CreateFrame("Button", nil, rd)
    at(b, rd, x, 4.2, 2.8, 2.8)
    local face = round(b, "ARTWORK", "8a8494", 1)
    face:SetAllPoints()
    local shine = round(b, "OVERLAY", "eeeeee", 0.55)
    shine:SetPoint("TOPLEFT", px(0.5), -px(0.4)) shine:SetSize(px(1), px(1))
    b.mark = fs(b, 14, "07060f", nil, "CENTER")
    b.mark:SetPoint("CENTER")
    b.mark:SetText(dir < 0 and "<" or ">")
    pop(b)
    b.tip = tip
    b:SetScript("OnClick", function() DR.Turn(dir) end)
    hoverTip(b)
    return b
  end
  DR.knobL = knob(0.8, -1, "the atlas: the page before")
  DR.knobR = knob(23.4, 1, "the atlas: the next page")
  local well = CreateFrame("Frame", nil, rd)
  at(well, rd, 4.2, 4.5, 18.6, 2.2)
  fill(well, "BACKGROUND", "lcd", 1):SetAllPoints()
  local eb = CreateFrame("EditBox", "BiSToolsCodexDriveSearch", well)
  eb:SetAllPoints()
  eb:SetTextInsets(8, 8, 0, 0)
  eb:SetFont(STANDARD_TEXT_FONT, 14, "")
  eb:SetAutoFocus(false)
  eb:SetMaxLetters(40)
  eb:SetTextColor(rgb("green"))
  local ph = fs(well, 13, "2f6a45", nil, "LEFT")
  ph:SetPoint("LEFT", 8, 0)
  ph:SetText("search a name")
  eb:SetScript("OnEditFocusGained", function() ph:Hide() end)
  eb:SetScript("OnEditFocusLost", function(self) if (self:GetText() or "") == "" then ph:Show() end end)
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  eb:SetScript("OnTextChanged", function(self, user) if user then DR.Search(self:GetText()) end end)
  DR.find = { box = eb, hint = ph }
  -- the presets
  DR.presets = {}
  for i, p in ipairs({ { "CONTENTS", function() DR.Contents() end }, { "DUNGEONS", function() DR.Volume("dungeons") end },
                       { "RAIDS", function() DR.Volume("raids") end }, { "INDEX", function() DR.Index(X.letter or "A") end } }) do
    local b = key(rd, p[1], 6, 2.2, p[2], nil, 12)
    b:SetPoint("TOPLEFT", rd, "TOPLEFT", px(0.8 + (i - 1) * 6.45), -px(7.8))
    DR.presets[p[1]] = b
  end
end

local function buildAbilities(dash)
  local ab = CreateFrame("Frame", nil, dash)
  at(ab, dash, 49, 14, 27, 4.6)
  fill(ab, "BACKGROUND", "0b0910", 1):SetAllPoints()
  edge(ab, "2e2738", 1, 2)
  ab.head = fs(ab, 11, "cyan", DR.NARROW, "LEFT")
  ab.head:SetPoint("TOPLEFT", px(0.8), -px(0.4))
  ab.rows = {}
  for i = 1, DR.ABIL do
    local r = CreateFrame("Button", nil, ab)
    at(r, ab, 0.6 + ((i - 1) % 2) * 13.2, 1.5 + math.floor((i - 1) / 2) * 1.5, 12.8, 1.4)
    pop(r)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetPoint("LEFT", 2, 0)
    r.icon:SetSize(px(1.2), px(1.2))
    r.name = fs(r, 13, "ink", nil, "LEFT")
    r.name:SetPoint("LEFT", px(1.6), 0)
    hoverTip(r)
    ab.rows[i] = r
  end
  ab.none = fs(ab, 12, "dim", DR.NARROW, "LEFT")
  ab.none:SetPoint("TOPLEFT", px(0.8), -px(1.8))
  DR.abil = ab
end

local function buildKey(dash)
  local b = CreateFrame("Button", nil, dash)
  at(b, dash, 46.4, 14.2, 2.4, 2.4)
  local ring = round(b, "ARTWORK", "chrome", 1)
  ring:SetAllPoints()
  local hole = round(b, "OVERLAY", "2a2530", 1)
  hole:SetPoint("CENTER") hole:SetSize(px(1.4), px(1.4))
  local blade = fill(b, "OVERLAY", "d8d2e4", 1)
  blade:SetPoint("CENTER") blade:SetSize(px(0.35), px(1.6))
  blade:SetRotation(math.rad(35))
  pop(b)
  b.tip = { "Turn the key", "close the full screen (Escape does too)" }
  b:SetScript("OnClick", function() DR.Close() end)
  hoverTip(b)
  local lbl = fs(dash, 10, "faint", DR.NARROW, "CENTER")
  lbl:SetPoint("TOP", b, "BOTTOM", 0, -2)
  lbl:SetText("KEY")
  DR.key = b
end

local function buildAtlas(room)
  local a = CreateFrame("Frame", nil, room)
  at(a, room, 77.5, 26.5, 20.5, 28.4)
  a:SetFrameLevel(room:GetFrameLevel() + 20)
  local shade = fill(a, "BACKGROUND", "000000", 0.55)
  shade:SetPoint("TOPLEFT", px(0.4), -px(0.6)) shade:SetPoint("BOTTOMRIGHT", px(0.6), -px(0.6))
  local paper = fill(a, "BORDER", "paper", 1)
  paper:SetAllPoints()
  local lampGlow = round(a, "ARTWORK", "fff2c0", 0.28)
  lampGlow:SetBlendMode("ADD")
  at(lampGlow, a, 2, -2, 14, 12)
  a.hdL = fs(a, 11, "paperSoft", DR.NARROW, "LEFT")
  a.hdL:SetPoint("TOPLEFT", px(1.1), -px(0.9))
  a.hdR = fs(a, 11, "paperSoft", DR.NARROW, "RIGHT")
  a.hdR:SetPoint("TOPRIGHT", -px(1.1), -px(0.9))
  a.title = fs(a, 30, "rubric", DR.SERIF, "LEFT")
  a.title:SetPoint("TOPLEFT", px(1.1), -px(2.1))
  a.about = fs(a, 13, "5a4634", nil, "LEFT")
  a.about:SetPoint("TOPLEFT", px(1.1), -px(4.6))
  a.about:SetWidth(px(18.3))
  a.about:SetWordWrap(true)
  -- the route: a page's creatures as numbered dots
  local route = CreateFrame("Frame", nil, a)
  at(route, a, 1.1, 8, 18.3, 4.2)
  a.route = route
  a.dots = {}
  for i = 1, DR.ROWS do
    local p = DR.ROUTE[i]
    local dot = CreateFrame("Button", nil, route)
    dot:SetSize(px(1.25), px(1.25))
    dot:SetPoint("CENTER", route, "TOPLEFT", p[1] * px(18.3), -p[2] * px(4.2))
    dot.face = round(dot, "ARTWORK", "paperInk", 1)
    dot.face:SetAllPoints()
    dot.n = fs(dot, 11, "paper", nil, "CENTER")
    dot.n:SetPoint("CENTER", 0, 0)
    dot:SetScript("OnClick", function(self) if self.npc then DR.Pick(self.npc) end end)
    a.dots[i] = dot
    if i > 1 then
      local q = DR.ROUTE[i - 1]
      local seg = route:CreateLine(nil, "BORDER")
      seg:SetTexture(DR.WHITE)
      seg:SetVertexColor(rgb("rubric"))
      seg:SetAlpha(0.45)
      seg:SetThickness(2)
      seg:SetStartPoint("TOPLEFT", route, q[1] * px(18.3), -q[2] * px(4.2))
      seg:SetEndPoint("TOPLEFT", route, p[1] * px(18.3), -p[2] * px(4.2))
      dot.seg = seg
    end
  end
  -- the lines
  a.rows = {}
  for i = 1, DR.ROWS do
    local r = CreateFrame("Button", nil, a)
    at(r, a, 0.6, 12.6 + (i - 1) * 1.38, 19.3, 1.32)
    pop(r)
    r.num = fs(r, 12, "paperSoft", nil, "RIGHT")
    r.num:SetPoint("LEFT", 0, 0)
    r.num:SetWidth(px(1.5))
    r.name = fs(r, 14, "paperInk", nil, "LEFT")
    r.name:SetPoint("LEFT", px(1.9), 0)
    r.right = fs(r, 11, "paperSoft", DR.NARROW, "RIGHT")
    r.right:SetPoint("RIGHT", -px(0.4), 0)
    r:SetScript("OnClick", function(self)
      local e = self.entry
      if not e then return end
      if e.dungeon then DR.OpenDungeon(e.dungeon) elseif e.npc then DR.Pick(e.npc) end
    end)
    hoverTip(r, "ANCHOR_LEFT")
    a.rows[i] = r
  end
  a.foot = fs(a, 11, "paperSoft", DR.NARROW, "LEFT")
  a.foot:SetPoint("BOTTOMLEFT", px(1.1), px(0.7))
  a.page = fs(a, 11, "paperSoft", DR.NARROW, "RIGHT")
  a.page:SetPoint("BOTTOMRIGHT", -px(1.1), px(0.7))
  DR.atlas = a
end

function DR.Build()
  if DR.back then return DR.back end
  X.Build()
  DR.history = DR.history or {}
  local back = CreateFrame("Frame", "BiSToolsCodexDrive", UIParent)
  DR.back = back
  back:SetAllPoints(UIParent)
  back:SetFrameStrata("FULLSCREEN_DIALOG")
  back:SetFrameLevel(1)
  back:EnableMouse(true)                     -- the world behind is not clicked through
  fill(back, "BACKGROUND", "000000", 0.94):SetAllPoints()
  local room = CreateFrame("Frame", nil, back)
  DR.room = room
  room:SetSize(DR.W, DR.H)
  room:SetPoint("CENTER", back, "CENTER", 0, 0)
  room:SetFrameLevel(2)
  buildNight(room)
  buildHero(room)
  buildRain(room)
  buildFrame(room)
  buildCredit(room)
  buildMirror(room)
  buildVisor(room)
  local dash = buildDash(room)
  buildCluster(dash)
  buildRadio(dash)
  buildAbilities(dash)
  buildKey(dash)
  buildAtlas(room)
  if UISpecialFrames then table.insert(UISpecialFrames, "BiSToolsCodexDrive") end   -- Escape closes it
  back:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
      DR.Close()
      NS.Print("codex: the full screen closed for the fight")
    end
  end)
  back:Hide()
  -- shut by anything (the key, Escape, a fight): nothing runs on, and the window comes back if it stepped out
  back:SetScript("OnHide", function(self)
    self:UnregisterEvent("PLAYER_REGEN_DISABLED")
    if DR.rain then DR.rain:SetScript("OnUpdate", nil) end
    DR.Spin(false)
    if DR.hero then dragStop(DR.hero) end
    if DR.find then DR.find.box:ClearFocus() end
    DR.Settle()
    if DR.was then
      DR.was = nil
      X.Toggle(true)
    end
  end)
  return back
end

--- The book's place made whole for the window (Arn's BugSack, 8 Nov: closing on a dungeon the window had never shown
--- left C.UI.plate nil and its paint died): the plate holding the pick, the index's page and list.
function DR.Settle()
  if X.view == "dungeon" then
    local dd = X.dungeon and C.DATA.dungeons[X.dungeon]
    if not dd then X.view = "contents" return end
    local at = 1
    for i, id in ipairs(dd.list) do if id == X.sel then at = i end end
    X.plate = math.ceil(at / X.FIG)
  elseif X.view == "index" then
    X.letter = X.letter or "A"
    X.list = C.Index(X.letter, X.search)
    X.offset = 0
    for i, id in ipairs(X.list) do if id == X.sel then X.offset = math.floor((i - 1) / X.IDX) * X.IDX end end
  end
end

--- How big: the largest 16:9 that fits the screen (asked each time it opens).
function DR.Size()
  local sw = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 1024
  local sh = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 768
  if sw <= 0 or sh <= 0 then sw, sh = 1024, 768 end
  return math.min(sw / DR.W, sh / DR.H)
end

function DR.IsOpen() return DR.back ~= nil and DR.back:IsShown() end

function DR.Open()
  if fighting() then
    NS.Print("codex: the full screen opens after the fight")
    return false
  end
  local back = DR.Build()
  DR.was = X.IsOpen() or nil
  if DR.was then X.frame:Hide() end
  if GameTooltip then GameTooltip:Hide() end
  DR.room:SetScale(DR.Size())
  if not X.view or (X.view == "contents" and not X.sel) then
    -- nothing picked yet: start on the first dungeon's first boss
    local v = C.DATA.volumes[1]
    if v and v.list[1] then
      local dd = C.DATA.dungeons[v.list[1]]
      X.view, X.dungeon = "dungeon", v.list[1]
      for _, npc in ipairs(dd.list) do
        local s = C.DATA.creatures[npc]
        if s and s.boss then X.sel = npc break end
      end
    end
  end
  back:Show()
  back:RegisterEvent("PLAYER_REGEN_DISABLED")
  DR.rain:SetScript("OnUpdate", DR.rain.tick)
  DR.Paint()
  return true
end

function DR.Close()
  if DR.back then DR.back:Hide() end
end

function DR.Toggle()
  if DR.IsOpen() then DR.Close() return false end
  return DR.Open()
end

-- ------------------------------------------------------------------ painting

local function upper(s) return s and tostring(s):upper() or nil end

local function paintCredit(npc, c)
  local cr = DR.credit
  local name = (c and c.name) or C.Name(npc) or ("creature " .. npc)
  local size = shrink(cr.name, name, DR.SERIF, 64, 36, px(36))
  cr.glow:SetFont(DR.SERIF, size, "")
  cr.glow:SetText(cr.name:GetText())
  local dd = c and c.dungeon and C.DATA.dungeons[c.dungeon]
  local what = c and c.boss and "BOSS" or ((c and c.rank and X.RANKS[c.rank]) or "CREATURE")
  local where = dd and (upper(dd.name) .. "  -  " .. upper(dd.where)) or "MET IN THE WILD"
  set(cr.sub, what .. "   -   " .. where, 17, px(36))
end

local function paintMirror()
  local m, before = DR.mirror, DR.history[1]
  if before then
    local c = C.Creature(before)
    set(m.who, (c and c.name) or C.Name(before) or ("creature " .. before), 18, px(13.6))
    m.sub:SetText("THE PAGE BEFORE")
    m.back:SetTextColor(rgb("ink"))
  else
    m.who:SetText("")
    m.sub:SetText("NOTHING BEHIND YOU")
    m.back:SetTextColor(rgb("faint"))
  end
end

local function paintVisor(c)
  local v = DR.visor
  local drops = {}
  for item, n in pairs(c and c.seen or {}) do drops[#drops + 1] = { item = item, n = n } end
  table.sort(drops, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.item < b.item end)
  for i, t in ipairs(v.tickets) do
    local e = drops[i]
    t.item, t.link = e and e.item or nil, nil
    if e then
      local iname, q = C.Item(e.item)
      local I = C_Item
      if I and I.GetItemInfo then
        local ok, _, link = pcall(I.GetItemInfo, e.item)
        t.link = ok and C.Plain(link) or nil
        if type(t.link) ~= "string" then t.link = nil end
      end
      set(t.name, iname or ("item " .. e.item), 13, px(6.6))
      t.name:SetTextColor(rgb(X.QUALITY[q or 1] or X.QUALITY[1]))
      t.sub:SetText(e.n == 1 and "SEEN ONCE" or ("SEEN " .. e.n .. " TIMES"))
      t:Show()
    else
      t:Hide()
    end
  end
  v.none:SetShown(#drops == 0)
  set(v.none, "Nothing seen to drop yet.", 13, px(22))
end

local function paintCluster(npc, c)
  local lvl = c and c.level
  DR.level:Point(type(lvl) == "number" and lvl / 60 or 0)
  DR.level.value:SetText(type(lvl) == "number" and tostring(lvl) or "--")
  -- this place's bosses: how many met
  local dd = c and c.dungeon and C.DATA.dungeons[c.dungeon]
  local all, met = 0, 0
  for _, id in ipairs(dd and dd.list or {}) do
    local s = C.DATA.creatures[id]
    if s and s.boss then
      all = all + 1
      local cc = C.Creature(id)
      if cc and cc.met > 0 then met = met + 1 end
    end
  end
  DR.place:Point(all > 0 and met / all or 0)
  DR.place.value:SetText(all > 0 and (met .. " / " .. all) or "--")
  local n = math.min(c and c.met or 0, 9999)
  local s = ("%04d"):format(n)
  for i = 1, 4 do DR.odo[i]:SetText(s:sub(i, i)) end
  DR.lamps.BOSS:Lit(c and c.boss)
  DR.lamps.ELITE:Lit(c and c.rank and c.rank ~= "normal" and c.rank ~= "trivial" and c.rank ~= "minus")
  DR.lamps.MET:Lit(c and c.met > 0)
  local typ = c and c.type and upper(c.family and (c.type .. " - " .. c.family) or c.type) or "NOT MET YET"
  set(DR.lcd1, typ, 13, px(12.6))
  set(DR.lcd2, ("NPC %d   MODEL %s"):format(npc, c and c.display and tostring(c.display) or "BY NPC"), 13, px(12.6))
  for k, b in pairs(DR.pose) do
    if k == "TURN" then b:Lit(DR.spinning) else b:Lit(DR.hero and DR.hero.anim ~= nil and DR.hero.anim == X.ANIM[k]) end
  end
end

local function paintRadio(npc, c)
  local letter
  if X.view == "index" then letter = X.search and nil or (X.letter or "A")
  else letter = C.Letter(c and c.name or nil) end
  local hit
  for _, b in ipairs(DR.letters) do
    b.on = (b.letter == letter)
    b.label:SetTextColor(rgb(b.on and "amber" or "amberDim"))
    if b.on then hit = b end
  end
  DR.needle:ClearAllPoints()
  if hit then
    DR.needle:SetPoint("TOP", hit, "TOP", 0, -px(0.3))
    DR.needle:Show()
  else
    DR.needle:Hide()
  end
  local vol = X.view == "dungeon" and X.dungeon and X.VolumeOf(X.dungeon)
  DR.presets.CONTENTS:Lit(X.view == "contents")
  DR.presets.DUNGEONS:Lit(vol and vol.id == "dungeons")
  DR.presets.RAIDS:Lit(vol and vol.id == "raids")
  DR.presets.INDEX:Lit(X.view == "index")
  local box = DR.find.box
  local want = X.view == "index" and X.search or ""
  if not (box.HasFocus and box:HasFocus()) and (box:GetText() or "") ~= want then
    box:SetText(want)
    DR.find.hint:SetShown(want == "")
  end
end

local function paintAbilities(c)
  local ab = DR.abil
  local spells = c and c.spells or {}
  ab.head:SetText(#spells > DR.ABIL and ("ABILITIES  (%d OF %d)"):format(DR.ABIL, #spells) or "ABILITIES")
  for i, r in ipairs(ab.rows) do
    local id = spells[i]
    if id then
      local s = C.Spell(id)
      r.icon:SetTexture(s.icon or X.QUESTION)
      set(r.name, s.name or ("spell " .. id), 13, px(10.8))
      r.tip = { (s.name or "spell") .. "  (" .. id .. ")", s.desc or "the game is fetching its words" }
      r:Show()
    else
      r:Hide()
    end
  end
  ab.none:SetShown(#spells == 0)
  set(ab.none, "None known yet. Casts in a fight are hidden on Forever; out of one, they are learned.", 12, px(25.4))
end

local function paintAtlas(npc)
  local a = DR.atlas
  local lines = DR.Lines()
  local page = DR.PageOf(lines)
  local pages = DR.Pages(lines)
  local first = (page - 1) * DR.ROWS
  local db = C.DB()
  local met = 0
  for _ in pairs(db and db.met or {}) do met = met + 1 end
  if X.view == "contents" then
    a.hdL:SetText("THE CONTENTS")
    a.hdR:SetText("")
    shrink(a.title, "Contents", DR.SERIF, 30, 20, px(18.3))
    a.about:SetText(("%d places, %d creatures, %d met by you. Pick a place to drive there."):format(#lines, #C.All(), met))
    a.route:Hide()
  elseif X.view == "index" then
    a.hdL:SetText("THE INDEX")
    a.hdR:SetText(X.search and "SEARCH" or ("UNDER " .. (X.letter or "A")))
    shrink(a.title, X.search and ("\"" .. X.search .. "\"") or (X.letter == "?" and "Not yet named" or (X.letter or "A")),
      DR.SERIF, 30, 20, px(18.3))
    a.about:SetText(#lines == 0 and "Nothing here yet. Names arrive from the game as the book asks for them."
      or (("%d names. Turn the knob for more."):format(#lines)))
    a.route:Hide()
  else
    local dd = C.DATA.dungeons[X.dungeon]
    local vol = X.VolumeOf(X.dungeon)
    a.hdL:SetText(("VOL. %s  -  %s"):format(vol and vol.numeral or "?", vol and vol.title or ""))
    a.hdR:SetText("LEVEL " .. dd.level)
    shrink(a.title, dd.name, DR.SERIF, 30, 20, px(18.3))
    a.about:SetText(dd.about)
    a.route:Show()
    for i, dot in ipairs(a.dots) do
      local e = lines[first + i]
      dot.npc = e and e.npc or nil
      if e then
        dot:Show()
        if dot.seg then dot.seg:Show() end
        dot.n:SetText(tostring(e.n))
        local hex = e.npc == npc and "rubric" or (e.boss and "paperInk" or "paperSoft")
        dot.face:SetVertexColor(rgb(hex))
        dot:SetSize(px(e.npc == npc and 1.6 or 1.25), px(e.npc == npc and 1.6 or 1.25))
      else
        dot:Hide()
        if dot.seg then dot.seg:Hide() end
      end
    end
  end
  for i, r in ipairs(a.rows) do
    local e = lines[first + i]
    r.entry = e
    r.keep = e ~= nil and ((e.npc and e.npc == npc) or false)
    r:Pop(false)
    if e then
      r.num:SetText(e.n and tostring(e.n) or "")
      local me = e.npc and e.npc == npc
      r.name:SetTextColor(rgb(me and "rubric" or "paperInk"))
      set(r.name, e.text, 14, px(e.right ~= "" and 12.4 or 16.6))
      set(r.right, e.right or "", 11, px(4.4))
      r.tip = e.dungeon and { e.text, "click: drive there" } or { e.text, "click: its page" }
      r:Show()
    else
      r:Hide()
    end
  end
  a.foot:SetText(X.view == "dungeon" and "click one: drive to it" or "click one")
  a.page:SetText(("PAGE %d / %d"):format(page, pages))
  DR.knobL:SetAlpha(page > 1 and 1 or 0.4)
  DR.knobR:SetAlpha(page < pages and 1 or 0.4)
end

function DR.Paint()
  if not DR.IsOpen() then return end
  local npc = DR.Current()
  if not npc then return end
  local c = C.Creature(npc)
  local hero = DR.hero
  if hero then
    if hero.npc ~= npc then hero.anim = nil DR.Spin(false) end
    X.Dress(hero, npc, hero.npc == npc and hero.face or 0.35)
  end
  paintCredit(npc, c)
  paintMirror()
  paintVisor(c)
  paintCluster(npc, c)
  paintRadio(npc, c)
  paintAbilities(c)
  paintAtlas(npc)
end
