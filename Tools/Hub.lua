-- BiSTools / Tools / Hub.lua
-- The minimap button and the two windows behind it. Not a Registry tool: it is
-- how you reach the tools, so it cannot be switched off.
--
-- Arn (10 Sep 2026): "the / commands are so convoluted between all the addons
-- ... work on the minimap icon; right click opens the options we haven't built;
-- the first window shows all the tools we can open" and "right now I have no
-- idea where the farm window is at".
--
--   minimap button   left-click  -> the Hub (every tool, click one to open it) - the main page: since 1.0 a new
--                                   install has every tool off, and this is where the player switches them on
--                    right-click -> the options window (a toggle: right-click again closes it); the BiS> Tools page in the
--                                   game's AddOns options is the dashboard
--                    drag        -> slides around the minimap rim (angle saved)
--   Hub row          left-click  -> open that tool's window (and switch it on); again: close it
--                    shift-click -> open it AND bring it to the middle of the screen
--                    right-click -> switch the tool on / off
--   Options          on/off per tool, then each tool's `options` list: toggles,
--                    3-way segs, steppers. "reset positions" drags every window
--                    back to the middle.
--
-- A tool takes part by giving the Registry `OnOpen(tool, db, recenter)` and an
-- `options` list (see Registry.lua). Windows use the Farm kit (K.*) and the
-- BiSTheme prompt, like Summon.
local _, NS = ...
local T = NS.T
local K = NS.Farm
local R = NS.Registry
local H = {}
NS.Hub = H

H.W, H.OPT_W = 170, 230
-- 20% BIGGER (Arn, 12 Oct, the Tools list and Options side by side: "lets make this 20% bigger"). The
-- whole window scales - rows, text, boxes together - so nothing moves out of place (BiS Healing's bind
-- window grew the same way, 10 Oct).
H.SCALE = 1.2
H.ROW = 16
H.SEG_W, H.STEP_W, H.BOX = 36, 18, 10   -- seg: "always" at 8 pt is ~29 px, keep 36

-- ---------------------------------------------------------------- db
function H.DB()
  local db = NS.DB()
  db.hub = db.hub or {}
  local h = db.hub
  if h.angle == nil then h.angle = 225 end
  if h.minimap == nil then h.minimap = true end
  return h
end

-- ---------------------------------------------------------------- minimap
-- Hand-rolled, no LibDBIcon: a 31 px round button riding the minimap rim at
-- db.hub.angle degrees (0 = east, counter-clockwise), like every other minimap
-- button the raid already has. Drag it and the angle follows the cursor.
--- THE RING IS MEASURED (14 Oct, Arn's cousin: "the minimap buttons are appearing on the inside of the
--- minimap"). 80 is right for a 140 px minimap only; Forever's is wider, and minimap addons resize it -
--- the same lesson BiSTheme's shared button learned 19 Sep ("everyone else's buttons are on the
--- outside"). Half the minimap's width plus H.MM_OVER, so the button straddles the edge; 80 when the
--- minimap will not say.
H.MM_OVER, H.MM_RADIUS = 10, 80
function H.MinimapRadius()
  local mm = _G.Minimap
  local ok, w = pcall(function() return mm and mm:GetWidth() end)
  if ok and type(w) == "number" and w > 0 then return w / 2 + H.MM_OVER end
  return H.MM_RADIUS
end

function H.MinimapPos(angle)
  local r = H.MinimapRadius()
  local a = math.rad(angle or 225)
  return math.cos(a) * r, math.sin(a) * r
end

function H.PlaceMinimap()
  local b = H.mm
  if not b then return end
  local x, y = H.MinimapPos(H.DB().angle)
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function H.DragMinimap()
  -- angle from the minimap centre to the cursor, in the minimap's own scale
  local mx, my = Minimap:GetCenter()
  local cx, cy = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  cx, cy = cx / scale, cy / scale
  local angle = math.deg(math.atan2(cy - my, cx - mx))
  H.DB().angle = angle
  H.PlaceMinimap()
end

function H.BuildMinimap()
  if H.mm or not Minimap then return H.mm end
  local b = CreateFrame("Button", "BiSToolsMinimap", Minimap)
  H.mm = b
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  -- ARTWORK, like LibDBIcon's icon: BACKGROUND is where a minimap button keeps its dark backing disc,
  -- and minimap skinners dim or restyle that layer - an icon left there was taken for the backing
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(18, 18)
  icon:SetPoint("CENTER", b, "CENTER", 0, 1)
  icon:SetTexture("Interface\\Icons\\Spell_Shadow_Twilight")
  if icon.SetTexCoord then icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
  b.icon = icon
  local ring = b:CreateTexture(nil, "OVERLAY")
  ring:SetSize(53, 53)
  ring:SetPoint("TOPLEFT")
  ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  b.ring = ring
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetSize(31, 31) hl:SetPoint("CENTER")
  hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  -- ONE STANDARD for every BiS minimap button (Forever 1.0, Arn 7 Nov: "we gotta get everything on the same
  -- page"): left = the main window (the Hub), right = options - the BiS> Tools page in the game's own options,
  -- else the own options window. No shift/ctrl/middle extras.
  b:SetScript("OnClick", function(self, button)
    if button == "RightButton" then H.OpenOptions() else H.ToggleHub() end
    H.UnburyIcon(self)
  end)
  b:SetScript("OnDragStart", function(self) self.dragging = true self:SetScript("OnUpdate", H.DragMinimap) end)
  b:SetScript("OnDragStop", function(self) self.dragging = nil self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(T.text("accent", "BiS") .. " Tools " .. T.text("muted", NS.VERSION))
    GameTooltip:AddLine("left-click  the tools", 1, 1, 1)
    GameTooltip:AddLine("right-click  options", 1, 1, 1)
    GameTooltip:AddLine("drag  move", 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  H.PlaceMinimap()
  H.ApplyMinimap()
  -- a minimap addon resizes the map AFTER login: the ring follows it
  if Minimap.HookScript then pcall(Minimap.HookScript, Minimap, "OnSizeChanged", function() H.PlaceMinimap() end) end
  return b
end

-- THE ICON WENT DARK AFTER A CLICK (Arn, 12 Oct: "i click the minimap button it goes dark and stays
-- dimmed"). Not ours: EllesmereUI's minimap collector puts a black box behind each button it gathers - a
-- CHILD of the button, pinned one level below it - and its click hook (_RaiseLateFlyoutChildren) lifts
-- EVERY child of the clicked button to DIALOG, so pop-ups show; its own box goes too, over the icon, and
-- nothing puts it back. This button has no children of its own, so whatever is under it is somebody
-- else's backing: a moment after the click (their hook runs after ours) it goes back below the button.
function H.UnburyIcon(b)
  if not (b and b.GetChildren and C_Timer and C_Timer.After) then return false end
  C_Timer.After(0, function()
    local level = (b.GetFrameLevel and b:GetFrameLevel()) or 1
    local strata = b.GetFrameStrata and b:GetFrameStrata()
    -- somebody else's child can be a frame the client locks away: the method LOOKUP is refused too, so it goes
    -- inside the pcall with the call
    for _, child in ipairs({ b:GetChildren() }) do
      if strata then pcall(function() child:SetFrameStrata(strata) end) end
      pcall(function() child:SetFrameLevel(math.max(0, level - 1)) end)
    end
  end)
  return true
end

function H.ApplyMinimap()
  if not H.mm then return end
  if H.DB().minimap == false then H.mm:Hide() else H.mm:Show() end
end

-- ---------------------------------------------------------------- shared bits
-- Window / Fit / Box / Control USED TO LIVE HERE. Arn, 10 Sep: "this is
-- beautiful ... I want all option windows to look like this", so they moved out
-- to Libs\BiSTheme\Options.lua and this file kept only what is actually about
-- BiSTools: the minimap button, the tools list, and which option belongs to
-- which tool. See claude/bis-options.md for the law, and note the copy under
-- Libs\ is byte-identical to BiSTheme's - never edit it in place.
-- ---------------------------------------------------------------- the Hub
function H.BuildHub()
  if H.hub then return H.hub end
  -- The list is not an options list, but it is the same chrome: the kit builds
  -- the frame, the prompt header and the 16 px rows, and the Hub decorates them.
  local f = BiSTheme.Options("BiSToolsHub", H.W, "Tools")
  if f.SetScale then f:SetScale(H.SCALE) end
  H.hub = f
  f:Recenter(120)
  local i = 0
  for key, tool in R:Each() do
    i = i + 1
    local r = f:AddRow("Button", "BiSToolsHubRow" .. i)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.bg = K.tex(r, "BACKGROUND", "sunken", 0)
    -- POPS under the mouse (the standing rule, Arn 6 Nov): an accent wash and a bar down the left edge
    r.wash = K.tex(r, "BORDER", "accent", 0.35)
    r.wash:SetAllPoints()
    r.wash:SetAlpha(0)
    r.bar = K.tex(r, "ARTWORK", "accent", 1)
    r.bar:SetPoint("TOPLEFT") r.bar:SetPoint("BOTTOMLEFT") r.bar:SetWidth(2)
    r.bar:SetAlpha(0)
    r.name = K.fs(r, tool.title or tool.name, 9, "ink")
    r.name:SetPoint("LEFT", 6, 0)
    r.state = K.fs(r, "", 8, "muted")
    r.state:SetPoint("RIGHT", -6, 0)
    r.key, r.tool = key, tool
    r:SetScript("OnClick", function(self, button)
      if button == "RightButton" then
        R:SetEnabled(self.key, not R:Enabled(self.key))
        f.con:Say(self.key .. (R:Enabled(self.key) and " on" or " off"), R:Enabled(self.key) and "good" or "warn")
      else
        H.Open(self.key, IsShiftKeyDown and IsShiftKeyDown())
      end
      H.PaintHub()
    end)
    r:SetScript("OnEnter", function(self)
      self.bg:SetAlpha(0.9)
      self.wash:SetAlpha(1) self.bar:SetAlpha(1)
      if GameTooltip then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.tool.title or self.tool.name)
        GameTooltip:AddLine(self.tool.desc or "", 1, 1, 1, true)
        GameTooltip:AddLine("click: open / close  |  shift-click: open in the middle  |  right-click: on/off", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
      end
    end)
    r:SetScript("OnLeave", function(self)
      self.bg:SetAlpha(0) self.wash:SetAlpha(0) self.bar:SetAlpha(0)
      if GameTooltip then GameTooltip:Hide() end
    end)
  end
  -- footer: one button, full width
  local foot = CreateFrame("Button", "BiSToolsHubOptions", f)
  foot:SetPoint("BOTTOMLEFT") foot:SetPoint("BOTTOMRIGHT")
  foot:SetHeight(K.HEADER)
  K.tex(foot, "BACKGROUND", "field", 0.9)
  foot.edge = K.border(foot, "edge", 1)
  foot.label = K.fs(foot, "options", 9, "ink2")
  foot.label:SetPoint("CENTER")
  foot.wash = K.tex(foot, "BORDER", "accent", 0.35)
  foot.wash:SetAllPoints()
  foot.wash:SetAlpha(0)
  foot:SetScript("OnClick", function() H.ToggleOptions() end)   -- beside the Hub: the same window the BiS> page holds
  foot:SetScript("OnEnter", function() foot.edge:set("accent", 1) foot.wash:SetAlpha(1) end)
  foot:SetScript("OnLeave", function() foot.edge:set("edge", 1) foot.wash:SetAlpha(0) end)
  f.foot = foot
  f:Fit(K.HEADER)   -- the footer is the Hub's own; an options window has none
  H.PaintHub()
  return f
end

function H.PaintHub()
  local f = H.hub
  if not f then return end
  local on = 0
  for _, r in ipairs(f.rows) do
    local en = R:Enabled(r.key)
    if en then on = on + 1 end
    local cr, cg, cb = K.color(en and "accent" or "muted")
    r.name:SetTextColor(cr, cg, cb, 1)
    r.state:SetText(en and T.text("good", "on") or T.text("warn", "off"))
  end
  f.con:Set("count", on .. " of " .. #f.rows .. " on", "ink2")
end

-- open a tool's window: switch it on if it was off, then hand it to the tool.
-- recenter = true (shift-click) drags the window to the middle of the screen.
-- CLICK AGAIN CLOSES (Arn, 19 Oct: "when i click these in bis tools some open and close some just
-- open"). Each tool opened its own way - the map's open flipped it, party/recap/rivals only opened, and
-- farm/threat/summon took a second click as "bring it to the middle" (10 Sep: "I can't find the window
-- for the farm"; shift-click does that now). Every window tool now says IsOpen and OnClose, so a click
-- on an open one closes it, the same for all. A tool with no window (social, bg) opens the options,
-- where its settings are.
function H.Open(key, recenter)
  local tool = R:Get(key)
  if not tool then return false end
  if not R:Enabled(key) then R:SetEnabled(key, true) end
  local db = R:DBFor(tool)
  local open = tool.IsOpen and tool:IsOpen(db)
  if open and not recenter and tool.OnClose then tool:OnClose(db) return "closed" end
  if tool.OnOpen then tool:OnOpen(db, recenter and true or false) return true end
  H.ToggleOptions(true)
  return "options"
end

function H.ToggleHub(want)
  local f = H.BuildHub()
  H.PaintHub()   -- the kit's Paint walks r.paint; the tool rows are painted here
  f:Toggle(want)
end

-- ---------------------------------------------------------------- Options
-- The four control kinds - toggle / seg / step / button - are the kit's now.
-- A setting that fits none of them is a slash command, not a fifth kind.

-- the Hub's own options, listed under "tools"
function H.OwnOptions()
  return {
    { kind = "toggle", label = "minimap button", help = "Show the BiS Tools button on the minimap. Off hides it; /bist still opens everything.", get = function() return H.DB().minimap ~= false end,
      set = function(_, on) H.DB().minimap = on and true or false H.ApplyMinimap() end },
    { kind = "toggle", label = "BiS channel (/biscomm)", help = "Lets BiS addons talk to each other's copies in your group and guild (summon facts, rivals the guild shares). Off: you hear nothing and say nothing.", get = function() local l = _G.LibBiSComm return l and l:Enabled() end,
      set = function(_, on) local l = _G.LibBiSComm if l then l:SetEnabled(on and true or false) end end },
    { kind = "button", label = "reset window positions", help = "Puts every BiS Tools window back in the middle of the screen, if one was dragged out of reach.", button = "reset", action = function() H.ResetPositions() end },
  }
end

function H.ResetPositions()
  for key, tool in R:Each() do
    if tool.OnOpen and R:Enabled(key) then tool:OnOpen(R:DBFor(tool), true) end
  end
  if H.hub then H.hub:Recenter(120) end
  if H.opt then H.opt:Recenter(60) end
end

function H.BuildOptions()
  if H.opt then return H.opt end
  local f = BiSTheme.Options("BiSToolsOptions", H.OPT_W, "Options")
  if f.SetScale then f:SetScale(H.SCALE) end
  H.opt = f
  f:Recenter(60)
  -- the tools list shows on/off too, so it repaints whenever a section box does
  f.onChange = function() H.PaintHub() end

  f:Section("tools")
  for _, opt in ipairs(H.OwnOptions()) do f:Row(opt, nil) end
  for key, tool in R:Each() do
    f:Section(tool.title or tool.name, {
      get = function() return R:Enabled(key) end,
      set = function(on) R:SetEnabled(key, on) end,
    })
    for _, opt in ipairs(tool.options or {}) do f:Row(opt, R:DBFor(tool)) end
  end
  f:Fit()
  -- the bg marks' live preview in the help strip (Arn: "a window to the helper thing to preview the look")
  if NS.BG and NS.BG.AttachPreview then NS.BG.AttachPreview(f) end
  return f
end

function H.PaintOptions()
  if H.opt then H.opt:Paint() end
end

function H.ToggleOptions(want)
  H.BuildOptions():Toggle(want)
end

-- ---------------------------------------------------------------- the BiS> page
-- ONE OPTIONS HOME (Forever 1.0, Arn 7 Nov: "when they open the options, they go to add-ons ... they'll just see
-- BiS> ... click into that add-on"): "BiS> Tools" under the game's own AddOns options (Libs\BiSTheme\Settings.lua),
-- holding the options window - every tool's on/off tick and its settings. A new install has every tool off, so this
-- (and the Hub) is where a player switches on what they want.

--- What is on, in a few words (the BiS> front page shows it): "3 of 15 tools on".
function H.Status()
  local on, all = 0, 0
  for key in R:Each() do
    all = all + 1
    if R:Enabled(key) then on = on + 1 end
  end
  return ("%d of %d tools on"):format(on, all)
end

-- ---------------------------------------------------------------- the dashboard
-- THE PAGE IS A COCKPIT, NOT THE OLD WINDOW IN A BOX (Arn, 7 Nov, the first live look: "we esentially just took
-- the old option window kept it the same size and nestels it inside a bigger window not taking advantage of the
-- bigger side" / "dont just shrink remake them all"). The whole page:
--   left    TOOLS - a row per tool, its lamp lit when on. Click = look at it; right-click = on / off.
--   right   the tool you picked: its name, a big ON/OFF switch, what it does in full words, a button to its
--           window, its commands, and every one of its settings as a big row (two columns when they will not fit)
--   bottom  the help strip: what the row under the mouse does
-- Built from the same Registry tables the Hub and the Options window read, so nothing is listed twice.
H.DASH = { LIST_W = 220, LIST_ROW = 26, GAP = 12, GENERAL = "_general" }

local function dashFont(s, size) if BiSTheme.SetFont then BiSTheme.SetFont(s, size) end end

--- Every entry of the list: the addon's own settings first, then each tool in the Registry's order.
function H.DashEntries()
  local out = { { key = H.DASH.GENERAL, title = "BiS Tools", desc = "The addon itself: its minimap button, the shared "
    .. "BiS channel every BiS addon talks over, and putting every BiS Tools window back on the screen.",
    options = H.OwnOptions(), general = true } }
  for key, tool in R:Each() do
    out[#out + 1] = { key = key, tool = tool, title = tool.title or tool.name, desc = tool.desc, options = tool.options or {} }
  end
  return out
end

function H.BuildDash(body)
  local BT, D = BiSTheme, H.DASH
  local d = { body = body, entries = H.DashEntries(), rows = {}, pages = {} }
  body.dash = d
  H.dash = d
  d.help = BT.DashHelp(body, "Point at a tool or a setting to read what it does. Right-click a tool in the list to switch it on or off.")
  d.help:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 0, 0)
  d.help:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)
  -- left: the list
  d.list = BT.DashPanel(body, "TOOLS")
  d.list:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
  d.list:SetPoint("BOTTOMLEFT", d.help, "TOPLEFT", 0, D.GAP)
  d.list:SetWidth(D.LIST_W)
  d.count = K.fs(d.list, "", 11, "ink2")
  dashFont(d.count, 11)
  d.count:SetPoint("TOPRIGHT", d.list, "TOPRIGHT", -10, -10)
  for i, e in ipairs(d.entries) do
    local r = CreateFrame("Button", nil, d.list)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetHeight(D.LIST_ROW)
    r:SetPoint("TOPLEFT", d.list, "TOPLEFT", 6, -(d.list.HEAD + (i - 1) * (D.LIST_ROW + 2)))
    r:SetPoint("RIGHT", d.list, "RIGHT", -6, 0)
    r.bg = K.tex(r, "BACKGROUND", "sunken", 0.7)
    r.bg:SetAllPoints()
    r.wash = K.tex(r, "BORDER", "accent", 0.35)
    r.wash:SetAllPoints()
    r.wash:SetAlpha(0)
    r.bar = K.tex(r, "ARTWORK", "accent", 1)
    r.bar:SetPoint("TOPLEFT") r.bar:SetPoint("BOTTOMLEFT") r.bar:SetWidth(3)
    r.bar:SetAlpha(0)
    r.lamp = K.tex(r, "OVERLAY", "line2", 1)
    r.lamp:SetSize(8, 8)
    r.lamp:SetPoint("LEFT", 10, 0)
    r.name = K.fs(r, e.title, 12, "ink")
    dashFont(r.name, 12)
    r.name:SetPoint("LEFT", 26, 0)
    r.state = K.fs(r, "", 11, "muted")
    dashFont(r.state, 11)
    r.state:SetPoint("RIGHT", -8, 0)
    r.entry = e
    r:SetScript("OnClick", function(self, button)
      if button == "RightButton" and self.entry.tool then
        H.DashSwitch(self.entry.key, not R:Enabled(self.entry.key))
      else
        H.DashSelect(self.entry.key)
      end
    end)
    r:SetScript("OnEnter", function(self)
      self.wash:SetAlpha(1) self.bar:SetAlpha(1)
      d.help:Say(self.entry.desc)
    end)
    r:SetScript("OnLeave", function(self)
      self.wash:SetAlpha(0) self.bar:SetAlpha(self.entry.key == d.selected and 1 or 0)
      d.help:Idle()
    end)
    d.rows[i] = r
  end
  -- right: the picked tool
  local p = BT.DashPanel(body, "")
  d.detail = p
  p:SetPoint("TOPLEFT", d.list, "TOPRIGHT", D.GAP, 0)
  p:SetPoint("BOTTOMRIGHT", d.help, "TOPRIGHT", 0, D.GAP)
  p.name = K.fs(p, "", 20, "accent")
  dashFont(p.name, 20)
  p.name:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -12)
  p.switch = BT.DashSwitch(p, function() if d.selected ~= H.DASH.GENERAL then H.DashSwitch(d.selected, not R:Enabled(d.selected)) end end)
  p.switch:SetPoint("TOPRIGHT", p, "TOPRIGHT", -12, -12)
  p.desc = K.fs(p, "", 12, "ink2")
  dashFont(p.desc, 12)
  if p.desc.SetWordWrap then p.desc:SetWordWrap(true) end
  p.desc:SetPoint("TOPLEFT", p.name, "BOTTOMLEFT", 0, -8)
  p.desc:SetPoint("RIGHT", p, "RIGHT", -14, 0)
  p.open = BT.DashButton(p, "open its window", 150, function()
    local key = d.selected
    if BT.CloseSettingsPanel then BT.CloseSettingsPanel() end
    H.Open(key)
    H.PaintDash()
  end)
  p.usage = K.fs(p, "", 11, "muted")
  dashFont(p.usage, 11)
  p.usage:SetPoint("RIGHT", p, "RIGHT", -14, 0)
  p.none = K.fs(p, "Nothing to set: it just works while it is on.", 12, "muted")
  dashFont(p.none, 12)
  H.DashSelect(d.selected or d.entries[2] and d.entries[2].key or H.DASH.GENERAL)
  return d
end

--- The settings rows of one entry, built the first time it is picked.
function H.DashPage(e)
  local d = H.dash
  if d.pages[e.key] then return d.pages[e.key] end
  local db = e.tool and R:DBFor(e.tool) or nil
  local ctx = { help = d.help, onChange = function() H.PaintHub() H.PaintOptions() H.PaintDash() end }
  local rows = {}
  for i, opt in ipairs(e.options) do rows[i] = BiSTheme.DashControl(d.detail, opt, db, ctx) end
  d.pages[e.key] = rows
  return rows
end

function H.DashSelect(key)
  local d = H.dash
  if not d then return end
  d.selected = key
  for k, rows in pairs(d.pages) do
    if k ~= key then for _, r in ipairs(rows) do r:Hide() end end
  end
  H.PaintDash()
end

function H.DashSwitch(key, on)
  R:SetEnabled(key, on)
  H.PaintHub()
  H.PaintOptions()
  H.PaintDash()
end

--- Lay the picked entry's rows out: under its words, one column, or two when one will not fit the panel.
function H.DashLayout(p, rows, top)
  local D = BiSTheme.SETTINGS.DASH
  local step = D.ROW + 4
  local h = p.GetHeight and p:GetHeight() or 0
  local w = p.GetWidth and p:GetWidth() or 0
  local avail = (type(h) == "number" and h or 0) + top - 12
  local cols = (avail > 0 and #rows * step > avail and type(w) == "number" and w > 0) and 2 or 1
  local per = math.ceil(#rows / cols)
  local colW = cols == 2 and (w - 28 - 10) / 2 or nil
  for i, r in ipairs(rows) do
    local c = math.floor((i - 1) / per)
    local y = top - ((i - 1) % per) * step
    r:ClearAllPoints()
    if cols == 1 then
      r:SetPoint("TOPLEFT", p, "TOPLEFT", 14, y)
      r:SetPoint("RIGHT", p, "RIGHT", -14, 0)
    else
      r:SetPoint("TOPLEFT", p, "TOPLEFT", 14 + c * (colW + 10), y)
      r:SetWidth(colW)
    end
    r:Show()
  end
  return cols
end

function H.PaintDash()
  local d = H.dash
  if not d then return end
  local on, all = 0, 0
  for _, r in ipairs(d.rows) do
    local e = r.entry
    local en = e.tool and R:Enabled(e.key)
    if e.tool then
      all = all + 1
      if en then on = on + 1 end
      r.lamp:SetColorTexture(K.color(en and "good" or "line2"))
      r.state:SetText(en and "ON" or "off")
      r.state:SetTextColor(K.color(en and "good" or "muted"))
      r.name:SetTextColor(K.color(en and "ink" or "ink2"))
    else
      r.lamp:SetColorTexture(K.color("accent"))
      r.state:SetText("")
    end
    local picked = e.key == d.selected
    r.bar:SetAlpha(picked and 1 or 0)
    r.bg:SetColorTexture(K.color(picked and "line2" or "sunken"))
  end
  d.count:SetText(on .. " of " .. all .. " on")
  -- the picked one
  local e
  for _, x in ipairs(d.entries) do if x.key == d.selected then e = x end end
  if not e then return end
  local p = d.detail
  local en = e.tool and R:Enabled(e.key)
  p.name:SetText(e.title)
  p.desc:SetText(e.desc or "")
  if e.tool then p.switch:Set(en) p.switch:Show() else p.switch:Hide() end
  local top = -(12 + 24 + 8 + 48)                              -- under the name and two or three lines of words
  local canOpen = e.tool and e.tool.OnOpen
  if canOpen then
    p.open:ClearAllPoints()
    p.open:SetPoint("TOPLEFT", p, "TOPLEFT", 14, top)
    p.open:Show()
    top = top - 34
  else
    p.open:Hide()
  end
  if e.tool and e.tool.usage then
    p.usage:ClearAllPoints()
    p.usage:SetPoint("TOPLEFT", p, "TOPLEFT", 14, top)
    p.usage:SetText("command:  " .. e.tool.usage)
    p.usage:Show()
    top = top - 22
  else
    p.usage:Hide()
  end
  local rows = H.DashPage(e)
  if #rows == 0 then
    p.none:ClearAllPoints()
    p.none:SetPoint("TOPLEFT", p, "TOPLEFT", 14, top - 4)
    p.none:Show()
  else
    p.none:Hide()
    d.cols = H.DashLayout(p, rows, top)
  end
  for _, r in ipairs(rows) do
    r:Paint()
    r:SetDim(e.tool ~= nil and not en)
  end
end

function H.RegisterSettings()
  if not (BiSTheme and BiSTheme.SettingsPage) then return nil end
  return BiSTheme.SettingsPage("BiSTools", {
    title = "Tools",
    about = "Small tools, each with its own switch - a new install starts with every one off. Pick a tool on the "
      .. "left to see what it does, switch it on, and set it up.",
    status = H.Status,
    build = function(body) H.BuildDash(body) end,
    refresh = function() H.PaintDash() end,
    open = { label = "the tools list", func = function() H.ToggleHub(true) end },
    api = { name = "BiSToolsAPI", about = "party list, rivals and the ride clock, read-only (API.lua, version "
      .. tostring(rawget(_G, "BiSToolsAPI") and BiSToolsAPI.version or "?") .. ")" },
  })
end

--- The minimap's right-click: the OWN options window, a toggle (Arn, 7 Nov live: "when i right click the minimap
--- again it should close that option window ... we keep them opening how they used to"). The BiS> Tools page is
--- the dashboard in the game's options, reached from Esc > Options > AddOns.
function H.OpenOptions()
  H.ToggleOptions()
  return "window"
end

-- ---------------------------------------------------------------- boot
-- at login, after every tool registered (this file is last in the TOC)
H.frame = CreateFrame("Frame")
H.frame:RegisterEvent("PLAYER_LOGIN")
H.frame:SetScript("OnEvent", function()
  H.BuildMinimap()
  pcall(H.RegisterSettings)            -- an older client without the game's panel: nil, the own window still works
end)

-- /bist hub | /bist options  (the slash is the fallback; the button is the way)
NS.HubSlash = function(cmd)
  if cmd == "options" or cmd == "opt" or cmd == "config" then H.ToggleOptions() return true end
  if cmd == "hub" or cmd == "tools" or cmd == "show" then H.ToggleHub() return true end
  if cmd == "minimap" then H.DB().minimap = not (H.DB().minimap ~= false) H.ApplyMinimap()
    NS.Print("minimap button %s", H.DB().minimap and T.text("good", "on") or T.text("warn", "off")) return true end
  return false
end
