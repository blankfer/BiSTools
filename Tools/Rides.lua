-- BiSTools / Tools / Rides.lua
-- THE RIDES TOOL: a little card with the zeppelins and boats from where you stand (21 Oct 2026).
--
-- Arn: "if you have BiS Tools installed, do you get a little card when you're in Orgrimmar in the top left side of
-- the screen, something that just says Zeppelin arriving, leaving in X amount of time" - and then "the timer lives
-- in the libraries, so somebody that has BiS Healing and leaves can start the timer and someone that is not on the
-- Zeppelin will get [it] ... somebody with BiS Tools ... their card will say ... Zeppelin just arrived, leaving for
-- Undercity" - "everybody with the library does not show the clock by default. BiS Tools enables the card and
-- more options live in BiS Tools" - "the library still draws nothing".
--
-- So the CLOCK is LibBiSComm's (minor 15, RIDE): every BiS addon learns a ride by watching you ride it and shares it
-- with your guild and group. This tool only SHOWS it - A POP-UP (Arn, later that evening: "only pop out when it
-- arrives and itll show up and say zep to grom leaves in 1 minute ... and if the zeps are far they hide"): at a
-- tower or dock - or in its capital, Orgrimmar for Durotar's tower - a card at the top left while a ride waits at
-- the dock, "Zeppelin to Grom'gol - leaves in 0:58", and who timed it; hidden while none waits. "all rides" (an
-- option) shows every ride from here, coming and going. A watch looks once a second only where a ride is; nothing
-- ticks anywhere else, or in an instance. It also hands the lib its saved table (db.clock), so the clock outlives
-- a logout.
local _, NS = ...
local T, R = NS.T, NS.Registry

local RD = { W = 300, LINE = 16, TOP = 22, EVERY = 1 }
-- THE ANNOUNCER (Arn, 21 Oct: "it should be this guys portrait telling you like he is announcing"): a row per ride
-- that waits - his face (the stop's master, 3D, by npc id), his name, his line in quotes
RD.ROW, RD.FACE = 46, 40
-- who announces a ride when its stop has no master of its own (Forever's own crew; npc ids from Arn's probes)
RD.CRIER, RD.CRIERNAME = {}, {}
NS.Rides = RD

function RD.Lib()
  local lib = _G.LibBiSComm
  if lib and lib.RidesAt then return lib end
  return nil
end

--- HOW SURE THE CARD IS, NOT HOW OLD (Arn, 22 Oct, the card reading "timed by Chain Healz - BiSGamba, 634:12 ago": "id
--- like the time ... instead be a confidence % the longer its been since a reading the less confidence its correct").
--- A reading is right when it is taken (give or take RD.READ_ERR); after that, every lap the ride runs can carry the
--- loop's own small error, and the laps add up. The % is the chance the countdown is still within RD.SURE_WITHIN
--- seconds of the truth - a bell curve as wide as the reading's error and the loop's error times the laps since.
--- A loop measured end to end (the lib's RIDE_LOOP) drifts slower than one learned from rides.
RD.SURE_WITHIN, RD.READ_ERR = 10, 2
RD.LAP_ERR = { measured = 1, learned = 4 }
-- A SERVER RESTART RESETS EVERY ZEPPELIN, and the client cannot tell us one happened. Past RD.RESTART_AFTER the timing
-- may belong to a world that has since restarted: 0%. (Polestar's timetable drops its own after 6 h for the same
-- reason - studied 22 Oct; Arn: "add the 6 hour drop".)
RD.RESTART_AFTER = 6 * 3600

local function erf(x)                          -- Abramowitz and Stegun 7.1.26: good to 1.5e-7
  local s = x < 0 and -1 or 1
  x = math.abs(x)
  local t = 1 / (1 + 0.3275911 * x)
  local p = ((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t
  return s * (1 - p * math.exp(-x * x))
end

--- 0-100: how likely the countdown for this ride is still right, or nil with nothing to judge by.
function RD.Confidence(sched, stop)
  local lib = RD.Lib()
  if lib and lib.RideSure then return lib:RideSure(sched, stop) end   -- lib 17: the lib's own, every addon the same
  if not (sched and type(sched.rtt) == "number" and sched.rtt > 0 and type(sched.age) == "number") then return nil end
  if sched.age > RD.RESTART_AFTER then return 0 end
  local lib = RD.Lib()
  local measured = lib and type(lib.RIDE_LOOP) == "table" and stop and lib.RideKey
    and lib.RIDE_LOOP[lib:RideKey(stop)] ~= nil
  local drift = math.max(0, sched.age) / sched.rtt * (measured and RD.LAP_ERR.measured or RD.LAP_ERR.learned)
  local width = math.sqrt(RD.READ_ERR ^ 2 + drift ^ 2)
  return math.floor(100 * erf(RD.SURE_WITHIN / (width * math.sqrt(2))) + 0.5)
end

function RD.SureColour(pct)
  if pct >= 80 then return "good" elseif pct >= 50 then return "gold" end
  return "warn"
end

local function plainNum(v)
  if v == nil or type(v) ~= "number" then return nil end
  if issecretvalue then
    local ok, yes = pcall(issecretvalue, v)
    if not ok or yes then return nil end
  end
  return v
end

--- Where you stand: the map the client says (a capital is its own map; the lib counts it as its zone's).
function RD.Map()
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local ok, map = pcall(C_Map.GetBestMapForUnit, "player")
  return ok and plainNum(map) or nil
end

local function inInstance()
  if not IsInInstance then return false end
  local ok, inside = pcall(IsInInstance)
  if not ok then return true end
  if issecretvalue then
    local ok2, yes = pcall(issecretvalue, inside)
    if not ok2 or yes then return true end
  end
  return inside and true or false
end

function RD.Inside()
  if not inInstance() then return false end
  -- the Deeprun Tram: an instance with rides (lib 17) - asked only inside one, so the open world pays nothing for it
  local lib = RD.Lib()
  if lib and lib.InTram and lib:InTram() then return false end
  return true
end

--------------------------------------------------------------------
-- the card
--------------------------------------------------------------------

function RD.Build()
  if RD.frame then return RD.frame end
  local F = NS.Farm
  local f = CreateFrame("Frame", "BiSToolsRides", UIParent)
  RD.frame = f
  f:SetSize(RD.W, 40)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    RD.dragged = true
    if not InCombatLockdown() then self:StartMoving() end
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    if RD.db then RD.db.pos = { p, rp, x, y } end
  end)
  -- SHIFT-CLICK: RIDE-TRAK (Arn, 23 Oct: "people [should] be able to shift left click this and show a mock tracker
  -- like tram trak"). A plain click, or the end of a drag, does nothing.
  f:SetScript("OnMouseUp", function(_, button)
    local dragged = RD.dragged
    RD.dragged = nil
    if button == "LeftButton" and not dragged and IsShiftKeyDown and IsShiftKeyDown() then RD.ToggleTrak() end
  end)
  F.tex(f, "BACKGROUND", "frame", 0.88)
  F.border(f, "edge", 1)
  f.title = F.fs(f, "BiS> rides from here", 10, "accent")
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
  -- THE X (Arn, 23 Oct: "some people might want to close it and if they close it it should stop popping up ... we
  -- should print the command to enable it again")
  f.x = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  f.x:SetSize(20, 20)
  f.x:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
  f.x:SetScript("OnClick", function() RD.Close() end)
  f.lines = {}
  f.foot = F.fs(f, "", 9, "dim")
  f:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText("BiS> rides")
    GameTooltip:AddLine("Every zeppelin and boat runs a fixed loop. Anyone with a BiS addon who rides one times it, "
      .. "and your guild and group get the clock - so one rider sets it for everyone.", 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine("Shift-click: RIDE-TRAK - where each ride is on its line, live.", 0.4, 1, 0.5, true)
    GameTooltip:AddLine("Drag to move it. The X stops it popping up (/bist rides on brings it back).", 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  f:Hide()
  RD.Place()
  return f
end

--- A row of the card: a face (3D), a name, a line that may wrap to two.
function RD.Row(f, i)
  f.rows = f.rows or {}
  local row = f.rows[i]
  if row then return row end
  local F = NS.Farm
  row = CreateFrame("Frame", nil, f)
  row:SetSize(RD.W - 12, RD.ROW)
  local m = CreateFrame("DressUpModel", nil, row)
  m:SetSize(RD.FACE, RD.FACE)
  m:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
  m:Hide()
  row.face = m
  row.who = F.fs(row, "", 10, "accent")
  row.say = F.fs(row, "", 11, "gold")
  row.say:SetJustifyH("LEFT")
  if row.say.SetWordWrap then row.say:SetWordWrap(true) end
  f.rows[i] = row
  f.lines[i] = row.say                 -- the API's RideCard reads the lines
  return row
end

--- His face: the creature by npc id, close (a portrait), asked again once if the client had to fetch it.
-- HOW CLOSE HIS FACE (Arn's Undercity screenshot, 23 Oct: "the goblins are cut off" - at zoom 1 Zapetta and Hin
-- Denburg showed as thin slices; Snurk in Orgrimmar had looked fine). A little way out by default; `/bist rides zoom
-- <0.3-1>` to try it live (db.zoom).
RD.ZOOM = 0.75
function RD.Zoom()
  local z = RD.db and tonumber(RD.db.zoom)
  if z and z >= 0.3 and z <= 1 then return z end
  return RD.ZOOM
end

function RD.Face(row, npc)
  local m = row.face
  if not npc then m:Hide() row.npc = nil return nil end
  if row.npc == npc and m:IsShown() then return npc end
  row.npc = npc
  m:Show()
  pcall(m.ClearModel, m)
  pcall(m.SetCreature, m, npc)
  if m.SetPortraitZoom then pcall(m.SetPortraitZoom, m, RD.Zoom()) end
  if C_Timer and C_Timer.After then
    C_Timer.After(0.6, function()
      if row.npc ~= npc then return end
      local ok, file = pcall(m.GetModelFileID, m)
      if ok and type(file) == "number" and file > 0 then return end
      pcall(m.SetCreature, m, npc)
      if m.SetPortraitZoom then pcall(m.SetPortraitZoom, m, RD.Zoom()) end
    end)
  end
  return npc
end

function RD.Place()
  local f, pos = RD.frame, RD.db and RD.db.pos
  if not f then return end
  f:ClearAllPoints()
  if type(pos) == "table" and type(pos[1]) == "string" then
    f:SetPoint(pos[1], UIParent, pos[2] or pos[1], tonumber(pos[3]) or 0, tonumber(pos[4]) or 0)
  else
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -140)
  end
end

--- The card away (the watch may go on: a ride can still come in).
function RD.HideCard()
  local f = RD.frame
  if f and f:IsShown() then f:Hide() end
  RD.HideStrips(1)                                          -- RIDE-TRAK goes with it, and stops repainting
  RD.TrakWatching(false)
end

--- Everything off: the card, and the once-a-second watch.
function RD.Hide()
  RD.HideCard()
  RD.Watching(false)
  RD.TrakWatching(false)
end

--- The X: the card stops popping up, and says how to bring it back.
function RD.Close()
  if RD.db then RD.db.card = false end
  RD.Paint()
  NS.Print("the ride card won't pop up any more - |cff66ff80/bist rides on|r brings it back")
end

--- THE HUB'S CLICK ALWAYS ANSWERS (Arn, 5 Nov: "i clicked the setting thing and nothing happend i thought it was
--- bugged"). It used to repaint only, so after the X - or with no ride waiting - nothing moved and nothing was said.
--- Now: the card back on if the X had closed it, and every ride from here on it, waiting or not (RD.asked = this
--- spot, until you walk away from it; "all rides" itself is left as it was). Where it cannot show, one line says why.
function RD.Ask(db)
  RD.db = db
  local back = db.card == false
  db.card = true
  RD.asked, RD.seenAt = true, nil                         -- RD.Paint pins it to this spot; ask where you are NOW
  RD.Paint()
  local here = RD.asked ~= true and RD.asked or nil
  if RD.asked == true then RD.asked = nil end              -- nothing to pin it to (no ride here, an instance)
  local f = RD.frame
  local on = back and "the ride card: on again. " or ""
  if f and f:IsShown() then
    if back then NS.Print("the ride card: on again - it pops up while a ride waits (|cff66ff80/bist rides off|r stops it)") end
    return true
  end
  if RD.seenInside then
    NS.Print("%sno rides inside an instance - the card comes back outside", on)
  elseif here then                                         -- a ride here, the card kept away on purpose
    NS.Print("%sBiS Shell's TRAM-TRAK is showing the tram - the card waits until it closes", on)
  else
    NS.Print("%sno zeppelin, boat or tram from here - the card shows at a zeppelin tower, a boat dock or a tram platform, and in their capitals", on)
  end
  return false
end

--------------------------------------------------------------------
-- RIDE-TRAK: each ride on its line, live (BiS Shell's TRAM-TRAK, for every zeppelin and boat)
--------------------------------------------------------------------
-- A strip per ride, right under its announcer's row (Arn, 23 Oct: "id like the tracker under the respective goblin
-- so its easier to read"): here on the left, its far end on the right, the ride a gold block on the line,
-- moving; not timed yet = SCANNING, a bar sweeping the line. Open, the card stays up where a ride is (every ride
-- from here, docked or not) - the point is watching them come. The line's place comes from the lib's own schedule
-- (docked, seconds left, the loop): it docks here, crosses in half a loop less a dwell, docks there, comes back.
-- Open, it repaints RD.TRAK_EVERY seconds; closed, nothing of it ticks.
RD.TRAK_H, RD.TRAK_IN, RD.TRAK_EVERY = 50, 30, 0.25
-- FOUR LANES, NOTHING ON TOP OF ANYTHING (Arn, 23 Oct: "re arrange stuff so stuff does not get cut off" - his face at
-- the far end sat on "Undercity"): your face above the line; the line and the ride RD.LINE_Y over the middle; "here"
-- and where it goes UNDER the line's two ends; the words at the bottom
RD.LINE_Y = 4

--- Where a ride is on its line: 0 = here, 1 = its far end; and what it is doing ("here", "out", "there", "back")
--- with the seconds until the next thing happens.
function RD.Where(sched, dwell)
  if not (sched and type(sched.rtt) == "number" and type(sched.left) == "number") then return nil end
  local rtt, D = sched.rtt, dwell or 60
  local half = rtt / 2
  local phase = sched.docked and (D - sched.left) or (rtt - sched.left)
  if phase < D then return 0, "here", D - phase end
  if phase < half then return (phase - D) / (half - D), "out", half - phase end
  if phase < half + D then return 1, "there", half + D - phase end
  return 1 - (phase - half - D) / (half - D), "back", rtt - phase
end

--- The server's second, smoothed with the frame clock so a block glides instead of hopping once a second.
function RD.SmoothNow(lib, t)
  local s = lib.RideNow()
  t = t or (GetTime and GetTime()) or 0
  if s ~= RD.lastS then RD.lastS, RD.lastT = s, t end
  return s + math.max(0, math.min(0.99, t - (RD.lastT or t)))
end

function RD.ToggleTrak(on)
  local db = RD.db
  if not db then return nil end
  if on == nil then on = not db.trak end
  db.trak = on and true or nil
  RD.Paint()
  return db.trak
end

RD.trakWatch = CreateFrame("Frame")
function RD.TrakWatching(on)
  local w = RD.trakWatch
  if on and not w:GetScript("OnUpdate") then
    RD.trakWait = RD.TRAK_EVERY
    w:SetScript("OnUpdate", function(_, elapsed)
      RD.trakWait = RD.trakWait - (tonumber(elapsed) or 0)
      if RD.trakWait > 0 then return end
      RD.trakWait = RD.TRAK_EVERY
      -- the whole card, not only the strips: a goblin's "0:21" over his strip's "0:20" (Arn's screenshot, 23 Oct)
      -- was the once-a-second words lagging the strips' four
      RD.Paint(nil, true)
    end)
  elseif not on and w:GetScript("OnUpdate") then
    w:SetScript("OnUpdate", nil)
  end
end

RD.STRIP_W = RD.W - 12                                      -- a row's width: the strip sits in the card, under its row
-- WHERE AM I ON IT (Arn, 23 Oct: "can it guesstimate what track we are on and put our 2d portrait there?"): riding a
-- ride the lib saw you board (lib.riding) - your face rides its block; standing within RD.NEAR map units of a stop
-- (the lib's own measured spots) - your face at that line's "here" end, by the dock; anywhere else, no face: a guess
-- that far off would be wrong. Where you stand is asked once a second, and only while RIDE-TRAK is open.
RD.ME, RD.NEAR = 18, 4
RD.ROUND = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

--- Which of the card's rides you are on or at: its index in the list, and "ride" (aboard) or "dock" (on its
--- platform); nil when neither.
function RD.Mine(lib, list)
  local near = RD.seenX and RD.seenMap and lib.RideNear and lib:RideNear(RD.seenMap, RD.seenX, RD.seenY, RD.NEAR) or nil
  -- THE DOCK WINS (Arn, 23 Oct, on the platform in Ghost Wolf: "it thought i was on - should have a check to put me
  -- back on the dock"): on a platform you are at the dock, whatever the lib's riding says - unless you are being
  -- CARRIED right now (moving RD.CARRIED map units a second while your own feet are still, the lib's own rule)
  local carried = RD.seenSpeed and RD.seenSpeed >= RD.CARRIED and RD.seenFeet == false
  local on = lib.riding and lib.riding.from
  if on and lib.RideKey and (carried or not near) then
    local key = lib:RideKey(on)
    for i, e in ipairs(list) do if lib:RideKey(e.stop) == key then return i, "ride" end end
  end
  if near then
    for i, e in ipairs(list) do if e.stop == near then return i, "dock" end end
  end
  return nil
end
RD.CARRIED = 0.2                                            -- the lib's RIDE_CARRY: a zeppelin cruises at 0.5-0.6

--- MAKE IT POP (Arn, 23 Oct, showing Forever's own map beside Classic's: "look how little map changes make the name
--- pop out more" - the same names, heavier, with an edge round each letter). On our dark strip: an outline and a
--- shadow, so a name stands off the line and the screen behind it.
function RD.Pop(fs, size)
  fs:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
  if fs.SetShadowColor then fs:SetShadowColor(0, 0, 0, 1) end
  if fs.SetShadowOffset then fs:SetShadowOffset(1, -1) end
  return fs
end

--- One strip of the card's: built once, reused.
function RD.Strip(f, i)
  f.strips = f.strips or {}
  local s = f.strips[i]
  if s then return s end
  local F = NS.Farm
  s = CreateFrame("Frame", nil, f)
  s:SetSize(RD.STRIP_W, RD.TRAK_H)
  local bg = s:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(s)
  bg:SetColorTexture(0.02, 0.05, 0.03, 0.9)                 -- TRAM-TRAK's green-black screen
  s.line = s:CreateTexture(nil, "BORDER")
  s.line:SetColorTexture(0.4, 1, 0.5, 0.6)
  s.line:SetHeight(2)
  s.line:SetPoint("LEFT", s, "LEFT", RD.TRAK_IN, RD.LINE_Y)
  s.line:SetPoint("RIGHT", s, "RIGHT", -RD.TRAK_IN, RD.LINE_Y)
  s.here = RD.Pop(F.fs(s, "here", 9, "ink"), 9)
  s.here:SetPoint("TOPLEFT", s, "LEFT", RD.TRAK_IN - 4, RD.LINE_Y - 4)
  s.there = RD.Pop(F.fs(s, "", 9, "ink"), 9)
  s.there:SetPoint("TOPRIGHT", s, "RIGHT", -RD.TRAK_IN + 4, RD.LINE_Y - 4)
  s.ride = s:CreateTexture(nil, "OVERLAY")
  s.ride:SetColorTexture(1, 0.82, 0.2, 1)
  s.ride:SetSize(12, 8)
  s.ride2 = s:CreateTexture(nil, "OVERLAY")
  s.ride2:SetColorTexture(1, 0.82, 0.2, 1)
  s.ride2:SetSize(12, 8)
  s.ride2:Hide()
  s.sweep = s:CreateTexture(nil, "OVERLAY")
  s.sweep:SetColorTexture(0.4, 1, 0.5, 0.9)
  s.sweep:SetSize(3, 16)
  s.word = RD.Pop(F.fs(s, "", 9, "dim"), 9)
  s.word:SetPoint("BOTTOM", s, "BOTTOM", 0, 3)
  -- YOU (RD.Mine): your own face, round, above the line where you are
  s.me = s:CreateTexture(nil, "OVERLAY", nil, 7)
  s.me:SetSize(RD.ME, RD.ME)
  if s.CreateMaskTexture and s.me.AddMaskTexture then
    local m = s:CreateMaskTexture()
    m:SetAllPoints(s.me)
    m:SetTexture(RD.ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    s.me:AddMaskTexture(m)
  end
  s.me:Hide()
  f.strips[i] = s
  return s
end

--- The card's strips from the i-th on, away.
function RD.HideStrips(from)
  local f = RD.frame
  for i = from or 1, #(f and f.strips or {}) do f.strips[i]:Hide() end
end

--- What the card's strips show now (Paint places them, each under its row; this only fills them in).
function RD.PaintTrak(list, t)
  local lib, f = RD.Lib(), RD.frame
  local db = RD.db
  if not (lib and f and f:IsShown() and db and db.trak) then
    RD.HideStrips(1)
    RD.TrakWatching(false)
    return nil
  end
  list = list or RD.trakList or {}
  RD.trakList = list
  local now = RD.SmoothNow(lib, t)
  local span = RD.STRIP_W - 2 * RD.TRAK_IN
  local out = {}
  for i, e in ipairs(list) do
    local s = RD.Strip(f, i)
    s.there:SetText(tostring(e.stop.toName or "?"))
    local sched = lib:RideSched(e.stop, now)
    local x, what, secs = RD.Where(sched, sched and sched.dwell or lib.RIDE_DWELL)
    if not x then
      -- SCANNING: nobody has timed it - the bar sweeps the line, a computer at work
      s.ride:Hide()
      s.ride2:Hide()
      s.sweep:ClearAllPoints()
      s.sweep:SetPoint("CENTER", s, "LEFT", RD.TRAK_IN + (now * 0.5 % 1) * span, RD.LINE_Y)
      s.sweep:Show()
      s.word:SetText("SCANNING - ride it once to lock on" .. string.rep(".", math.floor(now * 2) % 4))
      out[i] = "scanning"
    else
      s.sweep:Hide()
      s.ride:ClearAllPoints()
      s.ride:SetPoint("CENTER", s, "LEFT", RD.TRAK_IN + x * span, RD.LINE_Y)
      s.ride:Show()
      -- THE TRAM'S SECOND CAR (lib 17, sched.cars): its own block, half a loop behind
      local other
      for _, c in ipairs(sched.cars or {}) do
        if c.docked ~= sched.docked or c.left ~= sched.left then other = c end
      end
      local x2 = other and RD.Where({ rtt = sched.rtt, docked = other.docked, left = other.left }, sched.dwell)
      if x2 then
        s.ride2:ClearAllPoints()
        s.ride2:SetPoint("CENTER", s, "LEFT", RD.TRAK_IN + x2 * span, RD.LINE_Y)
        s.ride2:Show()
      else
        s.ride2:Hide()
      end
      local clock = lib.RideClock(math.ceil(secs - 1e-6))      -- whole seconds up: the card's own count (Arn saw 0:22 under 0:23)
      local to = tostring(e.stop.toName or "?")
      s.word:SetText(what == "here" and ("Docked here - leaves in " .. clock)
        or what == "out" and ("On its way to " .. to .. " - there in " .. clock)
        or what == "there" and ("Docked at " .. to .. " - leaves in " .. clock)
        or ("Coming back - here in " .. clock))
      out[i] = x
    end
    s:Show()
  end
  RD.HideStrips(#list + 1)
  -- you: above your ride's block while aboard, above "here" while on its platform
  local mi, how = RD.Mine(lib, list)
  for i = 1, #list do
    local s = f.strips[i]
    local x = how == "dock" and 0 or (type(out[i]) == "number" and out[i]) or nil
    -- in the tram you know exactly where you are on the line: your own spot along it, whichever car you are on
    local e = list[i]
    local far = how == "ride" and e and e.stop.kind == "tram" and lib.ridePartner and lib.ridePartner[e.stop.id]
    if far and RD.seenX and far.x ~= e.stop.x then
      x = math.max(0, math.min(1, (e.stop.x - RD.seenX) / (e.stop.x - far.x)))
    end
    if i == mi and x then
      if not s.me.face then s.me.face = pcall(SetPortraitTexture, s.me, "player") end
      s.me:ClearAllPoints()
      s.me:SetPoint("CENTER", s, "LEFT", RD.TRAK_IN + x * span, RD.LINE_Y + RD.ME / 2 + 3)
      s.me:Show()
    else
      s.me:Hide()
    end
  end
  RD.mine = mi and how or nil
  RD.TrakWatching(true)
  return out
end

--- THE WATCH: once a second while you are where a ride is (its zone, or its capital) - so the card can pop up the
--- moment one docks; nothing ticks anywhere else.
RD.watch = CreateFrame("Frame")
function RD.Watching(on)
  local w = RD.watch
  if on and not w:GetScript("OnUpdate") then
    RD.wait = RD.EVERY
    w:SetScript("OnUpdate", function(_, elapsed)
      RD.wait = RD.wait - (tonumber(elapsed) or 0)
      if RD.wait > 0 then return end
      RD.wait = RD.EVERY
      RD.Paint()
    end)
  elseif not on and w:GetScript("OnUpdate") then
    w:SetScript("OnUpdate", nil)
  end
end

--- What the announcer says: "All aboard for Grom'gol - we lift off in 0:58!" (a ship sails).
function RD.Cry(lib, e)
  local to = tostring(e.stop.toName)
  -- WITH RIDE-TRAK OPEN HE STAYS (Arn, 23 Oct: "if the trak window is open it should not close the cards"): gone or
  -- not timed, he says so in his own voice
  if not e.sched then return ("\"Nobody's timed the one for %s yet - ride it once!\""):format(to) end
  if not e.sched.docked then
    return ("\"Next one for %s is here in %s.\""):format(to, lib.RideClock(e.sched.left))
  end
  return ("\"All aboard for %s - we %s in %s!\""):format(to,
    e.stop.kind == "zeppelin" and "lift off" or e.stop.kind == "tram" and "roll" or "sail", lib.RideClock(e.sched.left))
end

--- A ride in the card's words. THE POP-UP (Arn, 21 Oct: "i want it to only pop out when it arrives and itll show up
--- and say zep to grom leaves in 1 minute ... and if the zeps are far they hide"): only what waits at the dock now,
--- "Zeppelin to Grom'gol - leaves in 0:58". With "all rides" on: every ride from here, coming and going.
function RD.Line(lib, e, all)
  if all then return lib:RideLine(e.stop, e.sched) end
  return ("%s to %s - leaves in %s"):format(e.stop.kind == "zeppelin" and "Zeppelin" or e.stop.kind == "tram" and "Tram" or "Boat",
    tostring(e.stop.toName),
    lib.RideClock(e.sched.left))
end

--- The card now: where a ride is, it pops up while one waits at the dock (or, with "all rides", shows them all);
--- anywhere else, in an instance, or switched off: nothing. Answers the lines it shows.
function RD.Paint(now, quick)
  local lib, db = RD.Lib(), RD.db
  if not (lib and db and R:Enabled("rides") and db.card ~= false) then RD.asked = nil return RD.Hide() end
  -- QUICK (RIDE-TRAK's four a second): where you are, asked at most once a second - the map and "in an instance?"
  -- do not change between a quarter-second and the next
  local t = quick and GetTime and GetTime() or nil         -- the clock only on the quick road: the card alone never asks
  if not (t and RD.seenAt and t >= RD.seenAt and t - RD.seenAt < 1) then
    RD.seenAt, RD.seenInside = t, RD.Inside()
    if db.trak and lib.RideSpot then                         -- RIDE-TRAK open: your spot too, for your face on it
      local m0, x0, y0, c0 = RD.seenMap, RD.seenX, RD.seenY, RD.seenClock
      RD.seenMap, RD.seenX, RD.seenY = lib:RideSpot()
      RD.seenClock = t or (GetTime and GetTime()) or 0
      -- how fast you go, and whether your own feet move: carried or walking (RD.Mine)
      RD.seenSpeed = nil
      if m0 and m0 == RD.seenMap and x0 and RD.seenX and c0 then
        RD.seenSpeed = math.sqrt((RD.seenX - x0) ^ 2 + (RD.seenY - y0) ^ 2) / math.max(0.2, RD.seenClock - c0)
      end
      local okF, feet = pcall(IsPlayerMoving or function() return nil end)
      local hidden = issecretvalue and select(2, pcall(issecretvalue, feet))
      RD.seenFeet = nil                                     -- a hidden yes/no is never tested
      if okF and hidden ~= true and feet ~= nil then RD.seenFeet = feet and true or false end
    else
      RD.seenMap, RD.seenX, RD.seenY = RD.Map(), nil, nil
      -- THE DEEPRUN TRAM has no map (lib 17): the lib's own spot there, along the track - which platform you are on
      if not RD.seenMap and lib.TramSpot then RD.seenMap, RD.seenX, RD.seenY = lib:TramSpot() end
    end
  end
  if RD.seenInside then return RD.Hide() end
  local map = RD.seenMap
  local here = map and lib:RidesAt(map, now) or {}
  -- the Hub's ask (RD.Ask): pinned to this spot; walk somewhere else and the card is the plain pop-up again
  if RD.asked == true then RD.asked = #here > 0 and map or true
  elseif RD.asked and RD.asked ~= map then RD.asked = nil end
  if #here == 0 then return RD.Hide() end
  RD.Watching(true)
  if map == lib.TRAM_MAP then
    -- ONE CARD (Arn, 23 Oct: "i can ship in both but dont want two cards floating"): BiS Shell's TRAM-TRAK up, ours
    -- waits; the watch goes on, so it comes back the moment TRAM-TRAK goes
    local api = rawget(_G, "BiSShellAPI")
    if api and api.TramShown then
      local okT, up = pcall(api.TramShown)
      if okT and up == true then RD.HideCard() return {} end
    end
    -- the tram's two platforms are one place to the lib: only YOUR side's tram, by where you stand along the line
    if RD.seenX and #here == 2 then
      local a, b = here[1], here[2]
      here = { math.abs(a.stop.x - RD.seenX) <= math.abs(b.stop.x - RD.seenX) and a or b }
    end
  end
  local all = db.all == true or (RD.asked ~= nil and RD.asked == map)
  local trak = db.trak == true                 -- RIDE-TRAK open: every ride from here stays on the card
  local pick = {}
  for _, e in ipairs(here) do
    if all or trak or (e.sched and e.sched.docked) then pick[#pick + 1] = e end
  end
  if #pick == 0 then RD.HideCard() return {} end
  local F = NS.Farm
  local f = RD.Build()
  local shown, newest, newestStop = {}, nil, nil
  local y = RD.TOP
  for i, e in ipairs(pick) do
    local row = RD.Row(f, i)
    -- the announcer for a ride that waits - and, with RIDE-TRAK open, for every ride (he stays and says when it's back);
    -- "all rides" alone keeps its plain list
    local plain = not trak and (all or not (e.sched and e.sched.docked))
    local face = not plain and (RD.CRIER[e.stop.id] or e.stop.npc) or nil
    local who = (RD.CRIER[e.stop.id] and RD.CRIERNAME and RD.CRIERNAME[e.stop.id]) or e.stop.who
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -y)
    RD.Face(row, face)
    local x = face and (RD.FACE + 6) or 0
    row.who:ClearAllPoints()
    row.who:SetPoint("TOPLEFT", row, "TOPLEFT", x, -2)
    row.say:ClearAllPoints()
    row.say:SetPoint("TOPLEFT", row, "TOPLEFT", x, plain and -2 or -14)
    row.say:SetWidth(RD.W - 18 - x)
    local text = plain and RD.Line(lib, e, true) or RD.Cry(lib, e)
    row.who:SetText(plain and "" or tostring(who or ""))
    if plain then row.who:Hide() else row.who:Show() end
    row.say:SetText(text)
    local r, g, b = F.color((e.sched and e.sched.docked) and "gold" or (e.sched and "ink" or "dim"))
    row.say:SetTextColor(r, g, b, 1)
    row:Show()
    -- AS TALL AS ITS TEXT (Arn's Skycutter card, 5 Nov: "Zeppelin to Zephras Isle - here now, leaves in 0:47" wrapped
    -- and its second line sat on the foot): a row grows to its wrapped line, never shorter than before
    local textH = row.say.GetStringHeight and tonumber(row.say:GetStringHeight()) or 0
    local tall = plain and math.max(RD.LINE, textH + 3) or math.max(RD.ROW, 14 + textH + 2)
    row:SetHeight(tall)
    y = y + tall
    if trak then                                            -- its own line, right under him
      local s = RD.Strip(f, i)
      s:ClearAllPoints()
      s:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -y)
      y = y + RD.TRAK_H + 4
    end
    shown[#shown + 1] = text
    if e.sched and (not newest or e.sched.age < newest.age) then newest, newestStop = e.sched, e.stop end
  end
  for i = #pick + 1, #f.rows do f.rows[i]:Hide() end
  local h = y
  f.foot:ClearAllPoints()
  f.foot:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -h - 1)
  local foot = ""
  if newest and db.who ~= false then
    local sure = RD.Confidence(newest, newestStop)
    foot = ("timed by %s%s%s"):format(tostring(newest.by or "?"), newest.via and (" - " .. newest.via) or "",
      sure and (" - " .. NS.T.text(RD.SureColour(sure), sure .. "% sure")) or "")
  elseif not newest then
    foot = "ride one once - your guild gets the clock"
  end
  f.foot:SetText(foot)
  if foot ~= "" then f.foot:Show() else f.foot:Hide() end
  f:SetHeight(h + (foot ~= "" and 16 or 6))
  if not f:IsShown() then f:Show() end
  RD.PaintTrak(trak and pick or {}, t)
  return shown
end

--------------------------------------------------------------------
-- events, the tool
--------------------------------------------------------------------

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS" }) do
  ev:RegisterEvent(e)
end
ev:SetScript("OnEvent", function() if RD.db then RD.Paint() end end)
RD.events = ev

--- The lib's saved place: BiS Tools' table, so the clock survives a logout (the lib has no SavedVariables).
function RD.Keep(db)
  local lib = RD.Lib()
  if not lib then return nil end
  if type(db.clock) ~= "table" then db.clock = {} end
  pcall(lib.RideStore, lib, db.clock)
  if not RD.hooked and lib.RegisterCallback then
    RD.hooked = true
    lib:RegisterCallback("RIDE", function() if RD.db then RD.Paint() end end)   -- a sighting heard: repaint
  end
  return db.clock
end

R:Register({
  name = "rides",
  desc = "a card with the zeppelins and boats from where you stand, timed by your guild",
  usage = "/bist rides [on | off | all | who | trak | reset]",
  defaults = { card = true, who = true },
  options = {
    { kind = "toggle", label = "the card", help = "At a zeppelin tower or a boat dock - or in its capital - a little card pops up at the top left while a ride waits: where it goes, and when it leaves. Timed by your guild.",
      get = function(db) return db.card ~= false end,
      set = function(db, on) db.card = on and true or false RD.Paint() end },
    { kind = "toggle", label = "all rides", help = "Every ride from here, coming and going, with how long until it arrives. Off: the card only pops up while a ride waits at the dock.",
      get = function(db) return db.all == true end,
      set = function(db, on) db.all = on and true or false RD.Paint() end },
    { kind = "toggle", label = "who timed it", help = "The card's last line: who timed the ride, with which BiS addon, and how sure the countdown is - the chance it is still within 10 seconds, lower the longer since the ride was timed.",
      get = function(db) return db.who ~= false end,
      set = function(db, on) db.who = on and true or false RD.Paint() end },
    { kind = "button", label = "the card's place", button = "reset", help = "Back to the top left.",
      action = function(db) db.pos = nil RD.Place() end },
  },
  OnInit = function(_, db)
    RD.db = db
    RD.Keep(db)
  end,
  OnLogin = function(_, db)
    RD.db = db
    RD.Keep(db)
    RD.Paint()
  end,
  OnEnable = function(_, db) RD.db = db RD.Paint() end,
  -- the Hub's "reset window positions" (recenter) puts the card back at the top left too, quietly; a plain click on
  -- rides in the Hub asks for the card (RD.Ask) and always answers
  OnOpen = function(_, db, recenter)
    RD.db = db
    if recenter then db.pos = nil RD.Place() return RD.Paint() end
    RD.Ask(db)
  end,
  OnDisable = function() RD.Hide() end,
  OnSlash = function(_, db, args)
    RD.db = db
    if args == "on" or args == "off" then
      db.card = args == "on"
      RD.Paint()
      return NS.Print("the ride card: %s", db.card and "on" or "off")
    elseif args == "all" then
      db.all = not db.all
      RD.Paint()
      return NS.Print("the ride card: %s", db.all and "every ride from here" or "only while one waits at the dock")
    elseif args == "who" then
      db.who = db.who == false
      RD.Paint()
      return NS.Print("who timed it: %s", db.who and "shown" or "hidden")
    elseif args == "reset" then
      db.pos = nil
      RD.Place()
      return NS.Print("the ride card is back at the top left")
    elseif args and args:match("^zoom") then
      local z = tonumber(args:match("^zoom%s+([%d%.]+)"))
      if not z or z < 0.3 or z > 1 then return NS.Print("his face: zoom %.2f - try |cff66ff80/bist rides zoom 0.6|r (0.3 far .. 1 close)", RD.Zoom()) end
      db.zoom = z
      local f = RD.frame
      for _, row in ipairs(f and f.rows or {}) do row.npc = nil end   -- every face asked again at the new zoom
      RD.Paint()
      return NS.Print("his face: zoom %.2f", z)
    elseif args == "trak" then
      return NS.Print("RIDE-TRAK: %s", RD.ToggleTrak() and "open - every ride from here, on its line"
        or "closed (shift-click the card to open it)")
    end
    local lib = RD.Lib()
    if not lib then return NS.Print("the shared BiS lib is too old for the ride clock") end
    local map = RD.Map()
    local here = map and lib:RidesAt(map) or {}
    if #here == 0 then return NS.Print("no zeppelin or boat from here - the card shows where one is") end
    for _, e in ipairs(here) do NS.Print("%s", lib:RideLine(e.stop, e.sched)) end
  end,
})
