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
W.W, W.H, W.GAP, W.TEST = 150, 20, 28, 20
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
W.ClassOf = classOf                                    -- (the deck's app asks too: Tools/Apps/Windfury.lua)
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
  -- (18 Nov, Arn's screenshot: with the paper tape on, the lamp sat across it - then it goes under the tape)
  if C and C.Tape and C.Clean and not C.Clean() and R:Enabled("combo") then
    local t = C.Tape()
    if t then f:SetPoint("TOP", t, "BOTTOM", 0, -6) f.under = t return t end
  end
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
  -- YOUR OWN WINDFURY WEAPON (18 Nov 2026, Arn: "its not reading my own windfury imbue"): the lamp was the totem's
  -- buff only. The weapon's enchant DOES read in a fight (his /bist combo wf: "enchant: true id 1663" in the lockdown),
  -- so this one is ours to draw: gold over the red while your main hand carries Windfury (W.CheckImbue, once a second).
  local wpn = CreateFrame("Frame", nil, f)
  wpn:SetAllPoints(f)
  if wpn.SetFrameLevel then wpn:SetFrameLevel((f:GetFrameLevel() or 1) + 5) end
  wpn.bg = wpn:CreateTexture(nil, "ARTWORK")
  wpn.bg:SetAllPoints(wpn)
  wpn.bg:SetColorTexture(W.GOLD[1], W.GOLD[2], W.GOLD[3], 1)
  wpn.word = wpn:CreateFontString(nil, "OVERLAY")
  wpn.word:SetFont("Fonts\\ARIALN.TTF", 13, "")
  wpn.word:SetPoint("CENTER", wpn, "CENTER", 0, 0)
  wpn.word:SetTextColor(0.12, 0.09, 0.02, 1)
  wpn.word:SetText("WINDFURY")
  wpn:Hide()
  f.weapon = wpn
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
    -- (the buttons are not anchored to the lamp - W.Place: moved with it by hand, out of a fight only)
    if not locked() then
      if W.ask and W.ask:IsShown() then W.Place(W.ask, self) end
      if W.totem and W.totem:IsShown() then W.Place(W.totem, self) end
    end
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
    W.CheckImbue()
    if W.imbueTicker and W.imbueTicker.Cancel then W.imbueTicker:Cancel() end
    W.imbueTicker = (C_Timer and C_Timer.NewTicker) and C_Timer.NewTicker(W.IMBUE_EVERY, W.CheckImbue) or nil
    return true
  end
  if W.imbueTicker and W.imbueTicker.Cancel then W.imbueTicker:Cancel() end
  W.imbueTicker = nil
  if f then
    W.testUntil = nil
    f:Hide()
    if f.red.pulse then f.red.pulse:Stop() end
    if f.weapon then f.weapon:Hide() end
    if f.container then pcall(f.container.SetEnabled, f.container, false) end
  end
  return false
end
--- Your main hand's Windfury Weapon (the combo's reading - plain in a fight too): the lamp's own gold on or off.
W.IMBUE_EVERY = 1
function W.CheckImbue()
  local f = W.frame
  if not (f and f.weapon) then return false end
  local C = NS.Combo
  local im = C and C.ImbueNow and C.ImbueNow()
  local wf = type(im) == "string" and im:find("Windfury", 1, true) and true or false
  if wf then f.weapon:Show() else f.weapon:Hide() end
  return wf
end

--[[ THE ASK (18 Nov 2026, Arn: "a warrior missing wf, click a button it clicks the shaman in his group he gets a light up
  wf totem he can click"; "lamp alone and then we work on the ask module"; the lamp worked live, then "start the ask
  module"). Addon messages HOLD in a fight, so the warrior knocks with his TARGET - BiS Healing's rhythm test, put to work.

  THE WARRIOR (anyone but a shaman): a small SECURE "ASK" button at the lamp's right end (and a key, /bist wf key <KEY>).
  Each press flips the target: a hostile one or none -> /target partyN (the first shaman in the party, aimed at the pull),
  a friendly one -> /targetlasttarget (back to the boss). A header's WrapScript snippet picks it just before the click
  runs - legal in a fight. Four STEADY presses (two a second) = four target changes, and he ends on the boss again.
  MEASURED LIVE 18 Nov (Arn's two accounts, in a fight - it lit): the game passes a party member's target on about every
  half second, so a MASHED button cancels itself (7 presses in 0.9 s -> 1 change heard); 6 in 1.6 s -> 4 heard, 11 in
  3.3 s -> 5 heard - both lit. Hence "about two a second" in the words.

  THE SHAMAN (knows Windfury Totem): a SECURE Windfury Totem button in the same spot, quiet. In a fight he hears UNIT_TARGET
  for party1-4; W.NEED changes from one person inside W.WINDOW s = an ask: the button LIGHTS (a red frame of our own over
  it, the asker's name, a raid-warning sound) for W.LIT_FOR s or until clicked; one click drops the totem. Nothing secret
  is read: the unit token and the time are all it needs.

  Both write what happened (db.log, the newest W.KEEP): the warrior his presses, the shaman each burst he heard - so the
  first live tries can be read off the save. Secure buttons are made, shown, hidden and aimed out of the lockdown only:
  at PLAYER_REGEN_DISABLED (it has not started yet) and PLAYER_REGEN_ENABLED. They hang off UIParent, anchored to the lamp.
]]
W.NEED, W.WINDOW, W.QUIET, W.LIT_FOR, W.KEEP = 3, 2, 4, 8, 30
W.SOUND = (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959
W.ASK_W, W.TOT = 38, 24
W.SNIPPET = [[
  local back
  if SecureCmdOptionParse then
    back = SecureCmdOptionParse("[@target,help] back; go") == "back"
  else
    local n = (self:GetAttribute("bis-n") or 0) + 1
    self:SetAttribute("bis-n", n)
    back = (n % 2 == 0)
  end
  if back then
    self:SetAttribute("macrotext", "/targetlasttarget")
  else
    self:SetAttribute("macrotext", "/target " .. (self:GetAttribute("bis-who") or "player"))
  end
]]
local function now() return (GetTime and GetTime()) or 0 end
local function wall() return (time and time()) or 0 end

--- The first shaman in your party, as a unit ("party2"), or nil.
function W.ShamanUnit()
  for i = 1, 4 do
    local u = "party" .. i
    local okE, there = pcall(UnitExists, u)
    if okE and plain(there) and classOf(u) == "SHAMAN" then return u end
  end
  return nil
end
function W.IsShaman() return classOf("player") == "SHAMAN" end
--- Do you know Windfury Totem? (the combo's spell check)
function W.KnowsWF()
  local C = NS.Combo
  return (C and C.Knows and C.Knows("Windfury Totem")) and true or false
end
local function nameOf(u)
  local ok, n = pcall(UnitName, u)
  n = ok and plain(n) or nil
  return (type(n) == "string" and n ~= "") and n or u
end
W.NameOf = nameOf
function W.Log(e)
  local d = db()
  d.log = d.log or {}
  e.at = wall()
  d.log[#d.log + 1] = e
  while #d.log > W.KEEP do table.remove(d.log, 1) end
end
local function edge(f, r, g, b, a, px)
  px = px or 1
  local sides = { { "TOPLEFT", "TOPRIGHT", nil, px }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, px },
                  { "TOPLEFT", "BOTTOMLEFT", px, nil }, { "TOPRIGHT", "BOTTOMRIGHT", px, nil } }
  for _, side in ipairs(sides) do
    local t = f:CreateTexture(nil, "OVERLAY")
    t:SetPoint(side[1], f, side[1], 0, 0)
    t:SetPoint(side[2], f, side[2], 0, 0)
    if side[3] then t:SetWidth(side[3]) else t:SetHeight(side[4]) end
    t:SetColorTexture(r, g, b, a)
  end
end

--- THE WARRIOR'S BUTTON. Out of the lockdown only (it is secure).
function W.BuildAsk()
  if W.ask then return W.ask end
  if locked() then return nil end
  local b = CreateFrame("Button", "BiSToolsWFAsk", UIParent, "SecureActionButtonTemplate")
  if b.RegisterForClicks then b:RegisterForClicks("AnyDown") end
  b:SetSize(W.ASK_W, W.H)
  b:SetFrameStrata("HIGH")
  b:SetAttribute("type", "macro")
  b:SetAttribute("macrotext", "/targetlasttarget")
  b:SetAttribute("bis-who", "player")
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints(b)
  b.bg:SetColorTexture(0.1, 0.08, 0.05, 0.9)
  edge(b, 1, 0.69, 0.18, 1)
  b.word = b:CreateFontString(nil, "OVERLAY")
  b.word:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE")
  b.word:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.word:SetTextColor(1, 0.69, 0.18, 1)
  b.word:SetText("ASK")
  b.hl = b:CreateTexture(nil, "HIGHLIGHT")
  b.hl:SetAllPoints(b)
  b.hl:SetColorTexture(1, 0.69, 0.18, 0.18)
  b:SetScript("PreClick", function() W.Pressed() end)      -- (insecure: counts the press, touches nothing secure)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Ask the shaman for Windfury", 1, 0.69, 0.18)
    GameTooltip:AddLine(("Press about twice a second, 4 times (mashing is too fast - the game passes only one change each half second): your target flips to %s and back, and their Windfury Totem button lights up."):format(W.askName or "the shaman"), 0.9, 0.9, 0.9, true)
    -- (Arn, at the 1.7.0 release: "make sure that tooltip says needs bis tools for it to work")
    GameTooltip:AddLine("Needs BiS Tools: the shaman must have BiS Tools with windfury switched on, or nothing lights up for them.", 1, 0.45, 0.45, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  local okH, h = pcall(CreateFrame, "Frame", "BiSToolsWFHeader", UIParent, "SecureHandlerBaseTemplate")
  W.header = okH and h or nil
  W.wrapped = false
  if W.header and W.header.WrapScript then W.wrapped = pcall(W.header.WrapScript, W.header, b, "OnClick", W.SNIPPET) and true or false end
  b:Hide()
  W.ask = b
  W.ApplyKey()
  return b
end

--- THE SHAMAN'S BUTTON: casts Windfury Totem; our red frame and the asker's name over it while lit.
function W.BuildTotem()
  if W.totem then return W.totem end
  if locked() then return nil end
  local b = CreateFrame("Button", "BiSToolsWFTotem", UIParent, "SecureActionButtonTemplate")
  if b.RegisterForClicks then b:RegisterForClicks("AnyDown") end
  b:SetSize(W.TOT, W.TOT)
  b:SetFrameStrata("HIGH")
  b:SetAttribute("type", "spell")
  b:SetAttribute("spell", "Windfury Totem")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints(b)
  local tex
  if C_Spell and C_Spell.GetSpellTexture then
    local ok, t = pcall(C_Spell.GetSpellTexture, 8512)
    tex = ok and plain(t) or nil
  end
  b.icon:SetTexture(tex or "Interface\\Icons\\Spell_Nature_Windfury")
  if b.icon.SetTexCoord then b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  b.icon:SetAlpha(0.55)
  b.hl = b:CreateTexture(nil, "HIGHLIGHT")
  b.hl:SetAllPoints(b)
  b.hl:SetColorTexture(1, 1, 1, 0.15)
  b:SetScript("PostClick", function() W.Unlight() end)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Windfury Totem", 1, 0.83, 0.23)
    GameTooltip:AddLine("Click to drop it. It lights up red with a name when someone in your party presses ASK.", 0.9, 0.9, 0.9, true)
    GameTooltip:AddLine("Needs BiS Tools: they must have BiS Tools with windfury switched on to ask.", 1, 0.45, 0.45, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  -- the lit look: our own frame over it (never the secure button's own show or size in a fight)
  local lit = CreateFrame("Frame", nil, UIParent)
  lit:SetFrameStrata("HIGH")
  if lit.SetFrameLevel then lit:SetFrameLevel((b:GetFrameLevel() or 1) + 5) end
  lit:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 3)
  lit:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
  if lit.EnableMouse then lit:EnableMouse(false) end
  edge(lit, 0.92, 0.16, 0.16, 1, 3)
  lit.who = lit:CreateFontString(nil, "OVERLAY")
  lit.who:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE")
  lit.who:SetPoint("BOTTOM", lit, "TOP", 0, 2)
  lit.who:SetTextColor(1, 0.35, 0.35, 1)
  if lit.CreateAnimationGroup then
    local ok, pulse = pcall(lit.CreateAnimationGroup, lit)
    if ok and pulse then
      local fade = pulse:CreateAnimation("Alpha")
      fade:SetFromAlpha(1)
      fade:SetToAlpha(0.35)
      fade:SetDuration(0.4)
      pulse:SetLooping("BOUNCE")
      lit.pulse = pulse
    end
  end
  lit:Hide()
  b.lit = lit
  b:Hide()
  W.totem = b
  return b
end

--[[ NEVER ANCHORED TO THE LAMP (18 Nov 2026, Arn's BugSack after 1.7.0: "BiSTools tried to call the protected function
  'BiSToolsComboFloat:Show()'"). The client protects every frame a secure one hangs from - by ANCHOR as well as by parent:
  ASK sat on the lamp, the lamp on the combo's proc text, so the proc text could no longer be shown in a fight. A secure
  button is placed on UIParent at the lamp's right end, worked out from where the lamp is (out of the lockdown only);
  nothing of ours is in its chain. ]]
function W.Place(b, f)
  b:ClearAllPoints()
  local okR, right = pcall(f.GetRight, f)
  local okC, _, cy = pcall(f.GetCenter, f)
  right = okR and plain(right) or nil
  cy = okC and plain(cy) or nil
  if type(right) == "number" and type(cy) == "number" then
    b:SetPoint("LEFT", UIParent, "BOTTOMLEFT", right + 4, cy)
  else
    b:SetPoint("CENTER", UIParent, "CENTER", W.W / 2 + 4 + W.TOT / 2, -160)   -- (the lamp not laid out yet: near its default)
  end
end

--- Out of the lockdown: the right button for you, aimed and placed at the lamp's right end - or both away.
function W.Buttons(on)
  if locked() then W.pendingButtons = on return false end
  W.pendingButtons = nil
  local f = W.frame
  if on and f then
    if W.IsShaman() then
      if W.KnowsWF() and W.BuildTotem() then
        W.Place(W.totem, f)
        W.totem:Show()
        W.Hear(true)
      end
    else
      local u = W.ShamanUnit()
      if u and W.BuildAsk() then
        W.ask:SetAttribute("bis-who", u)
        W.ask:SetAttribute("macrotext", "/target " .. u)
        W.ask:SetAttribute("bis-n", 0)
        W.askUnit, W.askName = u, nameOf(u)
        W.Place(W.ask, f)
        W.ask:Show()
      end
    end
    return true
  end
  if W.ask then W.ask:Hide() end
  if W.totem then W.totem:Hide() end
  W.Hear(false)
  W.Unlight()
  return false
end

--- The warrior pressed ASK: counted (a burst = presses with no gap over W.WINDOW), written when it ends.
function W.Pressed()
  local t = now()
  local s = W.sent
  if not s or t - s.last > W.WINDOW then s = { n = 0, first = t, fight = locked(), to = W.askName } W.sent = s end
  s.n, s.last = s.n + 1, t
  if C_Timer and C_Timer.After then
    C_Timer.After(W.WINDOW + 0.1, function()
      if W.sent == s and now() - s.last >= W.WINDOW then
        W.sent = nil
        W.Log({ k = "sent", n = s.n, span = math.floor((s.last - s.first) * 10 + 0.5) / 10, fight = s.fight, to = s.to })
      end
    end)
  end
end

--- THE SHAMAN HEARS: a party member's target changed.
function W.Hear(on)
  if on then W.events:RegisterEvent("UNIT_TARGET") else W.events:UnregisterEvent("UNIT_TARGET") end
end
W.seen, W.stat = {}, { secret = 0 }
function W.Heard(unit)
  if issecretvalue and issecretvalue(unit) then W.stat.secret = W.stat.secret + 1 return end
  if type(unit) ~= "string" or not unit:match("^party%d$") then return end
  local t = now()
  local s = W.seen[unit]
  if s and t - s.last > W.WINDOW then W.CloseBurst(unit, s) s = nil end
  if not s then s = { n = 0, first = t, stamps = {}, fight = locked() } W.seen[unit] = s end
  s.n, s.last = s.n + 1, t
  s.stamps[#s.stamps + 1] = t
  while s.stamps[1] and t - s.stamps[1] > W.WINDOW do table.remove(s.stamps, 1) end
  if #s.stamps >= W.NEED and t >= (W.quietUntil or 0) then
    if W.CanAsk(unit) then
      s.lit = true
      W.quietUntil = t + W.QUIET
      W.Light(unit)
    else
      s.notBis = true                                        -- (counted, never lit: they could not have pressed ASK)
    end
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(W.WINDOW + 0.1, function() if W.seen[unit] == s and now() - s.last >= W.WINDOW then W.CloseBurst(unit, s) end end)
  end
end
--[[ ONLY SOMEONE WHO COULD HAVE ASKED (18 Nov 2026, Arn's screenshot: the totem button lit "Yoruichi asks" - a party
  member switching targets fast, three in two seconds, without BiS Tools). ASK lives in BiS Tools, and every BiS addon
  says hello on the group line before a fight (LibBiSComm's peers, each with the addons it runs). So the button lights
  only for a party member whose peer entry carries BiS Tools. With the comm switched off (/biscomm off) nobody is known:
  then it falls back to the rhythm alone. ]]
function W.CanAsk(unit)
  local lib = _G.LibBiSComm
  if not (lib and lib.Peer and lib.Enabled) or not lib:Enabled() then return true end
  local ok, p = pcall(lib.Peer, lib, nameOf(unit))
  return ok and type(p) == "table" and type(p.addons) == "table" and p.addons.BiSTools ~= nil or false
end
function W.CloseBurst(unit, s)
  if W.seen[unit] == s then W.seen[unit] = nil end
  W.Log({ k = "heard", who = nameOf(unit), unit = unit, n = s.n, span = math.floor((s.last - s.first) * 10 + 0.5) / 10,
          fight = s.fight, lit = s.lit or nil, notBis = s.notBis or nil })
end
--- An ask: the totem button lights with the asker's name, a sound, W.LIT_FOR s or until clicked.
function W.Light(unit)
  local b = W.totem
  if not (b and b.lit) then return false end
  b.lit.who:SetText(nameOf(unit) .. " asks")
  b.lit:Show()
  if b.lit.pulse then b.lit.pulse:Play() end
  b.icon:SetAlpha(1)
  if PlaySound then pcall(PlaySound, W.SOUND, "Master") end
  local tok = {}
  W.litTok = tok
  if C_Timer and C_Timer.After then C_Timer.After(W.LIT_FOR, function() if W.litTok == tok then W.Unlight() end end) end
  return true
end
function W.Unlight()
  local b = W.totem
  W.litTok = nil
  if not (b and b.lit) then return end
  b.lit:Hide()
  if b.lit.pulse then b.lit.pulse:Stop() end
  b.icon:SetAlpha(0.55)
end

--- /bist wf key <KEY>: that key presses ASK (none = off). Set out of a fight; kept.
function W.ApplyKey()
  if locked() then return false end
  if ClearOverrideBindings then pcall(ClearOverrideBindings, W.events) end
  local k = db().key
  if k and W.ask and SetOverrideBindingClick then pcall(SetOverrideBindingClick, W.events, true, k, "BiSToolsWFAsk", "LeftButton") end
  return k
end
function W.Key(word)
  if locked() then NS.Print("windfury: not in a fight") return false end
  word = tostring(word or ""):upper()
  if word == "" or word == "NONE" then db().key = nil W.ApplyKey() NS.Print("windfury: no ASK key") return false end
  db().key = word
  W.BuildAsk()
  W.ApplyKey()
  NS.Print("windfury: %s presses ASK (4 presses, about two a second = an ask)", word)
  return word
end

--- /bist wf log: the last asks, sent and heard.
function W.Report(n)
  local log = db().log or {}
  n = math.min(tonumber(n) or 8, #log)
  for i = #log - n + 1, #log do
    local e = log[i]
    if e.k == "sent" then
      NS.Print("  sent: %d presses in %.1f s to %s%s", e.n or 0, e.span or 0, tostring(e.to or "?"), e.fight and " (in a fight)" or "")
    else
      NS.Print("  heard: %s, %d target changes in %.1f s%s%s", tostring(e.who or "?"), e.n or 0, e.span or 0,
        e.fight and " (in a fight)" or "", e.lit and " - LIT" or "")
    end
  end
  return n
end

--- /bist wf test: the lamp (and your ASK or totem button) out of a fight for W.TEST s.
function W.Test()
  if locked() then NS.Print("windfury: not in a fight - it shows by itself there") return false end
  W.Learn()
  if not W.Show(true) then NS.Print("windfury: no lamp - %s", W.refused or "?") return false end
  W.Buttons(true)
  local tok = {}
  W.testUntil = tok
  if C_Timer and C_Timer.After then
    C_Timer.After(W.TEST, function() if W.testUntil == tok and not locked() then W.Show(false) W.Buttons(false) end end)
  end
  NS.Print("windfury: the lamp for %d s - gold = Windfury on you, red = not. Drag it to move it.", W.TEST)
  return true
end

--- /bist wf: what it knows (and the ask's line).
function W.Status()
  local on = R:Enabled("windfury")
  NS.Print("windfury: %s  -  shaman in your party: %s  -  %d ids  -  lamp: %s%s", on and "ON" or "OFF (/bist on wf)",
    W.ShamanNear() and "yes" or "no", #W.Ids(), (W.frame and W.frame.container) and "ready" or (W.refused or "not built yet"),
    W.drawn and ("  -  drawn gold %d times"):format(W.drawn) or "")
  if W.IsShaman() then
    NS.Print("windfury ask: you're the shaman - %s", W.KnowsWF() and "your Windfury Totem button lights when someone asks"
      or "you don't know Windfury Totem yet")
  else
    local u = W.ShamanUnit()
    NS.Print("windfury ask: ASK aims at %s  -  key: %s%s", u and nameOf(u) or "no shaman in your party",
      db().key or "none (/bist wf key F)", (W.ask and not W.wrapped) and "  |cffff5050(no snippet!)|r" or "")
  end
end

W.events = CreateFrame("Frame")
W.events:SetScript("OnEvent", function(_, event, a1)
  if event == "UNIT_TARGET" then W.Heard(a1) return end
  if event == "PLAYER_REGEN_DISABLED" then
    -- (the lockdown starts after this: the buff still reads, frames and secure buttons may still be shown and aimed)
    W.Learn()
    if W.ShamanNear() and W.Show(true) then W.Buttons(true) end
    if W.frame then W.frame:EnableMouse(false) end            -- never in the way of a click in a fight
  elseif event == "PLAYER_REGEN_ENABLED" then
    W.Show(false)
    W.Buttons(false)
    if W.frame then W.frame:EnableMouse(true) end
    if W.dirty and W.frame then W.Container(W.frame) end
    if not R:Enabled("windfury") then W.Listen(false) end      -- (switched off mid-fight: now)
  end
end)
function W.Listen(on)
  if on then
    W.events:RegisterEvent("PLAYER_REGEN_DISABLED")
    W.events:RegisterEvent("PLAYER_REGEN_ENABLED")
    if db().key then W.BuildAsk() end
    return
  end
  W.events:UnregisterEvent("PLAYER_REGEN_DISABLED")
  W.Show(false)
  if locked() then return end                                -- (secure buttons wait: PLAYER_REGEN_ENABLED finishes it)
  W.Buttons(false)
  W.events:UnregisterEvent("PLAYER_REGEN_ENABLED")
  if ClearOverrideBindings then pcall(ClearOverrideBindings, W.events) end
end

R:Register({
  name = "windfury",
  short = "wf",
  defaultOff = true,                                   -- (a save from before 1.0 never had it: off there too)
  desc = "a lamp: red NO WINDFURY! when a shaman's Windfury Totem is not on you - ASK lights their totem button",
  usage = "/bist wf [test | key <KEY> | log]",
  defaults = {},
  options = {
    { kind = "button", label = "the lamp", button = "test",
      help = "Shows the lamp for a few seconds out of a fight: gold while Windfury is on you, red when not. In a fight it shows by itself when a shaman is in your party, with ASK beside it - a shaman gets a Windfury Totem button there that lights up when someone asks. ASK needs BiS Tools (windfury on) on both players.",
      action = function(d) W.db = d W.Test() end },
  },
  OnInit = function(_, d) W.db = d end,
  OnLogin = function(_, d) W.db = d W.Listen(true) end,
  OnEnable = function(_, d) W.db = d W.Listen(true) end,
  OnDisable = function() W.Listen(false) end,
  OnSlash = function(_, d, args)
    W.db = d
    local cmd, rest = tostring(args or ""):match("^(%S*)%s*(.-)%s*$")
    if cmd == "test" then W.Test() return end
    if cmd == "key" then W.Key(rest) return end
    if cmd == "log" then W.Report(rest) return end
    W.Status()
  end,
})
