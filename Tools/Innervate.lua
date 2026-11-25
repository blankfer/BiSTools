--[[ BiSTools / Tools / Innervate.lua  --  ASKING FOR INNERVATE, POWER INFUSION, MANA TIDE (22 Nov 2026).

  Arn, 22 Nov: "we put the innervate thing on the tool deck, maybe keep the healing out of it, so that a druid only has to download
  bis tools not healing and that way we dont have to do onboarding on bis healing for mages and druids". (And 22 Oct: "a mage can
  ask for an innervate ... the druid sees all the people that opt in and who ever he clicks the druid cast innervate on them".)

  THE ASKING IS LibBiSComm's (MOD IN, minor 17; docs/bisin.md in bisdev): BisInSet / Me / Ready / Askers / Requests / Ask / Claim /
  Cancel and its "BISIN" callback. Any BiS addon's player hears it. Here: what a player sees.
    THE PHONE'S APP (Tools/Apps/Innervate.lua): who asks, who gives, ASK; its live card.
    THE BAR (this file): on your screen, because Innervate is cast in fights and the phone's buttons leave then. A giver's faces are
    SECURE buttons pre-aimed at their unit out of a fight (type spell, unit); in one they only light (alpha) and the click casts. A
    shaman's MANA TIDE is one secure button. An asker's buttons are plain (asking is a message). Shown in a group, only when there
    is something on it. Everything secure is written out of a fight (A.pending -> PLAYER_REGEN_ENABLED).
  In a fight the client holds addon messages (the chat lockdown): an ask made then leaves when it ends, and the button says so.
  The bar steps back while BiS Healing's own utility window is up (one of them is enough). ]]
local _, NS = ...
local R = NS.Registry
local A = {}
NS.Asks = A

local function L() return rawget(_G, "LibBiSComm") end
local function db() return R:Get("innervate") and R:DBFor(R:Get("innervate")) or {} end
local function plain(v) if v == nil or (issecretvalue and issecretvalue(v)) then return nil end return v end
local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a = pcall(fn, ...)
  if ok then return plain(a) end
end
local function fighting() return ask(InCombatLockdown) and true or false end
local function K() return NS.Farm end

A.SPELL = { innervate = "Innervate", pi = "Power Infusion", tide = "Mana Tide Totem" }
A.WORD = { innervate = "INNERVATE", pi = "POWER INFUSION", tide = "MANA TIDE" }
A.NAME = { innervate = "Innervate", pi = "Power Infusion", tide = "Mana Tide" }
A.ICON = { innervate = "Interface\\Icons\\Spell_Nature_Lightning", pi = "Interface\\Icons\\Spell_Holy_PowerInfusion", tide = "Interface\\Icons\\Spell_Frost_SummonWaterElemental" }
A.GIVER = { DRUID = "innervate", PRIEST = "pi", SHAMAN = "tide" }
A.W, A.FACE, A.BOX_H, A.ASK_H, A.PAD, A.REPAINT = 236, 46, 34, 34, 8, 1

-- what the library knows ------------------------------------------------------------------------------------------------------

--- { on, give = { innervate = true }, ask, class } or nil.
function A.Me()
  local lib = L()
  if not (lib and lib.BisInMe) then return nil end
  local ok, me = pcall(lib.BisInMe, lib)
  return ok and type(me) == "table" and me or nil
end
function A.On() local me = A.Me() return R:Enabled("innervate") and me ~= nil and me.on == true end
function A.Order() local lib = L() return lib and lib.BISIN_ORDER or {} end
--- Ready now, seconds to the soonest, the givers' names.
function A.Ready(spell)
  local lib = L()
  if not (lib and lib.BisInReady) then return 0, nil, {} end
  local ok, n, soon, who = pcall(lib.BisInReady, lib, spell)
  if not ok then return 0, nil, {} end
  local left = type(soon) == "number" and math.max(0, soon - (ask(GetServerTime) or 0)) or nil
  return n or 0, left, type(who) == "table" and who or {}
end
--- Seconds until my own spell is ready (0 = now).
function A.Mine(spell)
  local lib = L()
  local s = lib and lib.BisInState and lib.BisInState()
  local at = s and s.cd and s.cd[spell]
  return type(at) == "number" and math.max(0, at - (ask(GetServerTime) or 0)) or 0
end
function A.Requests(spell)
  local lib = L()
  if not (lib and lib.BisInRequests) then return {} end
  local ok, list = pcall(lib.BisInRequests, lib, spell)
  return ok and type(list) == "table" and list or {}
end
--- The group unit a whole name is, or nil.
function A.UnitOf(name)
  local lib = L()
  local full = lib and lib.FullName
  if not (full and name) then return nil end
  if full("player") == name then return "player" end
  local raid = ask(IsInRaid) and true or false
  local n = raid and (ask(GetNumGroupMembers) or 0) or 4
  for i = 1, n do
    local u = (raid and "raid" or "party") .. i
    if ask(UnitExists, u) and full(u) == name then return u end
  end
end
function A.Grouped() return ask(IsInGroup) == true or ask(IsInRaid) == true end
--- A giver's own filter: classes whose faces are left off.
function A.Hidden(class) local h = db().hide return type(h) == "table" and class ~= nil and h[class] == true end
function A.Mode() return db().mode == "boxes" and "boxes" or "faces" end
--- A druid in cat or bear form has no mana bar up: dimmed.
function A.OnMana(unit) local t = ask(UnitPowerType, unit) return t == nil or t == 0 end
--- A unit's mana in percent, or nil (hidden).
function A.Mana(unit)
  local v, mx = ask(UnitPower, unit, 0), ask(UnitPowerMax, unit, 0)
  return type(v) == "number" and type(mx) == "number" and mx > 0 and math.floor(v / mx * 100 + 0.5) or nil
end
function A.Short(name) return tostring(name or "?"):match("^(%S+)") or tostring(name) end
function A.Clock(s) s = math.max(0, math.floor((s or 0) + 0.5)) return ("%d:%02d"):format(math.floor(s / 60), s % 60) end
function A.Locked()
  if type(InChatMessagingLockdown) ~= "function" then return false end
  local ok, v = pcall(InChatMessagingLockdown)
  if not ok then return false end
  if issecretvalue and issecretvalue(v) then return true end
  return v == true
end
--- What there is for me: the spell I give to one person and who may want it, Mana Tide, what I can ask for.
function A.Plan()
  local lib, me = L(), A.Me()
  local plan = { askers = {}, asks = {} }
  if not (lib and me and me.on) then return plan end
  for _, k in ipairs(A.Order()) do
    if me.give and me.give[k] then
      if k == "tide" then plan.tide = true elseif not plan.give then plan.give = k end
    end
  end
  if plan.give then
    local ok, list = pcall(lib.BisInAskers, lib)
    for _, x in ipairs(ok and list or {}) do
      local u = A.UnitOf(x.name)
      if u and u ~= "player" and not A.Hidden(x.class) then plan.askers[#plan.askers + 1] = { name = x.name, class = x.class, unit = u } end
    end
  end
  if me.ask then
    for _, k in ipairs(A.Order()) do
      if not (me.give and me.give[k]) then
        local _, _, givers = A.Ready(k)
        if #givers > 0 then plan.asks[#plan.asks + 1] = k end
      end
    end
  end
  return plan
end
--- Ask, or take it back. Answers the request's id, false (taken back) or nil, why.
function A.Ask(spell)
  local lib = L()
  if not (lib and lib.BisInAsk) then return nil, "not ready" end
  A.asked = A.asked or {}
  local mine = A.asked[spell]
  if mine and lib:BisInRequest(mine) then
    pcall(lib.BisInCancel, lib, mine, "taken back")
    A.asked[spell] = nil
    A.Paint()
    return false
  end
  local ok, id, why = pcall(lib.BisInAsk, lib, spell)
  if ok and id then A.asked[spell] = id else A.said = "could not ask: " .. tostring(ok and why or id) end
  A.Paint()
  return ok and id or nil, why
end
--- My open ask of this spell: its words, and is it open.
function A.AskWords(spell)
  local lib = L()
  local mine = A.asked and A.asked[spell]
  local r = mine and lib and lib.BisInRequest and lib:BisInRequest(mine)
  if mine and not r then A.asked[spell] = nil end
  if r then
    return r.claim and (A.Short(r.claim.by) .. " is answering") or (A.Locked() and "goes out when the fight ends" or "asked"), true
  end
  local n, left, givers = A.Ready(spell)
  if n > 0 then return n == 1 and #givers == 1 and (A.Short(givers[1]) .. " ready") or (n .. " ready"), false end
  if left then return A.Clock(left), false end
  return "nobody ready", false
end
function A.Claim(id)
  local lib = L()
  if id and lib and lib.BisInClaim then pcall(lib.BisInClaim, lib, id) end
end

-- the bar ---------------------------------------------------------------------------------------------------------------------

local function edge(f, colour, a)
  for _, t in ipairs(f.edges or {}) do local r, g, b = K().color(colour) t:SetColorTexture(r, g, b, a or 1) end
end
local function box(b)
  K().tex(b, "BACKGROUND", "frame", 0.96)
  b.edges = {}
  for i = 1, 4 do b.edges[i] = b:CreateTexture(nil, "BORDER") end
  local t = b.edges
  t[1]:SetPoint("TOPLEFT") t[1]:SetPoint("TOPRIGHT") t[1]:SetHeight(1)
  t[2]:SetPoint("BOTTOMLEFT") t[2]:SetPoint("BOTTOMRIGHT") t[2]:SetHeight(1)
  t[3]:SetPoint("TOPLEFT") t[3]:SetPoint("BOTTOMLEFT") t[3]:SetWidth(1)
  t[4]:SetPoint("TOPRIGHT") t[4]:SetPoint("BOTTOMRIGHT") t[4]:SetWidth(1)
  edge(b, "edge")
end
local function stop(f)
  if not f.moving then return end
  f.moving = nil
  NS.LetGo(f)
  local ok, p, _, rp, x, y = pcall(f.GetPoint, f, 1)
  if ok and plain(p) and plain(x) then db().pos = { p, rp, x, y } end
end
A.Stop = function() if A.frame then stop(A.frame) end end

function A.Build()
  if A.frame then return A.frame end
  local f = CreateFrame("Frame", "BiSToolsInnervate", UIParent)
  f:SetSize(A.W, 80)
  local p = db().pos
  if type(p) == "table" and type(p[1]) == "string" then f:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
  else f:SetPoint("CENTER", UIParent, "CENTER", 320, -80) end
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) if not fighting() then self:StartMoving() self.moving = true end end)
  f:SetScript("OnDragStop", stop)
  box(f)
  f.title = K().fs(f, "BiS> innervate", 9, "accent")
  f.title:SetPoint("TOPLEFT", A.PAD, -6)
  f.head = K().fs(f, "", 9, "muted")
  f.head:SetPoint("TOPRIGHT", -24, -6)
  f.close = CreateFrame("Button", nil, f)
  f.close:SetSize(16, 16)
  f.close:SetPoint("TOPRIGHT", -3, -3)
  f.close.label = K().fs(f.close, "x", 10, "muted")
  f.close.label:SetPoint("CENTER")
  f.close:SetScript("OnClick", function() if not fighting() then db().bar = false A.Layout() end end)
  f.faces, f.asks = {}, {}
  f:SetScript("OnUpdate", function(self, e)
    self.acc = (self.acc or 0) + (tonumber(e) or 0)
    if self.acc >= A.REPAINT then self.acc = 0 A.Paint() end
  end)
  f:Hide()
  f:SetScript("OnHide", stop)
  A.frame = f
  return f
end
--- One face: a SECURE button pre-aimed at a unit. The click claims their ask first (the first claim wins everywhere), then casts.
function A.Face(i)
  local f = A.Build()
  local b = f.faces[i]
  if b then return b end
  b = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("type1", "spell")
  box(b)
  local ok, m = pcall(CreateFrame, "PlayerModel", nil, b)
  if ok and m then b.model = m if m.EnableMouse then m:EnableMouse(false) end end
  b.pic = b:CreateTexture(nil, "ARTWORK")
  b.name = K().fs(b, "", 9, "ink")
  b.mana = CreateFrame("StatusBar", nil, b)
  b.mana:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  b.mana:SetStatusBarColor(K().color("slate"))
  b.ask = K().fs(b, "ASKING", 8, "gold")
  b:SetScript("PreClick", function(self, button) if button ~= "RightButton" and self.req then A.Claim(self.req) end end)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(self.who or "?", 1, 1, 1)
    GameTooltip:AddLine((self.req and "asking - " or "") .. "click: " .. (A.SPELL[self.spell] or "?") .. " on them", 0.9, 0.75, 0.29)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  f.faces[i] = b
  return b
end
local function wide(b, secure)
  box(b)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(A.ASK_H - 10, A.ASK_H - 10)
  b.icon:SetPoint("LEFT", 5, 0)
  if b.icon.SetTexCoord then b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  b.word = K().fs(b, "", 10, "ink")
  b.word:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 7, 0)
  b.say = K().fs(b, "", 9, "muted")
  b.say:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 7, 0)
  b:SetScript("OnEnter", function(self) edge(self, "accent") end)
  b:SetScript("OnLeave", function(self) edge(self, self.lit and "gold" or "edge") end)
end
function A.AskButton(i)
  local f = A.Build()
  local b = f.asks[i]
  if b then return b end
  b = CreateFrame("Button", nil, f)
  wide(b)
  b:SetScript("OnClick", function(self) A.Ask(self.spell) end)
  f.asks[i] = b
  return b
end
function A.TideButton()
  local f = A.Build()
  if f.tide then return f.tide end
  local b = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("type1", "spell")
  b:SetAttribute("spell1", A.SPELL.tide)
  wide(b)
  b.icon:SetTexture(A.ICON.tide)
  b.word:SetText("MANA TIDE")
  b:SetScript("PreClick", function(self, button) if button ~= "RightButton" and self.req then A.Claim(self.req) end end)
  f.tide = b
  return b
end

--- May the bar stand: on, in a group, its switch, and BiS Healing's own window away.
function A.BarWanted()
  if not (A.On() and db().bar ~= false and A.Grouped()) then return false end
  local other = rawget(_G, "BiSHealingUtility")
  return not (type(other) == "table" and other.IsShown and ask(other.IsShown, other) == true)
end
--- Out of a fight only: what stands where, who each face is aimed at. Answers whether the bar is up.
function A.Layout()
  if fighting() then A.pending = true return false end
  A.pending = nil
  local plan = A.BarWanted() and A.Plan() or nil
  A.plan = plan
  if not plan or (not plan.tide and #plan.asks == 0 and not (plan.give and #plan.askers > 0)) then
    if A.frame then A.frame:Hide() end
    return false
  end
  local f, P = A.Build(), A.PAD
  local y, mode, used = -22, A.Mode(), 0
  if plan.give then
    local per = mode == "faces" and math.max(1, math.floor((A.W - 2 * P + 4) / (A.FACE + 8))) or 2
    local w = mode == "faces" and A.FACE + 8 or math.floor((A.W - 2 * P + 4) / 2)
    local h = mode == "faces" and A.FACE + 20 or A.BOX_H
    for i, x in ipairs(plan.askers) do
      used = i
      local b = A.Face(i)
      b.who, b.unit, b.spell, b.req = x.name, x.unit, plan.give, nil
      b:SetAttribute("unit", x.unit)
      b:SetAttribute("spell1", A.SPELL[plan.give])
      local col, row = (i - 1) % per, math.floor((i - 1) / per)
      b:ClearAllPoints()
      b:SetSize(w - 4, h)
      b:SetPoint("TOPLEFT", f, "TOPLEFT", P + col * w, y - row * (h + 10) - 8)
      b.name:SetText(A.Short(x.name))
      local cc = RAID_CLASS_COLORS and x.class and RAID_CLASS_COLORS[x.class]
      if cc then b.name:SetTextColor(cc.r, cc.g, cc.b, 1) end
      b.name:ClearAllPoints() b.mana:ClearAllPoints() b.ask:ClearAllPoints()
      if mode == "faces" then
        b.pic:Hide()
        if b.model then
          b.model:ClearAllPoints()
          b.model:SetPoint("TOP", b, "TOP", 0, -2)
          b.model:SetSize(A.FACE - 2, A.FACE - 4)
          b.model:Show()
          pcall(b.model.SetUnit, b.model, x.unit)
          if b.model.SetPortraitZoom then pcall(b.model.SetPortraitZoom, b.model, 1) end
        end
        b.mana:SetPoint("TOP", b, "TOP", 0, -A.FACE) b.mana:SetSize(A.FACE - 4, 4)
        b.name:SetPoint("TOP", b.mana, "BOTTOM", 0, -2)
        b.ask:SetPoint("BOTTOM", b, "TOP", 0, 1)
      else
        if b.model then b.model:Hide() end
        b.pic:ClearAllPoints()
        b.pic:SetPoint("LEFT", 3, 0) b.pic:SetSize(h - 6, h - 6)
        if SetPortraitTexture then pcall(SetPortraitTexture, b.pic, x.unit) end
        b.pic:Show()
        b.name:SetPoint("TOPLEFT", b.pic, "TOPRIGHT", 5, 0)
        b.mana:SetPoint("LEFT", b.pic, "RIGHT", 5, -2) b.mana:SetSize(w - h - 12, 4)
        b.ask:SetPoint("BOTTOMLEFT", b.pic, "BOTTOMRIGHT", 5, 0)
      end
      b:Show()
    end
    y = y - math.ceil(#plan.askers / per) * (h + 10) - (#plan.askers > 0 and 4 or 0)
  end
  for i = used + 1, #f.faces do f.faces[i]:Hide() end
  local function line(b)
    b:ClearAllPoints()
    b:SetSize(A.W - 2 * P, A.ASK_H)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", P, y)
    b:Show()
    y = y - A.ASK_H - 4
  end
  if plan.tide then line(A.TideButton()) elseif f.tide then f.tide:Hide() end
  for i, k in ipairs(plan.asks) do
    local b = A.AskButton(i)
    b.spell = k
    b.icon:SetTexture(A.ICON[k])
    b.word:SetText("ASK: " .. A.WORD[k])
    line(b)
  end
  for i = #plan.asks + 1, #f.asks do f.asks[i]:Hide() end
  f:SetHeight(-y + 4)
  f:Show()
  A.Paint()
  return true
end
--- Any time: who asks lights, the words, the mana.
function A.Paint()
  local f, plan = A.frame, A.plan
  if not (f and f:IsShown() and plan) then return end
  if plan.give then
    local by = {}
    for _, r in ipairs(A.Requests(plan.give)) do by[r.owner] = by[r.owner] or r.id end
    local left = A.Mine(plan.give)
    f.head:SetText(A.WORD[plan.give] .. (left > 0 and " " .. A.Clock(left) or " ready"))
    for _, b in ipairs(f.faces) do
      if b:IsShown() then
        b.req = by[b.who]
        b:SetAlpha(b.req and 1 or (A.OnMana(b.unit) and 0.6 or 0.25))
        edge(b, b.req and "gold" or "edge")
        if b.req then b.ask:Show() else b.ask:Hide() end
        local okM, mx = pcall(UnitPowerMax, b.unit, 0)
        local okV, v = pcall(UnitPower, b.unit, 0)
        if okM and okV then pcall(b.mana.SetMinMaxValues, b.mana, 0, mx) pcall(b.mana.SetValue, b.mana, v) end
      end
    end
  else f.head:SetText("") end
  local function lit(b, on, words)
    b.lit = on and true or nil
    edge(b, on and "gold" or "edge")
    b.say:SetText(words)
    b.say:SetTextColor(K().color(on and "gold" or "muted"))
  end
  if plan.tide and f.tide then
    local r = A.Requests("tide")[1]
    f.tide.req = r and r.id or nil
    local left = A.Mine("tide")
    lit(f.tide, r ~= nil, r and (A.Short(r.owner) .. " asks - click to drop it") or left > 0 and A.Clock(left) or "nobody asks")
  end
  for _, b in ipairs(f.asks) do
    if b:IsShown() and b.spell then local w, on = A.AskWords(b.spell) lit(b, on, on and w .. " - click: take it back" or w) end
  end
end

--- The library told something.
function A.Heard(what)
  if what == "roster" or what == "cd" or what == "me" then A.Layout() end
  if fighting() and (what == "roster" or what == "cd") then A.pending = true end
  A.Paint()
  local D = BiSTheme and BiSTheme.Deck
  if D and D.Dirty and D.mainSurf then D.Phone(D.Dirty) end
end
function A.Hook()
  local lib = L()
  if A.hooked or not (lib and lib.RegisterCallback) then return end
  A.hooked = true
  pcall(lib.RegisterCallback, lib, "BISIN", function(_, what) if R:Enabled("innervate") then A.Heard(what) end end)
end
--- The tool's switch: in or out, everyone is told.
function A.Set(on)
  local lib = L()
  if lib and lib.BisInSet then
    local me = A.Me()
    if (me and me.on or false) ~= on then pcall(lib.BisInSet, lib, on) end
  end
  A.Hook()
  A.Layout()
end

local ev = CreateFrame("Frame")
A.events = ev
local function listen(on)
  for _, e in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "GROUP_ROSTER_UPDATE" }) do
    if on then ev:RegisterEvent(e) else ev:UnregisterEvent(e) end
  end
end
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_DISABLED" then A.Stop() return end
  if event == "PLAYER_REGEN_ENABLED" then if A.pending then A.Layout() end return end
  A.Layout()
end)

R:Register({
  name = "innervate",
  title = "Innervate",
  short = "inn",
  desc = "ask for Innervate, Power Infusion or Mana Tide - and give them: the one who asks lights up, a click casts it",
  usage = "/bist innervate  |  /bist innervate ask",
  defaultOff = true,
  slashWhenOff = true,
  defaults = {},
  options = {
    { kind = "toggle", label = "the bar on your screen", help = "In a group: the faces of who may ask (a giver), Mana Tide (a shaman), the ASK buttons (everyone with mana). It stays in a fight, the phone's buttons do not.",
      get = function(d) return d.bar ~= false end, set = function(d, v) d.bar = v and true or false A.Layout() end },
    { kind = "seg", label = "how people look on it", values = { "faces", "boxes" }, help = "faces = 3D portraits, boxes = small bars.",
      get = function(d) return d.mode == "boxes" and "boxes" or "faces" end, set = function(d, v) d.mode = v == "boxes" and "boxes" or nil A.Layout() end },
  },
  OnLogin = function() if R:Enabled("innervate") then listen(true) A.Set(true) end end,
  OnEnable = function() listen(true) A.Set(true) end,
  OnDisable = function() listen(false) A.Set(false) if A.frame and not fighting() then A.frame:Hide() end end,
  OnOpen = function(_, d, recenter)
    if recenter then
      d.pos = nil
      if A.frame and not fighting() then A.frame:ClearAllPoints() A.frame:SetPoint("CENTER", UIParent, "CENTER", 320, -80) end
      return
    end
    local DP = NS.DeckPages
    if DP and DP.OpenApp and DP.OpenApp("innervate") then return end
    d.bar = true
    A.Layout()
  end,
  OnSlash = function(_, _, args)
    if not R:Enabled("innervate") then R:SetEnabled("innervate", true) end
    if tostring(args or "") == "ask" then
      local plan = A.Plan()
      if plan.asks[1] then A.Ask(plan.asks[1]) else NS.Print("innervate: nobody here gives it yet") end
      return
    end
    local me = A.Me()
    NS.Print("innervate: on - you %s", me and next(me.give or {}) and "give" or "ask")
    A.Layout()
  end,
})
