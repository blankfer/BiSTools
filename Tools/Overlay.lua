-- BiSTools / Tools / Overlay.lua
-- THE OVERLAY MAP: a see-through map over the game, Diablo style (14 Oct 2026).
--
-- Arn, 13 Oct: Diablo's overlay map - press a key, a see-through map sits over the game and you keep
-- playing through it. 14 Oct: "can we try to make the map that alpha out the useless stuff".
--
-- So: our OWN frame (never Blizzard's world map - reading or hooking it taints, Overlord 6 and 11 Oct),
-- click-through, under every other window, faint. By default it draws only the zone's EXPLORED pieces
-- (C_MapExplorationInfo - the same pieces the world map reveals): the parchment, the borders and every
-- place you have not been stay fully see-through, and the map fills in as you explore. "full" draws the
-- whole zone art instead, desaturated. On top: your arrow, and a dotted trail of where you walked.
--
-- Cost: the arrow is repainted 10 times a second ONLY while the map is up; the art is redrawn on a zone
-- change or a setting. The trail is sampled every 2 s while the tool is on and the trail is on (one
-- position question); nothing else ticks. Position or facing hidden (an instance) = no arrow, the
-- art still shows, and the corner says so.
local _, NS = ...
local T, R = NS.T, NS.Registry

local O = { TICK = 0.1, SAMPLE = 2, STEP = 0.012, TRAIL_MAX = 600, TILE = 256 }
NS.Overlay = O
O.TINT = { 0.75, 0.88, 1.0 }          -- a cold glow, so the art reads as "map", not as the world
O.ARROW = { 1.0, 0.85, 0.2 }          -- your arrow: gold, so it stands out on grey art
O.ARROW_LEN = 14

local function hidden(v)
  if v == nil or not issecretvalue then return false end
  local ok, yes = pcall(issecretvalue, v)
  return (not ok) or yes == true
end
local function num(v) if hidden(v) or type(v) ~= "number" then return nil end return v end

-- THE DEFAULTS ARE ARN'S PICK (14 Oct, a screenshot: "these settings keep it in a nice place"):
-- all of the map, grey, 30% of the screen's height, 50% solid
O.DEFAULT = { size = 30, alpha = 50 }
function O.Size(db) return tonumber(db.size) or O.DEFAULT.size end   -- % of the screen's height
-- Arn, 14 Oct (a world-map shot of Durotar): "a little color like this, alpha like 10%"
function O.Alpha(db) return tonumber(db.alpha) or O.DEFAULT.alpha end   -- %
function O.Grey(db) return db.grey ~= false end                 -- off: the map's own colours
function O.Mode(db) return db.mode == "explored" and "explored" or "full" end
-- Arn, 14 Oct: "also no trail its getting too busy" - off unless switched on
function O.TrailOn(db) return db.trail == true end

------------------------------------------------------------------ where am I --

function O.MapID()
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
  return ok and num(id) or nil
end

--- Your spot on this map (or a groupmate's), 0-1 each way, or nil (hidden, an instance, no map).
function O.Where(mapID, unit)
  if not (mapID and C_Map and C_Map.GetPlayerMapPosition) then return nil end
  local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, unit or "player")
  if not ok or pos == nil or hidden(pos) then return nil end
  local ok2, x, y = pcall(function() return pos:GetXY() end)
  if ok2 then
    x = num(x)
    y = num(y)
  else
    x, y = nil, nil
  end
  if not (x and y) or (x == 0 and y == 0) then return nil end
  return x, y
end

function O.Facing()
  if not GetPlayerFacing then return nil end
  local ok, f = pcall(GetPlayerFacing)
  return ok and num(f) or nil
end

------------------------------------------------------------------ the frame --

O.FADE = "Interface\\AddOns\\BiSTools\\Media\\MapFade"

function O.Build()
  if O.frame then return O.frame end
  local f = CreateFrame("Frame", "BiSToolsOverlayMap", UIParent)
  O.frame = f
  f:SetFrameStrata("BACKGROUND")        -- over the world, under every window
  f:EnableMouse(false)                  -- click-through: you keep playing
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  if f.SetClipsChildren then f:SetClipsChildren(true) end
  -- SOFT EDGES (Arn, 14 Oct: "do the soft edges too ... fade out"): the art is masked by our own
  -- MapFade (white, its alpha falling to 0 over the outer eighth of each side), stretched to the
  -- frame, so the map melts into the game instead of ending in a box. The art only - dots and the
  -- arrow stay sharp. A client without masks just keeps the hard edge.
  if f.CreateMaskTexture then
    local ok, m = pcall(f.CreateMaskTexture, f)
    if ok and m then
      m:SetTexture(O.FADE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      m:SetAllPoints(f)
      O.mask = m
    end
  end
  O.art, O.dots = {}, {}
  -- the arrow is OURS, three lines (Arn's screenshots, 14 Oct: the trail drew and no arrow did -
  -- the old minimap arrow file is not on Forever). A Line needs WHITE8X8 + SetVertexColor.
  O.arrow = { shown = false }
  for i = 1, 3 do
    local l = f:CreateLine(nil, "OVERLAY")
    l:SetTexture("Interface\\Buttons\\WHITE8X8")
    l:SetVertexColor(O.ARROW[1], O.ARROW[2], O.ARROW[3], 1)
    l:SetThickness(3)
    l:Hide()
    O.arrow[i] = l
  end
  -- WHERE YOU ARE, Diablo style (Arn, 15 Oct, a Diablo II screenshot: "Rogue Encampment" small in
  -- the top-right corner): the zone and the subzone, in capitals, on the map's own corner
  O.place = f:CreateFontString(nil, "OVERLAY")
  O.place:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
  O.place:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -6)
  O.place:SetJustifyH("RIGHT")
  O.place:SetTextColor(O.GOLD[1], O.GOLD[2], O.GOLD[3])
  O.note = f:CreateFontString(nil, "OVERLAY")
  O.note:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
  O.note:SetPoint("BOTTOM", f, "BOTTOM", 0, 6)
  f:Hide()
  -- THE TAB (Arn, 14 Oct, the Zone Map beside it: "top left, if we could do it like zone map so we
  -- can drag if we want to" - "only visible if you hover over"). The map stays click-through; this
  -- small tab at the land's top-left is the one thing that takes the mouse. It is invisible until the
  -- mouse is on it; drag it and the map follows (the map hangs off it); the spot is saved.
  local tab = CreateFrame("Button", "BiSToolsOverlayMapTab", UIParent)
  O.tab = tab
  tab:SetSize(O.TAB_W, O.TAB_H)
  tab:SetFrameStrata("LOW")
  tab:SetMovable(true)
  tab:SetClampedToScreen(true)
  tab:EnableMouse(true)
  tab:RegisterForDrag("LeftButton")
  local bg = tab:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(tab)
  bg:SetColorTexture(0.08, 0.06, 0.14, 0.9)
  local label = tab:CreateFontString(nil, "OVERLAY")
  label:SetFont(STANDARD_TEXT_FONT, 10, "")
  label:SetPoint("CENTER", tab, "CENTER", 0, 0)
  label:SetText(T.text("accent", "BiS>") .. " map")
  tab.label, tab.bg = label, bg
  -- THE HINT (Arn, 14 Oct: "maybe we do show like a little line ____ ... to let people know where its
  -- at"): a short faint underline where the tab is, there while the tab is not - so the tab can be
  -- found without sitting over the map all the time
  local hint = tab:CreateTexture(nil, "ARTWORK")
  hint:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 4, 0)
  hint:SetSize(O.HINT_W, 2)
  local hr, hg, hb = T.rgb("accent")
  hint:SetColorTexture(hr or 1, hg or 0.82, hb or 0.3, O.HINT_A)
  tab.hint = hint
  O.Lit(false)
  tab:SetScript("OnEnter", function() O.Lit(true) end)
  tab:SetScript("OnLeave", function(self)
    if not self.dragging and not (O.menu and O.menu:IsShown()) then O.Lit(false) end
  end)
  tab:SetScript("OnDragStart", function(self)
    if O.db and O.db.locked then return end            -- the menu's "Lock map"
    self.dragging = true
    self:StartMoving()
  end)
  -- right-click: the quick menu, as the Zone Map's tab has (Arn, 14 Oct)
  tab:RegisterForClicks("RightButtonUp")
  tab:SetScript("OnClick", function(_, button) if button == "RightButton" then O.Menu() end end)
  tab:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self.dragging = nil
    O.Lit(false)
    O.SavePos(O.db)
  end)
  tab:Hide()
  return f
end

--- Where the tab sits: from the screen's top-left, x right and y down (negative). Default top-left.
O.TAB_W, O.TAB_H = 70, 16
O.HINT_W, O.HINT_A = 24, 0.5

--- The tab lit (hovered, dragged, its menu open) or resting: lit shows the tab and hides the hint;
--- resting is the other way round. The tab itself stays solid, so it always takes the mouse.
function O.Lit(on)
  local tab = O.tab
  if not tab then return end
  tab.lit = on and true or false
  tab.bg:SetAlpha(on and 1 or 0)
  tab.label:SetAlpha(on and 1 or 0)
  tab.hint:SetAlpha(on and 0 or 1)
end
O.POS = { 24, -80 }
function O.Pos(db)
  local p = type(db) == "table" and db.pos
  if type(p) == "table" and type(p[1]) == "number" and type(p[2]) == "number" then return p[1], p[2] end
  return O.POS[1], O.POS[2]
end

function O.PlaceTab(db)
  local x, y = O.Pos(db)
  O.tab:ClearAllPoints()
  O.tab:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
end

------------------------------------------------------------------ the menu --
-- Right-click the tab (Arn, 14 Oct, the Zone Map's tab menu: Show Teammates, Lock Zone Map, Change
-- Opacity). Our own little frame, not Blizzard's menu system - its menus are what instances broke for
-- our right-click lines (13 Oct). A tick row toggles; a -/+ row steps; Escape or the tab closes it.
O.MENU_W, O.ROW_H = 190, 18

function O.MenuRows()
  local function redraw() if O.frame and O.frame:IsShown() then O.Draw(O.db) end end
  return {
    { kind = "check", label = "Show group", get = function(db) return db.group ~= false end,
      -- not "(not on) and false or nil": that is nil both ways (Arn, 14 Oct: "cant unclick the grey")
      set = function(db, on) if on then db.group = nil else db.group = false end O.Group(true) end },
    { kind = "check", label = "Show guild", get = function(db) return db.guildDots ~= false end,
      set = function(db, on) if on then db.guildDots = nil else db.guildDots = false end O.Group(true) end },
    { kind = "check", label = "Lock map", get = function(db) return db.locked == true end,
      set = function(db, on) db.locked = on and true or nil end },
    { kind = "check", label = "Show all of the map", get = function(db) return O.Mode(db) == "full" end,
      set = function(db, on) db.mode = (not on) and "explored" or nil redraw() end },
    { kind = "check", label = "Grey", get = function(db) return O.Grey(db) end,
      set = function(db, on) if on then db.grey = nil else db.grey = false end redraw() end },
    { kind = "step", label = "Opacity", get = function(db) return O.Alpha(db) end, min = 5, max = 90, step = 5,
      set = function(db, v) db.alpha = v redraw() end },
    { kind = "step", label = "Size", get = function(db) return O.Size(db) end, min = 30, max = 100, step = 10,
      set = function(db, v) db.size = v redraw() end },
    { kind = "action", label = "All settings...", run = function()
        if NS.HubSlash then NS.HubSlash("options") end
        O.menu:Hide()
      end },
  }
end

function O.BuildMenu()
  if O.menu then return O.menu end
  local m = CreateFrame("Frame", "BiSToolsOverlayMapMenu", UIParent)
  O.menu = m
  m:SetFrameStrata("DIALOG")
  m:EnableMouse(true)
  local bg = m:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(m)
  bg:SetColorTexture(0.06, 0.05, 0.10, 0.95)
  m.rows = {}
  for i, r in ipairs(O.MenuRows()) do
    local b = CreateFrame("Button", nil, m)
    b:SetSize(O.MENU_W - 8, O.ROW_H)
    b:SetPoint("TOPLEFT", m, "TOPLEFT", 4, -4 - (i - 1) * O.ROW_H)
    b.def = r
    local fs = b:CreateFontString(nil, "OVERLAY")
    fs:SetFont(STANDARD_TEXT_FONT, 11, "")
    -- every label starts at the same spot; the tick is its own picture beside it (Arn, 14 Oct:
    -- "everything shifts when change states" - spaces stood in for an empty tick, narrower than it)
    fs:SetPoint("LEFT", b, "LEFT", 22, 0)
    b.text = fs
    local tick = b:CreateTexture(nil, "OVERLAY")
    tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    tick:SetSize(14, 14)
    tick:SetPoint("LEFT", b, "LEFT", 4, 0)
    tick:Hide()
    b.tick = tick
    if r.kind == "step" then
      for k, d in ipairs({ { "-", -1 }, { "+", 1 } }) do
        local s = CreateFrame("Button", nil, b)
        s:SetSize(18, O.ROW_H)
        s:SetPoint("RIGHT", b, "RIGHT", (k - 2) * 20, 0)
        local st = s:CreateFontString(nil, "OVERLAY")
        st:SetFont(STANDARD_TEXT_FONT, 12, "")
        st:SetPoint("CENTER", s, "CENTER", 0, 0)
        st:SetText(d[1])
        s:SetScript("OnClick", function()
          local v = r.get(O.db) + d[2] * r.step
          r.set(O.db, math.max(r.min, math.min(r.max, v)))
          O.PaintMenu()
        end)
        b[d[1] == "-" and "minus" or "plus"] = s
      end
    else
      b:SetScript("OnClick", function()
        if r.kind == "check" then r.set(O.db, not r.get(O.db)) O.PaintMenu() else r.run() end
      end)
    end
    m.rows[i] = b
  end
  m:SetSize(O.MENU_W, 8 + #m.rows * O.ROW_H)
  m:SetScript("OnHide", function() if O.tab and not O.tab.dragging then O.Lit(false) end end)
  m:Hide()
  table.insert(UISpecialFrames, "BiSToolsOverlayMapMenu")       -- Escape closes it
  return m
end

function O.PaintMenu()
  for _, b in ipairs(O.menu.rows) do
    local r = b.def
    if r.kind == "check" and r.get(O.db) then b.tick:Show() else b.tick:Hide() end
    if r.kind == "step" then
      b.text:SetText(("%s  %d%%"):format(r.label, r.get(O.db)))
    else
      b.text:SetText(r.label)
    end
  end
end

--- Open or shut the menu under the tab.
function O.Menu()
  local m = O.BuildMenu()
  if m:IsShown() then m:Hide() return false end
  m:ClearAllPoints()
  m:SetPoint("TOPLEFT", O.tab, "BOTTOMLEFT", 0, -2)
  O.PaintMenu()
  O.Lit(true)
  m:Show()
  return true
end

------------------------------------------------------------------ the group --
-- "Show group": your party or raid as small dots in class colours, asked twice a second while the
-- map is up (40 position questions at most). A hidden position (an instance, or the game says no)
-- is just no dot.
O.GROUP_EVERY = 0.5

local function groupUnits()
  local out = {}
  local n = GetNumGroupMembers and GetNumGroupMembers() or 0
  n = num(n) or 0
  if n == 0 then return out end
  local raid = IsInRaid and IsInRaid()
  for i = 1, raid and n or math.min(4, n - 1) do out[#out + 1] = (raid and "raid" or "party") .. i end
  return out
end
O.GroupUnits = groupUnits

--- One dot (the i-th of the pool) at a map spot, with a small name in its colour.
local function dot(i, x, y, c, nm, size)
  local d = O.gdots[i]
  if not d then
    d = O.frame:CreateTexture(nil, "OVERLAY")
    O.gdots[i] = d
  end
  d:SetSize(size, size)
  d:SetColorTexture(c.r, c.g, c.b, 1)
  d:ClearAllPoints()
  d:SetPoint("CENTER", O.frame, "TOPLEFT", O.ToFrame(x, y))
  d:Show()
  -- a small name beside the dot (Arn, 14 Oct: "since its ours maybe we can add small name"):
  -- the first name only, in the dot's colour; no name is just the dot
  if not d.name then
    d.name = O.frame:CreateFontString(nil, "OVERLAY")
    d.name:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    d.name:SetPoint("LEFT", d, "RIGHT", 2, 0)
  end
  if nm then
    d.name:SetText(nm)
    d.name:SetTextColor(c.r, c.g, c.b)
    d.name:Show()
  end
end

--- The group's dots (answers how many), then the guild's (O.guildShown) - see "the guild" below.
function O.Group(force)
  O.gdots = O.gdots or {}
  for _, d in ipairs(O.gdots) do d:Hide() if d.name then d.name:Hide() end end
  O.guildShown = 0
  if not (O.db and O.frame and O.frame:IsShown()) then return 0 end
  local shown, drawn = 0, {}
  if O.db.group ~= false then shown = O.GroupDots(drawn) end
  if O.db.guildDots ~= false then O.guildShown = O.GuildDots(shown, drawn) end
  return shown
end

function O.GroupDots(drawn)
  local shown = 0
  for _, u in ipairs(groupUnits()) do
    local okU, me = pcall(UnitIsUnit, u, "player")
    local isMe = okU and not hidden(me) and me == true
    local x, y
    if not isMe then
      local ok, pos = pcall(C_Map.GetPlayerMapPosition, O.mapID, u)
      if ok and pos and not hidden(pos) then
        local ok2, px, py = pcall(function() return pos:GetXY() end)
        if ok2 then
          x = num(px)
          y = num(py)
        end
      end
    end
    if x and y and not (x == 0 and y == 0) then
      shown = shown + 1
      local okC, _, class = pcall(UnitClass, u)
      if not okC then class = nil end
      local c = (type(class) == "string" and not hidden(class) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]) or { r = 0.9, g = 0.9, b = 0.9 }
      local okN, nm = pcall(UnitName, u)
      nm = okN and not hidden(nm) and type(nm) == "string" and nm:match("^(%S+)") or nil
      if nm then drawn[nm] = true end
      dot(shown, x, y, c, nm, 7)
    end
  end
  return shown
end

------------------------------------------------------------------ the guild --
-- Arn, 14 Oct: "what are the chances we can show all guild locations?" - the game gives an addon the
-- GROUP's positions only, so every BiS addon shares its player's spot over LibBiSComm's guild channel
-- (minor 12, SPOT: while moving, cascading 15/30/60 s by guild size, never inside an instance; ONE
-- switch for all of them, /biscomm share on|off - "or does it go in a library?"). This map only
-- DRAWS what the lib heard: guildmates on the map you are looking at, amber dots with first names.
O.GUILD = { r = 1.00, g = 0.62, b = 0.10 }   -- the family's guild amber (guild rivals wear it too)

local function commLib() return NS.Comm and NS.Comm.Lib and NS.Comm.Lib() end
O.CommLib = commLib

function O.Sharing()
  local l = commLib()
  return l and l.Sharing and l:Sharing() or false
end
function O.SetSharing(on)
  local l = commLib()
  if l and l.SetSharing then l:SetSharing(on) end
end

--- The guild's dots on the map you are looking at, after the group's (the i-th dot on); a
--- guildmate already drawn as a groupmate is not drawn twice.
function O.GuildDots(from, drawn)
  local l = commLib()
  if not (l and l.Spots) then return 0 end
  local n = 0
  for sender, s in pairs(l:Spots()) do
    if s.map == O.mapID then
      local nm = type(sender) == "string" and sender:match("^([^%-%s]+)")
      if nm and not drawn[nm] then
        n = n + 1
        dot(from + n, s.x, s.y, O.GUILD, nm, 6)
      end
    end
  end
  return n
end

--- After a drag: keep the tab's top-left, from the screen's top-left.
function O.SavePos(db)
  if not db then return end
  local okL, l = pcall(function() return O.tab:GetLeft() end)
  local okT, t = pcall(function() return O.tab:GetTop() end)
  local okH, h = pcall(function() return UIParent:GetHeight() end)
  l = okL and num(l) or nil
  t = okT and num(t) or nil
  h = okH and num(h) or nil
  if l and t and h then db.pos = { math.floor(l + 0.5), math.floor(t - h + 0.5) } end
  O.PlaceTab(db)
end

-- one pool per draw layer: a texture is made in its layer and stays there (the base map in
-- BORDER, the explored pieces over it in ARTWORK)
O.pools = {}
local function tex(layer)
  layer = layer or "ARTWORK"
  O.pools[layer] = O.pools[layer] or {}
  local t = table.remove(O.pools[layer])
  if not t then
    t = O.frame:CreateTexture(nil, layer)
    t.layer = layer
    if O.mask and t.AddMaskTexture then t:AddMaskTexture(O.mask) end
  end
  t:Show()
  O.art[#O.art + 1] = t
  return t
end

local function clearArt()
  for i = #O.art, 1, -1 do
    local t = O.art[i]
    t:Hide()
    local p = O.pools[t.layer]
    p[#p + 1] = t
    O.art[i] = nil
  end
end

--- One texture of map art at (x, y) in the art's own pixels, w x h of it shown, out of a file fw x fh.
local function piece(file, x, y, w, h, fw, fh, layer)
  local s = O.scale
  local t = tex(layer)
  t:SetTexture(file)
  t:SetTexCoord(0, w / fw, 0, h / fh)
  t:SetSize(w * s, h * s)
  t:ClearAllPoints()
  local l = O.land or { 0, 0 }
  t:SetPoint("TOPLEFT", O.frame, "TOPLEFT", (x - l[1]) * s, -(y - l[2]) * s)
  if t.SetDesaturated then t:SetDesaturated(O.Grey(O.db or {})) end
  if O.Grey(O.db or {}) then t:SetVertexColor(O.TINT[1], O.TINT[2], O.TINT[3], 1) else t:SetVertexColor(1, 1, 1, 1) end
  return t
end

-- the next power of two up from a piece's pixels (texture files are), at least 16
local function fileSize(px)
  local f = 16
  while f < px do f = f * 2 end
  return f
end

-- how much of the paper's edge never shows, as a share of the map: left/right, top, bottom. The top
-- stays whole: the map's name banner sits there (Arn, 14 Oct, Durotar: "it cut off the map name")
O.EDGE = { 0.03, 0, 0.045 }

-- THE CAPITALS' BOXES (Arn, 14 Oct: "nothing we can do for the capital city map about all the extra
-- parchment?"). The game cannot tell us where a city's drawing ends, so each box is measured by eye
-- from a screenshot of that city: left, top, right, bottom as shares of the map. Only measured
-- cities are here; any other map keeps O.EDGE alone.
O.CROP = {
  -- Orgrimmar: the empty band west, part of the crest east. First box (0.10, 0.04, 0.85, 0.955) cut
  -- the city (Arn: "cropped off some"), so every side was let out
  [1454] = { 0.08, 0.015, 0.88, 0.985 },
  -- Thunder Bluff, measured off the Blizzard world map (Arn, 14 Oct - no need to fly there): the
  -- four rises and the banner kept, the empty west and most of the crest gone
  [1456] = { 0.10, 0.03, 0.88, 0.96 },
  -- Undercity: the banner reaches the west edge and the crest sits under the sewers, so only the
  -- empty east goes
  [1458] = { 0.03, 0.01, 0.91, 0.975 },
  -- the Alliance three, off the same world map screenshots: Stormwind keeps the harbour's water (the
  -- crest sits in it) and loses the empty band over the keep; Ironforge and Darnassus lose the west
  -- margin and most of the crest - their banners sit at the bottom, so the bottom stays
  [1453] = { 0.03, 0.05, 0.92, 0.97 },    -- Stormwind
  [1455] = { 0.08, 0.005, 0.915, 0.98 },  -- Ironforge
  [1457] = { 0.05, 0.005, 0.93, 0.98 },   -- Darnassus
}

--- A spot on the map (0-1 each way) as an offset from the frame's top-left: the frame is the land,
--- which starts O.land's x0, y0 into the map.
function O.ToFrame(x, y)
  local l, s = O.land or { 0, 0 }, O.scale or 1
  return (x * (O.lw or 1) - l[1]) * s, -((y * (O.lh or 1) - l[2]) * s)
end

--- Redraw the art for this map: the explored pieces, or the whole zone.
--- "DUROTAR - RAZOR HILL": the zone, and the subzone when it is another name. Plain only.
O.GOLD = { 0.95, 0.80, 0.45 }
function O.PlaceName()
  local function ask(fn)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn)
    if not ok or v == nil or (issecretvalue and issecretvalue(v)) or type(v) ~= "string" or v == "" then return nil end
    return v
  end
  local zone, sub = ask(GetZoneText), ask(GetSubZoneText)
  if not zone then return "" end
  if sub and sub ~= zone then return (zone .. " - " .. sub):upper() end
  return zone:upper()
end
function O.PaintPlace()
  if O.place then O.place:SetText(O.PlaceName()) end
end

function O.Draw(db)
  local f = O.Build()
  O.PaintPlace()
  clearArt()
  local mapID = O.MapID()
  O.mapID = mapID
  local layers = mapID and C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(mapID)
  local L = type(layers) == "table" and layers[1] or nil
  local lw = L and num(L.layerWidth)
  local lh = L and num(L.layerHeight)
  if not (lw and lh and lw > 0 and lh > 0) then
    -- in the map's corner, under the tab - not the middle of the screen (Arn, 14 Oct, in Ragefire:
    -- "no map for this place" sat right over his character)
    f:SetSize(220, 40)
    O.scale = 1
    O.PlaceTab(db)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", O.tab, "BOTTOMLEFT", 0, 0)
    O.note:SetText("no map for this place")
    return false
  end
  f:SetAlpha(O.Alpha(db) / 100)
  O.note:SetText("")
  -- 1. what to draw, in the art's own pixels
  -- a city has no explored pieces at all (the game shows it whole): there, seen = all
  -- (Arn's Orgrimmar, 14 Oct: "nothing explored here yet" over an empty map)
  local info = C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures
    and C_MapExplorationInfo.GetExploredMapTextures(mapID) or {}
  if type(info) ~= "table" or hidden(info) then info = {} end
  local pieces = {}
  -- "all": the base layer IS the fog of war on these maps (Arn, 14 Oct: "all setting is showing fog
  -- of war") - the world map paints the explored pieces over it, so we do too. Ground never
  -- explored stays fogged: the game hands addons only the pieces you have explored.
  if O.Mode(db) == "full" or #info == 0 then
    local tw, th = num(L.tileWidth) or O.TILE, num(L.tileHeight) or O.TILE
    local files = C_Map.GetMapArtLayerTextures and C_Map.GetMapArtLayerTextures(mapID, 1) or {}
    local cols = math.ceil(lw / tw)
    for i, file in ipairs(files) do
      local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
      pieces[#pieces + 1] = { file, c * tw, r * th, tw, th, tw, th, "BORDER" }   -- under the pieces
    end
  end
  if #info > 0 then
    -- the explored pieces, cut the way the client cuts them: 256-pixel files, the last row and
    -- column only as big as what is left, in a file of the next power of two
    for _, e in ipairs(info) do
      local W, Hh = num(e.textureWidth), num(e.textureHeight)
      local ox, oy = num(e.offsetX) or 0, num(e.offsetY) or 0
      if W and Hh and type(e.fileDataIDs) == "table" then
        local wide, tall = math.ceil(W / O.TILE), math.ceil(Hh / O.TILE)
        for j = 1, tall do
          local ph = (j < tall) and O.TILE or (Hh - O.TILE * (tall - 1))
          for k = 1, wide do
            local pw = (k < wide) and O.TILE or (W - O.TILE * (wide - 1))
            local file = e.fileDataIDs[(j - 1) * wide + k]
            if file then
              pieces[#pieces + 1] = { file, ox + O.TILE * (k - 1), oy + O.TILE * (j - 1), pw, ph,
                (k < wide) and O.TILE or fileSize(pw), (j < tall) and O.TILE or fileSize(ph) }
            end
          end
        end
      end
    end
  end
  -- 2. the land those pieces cover; "all" is the whole map. NEVER the paper's torn edge (Arn, 14 Oct,
  -- Orgrimmar at 60%: "how come the map does not take out the extra stuff") - a city is one picture,
  -- parchment and all, so the most that can go is its border: the land stops O.EDGE inside each side,
  -- and the frame, which clips its children, shows that land and nothing past it.
  local ex, et, eb = lw * O.EDGE[1], lh * O.EDGE[2], lh * O.EDGE[3]
  local x0, y0, x1, y1 = lw, lh, 0, 0
  if O.Mode(db) == "full" then x0, y0, x1, y1 = 0, 0, lw, lh end
  for _, p in ipairs(pieces) do
    x0, y0 = math.min(x0, p[2]), math.min(y0, p[3])
    x1, y1 = math.max(x1, math.min(lw, p[2] + p[4])), math.max(y1, math.min(lh, p[3] + p[5]))
  end
  if x1 <= x0 or y1 <= y0 then x0, y0, x1, y1 = 0, 0, lw, lh end
  -- a capital is one painted picture, parchment and city in the same pixels, so its box is measured
  -- by eye, once per city (O.CROP) - and it REPLACES the edge trim: the city may reach past it
  -- (Orgrimmar's gate sits on the bottom edge)
  local box = mapID and O.CROP[mapID]
  if not box then
    x0, y0 = math.max(x0, ex), math.max(y0, et)
    x1, y1 = math.min(x1, lw - ex), math.min(y1, lh - eb)
  else
    x0, y0 = math.max(x0, lw * box[1]), math.max(y0, lh * box[2])
    x1, y1 = math.min(x1, lw * box[3]), math.min(y1, lh * box[4])
  end
  -- 3. size THAT land, not the canvas (Durotar sits right of the canvas's middle), and hang it from
  -- the tab: the land's top-left under the tab's bottom-left (Arn, 14 Oct: top left, draggable like
  -- the Zone Map). "map size" is the land's height as a share of the screen, never wider than it.
  local okH, sh = pcall(function() return UIParent:GetHeight() end)
  local okW, sw = pcall(function() return UIParent:GetWidth() end)
  sh = (okH and num(sh)) or 768
  sw = (okW and num(sw)) or 1024
  O.scale = math.min(sh * O.Size(db) / 100 / (y1 - y0), sw * 0.95 / (x1 - x0))
  -- the frame IS the land now (it clips what lies past it), hanging from the tab
  O.land, O.lw, O.lh = { x0, y0, x1, y1 }, lw, lh
  f:SetSize((x1 - x0) * O.scale, (y1 - y0) * O.scale)
  f:ClearAllPoints()
  O.PlaceTab(db)
  f:SetPoint("TOPLEFT", O.tab, "BOTTOMLEFT", 0, 0)
  for _, p in ipairs(pieces) do piece(p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8]) end
  O.DrawTrail(db)
  return true
end

------------------------------------------------------------------ the trail --

function O.Trail(db, mapID)
  db.trails = type(db.trails) == "table" and db.trails or {}
  local key = tostring(mapID)
  db.trails[key] = type(db.trails[key]) == "table" and db.trails[key] or {}
  return db.trails[key]
end

--- Remember where you are, if you moved far enough since the last dot.
function O.Sample(db)
  if not O.TrailOn(db) then return false end
  local mapID = O.mapID or O.MapID()
  local x, y = O.Where(mapID)
  if not x then return false end
  local t = O.Trail(db, mapID)
  local last = t[#t]
  if last and math.abs(last[1] - x) < O.STEP and math.abs(last[2] - y) < O.STEP then return false end
  t[#t + 1] = { math.floor(x * 1000 + 0.5) / 1000, math.floor(y * 1000 + 0.5) / 1000 }
  if #t > O.TRAIL_MAX then table.remove(t, 1) end
  if O.frame and O.frame:IsShown() then O.DrawTrail(db) end
  return true
end

function O.DrawTrail(db)
  for _, d in ipairs(O.dots) do d:Hide() end
  if not (O.TrailOn(db) and O.mapID) then return end
  for i, p in ipairs(O.Trail(db, O.mapID)) do
    local d = O.dots[i]
    if not d then
      d = O.frame:CreateTexture(nil, "OVERLAY")
      d:SetColorTexture(1, 1, 1, 0.75)
      d:SetSize(3, 3)
      O.dots[i] = d
    end
    d:ClearAllPoints()
    d:SetPoint("CENTER", O.frame, "TOPLEFT", O.ToFrame(p[1], p[2]))
    d:Show()
  end
end

------------------------------------------------------------------ the arrow --

local function arrowShown(on)
  O.arrow.shown = on
  for i = 1, 3 do if on then O.arrow[i]:Show() else O.arrow[i]:Hide() end end
end

--- Your arrow: a tip ahead of you and two back corners, turned the way you face. Facing is radians
--- counter-clockwise from north; the map's up is north. A hidden facing keeps the last one.
function O.Tick()
  local x, y = O.Where(O.mapID)
  if not x then
    arrowShown(false)
    if O.note:GetText() == "" then O.note:SetText("your position is hidden here") end
    return
  end
  local face = O.Facing()
  if face then O.lastFace = face end
  face = O.lastFace or 0
  local cx, cy = O.ToFrame(x, y)
  local dx, dy = -math.sin(face), math.cos(face)            -- ahead, in screen x / up
  local px, py = dy, -dx                                    -- to your right
  local L = O.ARROW_LEN
  local tipX, tipY = cx + dx * L, cy + dy * L
  local lx, ly = cx - dx * L * 0.6 - px * L * 0.6, cy - dy * L * 0.6 - py * L * 0.6
  local rx, ry = cx - dx * L * 0.6 + px * L * 0.6, cy - dy * L * 0.6 + py * L * 0.6
  local a = O.arrow
  a.x, a.y, a.face = cx, cy, face
  a[1]:SetStartPoint("TOPLEFT", O.frame, tipX, tipY)
  a[1]:SetEndPoint("TOPLEFT", O.frame, lx, ly)
  a[2]:SetStartPoint("TOPLEFT", O.frame, tipX, tipY)
  a[2]:SetEndPoint("TOPLEFT", O.frame, rx, ry)
  a[3]:SetStartPoint("TOPLEFT", O.frame, lx, ly)
  a[3]:SetEndPoint("TOPLEFT", O.frame, rx, ry)
  arrowShown(true)
end

------------------------------------------------------------------ open / shut --

function O.Show(db, on)
  db = db or O.db
  local f = O.Build()
  if on == nil then on = not f:IsShown() end
  if on then
    O.Draw(db)
    f:Show()
    O.tab:Show()
    O.acc, O.gacc = 0, O.GROUP_EVERY
    f:SetScript("OnUpdate", function(_, e)
      O.acc = O.acc + e
      if O.acc >= O.TICK then O.acc = 0 O.Tick() end
      O.gacc = O.gacc + e
      if O.gacc >= O.GROUP_EVERY then O.gacc = 0 O.Group() end
    end)
    O.Tick()
  else
    f:SetScript("OnUpdate", nil)
    f:Hide()
    O.tab:Hide()
    if O.menu then O.menu:Hide() end
    O.Group()
  end
  return on
end

-- the key binding (Bindings.xml: Key Bindings > BiS Tools > "Overlay map")
_G.BINDING_HEADER_BISTOOLS = "BiS Tools"
_G.BINDING_NAME_BISTOOLS_OVERLAYMAP = "Overlay map"     -- the long name was cut off in Key Bindings
function _G.BiSTools_ToggleOverlayMap()
  if not (O.db and R:Enabled("map")) then return end
  O.Show(O.db)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("ZONE_CHANGED")
ev:RegisterEvent("ZONE_CHANGED_INDOORS")
-- A NEW PLACE FOUND fills in at once (Arn, 15 Oct: "its not updating when i discover a new zone ...
-- have to close and open again"). The same map, so the map-changed test below never fired. The
-- client's own word for it is MAP_EXPLORATION_UPDATED (pcall: a client without it must not stop the
-- file); and a new subzone is usually where the discovery is, so in "explored" mode that redraws too.
pcall(ev.RegisterEvent, ev, "MAP_EXPLORATION_UPDATED")
ev:SetScript("OnEvent", function(_, event)
  if not (O.frame and O.frame:IsShown()) then return end
  O.PaintPlace()                       -- a new subzone renames the corner, map or no redraw
  if event == "MAP_EXPLORATION_UPDATED"
     or (event == "ZONE_CHANGED" and O.db and O.Mode(O.db) == "explored")
     or O.MapID() ~= O.mapID then
    O.Draw(O.db)
  end
end)
O.events = ev

function O.StartSampling(db)
  if O.ticker or not C_Timer or not C_Timer.NewTicker then return end
  O.ticker = C_Timer.NewTicker(O.SAMPLE, function() O.Sample(db) end)
end
function O.StopSampling()
  if O.ticker then O.ticker:Cancel() O.ticker = nil end
end

local function redraw() if O.frame and O.frame:IsShown() then O.Draw(O.db) end end

R:Register({
  name = "map",
  desc = "a see-through map over the game (pick a key in Key Bindings > BiS Tools)",
  usage = "/bist map [reset | clear]",
  defaults = {},
  options = {
    -- (Arn, 14 Oct: "i uncheck the map but can still show and hide it by clicking map button" -
    -- the tick on this section switches the tool; with it off, this button only says so)
    { kind = "button", label = "open / close the map", help = "Opens or closes the overlay map now (the tick on 'map' above switches the whole map tool on or off). Give it a key in the game's Key Bindings, under BiS Tools.",
      button = "open", action = function(db)
        if not R:Enabled("map") then
          return NS.Print("the map is off - tick 'map' in the options to use it")
        end
        O.Show(db)
      end },
    { kind = "seg", label = "map shows", values = { "seen", "all" },
      help = "seen: only the parts of the zone you have been to - everything else see-through, and it fills in as you explore. all: the whole zone, faint.",
      get = function(db) return O.Mode(db) == "full" and "all" or "seen" end,
      set = function(db, v) db.mode = (v == "seen") and "explored" or nil redraw() end },
    { kind = "step", label = "map size", help = "How tall the map is, as a share of your screen.", min = 30, max = 100, step = 10,
      get = function(db) return O.Size(db) end,
      set = function(db, v) db.size = v redraw() end,
      show = function(db) return O.Size(db) .. "%" end },
    { kind = "step", label = "map faintness", help = "How solid the map is: low is barely there, high is easy to read.", min = 5, max = 90, step = 5,
      get = function(db) return O.Alpha(db) end,
      set = function(db, v) db.alpha = v redraw() end,
      show = function(db) return O.Alpha(db) .. "%" end },
    { kind = "toggle", label = "grey map", help = "Off: the map in its own colours, like the world map. On: grey with a cold tint, so it reads as a map and not as the world.",
      get = function(db) return O.Grey(db) end,
      set = function(db, on) if on then db.grey = nil else db.grey = false end redraw() end },
    { kind = "toggle", label = "share my spot", help = "Your guildmates running a BiS addon see where you are on their map (while you move, never inside an instance). The same switch as /biscomm share on|off, for every BiS addon.",
      get = function() return O.Sharing() end,
      set = function(_, on) O.SetSharing(on) end },
    { kind = "toggle", label = "trail", help = "A dotted trail of where you have walked on each map, like Diablo's. /bist map clear wipes this map's.",
      get = function(db) return O.TrailOn(db) end,
      set = function(db, on)
        db.trail = on and true or false
        if on then O.StartSampling(db) else O.StopSampling() end
        redraw()
      end },
  },
  OnInit = function(_, db) O.db = db end,
  OnLogin = function(_, db) O.db = db if O.TrailOn(db) then O.StartSampling(db) end end,
  OnEnable = function(_, db) O.db = db if O.TrailOn(db) then O.StartSampling(db) end end,
  OnDisable = function() O.StopSampling() if O.frame then O.Show(O.db, false) end end,
  -- the Hub's "reset window positions" (recenter) puts the map back top-left; a plain open toggles it
  OnOpen = function(_, db, recenter)
    if recenter then
      db.pos = nil
      if O.tab then O.PlaceTab(db) end
      return
    end
    O.Show(db, true)
  end,
  IsOpen = function() return O.frame ~= nil and O.frame:IsShown() end,
  OnClose = function(_, db) O.Show(db, false) end,
  OnSlash = function(_, db, args)
    O.db = db
    if args == "reset" then
      db.pos = nil
      if O.tab then O.PlaceTab(db) end
      return NS.Print("the map is back in the top-left corner")
    end
    if args == "clear" then
      local id = O.MapID()
      if id then O.Trail(db, id) db.trails[tostring(id)] = {} end
      redraw()
      return NS.Print("this map's trail is wiped")
    end
    O.Show(db)
  end,
})
