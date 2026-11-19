--[[
  BiSTools / Tools / Windfury.lua - THE WINDFURY LAMP (18 Nov 2026). Arn: "it can serve as a im a warrior is windfury in
  range? and turns red No Windfury!"; picked A of https://claude.ai/artifact/337uApSdrAjHBknete1NS8 "with the proc scroll
  text above"; "they need to turn on in tools but dont have to go into combo setting to turn it on"; "lamp alone and then
  we work on the ask module".

  WHAT THE GAME TELLS AN ADDON (Arn's /bist combo wf, 18 Nov): out of a fight the Windfury Totem buff reads by name and by
  id (10609, from the totem's caster); IN a fight both answer nil - hidden. So the lamp is DRAWN BY THE CLIENT, BiS
  Healing's badge road (solved.md "NOT and AND out of aura containers"): a red NO WINDFURY! bar underneath, and over it
  an AuraContainer on you filtered to the Windfury Totem buff. While the buff is on you the client hands over a button;
  it is sized over the bar IN its creation (the only moment Forever lets an addon place one while auras are secret) and
  dressed gold, WINDFURY. The addon never learns the answer - it only lets the client show it.

  THE IDS: every spell the game names "Windfury Totem" (wago.tools SpellName, build 1.60.1.70862) - a totem spell in the
  filter is harmless, the buff is among them - plus any id learned by name at a pull (W.Learn, before the lockdown).

  WHEN IT SHOWS: the tool on (the BiS Tools list - off for everyone until switched on), in a fight, with a shaman in your
  party or being one. Shown at PLAYER_REGEN_DISABLED (the lockdown has not started yet), hidden after the fight; the
  container listens only while shown, and nothing else runs. /bist wf test shows it out of a fight for W.TEST s.

  WHERE: under the combo's proc text (BiSToolsComboFloat and its DUE bar) - one spot for both, the procs floating above
  the lamp. Dragging the lamp (out of a fight) moves that spot; without the combo file it keeps its own (db.pos).
]]
local _, NS = ...
local R = NS.Registry
local W = {}
NS.WF = W

W.IDS = { 8512, 8515, 8516, 10608, 10609, 10610, 10612, 10613, 10614, 27621, 78159 }
W.W, W.H, W.GAP, W.TEST = 150, 20, 28, 12
W.RED, W.GOLD = { 0.92, 0.16, 0.16 }, { 1, 0.83, 0.23 }
W.PULSE_LOW, W.PULSE_SECONDS = 0.45, 0.5

local function plain(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end
local function db()
  if not W.db and R.Get and R:Get("windfury") then W.db = R:DBFor(R:Get("windfury")) end
  return W.db or {}
end
local function locked() return InCombatLockdown and InCombatLockdown() and true or false end

--- Every id the lamp listens for: the game's "Windfury Totem" spells and any learned at a pull, sorted.
function W.Ids()
  local seen, out = {}, {}
  for _, id in ipairs(W.IDS) do if not seen[id] then seen[id] = true out[#out + 1] = id end end
  for id in pairs(db().ids or {}) do
    if type(id) == "number" and not seen[id] then seen[id] = true out[#out + 1] = id end
  end
  table.sort(out)
  return out
end

--- The Windfury Totem buff on you, by name, while the client still says (never in the lockdown): its id, kept when
--- new (the container takes it after the fight). nil when it is not on you or not readable.
function W.Learn()
  if locked() then return nil end
  local A = C_UnitAuras
  if not (A and A.GetAuraDataBySpellName) then return nil end
  local ok, a = pcall(A.GetAuraDataBySpellName, "player", "Windfury Totem", "HELPFUL")
  if not ok or type(a) ~= "table" or (issecretvalue and issecretvalue(a)) then return nil end
  local okI, id = pcall(function() return a.spellId end)
  id = okI and plain(id) or nil
  if type(id) ~= "number" then return nil end
  for _, x in ipairs(W.Ids()) do if x == id then return id end end
  local d = db()
  d.ids = d.ids or {}
  d.ids[id] = true
  W.dirty = true
  return id
end

local function classOf(u)
  if not UnitClass then return nil end
  local ok, _, cls = pcall(UnitClass, u)
  return ok and plain(cls) or nil
end
--- A shaman in your party (your raid group's party too), or you are one.
function W.ShamanNear()
  if classOf("player") == "SHAMAN" then return true end
  for i = 1, 4 do
    local u = "party" .. i
    local okE, there = pcall(UnitExists, u)
    if okE and plain(there) and classOf(u) == "SHAMAN" then return true end
  end
  return false
end

--- Does this client draw auras for addons?
function W.Available()
  local X = C_XMLUtil
  if not (X and X.GetTemplateInfo) then return false end
  local ok, info = pcall(X.GetTemplateInfo, "CustomAuraContainerTemplate")
  return ok and info ~= nil
end
local function addSlot(container, key, filter, opts)
  if container.AddAuraSlot then
    local ok, slot = pcall(container.AddAuraSlot, container, key, filter, opts)
    if ok and slot then return slot end
  end
  if container.AddAuraGroup then
    opts.maxFrameCount = opts.maxFrameCount or 1
    local ok, slot = pcall(container.AddAuraGroup, container, key, filter, opts)
    if ok and slot then return slot end
  end
  return nil
end

--- THE CLIENT'S BUTTON, while the buff is on you: sized and placed over the bar in its creation, its own art hidden,
--- dressed gold with the word. A button it will not let be placed is left alone (the red then stays - said by /bist wf).
function W.Dress(button)
  local f = W.frame
  if not (button and f) then return end
  local ok = pcall(function()
    button:SetSize(W.W, W.H)
    button:ClearAllPoints()
    button:SetPoint("CENTER", f, "CENTER", 0, 0)
  end)
  if not ok then W.refused = "the game would not let the lamp be placed" return end
  W.drawn = (W.drawn or 0) + 1
  if button.bisWF then return end                      -- (the client reuses its buttons: dressed once)
  pcall(function()
    if button.GetRegions then
      for _, r in ipairs({ button:GetRegions() }) do if r.Hide then r:Hide() end end
    end
    for _, k in ipairs({ "Icon", "icon", "Border", "border", "Count", "count", "Cooldown" }) do
      local part = button[k]
      if type(part) == "table" and part.Hide then part:Hide() end
    end
    if button.SetMouseMotionEnabled then button:SetMouseMotionEnabled(false) end
    if button.SetMouseClickEnabled then button:SetMouseClickEnabled(false) end
    local t = button:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints(button)
    t:SetColorTexture(W.GOLD[1], W.GOLD[2], W.GOLD[3], 1)
    local s = button:CreateFontString(nil, "OVERLAY")
    s:SetFont("Fonts\\ARIALN.TTF", 13, "")
    s:SetPoint("CENTER", button, "CENTER", 0, 0)
    s:SetTextColor(0.12, 0.09, 0.02, 1)
    s:SetText("WINDFURY")
    button.bisWF = { t = t, s = s }
  end)
end

--- The container over the bar, for the ids now known. Out of a fight only. Answers it, or nil (W.refused says why).
function W.Container(f)
  if f.container then pcall(f.container.SetEnabled, f.container, false) pcall(f.container.Hide, f.container) f.container = nil end
  if not W.Available() then W.refused = "this game draws no auras for addons" return nil end
  local ok, c = pcall(CreateFrame, "AuraContainer", nil, f, "CustomAuraContainerTemplate")
  if not ok or not c then W.refused = "the game refused to build the lamp" return nil end
  c:SetSize(1, 1)
  c:SetPoint("CENTER", f, "CENTER", 0, 0)
  if c.SetFrameLevel then c:SetFrameLevel((f:GetFrameLevel() or 1) + 10) end
  c:SetUnit("player")
  local want = {}
  for _, id in ipairs(W.Ids()) do want[id] = true end
  local slot = addSlot(c, "BiSToolsWF", "HELPFUL", { candidateFilters = { includeSpellIDs = want }, initializeFrame = W.Dress })
  if not slot then
    pcall(c.SetEnabled, c, false) pcall(c.Hide, c)
    W.refused = "the game would not take the lamp's filter"
    return nil
  end
  if c.SetEnabled then pcall(c.SetEnabled, c, false) end   -- (listens only while shown: W.Show)
  W.refused, W.dirty = nil, nil
  f.container = c
  return c
end

--- One spot with the combo's proc text: the lamp right under its DUE bar (that frame is made if it is not yet).
function W.Anchor(f)
  f:ClearAllPoints()
  local C = NS.Combo
  local g = C and C.Float and C.Float()
  if g then f:SetPoint("TOP", g, "BOTTOM", 0, -W.GAP) f.under = g return g end
  local p = db().pos
  if type(p) == "table" and p[1] then f:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
  else f:SetPoint("CENTER", UIParent, "CENTER", 0, -160) end
  f.under = nil
end

--- The lamp. Out of a fight only (it holds the container). Answers it, or nil.
function W.Build()
  if W.frame then return W.frame end
  if locked() then return nil end
  local f = CreateFrame("Frame", "BiSToolsWFLamp", UIParent)
  f:SetSize(W.W, W.H)
  f:SetFrameStrata("HIGH")
  -- THE RED UNDERNEATH: what shows while the client draws nothing over it. It breathes (the client runs the animation -
  -- no OnUpdate of ours), under the gold too, unseen: whether the buff is up is exactly what we may not know.
  local red = CreateFrame("Frame", nil, f)
  red:SetAllPoints(f)
  if red.SetFrameLevel then red:SetFrameLevel((f:GetFrameLevel() or 1) + 2) end
  red.bg = red:CreateTexture(nil, "ARTWORK")
  red.bg:SetAllPoints(red)
  red.bg:SetColorTexture(W.RED[1], W.RED[2], W.RED[3], 1)
  red.word = red:CreateFontString(nil, "OVERLAY")
  red.word:SetFont("Fonts\\ARIALN.TTF", 13, "OUTLINE")
  red.word:SetPoint("CENTER", red, "CENTER", 0, 0)
  red.word:SetTextColor(1, 1, 1, 1)
  red.word:SetText("NO WINDFURY!")
  if red.CreateAnimationGroup then
    local ok, pulse = pcall(red.CreateAnimationGroup, red)
    if ok and pulse then
      local fade = pulse:CreateAnimation("Alpha")
      fade:SetFromAlpha(1)
      fade:SetToAlpha(W.PULSE_LOW)
      fade:SetDuration(W.PULSE_SECONDS)
      if fade.SetSmoothing then fade:SetSmoothing("IN_OUT") end
      pulse:SetLooping("BOUNCE")
      red.pulse = pulse
    end
  end
  f.red = red
  -- moved out of a fight only; it moves the spot it shares with the proc text
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    if locked() then return end
    local m = self.under or self
    m:SetMovable(true) m:StartMoving() self.moving = m
  end)
  local function stop(self)
    local m = self.moving
    if not m then return end
    self.moving = nil
    m:StopMovingOrSizing()
    local ok, pt, _, rp, x, y = pcall(m.GetPoint, m)
    if not (ok and pt) then return end
    if m == self then db().pos = { pt, rp, x, y }
    elseif R:Get("combo") then R:DBFor(R:Get("combo")).tapePos = { pt, rp, x, y } end
  end
  f:SetScript("OnDragStop", stop)
  f:SetScript("OnHide", stop)
  f:SetScript("OnEnter", function(self)
    if not GameTooltip or locked() then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Windfury lamp", 1, 0.83, 0.23)
    GameTooltip:AddLine("Gold while a shaman's Windfury Totem is on you, red when it is not. The game draws it - it works in a fight.", 0.9, 0.9, 0.9, true)
    GameTooltip:AddLine("Drag me to move it (and the proc text above it), out of a fight.", 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  f:Hide()
  W.frame = f
  W.Container(f)
  return f
end

--- Shown: the container listens and draws. Hidden: nothing runs. Out of a fight to show (at the pull is still out).
function W.Show(on)
  local f = W.frame
  if on then
    f = f or W.Build()
    if not f then return false end
    if W.dirty and not locked() then W.Container(f) end   -- (an id learned since: the filter takes it)
    if not f.container then return false end
    W.Anchor(f)
    f:Show()
    if f.red.pulse then f.red.pulse:Play() end
    pcall(f.container.SetEnabled, f.container, true)
    if f.container.UpdateAllAuras then pcall(f.container.UpdateAllAuras, f.container) end   -- (a buff already on you)
    return true
  end
  if f then
    W.testUntil = nil
    f:Hide()
    if f.red.pulse then f.red.pulse:Stop() end
    if f.container then pcall(f.container.SetEnabled, f.container, false) end
  end
  return false
end

--- /bist wf test: the lamp out of a fight for W.TEST s - step in and out of the totem and watch it change.
function W.Test()
  if locked() then NS.Print("windfury: not in a fight - it shows by itself there") return false end
  W.Learn()
  if not W.Show(true) then NS.Print("windfury: no lamp - %s", W.refused or "?") return false end
  local tok = {}
  W.testUntil = tok
  if C_Timer and C_Timer.After then
    C_Timer.After(W.TEST, function() if W.testUntil == tok and not locked() then W.Show(false) end end)
  end
  NS.Print("windfury: the lamp for %d s - gold = Windfury on you, red = not. Drag it to move it.", W.TEST)
  return true
end

--- /bist wf: what it knows, in one line.
function W.Status()
  local on = R:Enabled("windfury")
  NS.Print("windfury: %s  -  shaman in your party: %s  -  %d ids  -  lamp: %s%s", on and "ON" or "OFF (/bist on wf)",
    W.ShamanNear() and "yes" or "no", #W.Ids(), (W.frame and W.frame.container) and "ready" or (W.refused or "not built yet"),
    W.drawn and ("  -  drawn gold %d times"):format(W.drawn) or "")
end

W.events = CreateFrame("Frame")
W.events:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_DISABLED" then
    -- (the lockdown starts after this: the buff still reads, the frame may still be shown)
    W.Learn()
    if W.ShamanNear() then W.Show(true) end
    if W.frame then W.frame:EnableMouse(false) end            -- never in the way of a click in a fight
  elseif event == "PLAYER_REGEN_ENABLED" then
    W.Show(false)
    if W.frame then W.frame:EnableMouse(true) end
    if W.dirty and W.frame then W.Container(W.frame) end
  end
end)
function W.Listen(on)
  if on then
    W.events:RegisterEvent("PLAYER_REGEN_DISABLED")
    W.events:RegisterEvent("PLAYER_REGEN_ENABLED")
  else
    W.events:UnregisterEvent("PLAYER_REGEN_DISABLED")
    W.events:UnregisterEvent("PLAYER_REGEN_ENABLED")
    W.Show(false)
  end
end

R:Register({
  name = "windfury",
  short = "wf",
  defaultOff = true,                                   -- (a save from before 1.0 never had it: off there too)
  desc = "a lamp: red NO WINDFURY! when a shaman's Windfury Totem is not on you",
  usage = "/bist wf [test]",
  defaults = {},
  options = {
    { kind = "button", label = "the lamp", button = "test",
      help = "Shows the lamp for a few seconds out of a fight: gold while Windfury is on you, red when not. In a fight it shows by itself when a shaman is in your party.",
      action = function(d) W.db = d W.Test() end },
  },
  OnInit = function(_, d) W.db = d end,
  OnLogin = function(_, d) W.db = d W.Listen(true) end,
  OnEnable = function(_, d) W.db = d W.Listen(true) end,
  OnDisable = function() W.Listen(false) end,
  OnSlash = function(_, d, args)
    W.db = d
    local cmd = tostring(args or ""):match("^(%S*)") or ""
    if cmd == "test" then W.Test() return end
    W.Status()
  end,
})
