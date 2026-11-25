-- BiSTools / Tools / FarmArrow.lua
-- ONE ARROW TO THE SPAWN MOST LIKELY UP NEXT (6 Oct 2026).
--
-- Arn, looking at a Spawns window seventeen zones long: "this old window is getting out of hand,
-- i think the minimap function is easier to read ... how about we work on an arrow like the spawn
-- window that directs us to the mark that ... might spawn soon, after a few kills it'll know this
-- marker is spawning every x minutes."
--
-- It already knows: every spot learns its respawn from the gaps between kills there (FarmSpots'
-- `learn`, the median of the gaps). The arrow reads the same order the window sorts by
-- (S.Describe's key): what is UP first, then what is due SOONEST, then - where no respawn is known
-- yet - the one killed LONGEST ago. A tie goes to the nearer spot. Only spots on the map you are
-- on: a bearing across two maps is not a thing the client can give.
--
-- It spent an afternoon as the top row of the Spawns window ("we put that arrow in the current
-- spawn list window"); that was "a little crowded", so it floats on its own now - see A.Build.
local _, NS = ...
local F = NS.Farm
local S = F and F.Spots
local T = NS.T

local A = {}
F.Arrow = A

--- The spot most likely up next, on this map: spot, its timer text, colour, yards, its mark.
function A.Next(db)
  local mob = S and S.Shown(db)
  local list = mob and db.spots and db.spots[mob]
  if not list then return nil end
  local map, px, py = S.Here()
  if not map then return nil end
  local now = time()
  local best, bestKey, bestD, bestText, bestColour, bestMark
  local function consider(sp, parent)
    local spMap = sp.map or (parent and parent.map)
    if spMap ~= map or type(sp.x) ~= "number" or type(sp.y) ~= "number" then return end
    local text, colour, key = S.Describe(sp, now)
    local d = S.Yards(map, px, py, sp.x, sp.y)
    if not bestKey or key < bestKey or (key == bestKey and d < bestD) then
      best, bestKey, bestD, bestText, bestColour = sp, key, d, text, colour
      bestMark = sp.mark or (parent and parent.mark)
    end
  end
  for _, z in ipairs(list) do
    if z.subs and #z.subs > 0 then
      for _, sb in ipairs(z.subs) do consider(sb, z) end
    else
      consider(z, nil)
    end
  end
  if not best then return nil end
  return best, bestText, bestColour, bestD, bestMark, px, py
end

-- BIG AND ON ITS OWN, LIKE RESTEDXP'S (6 Oct 2026). The row in the Spawns window was "a little
-- crowded"; Arn: "can we make it big like the rested one" - RestedXP's waypoint arrow, floating
-- on screen with "Step 76 (46yd)" under it. So:
--
--          ^          a big arrow that turns with you
--     [mark] 1:33     which spot, and its timer (up / due in / since the last kill)
--       (10 yd)       how far
--
-- Drag it anywhere; it remembers. It shows only while a mob is being farmed - nothing to point at
-- is nothing on the screen.
A.W, A.H = 120, 86
A.ARROW = 56

function A.Build(db)
  if A.frame then return A.frame end
  local f = CreateFrame("Frame", "BiSToolsFarmArrow", UIParent)
  A.frame = f
  f:SetSize(A.W, A.H)
  f:SetFrameStrata("MEDIUM")
  local p = db.arrowPos or { "CENTER", 0, 160 }
  f:SetPoint(p[1], UIParent, p[1], p[2], p[3])
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    NS.LetGo(self)
    local point, _, _, x, y = self:GetPoint()
    db.arrowPos = { point or "CENTER", math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5) }
  end)

  A.arrow = f:CreateTexture(nil, "ARTWORK")
  A.arrow:SetSize(A.ARROW, A.ARROW)
  A.arrow:SetPoint("TOP", 0, 0)
  A.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")

  -- the line under it: the mark (or #number) and the timer, centred as one
  A.line = CreateFrame("Frame", nil, f)
  A.line:SetSize(A.W, 18)
  A.line:SetPoint("TOP", A.arrow, "BOTTOM", 0, 0)
  A.mark = A.line:CreateTexture(nil, "ARTWORK")
  A.mark:SetSize(16, 16)
  A.mark:SetPoint("LEFT", 0, 0)
  A.id = F.fs(A.line, "", 11, "muted")
  A.id:SetPoint("LEFT", 0, 0)
  A.clock = F.fs(A.line, "", 13, "ink")
  A.clock:SetPoint("LEFT", A.mark, "RIGHT", 4, 0)
  A.dist = F.fs(f, "", 10, "muted")
  A.dist:SetPoint("TOP", A.line, "BOTTOM", 0, -1)
  A.none = F.fs(f, "no spot here", 10, "muted")
  A.none:SetPoint("TOP", A.arrow, "BOTTOM", 0, -2)
  A.none:Hide()
  for _, fs in ipairs({ A.id, A.clock, A.dist, A.none }) do
    if fs.SetShadowOffset then fs:SetShadowOffset(1, -1) end       -- readable over any ground
  end

  -- the arrow turns with the player, so it TURNS 20 times a second while shown (OnUpdate is
  -- silent on a hidden frame). Which spot, its timer and the yards are worked out 4 times a
  -- second (7 Oct 2026, the cost pass): picking the spot walks every spot with a map-size question
  -- each, and doing that 20 times a second all evening was ~3,000 client calls a second for a
  -- timer that only changes once a second.
  local acc, full = 0, 0
  f:SetScript("OnUpdate", function(_, el)
    acc, full = acc + (el or 0), full + (el or 0)
    if acc < A.TURN_EVERY then return end
    acc = 0
    if full >= A.PICK_EVERY then full = 0 A.Refresh(db) else A.Turn() end
  end)
  f:Hide()
  return f
end

--- Should it be on screen at all: the farm tool on, the arrow switched ON, a mob being farmed.
--- OFF UNTIL ASKED (Arn, 22 Oct: "turn the arrow off by default too", after his cousin wanted it gone): only a saved
--- `true` - /bist farm arrow on - shows it. A save that never touched it (nil) is off now, with no switch needed.
function A.Wanted(db)
  return db.arrow == true and db.active ~= nil and NS.Registry:Enabled("farm")
end

function A.Refresh(db)
  if not A.Wanted(db) then return A.Hide() end
  A.Build(db)
  if not A.frame:IsShown() then A.frame:Show() end
  local sp, text, colour, d, mark, px, py = A.Next(db)
  if not sp then
    A.mark:Hide() A.id:SetText("") A.clock:SetText("") A.dist:SetText("") A.arrow:Hide()
    A.none:Show()
    A.current = nil                    -- nothing for A.Turn to point at
    return
  end
  A.none:Hide()
  local markW
  if mark then
    A.mark:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. mark)
    A.mark:Show()
    A.id:SetText("")
    markW = 16
  else
    A.mark:Hide()
    A.id:SetText("#" .. tostring(sp.id or "?"))
    markW = A.id.GetStringWidth and A.id:GetStringWidth() or 14
  end
  A.clock:ClearAllPoints()
  A.clock:SetPoint("LEFT", mark and A.mark or A.id, "RIGHT", 4, 0)
  A.clock:SetText(text or "")
  local r, g, b = F.color(colour or "ink")
  A.clock:SetTextColor(r, g, b, 1)
  -- centre mark + timer as one line under the arrow
  local cw = A.clock.GetStringWidth and A.clock:GetStringWidth() or 30
  local total = markW + 4 + cw
  A.mark:ClearAllPoints() A.mark:SetPoint("LEFT", (A.W - total) / 2, 0)
  A.id:ClearAllPoints() A.id:SetPoint("LEFT", (A.W - total) / 2, 0)
  A.dist:SetText(("(%d yd)"):format(d or 0))
  local rot = S.Bearing(px, py, sp.x, sp.y)
  if rot then A.arrow:SetRotation(rot) A.arrow:Show() else A.arrow:Hide() end
  A.current = sp
end

A.TURN_EVERY, A.PICK_EVERY = 0.05, 0.25

--- Between full refreshes: only turn the arrow toward the spot already picked. One position read.
function A.Turn()
  local sp = A.current
  if not (sp and A.arrow) then return end
  local _, px, py = S.Here()
  local rot = px and S.Bearing(px, py, sp.x, sp.y)
  if rot then A.arrow:SetRotation(rot) A.arrow:Show() else A.arrow:Hide() end
end

function A.Show(db) A.Refresh(db) end

function A.Hide()
  if A.frame then A.frame:Hide() end
end

--- /bist farm arrow [on|off]
function A.Set(db, want)
  if want == nil then want = db.arrow ~= true end
  db.arrow = want and true or false
  A.Refresh(db)
  return db.arrow
end

-- ride the farm tool's own switch: on with it (here), off with it (its OnDisable calls A.Hide)
local hook = F.Hook
function F.Hook(db)
  hook(db)
  A.Refresh(db)
end
