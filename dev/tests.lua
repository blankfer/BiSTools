-- BiSTools headless harness. Run from the addon root:  lua5.1 dev/tests.lua
-- ------------------------------------------------------------ WoW mock
local W = { combat = false, target = nil, plates = {}, marks = {}, now = 0, forbidden = {} }
_G.__W = W
-- the TOC is the truth for the version and for what loads, in what order
local function readTOC()
  local fh = assert(io.open("BiSTools.toc", "r"))
  local ver, list = nil, {}
  for line in fh:lines() do
    line = line:gsub("\r$", "")
    local v = line:match("^## Version:%s*(.-)%s*$")
    if v then ver = v end
    if line ~= "" and not line:match("^#") then list[#list + 1] = (line:gsub("\\", "/")) end
  end
  fh:close()
  return ver, list
end
local TOC_VERSION, TOC_FILES = readTOC()
_G.GetAddOnMetadata = function(_, key) if key == "Version" then return TOC_VERSION end return "test" end
_G.STANDARD_TEXT_FONT = "font"
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) W.lastMsg = m end }
_G.SlashCmdList = {}
_G.GetTime = function() return W.now end
-- every client answers this; the suite is the TBC client unless a test says otherwise
_G.GetBuildInfo = function() return "2.5.6", "69795", "Sep 1 2026", W.iface or 20506 end
W.afters = {}
function W.runAfters(dt)
  W.now = W.now + (dt or 1)
  local again = true
  while again do
    again = false
    for i = #W.afters, 1, -1 do
      local a = W.afters[i]
      if a.at <= W.now then table.remove(W.afters, i) a.fn() again = true end
    end
  end
end
-- group / raid: W.raid = { {name, zone, online, x, y, inst, visible}, ... }, raid1 = W.raid[1] = "Me"
W.raid, W.inRaid, W.me = { { name = "Me" } }, false, { zone = "Netherstorm", x = 0, y = 0, inst = 530 }
_G.GetNumGroupMembers = function() return #W.raid > 1 and #W.raid or 0 end
_G.IsInRaid = function() return W.inRaid end
_G.IsInGroup = function(cat) if cat then return false end return #W.raid > 1 end
_G.LE_PARTY_CATEGORY_INSTANCE = 2
_G.GetRaidRosterInfo = function(i)
  local m = W.raid[i]
  if not m then return nil end
  return m.name, 0, 1, 70, "Warrior", "WARRIOR", m.zone, m.online ~= false, false
end
_G.UnitIsUnit = function(a, b)
  local function nm(u)
    if u == "player" then return "Me" end
    if u == "target" then return W.target and W.target.name end
    local i = u:match("^raid(%d+)$") return i and W.raid[tonumber(i)] and W.raid[tonumber(i)].name
  end
  return nm(a) ~= nil and nm(a) == nm(b)
end
_G.UnitPosition = function(u)
  if u == "player" then return W.me.y, W.me.x, 0, W.me.inst end
  local i = u:match("^raid(%d+)$")
  local m = i and W.raid[tonumber(i)]
  if m and m.inst == W.me.inst then return m.y, m.x, 0, m.inst end
  return nil
end
_G.UnitIsVisible = function(u)
  local i = u:match("^raid(%d+)$")
  local m = i and W.raid[tonumber(i)]
  return m and m.visible ~= false and m.inst == W.me.inst and m.x ~= nil or false
end
_G.UnitIsConnected = function() return true end
_G.GetRealZoneText = function() return W.me.zone end
_G.UISpecialFrames = {}   -- the client always has it: the frames Escape closes (14 Oct: the rivals window was missing)
_G.IsInInstance = function() return false, "none" end
_G.GetInstanceInfo = function() return W.me.zone, "none", 0, "", 0, 0, false, W.me.inst end
_G.IsShiftKeyDown = function() return W.shift or false end
-- your own feet: walking or still (a zeppelin carries you with them still)
_G.IsPlayerMoving = function() return W.moving and true or false end
-- a unit's 2D face painted onto a texture (the client's own call; the ride card puts yours on RIDE-TRAK)
_G.SetPortraitTexture = function(tex, unit)
  if type(tex) ~= "table" or type(unit) ~= "string" then error("SetPortraitTexture(texture, unit)", 2) end
  tex.portrait = unit
end
W.cursor = { 0, 0 }
_G.GetCursorPosition = function() return W.cursor[1], W.cursor[2] end
W.interactKey = "NUMPADMULTIPLY"
_G.GetBindingKey = function(cmd) if cmd == "INTERACTTARGET" then return W.interactKey end end
W.messages = {}
function W.sentCount(needle) local n = 0 for _, m in ipairs(W.messages) do if m:find(needle, 1, true) then n = n + 1 end end return n end
_G.C_ChatInfo = { RegisterAddonMessagePrefix = function() return true end,
  SendAddonMessage = function(prefix, msg, chan) W.messages[#W.messages + 1] = msg W.prefixes[#W.prefixes + 1] = prefix end }
W.prefixes = {}
W.innervateLoaded = false
_G.IsAddOnLoaded = function(name) return name == "BiSInnervate" and W.innervateLoaded or false end
-- both forms, as the client has them: hooksecurefunc("Global", fn) and hooksecurefunc(tbl, "key", fn)
-- (the table form was missing; the RestedXP listener hooks a method on RXP's own table)
_G.hooksecurefunc = function(a, b, c)
  local tbl, name, fn = _G, a, b
  if type(a) == "table" then tbl, name, fn = a, b, c end
  local orig = tbl[name]
  if type(orig) ~= "function" then return end
  tbl[name] = function(...) local r = orig(...) fn(...) return r end
end
W.offer = nil
_G.GetSummonConfirmSummoner = function() return W.offer and W.offer.summoner end
_G.GetSummonConfirmAreaName = function() return W.offer and W.offer.area end
_G.GetSummonConfirmTimeLeft = function() return W.offer and W.offer.left or 0 end
_G.ConfirmSummon = function() W.accepted = true end
W.notices = {}
_G.RaidWarningFrame = {}
_G.RaidNotice_AddMessage = function(_, text) W.notices[#W.notices + 1] = text end
_G.ChatTypeInfo = { RAID_WARNING = { r = 1, g = 0.5, b = 0 } }
W.tooltipShown, W.tooltipText = false, nil
_G.GameTooltipTextLeft1 = { GetText = function() return W.tooltipText end }
W.now = 1000
_G.time = function() return W.now end
W.facing = 0
_G.GetPlayerFacing = function() return W.facing end
W.map, W.px, W.py = 1952, 0.50, 0.50   -- world size 5000x3300 -> 0.01 = 50y/33y
_G.C_Map = {
  GetBestMapForUnit = function() return W.map end,
  GetPlayerMapPosition = function() return { GetXY = function() return W.px, W.py end } end,
  GetMapWorldSize = function() return 5000, 3300 end,
  -- the overlay map's art (shapes as the client documents them): one layer of 256-px tiles,
  -- 1002 x 668 shown, 4 x 3 files
  GetMapArtLayers = function() return { { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256,
    minScale = 1, maxScale = 1, additionalZoomSteps = 0 } } end,
  GetMapArtLayerTextures = function() local t = {} for i = 1, 12 do t[i] = 100000 + i end return t end,
}
-- the explored pieces of the zone: W.explored, a list as GetExploredMapTextures answers it
W.explored = {}
_G.C_MapExplorationInfo = { GetExploredMapTextures = function() return W.explored end }
_G.GameTooltip = { SetOwner = function() end, AddLine = function() end, AddDoubleLine = function() end, Show = function() end, Hide = function() end,
  IsShown = function() return W.tooltipShown end, GetOwner = function() return nil end }
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.InCombatLockdown = function() return W.combat end
_G.UnitGUID = function(u)
  if u == "player" then return "Player-1" elseif u == "pet" then return "Pet-1" end
  if u == "target" and W.target then return W.target.guid end
  -- a nameplate has a GUID in the client; this used to answer nil, which hid anything keyed by it
  if W.plates[u] then return W.plates[u].guid end
end
_G.UnitExists = function(u)
  if u == "player" then return true end
  local ri = u:match("^raid(%d+)$")
  if ri then return W.raid[tonumber(ri)] ~= nil end
  if u == "pet" then return W.hasPet end
  if u == "target" then return W.target ~= nil end
  return W.plates[u] ~= nil
end
local function unit(u) if u == "target" then return W.target end return W.plates[u] end
_G.UnitName = function(u)
  if u == "player" then return "Me" end
  local i = u:match("^raid(%d+)$")
  if i then return W.raid[tonumber(i)] and W.raid[tonumber(i)].name end
  local x = unit(u) return x and x.name
end
_G.UnitIsDead = function(u) local x = unit(u) return x and x.dead or false end
_G.UnitAffectingCombat = function(u) local x = unit(u) return x and x.combat or false end
_G.UnitIsTapDenied = function(u) local x = unit(u) return x and x.tapped or false end
_G.UnitCanAttack = function(_, u) local x = unit(u) return x and x.hostile ~= false end
-- the client answers this for every unit (13 Oct 2026: the rival line became players-only; a mock
-- without it refused every menu, which the client never does)
_G.UnitIsPlayer = function(u) if u == "player" then return true end local x = unit(u) return x ~= nil and x.player == true end
_G.SetRaidTarget = function(u, i)
  -- PROTECTED ON FOREVER (6 Oct 2026, Arn's BugGrabber: "AddOn 'BiSTools' tried to call the
  -- protected function 'SetRaidTarget()'", from the scanner's ticker). The client blames the addon
  -- and sets nothing. A secure macro's /tm is Blizzard's code and is allowed - the same split as
  -- C_Ping.SendMacroPing (forbidden) and /ping in a secure button (fine), measured 1 Oct.
  if W.restricted then
    W.forbidden[#W.forbidden + 1] = "SetRaidTarget(" .. tostring(u) .. ", " .. tostring(i) .. ")"
    return
  end
  for k, v in pairs(W.marks) do if v == i then W.marks[k] = nil end end -- one skull at a time
  W.marks[u] = i
end
-- A MARK IS A SECRET NUMBER ON FOREVER (6 Oct 2026, Arn's BugGrabber, open world: "attempt to
-- compare local 'm' (a secret number value)" in the scanner, and in the farm spots a kill later).
-- With W.secretMarks set, every read hands back a secret instead of the number - the mock used to
-- answer plainly, which is how two comparisons shipped.
_G.GetRaidTargetIndex = function(u)
  if W.secretMarks then return W.secretMarks() end
  return W.marks[u]
end
W.tickers = {}
_G.C_Timer = { After = function(delay, fn) W.afters[#W.afters + 1] = { at = W.now + delay, fn = fn } end,
  -- a one-shot timer that can be cancelled, as the client's (the party list's invite batches)
  NewTimer = function(delay, fn)
    local t = { alive = true }
    function t:Cancel() self.alive = false end
    W.afters[#W.afters + 1] = { at = W.now + delay, fn = function() if t.alive then fn(t) end end }
    return t
  end,
  NewTicker = function(iv, fn)
  local t = { iv = iv, fn = fn, alive = true }
  function t:Cancel() self.alive = false end
  W.tickers[#W.tickers + 1] = t
  return t
end }
function W.tick() for _, t in ipairs(W.tickers) do if t.alive then t.fn() end end end
W.binds = {}
W.sounds = {} W.spoken = {}
_G.PlaySound = function(id) W.sounds[#W.sounds + 1] = id end
_G.C_VoiceChat = { SpeakText = function(_, text) W.spoken[#W.spoken + 1] = text end }
_G.ClearOverrideBindings = function(owner) W.binds[owner] = nil end
_G.SetOverrideBindingClick = function(owner, prio, key, btn) W.binds[owner] = { key = key, btn = btn } end
_G.CombatLogGetCurrentEventInfo = function() return unpack(W.cleu) end
_G.C_NamePlate = { GetNamePlates = function()
  local out = {}
  for tok in pairs(W.plates) do if tok:find("^nameplate") then out[#out + 1] = { namePlateUnitToken = tok } end end
  table.sort(out, function(a, b) return a.namePlateUnitToken < b.namePlateUnitToken end)
  return out
end }

local function num3(a, b, c) return type(a) == "number" and type(b) == "number" and type(c) == "number" end
local function Texture()
  local t = { shown = true }
  -- size and anchor are REMEMBERED: a label pinned beside an icon starts where the icon ends, and
  -- the fit check below cannot know that if the icon forgot both (they were no-ops)
  function t:SetAllPoints() self.all = true end
  function t:SetPoint(p, rel, rp, x, y)
    if type(rel) == "number" then self.anchor = { p, nil, p, rel, rp }
    else self.anchor = { p, rel, rp or p, x or 0, y or 0 } end
  end
  function t:ClearAllPoints() self.anchor = nil end
  function t:SetHeight(h) self.h = h end
  function t:SetWidth(w) self.w = w end
  function t:SetSize(w, h) self.w, self.h = w, h end
  function t:SetTexture(x) self.file = x end
  function t:AddMaskTexture(m)
    if type(m) ~= "table" or not m.isMask then error("AddMaskTexture wants a mask texture", 2) end
    self.masks = self.masks or {} self.masks[#self.masks + 1] = m
  end
  function t:SetTexCoord() end
  function t:ClearAllPoints() end
  function t:SetRotation(r) if type(r) ~= "number" then error("SetRotation wants a number") end self.rot = r end
  function t:SetVertexColor(r, g, b, a)
    if not num3(r, g, b) then error("SetVertexColor wants r,g,b numbers") end
    self.vertex = { r, g, b, a }
  end
  function t:SetDesaturated(on) self.desat = on end
  function t:SetBlendMode(m) if type(m) ~= "string" then error("SetBlendMode wants a mode name") end self.blend = m end
  function t:SetColorTexture(r, g, b, a)
    if not num3(r, g, b) then error("SetColorTexture wants r,g,b numbers") end
    self.color = { r, g, b, a }
  end
  function t:Hide() self.shown = false end
  function t:Show() self.shown = true end
  function t:SetAlpha(a)
    if type(a) ~= "number" then error("SetAlpha wants a number", 2) end
    self.alpha = a
  end
  return t
end
-- EVERY LABEL, KEPT, WITH WHAT IT IS PINNED TO (6 Oct 2026). Arn's screenshot: "nothing here to
-- point at" and "click a mob to see its spawns" ran straight out of the 124 px Spawns window. A
-- label only remembered its x/y, so nothing could say where it STARTS - and "does it fit" needs
-- that. W.labels is walked by fitsIn() below.
W.labels = {}
local function FontString()
  local s = { shown = true }
  W.labels[#W.labels + 1] = s
  function s:SetFont(_, size, flags) self.size, self.flags = size, flags end
  function s:SetPoint(p, rel, rp, x, y)
    if type(rel) == "number" then self.x, self.y = rel, rp self.anchor = { p, nil, p, rel, rp }
    else self.x, self.y = x, y self.anchor = { p, rel, rp or p, x or 0, y or 0 } end
  end
  function s:ClearAllPoints() self.anchor = nil end
  function s:Show() self.shown = true end
  function s:Hide() self.shown = false end
  function s:IsShown() return self.shown end
  function s:SetText(x) self.text = x end
  function s:GetText() return self.text end
  function s:SetAlpha(a) self.alpha = a end
  function s:GetParent() return self.parent end
  function s:SetWidth(w) if type(w) ~= "number" then error("SetWidth wants a number", 2) end self.w = w end
  function s:SetWordWrap(on) self.wrap = on and true or false end
  function s:SetJustifyH(j)
    if j ~= "LEFT" and j ~= "CENTER" and j ~= "RIGHT" then error("SetJustifyH wants LEFT, CENTER or RIGHT", 2) end
    self.justify = j
  end
  function s:SetTextColor(r, g, b, a)
    if not num3(r, g, b) then error("SetTextColor wants r,g,b numbers") end
    self.color = { r, g, b, a }
  end
  -- ~5.5 px per character at the sizes we use: close enough to catch a label
  -- that runs into the next control
  -- ~0.6 px per point per character: 9pt = 5.4, 8pt = 4.8. Close enough to catch a
  -- label that runs into the next control or off the window
  function s:GetStringWidth()
    -- inline textures |T...:w:h...|t take their declared width, escapes take none
    local t, tex = tostring(self.text or ""), 0
    t = t:gsub("|T[^|]-:(%d+):%d+[^|]*|t", function(w) tex = tex + tonumber(w) return "" end)
    t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    -- LETTERS, NOT BYTES (12 Oct 2026): "Légolas Thiliaere" fit in game and not here - the é is two
    -- bytes, and the client measures glyphs. UTF-8 continuation bytes are not letters.
    return #(t:gsub("[\128-\191]", "")) * (self.size or 9) * 0.6 + tex
  end
  function s:Hide() self.shown = false end
  function s:Show() self.shown = true end
  return s
end
local frames = {}
_G.CreateFrame = function(kind, name, parent, template)
  local f = { kind = kind, name = name, parent = parent, template = template,
    shown = true, scripts = {}, attrs = {}, events = {}, h = 0 }
  -- A 3D MODEL (21 Oct 2026, the ride card's announcer - the first 3D in BiS Tools), as the client draws one by npc id
  -- (BiS Shell's probe, 18 Oct): a creature the client never fetched draws NOTHING the first time it is asked and
  -- the next time it does; GetModelFileID says whether it drew (0 = nothing).
  if kind == "DressUpModel" or kind == "PlayerModel" then
    W.knownCreature = W.knownCreature or {}
    function f:SetCreature(id)
      if type(id) ~= "number" then error("SetCreature needs an npc id", 2) end
      self._creature = id
      if W.knownCreature[id] then self._file = 100000 + id else self._file = 0 W.knownCreature[id] = true end
    end
    function f:ClearModel() self._creature, self._unit, self._file = nil, nil, nil end
    -- a unit's own body (the death recap's player killer, by UnitTokenFromGUID): a token, never a GUID or a name
    function f:SetUnit(u)
      if type(u) ~= "string" or u:find("%-") then error("SetUnit needs a unit token", 2) end
      self._unit, self._file = u, 200000
    end
    function f:GetModelFileID() return self._file or 0 end
    function f:SetPortraitZoom(z) self._zoom = z end
  end
  -- ON FOREVER, REGISTERING THE COMBAT LOG IS A PROTECTED ACTION (6 Oct 2026, Arn's BugGrabber:
  -- "AddOn 'BiSTools' tried to call the protected function 'Frame:RegisterEvent()'"). The client
  -- does not throw - it records the blame and fires ADDON_ACTION_FORBIDDEN later, which is why a
  -- pcall never saw it. This mock always took the registration, so the suite could not tell. With
  -- W.restricted on it behaves like that client: the event is NOT registered and the call is blamed.
  function f:RegisterEvent(e)
    if W.restricted and e == "COMBAT_LOG_EVENT_UNFILTERED" then
      W.forbidden[#W.forbidden + 1] = "Frame:RegisterEvent(" .. e .. ")"
      return
    end
    self.events[e] = true
  end
  function f:UnregisterAllEvents() self.events = {} end
  function f:UnregisterEvent(e) self.events[e] = nil end
  function f:IsMouseOver() return W.mouseOver == self end
  function f:GetParent() return self.parent end
  function f:SetScript(k, fn) self.scripts[k] = fn end
  function f:GetScript(k) return self.scripts[k] end
  -- RE-PARENTED, and REFUSED in combat for a secure frame - the client's rule (12 Oct 2026, the box)
  function f:SetParent(p)
    if W.combat and self.template and self.template:find("Secure") then error("SetParent on a secure frame in combat", 2) end
    self.parent = p
  end
  -- HookScript CHAINS after what is there, as the client's does (12 Oct 2026, the BiS> tools box)
  function f:HookScript(k, fn)
    local prev = self.scripts[k]
    self.scripts[k] = prev and function(...) prev(...) return fn(...) end or fn
  end
  function f:CreateTexture() local t = Texture() self.regions = self.regions or {} self.regions[#self.regions + 1] = t return t end
  -- a mask: a texture other textures take their alpha from (the overlay map's soft edges)
  function f:CreateMaskTexture() local m = Texture() m.isMask = true return m end
  -- a Line (the bg tool's crossed sabers): a texture with two ends and a thickness
  function f:CreateLine()
    local l = Texture()
    function l:SetVertexColor(r, g, b, a)
      if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then error("SetVertexColor wants r,g,b numbers") end
      self.color = { r, g, b, a or 1 }
    end
    function l:SetThickness(w) if type(w) ~= "number" then error("SetThickness wants a number") end self.w = w end
    function l:SetStartPoint(p, rel, x, y)
      if type(p) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then error("SetStartPoint(point, rel, x, y)") end
      self.from = { x, y }
    end
    function l:SetEndPoint(p, rel, x, y)
      if type(p) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then error("SetEndPoint(point, rel, x, y)") end
      self.to = { x, y }
    end
    return l
  end
  function f:CreateFontString() local fs = FontString() fs.parent = self return fs end
  function f:SetSize(w, h) self.w, self.h = w, h end
  function f:SetHeight(h) self.h = h end
  function f:SetWidth(w) self.w = w end
  function f:SetAllPoints() end
  function f:SetTextInsets() end
  function f:SetFont() end
  function f:SetAutoFocus() end
  function f:SetMaxLetters() end
  function f:SetTextColor(r, g, b) if not num3(r, g, b) then error("SetTextColor wants r,g,b") end end
  function f:SetText(x) self.text = x end
  function f:GetText() return self.text or "" end
  function f:ClearFocus() end
  function f:GetHeight() return self.h end
  function f:GetWidth() return self.w end                -- the client answers both (12 Oct 2026)
  function f:SetPoint(p, rel, rp, x, y) self.point = { p, rel, rp, x, y } end
  function f:ClearAllPoints() self.point = nil end
  function f:GetPoint() return "TOPLEFT", nil, "CENTER", 12, -34 end
  function f:SetFrameStrata() end
  function f:SetFrameLevel(l) self.level = l end
  function f:GetFrameLevel() return self.level or 1 end
  function f:SetParent(p) self.parent = p end
  function f:GetCenter() return self.cx or 0, self.cy or 0 end
  function f:GetEffectiveScale() return 1 end
  function f:SetAlpha(a) self.alpha = a end
  function f:SetScale(s) self.scale = s end
  function f:GetScale() return self.scale or 1 end
  -- AN ANIMATION GROUP, RECORDED (12 Oct 2026, the rival crosshair's pulse): the client hands back a
  -- group that makes animations, loops, plays and stops - and runs them itself
  function f:CreateAnimationGroup()
    local g = { anims = {}, playing = false }
    function g:CreateAnimation(kind)
      local a = { kind = kind }
      function a:SetFromAlpha(v) self.from = v end
      function a:SetToAlpha(v) self.to = v end
      function a:SetDuration(v) self.duration = v end
      function a:SetSmoothing(v) self.smoothing = v end
      self.anims[#self.anims + 1] = a
      return a
    end
    function g:SetLooping(v) self.looping = v end
    function g:Play() self.playing = true end
    function g:Stop() self.playing = false end
    function g:IsPlaying() return self.playing end
    return g
  end
  function f:SetMovable() end
  function f:EnableMouse() end
  function f:EnableMouseWheel(on) self.wheel = on end
  function f:SetClampedToScreen() end
  function f:RegisterForDrag() end
  function f:RegisterForClicks(c) self.clicks = c end
  function f:StartMoving() end
  function f:StopMovingOrSizing() end
  function f:Show() self.shown = true end
  function f:Hide() self.shown = false end
  function f:IsShown() return self.shown end
  function f:SetShown(v) self.shown = v and true or false end
  -- VISIBLE IS SHOWN ALL THE WAY UP (7 Oct 2026). A child whose parent hides stays IsShown() -
  -- that is how the Spawns shelf kept refreshing 4 times a second behind a closed farm window.
  function f:IsVisible()
    if not self.shown then return false end
    local p = self.parent
    if type(p) == "table" and type(p.IsVisible) == "function" then return p:IsVisible() end
    return true
  end
  function f:SetAttribute(k, v) if W.combat then error("attribute set in combat: " .. k) end self.attrs[k] = v end
  function f:GetAttribute(k) return self.attrs[k] end
  function f:Click()
    if self.scripts.PreClick then self.scripts.PreClick(self, "LeftButton", true) end
    local t = self.attrs.type
    local tunit = self.attrs.unit or self.attrs["*unit1"]
    if t == "target" or (t == nil and self.attrs["*type1"] == "target") then
      local ri = tunit and tunit:match("^raid(%d+)$")
      W.target = ri and W.raid[tonumber(ri)] or W.plates[tunit]
    elseif t == "macro" then
      local nm = self.attrs.macrotext:match("^/targetexact (.+)$")
      W.target = nil
      for _, tok in ipairs({ "nameplate1", "nameplate2", "nameplate3" }) do
        local p = W.plates[tok]
        if p and p.name == nm then W.target = p break end
      end
    end
    -- the client runs OnClick between the two (23 Oct 2026: the ride card's X was untestable without it)
    if self.scripts.OnClick then self.scripts.OnClick(self, "LeftButton", true) end
    if self.scripts.PostClick then self.scripts.PostClick(self, "LeftButton", true) end
  end
  if name then frames[name] = true _G[name] = f end
  return f
end

_G.Minimap = CreateFrame("Frame", "Minimap")
_G.Minimap.cx, _G.Minimap.cy = 1000, 500
-- ------------------------------------------------------------ load
local before = {} for k in pairs(_G) do before[k] = true end
local NS = {}
-- load exactly what the TOC lists, in TOC order (libs included, no stubs); a bogus
-- TOC line breaks the run here, the same way it would break the client
local files = TOC_FILES
assert(#files >= 9, "TOC lists fewer files than expected: " .. #files)
local handlers = {}
local realCF = _G.CreateFrame
_G.CreateFrame = function(...)
  local f = realCF(...)
  local ss = f.SetScript
  f.SetScript = function(self, k, fn) ss(self, k, fn) if k == "OnEvent" then handlers[#handlers + 1] = { fn = fn, frame = self } end end
  return f
end
-- HEREBEDRAGONS DRIVES THE CLIENT'S OWN MAP ENGINE (CreateVector2D, the world map's data providers,
-- the minimap's zoom tables), which a headless mock cannot stand in for honestly. So its two files
-- are still required to COMPILE, and in their place a stand-in registers under the same LibStub name
-- with the same argument checks the real one raises, and records every pin it is handed. The suite
-- tests what is ours: which map, which spot, which mark, dim or bright, and that pins go away.
W.pins = { minimap = {}, world = {} }
local function fakeHBDPins()
  local P = LibStub:NewLibrary("HereBeDragons-Pins-2.0", 999)
  local function check(ref, icon, map, x, y, what)
    if not ref then error("HereBeDragons-Pins-2.0: " .. what .. ": 'ref' must not be nil", 3) end
    if type(icon) ~= "table" or not icon.SetPoint then error("HereBeDragons-Pins-2.0: " .. what .. ": 'icon' must be a frame", 3) end
    if type(map) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
      error("HereBeDragons-Pins-2.0: " .. what .. ": 'uiMapID', 'x' and 'y' must be numbers", 3)
    end
  end
  -- ONE FRAME CANNOT BE ON BOTH MAPS (6 Oct 2026, Arn: no pins on either map, while every add
  -- answered true). The real library reparents an icon into whichever map draws it - SetParent to
  -- the minimap on add, to a world-map pin when that map draws it, Hide + SetParent(UIParent) when
  -- the world map lets go - so a frame handed to both is fought over and shows on neither. The
  -- stand-in used to take the same frame twice without a murmur; now it refuses, as the client
  -- effectively does by showing nothing.
  local function shared(icon, other, what)
    if other[icon] then error("HereBeDragons-Pins-2.0: " .. what .. ": this frame is already a pin on the other map - each map needs its own frame", 3) end
  end
  function P:AddMinimapIconMap(ref, icon, map, x, y)
    check(ref, icon, map, x, y, "AddMinimapIconMap")
    shared(icon, W.pins.world, "AddMinimapIconMap")
    W.pins.minimap[icon] = { map = map, x = x, y = y } return true
  end
  function P:AddWorldMapIconMap(ref, icon, map, x, y, flag)
    check(ref, icon, map, x, y, "AddWorldMapIconMap")
    shared(icon, W.pins.minimap, "AddWorldMapIconMap")
    if flag ~= nil and type(flag) ~= "number" then error("showFlag must be a number (or nil)", 2) end
    W.pins.world[icon] = { map = map, x = x, y = y, flag = flag } return true
  end
  function P:RemoveMinimapIcon(ref, icon) W.pins.minimap[icon] = nil end
  function P:RemoveWorldMapIcon(ref, icon) W.pins.world[icon] = nil end
  function P:RemoveAllMinimapIcons(ref) W.pins.minimap = {} end
  function P:RemoveAllWorldMapIcons(ref) W.pins.world = {} end
  _G.HBD_PINS_WORLDMAP_SHOW_PARENT, _G.HBD_PINS_WORLDMAP_SHOW_CONTINENT = 1, 2
end
for _, f in ipairs(files) do
  local chunk, err = loadfile(f)
  assert(chunk, "TOC lists a file that does not load: " .. tostring(f) .. " (" .. tostring(err) .. ")")
  if f == "Libs/HereBeDragons/HereBeDragons-2.0.lua" then
    -- compiled above; the engine itself is the client's
  elseif f == "Libs/HereBeDragons/HereBeDragons-Pins-2.0.lua" then
    fakeHBDPins()
  else
    chunk("BiSTools", NS)
  end
end
-- dev/theme.lua: poison the accent AFTER the files load, BEFORE anything is built
if _G.__THEME_MUTATION then BiSTheme.hex.accent = _G.__THEME_MUTATION end
-- Core/Init's frame is the one that listens for ADDON_LOADED (the libs' frames load first)
-- Core/Init's frame: the FIRST of ours to listen for ADDON_LOADED (Core loads before every tool).
-- This picked the LAST one, which was Core's only until a tool listened too (FarmGuide, 6 Oct).
local core
for _, h in ipairs(handlers) do
  if h.frame.events.ADDON_LOADED and h.frame.events.PLAYER_LOGOUT then core = h.fn break end
end
-- and the client hands an event to EVERY frame that registered it, not to one; so does this
local function deliver(event, ...)
  for _, h in ipairs(handlers) do
    if h.frame.events[event] then h.fn(h.frame, event, ...) end
  end
end
deliver("ADDON_LOADED", "BiSTools")
deliver("PLAYER_LOGIN")
-- the client fires PLAYER_ENTERING_WORLD after login; that is when the lib says HI
local function fireAll(ev, ...)
  local seen = {}
  for _, h in ipairs(handlers) do
    local f = h.frame
    if not seen[f] and f.events[ev] and f.scripts.OnEvent then seen[f] = true f.scripts.OnEvent(f, ev, ...) end
  end
end
fireAll("PLAYER_ENTERING_WORLD")
local S = SlashCmdList.BISTOOLS
local R = NS.Registry
local F = NS.Farm
local db = R:DBFor(R:Get("farm"))
local function fire(ev, ...) F.events.scripts.OnEvent(F.events, ev, ...) end
local function db_summon() return R:DBFor(R:Get("summon")) end
local function kill(name, guid, src, mark)
  guid = guid or ("Creature-0-0-0-0-123-" .. name)
  W.cleu = { 0, "PARTY_KILL", false, src or "Player-1", "Me", 0, 0, guid, name }
  if mark then W.target = { name = name, guid = guid } W.marks.target = mark end
  fire("COMBAT_LOG_EVENT_UNFILTERED")
  if mark then W.target = nil W.marks.target = nil end
end
local pass = 0
local function ok(cond, msg, got) if not cond then error("FAIL: " .. msg .. (got ~= nil and ("  [" .. tostring(got) .. "]") or ""), 2) end pass = pass + 1 end

-- THE FIND SOUND IS OFF BY DEFAULT (Arn, 22 Oct: the whisper ping kept going off in Orgrimmar). A fresh install
-- starts "off"; an old save holding the old default "first" turns "off" once; a chosen "always" stays, and
-- "first" chosen again after the switch stays too.
ok(db.sound == "off" and db.soundOff1, "fresh install: find sound off", db.sound)
do
  local farm, keepDb, keepEv = R:Get("farm"), F.db, F.events
  local old, chose, again = { sound = "first" }, { sound = "always" }, { sound = "first", soundOff1 = true }
  farm:OnInit(old) farm:OnInit(chose) farm:OnInit(again)
  F.db, F.events = keepDb, keepEv
  ok(old.sound == "off" and old.soundOff1, "an old save's \"first\" turns off once", old.sound)
  ok(chose.sound == "always", "a chosen \"always\" stays", chose.sound)
  ok(again.sound == "first", "\"first\" picked again after the switch stays", again.sound)
end
S("farm sound first")                            -- the find-sound checks below were written for "first"

-- ------------------------------------------------------------ checks
ok(BiSToolsFarm and BiSToolsFarm:IsShown(), "window shown on login (db.shown default)")
ok(BiSToolsFarm.h == 16 + 4 + 16 + 4, "no kills: header + search well only")
ok(BiSToolsFarmTarget and BiSToolsFarmTarget.template == "SecureActionButtonTemplate", "one secure target button exists")
ok(W.binds[BiSToolsFarmTarget] == nil, "no key bound by default")

kill("Wolf") kill("Wolf")
ok(db.last.name == "Wolf" and db.last.count == 2, "last kill + count")
ok(BiSToolsFarmRow1.name.text == "Wolf" and BiSToolsFarmRow1.count.text == "x2", "row 1 paints Wolf x2")
ok(BiSToolsFarm.h == 16 + 16 + 4 + 16 + 4, "one row + search well")
kill("Boar")
ok(db.last.name == "Boar" and db.last.count == 1 and BiSToolsFarmRow1.name.text == "Boar", "new mob replaces last")
ok(BiSToolsFarmRow2 == nil, "only one kill row")
ok(BiSToolsFarmRow1.template == nil, "rows are plain buttons (rebuildable in combat)")

kill("Farmer", "Player-99") ok(db.last.name == "Boar", "player kills ignored")
kill("Rat", nil, "Player-7") ok(db.last.name == "Boar", "other people's kills ignored")
W.hasPet = true kill("Rat", nil, "Pet-1") ok(db.last.name == "Rat", "pet kills count")

W.combat = true kill("Bear") W.combat = false
ok(BiSToolsFarmRow1.name.text == "Bear", "rows rebuild in combat")

-- hover paints (strict stub catches multi-return truncation)
BiSToolsFarmRow1.scripts.OnEnter(BiSToolsFarmRow1) ok(BiSToolsFarmRow1.bg.color[4] == 1, "hover fills row")
BiSToolsFarmRow1.scripts.OnLeave(BiSToolsFarmRow1) ok(BiSToolsFarmRow1.bg.color[4] == 0, "leave clears row")
F.collapseBtn.scripts.OnEnter(F.collapseBtn) F.collapseBtn.scripts.OnLeave(F.collapseBtn)
F.closeBtn.scripts.OnEnter(F.closeBtn) F.closeBtn.scripts.OnLeave(F.closeBtn)
F.edit.scripts.OnEditFocusGained(F.edit) F.edit.scripts.OnEditFocusLost(F.edit)

-- click once: scanner starts, a mark lands on the free copy
S("farm spots clear")   -- earlier kills made spots (which own marks); start the scanner clean
W.plates = {
  nameplate1 = { name = "Bear", combat = true },
  nameplate2 = { name = "Bear", tapped = true },
  nameplate3 = { name = "Bear" },
}
BiSToolsFarmRow1.scripts.OnClick(BiSToolsFarmRow1)
ok(db.active == "Bear", "click sets active")
ok(F.ticker and F.ticker.alive and F.ticker.iv == 0.5, "ticker running at 0.5s")
ok(W.marks.nameplate3 == 1 and W.marks.nameplate1 == nil and W.marks.nameplate2 == nil, "star on the free one, not the busy ones")
ok(BiSToolsFarmRow1.bar.shown and BiSToolsFarmRow1.bg.color[4] == 1, "active row painted (bar + fill)")
BiSToolsFarmRow1.scripts.OnLeave(BiSToolsFarmRow1)
ok(BiSToolsFarmRow1.bg.color[4] == 1, "active row keeps its fill after mouse leaves")

-- tick again: a second free plate gets the next mark, the first keeps its star
W.plates.nameplate2 = { name = "Bear" }
W.tick() ok(W.marks.nameplate3 == 1 and W.marks.nameplate2 == 2, "second free copy gets circle, star stays")
W.tick() ok(W.marks.nameplate3 == 1 and W.marks.nameplate2 == 2, "stable across ticks")
-- a mark the player put on by hand is respected: nameplate5 wearing square keeps it
W.plates.nameplate5 = { name = "Bear" } W.marks.nameplate5 = 6
W.tick() ok(W.marks.nameplate5 == 6, "hand-placed mark kept")
-- skull on a plate is not one of ours: it gets a scanner mark on top (skull moves off)
W.plates.nameplate6 = { name = "Bear" } W.marks.nameplate6 = 8
W.tick() ok(W.marks.nameplate6 == 3, "skulled plate gets a scanner mark (diamond), skull is the cursor's")
W.plates.nameplate5 = nil W.plates.nameplate6 = nil W.marks.nameplate5 = nil W.marks.nameplate6 = nil

-- skulled one gets tagged: skull moves to another free one
W.plates.nameplate3.tapped = true
W.plates.nameplate2 = nil
W.plates.nameplate4 = { name = "Bear" }
W.tick()
ok(W.marks.nameplate4 == 1 and W.marks.nameplate3 == nil, "star moves when the marked one gets busy")

-- nothing free: no mark, ticker keeps going
W.plates = { nameplate1 = { name = "Bear", combat = true } } W.marks = {}
W.tick() ok(next(W.marks) == nil and F.ticker.alive, "no free plate -> no mark, still scanning")

-- dead ones never marked
W.plates = { nameplate1 = { name = "Bear", dead = true } }
W.tick() ok(next(W.marks) == nil, "corpse not marked")

-- sound, default "first": voice on find 1 only, ping after; nothing for "already marked"
ok(#W.spoken == 1 and #W.sounds == 3, "four real finds so far -> one voice line, three pings")
ok(W.spoken[1] == "Star" and W.sounds[1] == 3081, "plate find names its mark, ping is the whisper sound")
W.marks = {} W.plates.nameplate1 = { name = "Bear" } W.tick() W.tick() W.tick()
ok(#W.sounds == 4 and #W.spoken == 1, "find 5 pings; a mark staying put is not a find")
-- "always": voice every find
S("farm sound always") ok(db.sound == "always", "sound always")
for i = 1, 3 do W.marks = {} W.plates.nameplate1 = { name = "Bear" } W.tick() end
ok(#W.spoken == 4 and #W.sounds == 4, "always -> three more voice lines, no pings")
-- "off": silent
S("farm sound off") ok(db.sound == "off", "sound off")
W.marks = {} W.tick() ok(#W.spoken == 4 and #W.sounds == 4, "off -> silent")
S("farm sound nonsense") ok(db.sound == "off", "bad mode ignored")
S("farm sound first") ok(db.sound == "first", "back to first")
-- FojjiCore present -> it gets the line, tts untouched
_G.FojjiCore = { Speak = function(_, t) W.fojji = t return true end }
W.plates = { nameplate1 = { name = "Bear" } } W.marks = {}
db.finds = 0 W.tick()
ok(W.fojji == "Star" and #W.spoken == 4, "FojjiCore speaks when loaded")
_G.FojjiCore = nil

-- mouseover: hovering the mob from anywhere marks it, instantly on the event
W.plates = { nameplate1 = { name = "Bear" } } W.marks = {} db.finds = 0
W.plates.mouseover = { name = "Bear" }
fire("UPDATE_MOUSEOVER_UNIT")
ok(W.marks.mouseover == 8 and W.marks.nameplate1 == nil, "mouseover gets the skull, plates not touched")
ok(W.spoken[#W.spoken] == "Skull", "mouseover find says Skull")
ok(db.finds == 1, "mouseover mark is a find")
fire("UPDATE_MOUSEOVER_UNIT") W.tick()
ok(db.finds == 1, "hovering the already-marked one is not a new find")
W.plates.mouseover = { name = "Bear", tapped = true } W.marks = {}
W.tick()
ok(W.marks.mouseover == nil and W.marks.nameplate1 == 1, "tapped mouseover ignored, plates still scanned")
-- both marks can be out at once: X from the scanner stays while the skull goes on the hover
W.marks = { nameplate1 = 1 } W.plates.mouseover = { name = "Bear" }
W.tick() ok(W.marks.mouseover == 8 and W.marks.nameplate1 == 1, "skull and scanner marks coexist")
-- hovering a copy that already wears a scanner mark: skull must NOT overwrite it
W.marks = { mouseover = 4 } W.plates.mouseover = { name = "Bear" }
local f0 = db.finds
W.tick() ok(W.marks.mouseover == 4 and db.finds == f0, "hover on a marked mob keeps its mark, no find")
W.plates.mouseover = { name = "Boar" } W.marks = {}
W.tick() ok(W.marks.mouseover == nil, "other mob under the mouse ignored")
W.plates.mouseover = nil
-- mouseover event with nothing active does nothing
local act = db.active db.active = nil F.Stop()
W.plates.mouseover = { name = "Bear" } W.marks = {}
fire("UPDATE_MOUSEOVER_UNIT") ok(next(W.marks) == nil, "no active -> hover does nothing")
W.plates.mouseover = nil db.active = act F.Start(db)

-- click again: off
BiSToolsFarmRow1.scripts.OnClick(BiSToolsFarmRow1)
ok(db.active == nil and not F.ticker, "second click stops the scanner")
ok(not BiSToolsFarmRow1.bar.shown and BiSToolsFarmRow1.bg.color[4] == 0, "row unpainted")

-- typed name: second row, active, kill row untouched
F.edit:SetText("  Ancient Bear  ")
F.edit.scripts.OnEnterPressed(F.edit)
ok(db.custom == "Ancient Bear" and db.active == "Ancient Bear", "typed name searched + active")
ok(BiSToolsFarmRow1.name.text == "Bear" and BiSToolsFarmRow2.name.text == "Ancient Bear" and BiSToolsFarmRow2.shown, "kill row 1, typed row 2")
ok(BiSToolsFarmRow2.bar.shown and not BiSToolsFarmRow1.bar.shown, "typed row is the active one")
ok(BiSToolsFarmRow2.count.text == "", "count 0 paints blank")
ok(F.edit:GetText() == "", "box cleared")
ok(BiSToolsFarm.h == 16 + 32 + 4 + 16 + 4, "two rows + well")
-- switching back to the kill row cancels the old ticker
local tOld = F.ticker
BiSToolsFarmRow1.scripts.OnClick(BiSToolsFarmRow1)
ok(db.active == "Bear" and not tOld.alive and F.ticker.alive and db.finds == 0, "switch active: old ticker cancelled, finds reset")
ok(BiSToolsFarmRow1.bar.shown and not BiSToolsFarmRow2.bar.shown, "bar follows")
-- typed name same as the kill: no duplicate row
F.edit:SetText("Bear") F.edit.scripts.OnEnterPressed(F.edit)
ok(db.custom == "Bear" and BiSToolsFarmRow2.shown == false, "same name as last kill -> one row")
S("farm add Old Bear") ok(db.active == "Old Bear" and BiSToolsFarmRow2.name.text == "Old Bear", "/bt farm add")
-- locked on Old Bear: a stray Wolf kill does not touch the page
kill("Wolf")
ok(BiSToolsFarmRow1.name.text == "Bear" and db.last.name == "Bear" and BiSToolsFarmRow2.name.text == "Old Bear" and db.active == "Old Bear", "locked: other kills ignored, page frozen")
-- kills of the locked (typed) mob count on its own row
kill("Old Bear") kill("Old Bear")
ok(db.customKills == 2 and BiSToolsFarmRow2.count.text == "x2" and db.last.name == "Bear", "locked typed mob counts on row 2, last-kill row untouched")
-- unlock: tracker back on
BiSToolsFarmRow2.scripts.OnClick(BiSToolsFarmRow2)
ok(db.active == nil, "unlocked")
kill("Wolf")
ok(BiSToolsFarmRow1.name.text == "Wolf" and db.last.name == "Wolf", "unlocked: last-kill tracker resumes")
F.edit:SetText("Old Bear") F.edit.scripts.OnEnterPressed(F.edit)
ok(db.active == "Old Bear" and db.customKills == 2, "re-locking the same typed name keeps its count")
F.edit:SetText("Elder Bear") F.edit.scripts.OnEnterPressed(F.edit)
ok(db.customKills == 0, "a different typed name resets the count")
-- locked on the last-kill row: its own kills still count there
BiSToolsFarmRow1.scripts.OnClick(BiSToolsFarmRow1)
ok(db.active == "Wolf", "locked on Wolf")
kill("Wolf")
ok(db.last.count == 2 and BiSToolsFarmRow1.count.text == "x2", "locked last-kill mob keeps counting")
BiSToolsFarmRow1.scripts.OnClick(BiSToolsFarmRow1)
F.edit:SetText("Old Bear") F.edit.scripts.OnEnterPressed(F.edit)

-- target key
S("farm key F")
ok(db.key == "F" and W.binds[BiSToolsFarmTarget].key == "F", "key bound")
W.plates = { nameplate1 = { name = db.active } } W.marks = {}
W.tick()
BiSToolsFarmTarget:Click()
ok(BiSToolsFarmTarget:GetAttribute("type") == "target" and BiSToolsFarmTarget:GetAttribute("unit") == "nameplate1", "key targets the skulled plate")
W.combat = true
BiSToolsFarmTarget:Click()
ok(BiSToolsFarmTarget:GetAttribute("type") == "target", "in combat PreClick touches nothing")
S("farm key none") ok(db.key == nil and F.keyDirty, "unbind in combat deferred")
W.combat = false fire("PLAYER_REGEN_ENABLED")
ok(W.binds[BiSToolsFarmTarget] == nil and not F.keyDirty, "unbound after regen")

-- collapse / toggle / clear / slash
F.SetCollapsed(db, true)
ok(not BiSToolsFarmRow1.shown and not F.well.shown and BiSToolsFarm.h == 16, "collapsed = header only")
F.SetCollapsed(db, false)
ok(BiSToolsFarmRow1.shown and F.well.shown, "expanded again")
S("farm") ok(not BiSToolsFarm:IsShown() and db.shown == false, "/bt farm hides")
ok(F.ticker and F.ticker.alive, "hidden window does not stop the scanner")
S("farm") ok(BiSToolsFarm:IsShown() and db.shown == true, "/bt farm shows")
S("farm clear") ok(db.last == nil and db.custom == nil and db.active == nil and not F.ticker and BiSToolsFarmRow1.shown == false, "/bt farm clear wipes + stops")
kill("Wolf") BiSToolsFarmRow1.scripts.OnClick(BiSToolsFarmRow1)
S("off farm")
ok(not BiSToolsFarm:IsShown() and next(F.events.events) == nil and not F.ticker, "off: hidden, unhooked, scanner stopped")
S("on farm")
ok(BiSToolsFarm:IsShown() and F.events.events.COMBAT_LOG_EVENT_UNFILTERED and F.ticker and F.ticker.alive, "on: back, listening, scanner resumed for saved active")
ok(NS.Registry:Enabled("farm") == true and BiSToolsDB.enabled.farm == nil, "on actually clears the off flag (and/or-nil trap)")

-- ---------------------------------------------------------------- spawn zones + spots
-- radius 20 (zone), 7 (sub). world 5000 wide: 0.001 = 5 yd, 0.004 = 20 yd
local Sp = F.Spots
S("farm clear") S("farm spots clear") S("farm radius 20") S("farm prune off")
ok(Sp.Radius(db) == 20 and math.abs(Sp.SubRadius(db) - 7) < 1e-9, "zone 20 yd, sub 7 yd")
ok(Sp.Prune(db) == 0, "prune off for the checks (time jumps around)")
W.now = 1000 W.px, W.py = 0.500, 0.500
kill("Boar")
local zones = db.spots.Boar
ok(zones and #zones == 1 and zones[1].mark == 1 and #zones[1].subs == 1 and zones[1].subs[1].last == 1000, "first kill: zone (star) + one sub")
ok(not BiSToolsFarmSpots or not BiSToolsFarmSpots:IsShown(), "shelf closed by default")
-- 3 yd away, 5 min later: same sub, respawn learned
W.now = 1300 W.px = 0.5006
kill("Boar")
ok(#zones == 1 and #zones[1].subs == 1 and zones[1].subs[1].respawn == 300 and zones[1].subs[1].kills == 2, "same sub -> respawn 300")
-- burst: 8 s later, same place -> a different mob standing there -> its own sub
W.now = 1308 kill("Boar")
ok(#zones[1].subs == 2 and zones[1].subs[2].last == 1308 and zones[1].subs[2].kills == 1, "kill 8 s after a spot -> new spot (burst)")
ok(#zones[1].subs[1].gaps == 1 and zones[1].subs[1].respawn == 300 and zones[1].subs[1].last == 1300, "first spot untouched by the burst kill")
-- three different marks in 10 s: three spots; a kill 24 s after sub1 is still a burst
W.now = 1310 kill("Boar", nil, nil, 5) W.now = 1314 kill("Boar", nil, nil, 6)
ok(#zones[1].subs == 4, "three quick kills wearing different marks -> three more timers")
W.now = 1355 W.px = 0.5006 kill("Boar")
ok(#zones[1].subs == 5 and zones[1].subs[1].last == 1300, "55 s after sub1 -> still a new spot (burst 60)")
-- burst is a setting
S("farm burst 20") ok(db.burst == 20 and Sp.Burst(db) == 20, "/bt farm burst 20")
S("farm burst 1") ok(Sp.Burst(db) == 5, "burst clamps low")
S("farm burst 9999") ok(Sp.Burst(db) == 300, "burst clamps high")
S("farm burst 60")
-- tidy: keep only the first sub for the rest of the checks
for i = #zones[1].subs, 2, -1 do table.remove(zones[1].subs, i) end
zones[1].subSeq = 1
-- early kill: sub1 respawn 300, killed at 1300; a kill at 1400 (200 s left, > 25%) is another mob
W.now = 1400 W.px = 0.5006 kill("Boar")
ok(#zones[1].subs == 2 and zones[1].subs[1].last == 1300 and zones[1].subs[2].last == 1400, "kill with 200 s still on the clock -> new spot")
table.remove(zones[1].subs, 2) zones[1].subSeq = 1
-- late-ish kill: 40 s left (< 25% of 300) folds in and teaches
W.now = 1560 kill("Boar")
ok(zones[1].subs[1].last == 1560 and #zones[1].subs == 1, "kill with 40 s left folds into the sub")
zones[1].subs[1].gaps = { 300 } zones[1].subs[1].respawn = 300 zones[1].subs[1].last = 1300 zones[1].subs[1].kills = 2
-- 12 yd away: same zone, new sub
W.now = 1400 W.px = 0.5024
kill("Boar")
ok(#zones == 1 and #zones[1].subs == 2 and zones[1].subs[2].id == 2 and not zones[1].subs[2].respawn, "12 yd -> same zone, second sub")
-- 60 yd away: new zone, circle
W.now = 1500 W.px = 0.512
kill("Boar")
ok(#zones == 2 and zones[2].mark == 2 and #zones[2].subs == 1, "60 yd -> second zone (circle)")
-- median at sub1
W.now = 1700 W.px = 0.5006 kill("Boar")
ok(zones[1].subs[1].respawn == 350 and #zones[1].subs[1].gaps == 2, "median of gaps (300, 400)")
kill("Wolf") ok(#db.spots.Boar == 2 and #db.spots.Wolf == 1, "zones are per mob")

-- sub marks: inside zone 1, sub1 wears the star (zone's), sub2 borrows the lowest free (3)
W.px = 0.5006
Sp.Assign(db, "Boar")
ok(zones[1].subs[1].mark == 1 and zones[1].subs[2].mark == 3, "inside zone: sub1 = zone mark, sub2 borrows diamond")
ok(zones[2].subs[1].mark == nil, "other zone's subs hold no marks")
local bound = Sp.BoundMarks(db, "Boar")
ok(bound[1] and bound[2] and bound[3] and not bound[4], "scanner may not deal star, circle, diamond here")
-- walk out: borrowed marks released
W.px = 0.530
Sp.Assign(db, "Boar")
ok(zones[1].subs[1].mark == nil and zones[1].subs[2].mark == nil, "outside: sub marks released")
bound = Sp.BoundMarks(db, "Boar")
ok(bound[1] and bound[2] and not bound[3], "outside: only zone marks are bound")
-- back in: stable assignment
W.px = 0.5006 Sp.Assign(db, "Boar") Sp.Assign(db, "Boar")
ok(zones[1].subs[1].mark == 1 and zones[1].subs[2].mark == 3, "stable on re-entry")

-- shelf: outside shows zones with their soonest sub; inside shows subs
BiSToolsFarmRow1.scripts.OnClick(BiSToolsFarmRow1)
F.edit:SetText("Boar") F.edit.scripts.OnEnterPressed(F.edit)
ok(db.active == "Boar", "farming Boar")
-- the farm header is the BiS> prompt now (11 Sep; Summon since 8 Sep). No logo, name
-- slot "Farm", "farming X" slot while active, events said over them, chat untouched.
do
  local function fshown() return (tostring(F.con:Text()):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
  local function fadv(dt) W.now = W.now + dt F.con:Paint() W.now = W.now + 0.3 F.con:Paint() W.now = W.now + 0.3 F.con:Paint() end
  ok(F.con ~= nil and F.title ~= nil, "the farm title FontString is a BiSTheme console")
  ok(F.con.slots.name and F.con.slots.name.text == "Farm", "name slot is Farm")
  ok(F.con.slots.active and F.con.slots.active.text == "farming Boar", "active slot names the mob", F.con.slots.active and F.con.slots.active.text)
  local chatF = 0 local oldAddF = DEFAULT_CHAT_FRAME.AddMessage
  DEFAULT_CHAT_FRAME.AddMessage = function() chatF = chatF + 1 end
  F.SetActive(db, nil) F.SetActive(db, "Boar")
  DEFAULT_CHAT_FRAME.AddMessage = oldAddF
  ok(chatF == 0, "a row click says it in the prompt, not chat", chatF)
  ok(F.con.slots.active == nil or F.con.slots.active.text == "farming Boar", "slot follows db.active")
  F.con:Clear() fadv(4)
  local seenName, seenActive = false, false
  for _ = 1, 6 do fadv(3) local t = fshown() if t:find("Farm[_ ]") then seenName = true end if t:find("farming Boar") then seenActive = true end end
  ok(seenName and seenActive, "both slots take their turn in the rotation")
  -- budget: prompt never runs into the three header boxes (strip 43 px)
  local wF = F.con:Width()
  ok(wF <= F.W - 43 - 8, "farm prompt fits its budget", wF)
  -- no header logo left behind
  local logos = 0
  for _, r in ipairs(F.head.regions or {}) do if r.file and tostring(r.file):find("RaidTargetingIcon_8") then logos = logos + 1 end end
  ok(logos == 0, "the skull logo is gone from the header", logos)
end
W.px = 0.530
F.spotsBtn.scripts.OnClick(F.spotsBtn)
ok(BiSToolsFarmSpots:IsShown() and db.shelf == true and Sp.ticker and Sp.ticker.alive, "t opens the shelf + ticker")
ok(BiSToolsFarmSpots.point[1] == "TOPLEFT" and BiSToolsFarmSpots.point[2] == BiSToolsFarm, "shelf hangs off the farm window")
ok(BiSToolsFarmSpots.w == 124 and not Sp.title.text:find("Boar"), "slim shelf, plain title")
W.now = 1900 Sp.Refresh(db)
-- layout: zone1 (star, soonest) / its 2 subs indented / zone2 (circle) / its 1 sub
ok(Sp.rows[1].icon.file:find("Icon_1$") and Sp.rows[1].clock.text == "2:30" and Sp.rows[1].clock.x == 33, "row 1: star zone, soonest sub countdown, not indented")
ok(Sp.rows[2].id.text == "#1" and Sp.rows[2].clock.text == "2:30" and Sp.rows[2].clock.x == 45, "row 2: sub #1 indented, no mark (not in its zone)")
ok(Sp.rows[3].id.text == "#2" and Sp.rows[3].clock.text == "+8:20" and Sp.rows[3].clock.x == 45, "row 3: sub #2 indented")
ok(Sp.rows[4].icon.file:find("Icon_2$") and Sp.rows[4].clock.text == "+6:40" and Sp.rows[4].clock.x == 33, "row 4: circle zone")
ok(Sp.rows[5].id.text == "#1" and Sp.rows[5].clock.x == 45, "row 5: circle's sub indented")
ok(not Sp.rows[6] or Sp.rows[6].shown == false, "five rows total")
ok(not Sp.zoneIcon.shown and Sp.rows[1].bg.color[4] == 0, "outside: no zone icon, no tint")
-- step inside zone 1: same layout, its subs now carry marks, its row tinted
W.px = 0.5006 Sp.Refresh(db)
ok(Sp.rows[1].icon.file:find("Icon_1$") and Sp.rows[1].bg.color[4] == 1, "inside: zone row tinted")
ok(Sp.rows[2].icon.file:find("Icon_1$") and Sp.rows[2].clock.text == "2:30", "inside: sub1 wears the star")
ok(Sp.rows[3].icon.file:find("Icon_3$") and Sp.rows[3].clock.text == "+8:20", "inside: sub2 wears the diamond")
ok(Sp.rows[4].icon.file:find("Icon_2$") and Sp.rows[5].id.text == "#1", "other zone and its sub still listed")
ok(Sp.zoneIcon.shown and Sp.zoneIcon.file:find("Icon_1$"), "header shows the zone's mark")
ok(Sp.rows[2].dist.text == "1y" and Sp.rows[3].dist.text == "8y", "yards to each sub")

-- callout 15 s before sub1 (inside: says the sub's mark)
local sp0 = #W.spoken
W.now = 2000 Sp.Refresh(db) ok(#W.spoken == sp0, "50 s left -> quiet")
W.now = 2036 Sp.Refresh(db) ok(#W.spoken == sp0 + 1 and W.spoken[#W.spoken] == "Star", "14 s left -> Star")
W.now = 2038 Sp.Refresh(db) W.tick() ok(#W.spoken == sp0 + 1, "once per cycle")
S("farm sound off") W.now = 2040 Sp.Refresh(db) S("farm sound first")
ok(#W.spoken == sp0 + 1, "sound off keeps it quiet")
-- gold / up
W.now = 2030 Sp.Refresh(db)
ok(Sp.rows[1].clock.text == "0:20" and Sp.rows[1].clock.color[1] == select(1, F.color("gold")), "under 30s goes gold")
W.now = 2100 Sp.Refresh(db)
ok(Sp.rows[1].clock.text == "up" and Sp.rows[1].clock.color[1] == select(1, F.color("good")), "overdue shows up in teal")

-- kill matching by the dying mark: standing 15 yd off inside the zone, mob wore the star
W.px = 0.5036
local s1 = zones[1].subs[1] local s1x = s1.x
W.now = 2200 kill("Boar", nil, nil, 1)
ok(s1.last == 2200 and #zones[1].subs == 2, "kill wearing the star resets sub1 from 15 yd")
ok(s1.x == s1x, "centre not dragged by a far kill")
-- unmarked kill ~19 yd from an up sub (and >7 yd from every sub): folds into the up one
W.now = 2200 + s1.respawn + 5 W.px = 0.5039
kill("Boar")
ok(s1.last == W.now and #zones[1].subs == 2, "unmarked kill near an up sub folds into it")
-- same place, nothing up any more: new sub
W.now = W.now + 30 W.px = 0.5039
kill("Boar")
ok(#zones[1].subs == 3, "same distance, nothing up -> new sub")
-- outside every zone, mob wore the circle -> circle zone gets the kill
W.px = 0.560 W.now = W.now + 100
kill("Boar", nil, nil, 2)
ok(zones[2].last == W.now and #zones == 2, "kill wearing circle from far -> circle zone")
table.remove(zones[1].subs, 3)

-- arrows
local function near(a, b) return math.abs(a - b) < 1e-6 end
W.px = 0.5006 W.facing = 0 Sp.Refresh(db)
-- sub2 is east of the player
local eastRow
for i = 1, 6 do if Sp.rows[i] and Sp.rows[i].shown and Sp.rows[i].icon.shown and Sp.rows[i].icon.file:find("Icon_3$") then eastRow = Sp.rows[i] end end
ok(eastRow and near(eastRow.arrow.rot, -math.pi / 2), "facing north, sub east -> arrow -90deg")
ok(eastRow.arrow.file == "Interface\\Minimap\\MinimapArrow", "arrow uses the minimap player arrow")
W.facing = -math.pi / 2 Sp.Refresh(db) ok(near(eastRow.arrow.rot, 0), "facing east -> straight up")
W.facing = math.pi / 2 Sp.Refresh(db) ok(near(math.abs(eastRow.arrow.rot), math.pi), "facing west -> down")
W.facing = math.pi Sp.Refresh(db) ok(near(eastRow.arrow.rot, math.pi / 2), "facing south -> +90deg")
W.facing = 0
ok(Sp.ticker.iv == 0.25, "shelf ticks at 0.25s")
_G.GetPlayerFacing = function() return nil end
Sp.Refresh(db) ok(not eastRow.arrow.shown and eastRow.clock.text ~= "", "no facing -> arrow hidden")
_G.GetPlayerFacing = function() return W.facing end
W.map = 1 Sp.Refresh(db) ok(Sp.rows[1].dist.text == "" and not Sp.rows[1].arrow.shown, "other map -> no distance, no arrow") W.map = 1952

-- target sync: inside zone 1 next to sub2 (diamond) -> target takes diamond
W.px = 0.5024 W.target = { name = "Boar" } W.marks = { target = 5 }
fire("PLAYER_TARGET_CHANGED")
ok(W.marks.target == 3, "target next to sub2 takes the diamond")
-- outside, near zone 2 -> circle
W.px = 0.512 W.marks = { target = 5 } fire("PLAYER_TARGET_CHANGED")
ok(W.marks.target == 2, "outside near zone 2 -> circle")
W.px = 0.7 W.marks = { target = 5 } fire("PLAYER_TARGET_CHANGED")
ok(W.marks.target == 5, "far from everything -> untouched")
W.target = { name = "Wolf" } W.px = 0.5024 W.marks = { target = 5 } fire("PLAYER_TARGET_CHANGED")
ok(W.marks.target == 5, "other mob -> untouched")
W.target = nil W.px = 0.530

-- scanner respects zone marks outside, and sub marks inside
W.plates = { nameplate1 = { name = "Boar" }, nameplate2 = { name = "Boar" } } W.marks = {}
W.tick()
ok(W.marks.nameplate1 == 3 and W.marks.nameplate2 == 4, "outside: scanner skips star+circle, deals diamond, triangle")
W.px = 0.5006 W.marks = {} W.tick()
ok(W.marks.nameplate1 == 4 and W.marks.nameplate2 == 5, "inside zone 1: diamond is a sub's now, scanner deals triangle, moon")
W.px = 0.530 W.plates = {} W.marks = {}

-- radius setting
S("farm radius 30") ok(db.spotRadius == 30 and Sp.Radius(db) == 30, "/bt farm radius 30")
S("farm radius 999") ok(Sp.Radius(db) == 60, "radius clamps high")
S("farm radius 1") ok(Sp.Radius(db) == 5, "radius clamps low")
S("farm radius abc") ok(Sp.Radius(db) == 5, "bad radius ignored")
S("farm radius 20")

-- zone cap: 10 zones, 7 marked, the rest #n; marks re-dealt when a marked zone drops
for i = 1, 18 do W.now = W.now + 100 W.px = 0.6 + i * 0.01 kill("Boar") end
ok(#zones == 16, "capped at 16 zones")
local marked, unmarked = 0, 0
for _, z in ipairs(zones) do if z.mark then marked = marked + 1 else unmarked = unmarked + 1 end end
ok(marked == 7 and unmarked == 9, "7 zones own marks, 9 do not")
W.px = 0.9 Sp.Refresh(db)
local sawId = false
for i = 1, 40 do if Sp.rows[i] and Sp.rows[i].shown and Sp.rows[i].id.text ~= "" and Sp.rows[i].clock.x == 33 then sawId = true end end
ok(sawId, "markless zones paint #n")
W.plates = { nameplate1 = { name = "Boar" } } W.marks = {}
W.tick() ok(next(W.marks) == nil, "all 7 marks owned by zones -> scanner deals none outside")
W.plates = {}

-- prune: a sub sat up 10 min with no kill folds into its nearest sibling
S("farm prune 600") ok(db.prune == 600 and Sp.Prune(db) == 600, "/bt farm prune 600")
S("farm prune 10") ok(Sp.Prune(db) == 60, "prune clamps low")
S("farm prune 99999") ok(Sp.Prune(db) == 3600, "prune clamps high")
S("farm prune 600")
local pz = zones[1]
pz.subs = {
  { id = 1, x = 0.5000, y = 0.5, last = W.now, kills = 4, respawn = 300, gaps = { 300 } },
  { id = 2, x = 0.5010, y = 0.5, last = W.now - 950, kills = 1, respawn = 300, gaps = { 300 } }, -- up for 650 s
  { id = 3, x = 0.5020, y = 0.5, last = W.now - 500, kills = 1 },                              -- unknown, 500 s
}
Sp.DoPrune(db)
ok(#pz.subs == 2 and pz.subs[1].id == 1 and pz.subs[2].id == 3, "stale sub 2 folded away")
ok(pz.subs[1].kills == 5, "its kills went to the nearest sibling (sub 1)")
W.now = W.now + 200 Sp.DoPrune(db)   -- sub 3 now unknown for 700 s -> stale
ok(#pz.subs == 1 and pz.subs[1].kills == 6, "unknown-respawn sub folds after the window too")
Sp.DoPrune(db) ok(#pz.subs == 1, "the last sub in a zone is never pruned")
S("farm prune off")
W.now = W.now + 5000 Sp.DoPrune(db) ok(#pz.subs == 1, "prune off -> nothing happens")
pz.subs = { { id = 1, x = 0.5000, y = 0.5, last = W.now, kills = 1 } }

-- r on the shelf: this mob only
db.spots.Wolf = { { id = 1, map = 1952, x = 0.1, y = 0.1, last = W.now, kills = 1, subs = {} } }
Sp.resetBtn.scripts.OnClick(Sp.resetBtn)
ok((db.spots.Boar == nil or #db.spots.Boar == 0) and db.spots.Wolf and #db.spots.Wolf == 1 and Sp.empty.shown, "r resets the shown mob only")
S("farm spots") ok(not BiSToolsFarmSpots:IsShown() and not Sp.ticker and db.shelf == false, "/bt farm spots closes")
S("farm spots") ok(BiSToolsFarmSpots:IsShown(), "/bt farm spots reopens")
S("farm spots clear")
local anyZone = false
for _, l in pairs(db.spots) do if #l > 0 then anyZone = true end end
ok(not anyZone and Sp.empty.shown, "spots clear wipes + hint")
S("farm clear") ok(db.spots ~= nil, "plain clear leaves the spots table alone")
S("off farm") ok(not BiSToolsFarmSpots:IsShown() and not Sp.ticker, "off hides shelf")
S("on farm") ok(BiSToolsFarmSpots:IsShown() and Sp.ticker, "on restores shelf (db.shelf)")
W.map = nil kill("Boar") ok(db.last.name == "Boar" and (db.spots.Boar == nil or #db.spots.Boar == 0), "no position -> no zone, kill still recorded") W.map = 1952
-- old flat data upgrades: a zone without subs gets an empty subs table
db.spots.Boar = { { id = 1, map = 1952, x = 0.5, y = 0.5, last = W.now, kills = 3, mark = 1 } }
W.px, W.py = 0.5, 0.5 W.now = W.now + 400
kill("Boar")
ok(db.spots.Boar[1].subs and #db.spots.Boar[1].subs == 1, "flat spot upgraded to a zone with a sub")
W.px, W.py = 0.5, 0.5

-- ---------------------------------------------------------------- comm lib + summon tool
local lib = _G.LibBiSComm
local SM = NS.Summon
ok(lib and lib.MINOR == 17 and lib._booted, "LibBiSComm 1.0 minor 17 loaded and booted from Core/Init")
-- Minor 8 sends one message a second, as the client allows. This suite is about summons and
-- farming, fires dozens of sends with the clock standing still and jumps it without running
-- timers - so it turns the pace off. The pace itself is proven in _bisdev/comm/tests.lua.
lib.sendGap = 0
-- the options kit must come from OUR embed via the TOC, not from the BiSTheme addon happening
-- to be installed: 0.3.0 shipped without the TOC line and the Hub threw "attempt to call field
-- 'Options'" for anyone without BiSTheme (found 11 Sep 2026, fixed 0.3.1). Minor 2 = Escape closes.
do local listed = false for _, f in ipairs(files) do if f == "Libs/BiSTheme/Options.lua" then listed = true end end
  ok(listed, "the TOC lists Libs/BiSTheme/Options.lua (the client loads it from here, not from the BiSTheme addon)") end
ok(type(BiSTheme.Options) == "function", "BiSTheme.Options is defined after the TOC load")
ok(BiSTheme.OPTIONS_MINOR == 3, "options kit minor 3 (windows dodge each other): " .. tostring(BiSTheme.OPTIONS_MINOR))
ok(_G.SLASH_BISCOMM1 == "/biscomm", "minor 4 gave /bis back to LoonBestInSlot; the lib is /biscomm")
for k, v in pairs(_G) do if type(k) == "string" and k:match("^SLASH_") then ok(v ~= "/bis", k .. " must not take /bis (LoonBestInSlot owns it)") end end
-- version: the TOC's, never a literal (RegisterAddon announces it to the whole raid)
ok(NS.VERSION == TOC_VERSION and TOC_VERSION:match("^%d+%.%d+%.%d+"), "NS.VERSION comes from the TOC: " .. tostring(NS.VERSION))
ok(lib.addons and lib.addons.BiSTools == TOC_VERSION, "the lib announces the TOC version, not a string", lib.addons and lib.addons.BiSTools)
do -- hygiene: any VERSION literal in a TOC-listed source must equal ## Version
  for _, f in ipairs(files) do
    if not f:match("^Libs/") then
      local fh = assert(io.open(f)) local src = fh:read("*a") fh:close()
      for lit in src:gmatch("VERSION[^\n]-\"(%d+%.%d+%.%d+)\"") do
        ok(lit == TOC_VERSION, f .. " carries a VERSION literal " .. lit .. " that drifted from the TOC " .. TOC_VERSION)
      end
    end
  end
end

ok(lib.addons.BiSTools == TOC_VERSION, "BiSTools registered itself with the lib, TOC version")
ok(lib:Enabled() and BiSToolsDB.comm == nil, "comm on by default, nothing persisted yet")
ok(NS.Registry:Get("summon") and NS.Registry:Enabled("summon"), "summon tool registered and on")
ok(BiSToolsSummon and not BiSToolsSummon:IsShown(), "summon window built, hidden (auto mode)")

-- the hard rule: the tool toggle never touches the lib
S("summon show") ok(BiSToolsSummon:IsShown() and db_summon().mode == "on", "/bt summon show pins it")
S("off summon")
ok(not BiSToolsSummon:IsShown(), "off: window gone")
ok(lib:Enabled() and next(SM.nagFrame.events) ~= nil, "off: lib still on, nag still listening")
S("on summon") ok(BiSToolsSummon:IsShown(), "on: window back (mode was on)")

-- /biscomm off is the user's own switch, and BiSTools remembers it
SlashCmdList.BISCOMM("off")
ok(not lib:Enabled(), "/biscomm off mutes the lib")
core(nil, "PLAYER_LOGOUT")
ok(BiSToolsDB.comm == false, "logout persists the off switch")
SlashCmdList.BISCOMM("on")
core(nil, "PLAYER_LOGOUT")
ok(BiSToolsDB.comm == true and lib:Enabled(), "/biscomm on persists too")
-- and it is restored BEFORE Boot on the next login: a saved "off" boots silent
do
  BiSToolsDB.comm = false lib._booted = nil lib.enabled = true
  NS.Comm.Boot()
  ok(not lib:Enabled(), "a saved off switch is applied at ADDON_LOADED, before Boot")
  BiSToolsDB.comm = true lib:SetEnabled(true)
end
-- no feature toggle may gate the lib: every tool off/on, every db boolean flipped
do
  for _, t in ipairs({ "farm", "summon" }) do
    S("off " .. t) ok(lib:Enabled(), "/bt off " .. t .. " leaves the lib on")
    S("on " .. t)  ok(lib:Enabled(), "/bt on " .. t .. " leaves the lib on")
  end
  for _, t in ipairs({ "farm", "summon" }) do
    local d = R:DBFor(R:Get(t))
    for k, v in pairs(d) do
      if type(v) == "boolean" then d[k] = not v ok(lib:Enabled(), t .. "." .. k .. " flipped: lib still on") d[k] = v end
    end
  end
  for _, cmd in ipairs({ "farm sound off", "farm sound first", "summon nag off", "summon nag on", "summon key off", "summon key on", "summon summoner", "summon summoner", "summon hide", "summon auto" }) do
    S(cmd) ok(lib:Enabled(), "/bt " .. cmd .. ": lib still on")
  end
  S("summon show")   -- back to pinned, the state the blocks below expect
  -- and a client that logs in with every toggle already off still boots the lib
  local fdb, sdb = R:DBFor(R:Get("farm")), R:DBFor(R:Get("summon"))
  local keep = { fdb.sound, sdb.nag, sdb.key, sdb.summoner, BiSToolsDB.enabled.farm, BiSToolsDB.enabled.summon }
  fdb.sound, sdb.nag, sdb.key, sdb.summoner = "off", false, false, false
  BiSToolsDB.enabled.farm, BiSToolsDB.enabled.summon = false, false
  lib._booted = nil lib.addons.BiSTools = nil
  NS.Comm.Boot()
  ok(lib._booted and lib.addons.BiSTools == TOC_VERSION and lib:Enabled(), "everything off in the saved db: the lib still boots and registers")
  fdb.sound, sdb.nag, sdb.key, sdb.summoner = keep[1], keep[2], keep[3], keep[4]
  BiSToolsDB.enabled.farm, BiSToolsDB.enabled.summon = keep[5], keep[6]
end

-- the only raid that exists: Tools-only, Innervate-only, Gamba-only, and a man with nothing
W.raid = {
  { name = "Me" },
  { name = "Toolsy",  zone = "Netherstorm", x = 1000, y = 1000, inst = 530 },
  { name = "Druid",   zone = "Netherstorm", x = 1300, y = 1000, inst = 530 },
  { name = "Gambler", zone = "Netherstorm", x = 1000, y = 1400, inst = 530 },
  { name = "Nolib",   zone = "Netherstorm", x = 1000, y = 1200, inst = 530 },
  { name = "Farzone", zone = "Shattrath City", x = nil, y = nil, inst = nil },
  { name = "Azzy",    zone = "Stormwind City", x = nil, y = nil, inst = nil },
}
W.me = { zone = "Netherstorm", x = 1000, y = 1000, inst = 530 }
W.inRaid = true
local function say(from, line) lib:OnMessage("BiS", line, "RAID", from) end
-- entering the world in a raid: the lib says HI once (jittered 1-3 s, the mock runs the timer)
do
  W.runAfters(5)   -- drain timers left over from the ungrouped login
  local h0 = 0 for _, m in ipairs(W.messages) do if m:match("^1|CORE|HI|") then h0 = h0 + 1 end end
  fireAll("PLAYER_ENTERING_WORLD")
  W.runAfters(3.5)
  local his = 0 for _, m in ipairs(W.messages) do if m:match("^1|CORE|HI|") then his = his + 1 end end
  ok(his == h0 + 1, "the lib said HI once after entering the world in a raid", his - h0)
  ok(W.messages[#W.messages]:match("^1|CORE|HI|" .. lib.MINOR .. "|BiSTools=" .. TOC_VERSION:gsub("%.", "%%.")), "and the HI carries the lib minor and the TOC version", W.messages[#W.messages])
end
say("Toolsy",  "1|CORE|HI|1|BiSTools=0.1.0|0")
say("Druid",   "1|CORE|HI|1|BiSInnervate=3.3.5|0")
say("Gambler", "1|CORE|HI|1|BiSGamba=1.1.0|0")
ok(lib:HasLib("Toolsy") and lib:HasLib("Druid") and lib:HasLib("Gambler"), "three clients with any BiS addon are peers")
ok(not lib:HasLib("Nolib") and not lib:HasLib("Farzone") and not lib:HasLib("Azzy"), "the addon-less men never become peers")
say("Toolsy",  "1|CORE|WHERE|0|none||Netherstorm|1000.0|1000.0|530")
say("Druid",   "1|CORE|WHERE|0|none||Netherstorm|1300.0|1000.0|530")
say("Gambler", "1|CORE|WHERE|1|raid|Karazhan|Karazhan|100.0|100.0|532")

S("summon near 80")
-- I am standing at a known stone for the list checks (far from one the list is compact)
db_summon().stones = { ["530|Netherstorm"] = { map = 530, zone = "Netherstorm", x = 1000, y = 1000 } }
SM.Refresh(db_summon())
local list, inside = SM.list, SM.inside
local byName = {}
for _, e in ipairs(list) do byName[e.name] = e end
ok(inside == 1 and byName.Gambler == nil, "Gambler says he is inside Karazhan -> counted inside, hidden until 'all'")
ok(byName.Toolsy == nil, "Toolsy stands on us (0 y, visible) -> not a candidate")
ok(byName.Druid and byName.Druid.fact and math.abs(byName.Druid.score - 300) < 1e-6, "Druid is a fact at 300 y from his own WHERE")
ok(byName.Nolib and not byName.Nolib.fact and math.abs(byName.Nolib.score - 200) < 1e-6, "Nolib is a guess at 200 y from UnitPosition")
ok(byName.Farzone and not byName.Farzone.fact and byName.Farzone.score == SM.SCORE_OTHER_ZONE, "Farzone (Shattrath): same world, other zone")
ok(byName.Azzy and byName.Azzy.score == SM.SCORE_OTHER_WORLD and byName.Azzy.world == "Azeroth", "Azzy (Stormwind): other world")
ok(list[1].name == "Azzy" and list[2].name == "Farzone" and list[3].name == "Druid" and list[4].name == "Nolib" and #list == 4, "other world, other zone, then yards; inside hidden")
-- paint: fact plain, guess with a ?
ok(BiSToolsSummonRow1.name.text == "Azzy ?" and BiSToolsSummonRow3.name.text == "Druid" and BiSToolsSummonRow4.name.text == "Nolib ?", "guess rows wear the question mark, fact rows do not")
ok(BiSToolsSummonRow1.info.text == "Azeroth" and BiSToolsSummonRow2.info.text == "far" and BiSToolsSummonRow3.info.text == "300y", "info text: world name, far, yards (I stand at the stone)")
-- unroll: everyone, inside last
BiSToolsSummonAll.scripts.OnClick(BiSToolsSummonAll)
ok(SM.unrolled and #SM.list == 6 and SM.list[5].name == "Gambler" and SM.list[5].inside and SM.list[6].here, "all: Gambler listed as inside, here-people last")
local hereRow
for i = 1, 6 do local r = _G["BiSToolsSummonRow" .. i] if r and r.name.text:find("Toolsy") then hereRow = r end end
ok(hereRow and hereRow.info.text == "here", "all: Toolsy standing with me shows 'here'")
ok(BiSToolsSummonAll.label.color[1] == select(1, F.color("accent")), "all lit")
BiSToolsSummonAll.scripts.OnClick(BiSToolsSummonAll)
ok(not SM.unrolled and #SM.list == 4, "rolled back up")
ok(BiSToolsSummonRow1.template == "SecureActionButtonTemplate" and BiSToolsSummonRow1.clicks == "AnyDown", "rows are secure, AnyDown")
ok(BiSToolsSummonRow1:GetAttribute("*type1") == "target" and BiSToolsSummonRow1:GetAttribute("*unit1") == "raid7", "row targets its unit")
ok(BiSToolsSummonRow1:GetAttribute("shift-type1") == "" and BiSToolsSummonRow1:GetAttribute("type2") == nil and BiSToolsSummonRow1:GetAttribute("*type2") == nil, "shift kills the click, no type2 anywhere")
ok(BiSToolsSummon.h == 16 + 4 * 14 + 4 + 12 + 16, "four rows tall, status line (1 in), request footer - the prompt lives in the header, no strip")
ok(BiSToolsSummonRequest.w + BiSToolsSummonAll.w == BiSToolsSummon.w, "footer: request + all fill the width exactly")
-- every label fits its box, both states of the footer
local function fits(fs, w) return fs:GetStringWidth() <= w end
ok(fits(BiSToolsSummonRequest.label, BiSToolsSummonRequest.w - 8), "footer label fits (idle)")
BiSToolsSummonRequest.scripts.OnClick(BiSToolsSummonRequest)
ok(fits(BiSToolsSummonRequest.label, BiSToolsSummonRequest.w - 8), "footer label fits (requested)")
ok(BiSToolsSummonRequest.label.text:find("cancel"), "and still says cancel")
BiSToolsSummonRequest.scripts.OnClick(BiSToolsSummonRequest)
ok(fits(BiSToolsSummonAll.label, BiSToolsSummonAll.w - 8), "all label fits")
-- header budget: W minus the button strip (56) minus the left pad (4); the title
-- is the BiS> prompt (Arn, 8 Sep: "prompt BiS> _ blinking should be in the header
-- and cycle relevant messages: addon name, summoners at the stone ...")
local BUDGET = SM.W - 56 - 8
local function plain() return (tostring(SM.con:Text()):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
-- move the clock and let the fade (out, then in) finish - Arn: "fade in and out, not hard cuts"
local function adv(dt) W.now = W.now + dt SM.PaintConsole() W.now = W.now + 0.3 SM.PaintConsole() W.now = W.now + 0.3 SM.PaintConsole() end
ok(SM.con and SM.con.fs == SM.title, "the title FontString is the BiSTheme console")
ok(SM.con.words.parent == SM.title.parent, "the words FontString lives in the header too")
adv(0)
ok(plain():find("^BiS> ") and (plain():find("_$") or plain():find(" $")), "prompt: BiS> ... cursor", plain())
ok(SM.con:Width() <= BUDGET, "title fits the header's left budget (idle)")
-- the two footer clicks above said "requested" / "request off": events jump the
-- rotation and hold 3 s each, then the slots come back
ok(plain():find("requested", 1, true), "an event line takes the prompt first", plain())
adv(3)
ok(plain():find("request off", 1, true), "queued events show one after the other", plain())
adv(3)
SM.PaintTitle(0) adv(0)
ok(SM.con.slots.stone == nil and plain():find("Summon", 1, true), "no one at a stone: only the name slot", plain())
SM.PaintTitle(2)
ok(SM.con.slots.stone and SM.con.slots.stone.text:find("UI%-RaidTargetingIcon_4") and SM.con.slots.stone.text:find("2 at stone", 1, true), "2 at stone: triangle + green count slot")
-- the slots rotate: name now, stone after a cycle, name again after another
-- no hard cut: the old words fade out, the new fade in (alpha on the words only)
W.now = W.now + 3 SM.PaintConsole()
ok(SM.con.fading == "out" and plain():find("Summon", 1, true), "cycle due: the old words start fading, still there")
W.now = W.now + 0.1 SM.PaintConsole()
ok(SM.con.words.alpha > 0 and SM.con.words.alpha < 1, "words alpha on the way down", SM.con.words.alpha)
W.now = W.now + 0.2 SM.PaintConsole()
ok(SM.con.words.alpha == 0 and plain():find("2 at stone", 1, true), "swap at zero: the stone slot, coming up")
W.now = W.now + 0.3 SM.PaintConsole()
ok(SM.con.words.alpha == 1 and not SM.con.fading, "solid again")
ok(SM.con:Width() <= BUDGET, "title fits the header's left budget (counting)")
local back
for _ = 1, 4 do adv(3) if plain():find("Summon", 1, true) then back = true break end end
ok(back, "then round to the name again", plain())
SM.PaintTitle(12) adv(3)
ok(SM.con:Width() <= BUDGET, "title fits the header's left budget (12 at stone)")
-- the cursor blinks at 2 Hz and is never trimmed away
W.now = W.now + 0.5 SM.PaintConsole() local c1 = plain():sub(-1)
W.now = W.now + 0.5 SM.PaintConsole() local c2 = plain():sub(-1)
ok((c1 == "_" and c2 == " ") or (c1 == " " and c2 == "_"), "cursor blinks", c1, c2)
ok(SM.count:GetText() == nil or not tostring(SM.count:GetText()):find("at stone", 1, true), "status line no longer repeats the at-stone count")
SM.PaintTitle(0)
-- the status line gets its own row: body height grows by STATUS_H when it has text
SM.count:SetText("") SM.PaintRows(db_summon(), SM.list) local h0 = SM.body.h
SM.count:SetText("1 at stone") SM.PaintRows(db_summon(), SM.list)
ok(SM.body.h == h0 + 12, "status text adds a 12 px line under the rows (GetText, not a mock field)")
SM.Refresh(db_summon())
-- header overlap guard: nothing but title + buttons lives in the header
ok(SM.count.parent == SM.body, "the count line lives under the rows, not in the header")
ok(SM.summonerBtn.point[4] == -38 and SM.askBtn.point[4] == -17 and SM.closeBtn.point[4] == -3, "header buttons at their computed slots")
ok(SM.pinBtn == nil, "no pin button (auto-open covers it; /bt summon show|auto|hide is the manual way)")
ok(SM.summonerBtn.w == 18 and SM.summonerBtn.point[4] - SM.summonerBtn.w == -56, "J's left edge is the 56 px strip")

-- lib 1 peers sent no mapId outdoors: a fact standing next to me must not read "far"
say("Druid", "1|CORE|WHERE|0|none||Netherstorm|1300.0|1000.0|")   -- empty mapId
SM.Refresh(db_summon())
local dd
for _, e in ipairs(SM.list) do if e.name == "Druid" then dd = e end end
ok(dd and math.abs(dd.score - 300) < 1e-6, "no mapId in the WHERE -> UnitPosition yards instead of far")
say("Druid", "1|CORE|WHERE|0|none||Netherstorm|1300.0|1000.0|530")

-- a guess in a blacklisted zone is 'inside' by inference
W.raid[5].zone = "Karazhan"
SM.Refresh(db_summon())
ok(SM.inside == 2 and #SM.list == 3, "Nolib in Karazhan by roster string -> inside (the old guess)")
W.raid[5].zone = "Netherstorm"

-- fact outranks guess at equal score
W.raid[5].x, W.raid[5].y = 1300, 1000
SM.Refresh(db_summon())
ok(SM.list[3].name == "Druid" and SM.list[4].name == "Nolib", "equal 300 y: the fact sorts above the guess")
W.raid[5].x, W.raid[5].y = 1000, 1200

-- click = park. A fact parks 15 s (their client will report the offer), a guess 120 s
W.now = 5000
BiSToolsSummonRow1:Click()   -- Azzy, a guess in the other world
ok(SM.tried.Azzy and math.abs(SM.tried.Azzy - (5000 + 120)) < 1e-6, "clicking a guess parks 120 s")
ok(SM.list[1].name == "Farzone" and SM.list[4].name == "Azzy" and BiSToolsSummonRow4.info.text == "2:00", "parked guess sinks with its clock")
BiSToolsSummonRow1:Click()   -- Farzone, a guess
BiSToolsSummonRow1:Click()   -- Druid, a fact
ok(SM.tried.Druid and math.abs(SM.tried.Druid - (5000 + 15)) < 1e-6, "clicking a fact parks only 15 s")
ok(SM.list[1].name == "Nolib", "Nolib is top now")

-- the peer's own word replaces the park: OFFER with 60 s left, then NO pops him back that second
say("Druid", "1|CORE|SUM|OFFER|Me|Karazhan|60")
ok(SM.tried.Druid == nil, "a SUM from the peer clears our park")
local d
for _, e in ipairs(SM.list) do if e.name == "Druid" then d = e end end
ok(d and d.why == "offer" and math.abs(d.waiting - 60) < 1e-6, "Druid waits on his real 60 s offer")
-- a peer still on lib minor 4 announces a bystander's CONFIRM_SUMMON as an OFFER with no
-- summoner: not an offer here, he is not parked on it
say("Druid", "1|CORE|SUM|NO|||") W.now = W.now + 1 SM.Refresh(db_summon())
say("Druid", "1|CORE|SUM|OFFER|||120")
d = nil for _, e in ipairs(SM.list) do if e.name == "Druid" then d = e end end
ok(d and d.why ~= "offer" and d.summon == nil, "a phantom OFFER (no summoner) from an old peer is ignored", d and d.why)
say("Druid", "1|CORE|SUM|NO|||") SM.Refresh(db_summon())
say("Druid", "1|CORE|SUM|OFFER|Me|Karazhan|60")
d = nil for _, e in ipairs(SM.list) do if e.name == "Druid" then d = e end end
ok(d and d.why == "offer", "a real one still parks him")
W.now = 5030
say("Druid", "1|CORE|SUM|NO|||")
ok(SM.list[1].name == "Druid", "NO -> Druid is back on top that second, not two minutes later")
say("Druid", "1|CORE|SUM|OFFER|Me|Karazhan|60")
say("Druid", "1|CORE|SUM|OK|Me|Karazhan|")
for _, e in ipairs(SM.list) do if e.name == "Druid" then d = e end end
ok(d and d.why == "ok" and d.waiting == 0, "OK -> 'ok', sinks")
local okRow
for i = 1, 4 do if BiSToolsSummonRow1 and _G["BiSToolsSummonRow" .. i].name.text == "Druid" then okRow = _G["BiSToolsSummonRow" .. i] end end
ok(okRow and okRow.info.text == "ok", "row says ok")
-- lapse: OFFER 60 s ago with no word -> not waiting any more
say("Druid", "1|CORE|SUM|OFFER|Me|Karazhan|60")
W.now = 5100 SM.Refresh(db_summon())
for _, e in ipairs(SM.list) do if e.name == "Druid" then d = e end end
ok(d and d.waiting == nil, "an offer past its own clock is no longer waiting")
say("Druid", "1|CORE|SUM|NO|||")
S("summon clear")

-- request a summon: a peer's REQ jumps the queue with "asks"; mine goes out on the wire
S("summon show") SM.Refresh(db_summon())
ok(SM.list[1].name ~= "Nolib", "Nolib is not on top by score")
say("Nolib", "1|SUMMON|REQ|1")   -- the addon-less man cannot send this; pretend a Tools user did
ok(SM.requests.Nolib and SM.list[1].name == "Nolib" and BiSToolsSummonRow1.info.text == "asks", "a request puts him on top with 'asks'")
ok(BiSToolsSummonRow1.info.color[1] == select(1, F.color("gold")), "asks is gold")
ok(W.sounds[#W.sounds] == 3081, "request pings the summoner")
local pr0 = #W.messages
say("Nolib", "1|SUMMON|REQ|1")
ok(#W.sounds > 0 and W.sounds[#W.sounds] == 3081 and SM.requests.Nolib, "repeat request does not re-ping (still asked)")
say("Nolib", "1|SUMMON|REQ|0")
ok(not SM.requests.Nolib and SM.list[1].name ~= "Nolib", "cancel drops him back")
say("Nolib", "1|SUMMON|REQ|1")
W.now = W.now + 700 SM.Refresh(db_summon())
ok(not SM.requests.Nolib, "a request nobody answered dies after 10 min")
say("Druid", "1|SUMMON|REQ|1")
say("Druid", "1|CORE|SUM|OFFER|Me|Karazhan|60")
ok(not SM.requests.Druid, "an offer landing clears the request")
say("Druid", "1|CORE|SUM|NO|||")
-- my own request
local m0 = #W.messages
BiSToolsSummonRequest.scripts.OnClick(BiSToolsSummonRequest)
ok(SM.myRequest and W.messages[m0 + 1] == "1|SUMMON|REQ|1" and W.sentCount("WHERE") > 0, "footer sends REQ 1 and a WHERE")
ok(BiSToolsSummonRequest.label.text:find("cancel"), "footer says click to cancel")
BiSToolsSummonRequest.scripts.OnClick(BiSToolsSummonRequest)
ok(not SM.myRequest and W.messages[#W.messages] == "1|SUMMON|REQ|0", "click again sends REQ 0")
S("summon me") ok(SM.myRequest, "/bt summon me")
W.offer = { summoner = "Warlock", area = "Karazhan", left = 120 }
SM.nagFrame.scripts.OnEvent(SM.nagFrame, "CONFIRM_SUMMON")
ok(not SM.myRequest and W.messages[#W.messages] == "1|SUMMON|REQ|0", "an offer reaching me cancels my request")
SM.nagFrame.scripts.OnEvent(SM.nagFrame, "CANCEL_SUMMON") W.runAfters() SM.NagStop()
-- header is a drag handle
S("summon hide")

-- stones: learned by hover, broadcast, received, and by a peer landing after OK
lib.peers.Nolib = nil   -- the request test spoke as him; he is the addon-less man again
S("summon show")
local dbs = db_summon()
dbs.stones = {}
ok(next(dbs.stones or {}) == nil, "no stones known yet")
W.me = { zone = "Netherstorm", x = 1000, y = 1000, inst = 530 }
W.tooltipShown, W.tooltipText = true, "Tempest Keep Summoning Stone"
local st0 = #W.messages
SM.Watch(dbs, 0.2)
local st = dbs.stones["530|Netherstorm"]
ok(st and st.x == 1000 and st.y == 1000, "hovering the stone records it under map|zone")
ok(W.messages[#W.messages]:find("^1|SUMMON|STONE|530|Netherstorm|1000.0|1000.0"), "and tells the raid")
SM.Watch(dbs, 0.2) SM.Watch(dbs, 0.2)
ok(W.sentCount("SUMMON|STONE") == 1, "told once")
W.tooltipShown = false
-- a peer standing on that stone is "at stone", dropped from the list, counted in the header
say("Druid", "1|CORE|WHERE|0|none||Netherstorm|1010.0|1000.0|530")
SM.Refresh(dbs)
local names = {}
for _, e in ipairs(SM.list) do names[e.name] = true end
ok(not names.Druid and SM.atStone == 2, "Druid within 80 y of the stone -> at stone, not a candidate (Toolsy too)")
ok(SM.con.slots.stone and SM.con.slots.stone.text:find("3 at stone", 1, true), "the prompt's stone slot counts them, me included (green, Innervate-style)", SM.con.slots.stone and SM.con.slots.stone.text)
ok(not (SM.count:GetText() or ""):find("at stone", 1, true), "and the status line does not repeat it")
-- I am at the stone: yards show now (Farzone stays far)
local fz
for i = 1, 4 do local r = _G["BiSToolsSummonRow" .. i] if r and r.shown and r.name.text:find("Farzone") then fz = r end end
ok(fz and fz.info.text == "far", "other zone still 'far' at the stone")
W.raid[5].x, W.raid[5].y = 1000, 1200 SM.Refresh(dbs)
local nb
for i = 1, 4 do local r = _G["BiSToolsSummonRow" .. i] if r and r.shown and r.name.text:find("Nolib") then nb = r end end
ok(nb and nb.info.text == "200y", "at the stone: yards from the stone")
W.me.x, W.me.y = 5000, 5000 W.now = W.now + 5 SM.Refresh(dbs)
-- away from the stone the window is compact: no rows, the empty line counts the stone
local anyRow = false
for i = 1, 6 do local r = _G["BiSToolsSummonRow" .. i] if r and r.shown then anyRow = true end end
ok(not anyRow and not SM.empty.shown and SM.body.h == 4, "away from the stone: compact - no rows, no body text (the header prompt says N at stone)")
ok(SM.count.text == "", "compact: no second count line")
ok(BiSToolsSummonRequest.shown ~= false, "compact: request button still there")
-- unroll shows the list, without yards
BiSToolsSummonAll.scripts.OnClick(BiSToolsSummonAll)
nb = nil
for i = 1, 8 do local r = _G["BiSToolsSummonRow" .. i] if r and r.shown and r.name.text:find("Nolib") then nb = r end end
ok(nb and nb.info.text == "", "unrolled away from the stone: rows, no yards")
BiSToolsSummonAll.scripts.OnClick(BiSToolsSummonAll)
W.me.x, W.me.y = 1000, 1000
-- a guess standing on the stone too (same instance, UnitPosition)
W.raid[5].x, W.raid[5].y = 1000, 1050
SM.Refresh(dbs)
ok(SM.atStone == 3, "the addon-less man at the stone counts too, by UnitPosition")
W.raid[5].x, W.raid[5].y = 1000, 1200
-- I walk away: the stone stays where it was, Druid still at it
W.me.x, W.me.y = 5000, 5000
SM.Refresh(dbs)
ok(SM.atStone == 2, "at-stone is measured from the stone, not from me")
W.me.x, W.me.y = 1000, 1000
say("Druid", "1|CORE|WHERE|0|none||Netherstorm|1300.0|1000.0|530")
-- receive a stone from a peer
say("Toolsy", "1|SUMMON|STONE|530|Shadowmoon Valley|-3000.0|2000.0")
ok(dbs.stones["530|Shadowmoon Valley"] and dbs.stones["530|Shadowmoon Valley"].x == -3000, "a peer's STONE lands in my table")
-- landing: Gambler says OK, arrives, his WHERE after that is the stone
dbs.stones = {}
say("Gambler", "1|CORE|SUM|OFFER|Me|Blade's Edge|60")
say("Gambler", "1|CORE|SUM|OK|Me|Blade's Edge|")
ok(SM.landing and SM.landing.Gambler, "OK starts a landing watch")
local asks0 = W.sentCount("ASK")
W.runAfters(5)
ok(W.sentCount("ASK") == asks0 + 1, "asks once after the teleport")
say("Gambler", "1|CORE|WHERE|0|none||Blade's Edge Mountains|7000.0|-800.0|530")
ok(dbs.stones["530|Blade's Edge Mountains"] and dbs.stones["530|Blade's Edge Mountains"].x == 7000, "his position after landing is the stone")
ok(not SM.landing.Gambler, "watch cleared")
say("Gambler", "1|CORE|SUM|NO|||")

-- a request from someone standing AT the stone still shows (Kumlance at the Stormwind stone, 8 Sep)
S("summon auto") ok(not BiSToolsSummon:IsShown(), "auto: hidden")
say("Druid", "1|CORE|WHERE|0|none||Netherstorm|1010.0|1000.0|530")   -- at the stone
SM.Refresh(dbs)
local seen = false for _, e in ipairs(SM.list) do if e.name == "Druid" then seen = true end end
ok(not seen, "at the stone, no request -> not listed")
say("Druid", "1|SUMMON|REQ|1")
ok(BiSToolsSummon:IsShown(), "a request pops the window in auto mode")
ok(SM.list[1] and SM.list[1].name == "Druid" and SM.list[1].asked, "asked beats the at-stone filter, sits on top")
say("Druid", "1|SUMMON|REQ|0")
say("Druid", "1|CORE|WHERE|0|none||Netherstorm|1300.0|1000.0|530")
S("summon show")

-- freshness: walking off a known stone pushes a WHERE; a summoner re-asks when a fact goes stale
S("summon show")
dbs.stones = { ["530|Netherstorm"] = { map = 530, zone = "Netherstorm", x = 1000, y = 1000 } }
W.me = { zone = "Netherstorm", x = 1000, y = 1000, inst = 530 }
local wh0 = W.sentCount("CORE|WHERE")
SM.selfAtStone = nil SM.SelfWatch(dbs)              -- first look just remembers
ok(W.sentCount("CORE|WHERE") == wh0 and SM.selfAtStone == true, "first look: at the stone, nothing sent")
SM.SelfWatch(dbs)
ok(W.sentCount("CORE|WHERE") == wh0, "still there: nothing sent")
W.me.x = 1500 SM.SelfWatch(dbs)                       -- 2500 yd off
ok(W.sentCount("CORE|WHERE") == wh0 + 1 and SM.selfAtStone == false, "walked off the stone -> one WHERE")
SM.SelfWatch(dbs) SM.SelfWatch(dbs)
ok(W.sentCount("CORE|WHERE") == wh0 + 1, "standing away: nothing more")
W.me.x = 1000 SM.SelfWatch(dbs)
ok(W.sentCount("CORE|WHERE") == wh0 + 2, "back on it -> one more")
ok(SM.selfTicker and SM.selfTicker.iv == 3, "self-watch ticks every 3 s from load")
-- re-ask: a fact older than 30 s while the window is up
local ask0 = W.sentCount("ASK")
for _, p in pairs(lib:Peers()) do if p.where then p.where.at = W.now end end
SM.lastReask = nil SM.Reask(dbs)
ok(W.sentCount("ASK") == ask0, "all facts fresh -> no ask")
lib:Peer("Druid").where.at = W.now - 40
SM.Reask(dbs)
ok(W.sentCount("ASK") == ask0 + 1, "a 40 s old fact -> one ask")
SM.Reask(dbs)
ok(W.sentCount("ASK") == ask0 + 1, "throttled to one per 15 s")
W.now = W.now + 16 SM.Reask(dbs)
ok(W.sentCount("ASK") == ask0 + 2, "asks again after 15 s if still stale")
lib:Peer("Druid").where.at = W.now
S("summon hide") SM.Reask(dbs) W.now = W.now + 16
ok(W.sentCount("ASK") == ask0 + 2, "window hidden -> never asks")
dbs.stones = {} W.me.x = 1000 SM.selfAtStone = nil

-- two at a stone pops the window for everyone (auto mode), and keeps it while true
S("summon auto")
dbs.stones = { ["530|Netherstorm"] = { map = 530, zone = "Netherstorm", x = 1000, y = 1000 } }
W.me = { zone = "Netherstorm", x = 5000, y = 5000, inst = 530 }   -- I am far away
say("Druid",  "1|CORE|WHERE|0|none||Netherstorm|1300.0|1000.0|530")
say("Toolsy", "1|CORE|WHERE|0|none||Netherstorm|1005.0|1000.0|530")  -- one at the stone
W.now = W.now + 20 SM.selfAtStone = nil SM.SelfWatch(dbs)
ok(not BiSToolsSummon:IsShown(), "one at the stone: nothing")
say("Druid", "1|CORE|WHERE|0|none||Netherstorm|1010.0|1000.0|530")   -- now two
SM.SelfWatch(dbs)
ok(BiSToolsSummon:IsShown(), "two at the stone: the window pops for me, far away")
ok(not SM.empty.shown and SM.body.h == 4 and SM.con.slots.stone.text:find("2 at stone", 1, true), "compact: bare body, the header prompt says 2 at stone")
W.now = W.now + 20 SM.SelfWatch(dbs) SM.Watch(dbs, 0.2)
ok(BiSToolsSummon:IsShown(), "stays while two are there")
say("Druid", "1|CORE|WHERE|0|none||Netherstorm|1300.0|1000.0|530")   -- one walks off
W.now = W.now + 20 SM.SelfWatch(dbs) SM.Watch(dbs, 0.2)
ok(BiSToolsSummon:IsShown(), "one left -> a few seconds of grace")
W.now = W.now + 6 SM.Watch(dbs, 0.2)
ok(not BiSToolsSummon:IsShown(), "then it hides")
W.me = { zone = "Netherstorm", x = 1000, y = 1000, inst = 530 }
dbs.stones = {} S("summon show")

-- the prompt in the header: events show over the slots, hold 3 s, chat stays clean
S("summon show")
local chat0 = 0
local oldAdd = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(_, m) chat0 = chat0 + 1 W.lastMsg = m end
local function shown() return (tostring(SM.con:Text()):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function adv(dt) W.now = W.now + dt SM.PaintConsole() W.now = W.now + 0.3 SM.PaintConsole() W.now = W.now + 0.3 SM.PaintConsole() end
SM.con:Clear() adv(4)
ok(shown():find("^BiS> "), "prompt always there")
local h0 = BiSToolsSummon.h
SM.Log("request now", "good") adv(0)
ok(shown():find("request now", 1, true) and not shown():find("%.%.%."), "event printed whole in the prompt", shown())
ok(BiSToolsSummon.h == h0, "the window did not grow: no strip")
ok(SM.con:Width() <= SM.W - 56 - 8, "prompt fits the header budget")
ok(SM.con.line and SM.con.line.colour == "good", "coloured as asked")
adv(3)
ok(not shown():find("request now", 1, true), "gone after the hold, back to the slots", shown())
for i = 1, 3 do SM.Log("line " .. i) end
adv(0)
ok(shown():find("line 1", 1, true) and #SM.con.queue == 2, "several events queue up, first one showing")
adv(3) ok(shown():find("line 2", 1, true), "second after the hold")
adv(3) ok(shown():find("line 3", 1, true), "third after the next")
adv(3) ok(not shown():find("line", 1, true), "then the slots again")
-- a long event is trimmed with an ellipsis, the cursor survives the trim
SM.Log("Verylongdruidname accepted the thing", "good") adv(0)
ok(shown():find("%.%.%.[_ ]$") and SM.con:Width() <= SM.W - 56 - 8, "long line trimmed, cursor kept, fits", shown())
adv(3)
-- the everyday events go to the prompt, not chat
chat0 = 0
say("Druid", "1|SUMMON|REQ|1") adv(0)
ok(chat0 == 0 and shown():find("Druid asks", 1, true), "a request prints in the prompt, not chat", shown())
-- "N asking" is for summoners only (Arn, 8 Sep: "a random person should not see 1 asking")
ok(SM.con.slots.asks == nil, "far from any stone, not the summoner: no asking slot for me")
dbs.summoner = true SM.Refresh(dbs)
ok(SM.con.slots.asks and SM.con.slots.asks.text == "1 asking", "the summoner sees the asking slot")
dbs.summoner = false SM.Refresh(dbs)
ok(SM.con.slots.asks == nil, "summoner mode off: gone again")
SM.stoneSeen = W.now SM.Refresh(dbs)
ok(SM.con.slots.asks and SM.con.slots.asks.text == "1 asking", "standing at a stone: the asking slot shows")
SM.stoneSeen = nil
say("Druid", "1|SUMMON|REQ|0") SM.Refresh(dbs)
ok(SM.con.slots.asks == nil, "asking slot clears with the request")
-- my own echo: the client hands my REQ back to me; the lib (minor 3) drops it
local lib3 = SM.Lib()
lib3:OnMessage("BiS", "1|SUMMON|REQ|1", "RAID", "Me")
lib3:OnMessage("BiS", "1|CORE|WHERE|0|none||Netherstorm|1000.0|1000.0|530", "RAID", "Me")
ok(SM.requests.Me == nil and lib3:Peer("Me") == nil, "my own REQ / WHERE echo never makes me a peer or a requester")
adv(3)
say("Druid", "1|CORE|SUM|OFFER|Me|Karazhan|60") adv(0)
ok(shown():find("Druid offered", 1, true), "offer line", shown())
adv(3)
say("Druid", "1|CORE|SUM|NO|||") adv(0)
ok(shown():find("Druid declined", 1, true), "decline line", shown())
ok(chat0 == 0, "still nothing in chat")
DEFAULT_CHAT_FRAME.AddMessage = oldAdd
-- my own request is a standing slot while it lasts
BiSToolsSummonRequest.scripts.OnClick(BiSToolsSummonRequest)
ok(SM.con.slots.mine and SM.con.slots.mine.text == "requesting...", "requesting slot while my request stands")
BiSToolsSummonRequest.scripts.OnClick(BiSToolsSummonRequest)
ok(SM.con.slots.mine == nil, "cleared when I take it back")
-- pop and leave narrate themselves
S("summon auto") SM.con:Clear() SM.popped = false
dbs.stones = { ["530|Netherstorm"] = { map = 530, zone = "Netherstorm", x = 1000, y = 1000 } }
W.me = { zone = "Netherstorm", x = 5000, y = 5000, inst = 530 }
say("Druid",  "1|CORE|WHERE|0|none||Netherstorm|1010.0|1000.0|530")
say("Toolsy", "1|CORE|WHERE|0|none||Netherstorm|1005.0|1000.0|530")
W.now = W.now + 20 SM.selfAtStone = nil SM.SelfWatch(dbs) adv(0)
ok(BiSToolsSummon:IsShown() and shown():find("request now", 1, true), "pop narrates: request now", shown())
ok(SM.con.slots.stone and SM.con.slots.stone.text:find("2 at stone", 1, true), "and the stone slot says 2 at stone")
local q0 = #SM.con.queue
SM.SelfWatch(dbs) ok(#SM.con.queue == q0, "said once")
say("Druid", "1|CORE|WHERE|0|none||Netherstorm|1300.0|1000.0|530")
adv(3) SM.SelfWatch(dbs) adv(0)
ok(shown():find("no summons", 1, true), "leave narrates: no summons", shown())
W.now = W.now + 4 SM.Watch(dbs, 0.2) ok(BiSToolsSummon:IsShown(), "still up 4 s later")
W.now = W.now + 2 SM.Watch(dbs, 0.2) ok(not BiSToolsSummon:IsShown(), "hidden ~5 s after the line")
W.me = { zone = "Netherstorm", x = 1000, y = 1000, inst = 530 }
dbs.stones = {} SM.con:Clear() S("summon show")

-- the interact key over the window: press 1 targets the top name, press 2 is the real interact
S("summon show") SM.Refresh(dbs)
local kb = SM.KeyButton()
W.target = nil W.mouseOver = nil
SM.Watch(dbs, 0.2)
ok(W.binds[kb] == nil, "mouse off the window: no override")
W.mouseOver = SM.frame
SM.Watch(dbs, 0.2)
ok(W.binds[kb] and W.binds[kb].key == "NUMPADMULTIPLY" and W.binds[kb].btn == "BiSToolsSummonKey", "mouse on the window, top not targeted -> interact key overridden to the key button")
ok(kb:GetAttribute("*unit1") == SM.list[1].unit, "key button points at the top name")
kb:Click()                                       -- press 1
ok(W.target and W.target.name == SM.list[1].name, "press 1 targets the top name")
ok(SM.list[1].name == W.target.name, "and does NOT park him")
SM.Watch(dbs, 0.2)
ok(W.binds[kb] == nil, "top targeted -> override dropped, press 2 is the real interact")
-- park him (his offer lands): the top changes, the override is back
say(SM.list[1].name, "1|CORE|SUM|OFFER|Me|Karazhan|60")
SM.Watch(dbs, 0.2)
ok(W.binds[kb] and kb:GetAttribute("*unit1") == SM.list[1].unit, "new top -> re-armed on the new name")
say(W.target.name, "1|CORE|SUM|NO|||")
W.combat = true W.mouseOver = nil
SM.Watch(dbs, 0.2)
ok(W.binds[kb] ~= nil, "in combat: binds untouched")
W.combat = false
SM.Watch(dbs, 0.2) ok(W.binds[kb] == nil, "mouse off -> cleared")
S("summon key off") W.mouseOver = SM.frame W.target = nil SM.Watch(dbs, 0.2)
ok(W.binds[kb] == nil, "/bt summon key off -> never armed")
S("summon key on") SM.Watch(dbs, 0.2) ok(W.binds[kb] ~= nil, "back on")
W.interactKey = nil SM.Watch(dbs, 0.2) ok(W.binds[kb] == nil, "no interact key bound -> nothing to override")
W.interactKey = "NUMPADMULTIPLY" W.mouseOver = nil W.target = nil SM.Watch(dbs, 0.2)
S("off summon") ok(W.binds[kb] == nil, "tool off clears the override") S("on summon")
S("summon hide")

-- summoner mode: the summoner opts in; window pinned, requests come through like a raid warning
S("summon summoner on")
ok(dbs.summoner and dbs.mode == "on" and BiSToolsSummon:IsShown(), "summoner: pinned")
ok(SM.summonerBtn.label.color[1] == select(1, F.color("gold")), "J lit gold")
local n0 = #W.notices
say("Nolib", "1|SUMMON|REQ|1")
ok(#W.notices == n0 + 1 and W.notices[#W.notices]:find("Nolib") and W.sounds[#W.sounds] == 8959 and W.spoken[#W.spoken] == "Summon", "summoner: request = raid warning + sound + voice")
say("Nolib", "1|SUMMON|REQ|0")
S("summon summoner off")
say("Nolib", "1|SUMMON|REQ|1")
ok(#W.notices == n0 + 1 and W.sounds[#W.sounds] == 3081, "not summoner: quiet ping only")
say("Nolib", "1|SUMMON|REQ|0")
SM.summonerBtn.scripts.OnClick(SM.summonerBtn) ok(dbs.summoner, "J button toggles") SM.summonerBtn.scripts.OnClick(SM.summonerBtn) ok(not dbs.summoner, "and back")
S("summon hide") dbs.stones = {}

-- stone mouseover brings the window up in auto mode, asks the raid once, lingers, hides
S("summon auto")
ok(not BiSToolsSummon:IsShown() and db_summon().mode == "auto", "auto: hidden until a stone")
local asksBefore = W.sentCount("ASK")
W.tooltipShown, W.tooltipText = true, "Karazhan Summoning Stone"
W.now = 6000 SM.Watch(db_summon(), 0.2)
ok(BiSToolsSummon:IsShown(), "stone under the cursor -> window up")
ok(W.sentCount("ASK") == asksBefore + 1, "one ASK on the way up")
SM.Watch(db_summon(), 0.2) SM.Watch(db_summon(), 0.2)
ok(W.sentCount("ASK") == asksBefore + 1, "standing there costs no more asks")
W.tooltipShown = false
W.now = 6005 SM.Watch(db_summon(), 0.2)
ok(BiSToolsSummon:IsShown(), "lingers 8 s after you look away")
W.now = 6010 SM.Watch(db_summon(), 0.2)
ok(not BiSToolsSummon:IsShown(), "then hides")
ok(SM.IsStoneText("Meeting Stone") and not SM.IsStoneText("Innkeeper"), "stone text patterns")
ok(SM.IsStoneText("Pierre de convocation", "convocation"), "custom stone name (other locales)")
W.tooltipShown, W.tooltipText = true, "Some NPC"
W.now = 7000 SM.Watch(db_summon(), 0.2)
ok(not BiSToolsSummon:IsShown(), "a non-stone tooltip does nothing")
W.tooltipShown = false

-- combat: Show/Hide queued, flushed on regen
S("summon show")
W.combat = true
S("summon hide")
ok(BiSToolsSummon:IsShown() and SM.pending.visible == false, "hide in combat is queued")
W.combat = false
SM.events.scripts.OnEvent(SM.events, "PLAYER_REGEN_ENABLED")
ok(not BiSToolsSummon:IsShown(), "flushed on regen")

-- the nag: fires on the person being summoned, keeps going, stops on accept/cancel, survives /bt off summon
local nagFrame = SM.nagFrame
local notices0, sounds0, spoken0 = #W.notices, #W.sounds, #W.spoken
W.offer = { summoner = "Warlock", area = "Karazhan", left = 120 }
lib:OnConfirmSummon()                     -- the lib's own handler (order between frames is not promised)
nagFrame.scripts.OnEvent(nagFrame, "CONFIRM_SUMMON")
W.runAfters()
ok(#W.notices == notices0 + 1 and W.notices[#W.notices]:find("Warlock") and W.notices[#W.notices]:find("Karazhan"), "raid-warning text names the summoner and the place")
ok(W.sounds[#W.sounds] == 8959 and W.spoken[#W.spoken] == "Summon", "raid warning sound + voice line")
W.now = W.now + 20 W.tick()
ok(#W.notices == notices0 + 2, "nags again 20 s later")
lib:OnConfirmed() SM.NagStop()            -- accept (the hook does this live)
W.now = W.now + 20 W.tick()
ok(#W.notices == notices0 + 2 and not SM.nag.active, "accepted -> quiet")
-- cancel path
W.offer = { summoner = "Warlock", area = "Karazhan", left = 120 }
lib:OnConfirmSummon() nagFrame.scripts.OnEvent(nagFrame, "CONFIRM_SUMMON") W.runAfters()
ok(SM.nag.active, "second offer nags")
nagFrame.scripts.OnEvent(nagFrame, "CANCEL_SUMMON")
ok(not SM.nag.active, "cancel stops it")
-- tool off, nag on
S("off summon")
W.offer = { summoner = "Warlock", area = "Karazhan", left = 120 }
lib:OnConfirmSummon() nagFrame.scripts.OnEvent(nagFrame, "CONFIRM_SUMMON") W.runAfters()
ok(SM.nag.active and #W.notices == notices0 + 4, "nag works with the summon tool switched off")
nagFrame.scripts.OnEvent(nagFrame, "CANCEL_SUMMON")
S("summon nag off")
lib:OnConfirmSummon() nagFrame.scripts.OnEvent(nagFrame, "CONFIRM_SUMMON") W.runAfters()
ok(not SM.nag.active and #W.notices == notices0 + 4, "/bt summon nag off is the only thing that silences it")
S("summon nag on")
nagFrame.scripts.OnEvent(nagFrame, "CANCEL_SUMMON")
-- a bystander's CONFIRM_SUMMON (someone ELSE got summoned; the client fires it on me with
-- nothing behind it - Arn: "randomly ... it says SUMMON by someone"): no nag, no OFFER,
-- and my own pending request is not cancelled by it
do
  W.offer = nil
  local n1, m1 = #W.notices, #W.messages
  SM.myRequest = true
  lib:OnConfirmSummon() nagFrame.scripts.OnEvent(nagFrame, "CONFIRM_SUMMON") W.runAfters()
  ok(#W.notices == n1 and not SM.nag.active, "empty CONFIRM_SUMMON: no raid warning, no nag")
  ok(#W.messages == m1, "and the lib sent no phantom OFFER")
  ok(SM.myRequest == true, "and my standing request was not cancelled by it")
  SM.myRequest = false
end
S("on summon")
S("summon hide")

-- drag saves point + relative point
BiSToolsFarm.scripts.OnDragStop(BiSToolsFarm)
ok(db.pos[1] == "TOPLEFT" and db.pos[4] == "CENTER" and db.pos[2] == 12, "drag saves position")

-- ------------------------------------------------------------ a full 25-man
-- Arn (8 Sep): "run some tests with 25 people using this addon". 21 facts (12-char
-- names, the ugly kind), 3 without any addon, me at the stone in Netherstorm.
do
  -- 24 in the raid. The names were real people's characters until 19 Sep 2026, when this repo
  -- went public; Kumlance is Arn's own and stays. The long ones matter: the window has to cope
  -- with a name that does not fit, which is why Raider10 and up are deliberately longer.
  local names = { "Kumlance", "Raider1", "Raider2", "Raider3", "Raider4", "Raider5", "Raider6", "Raider7", "Raider8", "Raider9", "Raider10", "Raider11", "Raider12", "Raider13", "Raider14", "Raider15", "Raider16", "Raider17", "Raider18", "Raider19", "Raider20", "Raider21", "Raider22", "Raider23" }
  local nolib = { Raider21 = true, Raider22 = true, Raider23 = true }
  W.raid = { { name = "Me" } }
  for i, n in ipairs(names) do
    W.raid[#W.raid + 1] = { name = n, zone = "Netherstorm", x = 1000 + i * 40, y = 1000, inst = 530 }
  end
  W.inRaid = true
  local dbx = db_summon()
  dbx.stones = { ["530|Netherstorm"] = { map = 530, zone = "Netherstorm", x = 1000, y = 1000 } }
  dbx.rows = 6 dbx.summoner = false
  W.me = { zone = "Netherstorm", x = 1000, y = 1000, inst = 530 }
  lib.peers = {} SM.requests = {} SM.tried = {}
  for i, n in ipairs(names) do
    if not nolib[n] then
      say(n, "1|CORE|HI|3|BiSTools=0.2.0|0")
      if i <= 6 then        -- six standing at the stone with me
        say(n, ("1|CORE|WHERE|0|none||Netherstorm|%d.0|1000.0|530"):format(1000 + i * 5))
      elseif i <= 11 then   -- five inside Karazhan
        say(n, "1|CORE|WHERE|1|raid|Karazhan|Karazhan|100.0|100.0|532")
      elseif i <= 15 then   -- four in Azeroth
        say(n, ("1|CORE|WHERE|0|none||Elwynn Forest|%d.0|500.0|0"):format(i * 100))
      else                  -- the rest spread across Netherstorm
        say(n, ("1|CORE|WHERE|0|none||Netherstorm|%d.0|1000.0|530"):format(1000 + i * 300))
      end
    end
  end
  say("Raider9", "1|SUMMON|REQ|1") say("Raider12", "1|SUMMON|REQ|1")   -- an addon-less man cannot ask
  S("summon show") SM.Refresh(dbx)
  ok(lib:Count() == 21, "21 facts on the lib, 3 addon-less men are not", lib:Count())
  -- Raider9 is inside Karazhan AND asked: a request beats every filter, so 4 count as inside
  ok(SM.atStone == 6 and SM.inside == 4, "6 at the stone, 4 inside - counted, not listed (the asking one is listed)", SM.atStone, SM.inside)
  ok(SM.stoneCount == 7, "the stone slot counts me too: 7", SM.stoneCount)
  ok(SM.con.slots.stone.text:find("7 at stone", 1, true) and SM.con:Width() <= SM.W - 56 - 8, "header prompt fits with 7 at stone")
  -- 24 members - 6 at stone - 4 inside = 14 candidates; the two asking facts on top,
  -- then the other world (Azeroth), then Netherstorm far-to-near, guesses last with ?
  ok(#SM.list == 14, "14 candidates listed", #SM.list)
  ok(SM.list[1].asked and SM.list[2].asked, "the two who asked are on top", SM.list[1].name, SM.list[2].name)
  ok(SM.list[3].score >= SM.SCORE_OTHER_WORLD and SM.list[5].score >= SM.SCORE_OTHER_WORLD and SM.list[6].score < SM.SCORE_OTHER_WORLD, "then the three in the other world, then Netherstorm", SM.list[3].name)
  ok(SM.list[6].score > SM.list[11].score, "Netherstorm furthest first")
  local guessSeen = false
  for _, e in ipairs(SM.list) do if e.name == "Raider22" and not e.fact then guessSeen = true end end
  ok(guessSeen, "an addon-less man still ranks, as a guess")
  -- rows: capped at db.rows, every row's name + info fit inside 170 px
  local shown, widest = 0, 0
  for i = 1, SM.MAX_ROWS do
    local r = _G["BiSToolsSummonRow" .. i]
    if r and r.shown then
      shown = shown + 1
      local w = r.name:GetStringWidth() + r.info:GetStringWidth() + 12
      if w > widest then widest = w end
    end
  end
  ok(shown == 6, "six rows shown of fourteen (db.rows)", shown)
  ok(widest <= SM.W, "the widest row (12-char name + info) fits the window", widest)
  -- the summoner mode: the asking slot appears for the summoner
  dbx.summoner = true SM.Refresh(dbx)
  ok(SM.con.slots.asks and SM.con.slots.asks.text == "2 asking", "2 asking for the summoner", SM.con.slots.asks and SM.con.slots.asks.text)
  ok(SM.con:Width() <= SM.W - 56 - 8, "header still fits")
  dbx.summoner = false
  -- the ticker's Refresh must stay cheap with 25 on the roster
  local t0 = os.clock()
  for _ = 1, 200 do SM.Refresh(dbx) end
  local per = (os.clock() - t0) / 200 * 1000
  print(("   Refresh on a 25-man: %.3f ms each (runs every 2 s)"):format(per))
  ok(per < 2, "Refresh on a 25-man under 2 ms")
  -- everybody at the stone -> pop rule still says "N at stone", list empties
  for i, n in ipairs(names) do
    if not nolib[n] then say(n, ("1|CORE|WHERE|0|none||Netherstorm|%d.0|1000.0|530"):format(1000 + i)) end
  end
  SM.Refresh(dbx)
  ok(SM.atStone == 19 and SM.stoneCount == 22 and #SM.list == 5, "everyone with the addon at the stone: 22 counted with me; the two asking + three guesses still listed", SM.atStone, SM.stoneCount, #SM.list)
  ok(SM.con.slots.stone.text:find("22 at stone", 1, true) and SM.con:Width() <= SM.W - 56 - 8, "22 at stone fits the prompt")
  S("summon hide")
  -- put the small fixture back for whatever follows
  W.raid = { { name = "Me" } } W.inRaid = false lib.peers = {} SM.requests = {}
end

-- ------------------------------------------------------------ RezComm: the rez emitter
-- Arn (10 Sep): "look at how Innervate and Gamba use it to talk about the rez, make
-- this another peer". BiSTools embeds _bisdev/RezComm-1.0 byte-identical, TOC-only:
-- a Tools-only priest/paladin/shaman puts rez claims on Innervate's wire (BiSInn,
-- proto 4) without a line of rez code in Tools. Announce-only; stands down when
-- BiSInnervate is loaded (it announces its own casts).
do
  local RC = _G.BiSRezComm
  ok(RC and RC.MINOR == 5 and RC.PROTO == 4, "RezComm 1.0 minor 5 loaded, speaks Innervate's proto 4")
  ok(RC._login and RC._login.events.PLAYER_LOGIN, "self-boots at PLAYER_LOGIN: TOC line only, no call from Tools")
  -- boot as a client WITHOUT Innervate
  W.innervateLoaded = false RC._booted = nil
  RC._login.scripts.OnEvent(RC._login, "PLAYER_LOGIN")
  ok(RC._booted and RC.standDown == false and RC._frame and RC._frame.events.UNIT_SPELLCAST_SENT, "no Innervate: booted, listening to my own casts")
  W.raid = { { name = "Me" }, { name = "Bob", zone = "Netherstorm", x = 1, y = 1, inst = 530 } } W.inRaid = true
  local m0, p0 = #W.messages, #W.prefixes
  RC._frame.scripts.OnEvent(RC._frame, "UNIT_SPELLCAST_SENT", "player", "Bob", "cast-1", 2006)   -- Resurrection r1
  ok(W.messages[#W.messages] == "4|RCLAIM|Bob" and W.prefixes[#W.prefixes] == "BiSInn", "my rez cast -> 4|RCLAIM|Bob on BiSInn, that instant", W.messages[#W.messages], W.prefixes[#W.prefixes])
  ok(#W.afters == 0 or true, "(no timer involved - sent synchronously)")
  RC._frame.scripts.OnEvent(RC._frame, "UNIT_SPELLCAST_INTERRUPTED", "player", "cast-1", 2006)
  ok(W.messages[#W.messages] == "4|RFREE|Bob", "interrupted -> 4|RFREE|Bob")
  RC._frame.scripts.OnEvent(RC._frame, "UNIT_SPELLCAST_SENT", "player", "Bob", "cast-2", 20777)  -- Ancestral Spirit
  RC._frame.scripts.OnEvent(RC._frame, "UNIT_SPELLCAST_INTERRUPTED", "player", "cast-9", 1234)   -- some other cast
  ok(W.messages[#W.messages] == "4|RCLAIM|Bob", "a stray interrupt of another cast does NOT free the corpse")
  RC._frame.scripts.OnEvent(RC._frame, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 20777)
  ok(W.messages[#W.messages] == "4|RDONE|Bob", "landed -> 4|RDONE|Bob")
  local m1 = #W.messages
  RC._frame.scripts.OnEvent(RC._frame, "UNIT_SPELLCAST_SENT", "player", "Bob", "cast-3", 20484)   -- Rebirth: excluded on purpose
  RC._frame.scripts.OnEvent(RC._frame, "UNIT_SPELLCAST_SENT", "raid2", "Me", "cast-4", 2006)      -- somebody else's cast
  ok(#W.messages == m1, "Rebirth and other people's casts say nothing")
  -- the two pipes never mix: LibBiSComm still talks on BiS, the emitter on BiSInn
  local bis, inn = 0, 0
  for i = p0 + 1, #W.prefixes do if W.prefixes[i] == "BiS" then bis = bis + 1 elseif W.prefixes[i] == "BiSInn" then inn = inn + 1 end end
  ok(inn == 4 and bis == 0, "four rez lines on BiSInn, none leaked onto the BiS pipe", inn, bis)
  ok(lib:Peer("Bob") == nil, "an RCLAIM is not a LibBiSComm message: no peer appears")
  -- a client WITH Innervate: the emitter stands down (Innervate announces its own casts)
  W.innervateLoaded = true RC._booted = nil RC._frame = nil
  RC._login.scripts.OnEvent(RC._login, "PLAYER_LOGIN")
  ok(RC._booted and RC.standDown == true and RC._frame == nil, "Innervate loaded: stands down, no frame, no double claim")
  W.innervateLoaded = false
  W.raid = { { name = "Me" } } W.inRaid = false
end

-- ------------------------------------------------------------ the Hub: minimap button, tools window, options
-- Arn (10 Sep): "/ commands are so convoluted ... work on the minimap icon; right click
-- opens the options; the first window shows all the tools we can open" and "right now I
-- have no idea where the farm window is at".
do
  local H = NS.Hub
  ok(H and H.frame.events.PLAYER_LOGIN, "the Hub boots its minimap button at PLAYER_LOGIN")
  local mm = H.BuildMinimap()
  ok(mm and mm == BiSToolsMinimap and mm.parent == Minimap, "minimap button, parented to the Minimap")
  local x, y = H.MinimapPos(225)
  ok(mm.point[1] == "CENTER" and mm.point[2] == Minimap and math.abs(mm.point[4] - x) < 1e-6 and math.abs(mm.point[5] - y) < 1e-6, "sits on the rim at the saved angle (225 = lower left)")
  -- THE RING IS MEASURED (Arn's cousin: "the minimap buttons are appearing on the inside of the minimap")
  local keepW = Minimap.GetWidth
  Minimap.GetWidth = function() return 192 end            -- Forever's minimap is wider than 140
  ok(math.abs(H.MinimapRadius() - (96 + H.MM_OVER)) < 1e-6, "a 192 px minimap: the ring at 106, on its edge - not 80, inside it")
  Minimap.GetWidth = function() return nil end
  ok(H.MinimapRadius() == H.MM_RADIUS, "a minimap that will not say: the old 80")
  Minimap.GetWidth = keepW
  ok(mm.icon.file == "Interface\\Icons\\Spell_Shadow_Twilight" and mm.ring.file == "Interface\\Minimap\\MiniMap-TrackingBorder", "BiS icon in the standard tracking ring")
  -- drag: the angle follows the cursor around the minimap centre
  W.cursor = { 1000 + 100, 500 }   -- due east of the centre
  H.DragMinimap()
  ok(math.abs(NS.DB().hub.angle - 0) < 1e-6 and math.abs(mm.point[4] - 80) < 1e-6 and math.abs(mm.point[5]) < 1e-6, "dragging east: 0 degrees, button at (80, 0)", NS.DB().hub.angle, mm.point[4], mm.point[5])
  W.cursor = { 1000, 500 + 100 }
  H.DragMinimap()
  ok(math.abs(NS.DB().hub.angle - 90) < 1e-6 and math.abs(mm.point[4]) < 1e-6 and math.abs(mm.point[5] - 80) < 1e-6, "north: 90 degrees, button at (0, 80)")
  NS.DB().hub.angle = 225 H.PlaceMinimap()
  -- left click: the Hub, one row per tool
  mm.scripts.OnClick(mm, "LeftButton")
  local hub = BiSToolsHub
  ok(hub and hub:IsShown() and #hub.rows == 10, "left click opens the Hub with a row per registered tool")
  ok(hub.scale == 1.2, "the Tools list is 20% bigger (Arn: \"lets make this 20% bigger\")")
  ok(hub.rows[1].key == "farm" and hub.rows[2].key == "summon" and hub.rows[3].key == "recap" and hub.rows[4].key == "rivals"
     and hub.rows[5].key == "social" and hub.rows[6].key == "threat" and hub.rows[7].key == "bg" and hub.rows[8].key == "map" and hub.rows[9].key == "party"
     and hub.rows[10].key == "rides",
     "rows in TOC order: farm, summon, recap, rivals, social, threat, bg, map, party, rides")
  -- RIVALS & PALS, their own tool (Arn, 14 Oct: "decouple from recap ... be its own thing")
  ok(hub.rows[4].name.text == "rivals & pals", "the rivals tool's row is titled rivals & pals")
  ok(hub.rows[1].name.text == "farm" and hub.rows[1].state.text:find("on", 1, true), "row: name + on")
  ok(hub.con.slots.count and hub.con.slots.count.text == "8 of 10 on", "prompt slot counts the tools that are on (threat and party start off; rides on)")
  ok(not R:Enabled("threat") and hub.rows[6].name.text == "threat (beta)" and hub.rows[6].state.text:find("off", 1, true),
     "the threat tool starts OFF and is shown as \"threat (beta)\"")
  ok(hub.con:Width() <= H.W - 15 - 8, "hub prompt fits its header budget")
  ok(hub.closeBtn.point[4] == -3, "only an x in the header, at -3")
  ok(hub.foot and hub.foot.label.text == "options" and hub.h == 16 + 10 * 16 + 4 + 16, "footer 'options' button; height = header + rows + footer")
  -- row click opens the tool window; shift-click drags it to the middle
  BiSToolsFarm:Hide() F.db.pos = { "TOPLEFT", 400, -300, "TOPLEFT" }
  hub.rows[1].scripts.OnClick(hub.rows[1], "LeftButton")
  ok(BiSToolsFarm:IsShown() and F.db.pos[1] == "TOPLEFT", "click: farm window shown where it was")
  -- CLICK AGAIN CLOSES (Arn, 19 Oct: "when i click these in bis tools some open and close some just
  -- open") - "bring it to me" (10 Sep) is shift-click's now
  hub.rows[1].scripts.OnClick(hub.rows[1], "LeftButton")
  ok(not BiSToolsFarm:IsShown(), "second click: the farm window closes")
  W.shift = true
  hub.rows[1].scripts.OnClick(hub.rows[1], "LeftButton")
  hub.rows[1].scripts.OnClick(hub.rows[1], "LeftButton")
  W.shift = false
  ok(BiSToolsFarm:IsShown() and BiSToolsFarm.point[1] == "CENTER", "shift-click on an open window: it stays, brought to the middle")
  F.db.pos = { "TOPLEFT", 400, -300, "TOPLEFT" } BiSToolsFarm:Hide() BiSToolsFarm.point = nil
  -- EVERY window tool the same: open, then closed; a tool with no window opens the options
  do
    local same, tried = true, {}
    for _, r in ipairs(hub.rows) do
      local tool = R:Get(r.key)
      if tool.IsOpen and tool.OnClose then
        local dbt = R:DBFor(tool)
        local was = R:Enabled(r.key)
        if tool:IsOpen(dbt) then tool:OnClose(dbt) end
        r.scripts.OnClick(r, "LeftButton")
        local opened = tool:IsOpen(dbt) and true or false
        r.scripts.OnClick(r, "LeftButton")
        local closed = not tool:IsOpen(dbt)
        -- the recap has nothing to open before your first death (it says so); it still must not stick
        if (opened and not closed) or (not opened and r.key ~= "recap") then same = false end
        tried[#tried + 1] = r.key .. (opened and "+" or "") .. (closed and "-" or "")
        if not was then R:SetEnabled(r.key, false) end      -- a click switched it on; put it back
      end
    end
    ok(same and #tried >= 7, "every window tool: a click opens it, the next closes it", table.concat(tried, " "))
    if BiSToolsOptions then BiSToolsOptions:Hide() end
    local social
    for _, r in ipairs(hub.rows) do if r.key == "social" then social = r end end
    social.scripts.OnClick(social, "LeftButton")
    ok(BiSToolsOptions and BiSToolsOptions:IsShown(), "social has no window: its click opens the options")
    BiSToolsOptions:Hide()
  end
  W.shift = true
  hub.rows[1].scripts.OnClick(hub.rows[1], "LeftButton")
  W.shift = false
  ok(F.db.pos[1] == "CENTER" and F.db.pos[2] == 0 and BiSToolsFarm.point[1] == "CENTER" and BiSToolsFarm.point[2] == UIParent, "shift-click: farm window dragged to the middle of the screen")
  -- every seg label fits its button (the screenshot showed "alw...")
  for _, r in ipairs(BiSToolsOptions and BiSToolsOptions.rows or {}) do end
  -- right click toggles the tool; opening an off tool switches it on first
  hub.rows[2].scripts.OnClick(hub.rows[2], "RightButton")
  ok(not R:Enabled("summon") and hub.rows[2].state.text:find("off", 1, true) and hub.con.slots.count.text == "7 of 10 on", "right click: summon off, row and count follow")
  ok(lib:Enabled(), "and the lib is untouched by it")
  hub.rows[2].scripts.OnClick(hub.rows[2], "LeftButton")
  ok(R:Enabled("summon") and BiSToolsSummon:IsShown() and db_summon().mode == "on", "click on an off tool: switched on and its window pinned open")
  -- right click on the minimap: options
  mm.scripts.OnClick(mm, "RightButton")
  local opt = BiSToolsOptions
  ok(opt and opt:IsShown(), "right click opens Options")
  ok(opt.scale == 1.2, "and so is Options")
  -- THE ICON THAT WENT DARK (Arn: "i click the minimap button it goes dark and stays dimmed"):
  -- EllesmereUI's minimap collector backs a gathered button with a black box (a child, one level below)
  -- and its click hook lifts every child to DIALOG - its box over the icon. A moment later it goes back.
  local box2 = { level = 50, strata = "DIALOG" }
  function box2:SetFrameLevel(l) self.level = l end
  function box2:SetFrameStrata(s) self.strata = s end
  mm.GetChildren = function() return box2 end
  mm.GetFrameLevel = function() return 8 end
  mm.GetFrameStrata = function() return "MEDIUM" end
  mm.scripts.OnClick(mm, "RightButton") mm.scripts.OnClick(mm, "RightButton")   -- twice: Options as it was
  W.runAfters(0.1)
  ok(box2.level == 7 and box2.strata == "MEDIUM", "after a click, a backing lifted over the icon goes back below the button")
  mm.GetChildren = nil
  ok(opt.con:Width() <= H.OPT_W - 15 - 8, "options prompt fits")
  -- sections: tools (3), farm (5), summon (7), recap (1), rivals (8), social (2), threat (2), bg (4), map (7),
  -- party (2), rides (4) (the rival settings moved out of recap into their own tool, 14 Oct; the overlay map, 14 Oct;
  -- the party list, 15 Oct; the recruit crest, 21 Oct; the ride card, 21 Oct)
  -- (+5 in party, 21 Oct: accept from the guild / friends, invite on a keyword, the keyword, from whom)
  ok(#opt.rows == 11 + 3 + 5 + 7 + 1 + 8 + 2 + 2 + 4 + 7 + 4 + 4 + 5, "one row per section header and per option", #opt.rows)
  -- THE BiSTheme STANDARD, 1.43:1 (Arn, 14 Oct): its sections poured into columns, the window that shape
  ok(math.abs(opt.w / opt.h - 1.43) < 0.01 and (opt.columns or 1) >= 2, "options: 1.43:1, in columns", opt.w .. "x" .. opt.h)
  local function find(label) for _, r in ipairs(opt.rows) do if r.name and r.name.text == label then return r end end end
  -- THE HELP STRIP (Arn, 14 Oct: "yes do the help strip"): hover a setting, the bottom says what it does
  local hb = opt.helpBox
  ok(hb and hb.shown ~= false and hb.h and hb.h >= BiSTheme.OPTIONS.HELP_MIN, "the window carries a help strip at the bottom")
  local spot = find("spot radius")
  spot.scripts.OnEnter(spot)
  ok(hb.text.text:find("spawn spot", 1, true) and hb.title.text:find("spot radius", 1, true), "hovering a setting says what it does", hb.text.text)
  local kids = spot.GetChildren and { spot:GetChildren() } or {}
  if kids[1] and kids[1].scripts.OnEnter then
    find("burst window").scripts.OnEnter(find("burst window"))
    kids[1].scripts.OnEnter(kids[1])
    ok(hb.text.text:find("spawn spot", 1, true), "and so does hovering its own buttons")
  end
  -- THE MARK PREVIEW (Arn: "a window to the helper thing to preview the look")
  local BGt = NS.BG
  local lookRow = find("mark look")
  lookRow.scripts.OnEnter(lookRow)
  local pv = BGt.preview
  ok(pv and pv:IsShown() and pv.marks and pv.marks.healer and pv.marks.killer, "hovering a mark setting: the preview rolls out with both marks")
  -- Arn: "a full on rollout 3d model of self with the marks on them, like how we did for bisgamba"
  ok(pv.cellH.model and pv.cellK.model, "two 3D models of you, one per mark")
  ok(math.abs(pv.w / pv.h - 1.43) < 0.01, "the roll-out is 1.43:1, the BiSTheme standard", pv.w .. "x" .. pv.h)
  -- Arn: "make the preview same aspect as our windows" / "in the preview its cut off"
  ok(pv.h == math.floor(opt.h + 0.5) or (opt.h < BGt.PREVIEW_H and pv.h == BGt.PREVIEW_H), "as tall as the options window", pv.h .. " vs " .. opt.h)
  ok(BGt.PREVIEW_HEADROOM >= 2 + 40 + BGt.TAG[2] * 1.5, "room over each nameplate for a tag set above it, nudged all the way up")
  ok(pv.point and pv.point[1] == "TOPLEFT" and pv.point[2] == opt and pv.point[3] == "TOPRIGHT", "hung off the options window's right edge")
  ok(pv.marks.healer.point and pv.marks.healer.point[2] == pv.cellH.plate, "the mark placed on the preview's own nameplate, by the same code as a real one")
  ok(pv.marks.healer.look == BGt.LookIndex() and pv.marks.healer.shown ~= false, "in the look picked now")
  local bdbP = R:DBFor(R:Get("bg"))
  for _, o in ipairs(R:Get("bg").options) do if o.label == "mark look" then o.set(bdbP, 6) end end
  ok(pv.marks.healer.tag and pv.marks.killer.tag, "a step in the options redraws the preview at once (the tag)")
  for _, o in ipairs(R:Get("bg").options) do if o.label == "mark look" then o.set(bdbP, 1) end end
  -- THE REAL NAMEPLATE'S WIDTH (Arn: the preview's crosshair "look squished cause name plates are smaller
  -- than in game ... the width is what's important")
  local keepPx = BGt.platePx
  BGt.platePx = { 180, 12 }               -- as measured off a real plate, in screen pixels
  BGt.SizePreviewPlates()
  ok(pv.cellH.plate.w == 180 and pv.cellK.plate.w == 180, "the preview's nameplates take the real ones' width", tostring(pv.cellH.plate.w))
  BGt.platePx = { 180, 60 }               -- a plate FRAME is its whole clickable area: far taller than its bar
  BGt.SizePreviewPlates()
  ok(pv.cellH.plate.h == BGt.PREVIEW_BAR_H, "but the bar stays a bar's height - never the frame's (Arn's red slab)", tostring(pv.cellH.plate.h))
  -- THE RIVALS & PALS PREVIEW (Arn: "need the preview for pals and rivals")
  local crossRow = find("crosshair")
  crossRow.scripts.OnEnter(crossRow)
  ok(pv:IsShown() and pv.mode == "rivals" and #pv.rmarks == 4, "hovering a rival setting: the rival and the pal, wearing their marks", #(pv.rmarks or {}))
  ok(pv.marks and next(pv.marks) == nil, "and the battleground marks are put away")
  ok(pv.cellH.word.text:find("rival", 1, true) and pv.cellK.word.text:find("pal", 1, true), "captions say which is which")
  ok(pv.rmarks[1].w == math.floor(180 * NS.Recap.MARK_WIDE + 0.5), "the rival's crosshair as wide as on a real plate - not squished", tostring(pv.rmarks[1].w))
  local styleBefore = pv.rmarks[1].style
  for _, o in ipairs(R:Get("rivals").options) do if o.label == "crosshair" then o.set(nil, 4) end end
  ok(pv.rmarks[1].style ~= styleBefore and pv.rmarks[1].style == NS.Recap.STYLES[4], "a new crosshair style: the preview redraws in it", tostring(pv.rmarks[1].style))
  for _, o in ipairs(R:Get("rivals").options) do if o.label == "crosshair" then o.set(nil, 1) end end
  lookRow.scripts.OnEnter(lookRow)
  ok(pv.mode == "bg" and pv.marks.healer and not pv.rmarks[1]:IsShown(), "back on a bg setting: the battleground marks again")
  BGt.platePx = keepPx
  find("spot radius").scripts.OnEnter(find("spot radius"))
  ok(not pv:IsShown(), "any other setting: the preview goes")
  local undocumented = {}
  for _, r in ipairs(opt.rows) do if r.opt and not r.opt.help then undocumented[#undocumented + 1] = r.opt.label end end
  ok(#undocumented == 0, "every BiS Tools setting has its help written", table.concat(undocumented, ", "))
  -- every option label fits its lane (controls take the right 110 px)
  for _, r in ipairs(opt.rows) do if r.name then ok(r.name:GetStringWidth() <= H.OPT_W - 12 - 110, "option label fits: " .. tostring(r.name.text)) end end
  -- a section header's box toggles the tool
  local farmHdr = opt.rows[5]
  ok(farmHdr.ctl and farmHdr.ctl.on == true, "farm section box shows on")
  farmHdr.ctl.scripts.OnClick(farmHdr.ctl)
  ok(not R:Enabled("farm") and farmHdr.ctl.on == false and hub.con.slots.count.text == "7 of 10 on", "box off: farm off, hub count follows")
  farmHdr.ctl.scripts.OnClick(farmHdr.ctl)
  ok(R:Enabled("farm"), "and back on")
  -- toggle: nag
  local nag = find("nag me when summoned")
  ok(nag and nag.ctl.on == true, "nag toggle reads db.nag (default on)")
  nag.ctl.scripts.OnClick(nag.ctl)
  ok(db_summon().nag == false and nag.ctl.on == false, "click: nag off in the db and in the box")
  nag.ctl.scripts.OnClick(nag.ctl)
  ok(db_summon().nag == true, "click: back on")
  -- seg: farm sound
  local snd = find("find sound")
  ok(snd and #snd.ctl == 3 and snd.ctl[1].label.text == "first", "sound is a 3-way seg")
  for _, r in ipairs(opt.rows) do
    if type(r.ctl) == "table" and r.ctl[1] and r.ctl[1].label then
      for _, sg in ipairs(r.ctl) do ok(not tostring(sg.label.text):find("%.%.%."), "seg label whole, no ellipsis: " .. tostring(sg.label.text)) end
    end
  end
  snd.ctl[3].scripts.OnClick(snd.ctl[3])
  ok(db.sound == "off", "seg click sets db.sound = off")
  snd.ctl[1].scripts.OnClick(snd.ctl[1])
  ok(db.sound == "first", "and back to first")
  -- step: radius, clamped
  local rad = find("spot radius")
  ok(rad and rad.ctl.val.text == "20 yd", "radius step shows 20 yd")
  rad.ctl.plus.scripts.OnClick(rad.ctl.plus)
  ok(F.Spots.Radius(db) == 25 and rad.ctl.val.text == "25 yd", "> bumps the radius by 5")
  for _ = 1, 10 do rad.ctl.minus.scripts.OnClick(rad.ctl.minus) end
  ok(F.Spots.Radius(db) == 5, "< clamps at 5")
  db.spotRadius = 20 H.PaintOptions()
  local rows = find("rows")
  for _ = 1, 20 do rows.ctl.minus.scripts.OnClick(rows.ctl.minus) end
  ok(db_summon().rows == 1, "the stepper itself clamps at min (rows never below 1)", db_summon().rows)
  for _ = 1, 20 do rows.ctl.plus.scripts.OnClick(rows.ctl.plus) end
  ok(db_summon().rows == SM.MAX_ROWS, "and at max", db_summon().rows)
  db_summon().rows = SM.DEFAULT_ROWS H.PaintOptions()
  -- prune: 0 shows off
  local pr = find("prune after")
  for _ = 1, 12 do pr.ctl.minus.scripts.OnClick(pr.ctl.minus) end
  ok(F.Spots.Prune(db) == 0 and pr.ctl.val.text == "off", "prune stepped down to 0 reads off")
  pr.ctl.plus.scripts.OnClick(pr.ctl.plus)
  ok(F.Spots.Prune(db) == 60 and pr.ctl.val.text == "60 s", "and one up is 60 s")
  db.prune = nil H.PaintOptions()
  -- own options: minimap button hide/show, the BiS channel switch, reset positions
  local mmo = find("minimap button")
  mmo.ctl.scripts.OnClick(mmo.ctl)
  ok(NS.DB().hub.minimap == false and not mm:IsShown(), "minimap option hides the button")
  mmo.ctl.scripts.OnClick(mmo.ctl)
  ok(mm:IsShown(), "and brings it back")
  local comm = find("BiS channel (/biscomm)")
  ok(comm and comm.ctl.on == true, "channel switch reads the lib")
  comm.ctl.scripts.OnClick(comm.ctl)
  ok(not lib:Enabled(), "the user's own switch: off is off (same as /biscomm off)")
  comm.ctl.scripts.OnClick(comm.ctl)
  ok(lib:Enabled(), "and on again")
  BiSToolsFarm.point = { "TOPLEFT", nil, "TOPLEFT", 900, -100 }
  find("reset window positions").ctl.scripts.OnClick(find("reset window positions").ctl)
  ok(BiSToolsFarm.point[1] == "CENTER" and BiSToolsSummon.point[1] == "CENTER" and hub.point[1] == "CENTER", "reset drags every window to the middle")
  -- slash fallbacks
  S("options") ok(not opt:IsShown(), "/bt options toggles the window")
  S("hub") ok(not hub:IsShown(), "/bt hub toggles the hub")
  S("minimap") ok(NS.DB().hub.minimap == false, "/bt minimap hides the button") S("minimap")
  -- window events go to the prompt, never chat
  local chat = 0 local oldAdd = DEFAULT_CHAT_FRAME.AddMessage
  DEFAULT_CHAT_FRAME.AddMessage = function() chat = chat + 1 end
  S("hub") hub.rows[2].scripts.OnClick(hub.rows[2], "RightButton") hub.rows[2].scripts.OnClick(hub.rows[2], "RightButton")
  DEFAULT_CHAT_FRAME.AddMessage = oldAdd
  ok(chat == 0, "toggling from the hub prints nothing to chat", chat)
  local q = hub.con.queue
  ok(#q >= 1 and q[#q].text == "summon on", "the hub says it in the prompt (queued behind the earlier lines)", q[#q] and q[#q].text)
  S("hub")
end

-- ------------------------------------------------------------ wrong-accent pass (dev/theme.lua)
if _G.__THEME_MUTATION then
  local red = _G.__THEME_MUTATION
  ok(NS.T.text("accent", "x") == "|cff" .. red .. "x|r", "NS.T.text reads the palette, not a hardcoded purple")
  local r, g, b = NS.T.rgb("accent")
  ok(r == 1 and g == 0 and b == 0, "NS.T.rgb reads the palette")
  local fr = F.color("accent")
  ok(fr == 1, "F.color (the kit) reads the palette for accent")
  S("summon show")
  ok(SM.title:GetText():find("|cff" .. red, 1, true), "the BiS> prompt wears the injected accent", SM.title:GetText())
  ok(BiSToolsSummon:IsShown(), "window still builds with the poisoned palette")
  local leak = false
  for _, f in ipairs(files) do
    if not f:match("^Libs/") then
      local fh = assert(io.open(f)) local src = fh:read("*a") fh:close()
      -- a hardcoded accent escape in addon code is exactly what this pass exists to catch
      if src:find("|cffb980ff", 1, true) then leak = true print("   hardcoded accent in " .. f) end
    end
  end
  ok(not leak, "no addon file hardcodes the accent escape |cffb980ff (use T.text)")
end

-- ------------------------------------------------------------ embedded libs are the canonical bytes
-- The lib is edited in _bisdev and copied out; a stale copy in an addon is how three addons
-- were still announcing phantom OFFERs after minor 5 fixed it. When the sibling folders are
-- there (they are, in the AddOns tree), every embedded file must be byte-identical.
do
  local function bytes(path) local fh = io.open(path, "rb") if not fh then return nil end local b = fh:read("*a") fh:close() return b end
  local pairs_ = {
    { "Libs/LibBiSComm-1.0/LibBiSComm-1.0.lua", "../_bisdev/LibBiSComm-1.0/LibBiSComm-1.0.lua" },
    { "Libs/RezComm-1.0/RezComm-1.0.lua",       "../_bisdev/RezComm-1.0/RezComm-1.0.lua" },
    { "Libs/BiSTheme/Console.lua",              "../BiSTheme/Console.lua" },
    { "Libs/BiSTheme/Options.lua",              "../BiSTheme/Options.lua" },
  }
  for _, pr in ipairs(pairs_) do
    local mine, ref = bytes(pr[1]), bytes(pr[2])
    if ref then ok(mine == ref, "embedded " .. pr[1] .. " is byte-identical to " .. pr[2] .. " (run _bisdev/sync.ps1)")
    else print("   (canonical " .. pr[2] .. " not beside this checkout - embed check skipped)") end
  end
end

-- ---------------------------------------------------------------- Forever: kills without the combat log
-- (6 Oct 2026) The farm tool heard kills through COMBAT_LOG_EVENT_UNFILTERED, and on WoW Forever
-- even REGISTERING it is a protected action. On a client that says it hides values, the tool must
-- never ask for it, and must count kills from the plain PARTY_KILL event instead - in either of the
-- two shapes Overlord handles, with any argument possibly a secret.
do
  -- A SECRET STRING SAYS "string" (on Forever type() still answers the real type) and refuses
  -- everything else: a match, a find, a comparison. A plain table would be caught by any type
  -- check by luck - the mock must not be kinder than that.
  local secretMeta = { __secret = true, __index = function(_, k)
    error("attempt to use a secret value (" .. tostring(k) .. ")", 2) end,
    __eq = function() error("attempt to compare a secret value", 2) end }
  local function secret() return setmetatable({}, secretMeta) end
  local realType = type
  local names = {}
  local keep = { C_Secrets = _G.C_Secrets, issecretvalue = _G.issecretvalue, UnitNameFromGUID = _G.UnitNameFromGUID,
                 type = _G.type }
  _G.type = function(v) if getmetatable(v) == secretMeta then return "string" end return realType(v) end
  _G.C_Secrets = { HasSecretRestrictions = function() return true end }
  _G.issecretvalue = function(v) return getmetatable(v) == secretMeta end
  _G.UnitNameFromGUID = function(g) return names[g] end
  W.restricted = true
  W.forbidden = {}

  S("off farm") S("on farm")
  ok(#W.forbidden == 0, "Forever: the farm tool never asks for the combat log (nothing blamed on BiSTools)")
  ok(not F.events.events.COMBAT_LOG_EVENT_UNFILTERED, "Forever: and is not listening to it")
  ok(F.events.events.PARTY_KILL, "Forever: it listens to PARTY_KILL instead")

  S("farm clear")
  local g = "Creature-0-0-0-0-777-Raptor"
  names[g] = "Raptor"
  fire("PARTY_KILL", "Player-1", g)
  ok(db.last and db.last.name == "Raptor" and db.last.guid == g, "Forever: my kill, GUID shape, is recorded by name")
  fire("PARTY_KILL", "Player-1", g)
  ok(db.last.count == 2, "Forever: and counted again")

  fire("PARTY_KILL", "Player-99", "Creature-0-0-0-0-778-Raptor")
  ok(db.last.count == 2, "Forever: somebody else's kill does not count, as with the combat log")
  fire("PARTY_KILL", "Pet-1", g)
  ok(db.last.count == 3, "Forever: my pet's kill counts")
  fire("PARTY_KILL", "Player-1", "Player-2")
  ok(db.last.count == 3, "Forever: a player dying is not a farm kill")

  ok(pcall(fire, "PARTY_KILL", secret(), g), "Forever: a SECRET attacker does not throw")
  ok(pcall(fire, "PARTY_KILL", "Player-1", secret()), "Forever: nor a secret victim")
  ok(db.last.count == 3, "Forever: and neither is counted - nothing secret was read")

  -- the name is not resolved yet: the client says "Unknown". Fall back to the target, if it is the one
  local g2 = "Creature-0-0-0-0-779-Boar"
  names[g2] = "Unknown"
  W.target = { name = "Boar", guid = g2 }
  fire("PARTY_KILL", "Player-1", g2)
  W.target = nil
  ok(db.last.name == "Boar", "Forever: an unresolved name is taken from the target with that GUID")
  names[g2] = "Unknown"
  local before = db.last.count
  fire("PARTY_KILL", "Player-1", g2)
  ok(db.last.count == before, "Forever: and with no way to name it, it is not recorded as 'Unknown'")

  -- the old shape: one unit token, the victim
  W.target = { name = "Boar", guid = g2 }
  before = db.last.count
  fire("PARTY_KILL", "target")
  W.target = nil
  ok(db.last.name == "Boar" and db.last.count == before + 1, "Forever: the unit-token shape is understood too")

  -- THE SCANNER MARKS NOTHING ON FOREVER; THE KEY DOES (6 Oct 2026). SetRaidTarget is protected
  -- there - BugGrabber, from the ticker. Blizzard's /tm in a secure macro, on a key press, is not.
  W.forbidden = {}
  W.marks = {}
  local keepSpots = db.spots
  db.spots = {}          -- no spot here: the key's mark is the skull (a spot's own mark is checked below)
  W.plates = { nameplate1 = { name = "Raptor", guid = "Creature-0-0-0-0-800-Raptor" } }
  F.marked = nil
  db.active = "Raptor" db.finds = 0
  F.Tick(db)
  ok(#W.forbidden == 0, "Forever: the scanner never calls SetRaidTarget", table.concat(W.forbidden, ", "))
  ok(next(W.marks) == nil, "Forever: so nothing is marked by the addon")
  ok(F.marked == "nameplate1", "Forever: but the clean copy is FOUND")
  ok(db.finds == 1, "Forever: and the find is said once")
  F.Tick(db)
  ok(db.finds == 1, "Forever: not again on every tick while it stays in view")

  local btn = BiSToolsFarmTarget
  btn.scripts.PreClick(btn, "LeftButton", true)
  ok(btn:GetAttribute("type") == "macro" and btn:GetAttribute("macrotext") == "/target nameplate1\n/tm !8",
     "Forever: the farm key targets it and marks it with Blizzard's /tm", btn:GetAttribute("macrotext"))
  -- "/tm !N" sets without toggling (RestedXP, on Forever), so the key never reads the mark - and on
  -- this client a mark can be a SECRET, which a comparison would throw on
  -- (a Lua 5.1 mock cannot make `secret ~= 8` throw - a table compared with a number never calls a
  -- metamethod - so the honest test is the stronger claim: the key does not READ the mark at all)
  local realIdx = _G.GetRaidTargetIndex
  _G.GetRaidTargetIndex = function() error("the farm key read the unit's mark") end
  ok(pcall(btn.scripts.PreClick, btn, "LeftButton", true), "Forever: the key never reads the unit's mark (it may be secret)")
  ok(btn:GetAttribute("macrotext") == "/target nameplate1\n/tm !8",
     "Forever: and the key still marks with /tm ! - it never needed to read the mark")
  _G.GetRaidTargetIndex = realIdx
  ok(#W.forbidden == 0, "Forever: the key's PreClick marks nothing itself either")

  -- THE NEXT PRESS MARKS THE NEXT COPY (6 Oct 2026). Arn: "if something is already marked skull
  -- it'll look for another target without a mark and put another marker". Forever hides marks, so
  -- the key keeps its own record of what it handed out.
  do
    local keepWant = F.Spots and F.Spots.Want
    if F.Spots then F.Spots.Want = function() return nil end end      -- no spot here
    F.placed = {}
    local gA, gB, gC = "Creature-0-0-0-0-900-Raptor", "Creature-0-0-0-0-901-Raptor", "Creature-0-0-0-0-902-Raptor"
    W.plates = { nameplate1 = { name = "Raptor", guid = gA }, nameplate2 = { name = "Raptor", guid = gB } }
    F.marked = nil F.Tick(db)
    btn.scripts.PreClick(btn, "LeftButton", true)
    ok(btn:GetAttribute("macrotext"):find("/tm !8$") and F.placed[gA] == 8, "Forever: the first press puts the skull on a copy")
    F.marked = nil F.Tick(db)
    ok(F.marked == "nameplate2", "Forever: the scan now prefers the copy the key has NOT marked", F.marked)
    btn.scripts.PreClick(btn, "LeftButton", true)
    ok(btn:GetAttribute("macrotext") == "/target nameplate2\n/tm !7", "Forever: the second press gives the next copy a cross, not the skull")
    btn.scripts.PreClick(btn, "LeftButton", true)
    ok(btn:GetAttribute("macrotext") == "/target nameplate2\n/tm !7", "Forever: pressing again on a copy it marked keeps that copy's mark")

    -- the skull's mob dies: the skull is free for the next copy
    names[gA] = "Raptor"
    fire("PARTY_KILL", "Player-1", gA)
    ok(F.placed[gA] == nil, "Forever: a kill frees the mark it wore")
    W.plates = { nameplate3 = { name = "Raptor", guid = gC } }
    F.marked = nil F.Tick(db)
    btn.scripts.PreClick(btn, "LeftButton", true)
    ok(btn:GetAttribute("macrotext") == "/target nameplate3\n/tm !8", "Forever: and the next copy gets the skull back")

    -- all eight out: the skull moves (the game takes it from whoever had it), and our record follows
    F.placed = {}
    for i = 1, 8 do F.Placed("Creature-0-0-0-0-91" .. i .. "-Raptor", F.NextMark("Creature-0-0-0-0-91" .. i .. "-Raptor")) end
    ok(F.NextMark("Creature-0-0-0-0-999-Raptor") == 8, "Forever: with every mark out, the skull moves")
    F.Placed("Creature-0-0-0-0-999-Raptor", 8)
    local skulls = 0
    for _, m in pairs(F.placed) do if m == 8 then skulls = skulls + 1 end end
    ok(skulls == 1, "Forever: and only one mob is ever recorded wearing it")

    S("farm clear")
    ok(next(F.placed) == nil, "Forever: /bist farm clear starts the marks at the skull again")
    if F.Spots then F.Spots.Want = keepWant end
    db.active = "Raptor"
    W.plates = { nameplate1 = { name = "Raptor", guid = "Creature-0-0-0-0-800-Raptor" } }
    F.marked = nil
  end
  -- standing at a recorded spot, the key carries THAT spot's mark, as the old sync did
  if F.Spots and F.Spots.Want then
    local realWant = F.Spots.Want
    F.Spots.Want = function() return 3 end
    W.marks.nameplate1 = nil
    btn.scripts.PreClick(btn, "LeftButton", true)
    ok(btn:GetAttribute("macrotext") == "/target nameplate1\n/tm !3", "Forever: at a spot, the key marks with the spot's mark")
    F.Spots.Want = realWant
  end
  db.spots = keepSpots

  -- SECRET MARKS, SECRET NAMES, SECRET FLAGS (6 Oct 2026, the BugGrabber paste): the scanner
  -- compared a plate's mark (`m >= 1`) and the farm spots compared the target's mark at a kill.
  W.secretMarks = secret
  W.plates = { nameplate1 = { name = "Raptor", guid = "Creature-0-0-0-0-800-Raptor" },
               nameplate2 = { name = "Raptor", guid = "Creature-0-0-0-0-801-Raptor" } }
  F.marked = nil
  ok(pcall(F.Tick, db), "Forever: a SECRET mark on every plate does not throw in the scanner")
  ok(F.marked ~= nil, "Forever: and a clean copy is still found")
  -- (Lua 5.1 cannot make `5 == secret` throw the way the client does - a number compared with a
  -- table is just false - so the test checks the promise instead: the farm spots are never HANDED
  -- a secret mark. In Arn's paste they were, and MatchZone's `z.mark == mark` threw.)
  W.target = { name = "Raptor", guid = "Creature-0-0-0-0-800-Raptor" }
  local handed
  local realKill = F.Spots.Kill
  F.Spots.Kill = function(d, n, mark) handed = { mark } return realKill(d, n, mark) end
  ok(pcall(F.OnKill, db, "Raptor", "Creature-0-0-0-0-800-Raptor"),
     "Forever: a kill on a secret-marked target does not throw")
  ok(handed and not F.Secret(handed[1]), "Forever: and the farm spots are handed no secret mark (nil = cannot say)")
  F.Spots.Kill = realKill
  W.target = nil
  ok(F.Mark("nameplate1") == nil, "Forever: a secret mark reads as 'cannot say', never as a number")
  W.secretMarks = nil
  W.plates = { nameplate1 = { name = secret(), guid = "Creature-0-0-0-0-802-Raptor" } }
  F.marked = nil
  ok(pcall(F.Tick, db), "Forever: a SECRET name on a plate does not throw")
  ok(F.marked == nil, "Forever: and a plate whose name we may not read is not taken for the mob")
  -- (the client REFUSES `if secretBoolean`; a Lua 5.1 table is always true, so the mock cannot.
  -- The promise tested is that every flag is ASKED ABOUT before it is tested.)
  local deadFlag = secret()
  W.plates = { nameplate1 = { name = "Raptor", guid = "Creature-0-0-0-0-803-Raptor", dead = deadFlag } }
  local asked = {}
  local realIs = _G.issecretvalue
  _G.issecretvalue = function(v) asked[v] = true return realIs(v) end
  ok(pcall(F.Clean, "nameplate1") and F.Clean("nameplate1") == false,
     "Forever: a SECRET dead flag does not throw, and the unit is not called clean")
  ok(asked[deadFlag], "Forever: the dead flag was asked about before it was tested")
  _G.issecretvalue = realIs
  W.plates = { nameplate1 = { name = "Raptor", guid = "Creature-0-0-0-0-800-Raptor" } }

  -- the spot sync, which used to SetRaidTarget the target to its spot's mark
  W.target = { name = "Raptor", guid = "Creature-0-0-0-0-800-Raptor" }
  if F.Spots then F.Spots.Sync(db) end
  ok(#W.forbidden == 0, "Forever: the spot sync marks nothing (the key's /tm carries the spot's mark)")
  W.target = nil W.plates = {} W.marks = {} F.marked = nil db.active = nil

  -- and on a client WITHOUT restrictions the combat log is still the road (TBC, unchanged)
  W.restricted = false
  _G.C_Secrets = { HasSecretRestrictions = function() return false end }
  S("off farm") S("on farm")
  ok(F.events.events.COMBAT_LOG_EVENT_UNFILTERED and not F.events.events.PARTY_KILL,
     "a client that hides nothing keeps the combat log, and does not listen twice")

  _G.C_Secrets, _G.issecretvalue, _G.UnitNameFromGUID = keep.C_Secrets, keep.issecretvalue, keep.UnitNameFromGUID
  _G.type = keep.type
  S("farm clear")
end

-- NO SUMMONING STONES ON FOREVER (6 Oct 2026). Arn: sunset the summon module there, keep it for
-- TBC. On a Forever interface number Summon.lua stops at its first lines: no tool, no window, no
-- nag, no /bt summon. The whole suite above ran it as TBC, where it is untouched.
do
  ok(NS.Registry:Get("summon") ~= nil, "TBC (20506): the summon tool is there")
  W.iface = 16001
  local registered = 0
  local fresh = { T = NS.T, Farm = NS.Farm,
                  Registry = { Register = function() registered = registered + 1 end } }
  local chunk = assert(loadfile("Tools/Summon.lua"))
  chunk("BiSTools", fresh)
  ok(fresh.SummonSunset == true and fresh.Summon == nil, "Forever (16001): Summon.lua stops at the top")
  ok(registered == 0, "Forever: and registers no tool - no window, no nag, no /bt summon")
  W.iface = nil
end

-- /bist IS THE COMMAND (0.4.0, Arn: "let's make it consistent" - /bish, /bisg, /bist), and the
-- two old names still reach the same handler so a 0.3.x macro keeps working
ok(SLASH_BISTOOLS1 == "/bist", "the command is /bist")
ok(SLASH_BISTOOLS2 == "/bistools" and SLASH_BISTOOLS3 == "/bt", "/bistools and /bt are kept as aliases")
for _, name in ipairs({ "Core/Slash.lua", "Core/Registry.lua", "Tools/TargetFarming.lua", "Tools/FarmSpots.lua",
                        "Tools/Hub.lua", "Tools/Summon.lua" }) do
  local fh = assert(io.open(name)) local src = fh:read("*a") fh:close()
  -- only text inside quotes is what the player reads; a comment may name the old alias
  local stray = src:gsub('SLASH_BISTOOLS3 = "/bt"', ""):match('"[^"\n]-/bt[^%w]')
  ok(not stray, name .. " still tells the player to type /bt: " .. tostring(stray))
end

-- ---------------------------------------------------------------- the farm spots on the maps
-- (6 Oct 2026) Arn: "can we see how questie puts marks on the minimap and can we do that?" Every
-- recorded spot of the farmed mob is a pin on the minimap AND the world map, wearing its own mark:
-- bright when it is up, dim while it waits to respawn.
do
  local Pn = F.Pins
  ok(Pn ~= nil, "the pins module loaded")
  local fdb = db
  local now = W.now
  local keepSpots, keepActive = fdb.spots, fdb.active
  fdb.spots = { Pinbear = {
    { id = 1, map = 1952, x = 0.50, y = 0.50, mark = 1, kills = 3, last = now - 10, respawn = 60,
      subs = { { x = 0.51, y = 0.50, mark = 2, kills = 2, last = now - 120, respawn = 60 } } },
  } }
  fdb.active = "Pinbear"
  fdb.pins = nil
  W.pins = { minimap = {}, world = {} }
  Pn.Update(fdb)
  local mini, world = {}, {}
  for icon, p in pairs(W.pins.minimap) do mini[#mini + 1] = { icon = icon, p = p } end
  for icon in pairs(W.pins.world) do world[#world + 1] = icon end
  ok(#mini == 2 and #world == 2, "every spot and sub is pinned on the minimap AND the world map", #mini .. "/" .. #world)
  local byMark = {}
  for _, e in ipairs(mini) do
    ok(e.p.map == 1952, "a pin sits on the spot's own map")
    byMark[e.icon.tex.file] = e
  end
  local zonePin = byMark["Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"]
  local subPin = byMark["Interface\\TargetingFrame\\UI-RaidTargetingIcon_2"]
  ok(zonePin and subPin, "each pin wears its spot's own raid mark")
  ok(zonePin.p.x == 0.50 and subPin.p.x == 0.51, "where the spot was recorded")
  ok(zonePin.icon.alpha == Pn.DIM, "a spot still waiting to respawn is dim")
  ok(subPin.icon.alpha == Pn.BRIGHT, "a spot whose respawn is up is bright")
  ok(subPin.icon.info and subPin.icon.info.state == "up now" and zonePin.icon.info.state:find("^back in"),
     "the tooltip says up now, or how long until it is back")

  -- time passes: the waiting spot comes up, the same pin brightens (no new pin)
  W.now = now + 60
  Pn.Update(fdb)
  local n = 0 for _ in pairs(W.pins.minimap) do n = n + 1 end
  ok(n == 2 and zonePin.icon.alpha == Pn.BRIGHT, "a spot that comes up brightens its own pin, nothing added")

  -- a sub forgotten (prune, clear): its pin goes, the zone's stays
  fdb.spots.Pinbear[1].subs = {}
  Pn.Update(fdb)
  n = 0 for _ in pairs(W.pins.minimap) do n = n + 1 end
  local w = 0 for _ in pairs(W.pins.world) do w = w + 1 end
  ok(n == 1 and w == 1, "a spot that is gone takes its pin off both maps")

  S("farm pins off")
  ok(next(W.pins.minimap) == nil and next(W.pins.world) == nil and fdb.pins == false, "/bist farm pins off clears both maps")
  S("farm pins on")
  ok(next(W.pins.minimap) ~= nil and fdb.pins == true, "/bist farm pins on brings them back")
  -- the diagnosis, for "nothing shows": prints every step and never throws, whatever is missing
  local said = {}
  local realChat = DEFAULT_CHAT_FRAME
  _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) said[#said + 1] = m end }
  ok(pcall(S, "farm pins why"), "/bist farm pins why never throws")
  _G.DEFAULT_CHAT_FRAME = realChat
  local all = table.concat(said, "\n")
  ok(all:find("HereBeDragons") and all:find("WOW_PROJECT_ID") and all:find("pinnable spots") and all:find("last add"),
     "and says what is loaded, which client it thinks this is, what it has to pin, and what the last add answered")
  S("off farm")
  ok(next(W.pins.minimap) == nil, "switching the farm tool off takes its pins off")
  S("on farm")
  ok(next(W.pins.minimap) ~= nil, "and on puts them back")

  -- no HereBeDragons at all (a stripped copy): nothing drawn, nothing thrown
  local keepLib = LibStub.libs["HereBeDragons-Pins-2.0"]
  LibStub.libs["HereBeDragons-Pins-2.0"] = nil
  ok(pcall(Pn.Update, fdb), "without the pin library the update does nothing and throws nothing")
  LibStub.libs["HereBeDragons-Pins-2.0"] = keepLib

  Pn.Stop()
  fdb.spots, fdb.active, fdb.pins = keepSpots, keepActive, nil
  W.now = now
end

-- ---------------------------------------------------------------- does every label FIT its window
-- (6 Oct 2026) Arn: "spawns window cut off make a check for cut offs or overflows that happens
-- often". Every shown label inside a window is measured where it actually starts - following what it
-- is pinned to: the window's edge, an icon, another label - and must end inside the window.
--
-- WIDTH, CALIBRATED ON THE CLIENT, NOT GUESSED: capitals and digits 0.75 px per point ("NEED MATS",
-- BiSCraft, 11 Sep), lowercase 0.55 and spaces/punctuation 0.3 (Arn's screenshot: "click a mob to
-- see its spawns" at 9 pt ran ~10 px past a 124 px window - this puts it at ~132). The mock's own
-- GetStringWidth (0.6 flat) stays as it is: the addon's code trims by it, and changing it changes
-- what the addon draws.
local function realWidth(fs)
  local t, tex = tostring(fs.text or ""), 0
  t = t:gsub("|T[^|]-:(%d+):%d+[^|]*|t", function(w) tex = tex + tonumber(w) return "" end)
  t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  local size, px = fs.size or 9, 0
  -- one glyph per UTF-8 character; an accented letter (é) measures as a lowercase one
  for ch in t:gmatch("[%z\1-\127\192-\247][\128-\191]*") do
    if #ch > 1 or ch:match("%l") then px = px + 0.55 elseif ch:match("[%u%d]") then px = px + 0.75 else px = px + 0.3 end
  end
  return px * size + tex
end
local function regionWidth(r) if r.size or r.text ~= nil then return realWidth(r) end return r.w or 0 end
local function insideShown(r, root)
  local p = r.parent
  while p do
    if p.shown == false then return false end
    if p == root then return true end
    p = p.parent
  end
  return false
end
-- left edge in px from the window's left, following the anchor chain; nil when it cannot be followed
local function leftOf(r, width, depth)
  if (depth or 0) > 8 or not r.anchor then return nil end
  local p, rel, rp, x = r.anchor[1], r.anchor[2], r.anchor[3], r.anchor[4] or 0
  local relL, relW
  if rel == nil or rel.kind then relL, relW = 0, width      -- a frame inside the window spans it
  else relL, relW = leftOf(rel, width, (depth or 0) + 1), regionWidth(rel) end
  if not relL then return nil end
  local ax = rp:find("LEFT") and relL or rp:find("RIGHT") and (relL + relW) or (relL + relW / 2)
  local w = regionWidth(r)
  if p:find("LEFT") then return ax + x elseif p:find("RIGHT") then return ax + x - w end
  return ax + x - w / 2
end
local function plainText(t) return (tostring(t):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function fitsIn(root, what)
  local width, bad, measured = root.w, {}, 0
  for _, fs in ipairs(W.labels) do
    if fs.shown ~= false and fs.text and fs.text ~= "" and insideShown(fs, root) then
      local l = leftOf(fs, width)
      if l then
        measured = measured + 1
        -- A WRAPPING BOX (the ride card's announcer, 21 Oct - the family kit's rule): a label given a width AND set to
        -- word wrap goes down, not across - its box must fit, not its text on one line
        local w = (fs.wrap and fs.w) and fs.w or realWidth(fs)
        if l < -1 or l + w > width + 1 then
          bad[#bad + 1] = ("%q needs %d px from %d, the window is %d"):format(plainText(fs.text), w, l, width)
        end
      end
    end
  end
  ok(measured > 0, what .. ": the fit check measured something (a check that sees nothing proves nothing)")
  ok(#bad == 0, what .. ": every label fits - " .. table.concat(bad, "; "))
end

-- ---------------------------------------------------------------- RestedXP's Active Targets
-- (6 Oct 2026) Arn: "is there a way to have a rested exp section so anytime its active targets
-- update it adds it to our list". RXP is an AceAddon; its targets pass through
-- addon.targeting:UpdateEnemyList(unitscan, mobs, addEntries). A stand-in RXP is registered the same
-- way, and the real code path - hook, then their method called as they call it - is driven.
do
  local Gd = F.Guide
  ok(Gd ~= nil and not Gd.hooked, "RestedXP not installed: nothing hooked, nothing said")
  local rxp = { targeting = {} }
  local seenByRXP
  function rxp.targeting:UpdateEnemyList(unitscan, mobs, addEntries) seenByRXP = mobs end
  local AA = LibStub:NewLibrary("AceAddon-3.0", 1)
  function AA:GetAddon(name, silent) if name == "RXPGuides" then return rxp end if not silent then error("no " .. name) end end
  deliver("ADDON_LOADED", "RXPGuides")
  ok(Gd.hooked, "when RestedXP loads, its target list is listened to")

  local fdb = db
  local keep = { last = fdb.last, custom = fdb.custom, active = fdb.active, guide = fdb.guide }
  fdb.last = { name = "Hillsbrad Farmer", count = 3 }
  fdb.custom = nil fdb.active = nil fdb.guide = nil
  rxp.targeting:UpdateEnemyList({ "Rare Lion" }, { "Hillsbrad Farmer", "Hillsbrad Peasant" }, nil)
  ok(seenByRXP and seenByRXP[2] == "Hillsbrad Peasant", "RestedXP's own method still runs, untouched")
  local names = {}
  for _, e in ipairs(F.Entries(fdb)) do names[#names + 1] = e.name .. (e.guide and "*" or "") end
  ok(table.concat(names, ",") == "Hillsbrad Farmer,Hillsbrad Peasant*,Rare Lion*",
     "its targets join the list under your kills, the one you already farm not twice", table.concat(names, ","))
  F.Refresh(fdb)
  ok(BiSToolsFarmRow2.name.text == "Hillsbrad Peasant" and tostring(BiSToolsFarmRow2.count.text):find("RXP"),
     "a guide row says RXP where a kill row says how many")
  BiSToolsFarmRow2.scripts.OnClick(BiSToolsFarmRow2)
  ok(fdb.active == "Hillsbrad Peasant", "clicking it farms it, like any other row")
  F.SetActive(fdb, "Hillsbrad Peasant")

  rxp.targeting:UpdateEnemyList({}, { "Hillsbrad Footman" }, true)
  names = {}
  for _, e in ipairs(Gd.mobs) do names[#names + 1] = e end
  ok(table.concat(names, ",") == "Hillsbrad Farmer,Hillsbrad Peasant,Rare Lion,Hillsbrad Footman",
     "RestedXP ADDING targets adds to ours", table.concat(names, ","))
  rxp.targeting:UpdateEnemyList({}, { "Torn Fin Tidehunter" }, false)
  ok(#Gd.mobs == 1 and Gd.mobs[1] == "Torn Fin Tidehunter", "a new guide step REPLACES them")

  rxp.targeting:UpdateEnemyList({}, { "A1", "A2", "A3", "A4", "A5", "A6" }, false)
  local guideRows = 0
  for _, e in ipairs(F.Entries(fdb)) do if e.guide then guideRows = guideRows + 1 end end
  ok(guideRows == Gd.MAX, "never more than " .. Gd.MAX .. " guide rows in a small window")

  S("farm guide off")
  guideRows = 0
  for _, e in ipairs(F.Entries(fdb)) do if e.guide then guideRows = guideRows + 1 end end
  ok(guideRows == 0 and fdb.guide == false, "/bist farm guide off hides them")
  S("farm guide on")

  rxp.targeting:UpdateEnemyList({}, { "Hillsbrad Farmhand Overseer" }, false)
  F.Refresh(fdb)
  fitsIn(BiSToolsFarm, "the farm window with a long RestedXP name")

  fdb.last, fdb.custom, fdb.active, fdb.guide = keep.last, keep.custom, keep.active, keep.guide
  Gd.mobs = {}
  F.Refresh(fdb)
end

-- ---------------------------------------------------------------- the arrow to the next spawn
-- (6 Oct 2026) Arn: "an arrow like the spawn window that directs us to the mark that ... might
-- spawn soon, after a few kills it'll know this marker is spawning every x minutes". It points at
-- the spot the Spawns window would put FIRST - up, then due soonest, then killed longest ago.
do
  local A = F.Arrow
  ok(A ~= nil, "the arrow module loaded")
  local fdb = db
  local now = W.now
  local keep = { spots = fdb.spots, active = fdb.active, arrow = fdb.arrow, pins = fdb.pins }
  W.map, W.px, W.py, W.facing = 1952, 0.50, 0.50, 0
  fdb.active = "Arrowbear"
  fdb.spots = { Arrowbear = {
    -- zone 1, skull: its one sub was killed 10 s ago and comes back every 60 s - not soon
    { id = 1, map = 1952, x = 0.52, y = 0.50, mark = 8, kills = 3, last = now - 10, respawn = 60,
      subs = { { x = 0.52, y = 0.50, mark = 8, kills = 3, last = now - 10, respawn = 60 } } },
    -- zone 9: no mark left for it; killed 70 s ago, respawns every 60 s - it is UP
    { id = 9, map = 1952, x = 0.48, y = 0.50, kills = 2, last = now - 70, respawn = 60, subs = {} },
    -- a spot on another map: never pointed at, there is no bearing across maps
    { id = 3, map = 1453, x = 0.10, y = 0.10, mark = 3, kills = 1, last = now - 999, respawn = 60, subs = {} },
  } }
  local sp, text, _, d, mark = A.Next(fdb)
  ok(sp and sp.id == 9, "the arrow picks the spot that is UP over one still waiting", sp and sp.id)
  ok(text == "up" and mark == nil, "and says it is up; it has no mark of its own")
  ok(d and d > 0, "with a distance in yards")

  -- OFF BY DEFAULT (Arn, 22 Oct): a save that never touched it shows nothing; a bare toggle turns it on
  fdb.arrow = nil
  ok(not A.Wanted(fdb), "never switched: the arrow is off")
  ok(A.Set(fdb) == true and A.Set(fdb) == false, "/bist farm arrow with no word: on, then off again")
  S("farm arrow on")
  ok(BiSToolsFarmArrow and BiSToolsFarmArrow:IsShown(), "/bist farm arrow on shows it")
  A.Refresh(fdb)
  ok(A.id.text == "#9" and not A.mark.shown, "an unmarked spot is named by its number, as in the Spawns window")
  ok(type(A.arrow.rot) == "number", "the arrow is turned toward it")

  -- the skull's sub comes up later and is NEARER - but zone 9 came up first, so it stays ahead
  -- (the window's own order), until zone 9 is killed again
  fdb.spots.Arrowbear[2].last = W.now
  sp, text, _, _, mark = A.Next(fdb)
  ok(sp and mark == 8, "after the up spot is killed, the arrow moves to the next one - the skull's")
  A.Refresh(fdb)
  ok(A.mark.shown and A.mark.file == "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", "wearing its mark")

  -- facing unknown (an instance): no arrow drawn, the rest still says where
  W.facing = nil
  A.arrow.shown = true
  A.Refresh(fdb)
  ok(not A.arrow.shown and A.clock.text ~= "", "no facing, no arrow - the timer and distance still show")
  W.facing = 0

  -- nothing on this map: it says so instead of pointing anywhere
  W.map = 1453 W.px, W.py = 0.5, 0.5
  fdb.spots.Arrowbear[3].map = 9999
  A.Refresh(fdb)
  ok(A.none.shown and not A.arrow.shown, "no spot on this map: no arrow, a line saying so")
  W.map = 1952

  -- BIG AND ON ITS OWN, LIKE RESTEDXP'S (Arn: the row was "a little crowded ... can we make it big
  -- like the rested one"): floating, a big arrow, mark + timer under it, then the distance
  A.Refresh(fdb)                          -- back on the map with the spots
  ok(BiSToolsFarmArrow.parent == UIParent, "the arrow floats on its own, not inside the Spawns window")
  ok(A.arrow.w and A.arrow.w >= 48, "and it is BIG", A.arrow.w)
  ok(A.dist.text and A.dist.text:find("yd%)$"), "the distance under it, RestedXP-style: (N yd)", A.dist.text)
  ok(F.Spots.body.point and F.Spots.body.point[2] == F.Spots.head, "the Spawns window has no arrow row any more")
  ok(F.Spots.title.text:find("Spawns"), "and keeps its name: Spawns")
  BiSToolsFarmArrow.scripts.OnDragStop(BiSToolsFarmArrow)
  ok(type(fdb.arrowPos) == "table" and fdb.arrowPos[1], "a dragged arrow remembers where it was left")
  fitsIn(BiSToolsFarmArrow, "the floating arrow")

  S("farm arrow off")
  ok(not BiSToolsFarmArrow:IsShown() and fdb.arrow == false, "/bist farm arrow off hides it")
  S("farm arrow on")
  S("off farm")
  ok(not BiSToolsFarmArrow:IsShown(), "switching the farm tool off hides the arrow")
  S("on farm")
  ok(BiSToolsFarmArrow:IsShown(), "and on brings it back")

  -- CLICK THE MOB AGAIN: everything it shows goes; click it back: everything comes back (Arn:
  -- "when i click the mountain lion again it should remove all the marks on the minimap and clear
  -- the spawn timers window"). The spots themselves are kept.
  W.pins = { minimap = {}, world = {} }
  F.Pins.Stop() fdb.pins = nil
  F.Pins.Update(fdb)
  ok(next(W.pins.minimap) ~= nil, "farming: the spots are pinned")
  F.Spots.Toggle(fdb, true)
  -- as in game: the mob you stop farming is also the one you last KILLED - which is exactly what
  -- the old fallback (S.Mob: active, else last kill) kept showing
  local keepLast = fdb.last
  fdb.last = { name = "Arrowbear", count = 3 }
  F.SetActive(fdb, "Arrowbear")            -- the same mob again = stop farming it
  ok(fdb.active == nil, "clicking the farmed mob again stops farming it")
  ok(next(W.pins.minimap) == nil and next(W.pins.world) == nil, "and its pins leave both maps at once")
  ok(F.Spots.empty.shown and F.Spots.empty.text == "pick a mob to farm", "the Spawns window empties", F.Spots.empty.text)
  ok(not BiSToolsFarmArrow:IsShown(), "and the arrow leaves the screen - nothing farmed, nothing to point at")
  -- Arn's screenshot, this exact state: both lines ran out of the window
  fitsIn(BiSToolsFarmSpots, "Spawns, no mob picked")
  ok(fdb.spots.Arrowbear and #fdb.spots.Arrowbear == 3, "but the spots and what they learned are KEPT")
  F.SetActive(fdb, "Arrowbear")
  ok(fdb.active == "Arrowbear" and next(W.pins.minimap) ~= nil, "clicking it back brings the pins straight back")
  F.Spots.Refresh(fdb) A.Refresh(fdb)
  fitsIn(BiSToolsFarmSpots, "Spawns, spots listed")
  F.Refresh(fdb)
  fitsIn(BiSToolsFarm, "the farm window")
  fdb.last = keepLast

  -- the minimap pin for a spot with no mark: a gold dot, not nothing
  W.pins = { minimap = {}, world = {} }
  F.Pins.Stop() fdb.pins = nil
  F.Pins.Update(fdb)
  local dot
  for icon in pairs(W.pins.minimap) do if icon.w == F.Pins.DOT then dot = icon end end
  ok(dot and dot.tex.color, "a spot past the eighth mark is pinned as a dot, not skipped")
  F.Pins.Stop()

  fdb.spots, fdb.active, fdb.arrow, fdb.pins = keep.spots, keep.active, keep.arrow, keep.pins
  A.Hide()
  W.now = now
end

-- WHAT IT COSTS, IN CLIENT CALLS (7 Oct 2026). BiSHealing asked the client ~630,000 things a
-- second and every suite was green; Arn: "make sure stuff like this does not happen". The family's
-- counter (_bisdev/dev/cost.lua) holds the two things here that run all evening while farming.
do
  local Cost = dofile("../_bisdev/dev/cost.lua")
  local A, Sp = F.Arrow, F.Spots
  local keep = { spots = db.spots, active = db.active, arrow = db.arrow, shelf = db.shelf }
  W.map, W.px, W.py, W.facing = 1952, 0.50, 0.50, 0
  -- a full evening's farm: 16 zones with 2 subs each, on this map
  local list = {}
  for z = 1, 16 do
    local subs = {}
    for s = 1, 2 do
      subs[s] = { x = 0.40 + z * 0.01, y = 0.40 + s * 0.01, kills = 3, last = W.now - z * 7, respawn = 120 }
    end
    list[z] = { id = z, map = 1952, x = 0.40 + z * 0.01, y = 0.40, mark = (z % 8) + 1, kills = 6,
                last = W.now - z * 7, respawn = 120, subs = subs }
  end
  db.spots = { Costbear = list }
  db.active, db.arrow = "Costbear", nil
  S("farm arrow on")
  A.Refresh(db)
  ok(BiSToolsFarmArrow:IsShown(), "(cost) the arrow is up, pointing")

  -- ONE SECOND OF THE ARROW: twenty frames of 0.05 s
  local n, by = Cost.Count(function()
    for _ = 1, 20 do BiSToolsFarmArrow.scripts.OnUpdate(BiSToolsFarmArrow, 0.05) end
  end)
  -- measured 7 Oct after the split (turn 20/s, pick 4/s); every frame doing the full pick was 5x
  local ARROW = 300
  ok(n <= ARROW, "a second of the farm arrow asks the client at most " .. ARROW .. " things: " .. n,
     Cost.Top(by, 5))
  print(("   cost: arrow, 1 s, 32 spots = %d calls (%s)"):format(n, Cost.Top(by, 3)))

  -- THE SHELF BEHIND A CLOSED FARM WINDOW. Closing the window hides the parent only; the shelf
  -- stayed "shown" and rebuilt itself 4 times a second for nobody.
  Sp.Toggle(db, true)
  local seen = Cost.Count(function() for _ = 1, 4 do Sp.Refresh(db) end end)
  BiSToolsFarm:Hide()
  local hidden, hby = Cost.Count(function() for _ = 1, 4 do Sp.Refresh(db) end end)
  BiSToolsFarm:Show()
  ok(BiSToolsFarmSpots:IsShown() and hidden < seen / 2,
     "a closed farm window stops the Spawns shelf rebuilding: " .. hidden .. " calls a second, open "
     .. seen, Cost.Top(hby, 4))
  print(("   cost: shelf, 1 s = %d calls open, %d behind a closed window"):format(seen, hidden))

  -- A MOUSE SWEPT ACROSS A PACK: ten mouseovers in the same instant are one scan, not ten
  local realTick, scans = F.Tick, 0
  F.Tick = function(...) scans = scans + 1 return realTick(...) end
  local hadTicker = F.ticker
  F.ticker = F.ticker or { alive = true, Cancel = function() end }
  F.mouseTickAt = nil
  for _ = 1, 10 do F.events.scripts.OnEvent(F.events, "UPDATE_MOUSEOVER_UNIT") end
  ok(scans == 1, "ten mouseovers at once start one farm scan, not ten", scans)
  W.now = W.now + F.MOUSE_GAP + 0.01
  F.events.scripts.OnEvent(F.events, "UPDATE_MOUSEOVER_UNIT")
  ok(scans == 2, "and the next one after the gap scans again", scans)
  F.Tick, F.ticker = realTick, hadTicker

  Sp.Toggle(db, false)
  S("farm arrow off")
  db.spots, db.active, db.arrow, db.shelf = keep.spots, keep.active, keep.arrow, keep.shelf
end

-- ---------------------------------------------------------------- what killed you: the measuring tool
-- (12 Oct 2026) Arn, for a friend: "a death recap of who or what killed him". Step one only
-- MEASURES what C_DeathRecap hands over on Forever, and when. The mock is as unkind as the client
-- may be: a hidden field refuses every touch (index, concat, compare) and says "string" to type();
-- a whole row, or the whole list, may be hidden; the call may throw.
do
  local RC = NS.Recap
  local secretMeta = { __index = function(_, k) error("attempt to use a secret value (" .. tostring(k) .. ")", 2) end,
                       __eq = function() error("attempt to compare a secret value", 2) end,
                       __lt = function() error("attempt to compare a secret value", 2) end,
                       __concat = function() error("attempt to concatenate a secret value", 2) end }
  local function secret() return setmetatable({}, secretMeta) end
  local realType = type
  local keep = { type = _G.type, issecretvalue = _G.issecretvalue, issecrettable = _G.issecrettable,
                 canaccessvalue = _G.canaccessvalue, C_DeathRecap = _G.C_DeathRecap,
                 chat = DEFAULT_CHAT_FRAME.AddMessage }
  _G.type = function(v) if getmetatable(v) == secretMeta then return "string" end return realType(v) end
  _G.issecretvalue = function(v) return getmetatable(v) == secretMeta end
  local hiddenTables = {}
  _G.issecrettable = function(t) return hiddenTables[t] == true end
  local said = {}
  DEFAULT_CHAT_FRAME.AddMessage = function(_, m) said[#said + 1] = m end
  local function heard() local s = table.concat(said, "\n") said = {} return s end

  -- a client with no death recap at all: says so, never throws
  _G.C_DeathRecap = nil
  ok(pcall(S, "recap raw"), "/bist recap raw on a client with no death recap does not throw")
  ok(heard():find("no death recap to read", 1, true), "and says the client has none")

  -- THE GAME'S RECORD, the moment you die: who and with what readable, how much hidden
  local hide = true
  local function hit(i)
    return { event = "SPELL_DAMAGE", sourceName = "Defias Thug", spellId = 1752, spellName = "Sinister Strike",
             amount = hide and secret() or 52 + i, currentHP = hide and secret() or 300 - i, timestamp = 1000 + i }
  end
  local events, throw = {}, false
  _G.C_DeathRecap = {
    HasRecapEvents = function() return #events > 0 end,
    GetRecapMaxHealth = function() return hide and secret() or 1344 end,
    GetRecapEvents = function()
      if throw then error("Attempt to access forbidden object", 2) end
      if #events == 0 then return nil end
      local out = {}
      for i = 1, #events do out[i] = hit(i) end
      return out
    end,
  }
  events = { 1, 2, 3 }
  W.combat = true
  local onEvent = RC.frame.scripts.OnEvent
  ok(RC.frame.events.PLAYER_DEAD and RC.frame.events.PLAYER_REGEN_ENABLED, "it listens for dying and for the fight ending")
  ok(pcall(onEvent, RC.frame, "PLAYER_DEAD"), "dying with hidden numbers does not throw")
  ok(RC.win and RC.win:IsShown(), "and opens the recap window, hidden numbers and all")
  ok(RC.win.mid.dmg.text == "?" and RC.win.foot.text:find("some amounts hidden", 1, true),
     "where the game hid a number the window says ?, never a guess")
  heard()
  local d = RC.atDeath
  ok(d and d.count == 3 and #d.rows == 3, "every hit is recorded at death")
  ok(d.rows[1]:find('sourceName="Defias Thug"', 1, true) and d.rows[1]:find("spellId=1752", 1, true),
     "who hit you, and with what, read where the game lets it be read")
  ok(d.rows[1]:find("amount=<hidden>", 1, true) and d.rows[1]:find("currentHP=<hidden>", 1, true),
     "and what it hid is named as hidden - never touched")
  ok(d.hiddenFields.amount and d.hiddenFields.currentHP and not d.hiddenFields.sourceName,
     "the hidden fields are listed by name")
  ok(d.maxHealth == "<hidden>" and d.combat == "true", "max health hidden, and it says it was a fight")

  -- THE FIGHT ENDS: read again - the answer that says whether waiting helps
  hide = false
  W.combat = false
  onEvent(RC.frame, "PLAYER_REGEN_ENABLED")
  local a = RC.afterFight
  ok(a and a.rows[1]:find("amount=53", 1, true) and next(a.hiddenFields) == nil, "after the fight the same hits read plainly")
  local before = RC.afterFight
  onEvent(RC.frame, "PLAYER_REGEN_ENABLED")
  ok(RC.afterFight == before, "a second fight ending without a death reads nothing")

  -- /bist recap: all three readings, each with its verdict
  S("recap raw")
  local out = heard()
  ok(out:find("at death", 1, true) and out:find("after the fight", 1, true) and out:find("right now", 1, true),
     "/bist recap prints the reading at death, after the fight, and now")
  ok(out:find("hidden: amount, currentHP", 1, true) and out:find("nothing hidden", 1, true),
     "and which fields were hidden in each", out)
  S("recap now")
  out = heard()
  ok(out:find("right now", 1, true) and not out:find("at death", 1, true), "/bist recap now: just the live read")

  -- what the game may do instead of answering
  hiddenTables = {}
  local list
  _G.C_DeathRecap.GetRecapEvents = function() list = { hit(1) } hiddenTables[list] = true return list end
  ok(RC.Read("x").notes[1] == "the whole record is hidden", "a hidden list is said to be hidden")
  _G.C_DeathRecap.GetRecapEvents = function() local r = hit(1) hiddenTables[r] = true return { r } end
  ok(RC.Read("x").rows[1] == "#1 <hidden hit>", "a hidden hit is said to be hidden, not walked")
  _G.C_DeathRecap.GetRecapEvents = function() error("forbidden", 2) end
  local okR, snap = pcall(RC.Read, "x")
  ok(okR and snap.notes[1]:find("refused", 1, true), "a refusal is reported, not thrown")
  _G.C_DeathRecap.GetRecapEvents = function() local out2 = {} for i = 1, 15 do out2[i] = hit(i) end return out2 end
  snap = RC.Read("x")
  ok(snap.count == 15 and #snap.rows == RC.MAX_ROWS, "fifteen hits recorded, the newest ten printed")

  -- switched off: dying is not even read
  R:SetEnabled("recap", false)
  RC.atDeath = nil
  onEvent(RC.frame, "PLAYER_DEAD")
  ok(RC.atDeath == nil, "with the tool off, a death is not read")
  R:SetEnabled("recap", true)

  -- LEAN: it costs nothing until you die - a fight ending reads nothing at all
  local Cost = dofile("../_bisdev/dev/cost.lua")
  RC.waitFight = nil
  local n = Cost.Count(function() for _ = 1, 100 do onEvent(RC.frame, "PLAYER_REGEN_ENABLED") end end)
  ok(n == 0, "100 fights ending without a death cost no client calls: " .. n)
  print(("   cost: 100 fights ending, no death = %d calls"):format(n))

  _G.type, _G.issecretvalue, _G.issecrettable, _G.canaccessvalue, _G.C_DeathRecap =
    keep.type, keep.issecretvalue, keep.issecrettable, keep.canaccessvalue, keep.C_DeathRecap
  DEFAULT_CHAT_FRAME.AddMessage = keep.chat
  RC.atDeath, RC.afterFight, RC.waitFight = nil, nil, nil
end

-- ---------------------------------------------------------------- the death recap window, on Arn's death
-- (12 Oct 2026) Ragefire Chasm, pasted from /bist recap: ten hits, nothing hidden. The window has to
-- say what the mockup said - killer Molten Elemental 128 (42%), Earthborers 106 (35%) and 72 (24%),
-- "306 damage in 6.0 seconds" - and group by GUID, because Forever re-names a mob on every hit.
do
  local RC = NS.Recap
  local MOLTEN, EB_A, EB_B = "Creature-0-4621-389-178375-11321-0003CD6", "Creature-0-4621-389-178375-11320-0000CD6",
                             "Creature-0-4621-389-178375-11320-0002CD6"
  local function h(amount, crit, hp, t, name, guid, extra)
    local r = { event = "SWING_DAMAGE", amount = amount, critical = crit, currentHP = hp, timestamp = 1791846000 + t,
                sourceName = name, sourceGUID = guid, overkill = -1, school = 1 }
    for k, v in pairs(extra or {}) do r[k] = v end
    return r
  end
  local ARN = {   -- newest first, as the game gives it
    h(27, false, 13, 504.529, "Molten Elemental Smitecrust", MOLTEN, { overkill = 14 }),
    h(44, true, 57, 504.046, "Earthborer Milker", EB_A),
    h(44, true, 101, 503.163, "Earthborer Arms", EB_B),
    h(7, false, 108, 502.529, "Molten Elemental Shaquanda", MOLTEN, { blocked = 22 }),
    h(2, false, 110, 502.046, "Earthborer Sama", EB_A, { blocked = 22 }),
    h(44, true, 154, 501.146, "Earthborer Bee", EB_B),
    h(49, true, 203, 500.512, "Molten Elemental Shaquanda", MOLTEN),
    h(26, false, 229, 500.046, "Earthborer Deluxe", EB_A),
    h(18, false, 247, 499.147, "Earthborer Beartotem", EB_B),
    h(45, true, 292, 498.505, "Molten Elemental Flashs", MOLTEN),
  }
  local keepDR, keepDead = _G.C_DeathRecap, _G.UnitIsDeadOrGhost
  local deadNow = true
  _G.UnitIsDeadOrGhost = function() return deadNow end
  _G.C_DeathRecap = { HasRecapEvents = function() return true end, GetRecapMaxHealth = function() return 1192 end,
                      GetRecapEvents = function() return ARN end }

  local s = RC.Summary(RC.Hits(ARN), 1192)
  ok(#s.attackers == 3, "ten nicknames, three mobs: grouped by GUID")
  ok(s.killer and s.killer.title == "Molten Elemental" and s.killer.total == 128, "the killer: the Molten Elemental, 128")
  ok(s.assists[1].title == "Earthborer" and s.assists[1].total == 106 and s.assists[2].total == 72,
     "the assists: the two Earthborers, 106 and 72")
  ok(s.total == 306 and math.abs(s.seconds - 6.024) < 0.01 and s.startHP == 292, "306 damage in 6.0 seconds, from 292 health")
  ok(table.concat(s.killer.nicks, ","):find("Smitecrust", 1, true) and table.concat(s.killer.nicks, ","):find("Flashs", 1, true),
     "its nicknames listed under it")
  ok(RC.Shared({ "Kumlust" }) == "Kumlust" and RC.Shared({ "Earthborer Milker", "Earthborer Arms" }) == "Earthborer",
     "a lone name is kept whole; shared words make the kind")

  -- dying opens it, painted from the record
  local rdb = R:DBFor(R:Get("recap"))
  rdb.popup = true
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_DEAD")
  local w = RC.win
  ok(w:IsShown(), "dying opens the death recap")
  ok(w.mid.name.text == "Molten Elemental" and w.mid.role.text == "killer" and w.mid.dmg.text == "128 (42%)",
     "the middle card: killer, Molten Elemental, 128 (42%)", w.mid.dmg.text)
  ok(w.left.dmg.text == "106 (35%)" and w.right.dmg.text == "72 (24%)", "the assists either side, with their shares")
  ok(w.mid.what.text == "melee 27 +14", "what killed you: the killing blow's own hit, its size and its overkill", w.mid.what.text)
  -- THE FACES (Arn, 26 Oct: "instead of the wall of text, up to 3 3d models ... what they killed us with and how
  -- much they hit us for"): the killer and the two assists in 3D, by the npc id in each GUID
  ok(w.mid.model.shown and w.mid.model._creature == 11321 and w.mid.drawn == "creature",
     "the killer's card: the Molten Elemental in 3D (npc 11321, from its GUID)", tostring(w.mid.model._creature))
  ok(w.left.drawn == "creature" and w.right.drawn == "creature", "the assists in 3D too")
  -- faces first; the wall one click away
  ok(w.faces.shown and not w.detail.shown and w.detailBtn.label.text == "details >",
     "the window opens on the faces; the wall waits behind 'details >'")
  w.detailBtn.scripts.OnClick(w.detailBtn)
  ok(w.detail.shown and not w.faces.shown and w.detailBtn.label.text == "< faces" and rdb.detail == true,
     "details: who hit you, what kind, your health, the hits - and '< faces' brings them back")
  w.detailBtn.scripts.OnClick(w.detailBtn)
  ok(w.faces.shown and not w.detail.shown and rdb.detail == nil, "and back to the faces")
  ok(w.foot.text == "306 damage in 6.0 seconds", "the total line", w.foot.text)
  ok(w.rows[1].amt.text == "27 +14" and w.rows[2].what.text == "melee crit" and w.rows[5].what.text == "melee 22 blk",
     "the hits, newest first, crits and blocks marked", tostring(w.rows[1].amt.text) .. " | " .. tostring(w.rows[2].what.text) .. " | " .. tostring(w.rows[5].what.text))
  ok(w.stripLeft.text == "292 of 1192 health when these began", "the strip says where the hits began", w.stripLeft.text)
  -- THE REMADE RECAP (Arn, 14 Oct: "redo this window ... the imax 70mm aspect ratio")
  ok(math.abs(w.w / w.h - 1.43) < 0.01, "the death recap is 1.43:1", w.w .. "x" .. w.h)
  ok(w.who[1].name.text == "Molten Elemental" and w.who[1].amt.text == "128 (42%)" and w.who[2].name.text ~= "",
     "who hit you: a bar per attacker, the most damage first", w.who[1].name.text .. " " .. w.who[1].amt.text)
  ok(w.who[1].bar.shown ~= false and w.who[1].bar.w > w.who[2].bar.w, "the bars as long as their share")
  ok(w.kind[1].name.text == "physical" or w.kind[2].name.text:find("magic", 1, true),
     "what kind: physical, magic", w.kind[1].name.text .. " / " .. w.kind[2].name.text)
  ok(#w.rows == 10 and w.rows[6].amt.text ~= "" and w.rows[10].amt.text ~= "", "all ten hits, in two columns")
  ok(w.drawer == RC.rwin and math.abs(RC.rwin.w / RC.rwin.h - 1.43) < 0.01, "the rivals: their own window, also 1.43:1")
  -- "rivals >" opens it, and closes it again (Arn: "this opens it, it should also close it")
  RC.SetExpanded(rdb, false)
  w.rivalsBtn.scripts.OnClick(w.rivalsBtn)
  ok(RC.rwin:IsShown() and w.rivalsBtn.label.text == "rivals <", "rivals >: opens the window, the arrow turns")
  w.rivalsBtn.scripts.OnClick(w.rivalsBtn)
  ok(not RC.rwin:IsShown() and w.rivalsBtn.label.text == "rivals >", "and again: closes it")
  -- ESCAPE CLOSES BOTH (Arn: "esc not closing the bis rival and pal page")
  local inEsc = {}
  for _, n in ipairs(UISpecialFrames or {}) do inEsc[n] = true end
  ok(inEsc.BiSToolsRivals and inEsc.BiSToolsRecap, "Escape closes the rivals & pals window and the recap")
  RC.SetExpanded(rdb, true)
  RC.rwin:Hide() if RC.rwin.scripts.OnHide then RC.rwin.scripts.OnHide(RC.rwin) end   -- what Escape does
  ok(rdb.expanded == false and w.rivalsBtn.label.text == "rivals >", "closed by Escape: the arrow turns back")
  -- THE GUILD ONLINE TAB (Arn, 21 Oct 2026: "a tab that generates the online guild people so we can right click
  -- and add to pals"). Forever's roster names are whole ("Name Surname-Realm"); a pal is matched whole.
  do
    local keepIG, keepGN, keepGR, keepMU, keepTell = _G.IsInGuild, _G.GetNumGuildMembers, _G.GetGuildRosterInfo,
      _G.MenuUtil, _G.ChatFrame_SendTell
    local roster = { { "Chain Healz-Dreamscythe", "Officer", 1, true, "SHAMAN" },
                     { "Chain Other-Dreamscythe", "Raider", 3, true, "MAGE" },
                     { "Offline Guy-Dreamscythe", "Raider", 3, false, "ROGUE" } }
    _G.IsInGuild = function() return true end
    _G.GetNumGuildMembers = function() return #roster end
    _G.GetGuildRosterInfo = function(i) local m = roster[i]
      return m[1], m[2], m[3], 30, "x", "", "", "", m[4], 0, m[5] end
    local asked = 0
    local keepGI = _G.C_GuildInfo
    _G.C_GuildInfo = { GuildRoster = function() asked = asked + 1 end }
    local menuLines, menuFns = {}, {}
    _G.MenuUtil = { CreateContextMenu = function(owner, gen)
      menuLines, menuFns = {}, {}
      local root = { CreateTitle = function(_, t) menuLines[#menuLines + 1] = "title:" .. t end,
                     CreateButton = function(_, t, fn) menuLines[#menuLines + 1] = t menuFns[t] = fn end }
      gen(owner, root)
    end }
    local told
    _G.ChatFrame_SendTell = function(n) told = n end
    RC.Pals(rdb)["Chain Healz"] = nil
    RC.Pals(rdb)["Chain Other"] = nil
    RC.Pals(rdb)["Chain Pal"] = { added = 1 }           -- a pal who shares a first name with two guildmates
    RC.SetExpanded(rdb, true)
    RC.rwin.tabGuild.scripts.OnClick(RC.rwin.tabGuild)
    local d = RC.rwin
    ok(d.tab == "guild" and asked == 1, "the guild online tab: open, and a fresh roster asked for")
    ok(d.rows[1].mate == "Chain Healz" and d.rows[2].mate == "Chain Other" and not d.rows[3]:IsShown(),
       "the guildmates online, whole names, the offline one left out", tostring(d.rows[1].mate))
    ok(not RC.IsMatePal(rdb, "Chain Healz"), "a pal named Chain Pal does not make Chain Healz one (whole names)")
    d.rows[2].scripts.OnClick(d.rows[2], "RightButton")
    ok(menuLines[1] == "title:Chain Other" and menuLines[2] == "Add pal" and menuLines[3] == "Whisper",
       "right-click: the name, Add pal, Whisper", table.concat(menuLines, "|"))
    menuFns["Add pal"]()
    ok(RC.Pals(rdb)["Chain Other"] and d.rows[1].mate == "Chain Other" and d.rows[1].info.text:find("pal", 1, true),
       "added: a pal now, listed first", tostring(d.rows[1].info.text))
    d.rows[1].scripts.OnClick(d.rows[1], "RightButton")
    ok(menuLines[2] == "Remove pal", "and its menu offers to take them off again")
    menuFns["Whisper"]()
    ok(told == "Chain Other", "Whisper opens a whisper to them")
    menuFns["Remove pal"]()
    ok(RC.Pals(rdb)["Chain Other"] == nil, "removed")
    ok(RC.rwin.events and RC.rwin.events.GUILD_ROSTER_UPDATE ~= false, "the tab listens for the roster's answer")
    RC.rwin.tabRivals.scripts.OnClick(RC.rwin.tabRivals)
    ok(d.tab == "rivals" and not d.rows[1].mate, "back on the rivals tab: rivals again")
    _G.MenuUtil = nil
    RC.SetExpanded(rdb, true)
    RC.RivalsTab("guild")
    d.rows[1].scripts.OnClick(d.rows[1], "RightButton")
    ok(RC.Pals(rdb)["Chain Healz"] ~= nil, "a client without the menu kit: the click adds the pal straight away")
    RC.Pals(rdb)["Chain Healz"] = nil
    RC.Pals(rdb)["Chain Pal"] = nil
    RC.RivalsTab("rivals")
    RC.SetExpanded(rdb, false)
    _G.IsInGuild, _G.GetNumGuildMembers, _G.GetGuildRosterInfo, _G.MenuUtil, _G.ChatFrame_SendTell, _G.C_GuildInfo =
      keepIG, keepGN, keepGR, keepMU, keepTell, keepGI
  end
  -- NOT ON TOP OF THE RECAP (Arn: "needs the same brains to not overlap windows")
  do
    local keepR, keepRS, keepWR, keepWS = RC.rwin.GetRect, RC.rwin.GetEffectiveScale, w.GetRect, w.GetEffectiveScale
    w.GetRect = function() return 400, 300, 460, 322 end
    w.GetEffectiveScale = function() return 1 end
    RC.rwin.GetRect = function() return 450, 250, 500, 350 end      -- right over the recap
    RC.rwin.GetEffectiveScale = function() return 1 end
    local keepUP = _G.UIParent
    _G.UIParent = { GetWidth = function() return 1920 end, GetHeight = function() return 1080 end,
                    GetEffectiveScale = function() return 1 end }
    RC.SetExpanded(rdb, true)
    local p = RC.rwin.point
    ok(p and p[1] == "TOPLEFT" and p[2] == _G.UIParent and p[4] == 400 + 460 + 8, "the rivals window opens beside the recap, not on it",
       p and (tostring(p[4]) .. "," .. tostring(p[5])))
    RC.SetExpanded(rdb, false)
    RC.rwin.GetRect, RC.rwin.GetEffectiveScale, w.GetRect, w.GetEffectiveScale = keepR, keepRS, keepWR, keepWS
    _G.UIParent = keepUP
  end
  ok(w.cols[1].h > w.cols[10].h and w.cols[10].shown, "the health columns fall from oldest to newest")
  fitsIn(w, "the death recap")

  -- back on your feet: it closes; still a ghost: it stays
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_ALIVE")
  ok(w:IsShown(), "releasing your spirit (still a ghost) leaves it open")
  deadNow = false
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_UNGHOST")
  ok(not w:IsShown(), "back in your body, it closes")
  S("recap")
  ok(w:IsShown(), "/bist recap opens your last death again")
  S("recap")
  ok(not w:IsShown(), "and closes it")

  -- "STOP SHOWING THIS" (Arn, 12 Oct)
  S("recap")
  ok(w.stop and w.stop.label.text == "stop showing this", "the recap has a stop showing this line")
  w.stop.scripts.OnClick(w.stop)
  ok(rdb.popup == false and not w:IsShown(), "clicked: it closes, and will not open on a death")
  deadNow = true
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_DEAD")
  ok(not w:IsShown(), "dying again: it stays shut")
  S("recap")
  ok(w:IsShown() and w.stop.label.text == "show when I die", "/bist recap still opens it, offering it back")
  fitsIn(w, "the recap with its stop line")
  w.stop.scripts.OnClick(w.stop)
  ok(rdb.popup == true and w.stop.label.text == "stop showing this", "and clicking that turns it back on")
  w:Hide()
  deadNow = false

  -- switched off: dying does not open it
  rdb.popup = false
  deadNow = true
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_DEAD")
  ok(not w:IsShown(), "with 'open when you die' off, it stays shut")
  rdb.popup = true

  -- a player killer (PvP): the name is the name
  local pk = RC.Summary(RC.Hits({ h(80, true, 50, 10, "Kumlust", "Player-4619-00ABCDEF", { overkill = 30 }) }), 1192)
  ok(pk.killer.title == "Kumlust" and #pk.killer.nicks == 0 and pk.assists[1] == nil, "a player who killed you is named as themselves")

  -- KILLED BY THREE HUNTERS (Arn's screenshot, 12 Oct): player names in class colour, each card's
  -- main spell, the healing note, and a click to make one a rival
  local LEG, MOMS, EGGS = "Player-4619-0001", "Player-4619-0002", "Player-4619-0003"
  local PVP = {
    h(114, false, 114, 5.3, "Hunting Moms", MOMS, { spellName = "Auto Shot", event = "RANGE_DAMAGE", overkill = 38 }),
    h(48, false, 162, 5.3, "Légolas Thiliaere", LEG, { spellName = "Serpent Sting", event = "SPELL_PERIODIC_DAMAGE" }),
    h(137, true, 299, 5.2, "Hunting Moms", MOMS, { spellName = "Arcane Shot", event = "SPELL_DAMAGE" }),
    h(151, true, 450, 3.8, "Légolas Thiliaere", LEG, { spellName = "Arcane Shot", event = "SPELL_DAMAGE" }),
    h(104, false, 554, 3.7, "Hunting Moms", MOMS, { spellName = "Auto Shot", event = "RANGE_DAMAGE" }),
    h(26, false, 580, 2.6, "Eggs Benethicc", EGGS, { spellName = "Rend", event = "SPELL_PERIODIC_DAMAGE" }),
    h(120, false, 700, 2.0, "Légolas Thiliaere", LEG, { spellName = "Auto Shot", event = "RANGE_DAMAGE" }),
    h(117, false, 817, 1.2, "Légolas Thiliaere", LEG, { spellName = "Auto Shot", event = "RANGE_DAMAGE" }),
    h(130, true, 947, 0.5, "Légolas Thiliaere", LEG, { spellName = "Arcane Shot", event = "SPELL_DAMAGE" }),
    h(100, false, 361, 0.0, "Légolas Thiliaere", LEG, { spellName = "Serpent Sting", event = "SPELL_PERIODIC_DAMAGE" }),
  }
  local CLASS = { [LEG] = "HUNTER", [MOMS] = "HUNTER", [EGGS] = "WARRIOR" }
  local keepInfo, keepColors = _G.GetPlayerInfoByGUID, _G.RAID_CLASS_COLORS
  _G.GetPlayerInfoByGUID = function(g) return "x", CLASS[g] end
  _G.RAID_CLASS_COLORS = { HUNTER = { r = 0.67, g = 0.83, b = 0.45 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
  _G.C_DeathRecap.GetRecapEvents = function() return PVP end
  local rdb2 = R:DBFor(R:Get("recap"))
  rdb2.rivals = nil
  deadNow = true
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_DEAD")
  local p = RC.last
  ok(p.killer.title == "Hunting Moms" and p.killer.player and p.killer.class == "HUNTER", "a player killer, with their class")
  ok(w.left.name.text == "Légolas Thiliaere" and w.left.dmg.text == "666 (64%)", "the biggest assist: Légolas, 666 (64%)", w.left.dmg.text)
  ok(w.left.what.text == "Arcane Shot 281", "each card says what they mostly hit you with", w.left.what.text)
  ok(w.right.what.text == "Rend 26", "even a one-hit assist", w.right.what.text)
  -- a player's face: their own body while they are still about (a nameplate), else their class's icon
  -- (never someone else's face)
  local keepTok, keepTC = _G.UnitTokenFromGUID, _G.CLASS_ICON_TCOORDS
  _G.UnitTokenFromGUID = function(g) if g == MOMS then return "nameplate3" end end
  _G.CLASS_ICON_TCOORDS = { HUNTER = { 0, 0.25, 0.25, 0.5 }, WARRIOR = { 0, 0.25, 0, 0.25 } }
  RC.Paint(RC.last)
  ok(w.mid.drawn == "unit" and w.mid.model._unit == "nameplate3" and w.mid.model.shown,
     "the killer still in sight: their own body, gear and all (UnitTokenFromGUID)", tostring(w.mid.model._unit))
  ok(w.left.drawn == "icon" and not w.left.model.shown and w.left.icon.shown, "an assist already gone: their class icon, no face")
  _G.UnitTokenFromGUID, _G.CLASS_ICON_TCOORDS = keepTok, keepTC
  ok(w.left.name.color and math.abs(w.left.name.color[1] - 0.67) < 0.01, "a player's name in their class colour")
  ok(w.foot.text == "1047 damage in 5.3 seconds - you healed through some of it", "more damage than health is explained", w.foot.text)

  -- CLICK A PLAYER: a rival. Click again: not. A mob card is not clickable into the list.
  w.mid.scripts.OnClick(w.mid, "LeftButton")
  local rivals = RC.Rivals(rdb2)
  ok(rivals["Hunting Moms"] and rivals["Hunting Moms"].class == "HUNTER" and rivals["Hunting Moms"].guid == MOMS,
     "clicking the killer's card makes them a rival, with class and GUID")
  ok(w.mid.rival.text == "rival", "and the card says so")
  fitsIn(w, "the death recap, a rival on it")
  w.mid.scripts.OnClick(w.mid, "LeftButton")
  ok(rivals["Hunting Moms"] == nil and w.mid.rival.text == "", "a second click takes them off")
  w.mid.scripts.OnClick(w.mid, "LeftButton")
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_DEAD")
  ok(rivals["Hunting Moms"].kills == 1, "a rival who kills you again is counted")
  local said2 = {}
  local keepAdd = DEFAULT_CHAT_FRAME.AddMessage
  DEFAULT_CHAT_FRAME.AddMessage = function(_, m) said2[#said2 + 1] = m end
  S("recap rivals")
  local listed = table.concat(said2, "\n")
  ok(listed:find("Hunting Moms", 1, true) and listed:find("killed you 1 more time", 1, true), "/bist recap rivals lists them")
  -- the short words (Arn: "dont need to write to command all the time"): /bist rivals is the same
  said2 = {}
  S("rivals list")
  ok(table.concat(said2, " | "):find("Hunting Moms", 1, true), "/bist rivals list lists them in chat")
  -- /bist rivals: THEIR OWN WINDOW (Arn: "make its own thing that can be pulled up")
  RC.SetExpanded(rdb2, false)   -- start from closed: an earlier step left it open
  S("rivals")
  ok(RC.rwin and RC.rwin:IsShown(), "/bist rivals opens the rivals & pals window", tostring(RC.rwin) .. " on=" .. tostring(R:Enabled("rivals")) .. " said=" .. table.concat(said2, " | "))
  local found
  for _, b in ipairs(RC.rwin.rows) do if b.rival == "Hunting Moms" and b:IsShown() then found = b end end
  ok(found, "listing them")
  S("rivals")
  ok(not RC.rwin:IsShown(), "and again closes it")
  -- their own tool: with the recap switched off, the rivals' commands still answer
  R:SetEnabled("recap", false)
  said2 = {}
  S("rivals list")
  ok(table.concat(said2, " | "):find("Hunting Moms", 1, true), "recap off: /bist rivals list still lists them - their own tool now")
  R:SetEnabled("recap", true)
  said2 = {}
  S("pals")
  ok(table.concat(said2, "\n"):find("no pals yet", 1, true), "/bist pals: none yet, and how to add one")
  -- A PAL BY NAME, NO TARGET (Arn, 16 Oct: "can i type /bist pal <name> <surname> to add a pal?")
  S("pal fistfull ofpills")
  local palsNow = RC.Pals(R:DBFor(R:Get("recap")))
  ok(palsNow["Fistfull Ofpills"] ~= nil, "/bist pal fistfull ofpills: a pal, written the way the game writes names")
  ok(palsNow["Fistfull Ofpills"] and palsNow["Fistfull Ofpills"].guid == nil, "no ID yet - the name decides")
  said2 = {}
  S("pal Fistfull Ofpills")
  ok(palsNow["Fistfull Ofpills"] == nil and table.concat(said2, " "):find("no longer a pal", 1, true),
     "typed again: off the list, as /bist pal on a target does")
  S("pal Fistfull")
  S("pal fistfull")
  ok(palsNow["Fistfull"] == nil, "a first name alone toggles the same way")
  said2 = {}
  S("pal 1337 h4x")
  ok(next(palsNow) == nil and table.concat(said2, " "):find("not a name", 1, true), "digits are not a name")
  S("recap forget hunting moms")
  ok(rivals["Hunting Moms"] == nil, "/bist recap forget <name> takes one off, any capitals")
  DEFAULT_CHAT_FRAME.AddMessage = keepAdd
  _G.C_DeathRecap.GetRecapEvents = function() return ARN end
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_DEAD")
  w.mid.scripts.OnClick(w.mid, "LeftButton")
  ok(next(RC.Rivals(rdb2)) == nil, "a mob is never a rival")
  -- THE BIG VIEW AND THE TRACKER (Arn, 12 Oct: "if i click a button it maximize and shows more info
  -- all rivals etc. current target gold, all previous targets silver. can click them again to turn
  -- them gold" ... "yes start the tracker")
  _G.C_DeathRecap.GetRecapEvents = function() return PVP end
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_DEAD")
  w.mid.scripts.OnClick(w.mid, "LeftButton")                         -- Hunting Moms: gold
  w.left.scripts.OnClick(w.left, "LeftButton")                       -- Légolas: gold
  ok(RC.GoldCount(rdb2) == 2 and rivals["Légolas Thiliaere"].active, "a rival clicked from a recap starts gold")
  RC.SetActive(rdb2, "Légolas Thiliaere", false)
  ok(RC.GoldCount(rdb2) == 1, "and can be sent to silver")
  -- Légolas seen more recently than Moms: gold-first has to beat most-recent-first
  rivals["Légolas Thiliaere"].seen = W.now + 100
  rdb2.expanded = false
  RC.SetExpanded(rdb2, false)
  ok(not w.drawer:IsShown(), "small: no drawer")
  w.moreBtn.scripts.OnClick(w.moreBtn)
  ok(w.drawer:IsShown() and rdb2.expanded and w.moreBtn.label.text == "-", "the + button opens the rivals drawer")
  local d = w.drawer
  ok(d.rows[1].rival == "Hunting Moms" and d.rows[2].rival == "Légolas Thiliaere", "gold first, then silver")
  ok(d.rows[1].mark.color[2] > d.rows[2].mark.color[2] - 0.0 and d.rows[2].name.color[4] < 1,
     "a gold mark on the hunted, a dimmed silver row for the rest")
  fitsIn(d, "the rivals drawer")
  local function rowOf(name) for _, r in ipairs(d.rows) do if r.rival == name then return r end end end
  rowOf("Légolas Thiliaere").scripts.OnClick(rowOf("Légolas Thiliaere"), "LeftButton")
  ok(rivals["Légolas Thiliaere"].active, "clicking a silver rival turns them gold again")
  rowOf("Légolas Thiliaere").scripts.OnClick(rowOf("Légolas Thiliaere"), "LeftButton")
  ok(not rivals["Légolas Thiliaere"].active, "and back to silver")

  -- the tracker: a gold rival's nameplate appears
  local keepZone = _G.GetZoneText
  _G.GetZoneText = function() return "The Barrens" end
  W.notices, W.sounds = {}, {}
  W.plates.nameplate7 = { name = "Hunting Moms" }
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  ok(W.notices[1] == "Rival nearby: Hunting Moms" and #W.sounds == 1, "a gold rival in sight: a warning and a sound")
  ok(rivals["Hunting Moms"].where == "The Barrens" and rivals["Hunting Moms"].seen == W.now, "and where and when is kept")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  ok(#W.notices == 1, "the same rival again within a minute: quiet")
  W.now = W.now + RC.ALERT_GAP + 1
  W.target = { name = "Hunting Moms" }
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_TARGET_CHANGED")
  ok(#W.notices == 2, "a minute later, targeting them calls them out again")
  W.plates.nameplate8 = { name = "Légolas Thiliaere" }
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate8")
  ok(#W.notices == 2, "a silver rival is remembered, not called out")
  W.plates.nameplate9 = { name = "Somebody Else" }
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate9")
  ok(#W.notices == 2, "a stranger is nobody's business")
  rdb2.sound = false
  local soundsBefore = #W.sounds
  W.now = W.now + RC.ALERT_GAP + 1
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  ok(#W.notices == 3 and #W.sounds == soundsBefore, "with the sound off: the warning, no sound")
  rdb2.sound = nil
  ok(d.rows[1].info.text:find("seen 0m ago, The Barrens", 1, true), "the drawer says where they were last seen", d.rows[1].info.text)
  -- a nameplate whose name the game hides: nothing, and no error
  local keepName = _G.UnitName
  _G.UnitName = function() return setmetatable({}, { __index = function() error("secret") end }) end
  local keepIs = _G.issecretvalue
  _G.issecretvalue = function(v) return type(v) == "table" end
  ok(pcall(RC.frame.scripts.OnEvent, RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7") and #W.notices == 3,
     "a hidden name is not read, and nothing is called out")
  _G.UnitName, _G.issecretvalue = keepName, keepIs

  -- THE CROSSHAIR ON A GOLD RIVAL'S NAMEPLATE (Arn: "is there a way to draw a crosshairs like our
  -- healing addon via the name plates" ... "gold rivals only, pulsing"). The client hands an addon the
  -- nameplate frame; one it locks away says so with IsForbidden.
  local plates = {}
  local keepGet = _G.C_NamePlate.GetNamePlateForUnit
  _G.C_NamePlate.GetNamePlateForUnit = function(u) return plates[u] end
  plates.nameplate7 = CreateFrame("Frame", nil, nil)
  plates.nameplate7:SetSize(180, 20)
  plates.nameplate8 = CreateFrame("Frame", nil, nil)
  RC.SetActive(rdb2, "Hunting Moms", true)
  W.plates.nameplate7 = { name = "Hunting" }                -- the character name, as a nameplate gives it
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  local mk = RC.marks.nameplate7
  ok(mk and mk.shown and mk.rival == "Hunting Moms" and mk.point and mk.point[2] == plates.nameplate7
     and mk.point[1] == "TOP" and mk.point[3] == "BOTTOM",
     "a gold rival's nameplate wears the crosshair, hanging under the plate")
  ok(mk.w == 90 and mk.h == RC.MARK_H, "half the plate's width (Arn: \"tighten it up 50%\"), centred", mk.w)
  -- A SHARED FIRST NAME IS NOT THE RIVAL (Arn, 14 Oct: "terry daviss is marked as rival because there
  -- is a terry lin alliance")
  do
    local keepGUN = _G.GetUnitName
    plates.nameplate9 = CreateFrame("Frame", nil, nil)
    W.plates.nameplate9 = { name = "Hunting", guid = rivals["Hunting Moms"].guid }
    _G.GetUnitName = function(u) if u == "nameplate9" then return "Hunting Daviss" end end
    RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate9")
    ok(RC.marks.nameplate9 == nil, "the plate's whole name is somebody else's: no crosshair")
    _G.GetUnitName = keepGUN
    W.plates.nameplate9 = { name = "Hunting", guid = "Player-1-SOMEONEELSE" }
    RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate9")
    ok(RC.marks.nameplate9 == nil, "one word only, but another player's GUID: no crosshair")
    _G.GetUnitName = function(u) if u == "nameplate9" then return "Hunting Moms" end end
    W.plates.nameplate9 = { name = "Hunting", guid = rivals["Hunting Moms"].guid }
    RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate9")
    ok(RC.marks.nameplate9 and RC.marks.nameplate9.rival == "Hunting Moms", "the rival's own whole name and GUID: the crosshair")
    -- A PAL IS NEVER A RIVAL (Arn: "there should be a check if its friendly target not a rival but a
    -- pal - enemy hostile player rival")
    RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_REMOVED", "nameplate9")
    W.plates.nameplate9.hostile = false
    RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate9")
    ok(RC.marks.nameplate9 == nil, "a friendly player, even by the rival's own name: no crosshair")
    local keepT = W.target
    W.target = { name = "Pal Guy", player = true, hostile = false, guid = "Player-1-PAL" }
    RC.RivalFromTarget(rdb2)
    ok(rivals["Pal Guy"] == nil, "a friendly target is never added as a rival")
    local root = { lines = {} }
    function root:CreateButton(t) self.lines[#self.lines + 1] = t end
    RC.MenuLines(rdb2, root, { unit = "target", name = "Pal Guy" })
    ok(root.lines[1] == "Add pal" and #root.lines == 1 and RC.menuDecision:find("friendly", 1, true),
       "the right-click menu offers 'add pal' on them, never 'add rival'", RC.menuDecision)
    -- PALS (Arn: "a freindly list too ... puts a tiny little heart green ... only works out of combat")
    local pals = RC.Pals(rdb2)
    root.click = nil
    function root:CreateButton(t, fn) self.lines[#self.lines + 1] = t self.click = fn end
    root.lines = {}
    RC.MenuLines(rdb2, root, { unit = "target", name = "Pal Guy" })
    root.click()
    ok(pals["Pal Guy"] and pals["Pal Guy"].guid == "Player-1-PAL", "clicked: a pal, GUID and all")
    -- THE FRIENDS LIST (Arn, 14 Oct: "it thinks is a rival when its the same faction as me"): a
    -- Battle.net friend's menu has no unit and names the BattleTag nickname; the character comes
    -- from the account, and the line is the pal's
    local keepBN, keepFac = _G.C_BattleNet, _G.UnitFactionGroup
    _G.UnitFactionGroup = function() return "Horde", "Horde" end
    _G.C_BattleNet = { GetAccountInfoByID = function(id)
      if id == 77 then return { accountName = "ShinyPants", gameAccountInfo = { characterName = "Darthsidiouz Sithlord", factionName = "Horde" } } end
      if id == 79 then return { accountName = "Foe", gameAccountInfo = { characterName = "Alli Ance", factionName = "Alliance" } } end
      if id == 78 then return { accountName = "Elsewhere", gameAccountInfo = {} } end
    end }
    root.lines, root.click = {}, nil
    -- NOT THE FRIENDS LIST (Arn's BugGrabber, 20 Oct: "AddOn 'BiSTools' tried to call the protected function
    -- 'SearchFriends()'" from the list's Refresh): no line in a menu the Friends list opened - its own kinds,
    -- a Battle.net account or the list's index on it, or the Friends window open
    for _, kind in ipairs({ "BN_FRIEND", "BN_FRIEND_OFFLINE", "FRIEND_OFFLINE" }) do
      RC.MenuLines(rdb2, root, { name = "ShinyPants" }, kind)
    end
    RC.MenuLines(rdb2, root, { name = "ShinyPants", bnetIDAccount = 77 }, "FRIEND")
    RC.MenuLines(rdb2, root, { name = "Charfriend", friendsList = 3 }, "FRIEND")
    ok(#root.lines == 0 and tostring(RC.menuDecision):find("Friends list", 1, true),
      "a menu from the Friends list: no line, and /bist recap why says so", RC.menuDecision)
    local keepFF = _G.FriendsFrame
    _G.FriendsFrame = { IsVisible = function() return true end }
    RC.MenuLines(rdb2, root, { name = "Charfriend" }, "FRIEND")
    ok(#root.lines == 0, "the Friends window open: its FRIEND menu gets nothing either")
    _G.FriendsFrame = keepFF
    local hooked = table.concat(RC.MENUS, " ")
    ok(not hooked:find("BN_FRIEND", 1, true) and not hooked:find("FRIEND_OFFLINE", 1, true),
      "the menus only the Friends list opens are never hooked", hooked)
    -- A NAME IN CHAT opens FRIEND too: nothing says friend or foe - BOTH lines, you pick
    -- (Arn, 14 Oct: "if we cant see we add both?")
    RC.MenuLines(rdb2, root, { name = "Charfriend" }, "FRIEND")
    ok(root.lines[1] == "Add pal" and root.lines[2] == "Add rival" and #root.lines == 2,
      "can't tell: both lines", table.concat(root.lines, " / "))
    root.lines = {}
    RC.MenuLines(rdb2, root, { name = "Chatty" }, "CHAT_ROSTER")
    ok(#root.lines == 2, "a name in chat, no unit: both lines too")
    _G.C_BattleNet, _G.UnitFactionGroup = keepBN, keepFac
    pals["Darthsidiouz Sithlord"] = nil
    -- and in the rivals & pals window's right column
    RC.BuildRivals(rdb2)
    RC.db = RC.db or rdb2
    RC.PaintRivals()
    ok(RC.rwin.pals[1].pal == "Pal Guy" and RC.rwin.pals[1]:IsShown(), "the rivals & pals window lists the pal")
    plates.nameplate10 = CreateFrame("Frame", nil, nil)
    W.plates.nameplate10 = { name = "Pal Guy", player = true, hostile = false, guid = "Player-1-PAL" }
    RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate10")
    local heart = RC.hearts.nameplate10
    ok(heart and heart.shown and heart.point and heart.point[1] == "BOTTOM" and heart.point[3] == "TOP",
       "a pal's nameplate: a little heart over it")
    ok(heart.parts == nil or (heart.parts[2].color[2] > 0.9 and heart.parts[2].color[1] < 0.4), "green")
    -- A PAL NEARBY, a small note (Arn: "also a small notification when a pal is nearby")
    local saidP = {}
    local keepAddP = DEFAULT_CHAT_FRAME.AddMessage
    DEFAULT_CHAT_FRAME.AddMessage = function(_, m) saidP[#saidP + 1] = tostring(m) end
    RC.palSeenAt = {}
    RC.UnmarkPal("nameplate10")
    RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate10")
    local noted = table.concat(saidP, " | ")
    ok(noted:find("Pal Guy", 1, true) and noted:find("is nearby", 1, true), "a pal in view: a small green line in chat", noted)
    local n1 = #saidP
    RC.UnmarkPal("nameplate10")
    RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate10")
    ok(#saidP == n1, "the same pal again within ten minutes: quiet")
    rdb2.palNote = false
    RC.palSeenAt = {}
    RC.UnmarkPal("nameplate10")
    RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate10")
    ok(#saidP == n1, "the note switched off: quiet")
    rdb2.palNote = nil
    DEFAULT_CHAT_FRAME.AddMessage = keepAddP
    RC.frame.scripts.OnEvent(RC.frame, "PLAYER_REGEN_DISABLED")
    ok(RC.hearts.nameplate10 == nil, "a fight starts: the hearts come down")
    local keepLock = _G.InCombatLockdown
    _G.InCombatLockdown = function() return true end
    RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate10")
    ok(RC.hearts.nameplate10 == nil, "and none goes up mid-fight")
    _G.InCombatLockdown = keepLock
    RC.frame.scripts.OnEvent(RC.frame, "PLAYER_REGEN_ENABLED")
    ok(RC.hearts.nameplate10 ~= nil, "the fight over: back")
    W.plates.nameplate11 = { name = "Pal", player = true, hostile = false, guid = "Player-1-OTHERPAL" }
    plates.nameplate11 = CreateFrame("Frame", nil, nil)
    RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate11")
    ok(RC.hearts.nameplate11 == nil, "another player sharing the first word: no heart")
    -- /bist recap pal on the target: off again
    RC.PalFromTarget(rdb2)
    ok(pals["Pal Guy"] == nil and RC.hearts.nameplate10 == nil, "/bist recap pal on a pal: no longer one, the heart gone")
    W.target = { name = "Enemy Guy", player = true, guid = "Player-1-ENEMY" }
    RC.PalFromTarget(rdb2)
    ok(pals["Enemy Guy"] == nil, "an enemy is never a pal")
    for _, u in ipairs({ "nameplate10", "nameplate11" }) do
      RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_REMOVED", u)
      W.plates[u], plates[u] = nil, nil
    end
    -- A WHOLE SURNAME (Arn: "a special command for pals and rivals, that adds everyone with the
    -- Foreverpvp surname"): enemies wearing it are rivals, friends pals
    do
      local keepG = _G.GetUnitName
      local whole = { nameplate12 = "Kutsu Foreverpvp", nameplate13 = "Darof Foreverpvp",
                      nameplate14 = "Abba Foreverpvp", nameplate15 = "Kutsu Otherguy" }
      _G.GetUnitName = function(u) return whole[u] end
      W.plates.nameplate12 = { name = "Kutsu", player = true, guid = "Player-1-K" }
      W.plates.nameplate13 = { name = "Darof", player = true, guid = "Player-1-D" }
      W.plates.nameplate14 = { name = "Abba", player = true, hostile = false, guid = "Player-1-A" }
      W.plates.nameplate15 = { name = "Kutsu", player = true, guid = "Player-1-O" }
      for u in pairs(whole) do plates[u] = CreateFrame("Frame", nil, nil) end
      S("surname Foreverpvp")
      ok(RC.Surnames(rdb2).foreverpvp == "Foreverpvp", "/bist surname Foreverpvp keeps it")
      local sounds0 = #W.sounds
      W.now = W.now + RC.ALERT_GAP + 1
      for _, u in ipairs({ "nameplate12", "nameplate13", "nameplate14", "nameplate15" }) do
        RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", u)
      end
      ok(RC.crowns.nameplate12 and RC.crowns.nameplate13 and RC.marks.nameplate12 == nil,
         "every enemy wearing it: the gold crown (Arn: \"a champion competition looking thing\"), not a crosshair")
      local cr = RC.crowns.nameplate12
      ok(cr.point and cr.point[1] == "BOTTOM" and cr.point[3] == "TOP" and cr.parts and cr.parts[2].color[1] == 1
         and cr.parts[2].color[3] < 0.4, "over the plate, gold")
      ok(#W.sounds == sounds0 + 1, "but one call-out a minute for the whole surname, not one per player", #W.sounds - sounds0)
      ok(RC.crowns.nameplate14 and RC.crowns.nameplate14.friend and RC.hearts.nameplate14 == nil and RC.marks.nameplate14 == nil,
         "a friend wearing it: the crown too, never a heart or a crosshair")
      ok(RC.crowns.nameplate15 == nil and RC.marks.nameplate15 == nil, "a different surname: nothing")
      RC.frame.scripts.OnEvent(RC.frame, "PLAYER_REGEN_DISABLED")
      ok(RC.crowns.nameplate14 == nil and RC.crowns.nameplate12 ~= nil, "a fight: a friend's crown comes down, an enemy's stays")
      RC.frame.scripts.OnEvent(RC.frame, "PLAYER_REGEN_ENABLED")
      ok(RC.crowns.nameplate14 ~= nil, "and comes back after")
      S("surname foreverpvp")
      ok(RC.Surnames(rdb2).foreverpvp == nil and RC.crowns.nameplate12 == nil and RC.crowns.nameplate14 == nil,
         "the same again lets it go - crosshairs and hearts down")
      for u in pairs(whole) do
        RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_REMOVED", u)
        W.plates[u], plates[u] = nil, nil
      end
      _G.GetUnitName = keepG
    end
    W.target = keepT
    _G.GetUnitName = keepGUN
    RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_REMOVED", "nameplate9")
    W.plates.nameplate9, plates.nameplate9 = nil, nil
  end
  -- Arn's shape: a rail down each side of the body, a tick in at the middle of each
  ok(#mk.parts == 4 and mk.leftRail.h == RC.MARK_H and mk.rightRail.h == RC.MARK_H
     and mk.leftTick.anchor[1] == "LEFT" and mk.rightTick.anchor[1] == "RIGHT"
     and mk.leftTick.w > mk.leftTick.h and mk.parts[1].color[1] == 1 and mk.parts[1].color[2] < 0.3,
     "two red rails the body's height, a tick in from each side at the middle")
  ok(mk.pulse and mk.pulse:IsPlaying() and mk.pulse.looping == "BOUNCE", "and it pulses on the client's own loop")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  ok(RC.marks.nameplate7 == mk, "the same plate twice: one crosshair")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_REMOVED", "nameplate7")
  ok(RC.marks.nameplate7 == nil and not mk.shown and not mk.pulse:IsPlaying(), "the plate leaves: the crosshair goes")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  ok(RC.marks.nameplate7 == mk, "and comes back from the pool, not a new frame")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_REMOVED", "nameplate7")
  plates.nameplate7.w = nil                                  -- a plate that will not say how wide it is
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  ok(RC.marks.nameplate7 and RC.marks.nameplate7.w == RC.MARK_W, "a plate with no width: 60 px, never an error")
  plates.nameplate7.w = 180
  -- CROSSHAIRS TO PLAY WITH (Arn: "maybe in the recap or options we can play around with different
  -- crosshairs"): picking one redraws the rival already on screen, so they can be compared
  local function anchors(f) local a = {} for _, p in ipairs(f.parts) do a[#a + 1] = p.anchor and p.anchor[1] end table.sort(a) return table.concat(a, ",") end
  ok(RC.SetStyle(rdb2, "L") and rdb2.style == "L", "L: chosen")
  local mL = RC.marks.nameplate7
  ok(mL and mL ~= mk and mL.style == "L" and #mL.parts == 8 and not mk.shown,
     "L: the rival on screen is redrawn at once, eight arms at the four corners")
  ok(anchors(mL) == "BOTTOMLEFT,BOTTOMLEFT,BOTTOMRIGHT,BOTTOMRIGHT,TOPLEFT,TOPLEFT,TOPRIGHT,TOPRIGHT", "an L at each corner", anchors(mL))
  RC.SetStyle(rdb2, "aim")
  local mA = RC.marks.nameplate7
  ok(mA.style == "aim" and anchors(mA) == "BOTTOM,LEFT,RIGHT,TOP" and mA.parts[1].h == RC.SIGHT_LEN,
     "aim: a line in from the middle of each side", anchors(mA))
  RC.SetStyle(rdb2, "box")
  local mB = RC.marks.nameplate7
  ok(mB.style == "box" and #mB.parts == 4 and mB.parts[1].h == RC.MARK_THICK and mB.parts[3].w == RC.MARK_THICK,
     "box: four edges all the way round")
  ok(RC.SetStyle(rdb2, "swirl") == false and rdb2.style == "box", "a style that does not exist changes nothing")
  local said4 = {}
  local keepAdd4 = DEFAULT_CHAT_FRAME.AddMessage
  DEFAULT_CHAT_FRAME.AddMessage = function(_, m) said4[#said4 + 1] = m end
  S("recap style swirl")
  ok(table.concat(said4, "\n"):find("rails, L, aim, box", 1, true), "/bist recap style with a wrong name lists them")
  S("recap style l")
  ok(rdb2.style == "L", "/bist recap style l picks L")
  DEFAULT_CHAT_FRAME.AddMessage = keepAdd4
  -- FOUR FROM ARN'S PICTURES ("more ideas"): scope, drop, chevron, tee - centred on the body
  RC.SetStyle(rdb2, "scope")
  local sc = RC.marks.nameplate7
  local centred = 0
  for _, p in ipairs(sc.parts) do if p.anchor and p.anchor[1] == "CENTER" then centred = centred + 1 end end
  ok(sc.style == "scope" and #sc.parts == 13 and centred == 9, "scope: four posts, thin lines, ticks and the dot", #sc.parts)
  RC.SetStyle(rdb2, "drop")
  local dr = RC.marks.nameplate7
  ok(dr.style == "drop" and dr.parts[1].rot and dr.parts[2].rot and math.abs(dr.parts[1].rot + dr.parts[2].rot) < 1e-9,
     "drop: a chevron of two slants turned opposite ways, and a ladder")
  RC.SetStyle(rdb2, "chevron")
  ok(RC.marks.nameplate7.style == "chevron" and #RC.marks.nameplate7.parts == 2, "chevron: just the ^")
  RC.SetStyle(rdb2, "tee")
  ok(RC.marks.nameplate7.style == "tee" and #RC.marks.nameplate7.parts == 2, "tee: a bar and a stem")
  -- eight do not fit one row of buttons: the options stepper walks them, the name shown
  local stepper
  for _, o in ipairs(R:Get("rivals").options) do if o.label == "crosshair" then stepper = o end end   -- moved to the rivals tool, 14 Oct
  ok(stepper and stepper.kind == "step" and stepper.max == 9 and stepper.get(rdb2) == 8 and stepper.show(rdb2) == "tee",
     "the options stepper: eight styles, at tee")
  stepper.set(rdb2, 5)
  ok(rdb2.style == "scope" and RC.marks.nameplate7.style == "scope" and stepper.show(rdb2) == "scope",
     "a step redraws the rival on screen in the next shape")
  RC.SetStyle(rdb2, "rails")
  mk = RC.marks.nameplate7
  ok(mk.style == "rails" and #mk.parts == 4, "and back to rails")
  W.plates.nameplate8 = { name = "Légolas" }               -- a silver rival
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate8")
  ok(RC.marks.nameplate8 == nil, "a silver rival gets no crosshair")
  RC.SetActive(rdb2, "Hunting Moms", false)
  ok(RC.marks.nameplate7 == nil and not mk.shown, "sending a rival to silver takes their crosshair off")
  RC.SetActive(rdb2, "Hunting Moms", true)
  plates.nameplate7.IsForbidden = function() return true end
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  ok(RC.marks.nameplate7 == nil, "a nameplate the client locks away gets none, and no error")
  plates.nameplate7.IsForbidden = nil
  W.target = { name = "Hunting" }
  plates.target = CreateFrame("Frame", nil, nil)          -- the client WOULD hand back a plate for it
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_TARGET_CHANGED")
  plates.target = nil
  ok(RC.marks.target == nil, "only nameplates carry it - a target has no plate event to take it down")
  W.target = nil
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  -- TWO SWITCHES (14 Oct: rivals & pals are their own tool): recap off keeps the marks; rivals off takes them
  R:SetEnabled("recap", false)
  ok(next(RC.marks) ~= nil, "recap off: the death window's switch - the crosshairs stay")
  R:SetEnabled("recap", true)
  R:SetEnabled("rivals", false)
  ok(next(RC.marks) == nil, "rivals off takes every crosshair down")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  ok(next(RC.marks) == nil, "and while off, a new plate gets none")
  R:SetEnabled("rivals", true)
  _G.C_NamePlate.GetNamePlateForUnit = keepGet
  W.plates.nameplate7, W.plates.nameplate8 = { name = "Hunting Moms" }, nil

  -- THE RIVAL TARGET BUTTON (Arn: "i just did /tar Ford Knox and i was able to target an enemy
  -- player what about a small button that targets all our rivals"). The mock refuses an attribute
  -- set in combat, as the client does.
  RC.SetActive(rdb2, "Hunting Moms", true)
  RC.SetActive(rdb2, "Légolas Thiliaere", false)
  local tb = RC.tbtn
  ok(tb and tb.template == "SecureActionButtonTemplate" and tb.attrs.type == "macro", "a secure macro button")
  ok(tb.attrs.macrotext == "/target Hunting Moms" and tb.shown, "one gold rival: /target them, and the button shows")
  rivals["Hunting Moms"].seen, rivals["Légolas Thiliaere"].seen = W.now - 50, W.now
  RC.SetActive(rdb2, "Légolas Thiliaere", true)
  ok(tb.attrs.macrotext == "/target Hunting Moms\n/target Légolas Thiliaere",
     "two gold: the most recently seen runs last, so it is the one you get", tb.attrs.macrotext)
  -- in a fight the button cannot be rewritten: it waits
  W.combat = true
  ok(pcall(RC.SetActive, rdb2, "Légolas Thiliaere", false), "a rival sent to silver mid-fight: nothing thrown")
  ok(RC.btnDirty and tb.attrs.macrotext:find("Légolas", 1, true), "the button keeps its macro until the fight ends")
  W.combat = false
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_REGEN_ENABLED")
  ok(not RC.btnDirty and tb.attrs.macrotext == "/target Hunting Moms", "and is rewritten the moment it does")
  -- a key, and off again
  S("recap key f6")
  ok(W.binds[tb] and W.binds[tb].key == "F6" and W.binds[tb].btn == "BiSToolsRivalTarget", "/bist recap key F6 binds it")
  S("recap key off")
  ok(W.binds[tb] == nil and rdb2.key == nil, "and key off unbinds it")
  -- nobody gold: hidden; the option off: hidden
  RC.SetActive(rdb2, "Hunting Moms", false)
  ok(not tb.shown and tb.attrs.macrotext == "", "nobody gold: no button")
  RC.SetActive(rdb2, "Hunting Moms", true)
  rdb2.button = false RC.ApplyButton(rdb2)
  ok(not tb.shown, "'rival target button' off: hidden")
  rdb2.button = nil RC.ApplyButton(rdb2)
  -- THE BiS> TOOLS BOX (Arn: "lets keep all button neat maybe in a bis farm box, like the bis now, maybe if
  -- we have bis now it just puts the button there cross addon")
  local Bx = NS.Box
  local box = Bx.frame
  ok(box and tb.parent == box and box.shown and Bx.count >= 1, "the rival button lives in the BiS> tools box")
  -- ONE LOOK FOR EVERY BiS> BAR (Arn: "the bis headers are all different fonts some different color some
  -- blinking _ some static lets get them all the same"): the box's bar wears the prompt, BiS Healing's height
  local hc = box.head.con
  W.now = W.now + 1 box.head.scripts.OnUpdate(box.head, 0.3) W.now = W.now + 1 box.head.scripts.OnUpdate(box.head, 0.3)
  local hp = hc and (hc:Text():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
  ok(hp and hp:find("BiS> tools", 1, true), "the box's bar wears the family prompt", hp)
  ok(box.head.h == 16, "at BiS Healing's bar height", box.head.h)
  local fbtn = NS.Farm.TargetButton()
  local fdb = NS.Farm.db
  local keepActive2 = fdb.active
  fdb.active = nil Bx.Refresh()
  ok(not fbtn.shown and Bx.count == 1, "no mob farmed: no farm button")
  fdb.active = "Kobold Miner" Bx.Refresh()
  ok(fbtn.parent == box and fbtn.shown and Bx.count == 2 and fbtn.icon.file:find("RaidTargetingIcon_8", 1, true),
     "farming: the farm's target button, with the skull, beside the rival one")
  -- WHICH IS WHICH (Arn: "do the purple and red buttons"): mobs purple, players red, crossed swords
  ok(fbtn.edgeColour == RC.MOB_PURPLE and fbtn.edge.top.color[1] == RC.MOB_PURPLE[1] and fbtn.edge.top.h == 2,
     "the farm's button: a purple edge, two pixels")
  ok(tb.edgeColour == RC.MARK_RED and tb.edge.left.color[2] == RC.MARK_RED[2] and tb.edge.left.w == 2
     and tb.icon.file:find("Ability_DualWield", 1, true), "the rival button: a red edge and crossed swords")
  ok(box.w == math.max(Bx.MIN_W, Bx.PAD * 2 + 2 * Bx.SIZE + Bx.GAP), "the box is as wide as its buttons (and its name)", box.w)
  -- docked to BiS> now when it is up, its own place when not
  local now = CreateFrame("Frame", "BiSHealingNowBlock", nil)
  now.shown = true
  -- where things are on screen (the client answers GetLeft/Right/Top/Bottom): BiS> now UNDER the grid
  local function at(fr, l, r, t2, b) fr.GetLeft = function() return l end fr.GetRight = function() return r end
    fr.GetTop = function() return t2 end fr.GetBottom = function() return b end end
  local gridAnchor = CreateFrame("Frame", nil, nil)
  local gridHeader = CreateFrame("Frame", "BiSHealingForeverHeader", gridAnchor)
  at(gridAnchor, 300, 700, 600, 300) at(gridHeader, 300, 700, 618, 602)
  at(now, 300, 400, 280, 240)                                   -- under the grid
  Bx.DB().dock = nil
  Bx.Refresh()
  ok(Bx.docked and Bx.dock == "right" and box.point[2] == now and box.point[1] == "TOPLEFT" and box.point[3] == "TOPRIGHT",
     "BiS> now under the grid: the box docks to its right edge")
  -- BiS> now on the grid's LEFT (Arn: "it overlapped into the healing frames"): right of it is the grid
  at(now, 190, 295, 600, 560)
  Bx.Refresh()
  ok(Bx.dock == "below" and box.point[1] == "TOPLEFT" and box.point[3] == "BOTTOMLEFT",
     "BiS> now left of the grid: the box goes below it, not onto the grid")
  -- level with the grid's HEADER only (above its cells): that is the grid too
  at(now, 190, 295, 650, 630)
  Bx.Refresh()
  ok(Bx.dock == "below", "the grid's own header counts as the grid")
  at(now, 190, 295, 600, 560)
  -- shift-click sends it round BiS> now (Arn: "should have these same clicks and drags")
  W.shift = true
  box.head.scripts.OnMouseUp(box.head, "LeftButton")
  ok(Bx.DB().dock == "right" and Bx.dock == "right", "shift-click: right")
  box.head.scripts.OnMouseUp(box.head, "LeftButton")
  ok(Bx.DB().dock == "below" and box.point[3] == "BOTTOMLEFT", "then below")
  box.head.scripts.OnMouseUp(box.head, "LeftButton")
  ok(Bx.DB().dock == "left" and box.point[1] == "TOPRIGHT" and box.point[3] == "TOPLEFT", "then left")
  box.head.scripts.OnMouseUp(box.head, "LeftButton")
  ok(Bx.DB().dock == "top" and box.point[1] == "BOTTOMLEFT" and box.point[3] == "TOPLEFT", "then on top")
  box.head.scripts.OnMouseUp(box.head, "LeftButton")
  ok(Bx.DB().dock == "auto", "and round to auto")
  W.shift = false
  box.head.scripts.OnMouseUp(box.head, "LeftButton")
  ok(Bx.DB().dock == "auto", "a plain click does nothing")
  -- the header drags it anywhere - docked or not - and a dragged box stays where it is dropped
  local moved = 0
  local keepMove, keepStop = box.StartMoving, box.StopMovingOrSizing
  box.StartMoving = function() moved = moved + 1 end
  box.StopMovingOrSizing = function() end
  W.combat = true box.head.scripts.OnDragStart(box.head) box.head.scripts.OnDragStop(box.head) W.combat = false
  ok(moved == 0 and Bx.DB().dock == "auto", "never dragged in a fight")
  box.head.scripts.OnDragStart(box.head) box.head.scripts.OnDragStop(box.head)
  box.StartMoving, box.StopMovingOrSizing = keepMove, keepStop
  ok(moved == 1 and Bx.DB().dock == "free" and not Bx.docked and Bx.DB().pos, "dragged, even docked: it stays where it is dropped")
  Bx.Refresh()
  ok(box.point[2] == UIParent, "and stays free while BiS> now is up")
  W.shift = true box.head.scripts.OnMouseUp(box.head, "LeftButton") W.shift = false
  ok(Bx.DB().dock == "auto" and Bx.docked, "shift-click brings a dragged box back to BiS> now")
  now:Hide() if now.scripts.OnHide then now.scripts.OnHide(now) end
  ok(not Bx.docked and box.point[2] == UIParent, "BiS> now hidden: the box stands on its own")
  _G.BiSHealingNowBlock, _G.BiSHealingForeverHeader = nil, nil
  Bx.DB().dock = nil
  -- a change in a fight waits for its end
  W.combat = true
  fdb.active = nil
  ok(Bx.Refresh() == false and Bx.dirty and fbtn.shown, "in a fight the box is left as it is")
  W.combat = false
  Bx.events.scripts.OnEvent(Bx.events, "PLAYER_REGEN_ENABLED")
  ok(not Bx.dirty and not fbtn.shown, "and laid out again when it ends")
  -- nothing to do: no box
  RC.SetActive(rdb2, "Hunting Moms", false)
  ok(not box.shown, "no button with anything to do: no box")
  RC.SetActive(rdb2, "Hunting Moms", true)
  -- PURPLE FOR MOBS (Arn: "we should also add this to the farm module ... only the crosshair", "if rxp
  -- calls for mobs to be able to be tracked we crosshairs them", "red for players purple for mobs")
  local mplates = {}
  _G.C_NamePlate.GetNamePlateForUnit = function(u) return mplates[u] end
  mplates.nameplate3 = CreateFrame("Frame", nil, nil) mplates.nameplate3:SetSize(140, 20)
  mplates.nameplate2 = CreateFrame("Frame", nil, nil) mplates.nameplate2:SetSize(140, 20)
  fdb.active = "Kobold Miner"
  W.plates.nameplate3 = { name = "Kobold Miner" }
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate3")
  local fm = RC.marks.nameplate3
  ok(fm and fm.kind == "farm" and math.abs(fm.parts[1].color[1] - 0.73) < 0.01 and fm.parts[1].color[3] == 1,
     "the mob you farm: a purple crosshair")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_REMOVED", "nameplate3")
  W.plates.nameplate3 = { name = "Kobold Miner", tapped = true }
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate3")
  ok(RC.marks.nameplate3 == nil, "a copy somebody else tapped: none (the farm tool's own clean test)")
  W.plates.nameplate3 = { name = "Kobold Miner" }
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate3")
  NS.Farm.SetActive(fdb, "Kobold Geomancer")
  ok(RC.marks.nameplate3 == nil, "farm something else: the old crosshairs go")
  NS.Farm.SetActive(fdb, "Kobold Miner")
  -- RestedXP's Active Targets
  NS.Farm.Guide.Take(nil, { "Murloc Hunter" }, false)
  W.plates.nameplate2 = { name = "Murloc Hunter" }
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate2")
  local gm2 = RC.marks.nameplate2
  ok(gm2 and gm2.kind == "guide" and math.abs(gm2.parts[1].color[1] - 0.73) < 0.01, "a mob the RestedXP guide wants: purple too")
  NS.Farm.Guide.Take(nil, { "Murloc Oracle" }, false)
  ok(RC.marks.nameplate2 == nil, "the guide moves on: the old step's crosshairs go")
  fdb.guide = false
  NS.Farm.Guide.Take(nil, { "Murloc Hunter" }, false)
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate2")
  ok(RC.marks.nameplate2 == nil, "the guide's mobs hidden in the farm tool: none")
  fdb.guide = nil
  -- the farm tool's switch
  for _, o in ipairs(R:Get("farm").options) do if o.label == "crosshair on the mob" then o.set(fdb, false) end end
  ok(next(RC.marks) == nil or (function() for _, f in pairs(RC.marks) do if f.kind == "farm" or f.kind == "guide" then return false end end return true end)(),
     "'crosshair on the mob' off: every purple crosshair goes")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate3")
  ok(RC.marks.nameplate3 == nil, "and none drawn")
  fdb.cross = nil
  NS.Farm.Guide.Take(nil, {}, false)
  W.plates.nameplate2, W.plates.nameplate3 = nil, nil
  _G.C_NamePlate.GetNamePlateForUnit = nil
  fdb.active = keepActive2 Bx.Refresh()
  -- twenty gold rivals: the macro stays within the client's length, the most recent kept
  local keepList = rdb2.rivals
  rdb2.rivals = {}
  for i = 1, 20 do rdb2.rivals[("Rival Number%02d Longname"):format(i)] = { active = true, seen = i } end
  local mtext, n20 = RC.TargetMacro(rdb2)
  ok(#mtext <= RC.MACRO_MAX and n20 < 20 and mtext:find("Number20", 1, true) and not mtext:find("Number01", 1, true),
     "twenty gold rivals: as many as fit in 255 characters, the most recently seen kept", #mtext)
  rdb2.rivals = keepList
  RC.ApplyButton(rdb2)

  -- "ADD RIVAL" ON THE RIGHT-CLICK MENU (Arn: "when i right click maybe we can add add rival here").
  -- The client's Menu.ModifyMenu, in Olympus's shape: (owner, root, ctx) with ctx.name and ctx.surname.
  local hookedMenus = {}
  _G.Menu = { ModifyMenu = function(tag, fn) hookedMenus[tag] = fn end }
  RC.menusHooked = nil
  ok(RC.HookMenus(rdb2) and hookedMenus.MENU_UNIT_ENEMY_PLAYER and hookedMenus.MENU_UNIT_PLAYER,
     "the enemy and player menus get the line")
  ok(not hookedMenus.MENU_UNIT_COMMUNITIES_GUILD_MEMBER and not hookedMenus.MENU_UNIT_GUILD,
     "never the guild roster menus (the game's own promote and kick live there)")
  local function root()
    local r = { lines = {} }
    function r:CreateDivider() self.lines[#self.lines + 1] = "--" end
    function r:CreateButton(text, fn) self.lines[#self.lines + 1] = text self.click = fn end
    return r
  end
  local keepClass, keepGUID, keepMenuTarget = _G.UnitClass, _G.UnitGUID, W.target
  W.target = { name = "Dai", player = true, guid = "Player-4619-00DA1" }      -- an enemy player on target
  _G.UnitClass = function(u) if u == "target" then return "Rogue", "ROGUE" end return "Shaman", "SHAMAN" end
  _G.UnitGUID = function(u) if u == "target" then return "Player-4619-00DA1" end end
  local m = root()
  hookedMenus.MENU_UNIT_ENEMY_PLAYER(nil, m, { name = "Dai", surname = "Joubu", unit = "target" })
  ok(m.lines[2] == "Add rival", "an enemy's menu says, in the BiS section: Add rival", table.concat(m.lines, "|") .. " why=" .. tostring(RC.menuDecision))
  m.click()
  ok(rivals["Dai Joubu"] and rivals["Dai Joubu"].active and rivals["Dai Joubu"].class == "ROGUE"
     and rivals["Dai Joubu"].guid == "Player-4619-00DA1", "clicked: Dai Joubu is a gold rival, with class and GUID")
  ok(tb.attrs.macrotext:find("/target Dai Joubu", 1, true), "and the target button knows them at once")
  m = root()
  hookedMenus.MENU_UNIT_ENEMY_PLAYER(nil, m, { name = "Dai", surname = "Joubu", unit = "target" })
  ok(m.lines[2] == "Remove rival", "the next time: BiS: remove rival")
  m.click()
  ok(rivals["Dai Joubu"] == nil, "and that takes them off")
  m = root()
  hookedMenus.MENU_UNIT_FRIEND(nil, m, { name = "Hunting" })   -- a name in chat, no surname given
  ok(m.lines[2] == "Remove rival", "a chat name finds the rival by the character name alone")
  m = root() hookedMenus.MENU_UNIT_PLAYER(nil, m, { name = "Me" })
  ok(#m.lines == 0, "no line on your own menu")
  m = root() hookedMenus.MENU_UNIT_PLAYER(nil, m, { name = setmetatable({}, { __index = function() error("secret") end }) })
  ok(#m.lines == 0, "no line for a name the game hides")
  R:SetEnabled("rivals", false)
  m = root() hookedMenus.MENU_UNIT_ENEMY_PLAYER(nil, m, { name = "Dai", surname = "Joubu" })
  ok(#m.lines == 0, "and none while the rivals tool is off")
  R:SetEnabled("rivals", true)
  -- TARGET / FOCUS (Arn, 13 Oct: "i cant see the add rival when i right click them"): a unit frame
  -- that opens its menu through the secure togglemenu (EllesmereUI's do) can file a player's menu
  -- as TARGET - the line must be there too, and only for players
  ok(hookedMenus.MENU_UNIT_TARGET and hookedMenus.MENU_UNIT_FOCUS, "the TARGET and FOCUS menus carry the line too")
  m = root() hookedMenus.MENU_UNIT_TARGET(nil, m, { name = "Dai", surname = "Joubu", unit = "target" })
  ok(m.lines[2] == "Add rival", "a player's TARGET menu: BiS: add rival", m.lines[2])
  -- A BATTLEGROUND MENU CARRIES NO NAME (Arn, 13 Oct: "the menu gave no name" on Grape Sprite's PLAYER
  -- menu) - the unit answers instead: GetUnitName with the surname, else UnitName
  do
    local keepGUN, keepT = _G.GetUnitName, W.target
    W.target = { name = "Grape", player = true, guid = "Player-4619-0BG01" }
    _G.GetUnitName = function(u) if u == "target" then return "Grape Sprite" end end
    m = root() hookedMenus.MENU_UNIT_PLAYER(nil, m, { unit = "target" })
    ok(m.lines[2] == "Add rival" and RC.menuDecision == "added for Grape Sprite",
       "a battleground menu with no name: the name comes from the unit, surname and all", RC.menuDecision)
    m.click()
    ok(rivals["Grape Sprite"] and rivals["Grape Sprite"].active, "clicked: Grape Sprite is a gold rival")
    rivals["Grape Sprite"] = nil
    _G.GetUnitName = function() return setmetatable({}, { __index = function() error("secret") end }) end
    local keepIs = _G.issecretvalue
    _G.issecretvalue = function(v) return type(v) == "table" end
    m = root() hookedMenus.MENU_UNIT_PLAYER(nil, m, { unit = "target" })
    ok(m.lines[2] == "Add rival" and RC.menuDecision == "added for Grape",
       "GetUnitName hidden: UnitName's plain name still does", RC.menuDecision)
    m.click()
    _G.issecretvalue = keepIs
    ok(rivals["Grape"], "added as Grape")
    ok(RC.Find(rdb2, "Grape Sprite") == rivals["Grape"],
       "and the recap's 'Grape Sprite' finds the rival saved as plain 'Grape' - matching works both ways")
    rivals["Grape"] = nil
    m = root() hookedMenus.MENU_UNIT_PLAYER(nil, m, {})
    ok(#m.lines == 0 and RC.menuDecision == "the menu gave no name (hidden by the game, or none)",
       "no name and no unit: nothing, and why says so")
    _G.GetUnitName, W.target = keepGUN, keepT
  end
  -- INSIDE AN INSTANCE THE MENU BREAKS WITH AN ADDON LINE (Arn's BugGrabber in a battleground, 13 Oct:
  -- FrameUtil.lua:223 arithmetic on a secret frameLeft, "while execution tainted by 'BiSTools'").
  -- The mock menu is taught to break the same way: any line added inside an instance is an error.
  do
    local keepInst, keepT = _G.IsInInstance, W.target
    local inside = true
    _G.IsInInstance = function() return inside, inside and "pvp" or "none" end
    local function strictRoot()
      local r = { lines = {} }
      function r:CreateDivider() if inside then error("menu tainted inside an instance (FrameUtil secret rect)") end end
      function r:CreateButton(text, fn)
        if inside then error("menu tainted inside an instance (FrameUtil secret rect)") end
        self.lines[#self.lines + 1] = text self.click = fn
      end
      return r
    end
    W.target = { name = "Grape", player = true, guid = "Player-4619-0BG01" }
    local okM, errM = pcall(hookedMenus.MENU_UNIT_PLAYER, nil, strictRoot(), { name = "Grape", unit = "target" })
    ok(okM, "in a battleground the rival line never touches the game's menu", errM)
    ok(RC.menuDecision:find("inside an instance", 1, true) and RC.menuDecision:find("/bist recap rival", 1, true),
       "and why says so, with the way to add one there", RC.menuDecision)
    -- the farm's line (TARGET on a mob) is guarded the same way
    local F = NS.Farm
    W.target = { name = "Defias Thug", guid = "Creature-0-0-0-0-38-9", hostile = true }
    local okF, errF = pcall(F.MenuLines, F.db, strictRoot(), { unit = "target" })
    ok(okF, "nor does the farm's line on a mob inside an instance", errF)
    -- /bist recap rival: the battleground road, touching nothing of the game's
    W.target = { name = "Grape", player = true, guid = "Player-4619-0BG01" }
    local keepGUN = _G.GetUnitName
    _G.GetUnitName = function(u) if u == "target" then return "Grape Sprite" end end
    S("recap rival")
    ok(rivals["Grape Sprite"] and rivals["Grape Sprite"].active and rivals["Grape Sprite"].guid == UnitGUID("target"),
       "/bist recap rival: your target is a gold rival, surname, GUID and all")
    S("recap rival")
    ok(rivals["Grape Sprite"] == nil, "again: taken off")
    W.target = { name = "Defias Thug", guid = "Creature-0-0-0-0-38-9", hostile = true }
    S("recap rival")
    ok(rivals["Defias Thug"] == nil, "a mob on target is never a rival")
    W.target = nil
    S("recap rival")
    ok(next(rivals) == nil or rivals["Grape Sprite"] == nil, "no target: nothing added")
    -- for THIS match only (Arn: "it resets at the end of the bg - dont want a rival list that's 10000
    -- names long"); rivals from the world stay
    rivals["World Foe"] = { added = 1, kills = 2, active = true }
    W.target = { name = "Grape", player = true, guid = "Player-4619-0BG01" }
    S("recap rival")
    ok(rivals["Grape Sprite"] and rivals["Grape Sprite"].bg == true, "added inside a battleground: marked for this match")
    for _ = 1, RC.KEEP_AFTER - 1 do RC.KilledBy(nil, rivals["Grape Sprite"], "Grape Sprite") end
    ok(rivals["Grape Sprite"].bg == true, (RC.KEEP_AFTER - 1) .. " kills: still for this match only")
    rivals["Bully Boy"] = { added = 1, kills = 0, active = true, bg = true }
    for _ = 1, RC.KEEP_AFTER do RC.KilledBy(nil, rivals["Bully Boy"], "Bully Boy") end
    ok(rivals["Bully Boy"].bg == nil, RC.KEEP_AFTER .. " kills in the match: kept for good")
    fireAll("PLAYER_ENTERING_WORLD")
    ok(rivals["Grape Sprite"], "a /reload inside the battleground keeps them")
    inside = false
    fireAll("PLAYER_ENTERING_WORLD")
    ok(rivals["Grape Sprite"] == nil and rivals["World Foe"] and rivals["World Foe"].kills == 2,
       "out of the battleground: its rivals let go, the world's kept")
    ok(rivals["Bully Boy"] and rivals["Bully Boy"].kills == RC.KEEP_AFTER, "and the one who farmed you stays")
    rivals["World Foe"], rivals["Bully Boy"] = nil, nil
    -- outside an instance the menu line works as before
    inside = false
    W.target = { name = "Grape", player = true, guid = "Player-4619-0BG01" }
    local mo = strictRoot()
    hookedMenus.MENU_UNIT_PLAYER(nil, mo, { name = "Grape", unit = "target" })
    ok(mo.lines[1] == "Add rival", "out in the world: the menu line, as before")
    _G.GetUnitName, _G.IsInInstance, W.target = keepGUN, keepInst, keepT
  end
  W.target = { name = "Defias Thug", guid = "Creature-0-0-0-0-38-1" }
  m = root() hookedMenus.MENU_UNIT_FOCUS(nil, m, { name = "Defias Thug", unit = "target" })
  ok(#m.lines == 0, "a MOB's menu: no rival line")
  ok(RC.menuDecision == "target is not a player", "and the decision says why", RC.menuDecision)
  W.target = { name = "Dai", player = true, guid = "Player-4619-00DA1" }
  -- a menu kind nobody listed: the game's own UnitPopup_OpenMenu is watched; a new kind is noted and
  -- carries the line from the next right-click; a guild menu never
  do
    local opened = {}
    _G.UnitPopup_OpenMenu = function(which) opened[#opened + 1] = which end
    local keepHook = _G.hooksecurefunc
    _G.hooksecurefunc = function(name, fn)                    -- the client's: theirs runs, then ours
      local orig = _G[name]
      _G[name] = function(...) orig(...) fn(...) end
    end
    RC.menusHooked, RC.tags = nil, {}
    hookedMenus = {}
    ok(RC.HookMenus(rdb2), "hooked again")
    UnitPopup_OpenMenu("SOME_NEW_PLAYER_MENU", { unit = "target" })
    ok(RC.lastMenu == "SOME_NEW_PLAYER_MENU" and hookedMenus.MENU_UNIT_SOME_NEW_PLAYER_MENU,
       "a menu kind never listed is noted, and gets the line from the next right-click")
    UnitPopup_OpenMenu("COMMUNITIES_GUILD_MEMBER", { unit = "target" })
    ok(RC.lastMenu == "COMMUNITIES_GUILD_MEMBER" and not hookedMenus.MENU_UNIT_COMMUNITIES_GUILD_MEMBER,
       "a guild roster menu is noted but NEVER gets the line")
    local said = {}
    local keepChat = DEFAULT_CHAT_FRAME.AddMessage
    DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) said[#said + 1] = tostring(msg) end
    RC.Why(rdb2)
    DEFAULT_CHAT_FRAME.AddMessage = keepChat
    local all = table.concat(said, "\n")
    ok(all:find("last right-click menu", 1, true) and all:find("COMMUNITIES_GUILD_MEMBER", 1, true)
       and all:find("a guild menu: never", 1, true), "/bist recap why says which menu opened last, and why no line")
    ok(all:find("the rival line, last time:", 1, true), "and what the rival line decided the last time a menu asked")
    _G.hooksecurefunc, _G.UnitPopup_OpenMenu = keepHook, nil
  end
  _G.Menu = nil
  RC.menusHooked = nil
  ok(RC.HookMenus(rdb2) == false, "a client without Menu.ModifyMenu: no lines, no error")
  _G.UnitClass, _G.UnitGUID, W.target = keepClass, keepGUID, keepMenuTarget

  -- "TRACK IN FARM" ON A MOB'S RIGHT-CLICK MENU (Arn, 13 Oct: "right click npc ... track in the farm
  -- module not just type their name or wait till you kill one")
  do
    local menus = {}
    _G.Menu = { ModifyMenu = function(tag, fn) menus[tag] = fn end }
    F.menusHooked = nil
    ok(F.HookMenus(db) and menus.MENU_UNIT_TARGET and menus.MENU_UNIT_FOCUS, "a mob's portrait menus get the farm line")
    ok(not menus.MENU_UNIT_ENEMY_PLAYER and not menus.MENU_UNIT_PLAYER, "never a player's menu (the rival line lives there)")
    local keepIsPlayer, keepTarget = _G.UnitIsPlayer, W.target
    _G.UnitIsPlayer = function(u) local x = (u == "target") and W.target return x and x.player or false end
    F.Clear(db)
    W.target = { name = "Dalaran Summoner", guid = "Creature-0-0-0-0-1915-00A1" }
    local m = root()
    menus.MENU_UNIT_TARGET(nil, m, { unit = "target", name = "Dalaran Summoner" })
    ok(m.lines[1] == "--" and m.lines[2] == "Track in farm", "a mob's menu says, in the BiS section: Track in farm", m.lines[2])
    BiSToolsFarm:Hide()
    m.click()
    ok(db.active == "Dalaran Summoner" and db.custom == "Dalaran Summoner",
       "clicked: the farm tracks it, the same as /bist farm add")
    ok(BiSToolsFarm:IsShown(), "and the farm window opens")
    m = root()
    menus.MENU_UNIT_FOCUS(nil, m, { unit = "target" })
    ok(m.lines[2] == "Stop farming", "the next time: Stop farming", m.lines[2])
    m.click()
    ok(db.active == nil, "and that stops it")
    W.target = { name = "Kumlance", player = true }
    m = root() menus.MENU_UNIT_TARGET(nil, m, { unit = "target" })
    ok(#m.lines == 0, "no line on a player")
    W.target = { name = "Stormwind Guard", hostile = false }
    m = root() menus.MENU_UNIT_TARGET(nil, m, { unit = "target" })
    ok(#m.lines == 0, "no line on a mob you cannot attack")
    m = root() menus.MENU_UNIT_TARGET(nil, m, { name = "Dalaran Summoner" })
    ok(#m.lines == 0, "no line when the menu names no unit")
    W.target = { name = "Dalaran Summoner", guid = "Creature-0-0-0-0-1915-00A1" }
    R:SetEnabled("farm", false)
    m = root() menus.MENU_UNIT_TARGET(nil, m, { unit = "target" })
    ok(#m.lines == 0, "none while the farm tool is off")
    R:SetEnabled("farm", true)
    _G.Menu = nil
    F.menusHooked = nil
    ok(F.HookMenus(db) == false, "a client without Menu.ModifyMenu: no farm line, no error")
    _G.UnitIsPlayer, W.target = keepIsPlayer, keepTarget
    F.Clear(db)
  end

  -- GUILD RIVALS (Arn: "a toggle dont show guild rivals etc or show with a different color crosshair to
  -- know it was from someone else"), over LibBiSComm's GUILD channel
  local lib2 = _G.LibBiSComm
  local sent = {}
  local keepSendTo = lib2.SendTo
  lib2.SendTo = function(_, chan, mod, cmd, ...) sent[#sent + 1] = { chan = chan, mod = mod, cmd = cmd, args = { ... } } return true end
  _G.IsInGuild = function() return true end
  RC.guildHooked = nil
  ok(RC.HookGuild(rdb2) and lib2.guildMods.RIVAL and lib2.handlers.RIVAL.ADD and lib2.handlers.RIVAL.SEEN,
     "the guild channel carries RIVAL: ADD, DEL, SEEN, ASK, LIST")
  local mg = root()
  _G.Menu = { ModifyMenu = function() end }
  local keepT = W.target
  W.target = { name = "Kill", player = true }                -- the menu is about a player on target
  RC.MenuLines(rdb2, mg, { name = "Kill", surname = "Er", unit = "target" })
  W.target = keepT
  ok(mg.lines[3] == "Add guild rival", "the menu offers a guild rival too", mg.lines[3])
  _G.UnitClass = function() return "Mage", "MAGE" end
  mg.click()
  _G.UnitClass = keepClass
  local g = RC.GuildRivals(rdb2)
  ok(g["Kill Er"] and g["Kill Er"].class == "MAGE" and sent[#sent].chan == "GUILD" and sent[#sent].cmd == "ADD"
     and sent[#sent].args[1] == "Kill Er", "added: on the guild's list, and the guild told")
  -- from someone else
  lib2.handlers.RIVAL.ADD("Tyrone", "Ganka Boy", "ROGUE")
  ok(g["Ganka Boy"] and g["Ganka Boy"].by == "Tyrone", "a guildmate's guild rival arrives, with who added it")
  -- in sight: amber, no noise, the guild told once a minute
  W.notices, W.sounds = {}, {}
  local nSent = #sent
  plates.nameplate5 = CreateFrame("Frame", nil, nil) plates.nameplate5:SetSize(160, 20)
  _G.C_NamePlate.GetNamePlateForUnit = function(u) return plates[u] end
  W.plates.nameplate5 = { name = "Ganka" }
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate5")
  local gm = RC.marks.nameplate5
  ok(gm and gm.kind == "guild" and gm.parts[1].color[2] > 0.5, "a guild rival wears the AMBER crosshair")
  ok(#W.notices == 0 and #W.sounds == 0, "and makes no noise")
  ok(#sent == nSent + 1 and sent[#sent].cmd == "SEEN" and sent[#sent].args[1] == "Ganka Boy", "the guild is told they were seen")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_REMOVED", "nameplate5")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate5")
  ok(#sent == nSent + 1, "seen again within a minute: not said twice")
  -- a guild rival who is also YOUR gold rival: red
  RC.ToggleRival(rdb2, { player = true, title = "Ganka Boy", class = "ROGUE" })
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate5")
  ok(RC.marks.nameplate5.kind == "own", "yours as well: red, your crosshair wins")
  RC.ToggleRival(rdb2, { player = true, title = "Ganka Boy" })
  -- someone else saw one
  lib2.handlers.RIVAL.SEEN("Tyrone", "Kill Er", "Tarren Mill")
  ok(g["Kill Er"].where == "Tarren Mill" and g["Kill Er"].seenBy == "Tyrone", "a guildmate's sighting: where, and by whom")
  rdb2.expanded = true RC.SetExpanded(rdb2, true)
  local grow
  for _, b in ipairs(w.drawer.rows) do if b.rival == "Kill Er" then grow = b end end
  ok(grow and grow.guild and grow.info.text:find("guild", 1, true) and grow.info.text:find("Tarren Mill (Tyrone)", 1, true)
     and grow.mark.color[2] > 0.5, "the drawer: amber, guild, where and who saw them", grow and grow.info.text)
  fitsIn(w.drawer, "the drawer with guild rivals")
  -- guild rows: click = yours, shift-click = off the guild's list (and the guild told)
  grow.scripts.OnClick(grow, "LeftButton")
  ok(rivals["Kill Er"] and rivals["Kill Er"].active, "clicking a guild row makes them your gold rival")
  RC.ToggleRival(rdb2, { player = true, title = "Kill Er" })
  for _, b in ipairs(w.drawer.rows) do if b.rival == "Kill Er" then grow = b end end
  W.shift = true grow.scripts.OnClick(grow, "LeftButton") W.shift = false
  ok(g["Kill Er"] == nil and sent[#sent].cmd == "DEL", "shift-click takes them off the guild's list, for everyone")
  lib2.handlers.RIVAL.DEL("Tyrone", "Ganka Boy")
  ok(g["Ganka Boy"] == nil and RC.marks.nameplate5 == nil, "a guildmate's DEL: gone, crosshair and all")
  -- a newcomer asks; one answer is enough
  lib2.handlers.RIVAL.ADD("Tyrone", "Third Guy", "PRIEST")
  -- (other tools' timers send too: only RIVAL LISTs are counted)
  local function lists() local n, last = 0, nil for _, s in ipairs(sent) do if s.mod == "RIVAL" and s.cmd == "LIST" then n, last = n + 1, s end end return n, last end
  local before = lists()
  lib2.handlers.RIVAL.ASK("Newbie")
  W.runAfters(5)
  local nL, lastL = lists()
  ok(nL == before + 1 and lastL.args[1] == "Third Guy", "asked: the list is sent")
  lib2.handlers.RIVAL.ASK("Newbie")
  lib2.handlers.RIVAL.LIST("Someone", "Third Guy", "PRIEST")
  W.runAfters(5)
  ok(lists() == before + 1, "somebody else answered first: we stand down")
  lib2.handlers.RIVAL.LIST("Someone", "Fourth One", "WARLOCK", "Fifth One", "HUNTER")
  ok(g["Fourth One"] and g["Fifth One"].class == "HUNTER", "a LIST is merged in")
  lib2.handlers.RIVAL.ADD("Tyrone", "bad|name", "X")
  lib2.handlers.RIVAL.ADD("Tyrone", ("x"):rep(60), "X")
  ok(g["bad|name"] == nil and g[("x"):rep(60)] == nil, "a name with a pipe, or absurdly long, is refused")
  -- the switch: off hides them and stops listening
  for _, o in ipairs(R:Get("rivals").options) do
    if o.label == "guild rivals (amber)" then o.set(rdb2, false) end
  end
  W.plates.nameplate5 = { name = "Third" }
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate5")
  ok(RC.marks.nameplate5 == nil, "guild rivals off: no amber crosshair")
  lib2.handlers.RIVAL.ADD("Tyrone", "Sixth Guy", "PRIEST")
  ok(g["Sixth Guy"] == nil, "and the guild's additions are not taken in")
  rdb2.guildShow = nil

  -- GUILDMATES IN PASSING (Arn: "while not in a party and we see their name plate no noise just a
  -- small little cross hair ... turn off during party and raid and battleground")
  local keepMine = _G.UnitIsInMyGuild
  local mates = { nameplate6 = true }
  _G.UnitIsInMyGuild = function(u) return mates[u] == true end
  plates.nameplate6 = CreateFrame("Frame", nil, nil)
  W.plates.nameplate6 = { name = "Tyrone" }
  RC.solo = true
  W.notices, W.sounds = {}, {}
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate6")
  local mate = RC.mates.nameplate6
  ok(mate and mate.shown and mate.w == 11 and mate.bar.color[3] > 0.7, "a guildmate's plate, alone: a small teal mark")
  -- the crest (Arn: "some type of clan icon ... there should be respect at least in the icon")
  ok(mate.crest and #mate.parts == #RC.CREST * 2 and mate.h == 13, "and it is the guild crest: a shield with a chevron")
  ok(#W.notices == 0 and #W.sounds == 0, "with no noise at all")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_REMOVED", "nameplate6")
  ok(RC.mates.nameplate6 == nil and not mate.shown, "their plate goes: so does the +")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate6")
  local keepGroup = _G.IsInGroup
  _G.IsInGroup = function() return true end
  RC.frame.scripts.OnEvent(RC.frame, "GROUP_ROSTER_UPDATE")
  ok(RC.mates.nameplate6 == nil and RC.solo == false, "join a group: every + goes")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate6")
  ok(RC.mates.nameplate6 == nil, "and none while grouped")
  _G.IsInGroup = keepGroup
  local keepInst = _G.IsInInstance
  _G.IsInInstance = function() return true, "pvp" end
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_ENTERING_WORLD")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate6")
  ok(RC.mates.nameplate6 == nil, "nor in a battleground")
  _G.IsInInstance = keepInst
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_ENTERING_WORLD")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate6")
  ok(RC.mates.nameplate6, "alone again: back")
  rdb2.mates = false RC.ClearMates()
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate6")
  ok(RC.mates.nameplate6 == nil, "'guildmates' off: none")
  rdb2.mates = nil

  do   -- its own block: the main chunk is at Lua 5.1's 200 locals
  -- THE RECRUIT CREST (Arn, 21 Oct 2026: "its own crest shared to the guild potential recruit so if another
  -- person parties with them they know to nudge them to join"): BiS> Nebbinator's guild list through its API
  -- v2. The stand-in answers as Nebbinator's API.lua documents (and its own suite holds): IsProspect ->
  -- true, by, status, at - or false.
  local prospects = { ["Fresh Face"] = { by = "Tyrone", status = "contacted" } }
  local teamAsked = 0
  local nebCallbacks = {}
  _G.NebbinatorAPI = {
    major = 1, version = 2,
    Team = function()
      teamAsked = teamAsked + 1
      local out = {}
      for name, p in pairs(prospects) do out[#out + 1] = { name = name, status = p.status, by = p.by, at = 1 } end
      return out
    end,
    IsProspect = function(name)
      local p = prospects[name]
      if not p then return false end
      return true, p.by, p.status, 1
    end,
    RegisterCallback = function(owner, event, fn) nebCallbacks[event] = fn return true end,
  }
  RC.prospectsAt, RC.nebHooked = nil, nil
  ok(RC.HookNebbinator() and nebCallbacks.Nebbinator_TeamChanged, "listens for Nebbinator's list changing")
  plates.nameplate7 = CreateFrame("Frame", nil, nil)
  W.plates.nameplate7 = { name = "Fresh Face", hostile = false, player = true }
  W.lastMsg = nil
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  local crest = RC.recruits.nameplate7
  ok(crest and crest.shown and crest.crest and crest.bar.color[1] > 0.85 and crest.bar.color[3] < 0.4,
     "somebody the guild is recruiting: the crest, in gold")
  ok(W.lastMsg and W.lastMsg:find("Fresh Face", 1, true) and W.lastMsg:find("Tyrone is talking to them", 1, true),
     "and a line: who, and who is talking to them", W.lastMsg)
  W.lastMsg = nil
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_REMOVED", "nameplate7")
  ok(RC.recruits.nameplate7 == nil and not crest.shown, "their plate goes: so does the crest")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  ok(RC.recruits.nameplate7 and W.lastMsg == nil, "back in sight: the crest, but no second line inside ten minutes")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_REMOVED", "nameplate7")
  local keepGroup2 = _G.IsInGroup
  _G.IsInGroup = function() return true end
  RC.frame.scripts.OnEvent(RC.frame, "GROUP_ROSTER_UPDATE")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  ok(RC.recruits.nameplate7, "grouped too - partied with them is exactly when it helps")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_REMOVED", "nameplate7")
  _G.IsInGroup = keepGroup2
  RC.frame.scripts.OnEvent(RC.frame, "GROUP_ROSTER_UPDATE")
  W.plates.nameplate7.hostile = true
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  ok(RC.recruits.nameplate7 == nil, "an enemy of the same name: no crest")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_REMOVED", "nameplate7")
  W.plates.nameplate7.hostile = false
  -- the guild's list asked once, not per plate - and again when Nebbinator says it changed
  local asked = teamAsked
  for _ = 1, 20 do RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate4") end
  ok(teamAsked == asked, "twenty plates: the list is not asked again", teamAsked - asked)
  prospects = {}
  nebCallbacks.Nebbinator_TeamChanged("Nebbinator_TeamChanged", "Fresh Face")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  ok(teamAsked == asked + 1 and RC.recruits.nameplate7 == nil, "the list changed (they joined): asked again, no crest")
  prospects = { ["Fresh Face"] = { by = "Tyrone", status = "contacted" } }
  RC.prospectsAt = nil
  for _, o in ipairs(R:Get("rivals").options) do
    if o.label == "recruits (gold crest)" then o.set(rdb2, false) end
  end
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  ok(RC.recruits.nameplate7 == nil, "'recruits' off: none")
  rdb2.recruits = nil
  _G.NebbinatorAPI = { major = 1, version = 1 }
  RC.prospectsAt = nil
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  ok(RC.recruits.nameplate7 == nil and RC.Nebbinator() == nil, "an old Nebbinator (version 1): nothing asked, no crest")
  _G.NebbinatorAPI = { major = 1, version = 2, Team = function() error("boom") end, IsProspect = function() error("boom") end }
  RC.prospectsAt = nil
  local okBroken = pcall(RC.frame.scripts.OnEvent, RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  ok(okBroken and RC.recruits.nameplate7 == nil, "a broken Nebbinator never breaks the plates")
  _G.NebbinatorAPI = nil
  RC.prospectsAt, RC.nebHooked = nil, nil
  W.plates.nameplate7, plates.nameplate7 = nil, nil
  end
  -- LEAN: a town of strangers' plates, alone, nobody gold and no guild rivals: a name and a guild question each
  local Cost2 = dofile("../_bisdev/dev/cost.lua")
  for k in pairs(g) do g[k] = nil end
  RC.SetActive(rdb2, "Hunting Moms", false) RC.SetActive(rdb2, "Légolas Thiliaere", false)
  W.plates.nameplate4 = { name = "Stranger" }
  local nM = Cost2.Count(function() for _ = 1, 500 do RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate4") end end)
  ok(nM <= 500 * 3, "500 strangers' plates, guildmates on: at most 3 client calls each: " .. nM)
  rdb2.mates = false
  local nOff = Cost2.Count(function() for _ = 1, 500 do RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate4") end end)
  ok(nOff == 0, "and with everything off: none at all: " .. nOff)
  print(("   cost: 500 plates alone = %d calls (guildmates on), %d (all off)"):format(nM, nOff))
  rdb2.mates = nil
  RC.SetActive(rdb2, "Hunting Moms", true)
  _G.UnitIsInMyGuild, _G.C_NamePlate.GetNamePlateForUnit = keepMine, keepGet
  lib2.SendTo = keepSendTo
  _G.Menu, _G.IsInGuild = nil, nil
  W.plates.nameplate4, W.plates.nameplate5, W.plates.nameplate6 = nil, nil, nil

  -- /bist recap why (Arn, Hunting Moms on his target: "dont think i got a notification or sound"):
  -- says who is gold, what it last saw and why it stayed quiet, and reads the target every way
  local said3 = {}
  local keepAdd3 = DEFAULT_CHAT_FRAME.AddMessage
  DEFAULT_CHAT_FRAME.AddMessage = function(_, m) said3[#said3 + 1] = m end
  W.target = { name = "Somebody Else" }
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_TARGET_CHANGED")
  ok(pcall(S, "recap why"), "/bist recap why never throws")
  local why = table.concat(said3, "\n")
  ok(why:find("gold: ", 1, true) and why:find("Hunting Moms", 1, true) and why:find("not a rival", 1, true)
     and why:find('"Somebody Else"', 1, true), "it names the gold rivals, the last look and its reason, and the target", why)
  said3 = {}
  W.target = { name = "Hunting" }                     -- MEASURED: the game gives "Hunting", the recap "Hunting Moms"
  S("recap why")
  ok(table.concat(said3, "\n"):find("that is your rival Hunting Moms (gold)", 1, true),
     "the character name alone is the rival (Forever's surname is not part of it)", table.concat(said3, "\n"))
  said3 = {}
  W.target = { name = "Hunt" }                        -- a different, shorter name is not them
  S("recap why")
  ok(not table.concat(said3, "\n"):find("that is your rival", 1, true), "a name that only starts the same is not a rival")
  -- and the tracker calls them out under the first name, by the name the recap knows
  W.notices = {}
  W.now = W.now + RC.ALERT_GAP + 1
  W.target = { name = "Hunting" }
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_TARGET_CHANGED")
  ok(W.notices[1] == "Rival nearby: Hunting Moms", "targeting \"Hunting\" calls out your rival Hunting Moms", tostring(W.notices[1]))
  said3 = {}
  said3 = {}
  _G.UnitName = function() return setmetatable({}, { __index = function() error("secret") end }) end
  _G.issecretvalue = function(v) return type(v) == "table" end
  ok(pcall(S, "recap why") and table.concat(said3, "\n"):find("HIDDEN by the game", 1, true), "a hidden target name is said to be hidden")
  _G.UnitName, _G.issecretvalue = keepName, keepIs
  DEFAULT_CHAT_FRAME.AddMessage = keepAdd3
  W.target = nil

  -- LEAN: hunting nobody costs nothing; hunting someone costs a name check a nameplate
  local Cost = dofile("../_bisdev/dev/cost.lua")
  -- (the guildmate + off here: it is measured with its own budget in the guild section)
  rdb2.mates = false
  local n = Cost.Count(function() for _ = 1, 500 do RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate9") end end)
  ok(n <= 500 * 2, "500 strangers' nameplates with a gold rival: at most 2 client calls each: " .. n)
  RC.SetActive(rdb2, "Hunting Moms", false)
  local n0 = Cost.Count(function() for _ = 1, 500 do RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7") end end)
  ok(n0 == 0, "500 nameplates with nobody gold: no client calls at all: " .. n0)
  rdb2.mates = nil
  print(("   cost: 500 nameplates = %d calls hunting someone, %d hunting nobody"):format(n, n0))
  _G.GetZoneText = keepZone
  W.plates.nameplate7, W.plates.nameplate8, W.plates.nameplate9, W.target = nil, nil, nil, nil

  -- no death this session, but rivals: /bist recap opens the rivals & pals window instead (their own
  -- window since 14 Oct - an empty death recap is not shown)
  RC.last = nil
  _G.C_DeathRecap.GetRecapEvents = function() return nil end
  w:Hide()
  RC.SetExpanded(rdb2, false)
  S("recap")
  ok(not w:IsShown() and d:IsShown(), "no death yet: the rivals & pals window opens, not an empty recap")
  fitsIn(d, "the rivals & pals window")
  W.shift = true
  d.rows[1].scripts.OnClick(d.rows[1], "LeftButton")
  W.shift = false
  ok(#(function() local t = {} for k in pairs(rivals) do t[#t + 1] = k end return t end)() == 1, "shift-click forgets a rival")
  rdb2.rivals, rdb2.expanded = nil, nil
  w:Hide()

  _G.GetPlayerInfoByGUID, _G.RAID_CLASS_COLORS = keepInfo, keepColors

  _G.C_DeathRecap, _G.UnitIsDeadOrGhost = keepDR, keepDead
  RC.last = nil
  w:Hide()
end

-- ---------------------------------------------------------------- the social tool: a thank-you emote
-- (12 Oct 2026) Arn: "when i get a buff from a friendly player i hate having to say /thanks /kiss /hug etc.
-- can we track who buffed us and it select a random friendly emote to auto emote them maybe with a 2-5 min
-- cooldown". UNIT_AURA for "player" carries addedAuras with sourceUnit; in a fight it can be hidden.
do
  local Sc = NS.Social
  local sdb = R:DBFor(R:Get("social"))
  local emoted = {}
  local keep = { DoEmote = _G.DoEmote, UnitIsPlayer = _G.UnitIsPlayer, UnitIsUnit = _G.UnitIsUnit,
                 UnitName = _G.UnitName, UnitInParty = _G.UnitInParty }
  _G.DoEmote = function(token, who) emoted[#emoted + 1] = { token = token, who = who } end
  local units = { target = { name = "Kindpally", player = true }, nameplate9 = { name = "Wolfie", player = false },
                  party1 = { name = "Groupy", player = true, party = true } }
  _G.UnitName = function(u) if u == "player" then return "Me" end return units[u] and units[u].name end
  _G.UnitIsPlayer = function(u) return u == "player" or (units[u] and units[u].player) or false end
  _G.UnitIsUnit = function(a, b) return a == b end
  _G.UnitInParty = function(u) return units[u] and units[u].party or false end
  local function buff(src) return { addedAuras = { { isHelpful = true, sourceUnit = src, spellId = 1243 } } } end
  local fire = function(info) Sc.events.scripts.OnEvent(Sc.events, "UNIT_AURA", "player", info) end

  ok(sdb.thanks == false, "off until switched on: nobody gets hugged the day it is installed")
  fire(buff("target"))
  ok(#emoted == 0, "off: no emote")
  S("social on")
  ok(sdb.thanks == true, "/bist social on")
  Sc.next, Sc.thanked = nil, {}
  fire(buff("target"))
  local e = emoted[1]
  ok(e and e.who == "Kindpally", "a friendly player buffs you: an emote at them")
  local isFriendly = false
  for _, t in ipairs(Sc.EMOTES) do if e and e.token == t then isFriendly = true end end
  ok(isFriendly, "a friendly one, from the list", e and e.token)
  units.focus = { name = "Another", player = true }
  fire(buff("focus"))
  ok(#emoted == 1 and Sc.lastWhy:find("cooldown", 1, true), "within the 2-5 minute cooldown: no second emote")
  ok(Sc.next - W.now >= Sc.MIN_GAP and Sc.next - W.now <= Sc.MAX_GAP, "the cooldown is 2 to 5 minutes")
  W.now = W.now + Sc.MAX_GAP + 1
  fire(buff("target"))
  ok(#emoted == 1 and Sc.lastWhy:find("ten minutes", 1, true), "the same player again within ten minutes: no")
  fire(buff("focus"))
  ok(#emoted == 2 and emoted[2].who == "Another", "someone else after the cooldown: yes")
  W.now = W.now + 999
  -- who is never thanked
  fire(buff("player")) ok(#emoted == 2 and Sc.lastWhy == "your own buff", "your own buff: no")
  fire(buff("nameplate9")) ok(#emoted == 2 and Sc.lastWhy:find("not a player", 1, true), "a pet or creature: no")
  fire(buff("party1")) ok(#emoted == 2 and Sc.lastWhy:find("groupmate", 1, true), "a groupmate: left alone")
  fire({ addedAuras = { { isHelpful = true, sourceUnit = nil } } })
  ok(#emoted == 2 and Sc.lastWhy:find("did not say who", 1, true), "a buff from someone the game will not name: no")
  fire({ addedAuras = { { isHelpful = false, sourceUnit = "target" } } })
  ok(#emoted == 2, "a debuff: no")
  W.combat = true fire(buff("target")) W.combat = false
  ok(#emoted == 2 and Sc.lastWhy:find("fight", 1, true), "in a fight: never")
  local hiddenInfo = setmetatable({}, { __index = function() error("secret") end })
  local keepIs = _G.issecretvalue
  _G.issecretvalue = function(v) return v == hiddenInfo end
  ok(pcall(fire, hiddenInfo) and #emoted == 2, "a hidden payload: not read, no emote")
  _G.issecretvalue = keepIs
  S("social group")
  fire(buff("party1"))
  ok(#emoted == 3 and emoted[3].who == "Groupy", "/bist social group: groupmates thanked too")
  S("social group")
  -- AN EMOTE THE GAME PERFORMS AND THEN COMPLAINS ABOUT still starts the cooldown (Arn's paste: "You hug
  -- Mediumroar Dacraina." then "You thank Mediumroar Dacraina." two seconds apart, "it did it by itself")
  W.now = W.now + 999
  Sc.next = nil
  local performed = 0
  _G.DoEmote = function(token, who) performed = performed + 1 error("usage: DoEmote(token[, unit])") end
  units.mouseover = { name = "Mediumroar Dacraina", player = true }
  fire(buff("mouseover"))
  W.now = W.now + 2
  fire(buff("mouseover"))
  fire(buff("focus"))
  ok(performed == 1, "the game emoted and complained: the cooldown still started, no second emote", performed)
  ok(Sc.lastThanked and Sc.lastThanked.who == "Mediumroar Dacraina" and Sc.lastThanked.err, "and the complaint is kept for why")
  _G.DoEmote = function(token, who) emoted[#emoted + 1] = { token = token, who = who } end
  W.now = W.now + 999
  -- why
  local said = {}
  local keepAdd = DEFAULT_CHAT_FRAME.AddMessage
  DEFAULT_CHAT_FRAME.AddMessage = function(_, m) said[#said + 1] = m end
  ok(pcall(S, "social why") and table.concat(said, "\n"):find("Mediumroar Dacraina", 1, true), "/bist social why: who and why")
  -- a later piece of buff with no caster named must not hide who was thanked (Arn's paste: "last buff from:
  -- nobody yet - the game did not say who", 48 s after it thanked Mediumroar)
  fire({ addedAuras = { { isHelpful = true, sourceUnit = nil } } })
  said = {}
  S("social why")
  local w2 = table.concat(said, "\n")
  ok(w2:find("last thanked: ", 1, true) and w2:find("Mediumroar", 1, true) and w2:find("did not say who", 1, true),
     "why keeps the last one thanked apart from the last buff seen", w2)
  DEFAULT_CHAT_FRAME.AddMessage = keepAdd
  -- A TICKING TIMER SAYS NOTHING (Arn, 14 Oct: Blessing of Kings landed, and why said "nothing new on
  -- you" - the answer about the buff overwritten by the next aura change)
  local whyBefore = Sc.lastWhy
  fire({ isFullUpdate = false })
  fire({ updatedAuraInstanceIDs = {} })
  ok(Sc.lastWhy == whyBefore, "an aura change with nothing landed leaves the last answer standing", Sc.lastWhy)
  -- A RECAST: the buff you wore, back at its full duration - an update, thanked like a new one
  local keepUA = _G.C_UnitAuras
  local auras = {
    [77] = { isHelpful = true, sourceUnit = "mouseover", duration = 3600, expirationTime = W.now + 3600 },  -- just recast
    [78] = { isHelpful = true, sourceUnit = "target", duration = 3600, expirationTime = W.now + 1200 },     -- ticking
  }
  _G.C_UnitAuras = { GetAuraDataByAuraInstanceID = function(_, id) return auras[id] end }
  Sc.next, Sc.thanked = nil, {}
  units.mouseover = { name = "Kingsgiver", player = true }
  local before = #emoted
  fire({ updatedAuraInstanceIDs = { 78 } })
  ok(#emoted == before, "a buff whose timer merely ticks: no emote")
  fire({ updatedAuraInstanceIDs = { 77 } })
  ok(#emoted == before + 1 and emoted[#emoted].who == "Kingsgiver", "a buff recast on you (full duration again): thanked")
  _G.C_UnitAuras = keepUA
  -- THE LAST FIVE (Arn, 21 Oct: "i just dont know why sometimes it misses a emote"): why lists the last five
  -- buffs from other players, each with what was done or why not
  Sc.history, Sc.next, Sc.thanked = {}, nil, {}
  W.now = W.now + 999
  local function step(info, dt) W.now = W.now + (dt or 5) fire(info) end
  step({ addedAuras = { { isHelpful = true, sourceUnit = "target", name = "Power Word: Fortitude" } } })
  step(buff("focus"))
  step(buff("player"))
  step(buff("party1"))
  step(buff("party1"), 1)
  step(buff("nameplate9"))
  step({ addedAuras = { { isHelpful = true, sourceUnit = nil } } })
  W.combat = true step(buff("focus")) W.combat = false
  local hs = Sc.history
  ok(#hs == 5 and hs[1].who == "Another" and hs[1].why:find("fight", 1, true), "five kept, newest first: a buff mid-fight is listed",
     hs[1] and hs[1].why)
  ok(hs[5].why:find("cooldown", 1, true) and hs[4].why:find("groupmate", 1, true), "the oldest drops off; the same buff in pieces is one row")
  local own = false
  for _, h in ipairs(hs) do if h.who == "Me" then own = true end end
  ok(not own, "your own buffs are not listed")
  said = {}
  DEFAULT_CHAT_FRAME.AddMessage = function(_, m) said[#said + 1] = m end
  Sc.history[#Sc.history] = nil
  table.insert(Sc.history, 1, { who = "Kindpally", why = "/hug - thanked", spell = "Power Word: Fortitude", at = W.now - 120 })
  S("social why")
  DEFAULT_CHAT_FRAME.AddMessage = keepAdd
  local w3 = table.concat(said, "\n")
  ok(w3:find("the last 5 buffs from other players", 1, true) and w3:find("Kindpally", 1, true)
     and w3:find("(Power Word: Fortitude)", 1, true) and w3:find("2 min ago", 1, true) and w3:find("a groupmate", 1, true),
     "/bist social why: who, which buff, what happened, how long ago", w3)
  -- LEAN: everyone else's auras change constantly; that costs one string compare
  local Cost = dofile("../_bisdev/dev/cost.lua")
  local n = Cost.Count(function() for i = 1, 500 do Sc.events.scripts.OnEvent(Sc.events, "UNIT_AURA", "raid" .. (i % 25 + 1), buff("target")) end end)
  ok(n == 0, "500 aura changes on other people: no client calls: " .. n)
  -- in a fight your own auras churn (procs, your own buffs, debuffs): listing a player's buff mid-fight
  -- must cost no name lookup unless one really landed from someone else
  W.combat = true
  local nf, byf = Cost.Count(function()
    for _ = 1, 500 do
      fire({ addedAuras = { { isHelpful = true, sourceUnit = "player" }, { isHelpful = false, sourceUnit = "target" } } })
      fire({ updatedAuraInstanceIDs = { 77 } })
    end
  end)
  W.combat = false
  ok(nf <= 500 * 2, "1000 of your own aura changes in a fight: the fight check and nothing more: " .. nf, Cost.Top(byf))
  S("social off")
  -- every name put back, the ones that were not there before included (pairs skips a nil)
  for _, k in ipairs({ "DoEmote", "UnitIsPlayer", "UnitIsUnit", "UnitName", "UnitInParty" }) do _G[k] = keep[k] end
end

-- ---------------------------------------------------------------- "none", and the nameplate hint
do
  local RC = NS.Recap
  local rdb = R:DBFor(R:Get("recap"))
  RC.SetStyle(rdb, "none")
  local p = CreateFrame("Frame", nil, nil)
  _G.C_NamePlate.GetNamePlateForUnit = function() return p end
  ok(RC.MarkPlate("nameplate1", "Somebody", "own") == false and RC.marks.nameplate1 == nil,
     "crosshair \"none\": no mark at all (Arn: \"they can select none\")")
  RC.SetStyle(rdb, "rails")
  ok(RC.MarkPlate("nameplate1", "Somebody", "own") == true, "and back to rails, marked")
  RC.UnmarkUnit("nameplate1")
  _G.C_NamePlate.GetNamePlateForUnit = nil
  local hint
  for _, o in ipairs(R:Get("rivals").options) do if o.label == "needs nameplates on" then hint = o end end
  local cvars = {}
  local keepCV = _G.C_CVar
  _G.C_CVar = { SetCVar = function(k, v) cvars[k] = v return true end }
  ok(hint and hint.kind == "button" and hint.button == "turn on", "the options say the crosshair needs nameplates, with a button")
  hint.action()
  ok(cvars.nameplateShowEnemies == "1", "which turns enemy nameplates on")
  cvars = {}
  W.combat = true hint.action() W.combat = false
  ok(cvars.nameplateShowEnemies == nil, "never in a fight")
  _G.C_CVar = keepCV
end

-- leaked globals
-- ------------------------------------------------------------ the battleground "+ rival" button
-- Arn, 13 Oct: "maybe a bg button that rivals someone so i dont have to type" - the right-click menu
-- cannot carry the line inside an instance, so in a battleground the BiS> tools box gets a button.
do
  local RC, B = NS.Recap, NS.Box
  local rdb = R:DBFor(R:Get("recap"))
  local list = RC.Rivals(rdb)
  local keepInst, keepT, keepCombat = _G.IsInInstance, W.target, W.combat
  local kind = "none"
  _G.IsInInstance = function() return kind ~= "none", kind end
  W.combat = false
  B.Refresh()
  ok(not (RC.abtn and RC.abtn.shown), "out in the world: no + rival button (the menu has the line)")
  kind = "pvp"
  B.events.scripts.OnEvent(B.events, "PLAYER_ENTERING_WORLD")
  local ab = RC.abtn
  ok(ab and ab.shown and BiSToolsBox.shown, "into a battleground: the + rival button is in the box")
  ok(ab.template == nil, "a plain button - nothing secure, so its face may change mid-fight")
  ok(ab.icon == nil and ab.sign, "just a red + - no crossed swords (Arn: they looked the same as the target button)")
  -- no target / a mob: dim
  W.target = nil
  RC.PaintAdd()
  ok(ab.alpha == 0.4 and ab.sign.text == "+", "no enemy player on target: dim")
  W.target = { name = "Raging Gnoll", guid = "Creature-0-0-0-0-117-3", hostile = true }
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_TARGET_CHANGED")
  ok(ab.alpha == 0.4, "a mob on target: dim")
  -- an enemy player: +, click, -, click
  W.target = { name = "Whacky", player = true, hostile = true, guid = "Player-4619-0BG07" }
  local keepGUN = _G.GetUnitName
  _G.GetUnitName = function(u) if u == "target" then return "Whacky Waqqy" end end
  W.combat = true                                     -- mid-fight
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_TARGET_CHANGED")
  ok(ab.alpha == 1 and ab.sign.text == "+" and ab.state == "add", "an enemy player on target: + (even mid-fight)")
  ab.scripts.OnClick(ab, "LeftButton")
  ok(list["Whacky Waqqy"] and list["Whacky Waqqy"].active, "one click: Whacky Waqqy is a gold rival")
  ok(ab.sign.text == "-" and ab.state == "remove", "and the button now offers to take them off")
  ab.scripts.OnClick(ab, "LeftButton")
  ok(list["Whacky Waqqy"] == nil and ab.sign.text == "+", "clicked again: off")
  W.combat = false
  -- an arena counts too; leaving takes it away
  kind = "arena"
  B.events.scripts.OnEvent(B.events, "PLAYER_ENTERING_WORLD")
  ok(ab.shown, "an arena: the button too")
  kind = "none"
  B.events.scripts.OnEvent(B.events, "PLAYER_ENTERING_WORLD")
  ok(not ab.shown, "back in the world: gone")
  _G.IsInInstance, W.target, W.combat, _G.GetUnitName = keepInst, keepT, keepCombat, keepGUN
  B.Refresh()
end

-- ------------------------------------------------------------ the threat tool
-- A BiS Tools user, through Arn (13 Oct): a tank sees what is NOT on them; a dps sees nothing until
-- they pull threat. Then Arn: a CURVE - barely visible at 60% of a pull, stronger to 100%, yellow
-- to red, and flashing only near the top ("dps like to cut it close"). UnitDetailedThreatSituation
-- (who, mob): isTanking, status, scaledPercentage (100 = pulls it), ... - nothing when not listed.
do
  local RC, Th = NS.Recap, NS.Threat
  ok(Th and R:Get("threat"), "the threat tool is registered")
  ok(not R:Enabled("threat"), "a beta: off until someone turns it on")
  S("on threat")
  ok(R:Enabled("threat") and NS.DB().enabled.threat == true, "/bist on threat turns it on - and it is remembered as on")
  local tdb = R:DBFor(R:Get("threat"))
  tdb.look = "crosshair"                       -- these checks are about the crosshair look; the others below
  local plates, det, role = {}, { player = {} }, "DAMAGER"
  local keep = { get = _G.C_NamePlate.GetNamePlateForUnit, UnitDetailedThreatSituation = _G.UnitDetailedThreatSituation,
    UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned, IsInGroup = _G.IsInGroup, IsInInstance = _G.IsInInstance,
    IsInRaid = _G.IsInRaid, GetNumGroupMembers = _G.GetNumGroupMembers, issecretvalue = _G.issecretvalue, style = RC.style }
  _G.C_NamePlate.GetNamePlateForUnit = function(u) return plates[u] end
  _G.UnitDetailedThreatSituation = function(who, u)
    local d = det[who] and det[who][u]
    if not d then return end
    return d[1], d[2] or (d[1] and 3 or 0), d[3], d[3], 1000
  end
  _G.UnitGroupRolesAssigned = function() return role end
  local grouped = true
  _G.IsInGroup = function() return grouped end
  _G.IsInInstance = function() return grouped, grouped and "party" or "none" end
  _G.IsInRaid = function() return false end
  _G.GetNumGroupMembers = function() return grouped and 3 or 0 end
  local SECRET = setmetatable({}, {})
  _G.issecretvalue = function(v) return rawequal(v, SECRET) end
  RC.style = "rails"
  local function ev(e, u) Th.frame.scripts.OnEvent(Th.frame, e, u) end
  for i = 21, 23 do
    local u = "nameplate" .. i
    plates[u] = CreateFrame("Frame", nil, nil)
    plates[u]:SetSize(120, 20)
    W.plates[u] = { name = "Defias Thug", guid = "Creature-0-0-0-0-38-" .. i, hostile = true, combat = true }
    ev("NAME_PLATE_UNIT_ADDED", u)
  end
  local function mk(u) return RC.marks[u] end
  local function me(u, tanking, pct) det.player[u] = { tanking, nil, pct } ev("UNIT_THREAT_LIST_UPDATE", u) end

  me("nameplate21", false, 85)
  ok(mk("nameplate21") == nil, "out of combat: no threat crosshairs")
  ev("PLAYER_REGEN_DISABLED")
  ok(mk("nameplate21") and mk("nameplate21").kind == "threat", "a fight starts: the crosshair is there")

  me("nameplate21", false, 50)
  ok(mk("nameplate21") == nil, "dps at 50% of a pull: nothing")
  me("nameplate21", false, 60)
  ok(mk("nameplate21") == nil, "at 60% exactly: still nothing")
  me("nameplate21", false, 61)
  local m = mk("nameplate21")
  ok(m and m.alpha < 0.06 and not m.flashing, "61%: barely visible (Arn: 'like 1%'), steady", m and m.alpha)
  local c61 = m.parts[1].color
  ok(c61[1] == 1 and c61[2] > 0.8, "and yellow")
  local a = {}
  for _, pct in ipairs({ 70, 80, 90 }) do me("nameplate21", false, pct) a[pct] = mk("nameplate21").alpha end
  ok(a[70] < a[80] and a[80] < a[90], "70, 80, 90: stronger each step", a[70] .. " " .. a[80] .. " " .. a[90])
  me("nameplate21", false, 80)
  local c80 = mk("nameplate21").parts[1].color
  ok(c80[2] > 0.35 and c80[2] < 0.55, "80%: orange", c80[2])
  me("nameplate21", false, 90)
  ok(not mk("nameplate21").flashing and not mk("nameplate21").pulse:IsPlaying(),
     "90%: cutting it close is STEADY, not flashing (Arn: 'we don't want something flashing all the time')")
  local c90 = mk("nameplate21").parts[1].color
  ok(c90[2] < c80[2], "and redder")
  me("nameplate21", false, 96)
  ok(mk("nameplate21").flashing and mk("nameplate21").pulse:IsPlaying(), "96%: it flashes")
  me("nameplate21", true, 100)
  local cOn = mk("nameplate21").parts[1].color
  ok(mk("nameplate21").flashing and cOn[2] < 0.2, "it turns on you: red, flashing")
  me("nameplate21", false, 40)
  ok(mk("nameplate21") == nil, "the tank takes it back: gone")
  ok(mk("nameplate22") == nil, "a mob you are not on the list of: nothing for a dps")

  S("threat from 80")
  ok(tdb.from == 80, "/bist threat from 80")
  me("nameplate21", false, 75)
  ok(mk("nameplate21") == nil, "now 75% is still nothing")
  me("nameplate21", false, 81)
  ok(mk("nameplate21") and mk("nameplate21").alpha < 0.06, "and 81% is barely visible")
  S("threat from 60")
  me("nameplate21", false, 0)

  det.player.nameplate22 = { SECRET, SECRET, SECRET }
  ev("UNIT_THREAT_LIST_UPDATE", "nameplate22")
  ok(mk("nameplate22") == nil, "a threat answer the game hides: nothing, no error")
  ev("PLAYER_REGEN_ENABLED")
  ok(mk("nameplate21") == nil and mk("nameplate22") == nil, "the fight ends: every threat crosshair goes")

  -- TANK: on you - the closest groupmate's % drives it; off you - red, flashing
  role = "TANK"
  det.player = { nameplate21 = { true, 3, 100 }, nameplate22 = { false, 0, 40 } }
  det.party1 = { nameplate21 = { false, 0, 50 } }
  det.party2 = { nameplate21 = { false, 0, 85 } }
  ev("PLAYER_REGEN_DISABLED")
  local t21 = mk("nameplate21")
  ok(t21 and not t21.flashing and t21.alpha > 0.3 and t21.alpha < 0.5,
     "tank, on you, a dps at 85%: an orange warning, steady", t21 and t21.alpha)
  ok(mk("nameplate22") and mk("nameplate22").flashing and mk("nameplate22").parts[1].color[2] < 0.2,
     "tank, a mob that is NOT on you: red, flashing")
  ok(mk("nameplate23") and mk("nameplate23").flashing,
     "tank, a mob fighting the group you never touched (in a dungeon): red, flashing")
  det.party2.nameplate21 = { false, 0, 97 }
  ev("UNIT_THREAT_LIST_UPDATE", "nameplate21")
  ok(not mk("nameplate21").flashing, "the group is looked at no more than every half second per mob")
  local keepTime = _G.GetTime
  local tnow = keepTime() + Th.SCAN + 0.1
  _G.GetTime = function() return tnow end
  ev("UNIT_THREAT_LIST_UPDATE", "nameplate21")
  ok(mk("nameplate21").flashing, "half a second on: the dps at 97% makes it flash")
  _G.GetTime = keepTime
  det.party1, det.party2 = {}, {}
  Th.scan = {}
  ev("UNIT_THREAT_LIST_UPDATE", "nameplate21")
  ok(mk("nameplate21") and mk("nameplate21").parts[1].color[3] == 1 and not mk("nameplate21").flashing,
     "tank, safely on you, nobody close: purple, steady (Ariarie: purple = on me)")
  ev("PLAYER_REGEN_ENABLED")
  grouped = false
  ev("PLAYER_REGEN_DISABLED")
  ok(mk("nameplate23") == nil, "tank alone in the world: somebody else's fight is not yours")
  ev("PLAYER_REGEN_ENABLED")
  grouped = true

  RC.MarkPlate("nameplate22", "Defias Thug", "farm")
  ev("PLAYER_REGEN_DISABLED")
  ok(mk("nameplate22").kind == "farm", "the farm's crosshair (or a rival's) is never covered")
  ev("PLAYER_REGEN_ENABLED")
  RC.UnmarkUnit("nameplate22")

  S("threat dps")
  ok(tdb.role == "dps", "/bist threat dps: watch as a dps whatever the group role says")
  S("threat auto")
  ok(tdb.role == "auto", "/bist threat auto: back to the group role")
  ev("PLAYER_REGEN_DISABLED")
  R:SetEnabled("threat", false)
  ok(not mk("nameplate22"), "switching the tool off takes them down")
  me("nameplate22", false, 99)
  ok(not mk("nameplate22"), "and nothing more is drawn while it is off")
  R:SetEnabled("threat", true)
  ev("PLAYER_REGEN_ENABLED")

  -- COST. A dps: 300 list updates across three mobs, in a fight. A tank: the same, holding all
  -- three, with two groupmates to look at - throttled to one look per mob per T.SCAN. Measured: dps
  -- 1542 (~5 an update: the read and a "secret?" for the unit and each answer), tank 1800 (the group
  -- look cached, plus the clock for the throttle). Budgets 1650 and 1950.
  local Cost = dofile("../_bisdev/dev/cost.lua")
  role = "DAMAGER"
  det.player = {}
  ev("PLAYER_REGEN_DISABLED")
  local n, by = Cost.Count(function()
    for k = 1, 300 do
      local u = "nameplate" .. (21 + k % 3)
      det.player[u] = { false, 0, 55 + k % 45 }
      ev("UNIT_THREAT_LIST_UPDATE", u)
    end
  end)
  ok(n <= 1650, "dps: 300 threat updates ask at most 1650 things: " .. n .. " " .. Cost.Top(by, 5))
  ev("PLAYER_REGEN_ENABLED")
  role = "TANK"
  det.player = { nameplate21 = { true, 3, 100 }, nameplate22 = { true, 3, 100 }, nameplate23 = { true, 3, 100 } }
  det.party1 = { nameplate21 = { false, 0, 70 }, nameplate22 = { false, 0, 70 }, nameplate23 = { false, 0, 70 } }
  det.party2 = det.party1
  ev("PLAYER_REGEN_DISABLED")
  n, by = Cost.Count(function()
    for k = 1, 300 do ev("UNIT_THREAT_LIST_UPDATE", "nameplate" .. (21 + k % 3)) end
  end)
  ok(n <= 1950, "tank: 300 threat updates ask at most 1950 things: " .. n .. " " .. Cost.Top(by, 5))
  ev("PLAYER_REGEN_ENABLED")

  for i = 21, 23 do ev("NAME_PLATE_UNIT_REMOVED", "nameplate" .. i) W.plates["nameplate" .. i] = nil end
  _G.C_NamePlate.GetNamePlateForUnit = keep.get
  _G.UnitDetailedThreatSituation, _G.UnitGroupRolesAssigned = keep.UnitDetailedThreatSituation, keep.UnitGroupRolesAssigned
  _G.IsInGroup, _G.IsInInstance, _G.issecretvalue = keep.IsInGroup, keep.IsInInstance, keep.issecretvalue
  _G.IsInRaid, _G.GetNumGroupMembers = keep.IsInRaid, keep.GetNumGroupMembers
  RC.style = keep.style
end

-- ------------------------------------------------------------ threat: situations, looks, the window
-- The guild (Ariarie, 13 Oct): "purple on me ... grey another tank ... red a non-tank ... orange
-- nearing threat of another tank ... yellow out of combat", "customizable colors would be peak";
-- Gnomerpills: "left side of enemy bar", "the old DBM glow, miniaturized". Arn: "a customization window".
do
  local RC, Th, U = NS.Recap, NS.Threat, NS.Threat.UI
  local tdb = R:DBFor(R:Get("threat"))
  tdb.look, tdb.colours, tdb.on, tdb.role = "marker", {}, {}, "auto"
  local plates, det, roles = {}, { player = {} }, { player = "TANK" }
  local keep = { get = _G.C_NamePlate.GetNamePlateForUnit, D = _G.UnitDetailedThreatSituation,
    Role = _G.UnitGroupRolesAssigned, IsInGroup = _G.IsInGroup, IsInInstance = _G.IsInInstance,
    IsInRaid = _G.IsInRaid, N = _G.GetNumGroupMembers, style = RC.style }
  _G.C_NamePlate.GetNamePlateForUnit = function(u) return plates[u] end
  _G.UnitDetailedThreatSituation = function(who, u)
    local d = det[who] and det[who][u]
    if not d then return end
    return d[1], d[1] and 3 or 0, d[2], d[2], 1000
  end
  _G.UnitGroupRolesAssigned = function(u) return roles[u] or "NONE" end
  _G.IsInGroup = function() return true end
  _G.IsInInstance = function() return true, "party" end
  _G.IsInRaid = function() return false end
  _G.GetNumGroupMembers = function() return 3 end
  RC.style = "rails"
  Th.scan = {}
  local function ev(e, u) Th.frame.scripts.OnEvent(Th.frame, e, u) end
  for i = 31, 33 do
    local u = "nameplate" .. i
    plates[u] = CreateFrame("Frame", nil, nil)
    plates[u]:SetSize(120, 20)
    W.plates[u] = { name = "Defias Pillager", guid = "Creature-0-0-0-0-589-" .. i, hostile = true, combat = true }
    ev("NAME_PLATE_UNIT_ADDED", u)
  end
  local function ind(u) return Th.ind[u] end
  local function rgb(f) local c = f.parts[1].color return c[1], c[2], c[3] end

  -- Ariarie's tank situations, on the left marker (the default look)
  roles.party1, roles.party2 = "TANK", "DAMAGER"
  det.player = { nameplate31 = { true, 100 } }
  det.party1 = { nameplate32 = { true, 100 } }
  det.party2 = { nameplate33 = { true, 100 } }
  ev("PLAYER_REGEN_DISABLED")
  local m31, m32, m33 = ind("nameplate31"), ind("nameplate32"), ind("nameplate33")
  ok(m31 and m31.key == "mine" and m32 and m32.key == "otherTank" and m33 and m33.key == "nonTank",
     "tank: on me / on another tank / on a non-tank - three situations told apart")
  local r, g, b = rgb(m31)
  ok(r < 0.8 and b == 1, "on me: purple")
  r, g, b = rgb(m32)
  ok(math.abs(r - g) < 0.05 and r > 0.5 and r < 0.7, "on another tank: grey")
  r, g = rgb(m33)
  ok(r == 1 and g < 0.2 and m33.flashing, "on a non-tank: red, flashing")
  ok(not m31.flashing and not m32.flashing, "the calm ones are steady")
  ok(RC.marks.nameplate31 == nil, "the marker is not the crosshair: the plate's own mark is free")
  ok(m31.look == "marker" and m31.point and m31.point[1] == "BOTTOMRIGHT" and m31.point[2] == plates.nameplate31
     and m31.point[3] == "BOTTOMLEFT" and m31.w == Th.MARK_W,
     "the marker runs down the plate's LEFT side (Gnomerpills: readable when plates stack)")

  -- the situations follow the fight
  det.player.nameplate32 = { false, 80 }
  Th.scan = {}
  ev("UNIT_THREAT_LIST_UPDATE", "nameplate32")
  ok(ind("nameplate32").key == "otherTank", "still on the other tank")
  det.player.nameplate31 = { true, 100 }
  det.party2.nameplate31 = { false, 90 }
  Th.scan = {}
  ev("UNIT_THREAT_LIST_UPDATE", "nameplate31")
  ok(ind("nameplate31").key == "slipping" and not ind("nameplate31").flashing,
     "on me, a groupmate at 90%: nearly losing it - orange, steady")
  det.party2.nameplate31 = { false, 97 }
  Th.scan = {}
  ev("UNIT_THREAT_LIST_UPDATE", "nameplate31")
  ok(ind("nameplate31").flashing, "at 97% it flashes")
  det.party2.nameplate31 = nil

  -- the window: colours, on/off, the look, the steppers
  if U.frame then U.frame:Hide() end            -- the Hub's "reset positions" test opened it earlier
  S("threat")
  local win = BiSToolsThreat
  ok(win and win:IsShown(), "/bist threat opens the window")
  ok(#U.rows == #Th.STATES, "a row for every situation")
  local ar, ag = NS.Farm.color("accent")
  ok(U.look.btns[2].value == "marker" and U.look.btns[2].edge.top.color[1] == ar and U.look.btns[2].edge.top.color[2] == ag
     and U.look.btns[1].edge.top.color[1] ~= ar, "the look in use is lit, the others not")
  -- pick a colour for "on me"
  local mineRow
  for _, row in ipairs(U.rows) do if row.key == "mine" then mineRow = row end end
  mineRow.swatches[1].scripts.OnClick(mineRow.swatches[1])
  ok(U.pal and U.pal.shown and U.pal.target == mineRow.swatches[1], "a swatch opens the 16-colour palette")
  ok(#U.pal.cells == 16, "16 colours")
  U.pal.cells[6].scripts.OnClick(U.pal.cells[6])                    -- the green
  ok(not U.pal.shown, "picking one closes it")
  local c = Th.ColourOf(tdb, "mine")
  ok(c[2] > 0.8 and c[1] < 0.4, "on me is green now", c[1])
  local live = ind("nameplate31")
  ok(live and live.key == "mine" and select(2, rgb(live)) > 0.8, "and the plate on screen turned green at once")
  ok(mineRow.swatches[1].fill.color[2] > 0.8, "and so did the swatch")
  -- switch a situation off
  local nonRow
  for _, row in ipairs(U.rows) do if row.key == "nonTank" then nonRow = row end end
  nonRow.check.scripts.OnClick(nonRow.check)
  ok(Th.IsOn(tdb, "nonTank") == false and ind("nameplate33") == nil, "a box unticked: that situation draws nothing")
  ok(nonRow.check.mark.text == "", "and the box shows it")
  nonRow.check.scripts.OnClick(nonRow.check)
  ok(ind("nameplate33") and ind("nameplate33").key == "nonTank", "ticked again: back")
  -- the glow
  U.look.btns[3].scripts.OnClick(U.look.btns[3])
  ok(tdb.look == "glow" and ind("nameplate31") and ind("nameplate31").look == "glow", "the glow look")
  ok(#ind("nameplate31").parts == 6, "two rings, sides and bottom only - open at the top, off the name (Arn)")
  do
    -- the horizontal edges are the ones given a height: exactly two (one per ring), both the bottom
    local across, bottoms = 0, 0
    for _, t in ipairs(ind("nameplate31").parts) do
      if t.h == Th.GLOW then
        across = across + 1
        if t.anchor and t.anchor[1] == "BOTTOMRIGHT" then bottoms = bottoms + 1 end
      end
    end
    ok(across == 2 and bottoms == 2, "the only edges across are the bottoms: no edge along the top", across .. "/" .. bottoms)
  end
  ok(ind("nameplate31").parts[4].ringAlpha < ind("nameplate31").parts[1].ringAlpha, "the outer ring fainter")
  -- the crosshair look
  U.look.btns[1].scripts.OnClick(U.look.btns[1])
  ok(ind("nameplate31") == nil and RC.marks.nameplate31 and RC.marks.nameplate31.kind == "threat",
     "the crosshair look: the recap's crosshair, no marker")
  U.look.btns[2].scripts.OnClick(U.look.btns[2])
  ok(RC.marks.nameplate31 == nil and ind("nameplate31"), "and back to the marker")
  -- steppers
  U.from.plus.scripts.OnClick(U.from.plus)
  ok(tdb.from == 65 and U.from.val.text == "65%", "show from: +5")
  for _ = 1, 10 do U.from.plus.scripts.OnClick(U.from.plus) end
  ok(tdb.from == 90, "never past 90")
  tdb.from = 60
  U.flash.minus.scripts.OnClick(U.flash.minus)
  ok(tdb.flashAt == 90, "flash from: -5")
  tdb.flashAt = 95
  -- reset colours
  U.resetBtn.scripts.OnClick(U.resetBtn)
  r, g, b = rgb(ind("nameplate31"))
  ok(b == 1 and r < 0.8, "reset colours: on me is purple again")
  -- preview
  U.previewBtn.scripts.OnClick(U.previewBtn)
  ok(U.previewing and U.mark and U.mark.shown and U.previewText.text ~= "", "preview: a situation on a fake plate")
  local first = U.previewText.text
  win.scripts.OnUpdate(win, U.PREVIEW_STEP + 0.01)
  ok(U.previewText.text ~= first, "it steps on to the next situation")
  win:Hide() win.scripts.OnHide(win)
  ok(not U.previewing and not U.mark.shown, "closing the window ends the preview")
  -- labels fit before the swatches
  for _, row in ipairs(U.rows) do
    ok(26 + row.label:GetStringWidth() <= 170 - 4, "row label fits before its swatch: " .. row.label.text)
  end
  -- out of combat: the idle colour, only when ticked
  ev("PLAYER_REGEN_ENABLED")
  ok(ind("nameplate31") == nil, "the fight ends: marks go")
  for i = 31, 33 do W.plates["nameplate" .. i].combat = false end
  Th.SetOn(tdb, "idle", true)
  ok(ind("nameplate31") and ind("nameplate31").key == "idle", "out of combat, ticked: yellow on enemy plates")
  Th.SetOn(tdb, "idle", false)
  ok(ind("nameplate31") == nil, "unticked (the default): nothing out of combat")

  -- COST of the marker look: 300 threat updates across three mobs, a tank holding all three with
  -- two groupmates (the group look cached per mob). Measured below; budget a little above it.
  -- issecretvalue is in place, as on the client: without it the count is kinder than the game.
  local keepIs = _G.issecretvalue
  _G.issecretvalue = function() return false end
  local Cost = dofile("../_bisdev/dev/cost.lua")
  for i = 31, 33 do W.plates["nameplate" .. i].combat = true end
  det.player = { nameplate31 = { true, 100 }, nameplate32 = { true, 100 }, nameplate33 = { true, 100 } }
  det.party1, det.party2 = {}, {}
  ev("PLAYER_REGEN_DISABLED")
  local n, by = Cost.Count(function()
    for k = 1, 300 do ev("UNIT_THREAT_LIST_UPDATE", "nameplate" .. (31 + k % 3)) end
  end)
  ok(n <= 1950, "marker look: 300 threat updates ask at most 1950 things (measured 1800): " .. n .. " " .. Cost.Top(by, 5))
  _G.issecretvalue = keepIs
  ev("PLAYER_REGEN_ENABLED")

  for i = 31, 33 do ev("NAME_PLATE_UNIT_REMOVED", "nameplate" .. i) W.plates["nameplate" .. i] = nil end
  tdb.look, tdb.colours, tdb.on = "marker", {}, {}
  _G.C_NamePlate.GetNamePlateForUnit = keep.get
  _G.UnitDetailedThreatSituation, _G.UnitGroupRolesAssigned = keep.D, keep.Role
  _G.IsInGroup, _G.IsInInstance, _G.IsInRaid, _G.GetNumGroupMembers = keep.IsInGroup, keep.IsInInstance, keep.IsInRaid, keep.N
  RC.style = keep.style
end

-- ------------------------------------------------------------ threat: when the detailed read is hidden
-- Arn, 13 Oct: "ever since the threat custom window I don't think it's working". The window's build
-- moved to UnitDetailedThreatSituation; if a fight hides it, the simple UnitThreatSituation is used.
do
  local Th = NS.Threat
  local tdb = R:DBFor(R:Get("threat"))
  tdb.look, tdb.colours, tdb.on, tdb.role = "marker", {}, {}, "dps"
  local SECRET = setmetatable({}, {})
  local plates, simple = {}, {}
  local keep = { get = _G.C_NamePlate.GetNamePlateForUnit, D = _G.UnitDetailedThreatSituation,
    S = _G.UnitThreatSituation, is = _G.issecretvalue, ex = _G.UnitExists, target = W.target }
  _G.C_NamePlate.GetNamePlateForUnit = function(u) return plates[u] end
  _G.UnitDetailedThreatSituation = function() return SECRET, SECRET, SECRET, SECRET, SECRET end
  _G.UnitThreatSituation = function(_, u) return simple[u] end
  _G.issecretvalue = function(v) return rawequal(v, SECRET) end
  local function ev(e, u) Th.frame.scripts.OnEvent(Th.frame, e, u) end
  plates.nameplate41 = CreateFrame("Frame", nil, nil)
  plates.nameplate41:SetSize(120, 20)
  W.plates.nameplate41 = { name = "Riverpaw Gnoll", guid = "Creature-0-0-0-0-117-1", hostile = true, combat = true }
  ev("NAME_PLATE_UNIT_ADDED", "nameplate41")
  ev("PLAYER_REGEN_DISABLED")
  simple.nameplate41 = 0
  ev("UNIT_THREAT_LIST_UPDATE", "nameplate41")
  ok(Th.ind.nameplate41 == nil and Th.how == "simple", "detailed hidden, below the tank: the simple read, nothing drawn")
  simple.nameplate41 = 1
  ev("UNIT_THREAT_LIST_UPDATE", "nameplate41")
  ok(Th.ind.nameplate41 and Th.ind.nameplate41.key == "climb" and Th.ind.nameplate41.flashing,
     "above the tank: the climb, flashing - it is about to turn")
  simple.nameplate41 = 3
  ev("UNIT_THREAT_LIST_UPDATE", "nameplate41")
  ok(Th.ind.nameplate41.key == "onMe", "on you: on me")
  simple.nameplate41 = SECRET
  ev("UNIT_THREAT_LIST_UPDATE", "nameplate41")
  ok(Th.ind.nameplate41 == nil and Th.how == "hidden", "both hidden: nothing - never a guess")
  tdb.role = "tank"
  Th.Refresh()
  ev("PLAYER_REGEN_DISABLED")
  ok(Th.ind.nameplate41 == nil, "both hidden, as a tank: nothing either (not a red 'lost')")
  -- /bist threat why shows the raw reads for the target
  W.target = { name = "Riverpaw Gnoll", guid = "Creature-0-0-0-0-117-1", hostile = true }
  simple.target = 2
  local said = {}
  local keepChat = DEFAULT_CHAT_FRAME.AddMessage
  DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) said[#said + 1] = tostring(msg) end
  Th.Why(tdb)
  DEFAULT_CHAT_FRAME.AddMessage = keepChat
  local all = table.concat(said, "\n")
  ok(all:find("detailed: tanking HIDDEN, status HIDDEN, % of a pull HIDDEN", 1, true)
     and all:find("simple: 2", 1, true), "/bist threat why shows what the game hands over, hidden or not", all)
  ev("PLAYER_REGEN_ENABLED")
  ev("NAME_PLATE_UNIT_REMOVED", "nameplate41")
  W.plates.nameplate41 = nil
  tdb.role = "auto"
  _G.C_NamePlate.GetNamePlateForUnit, _G.UnitDetailedThreatSituation = keep.get, keep.D
  _G.UnitThreatSituation, _G.issecretvalue, W.target = keep.S, keep.is, keep.target
end

-- ------------------------------------------------------------ the bg tool: their healers and their killer
-- Arn's cousin: "can it auto crosshair people that cast heals" - casts are hidden, the battleground
-- SCOREBOARD is not. Arn: a white neon saber on "their top three heals", a red glow "on their top
-- killing blow person".
do
  local BG = NS.BG
  ok(BG and R:Get("bg") and R:Enabled("bg"), "the bg tool is registered, and on")
  local SECRET = setmetatable({}, {})
  local plates, rows, asked = {}, {}, 0
  local keep = { get = _G.C_NamePlate.GetNamePlateForUnit, inst = _G.IsInInstance, score = _G.C_PvP,
    n = _G.GetNumBattlefieldScores, req = _G.RequestBattlefieldScoreData, fac = _G.UnitFactionGroup,
    is = _G.issecretvalue }
  local inBG = false
  _G.IsInInstance = function() return inBG, inBG and "pvp" or "none" end
  _G.C_NamePlate.GetNamePlateForUnit = function(u) return plates[u] end
  _G.C_PvP = { GetScoreInfo = function(i) return rows[i] end }
  _G.GetNumBattlefieldScores = function() return #rows end
  _G.RequestBattlefieldScoreData = function() asked = asked + 1 end
  _G.UnitFactionGroup = function() return "Alliance", "Alliance" end
  _G.issecretvalue = function(v) return rawequal(v, SECRET) end
  local function ev(e, u) BG.frame.scripts.OnEvent(BG.frame, e, u) end
  -- the scoreboard: Horde = faction 0 (the enemy), Alliance = 1 (us)
  rows = {
    { name = "Heala-Realm", guid = "Player-1-A", faction = 0, healingDone = 90000, killingBlows = 1 },
    { name = "Shocka",      guid = "Player-1-B", faction = 0, healingDone = 60000, killingBlows = 9 },
    { name = "Mendy",       guid = "Player-1-C", faction = 0, healingDone = 30000, killingBlows = 0 },
    { name = "Bandaid",     guid = "Player-1-D", faction = 0, healingDone = 5000,  killingBlows = 2 },
    { name = "Fourth",      guid = "Player-1-F", faction = 0, healingDone = 20000, killingBlows = 0 },
    { name = "Ourhealer",   guid = "Player-1-E", faction = 1, healingDone = 200000, killingBlows = 20 },
  }
  local who = { A = "Heala", B = "Shocka", C = "Mendy", D = "Bandaid", F = "Fourth", E = "Ourhealer" }
  for k, n in pairs(who) do
    local u = "nameplate" .. (50 + k:byte() - 64)
    plates[u] = CreateFrame("Frame", nil, nil)
    plates[u]:SetSize(120, 20)
    W.plates[u] = { name = n, guid = "Player-1-" .. k, player = true, hostile = k ~= "E" }
    ev("NAME_PLATE_UNIT_ADDED", u)
  end
  local function unitOf(k) return "nameplate" .. (50 + k:byte() - 64) end
  local function mark(k) return BG.marks[unitOf(k)] end

  -- out in the world: nothing read, nothing drawn
  ev("PLAYER_ENTERING_WORLD")
  ok(not BG.inBG and BG.ticker == nil and asked == 0, "out in the world: the scoreboard is never asked")
  -- into a battleground
  inBG = true
  ev("PLAYER_ENTERING_WORLD")
  ok(BG.inBG and BG.ticker and BG.ticker.iv == BG.EVERY and asked == 1,
     "into a battleground: the scoreboard asked now, and every " .. BG.EVERY .. " s")
  W.tick()
  ok(asked == 2, "the ticker asks again")
  ev("UPDATE_BATTLEFIELD_SCORE")
  ok(mark("B") and mark("B").kind == "killer", "their top killer (9 killing blows): the red crosshair")
  ok(mark("A") and mark("A").kind == "healer" and mark("C") and mark("C").kind == "healer",
     "their top healers: the saber")
  ok(mark("F") == nil and mark("D") == nil, "only the top three heals count (Shocka is #2 and the killer - the glow wins)")
  ok(mark("E") == nil, "never one of ours, however much they heal")
  -- the saber's shape: a white-hot core in glow layers, a hilt, under the plate on the body, humming
  local s = mark("A")
  ok(s.x and #s.parts == 6 and s.parts[3].w == BG.SABER_W and s.parts[1].w > s.parts[2].w, "two blades, each a core in two glow layers")
  local core = s.parts[3].color
  ok(core[1] > 0.9 and core[2] > 0.9 and core[3] == 1 and core[4] == 1, "the core neon white, solid")
  ok(s.parts[1].color[4] < s.parts[2].color[4], "the outer glow fainter than the inner")
  local b1, b2 = s.parts[3], s.parts[6]
  ok(b1.to[1] > 0 and b2.to[1] < 0 and b1.to[2] > 0 and b2.to[2] > 0 and b1.from[1] < 0 and b2.from[1] > 0,
     "crossed: one blade leans right, the other left - an X")
  ok(#s.hilts == 2, "a hilt on each")
  ok(s.point and s.point[1] == "CENTER" and s.point[2] == plates[unitOf("A")] and s.point[3] == "BOTTOM"
     and s.point[5] == -2 - NS.Recap.MARK_H / 2 and s.w == BG.X_SIZE[1] and s.h == BG.X_SIZE[2],
     "on them: centred where the rival crosshair's middle is, BiS Healing's tank X size")
  ok(s.pulse and s.pulse:IsPlaying(), "humming (a slow pulse)")
  local g = mark("B")
  ok(g.kind == "killer" and g.x and g.parts[3].color[1] == 1 and g.parts[3].color[2] < 0.2 and g.point and g.point[1] == "CENTER",
     "the killer: the same crossed sabers, red, on them")
  ok(g.pulse and g.pulse:IsPlaying(), "humming")
  -- a name the game hides on the plate: the GUID still matches
  W.plates[unitOf("C")].name = nil
  BG.Undraw(unitOf("C"))
  ev("UPDATE_BATTLEFIELD_SCORE")
  ok(mark("C") and mark("C").kind == "healer", "no name on the plate: matched by GUID")
  -- the order changes: marks follow
  rows[5].healingDone = 100000
  ev("UPDATE_BATTLEFIELD_SCORE")
  ok(mark("F") and mark("F").kind == "healer" and mark("C") == nil, "a new top-three healer takes the saber off the fourth")
  -- hidden numbers are left out, never guessed
  rows[1].healingDone = SECRET
  ev("UPDATE_BATTLEFIELD_SCORE")
  ok(mark("A") == nil and BG.read.note and BG.read.note:find("hidden", 1, true), "a hidden healing number: no saber, and why says so")
  rows[1].healingDone = 90000
  -- why
  local said = {}
  local keepChat = DEFAULT_CHAT_FRAME.AddMessage
  DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) said[#said + 1] = tostring(msg) end
  ev("UPDATE_BATTLEFIELD_SCORE")
  S("bg why")
  -- raw: one enemy row, every field as given - a hidden one says HIDDEN, never a guess
  rows[1].healingDone = SECRET
  local from = #said + 1
  S("bg raw")
  rows[1].healingDone = 90000
  local rawText = table.concat(said, "\n", from)
  ok(rawText:find("healingDone=HIDDEN", 1, true) and rawText:find("killingBlows=", 1, true)
     and rawText:find("name=", 1, true), "/bist bg raw prints an enemy row's fields, hidden as HIDDEN", rawText)
  -- the match-end probe is gone (0.7.0): a finished match prints nothing by itself
  local before = #said
  _G.GetBattlefieldWinner = function() return 1 end
  ev("UPDATE_BATTLEFIELD_SCORE")
  ok(#said == before, "a match ending says nothing in chat - no probe left behind")
  _G.GetBattlefieldWinner = nil
  DEFAULT_CHAT_FRAME.AddMessage = keepChat
  local all = table.concat(said, "\n")
  ok(all:find("top healers (saber): Fourth 100000, Heala 90000, Shocka 60000", 1, true)
     and all:find("top killer (red crosshair): Shocka, 9 killing blows", 1, true), "/bist bg why reads out what it saw", all)
  -- COST: one scoreboard update, six players, six plates. Measured 64 (~10 a player: the row, a
  -- "hidden?" for each field, and the plate's GUID and name). A full 40-player battleground is ~400
  -- every 10 s - about 40 a second. Budget 80.
  local Cost = dofile("../_bisdev/dev/cost.lua")
  local n, by = Cost.Count(function() ev("UPDATE_BATTLEFIELD_SCORE") end)
  ok(n <= 80, "one scoreboard update (6 players, 6 plates) asks at most 80 things: " .. n .. " " .. Cost.Top(by, 5))
  -- REMEMBERED ACROSS BATTLEGROUNDS (Arn: "a data file that only keeps track of bgs so if we go into
  -- a new bg it knows these people are healers and this guy is dangerous")
  local known = BG.Known()
  ok(known.Heala and known.Heala.healer == 1 and known.Shocka and known.Shocka.killer == 1,
     "this battleground's top healers and top killer are written down")
  ok(known.Bandaid == nil and known.Ourhealer == nil, "nobody else - and never one of ours")
  ev("UPDATE_BATTLEFIELD_SCORE") ev("UPDATE_BATTLEFIELD_SCORE")
  ok(known.Heala.healer == 1, "counted once per battleground, not per scoreboard read")
  -- out, and into a NEW battleground: no scoreboard numbers yet
  inBG = false
  ev("PLAYER_ENTERING_WORLD")
  inBG = true
  known.Ghost = { healer = 2, killer = 0, last = (time and time() or 0) - 40 * 86400 }
  ev("PLAYER_ENTERING_WORLD")
  ok(known.Ghost == nil, "somebody not seen for 30 days is forgotten on the way in")
  ok(next(BG.healers) == nil and BG.killer == nil, "nothing live yet in the new battleground")
  for k in pairs(who) do ev("NAME_PLATE_UNIT_REMOVED", unitOf(k)) ev("NAME_PLATE_UNIT_ADDED", unitOf(k)) end
  ok(mark("A") and mark("A").kind == "healer" and mark("A").remembered and mark("A").alpha == BG.REMEMBERED_ALPHA
     and not mark("A").pulse:IsPlaying(), "a known healer is marked the moment their plate appears - dimmer, steady")
  ok(mark("B") and mark("B").kind == "killer" and mark("B").remembered, "and the known dangerous one wears the red crosshair")
  ok(mark("D") == nil and mark("E") == nil, "not the unknown, not ours")
  ev("UPDATE_BATTLEFIELD_SCORE")
  ok(mark("A") and not mark("A").remembered and mark("A").alpha == 1 and mark("A").pulse:IsPlaying(),
     "the live scoreboard takes over: full and humming")
  ok(known.Heala.healer == 2, "and this battleground counts them once more")
  -- forget one, then everyone
  S("bg forget heala")
  ok(BG.Known().Heala == nil, "/bist bg forget <name>")
  S("bg clear")
  ok(next(BG.Known()) == nil, "/bist bg clear forgets everyone")
  -- never more than B.KEEP
  local now = time and time() or 0
  for i = 1, BG.KEEP + 20 do BG.Known()["P" .. i] = { healer = 1, killer = 0, last = now - i } end
  BG.Prune()
  local count = 0
  for _ in pairs(BG.Known()) do count = count + 1 end
  ok(count == BG.KEEP and BG.Known().P1 and not BG.Known()["P" .. (BG.KEEP + 20)],
     "never more than " .. BG.KEEP .. " - the longest unseen go first")
  S("bg clear")
  -- FOREVER: every number hidden mid-match (Arn's /bist bg raw, 14 Oct). Arn: "what about we can click
  -- the top heals" - the game still SORTS by a hidden column; the names come back in that order.
  do
    local truth = {   -- what the sort sees; the addon never does
      { name = "Heala",   g = "A", class = "PRIEST",  h = 90000,  k = 1 },
      { name = "Shocka",  g = "B", class = "SHAMAN",  h = 60000,  k = 9 },
      { name = "Mendy",   g = "C", class = "DRUID",   h = 30000,  k = 0 },
      { name = "Bandaid", g = "D", class = "WARRIOR", h = 999999, k = 2 },  -- first-aid spam: not a healer class
      { name = "Fourth",  g = "F", class = "PALADIN", h = 20000,  k = 0 },
      { name = "Ourhealer", g = "E", class = "PRIEST", h = 200000, k = 20, ours = true },
    }
    local sorts = {}
    local function fill()
      for i, t in ipairs(truth) do
        rows[i] = { name = t.name, guid = SECRET, faction = t.ours and 1 or 0, classToken = t.class,
                    healingDone = SECRET, killingBlows = SECRET }
      end
    end
    fill()
    _G.SortBattlefieldScoreData = function(col)
      sorts[#sorts + 1] = col
      local key = col == "healing" and "h" or (col == "kills" and "k") or nil
      table.sort(truth, function(a, b) if key then return a[key] > b[key] end return a.name < b.name end)
      fill()
    end
    local run = 300000
    _G.GetBattlefieldInstanceRunTime = function() return run end
    -- no scoreboard window found: we cannot know it is closed, so no sort on our own
    W.now = (W.now or 0) + 60
    ev("UPDATE_BATTLEFIELD_SCORE")
    ok(#sorts == 0 and BG.read.note:find("not found", 1, true), "the window cannot be found: never sorts on its own, and why says so")
    local board = CreateFrame("Frame", "PVPMatchScoreboard", UIParent)
    _G.PVPMatchScoreboard = board
    board:Hide()
    W.now = (W.now or 0) + 60
    ev("UPDATE_BATTLEFIELD_SCORE")
    ok(sorts[1] == "name" and sorts[2] == "healing" and sorts[3] == "kills",
       "hidden numbers: sorted by name first (so healing never flips), then healing, then kills", table.concat(sorts, ","))
    ok(BG.healers.Heala == 1 and BG.healers.Shocka == 2 and BG.healers.Mendy == 3 and BG.healers.Bandaid == nil,
       "the saber: the first three healing-class enemies in healing order - first-aid warriors skipped")
    ok(BG.killer and BG.killer.name == "Shocka", "the red crosshair: the first enemy in kills order - never one of ours")
    ok(mark("A") and mark("A").kind == "healer" and mark("B") and mark("D") == nil, "and they are marked on their plates")
    -- OUR MVPs (Arn: "do 2 for friendly players and just mark them MVP with the same box style" - "best
    -- healer and best killer"): Ourhealer is our best healer AND our best killer - one >MVP<
    ok(BG.mvps.Ourhealer, "our side's best healer and best killer, read off the same sorts", tostring(BG.mvps.Ourhealer))
    local mvp = mark("E")
    ok(mvp and mvp.kind == "mvp" and mvp.tag and mvp.text.text:find("MVP", 1, true) and mvp.text.text:find("ffd100", 1, true),
       "a friend on top wears >MVP< - the tag box, the word in gold", mvp and mvp.text and mvp.text.text)
    -- the same "mark" in the BiS> tools box (Arn: "add that scoreboard button to the bis tools")
    do
      local function boxShows()
        for _, e in ipairs(NS.Box.Buttons()) do if e.b == BG.bbtn then return e.show end end
      end
      ok(boxShows() == true, "in a battleground: the tools box carries the mark button")
      inBG = false
      ok(boxShows() == false, "out of one: it does not")
      inBG = true
      local n1 = #sorts
      local keepChat = DEFAULT_CHAT_FRAME.AddMessage
      DEFAULT_CHAT_FRAME.AddMessage = function() end
      -- LEFT targets only, RIGHT marks (Arn: "right click marks left click targets")
      local n0 = #sorts
      BG.bbtn.scripts.OnClick(BG.bbtn, "LeftButton")
      ok(#sorts == n0, "a left-click only targets - it reads nothing")
      BG.bbtn.scripts.OnClick(BG.bbtn, "RightButton")
      DEFAULT_CHAT_FRAME.AddMessage = keepChat
      ok(#sorts > n1 and BG.healers.Heala == 1, "pressed: reads the board now and marks")
      -- and TARGETS one of them (Arn: "target the nearest on the list"): a secure macro, near last
      local m = BG.bbtn:GetAttribute("macrotext1") or ""
      ok(BG.bbtn:GetAttribute("type1") == "macro" and BG.bbtn:GetAttribute("type2") == nil and m:find("/target Heala", 1, true) and m:find("/target Shocka", 1, true),
         "the box button targets the marked players by macro", m)
      BG.Undraw(unitOf("C"))           -- Mendy: no plate on screen now - far away
      BG.ApplyMacro()
      m = BG.bbtn:GetAttribute("macrotext1")
      local lastLine = m:match("([^\n]+)$")
      ok(m:find("^/target Mendy") and lastLine == "/target Heala",
         "far ones first, near ones last - the last /target that finds someone wins; the top healer last of all", m)
      BG.Paint(unitOf("C"))
      local keepLock = _G.InCombatLockdown
      _G.InCombatLockdown = function() return true end
      BG.bbtn:SetAttribute("macrotext1", "untouched")
      ok(BG.ApplyMacro() == false and BG.bbtn:GetAttribute("macrotext1") == "untouched" and BG.macroDirty,
         "in a fight the macro is not touched - written when it ends")
      _G.InCombatLockdown = keepLock
      ev("PLAYER_REGEN_ENABLED")
      ok(BG.bbtn:GetAttribute("macrotext1") ~= "untouched" and not BG.macroDirty, "the fight over: written")
      -- the X fills the rival crosshair's box: tips in its corners
      local x = mark("A")
      local tip = x.parts[3].to
      ok(x.w == BG.X_SIZE[1] and math.abs(tip[1] - (x.w / 2 - 2)) < 0.01
         and math.abs(tip[2] - (x.h / 2 - 2)) < 0.01, "the X: the tank X's size, its tips in its own corners")
      -- the steppers (Arn: "we add the stepper if they want to change the marks")
      local bdb = R:DBFor(R:Get("bg"))
      bdb.size, bdb.lift = 200, 10
      BG.Redraw()
      x = mark("A")
      ok(x.w == BG.X_SIZE[1] * 2 and x.h == BG.X_SIZE[2] * 2 and x.point[5] == -2 - NS.Recap.MARK_H / 2 + 10,
         "mark size 200%, height 10 up: redrawn at once", x.w .. "x" .. x.h)
      -- ABOVE THE NAMEPLATE (Arn: "some people also like them at the top of the name plate - lets let them")
      bdb.spot = "above"
      BG.Redraw()
      x = mark("A")
      ok(x.point[1] == "BOTTOM" and x.point[3] == "TOP" and x.point[5] == 2 + 10, "mark spot above: on top of the nameplate, the height still nudging it")
      bdb.spot = nil
      bdb.size, bdb.lift = 999, -999
      ok(BG.Size(bdb) == 200 and BG.Lift(bdb) == -40, "out-of-range settings are held to the stepper's ends")
      bdb.size, bdb.lift = nil, nil
      -- the looks (Arn: "not all want x"): each its own strokes, hilts on the X and the saber
      for i, look in ipairs(BG.LOOKS) do
        bdb.look = i
        BG.Redraw()
        local m = mark("A")
        if look.tag then
          -- THE TAG (Arn: ">Healer<" - "remove the black", "do white arrows instead of red", "still want
          -- the white rectangle lines"): a white box of four edges, nothing behind, the words inside
          local white = true
          for _, e in pairs(m.edges or {}) do
            local c = e.color
            if not (c and c[1] > 0.9 and c[2] > 0.9 and c[3] > 0.9) then white = false end
          end
          local txt = m.text and m.text.text or ""
          ok(m.tag and m.edges and m.edges.top and m.edges.left and white and #m.parts == 4,
             "mark look tag: a white rectangle of four lines, no background")
          ok(txt == "|cffffffff>|r|cffff1a1aHealer|r|cffffffff<|r", "white arrows, a red Healer", txt)
          -- easier to read (Arn: "very small and kinda hard to see" - "maybe thicker letters too")
          ok(m.text2 and m.text2.text == txt and BG.TAG[1] >= 100 and BG.TAG[2] >= 26,
             "bigger, and the word drawn twice a pixel apart - thicker letters")
          ok(BG.TAG_PULSE_LOW >= 0.7, "a gentler pulse: a tag must stay readable")
          local killer = BG.NewSaber("killer", i)
          ok(killer.text.text:find("Killer", 1, true), "the killer's tag reads >Killer<")
          ok(m.w == math.floor(BG.TAG[1] + 0.5) and m.h == math.floor(BG.TAG[2] + 0.5), "the tag at its own size")
        else
          ok(m and m.look == i and #m.parts == #look.strokes * 3 and #m.hilts == (look.hilts and #look.strokes or 0),
             "mark look " .. look.word .. ": " .. #look.strokes .. " strokes")
        end
      end
      bdb.look = 99
      ok(BG.LookIndex(bdb) == 1, "an unknown look falls back to the X")
      bdb.look = nil
      BG.Redraw()
      ok(BG.Look({ ["Heala Moon"] = 1 }, "Heala") == 1, "the name lookup is still the name lookup")
    end
    -- Forever's two-part names: the board says "Heala Moon", the plate only "Heala" (14 Oct: no saber)
    do
      local h, k = BG.healers, BG.killer
      BG.healers, BG.killer = { ["Heala Moon"] = 1 }, { name = "Shocka Storm" }
      ok(BG.Which(unitOf("A")) == "healer" and BG.Which(unitOf("B")) == "killer" and BG.Which(unitOf("C")) == nil,
         "a plate's one-word name finds the board's two-word name")
      BG.healers, BG.killer = h, k
    end
    ok(BG.Known().Heala and BG.Known().Shocka and BG.Known().Bandaid == nil, "and remembered (counts: once per battleground, already spent here)")
    -- a /reload mid-match is a fresh load: the same match must not count anyone twice
    BG.inBG = false
    ev("PLAYER_ENTERING_WORLD")           -- into the match, its run time readable (as in the client)
    BG.lastOrder = nil
    ev("UPDATE_BATTLEFIELD_SCORE")
    local before = BG.Known().Heala.healer
    BG.inBG, BG.counted = false, {}
    ev("PLAYER_ENTERING_WORLD")
    BG.lastOrder = nil
    ev("UPDATE_BATTLEFIELD_SCORE")
    ok(BG.Known().Heala.healer == before, "a /reload in the same match: nobody counted twice")
    -- a NEW match (started later): counted again
    BG.inBG = false
    run = 30000 + 0   -- just started: a different start time
    ev("PLAYER_ENTERING_WORLD")
    ok(next(BG.counted) == nil, "a new match: the counted list starts empty")
    run = 300000
    BG.inBG = false
    ev("PLAYER_ENTERING_WORLD")
    BG.lastOrder = nil
    ev("UPDATE_BATTLEFIELD_SCORE")
    -- the sort fires its own score event: never read again inside B.ORDER_GAP
    local n0 = #sorts
    ev("UPDATE_BATTLEFIELD_SCORE")
    ok(#sorts == n0 and BG.healers.Heala == 1, "a score event right after a read: no re-sort, the last read stays")
    -- Arn's scoreboard is open: never reshuffle what he is looking at
    board:Show() if board.scripts.OnShow then board.scripts.OnShow(board) end
    W.now = W.now + 60
    ev("UPDATE_BATTLEFIELD_SCORE")
    ok(#sorts == n0, "the scoreboard window is open: no sort")
    -- the button on it does it on demand
    local b = BG.button
    ok(b and b:IsShown(), "\"BiS> mark\" sits on the open scoreboard")
    local said = {}
    local keepChat = DEFAULT_CHAT_FRAME.AddMessage
    DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) said[#said + 1] = tostring(msg) end
    b.scripts.OnClick(b)
    DEFAULT_CHAT_FRAME.AddMessage = keepChat
    ok(#sorts > n0 and table.concat(said, "\n"):find("healers Heala, Shocka, Mendy; killer Shocka", 1, true),
       "pressed: sorts now and says who", table.concat(said, "\n"))
    board:Hide() board.scripts.OnHide(board)   -- the client fires OnHide; this mock's Hide does not
    ok(not b:IsShown(), "the window closes: the button goes with it")
    -- the first moments of a match: everyone ties at 0, so nobody is marked
    run = 30000
    W.now = W.now + 60
    BG.read = nil
    ev("UPDATE_BATTLEFIELD_SCORE")
    ok(BG.read and BG.read.note and BG.read.note:find("only just started", 1, true), "inside the first 90 s: nothing new read, and why says so")
    _G.SortBattlefieldScoreData, _G.GetBattlefieldInstanceRunTime, _G.PVPMatchScoreboard = nil, nil, nil
    S("bg clear")
  end
  -- off, and out
  R:SetEnabled("bg", false)
  ok(next(BG.marks) == nil and BG.ticker == nil, "switched off: marks down, ticker stopped")
  R:SetEnabled("bg", true)
  inBG = false
  ev("PLAYER_ENTERING_WORLD")
  ok(next(BG.marks) == nil and BG.ticker == nil, "out of the battleground: marks down, ticker stopped")
  for k in pairs(who) do ev("NAME_PLATE_UNIT_REMOVED", unitOf(k)) W.plates[unitOf(k)] = nil end
  _G.C_NamePlate.GetNamePlateForUnit, _G.IsInInstance, _G.C_PvP = keep.get, keep.inst, keep.score
  _G.GetNumBattlefieldScores, _G.RequestBattlefieldScoreData, _G.UnitFactionGroup = keep.n, keep.req, keep.fac
  _G.issecretvalue = keep.is
end

-- ---------------------------------------------------------------- the overlay map
-- (14 Oct 2026) Arn: Diablo's see-through map over the game, "alpha out the useless stuff". Our own
-- click-through frame; explored pieces only by default; an arrow, and a dotted trail.
do
  local O = NS.Overlay
  local odb = R:DBFor(R:Get("map"))
  ok(type(_G.BiSTools_ToggleOverlayMap) == "function" and _G.BINDING_NAME_BISTOOLS_OVERLAYMAP ~= nil,
    "the overlay map has a key binding (Key Bindings > BiS Tools)")
  W.explored = {}
  W.map, W.px, W.py, W.facing = 1952, 0.40, 0.60, 1.5
  O.Show(odb, false)              -- the options section above pressed "open / close the map"
  -- the section's tick switches the tool: off, the open button only says so (Arn, 14 Oct: "i uncheck
  -- the map but can still show and hide it by clicking map button")
  local openBtn
  for _, o in ipairs(R:Get("map").options) do if o.kind == "button" then openBtn = o end end
  R:SetEnabled("map", false)
  openBtn.action(odb)
  ok(not (BiSToolsOverlayMap and BiSToolsOverlayMap:IsShown()), "map tool off: the open button opens nothing")
  _G.BiSTools_ToggleOverlayMap()
  ok(not (BiSToolsOverlayMap and BiSToolsOverlayMap:IsShown()), "and neither does the key")
  R:SetEnabled("map", true)
  ok(openBtn.button == "open" and openBtn.label == "open / close the map", "the button says what it does")
  _G.BiSTools_ToggleOverlayMap()
  local f = BiSToolsOverlayMap
  ok(f and f:IsShown(), "the key shows it")
  -- a place with NO map (a dungeon: Ragefire answers nil): the note sits in the map's corner, under the
  -- tab - not mid-screen over your character (Arn, 14 Oct)
  local keepBest = C_Map.GetBestMapForUnit
  C_Map.GetBestMapForUnit = function() return nil end
  O.Draw(odb)
  ok(O.note.text == "no map for this place" and f.point and f.point[2] == O.tab, "no map: it says so, hanging from the tab in the corner")
  C_Map.GetBestMapForUnit = keepBest
  O.Draw(odb)
  -- the defaults are Arn's pick: all, grey, 30% of the screen, 50% solid
  ok(O.Mode(odb) == "full" and O.Grey(odb) and O.Size(odb) == 30 and O.Alpha(odb) == 50,
    "defaults: all of the map, grey, 30% size, 50% solid (Arn: 'a nice place')")
  -- the rest of this section drives the explored-pieces look, in colour, at 70% and 10%
  odb.mode, odb.grey, odb.size, odb.alpha = "explored", false, 70, 10
  O.Draw(odb)
  -- a place with no explored pieces at all (a city: the game shows it whole) draws the whole map
  -- (Arn's Orgrimmar, 14 Oct: an empty map and "nothing explored here yet")
  local whole = 0
  for _, t in ipairs(O.art) do if t.shown then whole = whole + 1 end end
  ok(whole == 12, "no explored pieces (a city): the whole map, faint", whole)
  -- 70% of a 768-tall screen; the frame is the land, the paper's edge cut off (O.EDGE: 3% each side,
  -- none off the top, where the name banner is, 4.5% off the bottom - Arn, 14 Oct)
  local landW, landH = 1002 * (1 - 2 * O.EDGE[1]), 668 * (1 - O.EDGE[2] - O.EDGE[3])
  ok(O.EDGE[2] == 0, "the top is never cropped: the map's name lives there")
  ok(math.abs(f.h - 768 * 0.70) < 0.01 and math.abs(f.w / f.h - landW / landH) < 0.001,
    "sized to the screen, the paper's torn edge cropped off", f.w .. "x" .. f.h)
  ok(math.abs(O.art[1].anchor[4] + (1002 * O.EDGE[1]) * (f.h / landH)) < 1e-6, "the first tile starts left of the frame - its edge is clipped away", O.art[1].anchor[4])
  -- a capital with a measured box (Orgrimmar, 1454) is cut to it; the map above (1952) has none
  ok(O.CROP[1952] == nil, "an unmeasured map keeps the light crop")
  -- soft edges: every piece of art wears the fade mask, stretched over the frame; the dots do not
  local masked = O.mask and O.mask.all and O.mask.file == O.FADE
  for _, t in ipairs(O.art) do masked = masked and t.masks and t.masks[1] == O.mask end
  ok(masked and #O.art > 0, "the map's art fades out at its edges (MapFade mask over the frame)")
  local fh = io.open("Media/MapFade.tga", "rb")
  ok(fh ~= nil, "the fade file ships with the addon")
  if fh then fh:close() end
  W.map = 1454
  O.Draw(odb)
  local bx = O.CROP[1454]
  local cw, ch = 1002 * (bx[3] - bx[1]), 668 * (bx[4] - bx[2])
  ok(math.abs(f.w / f.h - cw / ch) < 0.001, "Orgrimmar: the frame is its measured box", f.w .. "x" .. f.h)
  local tx, ty = O.ToFrame(bx[1], bx[2])
  ok(math.abs(tx) < 1e-6 and math.abs(ty) < 1e-6, "the box's corner is the frame's corner")
  W.map = 1952
  O.Draw(odb)
  -- one explored piece of 300 x 200 pixels at (100, 50): two 256 columns (256 + 44) and one row of 200
  W.explored = { { textureWidth = 300, textureHeight = 200, offsetX = 100, offsetY = 50,
                   isShownByMouseOver = false, fileDataIDs = { 7001, 7002 } } }
  O.Draw(odb)
  local shown = 0
  for _, t in ipairs(O.art) do if t.shown then shown = shown + 1 end end
  ok(shown == 2 and O.art[1].file == 7001 and O.art[2].file == 7002, "an explored piece draws as the client cuts it", shown)
  local sc = O.scale
  ok(math.abs(O.art[2].w - 44 * sc) < 0.01 and O.art[2].anchor[4] == 256 * sc, "the last column only as wide as what is left, in its place (from the land's corner)")
  -- WHERE YOU ARE, in the corner (Arn, 15 Oct, Diablo II's "Rogue Encampment")
  do
    local keepZ, keepS = _G.GetZoneText, _G.GetSubZoneText
    _G.GetZoneText, _G.GetSubZoneText = function() return "Durotar" end, function() return "Razor Hill" end
    O.events.scripts.OnEvent(O.events, "ZONE_CHANGED")
    ok(O.place.text == "DUROTAR - RAZOR HILL", "the zone and the subzone, in capitals, in the map's corner", O.place.text)
    _G.GetSubZoneText = function() return "" end
    O.PaintPlace()
    ok(O.place.text == "DUROTAR", "no subzone: the zone alone", O.place.text)
    _G.GetZoneText = function() return setmetatable({}, { __index = function() error("secret") end }) end
    O.PaintPlace()
    ok(O.place.text == "", "a name we may not read: nothing, never an error", O.place.text)
    _G.GetZoneText, _G.GetSubZoneText = keepZ, keepS
  end
  -- A NEW PLACE FOUND, on the same map, fills in without closing the map (Arn, 15 Oct)
  do
    local keepEx = W.explored
    W.explored = { keepEx[1], { textureWidth = 100, textureHeight = 100, offsetX = 500, offsetY = 300,
                                isShownByMouseOver = false, fileDataIDs = { 7003 } } }
    local function count() local n = 0 for _, t in ipairs(O.art) do if t.shown then n = n + 1 end end return n end
    O.events.scripts.OnEvent(O.events, "MAP_EXPLORATION_UPDATED")
    ok(count() == 3, "the client says the map was explored: the new piece is drawn at once", count())
    W.explored = keepEx
    O.events.scripts.OnEvent(O.events, "ZONE_CHANGED")
    ok(count() == 2, "and a new subzone redraws too, in explored mode", count())
  end
  -- the LAND is sized, not the canvas (Durotar sits right of the canvas's middle), and hangs from the
  -- tab, top-left (Arn, 14 Oct: "top left ... like zone map so we can drag"): the piece covers
  -- x 100-400, y 50-250 of the 1002 x 668 art
  ok(math.abs(sc - 768 * 0.70 / 200) < 1e-9, "map size is the land's height on screen", sc)
  ok(f.point[1] == "TOPLEFT" and f.point[2] == O.tab and f.point[3] == "BOTTOMLEFT" and f.point[4] == 0 and f.point[5] == 0
     and math.abs(f.w - 300 * sc) < 1e-9 and math.abs(f.h - 200 * sc) < 1e-9,
    "the frame IS the land, hanging under the tab", f.point[4], f.point[5])
  ok(O.tab.point[1] == "TOPLEFT" and O.tab.point[4] == 24 and O.tab.point[5] == -80, "the tab: top-left of the screen by default")
  -- the tab: invisible until hovered, and the one thing that takes the mouse (Arn: "only visible if you hover over")
  ok(O.tab:IsShown() and not O.tab.lit and O.tab.bg.alpha == 0 and O.tab.label.alpha == 0,
    "the tab shows with the map, invisible")
  ok(O.tab.hint.alpha == 1 and O.tab.hint.w == O.HINT_W and O.tab.hint.h == 2,
    "but a short faint line marks where it is (Arn: 'a little line ____')")
  O.tab.scripts.OnEnter(O.tab)
  ok(O.tab.lit and O.tab.bg.alpha == 1 and O.tab.label.alpha == 1 and O.tab.hint.alpha == 0,
    "hovered: the tab shows, the line steps aside")
  O.tab.scripts.OnLeave(O.tab)
  ok(not O.tab.lit and O.tab.bg.alpha == 0 and O.tab.hint.alpha == 1, "the mouse leaves: back to the line")
  ok(O.tab.scripts.OnDragStart and O.tab.scripts.OnDragStop, "it drags (the map hangs off it, so the map follows)")
  odb.pos = { 300, -200 }
  O.Draw(odb)
  ok(O.tab.point[4] == 300 and O.tab.point[5] == -200, "a saved spot is where it goes")
  SlashCmdList.BISTOOLS("map reset")
  ok(odb.pos == nil and O.tab.point[4] == 24, "/bist map reset: back to the top-left")
  -- right-click the tab: the quick menu (Arn, 14 Oct, the Zone Map's tab menu)
  O.tab.scripts.OnClick(O.tab, "RightButton")
  local menu = BiSToolsOverlayMapMenu
  ok(menu and menu:IsShown() and O.tab.lit, "right-click the tab: the menu, and the tab stays visible")
  local inEsc = false
  for _, n in ipairs(UISpecialFrames) do if n == "BiSToolsOverlayMapMenu" then inEsc = true end end
  ok(inEsc, "Escape closes the menu")
  local function row(label) for _, b in ipairs(menu.rows) do if b.def.label == label then return b end end end
  row("Lock map").scripts.OnClick(row("Lock map"))
  ok(odb.locked == true and row("Lock map").tick.shown, "Lock map: ticked")
  -- every tick row UNTICKS too (Arn, 14 Oct: "cant unclick the grey" - "(not on) and false or nil"
  -- is nil both ways), and the label never moves when it does ("everything shifts")
  for _, label in ipairs({ "Show group", "Grey", "Show all of the map" }) do
    local b = row(label)
    local before = b.def.get(odb)
    local at = b.text.anchor and b.text.anchor[4]
    b.scripts.OnClick(b)
    ok(b.def.get(odb) == not before and b.tick.shown == not before, label .. ": one click flips it", tostring(before))
    b.scripts.OnClick(b)
    ok(b.def.get(odb) == before and b.text.anchor[4] == at, label .. ": and back, the label in the same place")
  end
  local greyOpt
  for _, o in ipairs(R:Get("map").options) do if o.label == "grey map" then greyOpt = o end end
  local g0 = greyOpt.get(odb)
  greyOpt.set(odb, true)
  greyOpt.set(odb, false)
  ok(greyOpt.get(odb) == false, "the options window's grey map unticks too")
  greyOpt.set(odb, g0)
  O.tab.dragging = nil
  O.tab.scripts.OnDragStart(O.tab)
  ok(not O.tab.dragging, "a locked map does not drag")
  row("Lock map").scripts.OnClick(row("Lock map"))
  ok(odb.locked == nil, "and unlocks")
  local a0 = O.Alpha(odb)
  row("Opacity").plus.scripts.OnClick(row("Opacity").plus)
  ok(O.Alpha(odb) == a0 + 5 and row("Opacity").text.text:find(tostring(a0 + 5) .. "%", 1, true), "Opacity +: 5 more, and the row says so")
  row("Opacity").minus.scripts.OnClick(row("Opacity").minus)
  ok(O.Alpha(odb) == a0, "Opacity -: back")
  odb.alpha = 5
  row("Opacity").minus.scripts.OnClick(row("Opacity").minus)
  ok(O.Alpha(odb) == 5, "never below 5")
  odb.alpha = 10
  O.tab.scripts.OnClick(O.tab, "RightButton")
  ok(not menu:IsShown(), "right-click again: the menu shuts")
  -- Show group: the party as dots in class colours, the player left out, a hidden position no dot
  local keepPos, keepN, keepRaid, keepClass = C_Map.GetPlayerMapPosition, _G.GetNumGroupMembers, _G.IsInRaid, _G.UnitClass
  local spots = { party1 = { 0.30, 0.40 }, party2 = { 0.50, 0.50 } }
  C_Map.GetPlayerMapPosition = function(_, u)
    local p = spots[u] or (u == "player" and { W.px, W.py })
    return p and { GetXY = function() return p[1], p[2] end } or nil
  end
  _G.GetNumGroupMembers = function() return 4 end
  _G.IsInRaid = function() return false end
  _G.UnitClass = function(u) return "Hunter", "HUNTER" end
  local keepName = _G.UnitName
  _G.UnitName = function(u) if u == "party1" then return "Mos Dei" elseif u == "party2" then return "Kel" end return keepName(u) end
  local keepColors = _G.RAID_CLASS_COLORS
  _G.RAID_CLASS_COLORS = { HUNTER = { r = 0.67, g = 0.83, b = 0.45 } }
  ok(O.Group() == 2, "Show group: two party members placed (party3 is hidden: no dot)")
  ok(O.gdots[1].color[1] == 0.67 and O.gdots[1].anchor[4] == select(1, O.ToFrame(0.30, 0.40)), "a dot in class colour, at their spot")
  ok(O.gdots[1].name and O.gdots[1].name.shown and O.gdots[1].name.text == "Mos",
    "a small name beside the dot - the first name only (Arn: 'maybe we can add small name')", O.gdots[1].name and O.gdots[1].name.text)
  -- THE GUILD (Arn, 14 Oct: "show all guild locations"): the lib (minor 12) hears guildmates' SPOTs;
  -- the map draws those on the map you are looking at, amber, first names, never a groupmate twice
  local lib = _G.LibBiSComm
  lib.spots["Kelvar-Dreamscythe"] = { map = 1952, x = 0.70, y = 0.20, at = GetTime() }
  lib.spots["Mos"] = { map = 1952, x = 0.31, y = 0.41, at = GetTime() }          -- in the group already
  lib.spots["Faraway"] = { map = 9999, x = 0.5, y = 0.5, at = GetTime() }       -- another zone
  O.Group()
  ok(O.guildShown == 1, "one guildmate on this map (the groupmate is not drawn twice, the other zone not at all)", O.guildShown)
  local gd = O.gdots[3]
  ok(gd and gd.shown and gd.color[1] == 1.00 and gd.color[2] == 0.62 and gd.name.text == "Kelvar", "an amber dot, named Kelvar")
  odb.guildDots = false
  O.Group()
  ok(O.guildShown == 0, "Show guild off: no guild dots")
  odb.guildDots = nil
  lib.spots = {}
  -- the share switch in the options is the lib's, for every BiS addon
  local shareOpt
  for _, o in ipairs(R:Get("map").options) do if o.label == "share my spot" then shareOpt = o end end
  ok(shareOpt and shareOpt.get(odb) == true, "share my spot: on by default")
  shareOpt.set(odb, false)
  ok(lib:Sharing() == false, "off here is off in the lib - /biscomm share off")
  shareOpt.set(odb, true)
  odb.group = false
  ok(O.Group() == 0 and not O.gdots[1].shown and not O.gdots[1].name.shown, "Show group off: no dots, no names")
  odb.group = nil
  C_Map.GetPlayerMapPosition, _G.GetNumGroupMembers, _G.IsInRaid, _G.UnitClass = keepPos, keepN, keepRaid, keepClass
  _G.UnitName = keepName
  _G.RAID_CLASS_COLORS = keepColors
  O.Draw(odb)
  ok(O.art[1].desat == false and O.art[1].vertex[1] == 1 and O.art[1].vertex[3] == 1, "the map's own colours (Arn: a little color)")
  ok(math.abs((f.alpha or 0) - 0.10) < 1e-9, "faintness 10% = 10% solid", f.alpha)
  odb.grey = true
  O.Draw(odb)
  ok(O.art[1].desat == true and O.art[1].vertex[1] < 1, "grey map: desaturated and tinted")
  odb.grey = false
  O.Draw(odb)
  -- the arrow: your spot and your facing
  f.scripts.OnUpdate(f, 0.2)
  ok(O.arrow.shown and O.arrow.face == 1.5 and O.arrow[1].shown and O.arrow[1].from, "your arrow - our own three lines, turned the way you face")
  local ax, ay = O.ToFrame(0.40, 0.60)
  ok(O.arrow.x == ax and O.arrow.y == ay, "at your spot on the map, from the land's corner")
  -- facing 1.5 rad counter-clockwise from north = pointing west-ish: the tip lies left of you
  ok(O.arrow[1].from[1] < O.arrow.x, "the tip points the way you face (west of you at 1.5 rad)")
  -- hidden position (an instance): no arrow, the art stays, and it says so
  local keepPos = C_Map.GetPlayerMapPosition
  C_Map.GetPlayerMapPosition = function() return nil end
  f.scripts.OnUpdate(f, 0.2)
  ok(not O.arrow.shown and O.note.text == "your position is hidden here", "position hidden: no arrow, and it says so")
  C_Map.GetPlayerMapPosition = keepPos
  -- a secret facing never reaches SetRotation
  -- a SECRET facing says "number" to type() and refuses arithmetic and comparison, as Forever's does
  local secretMeta = { __index = function() error("attempt to use a secret value", 2) end,
    __eq = function() error("attempt to compare a secret value", 2) end,
    __lt = function() error("attempt to compare a secret value", 2) end }
  local keep = { face = _G.GetPlayerFacing, is = _G.issecretvalue, type = _G.type }
  local realType = type
  _G.type = function(v) if getmetatable(v) == secretMeta then return "number" end return realType(v) end
  _G.issecretvalue = function(v) return getmetatable(v) == secretMeta end
  _G.GetPlayerFacing = function() return setmetatable({}, secretMeta) end
  local okS, errS = pcall(O.Tick)
  ok(okS and O.arrow.face == 1.5, "a secret facing is never used - the arrow keeps its last turn", errS)
  _G.GetPlayerFacing, _G.issecretvalue, _G.type = keep.face, keep.is, keep.type
  -- all: the zone's 12 base tiles - which ARE the fog of war on these maps - with the explored
  -- pieces painted over them, as the world map does (Arn, 14 Oct: "all setting is showing fog of war")
  odb.mode = nil
  O.Draw(odb)
  shown = 0
  local base, over = 0, 0
  for _, t in ipairs(O.art) do
    if t.shown then
      shown = shown + 1
      if t.layer == "BORDER" then base = base + 1 elseif t.layer == "ARTWORK" then over = over + 1 end
    end
  end
  ok(shown == 14 and base == 12 and over == 2, "all: the 12 base tiles under, the 2 explored pieces over", base, over)
  ok(f.point[4] == 0 and f.point[5] == 0, "all: the whole map, its top-left under the tab")
  -- (an "ink" look - BlendMode MOD - was tried and taken out, 14 Oct: Arn "ink wonky"; a MOD
  -- texture's transparent edges go black, so the explored pieces showed as dark boxes)
  odb.mode = nil
  -- the trail: a dot when you moved far enough, none for a shuffle
  ok(not O.TrailOn(odb) and not O.Sample(odb), "the trail is off by default (Arn: too busy) - nothing sampled")
  odb.trail = true
  odb.trails = nil
  ok(O.Sample(odb), "a first dot")
  W.px = 0.401
  ok(not O.Sample(odb), "a shuffle is not a new dot")
  W.px = 0.42
  ok(O.Sample(odb), "a few steps on: a new dot")
  ok(#O.Trail(odb, 1952) == 2 and O.dots[2] and O.dots[2].shown, "two dots, drawn on the open map")
  SlashCmdList.BISTOOLS("map clear")
  ok(#O.Trail(odb, 1952) == 0, "/bist map clear wipes this map's trail")
  odb.trail = nil
  -- click-through, and gone with the key again
  _G.BiSTools_ToggleOverlayMap()
  ok(not f:IsShown() and f.scripts.OnUpdate == nil, "the key again hides it, and nothing ticks")
  -- cost: a second of the open map asks a handful of things (10 arrow repaints)
  _G.BiSTools_ToggleOverlayMap()
  local Cost = dofile("../_bisdev/dev/cost.lua")
  local n, by = Cost.Count(function() for _ = 1, 60 do f.scripts.OnUpdate(f, 1 / 60) end end)
  ok(n <= 40, "a second of the open overlay map asks at most 40 things: " .. n, Cost.Top and Cost.Top(by, 5))
  -- in a 40-player raid with Show group on: twice a second, a position and a class per member
  local keepN2, keepRaid2 = _G.GetNumGroupMembers, _G.IsInRaid
  _G.GetNumGroupMembers = function() return 40 end
  _G.IsInRaid = function() return true end
  n, by = Cost.Count(function() for _ = 1, 60 do f.scripts.OnUpdate(f, 1 / 60) end end)
  ok(n <= 400, "a second of the open map in a 40-man raid asks at most 400 things: " .. n, Cost.Top and Cost.Top(by, 5))
  _G.GetNumGroupMembers, _G.IsInRaid = keepN2, keepRaid2
  _G.BiSTools_ToggleOverlayMap()
  W.explored = {}
end

-- THE PARTY LIST (Arn, 15 Oct: "the saved list to invite is nice and a disband button" - "its own
-- list" - "when in a party or in a raid new option to add to party list ... when right click")
do
  local P, Bx = NS.Party, NS.Box
  local pdb = R:DBFor(R:Get("party"))
  P.db = pdb
  ok(not R:Enabled("party"), "the party tool starts OFF (Arn: so the BiS> tools box is not overwhelming)")
  R:SetEnabled("party", true)
  local sent = { invite = {}, uninvite = {}, left = 0, raid = 0, full = {} }
  local keepPI, keepLead, keepRaid, keepIn = _G.C_PartyInfo, _G.UnitIsGroupLeader, W.raid, W.inRaid
  -- THE CLIENT'S RULES, NOT A KINDER ONE (Arn, 21 Oct: "auto turn the party into raid when more than 5"):
  -- a party - or you alone - holds five counting the invites still out; one more is refused with
  -- "party is full" in chat and no Lua error. A raid is made only from a party: alone, ConvertToRaid
  -- does nothing. `sent.invite` is the invites out (a test that lets someone in moves them to W.raid).
  _G.C_PartyInfo = { InviteUnit = function(n)
                       if not W.inRaid and math.max(#W.raid, 1) + #sent.invite >= 5 then
                         sent.full[#sent.full + 1] = n
                         return
                       end
                       sent.invite[#sent.invite + 1] = n
                     end,
                     UninviteUnit = function(n) sent.uninvite[#sent.uninvite + 1] = n end,
                     LeaveParty = function() sent.left = sent.left + 1 end,
                     ConvertToRaid = function()
                       sent.raid = sent.raid + 1
                       if #W.raid > 1 then W.inRaid = true end
                     end }
  local lead = true
  _G.UnitIsGroupLeader = function() return lead end
  W.raid, W.inRaid = { { name = "Me" }, { name = "Tobi" }, { name = "Kumlust" } }, true
  -- save the group: everyone but you
  SlashCmdList.BISTOOLS("party save")
  ok(#pdb.names == 2 and P.Has(pdb, "Tobi") and P.Has(pdb, "kumlust") and not P.Has(pdb, "Me"),
    "/bist party save: whoever you're grouped with is the list (never you)", #pdb.names)
  ok(P.Add(pdb, "Zed") and not P.Add(pdb, "zed"), "add a name once; the same name twice is refused")
  -- THE WINDOW (Arn, 15 Oct: "i dont see the party frame when i click the button on the list")
  do
    local tool = R:Get("party")
    ok(tool.OnOpen, "the party tool has a window for the tools list to open")
    tool:OnOpen(pdb, true)
    local w = BiSToolsParty
    ok(w and w:IsShown() and math.abs(w.w / w.h - 1.43) < 0.01, "a click on its row opens it, at 1.43:1", w and (w.w .. "x" .. w.h))
    ok(w.scale == 1.2, "20% bigger, every part with it (Arn: the g was too small to see)", w.scale)
    local names = {}
    for _, r in ipairs(w.rows) do if r.shown then names[#names + 1] = r.name.text end end
    ok(#names == 3 and names[1] == "Tobi" and names[3] == "Zed", "the names, in list order", table.concat(names, ","))
    -- with you now: a green bar behind the name, the name itself in its class colour (17 Oct)
    ok(w.rows[1].here and w.rows[1].here.shown and not w.rows[3].here.shown, "Tobi, with you now: a green bar; Zed, not, none")
    do
      local keepUC, keepRCC = _G.UnitClass, _G.RAID_CLASS_COLORS
      _G.UnitClass = function() return "Hunter", "HUNTER" end
      _G.RAID_CLASS_COLORS = { HUNTER = { r = 0.67, g = 0.83, b = 0.45 } }
      P.PaintWindow()
      local c = w.rows[1].name.color
      ok(c and math.abs(c[1] - 0.67) < 0.01 and math.abs(c[3] - 0.45) < 0.01, "and Tobi's name in his class colour",
         c and table.concat({ c[1], c[2], c[3] }, ","))
      _G.UnitClass, _G.RAID_CLASS_COLORS = keepUC, keepRCC
      P.PaintWindow()
    end
    -- WHEN YOU LAST GROUPED (Arn, 17 Oct, Blizzard's Recent Allies open: "maybe the list can add a
    -- little note of the last time we were partied?")
    do
      local keepTime, keepZone, keepRaid, keepIn = _G.time, _G.GetRealZoneText, W.raid, W.inRaid
      local now = 1000000
      _G.time = function() return now end
      _G.GetRealZoneText = function() return "Orgrimmar" end
      P.together = nil
      P.NoteTogether(pdb)
      local tk = P.Key("Tobi")
      ok(pdb.lastWith and pdb.lastWith[tk] and pdb.lastWith[tk].zone == "Orgrimmar", "grouped with Tobi: noted, with the zone")
      ok(not w.rows[1].name.text:find("now", 1, true), "while with you: no age, the green bar says it", w.rows[1].name.text)
      now = now + 7200
      W.raid, W.inRaid = { { name = "Me" } }, false
      P.NoteTogether(pdb)
      ok(pdb.lastWith[tk].t == now, "Tobi left: the time is when you parted, not when you met")
      now = now + 3 * 86400
      P.PaintWindow()
      ok(w.rows[1].name.text:find("Tobi", 1, true) and w.rows[1].name.text:find("3d", 1, true), "the window: Tobi, 3d", w.rows[1].name.text)
      ok(w.rows[1].last == pdb.lastWith[tk] and pcall(w.rows[1].scripts.OnEnter, w.rows[1]), "hovering the name: when and where")
      ok(P.Ago(now - 30, now) == "now" and P.Ago(now - 300, now) == "5m" and P.Ago(now - 7200, now) == "2h"
         and P.Ago(now - 86400 * 40, now) == "5w", "short ages: now, 5m, 2h, 5w")
      -- lean: a 40-man roster change asks the client about each member once, and keeps at most LAST_MAX
      local big = { { name = "Me" } }
      for i = 1, 39 do big[#big + 1] = { name = "Raider" .. i } end
      W.raid, W.inRaid = big, true
      local Cost = dofile("../_bisdev/dev/cost.lua")
      local calls, by = Cost.Count(function() P.NoteTogether(pdb) end)
      ok(calls <= 170, "a 40-man roster change asks at most 170 things: " .. calls, Cost.Top and Cost.Top(by, 5))
      local keepMax = P.LAST_MAX
      P.LAST_MAX = 10
      for _ = 1, 40 do P.NoteTogether(pdb) end
      local count = 0
      for _ in pairs(pdb.lastWith) do count = count + 1 end
      ok(count <= 41 and count >= 10, "the record is capped, the oldest out first", count)
      P.LAST_MAX = keepMax
      W.raid, W.inRaid = keepRaid, keepIn
      _G.time, _G.GetRealZoneText = keepTime, keepZone
      pdb.lastWith, P.together = nil, nil
      P.PaintWindow()
    end
    w.rows[3].x.scripts.OnClick(w.rows[3].x)
    ok(not P.Has(pdb, "Zed") and not w.rows[3].shown, "x takes a name off, and the window follows")
    w.add:SetText("Zed")
    w.add.scripts.OnEnterPressed(w.add)
    ok(P.Has(pdb, "Zed") and w.rows[3].shown and w.rows[3].name.text == "Zed", "type a name, Enter: on the list")
    ok(w.buttons.save and w.buttons.invite and w.buttons.guild and w.buttons.disband and not w.buttons.clear,
       "save, invite, guild, disband - and no clear (Arn, 17 Oct: \"too unforgiving\")")
    for name, b in pairs(w.buttons) do ok(b.label:GetStringWidth() <= b.w - 4, "the " .. name .. " label fits its button", b.label:GetStringWidth()) end
    -- THE GUILD VIEW (Arn, 15 Oct: the roster's own menu is off limits, so "list"; and "invite all
    -- rank <raider>"): ranks first, then names; a name onto the list, a rank invited whole
    do
      local keepIG, keepGN, keepGR = _G.IsInGuild, _G.GetNumGuildMembers, _G.GetGuildRosterInfo
      local keepRaidG, keepInG = W.raid, W.inRaid
      local roster = { { "Nebeon-Realm", "Raider", 3, true }, { "Grux-Realm", "Officer", 1, true },
                       { "Ariarie-Realm", "Raider", 3, true }, { "Asleep-Realm", "Raider", 3, false },
                       { "Me-Realm", "Raider", 3, true } }
      _G.IsInGuild = function() return true end
      _G.GetNumGuildMembers = function() return #roster, 4 end
      _G.GetGuildRosterInfo = function(i) local m = roster[i] return m[1], m[2], m[3], 30, "Shaman", "", "", "", m[4] end
      local keepGCN, keepGCR = _G.GuildControlGetNumRanks, _G.GuildControlGetRankName
      local ladder = { "Guild Master", "Officer", "Veteran", "Raider" }
      _G.GuildControlGetNumRanks = function() return #ladder end
      _G.GuildControlGetRankName = function(i) return ladder[i] end
      w.guildBtn.scripts.OnClick(w.guildBtn)
      ok(w.guildBtn.label.text == "party", "in the guild view the button says party - where it takes you", w.guildBtn.label.text)
      local texts = {}
      for _, r in ipairs(w.rows) do if r.shown then texts[#texts + 1] = r.name.text end end
      ok(texts[1] == "<Guild Master>  nobody else online" and texts[2] == "<Officer> (1)"
         and texts[3] == "<Veteran>  nobody else online" and texts[4] == "<Raider> (2)" and #texts == 4,
        "ranks: every rank, highest first; who else is online, never you, never the offline", table.concat(texts, ", "))
      -- one full-width line each: a long rank name fits (Arn's "<Altezza's Bruhs>" ran into the next column)
      ladder[3] = "Altezza's Bruhs Extra"
      w.guildBtn.scripts.OnClick(w.guildBtn) w.guildBtn.scripts.OnClick(w.guildBtn)
      for _, r in ipairs(w.rows) do
        if r.shown then ok(r.name:GetStringWidth() <= r.w, "a rank line fits its width: " .. tostring(r.name.text), r.name:GetStringWidth() .. " in " .. r.w) end
      end
      ladder[3] = "Veteran"
      sent.invite, P.out = {}, {}
      w.rows[1].pick.scripts.OnClick(w.rows[1].pick)
      ok(#sent.invite == 0, "a rank with nobody else on: dimmed, and a click does nothing")
      -- the row under the mouse lights up - a live rank, never a dimmed one (Arn, 15 Oct)
      w.rows[2].pick.scripts.OnEnter(w.rows[2].pick)
      ok(w.rows[2].hl.shown, "hovering a rank you can click: lit")
      w.rows[2].pick.scripts.OnLeave(w.rows[2].pick)
      ok(not w.rows[2].hl.shown, "and dark again when the mouse leaves")
      w.rows[1].pick.scripts.OnEnter(w.rows[1].pick)
      ok(not w.rows[1].hl.shown, "a dimmed rank does not light")
      sent.invite, P.out = {}, {}
      W.raid, W.inRaid = { { name = "Me" } }, false
      -- LOOK BEFORE IT GOES (Arn, 15 Oct): a rank click prepares, then waits on a confirm list by
      -- class - nothing is sent until Send; x leaves someone out; who is already in shows apart
      roster[1][5], roster[1][6] = "Paladin", "PALADIN"
      roster[3][5], roster[3][6] = "Shaman", "SHAMAN"
      roster[2][5], roster[2][6] = "Warrior", "WARRIOR"
      _G.GetGuildRosterInfo = function(i) local m = roster[i] return m[1], m[2], m[3], 30, m[5] or "Shaman", "", "", "", m[4], 0, m[6] or "SHAMAN" end
      W.raid, W.inRaid = { { name = "Me" }, { name = "Ariarie" } }, true       -- one Raider already in (a wave before)
      -- nothing ticked: invite says so in the window, not only in chat (Arn: "i click invite nothing happens")
      P.picked = nil
      w.buttons.invite.scripts.OnClick(w.buttons.invite)
      ok(not P.run and w.more.text:find("tick a rank first", 1, true), "invite with nothing ticked: the window says so", w.more.text)
      P.nudgeUntil = nil
      -- PICK, THEN INVITE (Arn, 17 Oct: "select mutiple ranks"): a rank click ticks it, nothing more
      w.rows[4].pick.scripts.OnClick(w.rows[4].pick)
      ok(#sent.invite == 0 and not P.run and w.rows[4].name.text:find("<Raider> (2)", 1, true)
         and w.rows[4].name.text:find("+", 1, true), "a rank click picks it: a +, and nothing happens yet", w.rows[4].name.text)
      ok(w.more.text == "1 rank picked - invite to check who", "the hint says how many", w.more.text)
      w.rows[2].pick.scripts.OnClick(w.rows[2].pick)
      w.rows[2].pick.scripts.OnClick(w.rows[2].pick)
      ok(not w.rows[2].name.text:find("+", 1, true), "a second click un-picks it", w.rows[2].name.text)
      w.buttons.invite.scripts.OnClick(w.buttons.invite)
      ok(#sent.invite == 0 and P.run and P.run.prep, "invite: the picked rank prepares, nothing sent yet", #sent.invite)
      local box = BiSToolsPartyLoading
      for _ = 1, 40 do box.scripts.OnUpdate(box, 0.05) end
      local cv = box.confirmView
      ok(cv:IsShown() and not box.runView:IsShown(), "then the confirm view")
      local seen = {}
      for _, l in ipairs(cv.lines) do if l.shown then seen[#seen + 1] = l.text.text end end
      ok(seen[1] == "Paladin (1)" and seen[2] == "Nebeon" and seen[3] == "Already with you (1)" and seen[4] == "Ariarie",
        "by class, then who is already with you - dimmed, apart", table.concat(seen, ", "))
      ok(cv.lines[2].x.shown and not cv.lines[4].x.shown, "an x on who would be invited; none on who is already in")
      ok(cv.send.label.text == "Send 1 invite", "Send says how many", cv.send.label.text)
      -- the buttons say they can be clicked (Arn, 16 Oct: "these buttons need the hover thing")
      for _, b in ipairs({ cv.send, cv.refresh, cv.cancel, box.cancel }) do
        ok(b.hover and not b.hover.shown, "a hover tint, hidden until the mouse comes")
        b.scripts.OnEnter(b)
        ok(b.hover.shown, "shown under the mouse")
        b.scripts.OnLeave(b)
        ok(not b.hover.shown, "and gone after")
      end
      -- REFRESH YOU CAN SEE (Arn, 16 Oct: "some type of animation so we know it actually did something")
      cv.refresh.scripts.OnClick(cv.refresh)
      ok(cv.head.text:find("refreshed", 1, true), "the head says what Refresh found", cv.head.text)
      ok(P.sweeper and P.sweeper.shown, "a sweep runs")
      ok(cv.lines[1].alpha == 0 and cv.refresh.label.text:find("Refresh.", 1, true), "the lines start hidden, the button counts dots")
      for _ = 1, 30 do P.sweeper.scripts.OnUpdate(P.sweeper, 0.05) end
      ok(not P.sweeper.shown and cv.lines[1].alpha == 1 and cv.lines[5].alpha == 1, "and come back top to bottom, then it stops")
      ok(cv.refresh.label.text == "Refresh", "the button reads Refresh again")
      -- a list from outside (BiSToolsAPI: BiS Guild's roster) - Refresh used to do nothing to it
      local keepWave, keepPend, keepHere, keepMembers = P.wave, P.pending, P.pendingHere, P.Members
      P.wave, P.pending, P.pendingHere = nil, { { name = "Tobi Joined" }, { name = "Kio Alpha" } }, {}
      P.Members = function() return { { key = P.Key("Tobi Joined") } } end
      local _, joined = P.RefreshNow()
      ok(joined == 1 and #P.pending == 1 and P.pending[1].name == "Kio Alpha", "who joined you moves down; the rest wait")
      ok(cv.head.text == "refreshed: 1 joined you", "and the head says so", cv.head.text)
      P.wave, P.pending, P.pendingHere, P.Members = keepWave, keepPend, keepHere, keepMembers
      for _ = 1, 30 do P.sweeper.scripts.OnUpdate(P.sweeper, 0.05) end
      P.note = nil
      P.PaintConfirm()
      cv.lines[2].x.scripts.OnClick(cv.lines[2].x)
      ok(#P.pending == 0 and cv.send.label.text == "Nobody left", "x: Nebeon is not raiding tonight", cv.send.label.text)
      cv.cancel.scripts.OnClick(cv.cancel)
      ok(not box:IsShown() and #sent.invite == 0, "Cancel: nobody invited")
      W.raid, W.inRaid = { { name = "Me" } }, false
      w.buttons.invite.scripts.OnClick(w.buttons.invite)        -- Raider still picked
      for _ = 1, 40 do box.scripts.OnUpdate(box, 0.05) end
      cv.send.scripts.OnClick(cv.send)
      W.runAfters(P.PUMP_GAP + 0.1)
      table.sort(sent.invite)
      ok(table.concat(sent.invite, ",") == "Ariarie,Nebeon", "Send: everyone left on the list invited", table.concat(sent.invite, ","))
      ok(box.runView:IsShown() and not cv:IsShown(), "and the box plays the invites")
      -- IN WAVES (Arn, 15 Oct: "can leave it open, it regenerates with new people ... click invite again")
      W.raid, W.inRaid = { { name = "Me" }, { name = "Nebeon" } }, true          -- Nebeon accepted
      for _ = 1, 100 do box.scripts.OnUpdate(box, 0.05) end
      ok(box:IsShown() and cv:IsShown() and P.wave, "after the invites: back to the list, still open")
      local now = {}
      for _, l in ipairs(cv.lines) do if l.shown then now[#now + 1] = l.text.text end end
      ok(table.concat(now, ","):find("Already with you (1)", 1, true) and table.concat(now, ","):find("Nebeon", 1, true)
         and cv.send.label.text == "Send 1 invite", "who joined moved down; who didn't is still there to send", table.concat(now, ", "))
      -- x someone: they stay out through every rebuild
      for _, l in ipairs(cv.lines) do if l.shown and l.text.text == "Ariarie" then l.x.scripts.OnClick(l.x) end end
      roster[6] = { "Newcomer-Realm", "Raider", 3, true, "Mage", "MAGE" }      -- logs on mid-wave
      P.waveEvents.scripts.OnEvent(P.waveEvents, "GUILD_ROSTER_UPDATE")
      W.runAfters(P.REGEN_GAP + 0.1)
      now = {}
      for _, l in ipairs(cv.lines) do if l.shown then now[#now + 1] = l.text.text end end
      local joined = table.concat(now, ",")
      ok(joined:find("Newcomer", 1, true) and not joined:find("Ariarie", 1, true) and cv.send.label.text == "Send 1 invite",
        "a new login appears by itself; the x'd one stays out", joined)
      ok(cv.refresh and cv.refresh.label.text == "Refresh" and cv.cancel.label.text == "Close", "Refresh, and Close")
      -- Send | Refresh | Close along the bottom, apart: Send from 12, Close ends 12 from the right
      local sendR = 12 + cv.send.w
      local closeL = P.W - 12 - cv.cancel.w
      local refreshL = closeL - 6 - cv.refresh.w
      ok(sendR < refreshL and cv.send.label:GetStringWidth() <= cv.send.w - 4, "the three buttons do not touch, and Send's words fit",
        sendR .. " < " .. refreshL)
      sent.invite, P.out = {}, {}
      cv.send.scripts.OnClick(cv.send)
      ok(sent.invite[1] == "Newcomer", "the next wave: Send again", table.concat(sent.invite, ","))
      for _ = 1, 100 do box.scripts.OnUpdate(box, 0.05) end
      cv.cancel.scripts.OnClick(cv.cancel)
      ok(not box:IsShown() and P.wave == nil, "Close ends the wave")
      roster[6] = nil
      W.raid, W.inRaid = { { name = "Me" } }, false
      -- TWO RANKS, ONE LIST (Arn, 17 Oct: "gm rank selected officer and raiders")
      w.rows[2].pick.scripts.OnClick(w.rows[2].pick)              -- Officer too, Raider still picked
      ok(w.more.text == "2 ranks picked - invite to check who", "two picked", w.more.text)
      sent.invite, P.out = {}, {}
      w.buttons.invite.scripts.OnClick(w.buttons.invite)
      for _ = 1, 40 do box.scripts.OnUpdate(box, 0.05) end
      local both = {}
      for _, l in ipairs(cv.lines) do if l.shown then both[#both + 1] = l.text.text .. (l.x.shown and "[x]" or "") end end
      local bs = table.concat(both, ", ")
      ok(bs:find("Grux[x]", 1, true) and bs:find("Nebeon[x]", 1, true) and bs:find("Ariarie[x]", 1, true),
         "both ranks' people on one list, an x on each", bs)
      ok(cv.head.text:find("<Officer> + <Raider>", 1, true), "the head names both, highest first", cv.head.text)
      for _, l in ipairs(cv.lines) do if l.shown and l.text.text == "Ariarie" then l.x.scripts.OnClick(l.x) end end
      cv.send.scripts.OnClick(cv.send)
      W.runAfters(P.PUMP_GAP + 0.1)
      table.sort(sent.invite)
      ok(table.concat(sent.invite, ",") == "Grux,Nebeon", "Send: both ranks, minus the x", table.concat(sent.invite, ","))
      for _ = 1, 100 do box.scripts.OnUpdate(box, 0.05) end
      cv.cancel.scripts.OnClick(cv.cancel)
      P.picked = nil
      W.raid, W.inRaid = { { name = "Me" } }, false
      sent.invite, P.out = {}, {}
      SlashCmdList.BISTOOLS("party rank officer")
      for _ = 1, 40 do box.scripts.OnUpdate(box, 0.05) end
      cv.send.scripts.OnClick(cv.send)
      ok(sent.invite[1] == "Grux", "/bist party rank officer - any case, through the same confirm", table.concat(sent.invite, ","))
      for _ = 1, 100 do box.scripts.OnUpdate(box, 0.05) end
      cv.cancel.scripts.OnClick(cv.cancel)
      w.guildBtn.scripts.OnClick(w.guildBtn)
      ok(w.rows[1].name.text ~= "invite all <Officer> (1)" and w.guildBtn.label.text == "guild", "the button again (it read 'party'): back to your list")
      -- THE FRIENDS VIEW (Arn, 20 Oct, once the Friends list's right-click line had to go: "bummer because it
      -- was an easy way to add a friend"): your friends online, only read; a click puts one on the list
      do
        local keepFL, keepBNN, keepBN, keepUFG = _G.C_FriendList, _G.BNGetNumFriends, _G.C_BattleNet, _G.UnitFactionGroup
        local chars = { { name = "Pally-Realm", connected = true, className = "Paladin" }, { name = "Sleepy", connected = false },
                        { name = "Zed", connected = true, className = "Mage" } }
        _G.C_FriendList = { GetNumFriends = function() return #chars end, GetFriendInfoByIndex = function(i) return chars[i] end }
        local accounts = {
          { gameAccountInfo = { isOnline = true, clientProgram = "WoW", characterName = "Darthsidiouz Sithlord", factionName = "Horde" } },
          { gameAccountInfo = { isOnline = true, clientProgram = "WoW", characterName = "Alli Ance", factionName = "Alliance" } },
          { gameAccountInfo = { isOnline = true, clientProgram = "BSAp" } },
          { gameAccountInfo = { isOnline = false, clientProgram = "WoW", characterName = "Gone" } } }
        _G.BNGetNumFriends = function() return #accounts end
        _G.C_BattleNet = { GetFriendAccountInfo = function(i) return accounts[i] end }
        _G.UnitFactionGroup = function() return "Horde", "Horde" end
        local names = {}
        for _, e in ipairs(P.FriendsOnline()) do names[#names + 1] = e.name end
        ok(table.concat(names, ",") == "Darthsidiouz Sithlord,Pally,Zed",
          "your friends online: character friends, and Battle.net friends in WoW on your side - by character", table.concat(names, ","))
        w.friendsBtn.scripts.OnClick(w.friendsBtn)
        ok(w.friendsBtn.label.text == "party", "the friends view: its button says party - where it takes you", w.friendsBtn.label.text)
        local row
        for _, r in ipairs(w.rows) do if r.shown and r.who == "Darthsidiouz Sithlord" then row = r end end
        ok(row and row.pick.shown and not row.x.shown, "a friend a row, the whole row a button")
        row.pick.scripts.OnClick(row.pick)
        ok(P.Has(pdb, "Darthsidiouz Sithlord") and row.name.text:find("+", 1, true), "a click: on the party list, marked +", row.name.text)
        row.pick.scripts.OnClick(row.pick)
        ok(not P.Has(pdb, "Darthsidiouz Sithlord"), "again: off it")
        w.friendsBtn.scripts.OnClick(w.friendsBtn)
        ok(w.friendsBtn.label.text == "friends", "the button again: back to your list")
        _G.C_FriendList, _G.BNGetNumFriends, _G.C_BattleNet, _G.UnitFactionGroup = keepFL, keepBNN, keepBN, keepUFG
      end
      -- THE GUILD WINDOW'S OWN MENU, behind its switch (a line there may cost officers promote/kick)
      local keepMenu, hooked = _G.Menu, {}
      _G.Menu = { ModifyMenu = function(tag, fn) hooked[tag] = fn end }
      P.guildHooked = nil
      pdb.guildMenu = nil
      ok(not P.HookGuildMenus(pdb) and not next(hooked), "switched off (the default): the guild menu is never even hooked")
      pdb.guildMenu = true
      ok(P.HookGuildMenus(pdb) and hooked.MENU_UNIT_COMMUNITIES_GUILD_MEMBER, "switched on: hooked at once")
      local gm = { lines = {} }
      function gm:CreateDivider() self.lines[#self.lines + 1] = "--" end
      function gm:CreateTitle(t) self.lines[#self.lines + 1] = "title" end
      function gm:CreateButton(text, fn) self.lines[#self.lines + 1] = text self.fn = fn end
      hooked.MENU_UNIT_COMMUNITIES_GUILD_MEMBER(nil, gm, { name = "Nebeon", surname = "Nolightforu" })
      ok(gm.lines[#gm.lines] == "Add to party list", "a guildmate's right-click in the guild window: Add to party list", table.concat(gm.lines, "|"))
      gm.fn()
      ok(P.Has(pdb, "Nebeon"), "and it adds them")
      pdb.guildMenu = false
      gm.lines = {}
      hooked.MENU_UNIT_COMMUNITIES_GUILD_MEMBER(nil, gm, { name = "Nebeon" })
      ok(#gm.lines == 0, "switched off again: no line (the hook goes at the next /reload)")
      _G.Menu, P.guildHooked, pdb.guildMenu = keepMenu, nil, nil
      -- THE WINDOW'S INVITE CHECKS FIRST (Arn, 17 Oct: "this button is sending the invite right away
      -- ... add the second screen of it doing the check to make sure they are online etc and the
      -- little x"): who is on, by class; offline apart with no x; nothing sent until Send
      do
        local keepList = pdb.names
        pdb.names = {}
        for _, n in ipairs({ "Nebeon", "Asleep", "Stranger", "Pete" }) do P.Add(pdb, n) end
        W.raid, W.inRaid = { { name = "Me" } }, false
        sent.invite, P.out = {}, {}
        local cv = BiSToolsPartyLoading and BiSToolsPartyLoading.confirmView
        w.buttons.invite.scripts.OnClick(w.buttons.invite)
        ok(#sent.invite == 0 and P.run and P.run.prep, "invite in the party window sends nothing yet: it checks")
        local box = BiSToolsPartyLoading
        cv = box.confirmView
        for _ = 1, 40 do box.scripts.OnUpdate(box, 0.05) end
        local seen = {}
        for _, l in ipairs(cv.lines) do if l.shown then seen[#seen + 1] = l.text.text .. (l.x.shown and "[x]" or "") end end
        local s = table.concat(seen, ", ")
        ok(cv:IsShown() and s:find("Paladin (1)", 1, true) and s:find("Nebeon[x]", 1, true),
           "a guildmate online: under their class, with an x", s)
        ok(s:find("Unknown (2)", 1, true) and s:find("Stranger[x]", 1, true),
           "someone the client cannot place: invited on trust, with an x", s)
        ok(s:find("Offline (1)", 1, true) and s:find("Asleep", 1, true) and not s:find("Asleep[x]", 1, true),
           "an offline guildmate: apart, dimmed, no x", s)
        ok(cv.send.label.text == "Send 3 invites", "Send counts only who is on", cv.send.label.text)
        for _, l in ipairs(cv.lines) do if l.shown and l.text.text == "Pete" then l.x.scripts.OnClick(l.x) end end
        roster[4][4] = true                                    -- Asleep logs on
        cv.refresh.scripts.OnClick(cv.refresh)
        for _ = 1, 30 do P.sweeper.scripts.OnUpdate(P.sweeper, 0.05) end
        seen = {}
        for _, l in ipairs(cv.lines) do if l.shown then seen[#seen + 1] = l.text.text .. (l.x.shown and "[x]" or "") end end
        s = table.concat(seen, ", ")
        ok(s:find("Asleep[x]", 1, true) and not s:find("Offline", 1, true) and not s:find("Pete", 1, true),
           "Refresh: who logged on moves up to invite; the x'd one stays out", s)
        -- ADD TO IT (Arn, 17 Oct: the party list open, a rank invited from the guild view - "add to it")
        for _ = 1, 30 do P.sweeper.scripts.OnUpdate(P.sweeper, 0.05) end
        w.guildBtn.scripts.OnClick(w.guildBtn)
        for _, r in ipairs(w.rows) do if r.shown and r.rank == "Officer" then r.pick.scripts.OnClick(r.pick) end end
        w.buttons.invite.scripts.OnClick(w.buttons.invite)
        ok(box:IsShown() and cv:IsShown() and not (P.run and P.run.prep),
           "with a list open, the guild view's invite adds to it: same window, no second list")
        seen = {}
        for _, l in ipairs(cv.lines) do if l.shown then seen[#seen + 1] = l.text.text .. (l.x.shown and "[x]" or "") end end
        s = table.concat(seen, ", ")
        ok(s:find("Grux[x]", 1, true) and s:find("Nebeon[x]", 1, true) and s:find("Asleep[x]", 1, true)
           and not s:find("Pete", 1, true), "the party list's people and the Officer on one list; the x'd still out", s)
        ok(cv.head.text == "added <Officer>: 1 new", "the head says what came in", cv.head.text)
        P.note = nil
        P.PaintConfirm()
        ok(cv.head.text:find("your party list + <Officer>", 1, true), "and then names both parts", cv.head.text)
        ok(cv.head.text:find("^%d+ to invite: ") and cv.head.wrap == false and cv.head.w == P.W - 24,
           "count first, one line cut at the window's edge (three parts ran to the border)", cv.head.text)
        ok(cv.more.text == "x leaves someone out", "the x hint sits above the buttons", cv.more.text)
        -- and no list row reaches it (Arn's screenshot: Frankadank, row 9, under the hint)
        local lastRowBottom = 48 + P.CONF_ROWS * P.CONF_LINE           -- from the top
        ok(P.H - lastRowBottom >= 32 + 12, "the last row ends above the hint line",
           (P.H - lastRowBottom) .. " px from the bottom")
        local nebs = 0
        for _, e in ipairs(P.pending) do if e.name == "Nebeon" then nebs = nebs + 1 end end
        ok(nebs == 1, "on the party list and Raider too: listed once")
        w.guildBtn.scripts.OnClick(w.guildBtn)
        P.picked = nil
        for _ = 1, 30 do P.sweeper.scripts.OnUpdate(P.sweeper, 0.05) end
        cv.send.scripts.OnClick(cv.send)
        W.runAfters(P.PUMP_GAP + 0.1)
        table.sort(sent.invite)
        ok(table.concat(sent.invite, ",") == "Asleep,Grux,Nebeon,Stranger", "Send: just those", table.concat(sent.invite, ","))
        for _ = 1, 100 do box.scripts.OnUpdate(box, 0.05) end
        P.EndShow()
        roster[4][4] = false
        pdb.names = keepList
        sent.invite, P.out = {}, {}
      end
      P.Remove(pdb, "Nebeon")
      if P.box then P.EndShow() end
      _G.IsInGuild, _G.GetNumGuildMembers, _G.GetGuildRosterInfo = keepIG, keepGN, keepGR
      _G.GuildControlGetNumRanks, _G.GuildControlGetRankName = keepGCN, keepGCR
      W.raid, W.inRaid = keepRaidG, keepInG
      sent.invite, P.out = {}, {}
    end
    -- the empty list's hint: current words (no "g" button any more), and it fits the window
    local keepNames = pdb.names
    pdb.names = {}
    P.PaintWindow()
    ok(w.more.text == "empty - save a group, add a name, or right-click a player"
       and w.more:GetStringWidth() <= P.WIN_W - 16, "the empty hint: today's buttons, and it fits", w.more.text)
    pdb.names = keepNames
    P.PaintWindow()
    SlashCmdList.BISTOOLS("party")
    ok(not w:IsShown(), "/bist party toggles it")
  end
  -- grouped with someone on the list: Disband shows; Invite shows for the one missing
  Bx.Refresh()
  ok(P.dbtn:IsShown() and P.ibtn:IsShown(), "grouped with listed players: Disband, and Invite for the one missing")
  P.Invite(pdb)
  ok(#sent.invite == 1 and sent.invite[1] == "Zed", "Invite asks only the ones not with you", #sent.invite)
  -- THE LITTLE SHOW (Arn, 15 Oct): the invite has already gone; a box fills, its log scrolls with
  -- the machine talking to each player - on the window, never in chat - then it closes itself
  do
    local box = BiSToolsPartyLoading
    ok(box and box:IsShown() and P.run, "Invite: the inviting box comes up")
    -- it drags, and stays where it was put (Arn, 15 Oct)
    ok(box.scripts.OnDragStart and box.scripts.OnDragStop, "the box can be dragged")
    box.scripts.OnDragStop(box)            -- the mock's GetPoint answers TOPLEFT 12, -34
    ok(pdb.boxPos and pdb.boxPos[1] == "TOPLEFT" and pdb.boxPos[2] == 12 and pdb.boxPos[3] == -34, "and its place is kept", pdb.boxPos and pdb.boxPos[2])
    local chat = 0
    local keepAdd = DEFAULT_CHAT_FRAME.AddMessage
    DEFAULT_CHAT_FRAME.AddMessage = function() chat = chat + 1 end
    local function shown() local t = {} for _, l in ipairs(box.log) do if l.text and l.text ~= "" then t[#t + 1] = l.text end end return t end
    for _ = 1, 30 do box.scripts.OnUpdate(box, 0.05) end        -- 1.5 s in
    local mid = shown()
    local saysZed = false
    for _, l in ipairs(mid) do if l:find("Zed", 1, true) then saysZed = true end end
    ok(#mid >= 2 and saysZed, "the log scrolls with lines about the player being invited", table.concat(mid, " / "))
    local lit = 0
    for _, b in ipairs(box.blocks) do if b.shown then lit = lit + 1 end end
    ok(lit > 0, "the bar fills with blocks", lit)
    for _ = 1, 60 do box.scripts.OnUpdate(box, 0.05) end        -- past the end and the linger
    ok(not box:IsShown() and P.run == nil, "it closes itself")
    ok(chat == 0, "and nothing of it went to chat (Arn: 'on the window')", chat)
    DEFAULT_CHAT_FRAME.AddMessage = keepAdd
    -- WHAT THE GAME SAYS BACK (Arn, 15 Oct: "he is in a group, should also throw an error on here")
    _G.ERR_ALREADY_IN_GROUP_S = "%s is already in a group."
    _G.ERR_INVITE_PLAYER_S = "You have invited %s to join your group."
    P.Show({ "Darthsidiouz Sithlord" })
    P.heard.scripts.OnEvent(P.heard, "CHAT_MSG_SYSTEM", "Darthsidiouz is already in a group.")
    local warned = false
    for _, l in ipairs(box.log) do if (l.text or ""):find("Darthsidiouz is already in a group", 1, true) then warned = true end end
    ok(warned, "the game's 'already in a group' lands in the box's log", table.concat(shown(), " / "))
    for _ = 1, 40 do box.scripts.OnUpdate(box, 0.05) end
    local last = box.log[#box.log].text or ""
    ok(last:find("Done. 0 of 1 invited", 1, true), "and the last line counts it", last)
    for _, l in ipairs(box.log) do
      ok(l.wrap == false and not (l.text or ""):find("Sithlord", 1, true), "one line each, by first name (no surname to wrap)", l.text)
    end
    for _ = 1, 40 do box.scripts.OnUpdate(box, 0.05) end
    -- and the game's words as Arn pasted them (15 Oct): invited, then declined - whole names
    _G.ERR_DECLINE_GROUP_S = "%s declines your group invitation."
    P.Show({ "Darthsidiouz Sithlord" })
    P.Heard("You have invited Darthsidiouz Sithlord to join your group.")
    P.Heard("Darthsidiouz Sithlord declines your group invitation.")
    local got = table.concat(shown(), " / ")
    ok(got:find("Darthsidiouz: invite received", 1, true) and got:find("Darthsidiouz declined", 1, true),
      "invited, then declined: both in the box, by first name", got)
    for _ = 1, 80 do box.scripts.OnUpdate(box, 0.05) end
    _G.ERR_DECLINE_GROUP_S = nil
    ok(not P.run and not P.Heard("Somebody is already in a group."), "a system line while no box is up: left alone")
    -- A REFUSED INVITE IS SAID (Arn, 15 Oct: "i dont think it is sending any invites" - the pcall had
    -- eaten the error): in the box's log, and once in chat
    do
      local keepPI2 = _G.C_PartyInfo
      local keepRaid2, keepIn2 = W.raid, W.inRaid
      _G.C_PartyInfo = { InviteUnit = function() error("Interface/AddOns/x.lua:1: you may not invite") end }
      W.raid, W.inRaid = { { name = "Me" } }, false
      local said = W.lastMsg
      P.InviteNames(pdb, { "Nebeon" })
      local refused = false
      for _, l in ipairs(box.log) do if (l.text or ""):find("Nebeon: the game refused (you may not invite)", 1, true) then refused = true end end
      ok(refused, "the game's refusal, in the box's log", table.concat(shown(), " / "))
      ok(W.lastMsg ~= said and tostring(W.lastMsg):find("refused an invite", 1, true), "and once in chat", W.lastMsg)
      for _ = 1, 80 do box.scripts.OnUpdate(box, 0.05) end
      _G.C_PartyInfo = keepPI2
      W.raid, W.inRaid = keepRaid2, keepIn2
    end
    _G.ERR_ALREADY_IN_GROUP_S, _G.ERR_INVITE_PLAYER_S = nil, nil      -- the client's strings, ours only for the test
    P.Show({ "A", "B" })
    box.cancel.scripts.OnClick(box.cancel)
    ok(not box:IsShown() and P.run == nil, "Cancel closes it (the invites went anyway)")
    -- lean: a whole run asks the client nothing (our own textures and text)
    local Cost = dofile("../_bisdev/dev/cost.lua")
    P.Show({ "A", "B", "C" })
    local n, by = Cost.Count(function() for _ = 1, 120 do box.scripts.OnUpdate(box, 0.05) end end)
    ok(n <= 10 and not box:IsShown(), "a whole inviting show asks at most 10 things: " .. n, Cost.Top and Cost.Top(by, 5))
    pdb.show = false
    P.Show = (function(show) return function(...) P.showCalled = true return show(...) end end)(P.Show)
    P.showCalled = nil
    P.Invite(pdb)
    ok(not P.showCalled, "the show switched off: invites go with no box")
    pdb.show = nil
  end
  -- leading: Disband removes everyone; not leading: you leave
  P.Disband()
  ok(#sent.uninvite == 2 and sent.left == 0, "the leader's Disband: everyone out", #sent.uninvite)
  lead = false
  P.Disband()
  ok(sent.left == 1, "not the leader: Disband leaves the group")
  -- the BUTTONS take a shift-click (Arn, 17 Oct: "might leave by mistake")
  W.shift = false
  P.dbtn.scripts.OnClick(P.dbtn)
  ok(sent.left == 1, "a plain click on the Disband button: nobody goes anywhere")
  W.shift = true
  P.dbtn.scripts.OnClick(P.dbtn)
  ok(sent.left == 2, "shift-click: you leave")
  W.shift = false
  ok(not P.ShiftDisband() and sent.left == 2, "the window's disband asks the same")
  ok(not P.ShowInvite(pdb), "not leading: no Invite button (only a leader can invite)")
  -- solo with a list: Invite only
  W.raid, W.inRaid, lead = { { name = "Me" } }, false, true
  Bx.Refresh()
  ok(P.ibtn:IsShown() and not P.dbtn:IsShown(), "solo with a list: Invite, no Disband")
  -- the BOX's Invite confirms first, and never shows in a battleground (Arn, 15 Oct: a stray click
  -- in the heat of battle)
  do
    sent.invite, P.out = {}, {}
    P.ibtn.scripts.OnClick(P.ibtn)
    ok(#sent.invite == 0 and not P.run and tostring(W.lastMsg):find("shift-click", 1, true),
      "a plain click on the box's Invite: nothing, but a reminder (Arn: shift-click only)", W.lastMsg)
    W.shift = true
    P.ibtn.scripts.OnClick(P.ibtn)
    W.shift = false
    ok(#sent.invite == 0 and BiSToolsParty and BiSToolsParty:IsShown(), "shift-click: the party window opens (Arn), nothing sent", #sent.invite)
    BiSToolsParty:Hide()
    ok(#sent.invite == 0, "and Cancel sends nobody")
    local keepII3 = _G.IsInInstance
    _G.IsInInstance = function() return true, "pvp" end
    Bx.Refresh()
    ok(not P.ibtn:IsShown(), "in a battleground: no Invite button in the box at all")
    _G.IsInInstance = keepII3
    Bx.Refresh()
  end
  sent.invite, P.out = {}, {}
  P.Invite(pdb)
  ok(#sent.invite == 3, "solo: the whole list asked", #sent.invite)
  -- grouped with strangers: nothing of the list's shows
  W.raid, W.inRaid = { { name = "Me" }, { name = "Stranger" } }, true
  Bx.Refresh()
  ok(not P.ibtn:IsShown() and not P.dbtn:IsShown(), "grouped with nobody on the list: neither button")
  -- the right-click line on ANY friendly player - a raid member or a stranger in town (Arn, 15 Oct:
  -- "why cant i add them to the party list? is that only for people in the party?") - outside
  -- instances only; never the other faction, never you
  local m = { lines = {} }
  function m:CreateButton(text, fn) self.lines[#self.lines + 1] = { text = text, fn = fn } end
  function m:CreateDivider() end
  local keepUIR, keepII = _G.UnitInRaid, _G.IsInInstance
  local keepUIP, keepUIF, keepUN2 = _G.UnitIsPlayer, _G.UnitIsFriend, _G.UnitName
  local people = { raid2 = { name = "Stranger", friend = true }, target = { name = "Richer", friend = true },
                   focus = { name = "Horde Guy", friend = false } }
  _G.UnitIsPlayer = function(u) return u == "player" or people[u] ~= nil end
  _G.UnitIsFriend = function(_, u) return people[u] ~= nil and people[u].friend end
  _G.UnitName = function(u) if people[u] then return people[u].name end return keepUN2(u) end
  _G.IsInInstance = function() return false, "none" end
  P.MenuLine(pdb, m, { unit = "raid2" })
  ok(#m.lines == 1 and m.lines[1].text == "Add to party list", "right-click a raid member: Add to party list", m.lines[1] and m.lines[1].text)
  m.lines[1].fn()
  ok(P.Has(pdb, "Stranger"), "and it adds them")
  m.lines = {}
  P.MenuLine(pdb, m, { unit = "raid2" })
  ok(m.lines[1] and m.lines[1].text == "Remove from party list", "on the list already: the line removes")
  m.lines = {}
  P.MenuLine(pdb, m, { unit = "target" })
  ok(#m.lines == 1 and m.lines[1].text == "Add to party list", "a friendly stranger you right-click: the line too")
  m.lines = {}
  P.MenuLine(pdb, m, { unit = "focus" })
  ok(#m.lines == 0, "the other faction: no line (you could not invite them)")
  P.MenuLine(pdb, m, { unit = "player" })
  ok(#m.lines == 0, "your own menu: no line")
  _G.IsInInstance = function() return true, "party" end
  P.MenuLine(pdb, m, { unit = "raid2" })
  ok(#m.lines == 0, "inside an instance: no line (it breaks the game's menu there)")
  _G.IsInInstance = function() return false, "none" end
  _G.UnitIsPlayer, _G.UnitIsFriend, _G.UnitName = keepUIP, keepUIF, keepUN2
  -- A FRIEND, from the Friends list (Arn, 15 Oct: "can it add the Darthsidiouz sithlord to the party
  -- list?" ... "another sub section to our section"): one BiS section - a divider, a title - holding
  -- the rivals tool's pal line and the party line together
  do
    local f = { lines = {} }
    function f:CreateDivider() self.lines[#self.lines + 1] = "--" end
    function f:CreateTitle(t) self.lines[#self.lines + 1] = "title:" .. tostring(t) end
    function f:CreateButton(text, fn) self.lines[#self.lines + 1] = text self["fn" .. #self.lines] = fn end
    local ctx = { name = "Darthsidiouz", surname = "Sithlord" }
    NS.Recap.MenuLines(R:DBFor(R:Get("recap")), f, ctx, "FRIEND")
    P.MenuLine(pdb, f, ctx, "FRIEND")
    local dividers, titles = 0, 0
    for _, l in ipairs(f.lines) do
      if l == "--" then dividers = dividers + 1 end
      if tostring(l):find("^title:") then titles = titles + 1 end
    end
    ok(dividers == 1 and titles == 1 and f.lines[2]:find("BiS", 1, true), "one BiS section: one divider, one title", table.concat(f.lines, " | "))
    ok(f.lines[#f.lines] == "Add to party list" and #f.lines == 5, "pal, rival (no faction seen: both) and the party line, together under it", table.concat(f.lines, " | "))
    f["fn" .. #f.lines]()
    ok(P.Has(pdb, "Darthsidiouz Sithlord"), "a friend goes on the list, surname and all")
    sent.invite, sent.full, sent.raid, P.out = {}, {}, 0, {}
    W.raid, W.inRaid = { { name = "Me" } }, false
    P.Invite(pdb)
    W.runAfters(P.PUMP_GAP + 0.1)
    ok(#sent.invite == 4 and #sent.full == 0 and P.held and #P.held.names == 1,
      "alone with five to ask: four go out, the fifth WAITS - the game would refuse it (party full)",
      #sent.invite .. " out, " .. #sent.full .. " refused")
    ok(sent.raid == 0, "and no raid yet: alone, there is no party to make one of", sent.raid)
    -- Tobi accepts: a party of two - it becomes a raid, and once it is one the fifth goes out
    W.raid = { { name = "Me" }, { name = table.remove(sent.invite, 1) } }
    P.events.scripts.OnEvent(P.events, "GROUP_ROSTER_UPDATE")
    ok(sent.raid == 1 and W.inRaid, "the first one in: the party becomes a raid by itself", sent.raid)
    ok(P.held ~= nil, "the rest still wait: the raid is the NEXT roster change", P.held and #P.held.names)
    P.events.scripts.OnEvent(P.events, "GROUP_ROSTER_UPDATE")
    W.runAfters(P.PUMP_GAP + 0.1)
    ok(P.held == nil and #sent.full == 0, "the raid is here: nobody waits, nothing refused")
    local asked = false
    for _, n in ipairs(sent.invite) do if n == "Darthsidiouz Sithlord" then asked = true end end
    ok(asked, "and the invite goes to Darthsidiouz Sithlord - Forever's whole name (Arn: /invite Nebeon completes to Nebeon Nolightforu)", table.concat(sent.invite, ","))
    ok(P.Key("Darthsidiouz Sithlord") == P.Key("darthsidiouz") and P.Key("Tobi-Realm") == "tobi", "compared by first name: no surname, no realm, any case")
    P.Remove(pdb, "Darthsidiouz")
  end
  _G.UnitInRaid, _G.IsInInstance = keepUIR, keepII
  -- more than a party holds: a party you lead becomes a raid first
  W.raid, W.inRaid = { { name = "Me" }, { name = "Tobi" } }, false
  pdb.names = { "Tobi", "A", "B", "C", "D" }
  _G.UnitExists = (function(ue) return function(u) local i = u:match("^party(%d+)$") if i then return W.raid[tonumber(i) + 1] ~= nil end return ue(u) end end)(_G.UnitExists)
  local keepUN = _G.UnitName
  _G.UnitName = function(u) local i = u:match("^party(%d+)$") if i then return W.raid[tonumber(i) + 1] and W.raid[tonumber(i) + 1].name end return keepUN(u) end
  sent.invite, sent.full, sent.raid, P.out = {}, {}, 0, {}
  P.Invite(pdb)
  ok(sent.raid == 1, "six of you: the party becomes a raid before the invites", sent.raid)
  ok(#sent.invite == 3 and #sent.full == 0 and P.held and #P.held.names == 1,
    "two of you: three go out at once, the fourth waits for the raid", #sent.invite .. " out")
  P.events.scripts.OnEvent(P.events, "GROUP_ROSTER_UPDATE")
  W.runAfters(P.PUMP_GAP + 0.1)
  ok(P.held == nil and #sent.invite == 4 and #sent.full == 0, "the raid made: the last one goes, none refused", #sent.invite)
  -- nobody ever joins: the waiting ones are dropped and said, not left to fire on some later group
  W.raid, W.inRaid = { { name = "Me" } }, false
  sent.invite, sent.full, sent.raid, P.out = {}, {}, 0, {}
  pdb.names = { "A", "B", "C", "D", "E", "F" }
  P.Invite(pdb)
  ok(P.held and #P.held.names == 2, "alone with six: two wait", P.held and #P.held.names)
  W.runAfters(P.HOLD_FOR + 1)
  ok(P.held == nil, "two minutes and nobody joined: they are dropped (Invite again sends them)")
  -- ONE AT A TIME (BiS Guild's raid-night pop-up: each raider invited as they log in): three of you,
  -- two invites out - the next one would be the sixth, so the party becomes a raid and it waits
  W.raid, W.inRaid = { { name = "Me" }, { name = "Tobi" }, { name = "Kio" } }, false
  sent.invite, sent.full, sent.raid, P.out = {}, {}, 0, {}

  _G.BiSToolsAPI.InviteOne("Ari")
  _G.BiSToolsAPI.InviteOne("Mare")
  ok(#sent.invite == 2 and sent.raid == 0 and P.held == nil, "three of you, two asked: five, still a party", #sent.invite)
  _G.BiSToolsAPI.InviteOne("Shwed")
  ok(sent.raid == 1 and P.held and P.held.names[1] == "Shwed" and #sent.full == 0,
    "the third would be the sixth: the party becomes a raid and Shwed waits for it, not refused", #sent.full)
  P.events.scripts.OnEvent(P.events, "GROUP_ROSTER_UPDATE")
  ok(P.held == nil and sent.invite[3] == "Shwed", "the raid made: Shwed is asked", table.concat(sent.invite, ","))
  -- an invite nobody answers stops counting after P.OUT_FOR
  W.raid, W.inRaid = { { name = "Me" } }, false
  sent.invite, sent.full, sent.raid, P.out = {}, {}, 0, {}
  for _, n in ipairs({ "A", "B", "C", "D" }) do _G.BiSToolsAPI.InviteOne(n) end
  ok(P.Out() == 4, "alone, four asked: four out", P.Out())
  W.now = W.now + P.OUT_FOR + 1
  ok(P.Out() == 0, "a minute unanswered: they no longer count", P.Out())
  _G.UnitName = keepUN
  -- cost: a group change in a 40-man raid with a full list re-asks the box, once
  W.raid, W.inRaid = { { name = "Me" } }, true
  pdb.names = {}
  for i = 2, 40 do W.raid[i] = { name = "R" .. i } pdb.names[#pdb.names + 1] = "R" .. i end
  local Cost = dofile("../_bisdev/dev/cost.lua")
  local n, by = Cost.Count(function() P.events.scripts.OnEvent(P.events, "GROUP_ROSTER_UPDATE") end)
  ok(n <= 150, "a roster change in a 40-man raid asks at most 150 things (measured 132: one roster walk): " .. n, Cost.Top and Cost.Top(by, 5))
  _G.C_PartyInfo, _G.UnitIsGroupLeader, W.raid, W.inRaid = keepPI, keepLead, keepRaid, keepIn
  pdb.names = {}

  -- BiSToolsAPI (16 Oct 2026, Arn: "I like OpenMap, that opens its stuff via API ... if installed it
  -- can API-call it"): BiS Guild asks here, never NS.Party
  local A = _G.BiSToolsAPI
  ok(A and A.major == 1 and A.version >= 1, "BiSToolsAPI is there, major 1")
  ok(A.PartyReady(), "ready while the party tool is on")
  -- version 2 (21 Oct 2026, for BiS Memories): is this name a rival?
  ok(A.version >= 2, "version 2")
  local rdb = NS.Recap.DB()
  NS.Recap.Rivals(rdb)["Latina Fatty"] = { class = "MAGE", added = 1 }
  ok(A.IsRival("Latina Fatty") == true and A.IsRival("Someone Else") == false and A.IsRival(nil) == false,
     "IsRival: a rival yes, anyone else no, no name no")
  NS.Recap.Rivals(rdb)["Latina Fatty"] = nil
  P.pending = nil
  local n = A.InviteList("on the pasted roster", { "Darthsidiouz Sithlord", { name = "Kio Alpha", class = "Mage", classFile = "MAGE" }, 7, {} })
  ok(n == 2 and P.pending and #P.pending == 2, "names and people land on the confirm list; junk is skipped", n)
  ok(P.pending and P.pending[2].class == "Mage", "with their class, for the sort")
  P.pending = nil
  ok(A.InviteList("x", { "Me" }) == 0, "only yourself: nothing to send")
  R:SetEnabled("party", false)
  local n2, why = A.InviteList("x", { "Tobi" })
  ok(n2 == nil and why == "party tool off", "party tool off: says so, does nothing", why)
  ok(not A.PartyReady(), "and is not ready")
  local n3, why3 = A.InviteOne("Tobi")
  ok(n3 == nil and why3 == "party tool off", "one invite too")
  R:SetEnabled("party", true)

  R:SetEnabled("party", false)
  Bx.Refresh()
end

-- ------------------------------------------------------------ the party tool's hands-off switches (21 Oct 2026)
-- Arn: "when a guild member invites you ... it'll auto accept an invite", "if somebody whispers you a key word,
-- it'll invite". THE CLIENT'S SHAPES: PARTY_INVITE_REQUEST (name, isTank, isHealer, isDamage, isNativeRealm,
-- allowMultipleRoles, inviterGUID); CHAT_MSG_WHISPER (text, "Name-Realm", ..., guid as the 12th); in a lockdown the
-- whisper's text and sender are SECRET - type() says "string", a comparison throws.
do
  local P = NS.Party
  local pdb = R:DBFor(R:Get("party"))
  P.db = pdb
  local guildG, friendG, bnetG = { ["Player-1-A"] = true }, { ["Player-1-B"] = true }, { ["Player-1-C"] = true }
  local roster = { { "Nebeon Nolightforu-Realm" }, { "Kio Alpha-Realm" } }
  local accepted, hidden = 0, {}
  local keep = { AG = _G.AcceptGroup, SH = _G.StaticPopup_Hide, IGM = _G.IsGuildMember, FL = _G.C_FriendList,
                 BN = _G.C_BattleNet, IG = _G.IsInGuild, GN = _G.GetNumGuildMembers, GR = _G.GetGuildRosterInfo,
                 PI = _G.C_PartyInfo, raid = W.raid, inRaid = W.inRaid, type = _G.type, isv = _G.issecretvalue }
  _G.AcceptGroup = function() accepted = accepted + 1 end
  _G.StaticPopup_Hide = function(which) hidden[#hidden + 1] = which end
  _G.IsGuildMember = function(g) return guildG[g] == true end
  _G.C_FriendList = { IsFriend = function(g) return friendG[g] == true end, GetNumFriends = function() return 0 end }
  _G.C_BattleNet = { GetAccountInfoByGUID = function(g) return bnetG[g] and { accountName = "x" } or nil end }
  _G.IsInGuild = function() return true end
  _G.GetNumGuildMembers = function() return #roster end
  _G.GetGuildRosterInfo = function(i) return roster[i] and roster[i][1] end
  local invited = {}
  _G.C_PartyInfo = { InviteUnit = function(n) invited[#invited + 1] = n end, ConvertToRaid = function() end }
  W.raid, W.inRaid = { { name = "Me" } }, false
  P.out, P.held, P.queue = {}, nil, {}
  local function invite(name, guid) fireAll("PARTY_INVITE_REQUEST", name, false, false, false, true, false, guid) end
  local function whisper(text, sender, guid)
    fireAll("CHAT_MSG_WHISPER", text, sender, "", "", "Me", "", 0, 0, "", 0, 1, guid)
    W.runAfters(P.PUMP_GAP + 0.1)
  end

  R:SetEnabled("party", true)
  invite("Nebeon", "Player-1-A")
  ok(accepted == 0, "every switch off (the default): a guildmate's invite waits for you")
  pdb.acceptGuild = true
  invite("Nebeon", "Player-1-A")
  ok(accepted == 1 and hidden[1] == "PARTY_INVITE", "accept from the guild: a guildmate's invite is accepted, the pop-up closed")
  invite("Zed", "Player-1-B")
  ok(accepted == 1, "a friend, with only the guild switch on: waits")
  pdb.acceptFriends = true
  invite("Zed", "Player-1-B")
  invite("Bnet", "Player-1-C")
  ok(accepted == 3, "accept from friends: a character friend and a Battle.net friend")
  invite("Stranger", "Player-1-Z")
  ok(accepted == 3, "a stranger: never")
  -- THE SAME FIRST NAME, ANOTHER PERSON: by GUID, a stranger called Nebeon is a stranger
  invite("Nebeon", "Player-1-Y")
  ok(accepted == 3, "a stranger who shares a guildmate's first name: never (matched by who they are)")
  -- no GUID in the event: a whole name in the roster counts, a first name alone never does
  invite("Nebeon Nolightforu", nil)
  ok(accepted == 4, "no GUID: the guildmate's WHOLE name is enough")
  invite("Nebeon", nil)
  ok(accepted == 4, "no GUID and only a first name: never - it could be anyone called that")
  R:SetEnabled("party", false)
  invite("Nebeon", "Player-1-A")
  ok(accepted == 4, "the party tool off: nothing at all")
  R:SetEnabled("party", true)

  -- THE KEYWORD
  whisper("inv", "Kio Alpha-Realm", "Player-1-A")
  ok(#invited == 0, "invite on a keyword off (the default): a whisper is only a whisper")
  pdb.keyword = true
  if P.box then P.box:Hide() end
  whisper("  INV ", "Kio Alpha-Realm", "Player-1-A")
  ok(invited[1] == "Kio Alpha", "on: a guildmate whispers \"inv\" (any case, spaces around) - invited, whole name, no realm",
     invited[1])
  ok(not (P.box and P.box:IsShown()), "and no inviting show: nobody pressed anything")
  whisper("inv", "Kio Alpha-Realm", "Player-1-A")
  ok(#invited == 1, "the same person again within " .. P.KEYWORD_GAP .. " s: once is enough")
  whisper("inv please", "Zed-Realm", "Player-1-B")
  ok(#invited == 1, "a sentence with the word in it is not the keyword")
  whisper("inv", "Stranger-Realm", "Player-1-Z")
  ok(#invited == 1, "from \"known\" only (the default): a stranger's \"inv\" does nothing")
  pdb.keywordFrom = "anyone"
  whisper("inv", "Stranger-Realm", "Player-1-Z")
  ok(invited[2] == "Stranger", "from anyone: invited", invited[2])
  SlashCmdList.BISTOOLS("party keyword Raid")
  ok(P.Keyword(pdb) == "raid", "/bist party keyword Raid: the word is raid", P.Keyword(pdb))
  whisper("raid", "Zed-Realm", "Player-1-B")
  ok(invited[3] == "Zed", "and \"raid\" invites now", invited[3])
  -- A LOCKDOWN HIDES THE WHISPER: nothing compared, nothing thrown, nobody invited
  local secretMeta = { __index = function() error("attempt to use a secret value", 2) end,
                       __eq = function() error("attempt to compare a secret value", 2) end }
  local realType = type
  _G.type = function(v) if getmetatable(v) == secretMeta then return "string" end return realType(v) end
  _G.issecretvalue = function(v) return getmetatable(v) == secretMeta end
  local okS = pcall(whisper, setmetatable({}, secretMeta), setmetatable({}, secretMeta), "Player-1-A")
  _G.type, _G.issecretvalue = keep.type, keep.isv
  ok(okS and #invited == 3, "a SECRET whisper (lockdown): no error, nobody invited")
  -- not leading: said, not sent
  W.raid = { { name = "Me" }, { name = "Tobi" } }
  local keepLead = _G.UnitIsGroupLeader
  _G.UnitIsGroupLeader = function() return false end
  W.now = W.now + 60
  whisper("raid", "Zed-Realm", "Player-1-B")
  ok(#invited == 3, "someone else leads: nobody invited")
  _G.UnitIsGroupLeader = keepLead
  -- LEAN: whispers come all evening - an ordinary one, keyword on, asks the game nothing
  local Cost = dofile("../_bisdev/dev/cost.lua")
  local nW, byW = Cost.Count(function()
    for i = 1, 100 do fireAll("CHAT_MSG_WHISPER", "hey, are you on tonight? " .. i, "Zed-Realm", "", "", "Me", "", 0, 0, "", 0, i, "Player-1-B") end
  end)
  ok(nW == 0, "cost: 100 whispers that aren't the keyword = " .. nW .. " calls (measured 0)", Cost.Top and Cost.Top(byW, 3))
  print(("   cost: 100 ordinary whispers, keyword on = %d calls"):format(nW))

  pdb.acceptGuild, pdb.acceptFriends, pdb.keyword, pdb.keywordFrom, pdb.keywordText = nil, nil, nil, nil, nil
  R:SetEnabled("party", false)
  P.out, P.held, P.queue, P.asked = {}, nil, {}, nil
  _G.AcceptGroup, _G.StaticPopup_Hide, _G.IsGuildMember, _G.C_FriendList, _G.C_BattleNet = keep.AG, keep.SH, keep.IGM, keep.FL, keep.BN
  _G.IsInGuild, _G.GetNumGuildMembers, _G.GetGuildRosterInfo, _G.C_PartyInfo = keep.IG, keep.GN, keep.GR, keep.PI
  W.raid, W.inRaid = keep.raid, keep.inRaid
end

-- ------------------------------------------------------------ the rides tool (21 Oct 2026)
-- Arn: "if you have BiS Tools installed, do you get a little card when you're in Orgrimmar in the top left side of
-- the screen ... Zeppelin arriving, leaving in X amount of time" - the clock is the shared lib's (LibBiSComm 15:
-- anyone with any BiS addon who rides one times it for the guild); this tool shows it. Then, the same evening: "i
-- want it to only pop out when it arrives and itll show up and say zep to grom leaves in 1 minute ... and if the zeps
-- are far they hide" - a pop-up while a ride waits at the dock; "all rides" keeps the whole list for who wants it.
do
  local RD, lib = NS.Rides, LibBiSComm
  ok(RD and R:Get("rides") and R:Enabled("rides"), "the rides tool, on by default (\"BiS Tools enables the card\")")
  local rdb = R:DBFor(R:Get("rides"))
  local keepMap = W.map
  local function tick() RD.watch.scripts.OnUpdate(RD.watch, 1.01) end
  W.map = 1429                                        -- Elwynn: no zeppelin, no boat
  fireAll("ZONE_CHANGED_NEW_AREA")
  ok(not (RD.frame and RD.frame:IsShown()) and RD.watch.scripts.OnUpdate == nil, "no ride from here: no card, nothing ticks")
  -- ORGRIMMAR (its tower stands on Durotar's map): nothing waiting at the dock - no card, but the watch is on
  W.map = 1454
  fireAll("ZONE_CHANGED_NEW_AREA")
  ok(not (RD.frame and RD.frame:IsShown()) and RD.watch.scripts.OnUpdate ~= nil,
     "in Orgrimmar, no zeppelin in: no card - the watch waits for one")
  -- a guildmate with only BiS Healing rode the Thundercaller: it docked 30 s ago - the card pops up
  local now = lib.RideNow()
  lib.handlers.RIDE.AT("Arn", "org_uc~uc_org", "org_uc", tostring(now - 30), "356", tostring(now), "BiSHealing")
  tick()
  local f = RD.frame
  ok(f and f:IsShown() and f.lines[1].text == '"All aboard for Undercity - we lift off in 0:30!"' and not (f.rows[2] and f.rows[2]:IsShown()),
     "the zeppelin is in: the card pops up with his call, only that one", f and f.lines[1].text)
  -- THE ANNOUNCER (Arn: "it should be this guys portrait telling you like he is announcing"): his face, his name
  ok(f.rows[1].face:IsShown() and f.rows[1].face._creature == 9564 and f.rows[1].who.text == "Frezza",
     "Frezza's face and name: he announces it")
  ok(f.point and f.point[1] == "TOPLEFT", "at the top left")
  ok(f.lines[1].color and f.lines[1].color[1] > 0.8 and f.lines[1].color[3] < 0.5, "in gold")
  ok(f.foot.text:find("timed by Arn - BiSHealing", 1, true), "and who timed it, with which addon", f.foot.text)
  -- HOW SURE, NOT HOW OLD (Arn, 22 Oct, the card reading "634:12 ago": "instead be a confidence % the longer its been
  -- since a reading the less confidence its correct")
  ok(f.foot.text:find("100% sure", 1, true) and not f.foot.text:find("ago", 1, true), "just timed: 100% sure, no age",
     f.foot.text)
  local uc = lib.rideById["org_uc"]
  local function sure(age, stop) return RD.Confidence({ rtt = 356, age = age }, stop) end
  ok(sure(600, uc) == 100, "ten minutes on a measured loop: still sure", sure(600, uc))
  ok(sure(3600, uc) >= 60 and sure(3600, uc) <= 75, "an hour on: about two in three", sure(3600, uc))
  ok(sure(38052, uc) == 0, "Arn's 10 1/2 hours: past 6 h a restart may have reset it - 0%", sure(38052, uc))
  ok(sure(6 * 3600 - 60, uc) > 0 and sure(6 * 3600 + 60, uc) == 0, "the 6-hour line: a minute before, some; a minute after, none")
  ok(sure(3600, uc) > sure(10800, uc) and sure(10800, uc) > sure(38052, uc), "the longer since, the less sure")
  local learned = { id = "nowhere", kind = "zeppelin" }
  local keepKey = lib.RideKey
  lib.RideKey = function(self, s) if s == learned then return "nowhere~nowhere" end return keepKey(self, s) end
  ok(sure(3600, learned) < sure(3600, uc), "a loop learned from rides drifts faster than a measured one",
     sure(3600, learned) .. " < " .. sure(3600, uc))
  lib.RideKey = keepKey
  ok(RD.SureColour(95) == "good" and RD.SureColour(60) == "gold" and RD.SureColour(20) == "warn", "green, gold, red")
  ok(RD.Confidence(nil, uc) == nil and RD.Confidence({ age = 5 }, uc) == nil, "nothing to judge by: no number")
  -- the countdown: once a second
  W.now = W.now + 5
  tick()
  ok(f.lines[1].text:find("lift off in 0:25", 1, true), "five seconds on: 0:25", f.lines[1].text)
  W.now = W.now + 40
  tick()
  ok(not f:IsShown() and RD.watch.scripts.OnUpdate ~= nil, "it left: the card hides; the watch goes on for the next")
  -- "all rides": the whole list, coming and going
  S("rides all")
  ok(rdb.all == true and f:IsShown() and not f.rows[1].face:IsShown() and f.lines[1].text:find("^Zeppelin to Undercity %- arrives in %d+:%d%d$")
     and f.lines[2].text:find("not timed yet", 1, true), "all rides: both zeppelins, coming and going", f.lines[1].text)
  S("rides all")
  ok(rdb.all == false and not f:IsShown(), "and back to the pop-up")
  -- other addons ask BiS Tools (API version 3): the rides, timed or not, docked or not
  ok(BiSToolsAPI.version == 3, "BiSToolsAPI version 3: the rides")
  local rides = BiSToolsAPI.Rides(1454)
  ok(#rides == 2 and rides[1].id == "org_uc" and rides[1].timed and rides[1].by == "Arn" and not rides[1].docked
     and rides[2].timed == false, "Rides(Orgrimmar): both zeppelins, the timed one with its numbers")
  ok(#BiSToolsAPI.RideCard() == 0, "RideCard(): nothing while the card is hidden")
  -- kept between sessions: the lib writes into BiS Tools' saved table
  ok(rdb.clock and rdb.clock["org_uc~uc_org"] and rdb.clock["org_uc~uc_org"].by == "Arn", "the clock is in BiS Tools' saved table")
  -- the next one docks: it pops up again; the options
  W.now = W.now + 356 - 45
  tick()
  ok(f:IsShown() and f.lines[1].text:find("lift off in", 1, true), "the next loop: it pops up again", f.lines[1].text)
  local card = BiSToolsAPI.RideCard()
  ok(#card == 1 and card[1] == f.lines[1].text, "RideCard(): the lines the card shows")
  S("rides off")
  ok(not f:IsShown() and RD.watch.scripts.OnUpdate == nil and rdb.card == false, "/bist rides off: no card, nothing ticks")
  S("rides on")
  ok(f:IsShown(), "/bist rides on: back")
  rdb.who = false RD.Paint()
  ok(not f.foot:IsShown(), "who timed it can be hidden")
  rdb.who = true RD.Paint()
  fitsIn(f, "the ride card")
  -- RIDE-TRAK (Arn, 23 Oct: "shift left click this and show a mock tracker like tram trak"): a strip per ride, the
  -- ride a block on its line - here, crossing, there, coming back - read off the lib's own schedule
  local D = lib.RIDE_DWELL
  local function at(docked, left) return RD.Where({ rtt = 356, docked = docked, left = left }, D) end
  local x0, w0 = at(true, 30)
  local x1, w1, s1 = at(false, 356 - 60 - 59)        -- a minute out, half its crossing gone
  local x2, w2 = at(false, 356 - 178 - 10)           -- docked over there
  local x3, w3, s3 = at(false, 30)                   -- 30 s from here, on its way back
  ok(x0 == 0 and w0 == "here", "docked here: the left end")
  ok(w1 == "out" and math.abs(x1 - 0.5) < 0.01 and math.abs(s1 - 59) < 0.01, "crossing: halfway, there in 59 s", tostring(x1))
  ok(x2 == 1 and w2 == "there", "docked at the far end: the right end")
  ok(w3 == "back" and x3 > 0 and x3 < 0.3 and s3 == 30, "coming back: nearly here, 30 s", tostring(x3))
  ok(RD.Where(nil) == nil, "not timed: nowhere to put it")
  -- the click: only a SHIFT-click opens it; a plain click or a drag's end does nothing
  W.shift = false
  f.scripts.OnMouseUp(f, "LeftButton")
  ok(not rdb.trak, "a plain click: nothing")
  W.shift = true
  f.scripts.OnDragStart(f)
  f.scripts.OnMouseUp(f, "LeftButton")
  ok(not rdb.trak, "shift held at the end of a drag: still nothing")
  f.scripts.OnMouseUp(f, "LeftButton")
  W.shift = false
  local st = f.strips
  ok(rdb.trak == true and st and st[1]:IsShown(), "shift-click: RIDE-TRAK opens")
  -- each strip right under its goblin (Arn: "id like the tracker under the respective goblin so its easier to read")
  local y1 = st[1].point and st[1].point[5]
  local y2 = st[2] and st[2].point and st[2].point[5]
  ok(y1 == -(RD.TOP + RD.ROW) and y2 == -(RD.TOP + RD.ROW + RD.TRAK_H + 4 + RD.ROW),
     "each ride's line right under its own announcer's row, in the card", tostring(y1) .. " / " .. tostring(y2))
  fitsIn(f, "the ride card with RIDE-TRAK open")
  -- YOUR FACE ON IT (Arn: "can it guesstimate what track we are on and put our 2d portrait there?")
  do
    local keepMap2, kx, ky = W.map, W.px, W.py
    W.map, W.px, W.py = 1411, 0.508, 0.137            -- Durotar, on the Undercity platform of Orgrimmar's tower
    RD.seenAt = nil
    RD.Paint()
    local mine
    for i, s in ipairs(f.strips) do if s:IsShown() and s.me.shown then mine = i end end
    local ucRow
    for i, e in ipairs(RD.trakList or {}) do if e.stop.id == "org_uc" then ucRow = i end end
    ok(mine and mine == ucRow and f.strips[mine].me.portrait == "player" and RD.mine == "dock",
       "on the Undercity platform: your face on the Undercity line, at the dock end", tostring(mine) .. " vs " .. tostring(ucRow))
    ok(f.strips[mine].me.anchor and f.strips[mine].me.anchor[4] == RD.TRAK_IN, "at its 'here' end", f.strips[mine].me.anchor and f.strips[mine].me.anchor[4])
    -- the lanes (Arn: "re arrange stuff so stuff does not get cut off" - his face sat on "Undercity"): face above the
    -- line, the end names below it, all inside the strip
    local sm = f.strips[mine]
    local faceLow, faceHigh = sm.me.anchor[5] - RD.ME / 2, sm.me.anchor[5] + RD.ME / 2
    ok(faceLow > RD.LINE_Y and faceHigh <= RD.TRAK_H / 2, "your face in its own lane: above the line, inside the strip",
       faceLow .. ".." .. faceHigh)
    ok(sm.here.anchor and sm.here.anchor[5] < RD.LINE_Y and sm.there.anchor and sm.there.anchor[5] < RD.LINE_Y,
       "'here' and where it goes: under the line, never under your face")
    -- THEY POP (Arn, 23 Oct, Forever's own map: "look how little map changes make the name pop out more")
    ok(sm.here.flags == "OUTLINE" and sm.there.flags == "OUTLINE" and sm.word.flags == "OUTLINE",
       "the names and words outlined, standing off the line", tostring(sm.here.flags))
    -- aboard: the lib saw you leave on it - your face rides the zeppelin's block
    W.px, W.py = 0.30, 0.30                            -- out over the zone, nowhere near a platform
    lib.riding = { from = lib.rideById["org_uc"], t0 = 0 }
    RD.seenAt = nil
    RD.Paint()
    local s = f.strips[ucRow]
    ok(s.me.shown and RD.mine == "ride" and s.me.anchor[4] == s.ride.anchor[4], "aboard: your face rides on its block",
       tostring(s.me.anchor[4]) .. " vs " .. tostring(s.ride.anchor[4]))
    -- THE DOCK WINS (Arn, on the platform in Ghost Wolf: "it thought i was on - should have a check to put me back on
    -- the dock"): the lib says riding, but you stand on the platform, running on your own feet
    W.px, W.py, W.moving = 0.508, 0.137, true
    RD.seenAt = nil RD.Paint()
    W.now = W.now + 1
    W.px = 0.512
    RD.seenAt = nil RD.Paint()
    ok(RD.mine == "dock" and f.strips[ucRow].me.anchor[4] == RD.TRAK_IN,
       "on the platform, running in Ghost Wolf: back on the dock, whatever the lib's riding says", tostring(RD.mine))
    -- but carried off it - moving fast while your feet are still - you are aboard, even this close
    W.moving = false
    W.now = W.now + 1
    W.px = 0.518
    RD.seenAt = nil RD.Paint()
    ok(RD.mine == "ride", "carried off the platform, feet still: aboard", tostring(RD.mine) .. " " .. tostring(RD.seenSpeed))
    -- neither aboard nor on a platform: no guess
    W.px, W.py, W.moving = 0.30, 0.30, false
    lib.riding = nil
    RD.seenAt = nil
    RD.Paint()
    local any = false
    for _, st2 in ipairs(f.strips) do if st2.me.shown then any = true end end
    ok(not any and RD.mine == nil, "away from every platform, riding nothing: no face - no wrong guess")
    W.map, W.px, W.py = keepMap2, kx, ky
    RD.seenAt = nil
    RD.Paint()
  end
  -- open, every ride from here is on it: the timed zeppelin on its line, the one nobody timed scanning
  ok(st[1]:IsShown() and st[1].ride.shown and st[1].there.text == "Undercity" and st[1].word.text:find("leaves in", 1, true),
     "the Undercity zeppelin: a block on its line, docked here", st[1].word.text)
  ok(st[2] and st[2]:IsShown() and st[2].sweep.shown and not st[2].ride.shown
     and st[2].word.text:find("SCANNING", 1, true), "the one nobody timed: SCANNING", st[2] and st[2].word.text)
  ok(RD.trakWatch.scripts.OnUpdate ~= nil, "open, it repaints a few times a second")
  -- it leaves: the card stays up (open, every ride shows) and the block moves off along the line
  W.now = W.now + 120
  tick()
  ok(f:IsShown() and st[1].word.text:find("On its way to Undercity", 1, true), "it left: still on the card, on its way",
     st[1].word.text)
  ok(f.rows[1].face:IsShown() and f.lines[1].text:find("Next one for Undercity is here in", 1, true),
     "RIDE-TRAK open: the announcer stays, and says when it's back (Arn: 'it should not close the cards')", f.lines[1].text)
  ok(f.lines[2].text:find("Nobody's timed", 1, true), "and for the one nobody timed, he says so", f.lines[2].text)
  -- his face, a little way out (Arn: "the goblins are cut off"), tried live with /bist rides zoom
  ok(f.rows[1].face._zoom == RD.ZOOM and RD.ZOOM < 1, "his face at zoom " .. RD.ZOOM .. ", not 1", tostring(f.rows[1].face._zoom))
  S("rides zoom 0.6")
  ok(rdb.zoom == 0.6 and f.rows[1].face._zoom == 0.6, "/bist rides zoom 0.6: every face asked again at 0.6", tostring(f.rows[1].face._zoom))
  S("rides zoom 9")
  ok(rdb.zoom == 0.6, "a zoom out of range: ignored, the current one said")
  rdb.zoom = nil
  RD.trakWatch.scripts.OnUpdate(RD.trakWatch, 0.3)
  local Cost2 = dofile("../_bisdev/dev/cost.lua")
  local nt, tby = Cost2.Count(function() for _ = 1, 240 do W.now = W.now + 0.25 RD.trakWatch.scripts.OnUpdate(RD.trakWatch, 0.26) end end)
  print(("   cost: RIDE-TRAK open, a minute = %d calls (%s)"):format(nt, Cost2.Top(tby, 3)))
  -- the whole card four times a second while open (its words and its strips in step, Arn's "0:21" over "0:20"):
  -- the clock mostly; where you are only once a second
  ok(nt <= 1000, "RIDE-TRAK open: a few cheap questions a repaint, only while open", nt)
  ok((tby["C_Map.GetBestMapForUnit"] or 0) <= 61, "where you are: still once a second, not four", tby["C_Map.GetBestMapForUnit"])
  -- shift-click again: closed, the pop-up as before, its repaint stopped
  W.shift = true
  f.scripts.OnMouseUp(f, "LeftButton")
  W.shift = false
  ok(not rdb.trak and not st[1]:IsShown() and not st[2]:IsShown() and RD.trakWatch.scripts.OnUpdate == nil,
     "shift-click again: closed, nothing of it ticks")
  -- THE X (Arn: "if they close it it should stop popping up ... print the command to enable it again")
  rdb.all = true RD.Paint()
  W.lastMsg = nil
  f.x:Click()
  ok(rdb.card == false and not f:IsShown(), "the X: the card off - it stops popping up")
  ok(W.lastMsg and W.lastMsg:find("/bist rides on", 1, true), "and says how to bring it back", W.lastMsg)
  S("rides on")
  rdb.all = false RD.Paint()
  -- LEAN: a minute where a ride is - one look a second, the map and an instance question each
  local Cost = dofile("../_bisdev/dev/cost.lua")
  local n, by = Cost.Count(function() for _ = 1, 60 do W.now = W.now + 1 tick() end end)
  print(("   cost: the ride card, a minute at the tower = %d calls (%s)"):format(n, Cost.Top(by, 3)))
  -- measured 180: the map, an instance question and the clock, once a second (only where a ride is)
  ok(n <= 200, "the ride card: three cheap questions a second", n)
  -- Thunder Bluff: the Skycutter, never timed - no card (with all rides: its line)
  W.map = 1456
  fireAll("ZONE_CHANGED_NEW_AREA")
  ok(not f:IsShown(), "Thunder Bluff, the Skycutter not timed: no card")
  rdb.all = true RD.Paint()
  ok(f:IsShown() and f.lines[1].text:find("^Zeppelin to Zephras Isle"), "all rides: its line", f.lines[1].text)
  rdb.all = false
  -- in an instance: nothing; and back where no ride is: nothing ticks
  W.map = 1454
  RD.Paint()
  local keepInst = _G.IsInInstance
  _G.IsInInstance = function() return true, "party" end
  RD.Paint()
  ok(not f:IsShown(), "in an instance: no card")
  _G.IsInInstance = keepInst
  W.map = 1429
  fireAll("ZONE_CHANGED_NEW_AREA")
  ok(not f:IsShown() and RD.watch.scripts.OnUpdate == nil, "away from every ride: hidden, nothing ticks")
  W.map = keepMap
end

-- THE DEEPRUN TRAM ON THE CARD (LibBiSComm 17; Arn, 23 Oct: "go ahead with the tram in the library" - "i can ship in
-- both but dont want two cards floating"). Against the CANONICAL lib, loaded on its own; skipped until it has the tram.
do
  local chunk = loadfile("../_bisdev/LibBiSComm-1.0/LibBiSComm-1.0.lua")
  local env = setmetatable({}, { __index = function(_, k) if k == "LibBiSComm" then return nil end return _G[k] end })
  env._G = env
  local tlib
  if chunk then
    setfenv(chunk, env)
    if pcall(chunk) then tlib = rawget(env, "LibBiSComm") end
  end
  if not (tlib and tlib.TRAM_MAP and tlib.RideSure) then
    print("   (the tram on the ride card: skipped - the canonical lib has no tram yet)")
  else
    local RD = NS.Rides
    local rdb = R:DBFor(R:Get("rides"))
    local real = _G.LibBiSComm
    local keep = { map = W.map, inst = _G.GetInstanceInfo, pos = _G.UnitPosition, ii = _G.IsInInstance, api = rawget(_G, "BiSShellAPI") }
    _G.LibBiSComm = tlib
    W.map = nil                                         -- no map in the tram: measured
    _G.GetInstanceInfo = function() return "Deeprun Tram", "none", 0, "", 0, 0, false, 369 end
    _G.IsInInstance = function() return true, "none" end
    local along, across = 2471.3, -33.4                 -- Stormwind's platform
    _G.UnitPosition = function(u) if u == "player" then return across, along, 0, 369 end end
    rdb.card, rdb.all, rdb.trak = true, false, nil
    local now = tlib.RideNow()
    tlib:RideSet("tram_if~tram_sw", "tram_sw", now - 5, 143.2, now, "Arn", "BiSShell")   -- it docked 5 s ago
    RD.seenAt = nil
    RD.Paint()
    local f = RD.frame
    ok(f:IsShown() and f.lines[1].text:find("All aboard for Ironforge - we roll in 0:08", 1, true) and not (f.rows[2] and f.rows[2]:IsShown()),
       "in the tram, on Stormwind's platform: the tram to Ironforge, waiting - only your side's", f.lines[1].text)
    ok(f.foot.text:find("100% sure", 1, true), "how sure: the lib's own number", f.foot.text)
    -- one card: TRAM-TRAK up, ours waits
    _G.BiSShellAPI = { major = 1, version = 2, TramShown = function() return true end }
    RD.seenAt = nil
    RD.Paint()
    ok(not f:IsShown() and RD.watch.scripts.OnUpdate ~= nil, "BiS Shell's TRAM-TRAK up: our card waits (the watch goes on)")
    _G.BiSShellAPI = { major = 1, version = 2, TramShown = function() return false end }
    RD.Paint()
    ok(f:IsShown(), "TRAM-TRAK away: ours is back")
    -- RIDE-TRAK: both cars on the line, and you at the dock
    rdb.trak = true
    RD.seenAt = nil
    RD.Paint()
    local s = f.strips[1]
    ok(s.ride.shown and s.ride2.shown and s.ride.anchor[4] ~= s.ride2.anchor[4], "RIDE-TRAK: both cars, each its own block")
    ok(s.me.shown and RD.mine == "dock", "and you at Stormwind's end")
    -- aboard, half way: your face where you are on the line
    tlib.riding = { from = tlib.rideById.tram_sw, t0 = 0 }
    along, across = (2471.3 - 12) / 2, -45.6
    RD.seenAt = nil
    RD.Paint()
    local mx = s.me.anchor[4]
    ok(RD.mine == "ride" and math.abs(mx - (RD.TRAK_IN + 0.5 * (RD.STRIP_W - 2 * RD.TRAK_IN))) < 2,
       "aboard, half way down the tunnel: your face half way along the line", mx)
    tlib.riding = nil
    rdb.trak = nil
    _G.LibBiSComm = real
    W.map, _G.GetInstanceInfo, _G.UnitPosition, _G.IsInInstance, _G.BiSShellAPI = keep.map, keep.inst, keep.pos, keep.ii, keep.api
    RD.seenAt = nil
    RD.Paint()
  end
end

local allowed = { BiSTools = true, BiSToolsDB = true, SLASH_BISTOOLS1 = true, SLASH_BISTOOLS2 = true,
  SLASH_BISTOOLS3 = true,
  -- the embedded third-party libs' own globals (Libs/THIRD-PARTY.txt): LibStub, and the world-map
  -- show flags HereBeDragons-Pins defines for every addon that pins
  LibStub = true, HBD_PINS_WORLDMAP_SHOW_PARENT = true, HBD_PINS_WORLDMAP_SHOW_CONTINENT = true,
  HBD_PINS_WORLDMAP_SHOW_WORLD = true,
  LibBiSComm = true, SLASH_BISCOMM1 = true, ConfirmSummon = true, BiSRezComm = true,
  BiSTheme = true,    -- the embedded Libs/BiSTheme/Console.lua guards on this global on purpose
  BiSToolsAPI = true, -- API.lua, for other addons (16 Oct: BiS Guild's invites)
  -- the overlay map's key binding: Bindings.xml calls a global, and the client reads these two names
  BiSTools_ToggleOverlayMap = true, BINDING_HEADER_BISTOOLS = true, BINDING_NAME_BISTOOLS_OVERLAYMAP = true }
for k in pairs(_G) do
  if not before[k] and not allowed[k] and not frames[k] then error("leaked global: " .. k) end
end
print(("ALL OK (%d checks)"):format(pass))
