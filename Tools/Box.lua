-- BiSTools / Tools / Box.lua
-- THE BUTTONS, IN ONE TIDY BOX (12 Oct 2026). Arn, asked where the farm's target button should go:
-- "lets keep all button neat maybe in a bis farm box, like the bis now, maybe if we have bis now it just
-- puts the button there cross addon".
--
-- "BiS> tools": a small header and a row of buttons - the farm's target button (F.TargetButton, the
-- farm key, now with a face and a skull) and the rival target button (Recap.lua). Each shows only when
-- it has something to do: a mob being farmed, a rival in gold. No button, no box.
--
-- BESIDE BiS> NOW, NOT INSIDE IT. When BiS Healing's "BiS> now" block is up, this box docks to its right
-- edge and moves with it, so the two read as one strip; without it, the box stands where you dragged it.
-- Putting these buttons INSIDE BiS Healing's block would mean two addons rewriting one set of secure
-- buttons - each would have to know the other's layout and combat queue. Side by side, either addon
-- still works alone.
--
-- Everything here is out of combat: the box holds secure buttons, so moving, showing or re-parenting it
-- in a fight is refused. A change asked for in combat waits for PLAYER_REGEN_ENABLED.
local _, NS = ...
local R = NS.Registry

-- HEADER 16 and lifted 2, BiS Healing's bars' (Grid.lua HEADER_H, HEADER_LIFT): the box sits beside them
local B = { SIZE = 28, GAP = 3, PAD = 4, HEADER = 16, LIFT = 2, MIN_W = 70, NOW_HEADER = 16 }
B.DOCKS = { "auto", "right", "below", "left", "top" }
NS.Box = B

local function K() return NS.Farm end

function B.DB()
  local d = NS.DB()
  d.box = type(d.box) == "table" and d.box or {}
  return d.box
end

function B.Build()
  if B.frame then return B.frame end
  local F = K()
  local f = CreateFrame("Frame", "BiSToolsBox", UIParent)
  f:SetFrameStrata("MEDIUM")
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  F.tex(f, "BACKGROUND", "frame", 0.85)
  F.border(f, "edge", 0.6)
  -- the header: the family's "BiS>" and a word; drag it to move the box (when it is not docked)
  local head = CreateFrame("Frame", nil, f)
  head:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, B.LIFT)
  head:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, B.LIFT)
  head:SetHeight(B.HEADER)
  F.tex(head, "BACKGROUND", "header", 0.9)
  -- THE FAMILY PROMPT, like every BiS> bar (Arn, 12 Oct: "the bis headers are all different fonts ...
  -- lets get them all the same"): purple BiS>, the word, the blinking _, at BiS Healing's size - the box
  -- sits beside its bars. Painted from OnUpdate, which only runs while the box is shown.
  head.label = head:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  head.label:SetPoint("LEFT", head, "LEFT", 4, 0)
  if BiSTheme and BiSTheme.Console then
    head.con = BiSTheme.Console(head.label, { width = 90, size = 10 })
    head.con:Set("name", "tools")
    local acc = 0
    head:SetScript("OnUpdate", function(_, dt)
      acc = acc + (dt or 0)
      if acc >= 0.2 then acc = 0 head.con:Paint() end
    end)
  else
    head.label:SetText(NS.T.text("accent", "BiS>") .. " tools")
  end
  head:EnableMouse(true)
  head:RegisterForDrag("LeftButton")
  -- THE SAME CLICKS AS BiS> NOW'S HEADER (Arn, 12 Oct: "should have these same clicks and drags so i
  -- can move it if i want"): drag it anywhere - that undocks it, and it stays where it is dropped;
  -- shift-click sends it round BiS> now: auto, right, below, left, top, and auto again.
  head:SetScript("OnDragStart", function()
    if InCombatLockdown and InCombatLockdown() then return end
    f:StartMoving()
    B.moving = true
  end)
  head:SetScript("OnDragStop", function()
    if not B.moving then return end
    B.moving = false
    f:StopMovingOrSizing()
    local point, _, rel, x, y = f:GetPoint(1)
    B.DB().pos = { point or "CENTER", x or 0, y or 0, rel or point or "CENTER" }
    B.DB().dock = "free"
    B.docked = false
  end)
  head:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" and IsShiftKeyDown and IsShiftKeyDown() then B.NextDock() end
  end)
  head:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("drag to move the tools box", 1, 0.82, 0)
    GameTooltip:AddLine("shift-click to send it round BiS> now", 1, 1, 1)
    GameTooltip:AddLine("now: " .. (B.DB().dock or "auto"), 0.6, 0.6, 0.65)
    GameTooltip:Show()
  end)
  head:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  f.head = head
  f:Hide()
  B.frame = f
  return f
end

--- Give a button a face: a dark well, the icon, a coloured edge.
local function dress(b, icon, edge)
  if b.boxed then return end
  local F = K()
  F.tex(b, "BACKGROUND", "field", 0.95)
  b.icon = b.icon or b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2) b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon:SetTexture(icon)
  b.edge = b.edge or F.border(b, edge, 1)
  b.boxed = true
end

-- WHICH BUTTON IS WHICH, AT A GLANCE (Arn, 12 Oct: "whats the best way to distinguish ... the right one is the
-- player and the left one is the npc farm mobs" ... "do the purple and red buttons"). The crosshair colours:
-- PURPLE for mobs (the farm's skull), RED for players (the rival button, crossed swords). Two pixels, so
-- the colour reads before the icon does.
B.EDGE = 2
function B.Colour(b, rgb)
  local e = b and b.edge
  if not (e and rgb) then return false end
  for _, side in ipairs({ "top", "bottom", "left", "right" }) do
    local tex = e[side]
    if tex then
      tex:SetColorTexture(rgb[1], rgb[2], rgb[3], 1)
      if side == "top" or side == "bottom" then tex:SetHeight(B.EDGE) else tex:SetWidth(B.EDGE) end
    end
  end
  b.edgeColour = rgb
  return true
end

--- The buttons the box may hold, each with when it shows.
function B.Buttons()
  local out = {}
  local F, RC = K(), NS.Recap
  if F and F.TargetButton then
    local fb = F.TargetButton()
    dress(fb, "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", "accent")
    B.Colour(fb, RC and RC.MOB_PURPLE or { 0.73, 0.50, 1.00 })
    if not fb.tipped then
      fb:HookScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Target " .. tostring(F.db and F.db.active or "the mob you farm"))
        GameTooltip:AddLine("A fresh copy, with the skull. /bist farm key <key> binds it.", 1, 1, 1, true)
        GameTooltip:Show()
      end)
      fb:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
      fb.tipped = true
    end
    local fdb = F.db
    out[#out + 1] = { b = fb, show = R:Enabled("farm") and fdb and fdb.active and fdb.button ~= false and true or false }
  end
  if RC and RC.tbtn then
    B.Colour(RC.tbtn, RC.MARK_RED)
    local db = R:DBFor(R:Get("recap"))
    out[#out + 1] = { b = RC.tbtn, show = (RC.tbtn.count or 0) > 0 and db.button ~= false and R:Enabled("rivals") }
  end
  -- the battleground "+ rival" button (Arn, 13 Oct: "a bg button that rivals someone"): only in a
  -- battleground or arena, where the right-click menu cannot carry "add rival"
  if RC and RC.AddButton then
    local db = R:DBFor(R:Get("recap"))
    local ab = RC.AddButton(db)
    B.Colour(ab, RC.MARK_RED)
    RC.PaintAdd()
    out[#out + 1] = { b = ab, show = R:Enabled("rivals") and RC.InPvP() and db.addButton ~= false }
  end
  -- the battleground "mark" (Arn, 14 Oct): their healers and killer, read now - battlegrounds only
  local BG = NS.BG
  if BG and BG.BoxButton then
    local mb = BG.BoxButton()
    B.Colour(mb, BG.WHITE)
    out[#out + 1] = { b = mb, show = R:Enabled("bg") and BG.InBG() and true or false }
  end
  -- your party list (Arn, 15 Oct: "the saved list to invite is nice and a disband button"): GREEN
  -- invites, RED disbands - each only when it means something now (Party.lua)
  local P = NS.Party
  if P and P.Buttons then
    local ib, db_ = P.Buttons()
    B.Colour(ib, P.GREEN)
    B.Colour(db_, P.RED)
    local members = P.Members()            -- one walk of the roster for both questions
    out[#out + 1] = { b = ib, show = P.ShowInvite(P.db, members) }
    out[#out + 1] = { b = db_, show = P.ShowDisband(P.db, members) }
  end
  -- the XP buffs (Arn, 6 Nov: Well-Rested, Well Fed, the Cozy Sleeping Bag - XP.lua): each only while it needs you
  local XP = NS.XP
  if XP and XP.Buttons then
    local bag, food, tent = XP.Buttons()
    -- Arn's order (6 Nov): "camp tent down, sleeping bag and food"
    if tent then out[#out + 1] = { b = tent, show = XP.ShowTent() } end
    out[#out + 1] = { b = bag, show = XP.ShowBag() }
    out[#out + 1] = { b = food, show = XP.ShowFood() }
  end
  -- BiS> processing (Arn, 6 Nov): while something in the bags is ready for your profession (Processing.lua)
  local PR = NS.Proc
  if PR and PR.BoxButton then out[#out + 1] = { b = PR.BoxButton(), show = PR.ShowBox() } end
  -- BiS> pups (Arn, 6 Nov: "fidget spinner to press while traveling"): on a flight or mounted (Pups.lua)
  local PU = NS.Pups
  if PU and PU.BoxButton then out[#out + 1] = { b = PU.BoxButton(), show = PU.ShowBox() } end
  return out
end

-- a frame's edges on screen, or nil (a frame not yet placed answers nothing)
local function rect(fr)
  if not (fr and fr.GetLeft) then return nil end
  local ok, l, r, t, b = pcall(function() return fr:GetLeft(), fr:GetRight(), fr:GetTop(), fr:GetBottom() end)
  if not (ok and type(l) == "number" and type(r) == "number" and type(t) == "number" and type(b) == "number") then return nil end
  return l, r, t, b
end

--- Would the box, put against BiS> now's right edge, sit on BiS Healing's grid (its header included)?
function B.WouldCoverGrid(now)
  local hdr = _G.BiSHealingForeverHeader
  local grid = hdr and hdr.GetParent and hdr:GetParent()
  local gl, gr, gt, gb = rect(grid)
  local nl, nr, nt = rect(now)
  if not (gl and nl) then return false end
  local _, _, ht = rect(hdr)
  gt = math.max(gt, ht or gt)                      -- the grid's own header sits above its cells
  local w = (B.frame and B.frame:GetWidth()) or B.MIN_W
  local h = (B.frame and B.frame:GetHeight()) or (B.SIZE + B.PAD * 2)
  local x1, x2 = nr + 6, nr + 6 + (w or B.MIN_W)
  local top, bottom = nt + B.HEADER + 1, nt - (h or B.SIZE)
  return x1 < gr and x2 > gl and bottom < gt and top > gb
end

--- Where the box stands: docked to BiS> now when it is up, else where it was dragged.
function B.Place()
  local f = B.frame
  if not f then return end
  local now = _G.BiSHealingNowBlock
  f:ClearAllPoints()
  local want = B.DB().dock or "auto"
  if now and now.IsShown and now:IsShown() and want ~= "free" then
    -- AUTO: RIGHT OF IT, UNLESS THAT IS ON THE GRID (Arn, 12 Oct, BiS> now on the grid's left: "it
    -- overlapped into the healing frames"). Then BELOW it, which is open ground wherever BiS> now sits.
    local side = want
    if side == "auto" then side = B.WouldCoverGrid(now) and "below" or "right" end
    local H = B.HEADER + 4
    if side == "below" then f:SetPoint("TOPLEFT", now, "BOTTOMLEFT", 0, -H)
    elseif side == "left" then f:SetPoint("TOPRIGHT", now, "TOPLEFT", -6, 0)
    elseif side == "top" then f:SetPoint("BOTTOMLEFT", now, "TOPLEFT", 0, H + B.NOW_HEADER)
    else f:SetPoint("TOPLEFT", now, "TOPRIGHT", 6, 0) side = "right" end
    B.dock = side
    B.docked = true
    -- BiS> now showing, hiding or moving (shift-click sends it round the grid) moves us too: hooked
    -- once; the relayout itself waits for the end of a fight like every other
    if not B.nowHooked and now.HookScript then
      now:HookScript("OnShow", function() B.Refresh() end)
      now:HookScript("OnHide", function() B.Refresh() end)
      if hooksecurefunc then pcall(hooksecurefunc, now, "SetPoint", function() B.Refresh() end) end
      B.nowHooked = true
    end
  else
    local pos = B.DB().pos or { "CENTER", 0, -180, "CENTER" }
    f:SetPoint(pos[1], UIParent, pos[4] or pos[1], pos[2], pos[3])
    B.docked = false
  end
end

--- Shift-click: the next place round BiS> now (a dragged box comes back to "auto").
function B.NextDock()
  local cur = B.DB().dock or "auto"
  local nextOne = "auto"
  for i, d in ipairs(B.DOCKS) do
    if d == cur then nextOne = B.DOCKS[i % #B.DOCKS + 1] end
  end
  B.DB().dock = nextOne
  B.Refresh()
  return nextOne
end

--- How many buttons fit on one row before the grid. NEVER UNDER THE GRID (Arn, 6 Nov: "the tool is putting a
--- button under the healing frames ... its the processing button"): docked below BiS> now, which sits on the
--- grid's left, a long row ran on under the grid's cells. A row stops at the grid's left edge and wraps.
function B.PerRow(n)
  if not B.docked then return n end
  local hdr = _G.BiSHealingForeverHeader
  local grid = hdr and hdr.GetParent and hdr:GetParent()
  local gl = rect(grid)
  local nl, nr = rect(_G.BiSHealingNowBlock)
  if not (gl and nl) then return n end
  local left
  if B.dock == "below" or B.dock == "top" then left = nl
  elseif B.dock == "right" then left = nr + 6
  else return n end
  if gl <= left then return n end                  -- the grid is not to our right: nothing to stop at
  local per = math.floor((gl - left - B.PAD + B.GAP) / (B.SIZE + B.GAP))
  return math.max(1, math.min(n, per))
end

--- Lay the box out: the buttons that have something to do, left to right, wrapping before the grid; none, no box.
function B.Refresh()
  if InCombatLockdown and InCombatLockdown() then B.dirty = true return false end
  B.dirty = nil
  local f = B.Build()
  local shown = {}
  for _, e in ipairs(B.Buttons()) do
    local b = e.b
    if b:GetParent() ~= f then b:SetParent(f) end
    b:ClearAllPoints()
    if e.show then shown[#shown + 1] = b else b:Hide() end
  end
  local n = #shown
  B.count = n
  if n == 0 then f:Hide() return true end
  -- one row first, so the dock is chosen the same way as before; then wrap where the grid starts
  f:SetSize(math.max(B.MIN_W, B.PAD * 2 + n * B.SIZE + (n - 1) * B.GAP), B.SIZE + B.PAD * 2)
  B.Place()
  local per = B.PerRow(n)
  local rows = math.ceil(n / per)
  for i, b in ipairs(shown) do
    local col, row = (i - 1) % per, math.floor((i - 1) / per)
    b:SetSize(B.SIZE, B.SIZE)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", B.PAD + col * (B.SIZE + B.GAP), -(B.PAD + row * (B.SIZE + B.GAP)))
    b:Show()
  end
  f:SetSize(math.max(B.MIN_W, B.PAD * 2 + per * B.SIZE + (per - 1) * B.GAP),
            B.PAD * 2 + rows * B.SIZE + (rows - 1) * B.GAP)
  f:Show()
  return true
end

-- a tool switched on or off changes what the box holds
do
  local set = R.SetEnabled
  function R:SetEnabled(...)
    local r = set(self, ...)
    B.Refresh()
    return r
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
-- into or out of a battleground: the "+ rival" button comes or goes (the loading screen is out of combat)
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_ENABLED" and not B.dirty then return end
  B.Refresh()
end)
B.events = ev
