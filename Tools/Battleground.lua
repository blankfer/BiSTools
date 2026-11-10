--[[
  BiSTools :: Tools/Battleground.lua - the "bg" tool: the enemy's healers and their top killer, marked.

  Arn's cousin, 13 Oct 2026: "can it auto crosshair people that cast heals". Not from their casts:
  Forever hides every other player's cast from addons in combat (measured on the beta; the cast bar
  draws, nothing can read it). But the BATTLEGROUND SCOREBOARD lists each player's healing done and
  killing blows, and its calls are on the Forever census. So, in a battleground:

    HEALERS  the enemy's top three by healing done (Arn: "on their top three heals") wear a WHITE
             NEON SABER - a white-hot core in soft glow layers, standing at the left of the plate,
             with a dark hilt (Arn: "a white neon white saber looking thing")
    KILLER   the enemy with the most killing blows wears a RED GLOW round the plate (Arn: "red cross
             hairs glowing like the threat meter on their top killing blow person") - the old threat
             tool's glow (retired 9 Nov 2026), sides and bottom, open at the top so the name stays clear

  The scoreboard is asked every T.EVERY seconds while you are in a battleground (RequestBattlefield-
  ScoreData; the answer arrives as UPDATE_BATTLEFIELD_SCORE) and never outside one. Read through
  C_PvP.GetScoreInfo - named fields, so no guessing at a return order that differs between clients.
  Every field asked "hidden?" first. A player is matched to a nameplate by GUID, else by name.
  UNVERIFIED on Forever: that the scoreboard's numbers come back unhidden mid-match - /bist bg why
  prints what it read.

  Our own frames, pinned beside the plate: nothing of the game's nameplate is touched, a plate the
  client locks away gets nothing.
]]
local _, NS = ...
local R = NS.Registry
local RC = NS.Recap
local F = NS.Farm

local B = {}
NS.BG = B

B.EVERY = 10                       -- seconds between scoreboard reads, in a battleground only
B.TOP_HEALERS = 3
B.WHITE = { 0.92, 0.97, 1.00 }     -- a neon white, a breath of blue
B.RED = { 1.00, 0.12, 0.12 }
B.SABER_W, B.SABER_H = 2, 70       -- the core's width; its height, the rival crosshair's (RC.MARK_H)
B.plates = {}                      -- nameplate units in sight
B.marks, B.pool = {}, {}           -- unit -> frame, and spare frames per kind
B.healers, B.killer = {}, nil      -- guid/name -> rank (1-3), and the top killer's key
B.read = {}                        -- what the last scoreboard read saw, for why

local plain = F.Plain

local function yes(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if not ok then return nil end
  return plain(v)
end

local function field(t, k)
  local ok, v = pcall(function() return t[k] end)
  if not ok then return nil end
  return plain(v)
end

--- A scoreboard name without its realm ("Grape-Realm" -> "Grape").
local function bare(n)
  if type(n) ~= "string" then return nil end
  return (n:match("^([^%-]+)") or n)
end

------------------------------------------------------------------- reading --

--- Every player on the scoreboard: name, guid, enemy?, healing done, killing blows. Hidden fields
--- are left out (nil), never guessed.
function B.Scores()
  local out = {}
  -- the fence's pair form: C_PvP's named table first; the old global (TBC) answers with a list in an
  -- order that differs by client, so its rows are not tables and are skipped below - never guessed at
  local G = (C_PvP and C_PvP.GetScoreInfo) or GetBattlefieldScore
  local n = yes(GetNumBattlefieldScores) or 0
  if not G or type(n) ~= "number" then return out, "no scoreboard on this client" end
  local mine = yes(UnitFactionGroup, "player")
  local myFaction = mine == "Horde" and 0 or (mine == "Alliance" and 1 or nil)
  local hidden = 0
  -- cost: once per scoreboard update (every B.EVERY s, in a battleground only), one row per player
  for i = 1, n do
    local ok, info = pcall(G, i)
    if ok and type(info) == "table" then
      local name, guid = field(info, "name"), field(info, "guid")
      local faction, heal, kb = field(info, "faction"), field(info, "healingDone"), field(info, "killingBlows")
      if heal == nil or kb == nil then hidden = hidden + 1 end
      out[#out + 1] = {
        name = bare(name), guid = type(guid) == "string" and guid or nil,
        enemy = (type(faction) == "number" and myFaction ~= nil) and faction ~= myFaction or nil,
        heal = type(heal) == "number" and heal or nil, kb = type(kb) == "number" and kb or nil,
      }
    end
  end
  return out, hidden > 0 and (hidden .. " row(s) with the numbers hidden") or nil
end

--- The enemy's top three healers and their top killer, from a scoreboard read.
function B.Pick(scores)
  local enemies = {}
  for _, s in ipairs(scores) do if s.enemy then enemies[#enemies + 1] = s end end
  local heals = {}
  for _, s in ipairs(enemies) do if (s.heal or 0) > 0 then heals[#heals + 1] = s end end
  table.sort(heals, function(a, b) return a.heal > b.heal end)
  local healers = {}
  for i = 1, math.min(B.TOP_HEALERS, #heals) do
    local s = heals[i]
    if s.guid then healers[s.guid] = i end
    if s.name then healers[s.name] = i end
  end
  local killer, best = nil, 0
  for _, s in ipairs(enemies) do
    if (s.kb or 0) > best then best, killer = s.kb, s end
  end
  B.read = { enemies = #enemies, heals = heals, killer = killer }
  return healers, killer
end

--- FOREVER HIDES THE NUMBERS (Arn's /bist bg raw, 14 Oct: only name, faction, class and race are
--- plain mid-match). Arn's idea, same night - "what about we can click the top heals": the game can
--- still SORT the board by a hidden column, and the names come back in that order. Proven in his
--- match: sorted by kills, the names matched the board's killing blows. So: sort, read names.
B.HEAL_CLASSES = { PRIEST = true, DRUID = true, SHAMAN = true, PALADIN = true }
B.WARMUP = 90       -- s into a match before anyone is marked: until then everyone ties at 0, in no order
B.ORDER_GAP = 5     -- s: a sort can itself fire UPDATE_BATTLEFIELD_SCORE - never read again inside this

local function sortRead(col, myFaction)
  if not pcall(SortBattlefieldScoreData, col) then return nil end
  local n = yes(GetNumBattlefieldScores) or 0
  local out, ours = {}, {}
  for i = 1, type(n) == "number" and n or 0 do
    local ok, info = pcall(C_PvP.GetScoreInfo, i)
    if ok and type(info) == "table" then
      local faction = field(info, "faction")
      if type(faction) == "number" and myFaction ~= nil then
        local row = { name = bare(field(info, "name")), class = field(info, "classToken") }
        if faction ~= myFaction then out[#out + 1] = row else ours[#ours + 1] = row end
      end
    end
  end
  return out, ours
end

--- The scoreboard window, if Blizzard's is open: we never re-sort what Arn is looking at.
--- Second answer: the window that exists (shown or not), for the button to sit on.
B.BOARDS = { "PVPMatchScoreboard", "WorldStateScoreFrame" }
function B.Board()
  local found
  for _, n in ipairs(B.BOARDS) do
    local f = _G[n]
    if f and f.IsShown then
      found = found or f
      local ok, shown = pcall(f.IsShown, f)
      if ok and plain(shown) == true then return f, f end
    end
  end
  return nil, found
end

--- "BiS> mark" on the scoreboard (Arn: "add a button in scoreboard"): read the board's order now,
--- even with the window open, mark, and say who. Our own button on UIParent, shown with the window
--- (hooked), placed on its bottom-right; the window's own frames are never touched.
function B.Button()
  local _, board = B.Board()
  if not board or B.button then return B.button end
  local K = NS.Farm
  local b = CreateFrame("Button", "BiSToolsBGMark", UIParent)
  b:SetSize(84, 20)
  -- 14 Oct, Arn's screenshot: "shown" on the window's own layer, yet not to be seen - under the
  -- window's inner panels. The top layer, and just UNDER the window's bottom edge, where nothing of
  -- Blizzard's sits; if its place cannot be taken (hidden rects in an instance), top of the screen.
  b:SetFrameStrata("FULLSCREEN_DIALOG")
  if b.SetToplevel then pcall(b.SetToplevel, b, true) end
  if not pcall(b.SetPoint, b, "TOP", board, "BOTTOM", 0, -2) then
    b:SetPoint("TOP", UIParent, "TOP", 0, -120)
  end
  K.tex(b, "BACKGROUND", "frame", 0.85)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.text:SetPoint("CENTER")
  b.text:SetText(NS.T.text("accent", "BiS>") .. " mark")
  b:SetScript("OnClick", function() B.Mark() end)
  local function show(on) if on then b:Show() else b:Hide() end end
  show(board:IsShown() and B.On())
  board:HookScript("OnShow", function() show(B.On()) end)
  board:HookScript("OnHide", function() b:Hide() end)
  B.button = b
  return b
end

--- /bist bg board: why no button - which scoreboard windows exist, and what is under the mouse.
--- Hover the scoreboard, type it: the window's real name on Forever, if B.BOARDS has it wrong.
function B.BoardWhy()
  for _, n in ipairs(B.BOARDS) do
    local f = _G[n]
    local okS, shown = pcall(function() return f and f:IsShown() end)
    local okT, strata = pcall(function() return f and f:GetFrameStrata() end)
    NS.Print("bg board: %s %s%s", n, f and "exists" or "missing",
      f and ((okS and plain(shown) and ", shown" or ", hidden") .. ", " .. tostring(okT and plain(strata) or "?")) or "")
  end
  local b = B.button
  local where = "?"
  if b then
    local okR, l, bt, w, h = pcall(b.GetRect, b)
    if okR then where = ("%s,%s %sx%s"):format(tostring(plain(l)), tostring(plain(bt)), tostring(plain(w)), tostring(plain(h))) end
  end
  NS.Print("bg board: button %s", b and ((b:IsShown() and "shown" or "hidden") .. ", " .. tostring(b:GetFrameStrata())
    .. ", at " .. where .. (b.IsVisible and (b:IsVisible() and ", visible" or ", NOT visible") or "")) or "not made yet")
  local foci = {}
  local okM, list = pcall(function() return GetMouseFoci and GetMouseFoci() end)
  for _, f in ipairs(okM and type(list) == "table" and list or {}) do
    local chain, cur = {}, f
    for _ = 1, 8 do
      if not cur then break end
      local okN, nm = pcall(cur.GetName, cur)
      chain[#chain + 1] = tostring(okN and plain(nm) or "?")
      local okP, par = pcall(cur.GetParent, cur)
      cur = okP and par or nil
    end
    foci[#foci + 1] = table.concat(chain, " < ")
  end
  NS.Print("bg board: under the mouse: %s", #foci > 0 and table.concat(foci, " | ") or "nothing named")
end

--- The box button's macro: the marked players, those far away first and those with a plate on
--- screen LAST - the last /target that finds someone wins, so a near one is chosen over a far one.
--- Healers before the killer within each group. At most RC.MACRO_MAX characters.
function B.TargetMacro()
  local near, far = {}, {}
  local onPlate = {}
  for u in pairs(B.marks) do
    local n = B.PlateName(u)
    if n then onPlate[n] = true end
  end
  local function add(name)
    if type(name) ~= "string" or name == "" then return end
    local first = name:match("^(%S+)")
    if onPlate[name] or onPlate[first] then near[#near + 1] = name else far[#far + 1] = name end
  end
  local hs = {}
  for name, rank in pairs(B.healers or {}) do if type(name) == "string" and type(rank) == "number" then hs[#hs + 1] = { name, rank } end end
  table.sort(hs, function(x, y) return x[2] > y[2] end)       -- #3 first, #1 last: the top healer wins a tie
  if B.killer and B.killer.name then add(B.killer.name) end
  for _, h in ipairs(hs) do add(h[1]) end
  local lines, len = {}, 0
  local max = (NS.Recap and NS.Recap.MACRO_MAX) or 255
  for _, group in ipairs({ far, near }) do
    for _, name in ipairs(group) do
      local line = "/target " .. name
      if len + #line + 1 <= max then lines[#lines + 1] = line len = len + #line + 1 end
    end
  end
  return table.concat(lines, "\n"), #lines
end

--- Written into the secure button out of combat only; in a fight, the next PLAYER_REGEN_ENABLED.
function B.ApplyMacro()
  local b = B.bbtn
  if not b then return false end
  if InCombatLockdown and InCombatLockdown() then B.macroDirty = true return false end
  B.macroDirty = nil
  local macro = B.TargetMacro()
  b:SetAttribute("macrotext1", macro)
  b.macro = macro
  return true
end

--- In a battleground, asked live (the box may lay out before B.Watch has heard the same event).
function B.InBG()
  local ok, inside, kind = pcall(IsInInstance)
  return ok and plain(inside) == true and plain(kind) == "pvp"
end

--- The same "mark" in the BiS> tools box (Arn, 14 Oct: "add that scoreboard button to the bis
--- tools") - read the board mid-fight without opening it. Its face: a little lit saber.
function B.BoxButton()
  if B.bbtn then return B.bbtn end
  local K = NS.Farm
  -- SECURE (Arn, 14 Oct: "when i click this i also want to try and target the nearest on the list"):
  -- targeting is protected, so a macro, as the rival target button; its names are written out of
  -- combat only (B.ApplyMacro). The read itself is our Lua, hooked after.
  local b = CreateFrame("Button", "BiSToolsBGMarkBox", UIParent, "SecureActionButtonTemplate")
  b:SetSize(26, 26)
  b:SetFrameStrata("MEDIUM")
  b:RegisterForClicks("AnyDown")
  -- LEFT targets, RIGHT marks (Arn, 14 Oct: "right click marks left click targets"): the macro is
  -- the left button's alone; the right button is ours (B.Mark), nothing secure
  b:SetAttribute("type1", "macro")
  b:SetAttribute("macrotext1", "")
  K.tex(b, "BACKGROUND", "field", 0.95)
  b.edge = K.border(b, "accent", 1)
  local function tex(f, layer, c, a, add)
    local t = f:CreateTexture(nil, layer)
    t:SetColorTexture(c[1], c[2], c[3], a or 1)
    if add and t.SetBlendMode then pcall(t.SetBlendMode, t, "ADD") end
    return t
  end
  for _, layer in ipairs({ { 7, 0.18 }, { 4, 0.45 }, { 2, 1 } }) do
    local t = tex(b, "ARTWORK", B.WHITE, layer[2], true)
    t:SetPoint("TOP", b, "TOP", 0, -4)
    t:SetPoint("BOTTOM", b, "BOTTOM", 0, 9)
    t:SetWidth(layer[1])
  end
  local hilt = tex(b, "OVERLAY", { 0.55, 0.57, 0.6 }, 1)
  hilt:SetPoint("BOTTOM", b, "BOTTOM", 0, 4)
  hilt:SetSize(4, 5)
  b:HookScript("OnClick", function(_, button) if button == "RightButton" then B.Mark() end end)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Their healers and killer")
    GameTooltip:AddLine("Left-click: target one of them - those near you first (who it targets is set out of combat).", 1, 1, 1, true)
    GameTooltip:AddLine("Right-click: mark them - reads the scoreboard now: white on their top three healers, red on their top killer. Same as /bist bg mark.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  b:Hide()
  B.bbtn = b
  return b
end

function B.Mark()
  if not B.On() then return NS.Print("bg: not in a battleground") end
  if not B.ReadOrder(true) then return NS.Print("bg: %s", (B.read and B.read.note) or "the board could not be read") end
  B.PaintAll()
  B.ApplyMacro()
  local names = {}
  for _, s in ipairs(B.read.heals or {}) do names[#names + 1] = s.name end
  NS.Print("bg: healers %s; killer %s", #names > 0 and table.concat(names, ", ") or "none",
    B.killer and B.killer.name or "none")
end

--- Top healers and killer by the board's order. `force` = the button: sort even with the window open.
function B.ReadOrder(force)
  if not (SortBattlefieldScoreData and C_PvP and C_PvP.GetScoreInfo) then return false end
  -- never sort what Arn may be looking at: the window open, OR not found at all - then we cannot
  -- know it is closed (14 Oct: the name was wrong, it sorted every 10 s under his eyes - "annoying")
  local open, exists = B.Board()
  if not force and (open or not exists) then
    if not exists then B.read = B.read or { enemies = 0, heals = {} } B.read.wait = "the scoreboard window was not found - /bist bg mark reads it, /bist bg board says why" B.read.note = B.read.wait end
    return false
  end
  local now = GetTime and GetTime() or 0
  if not force and B.lastOrder and now - B.lastOrder < B.ORDER_GAP then return false end
  local run = yes(GetBattlefieldInstanceRunTime)
  if type(run) == "number" and run < B.WARMUP * 1000 then
    B.read = { enemies = 0, heals = {}, wait = "the match has only just started - marked from " .. B.WARMUP .. " s" }
    B.read.note = B.read.wait
    return false
  end
  B.lastOrder = now
  local mine = yes(UnitFactionGroup, "player")
  local myFaction = mine == "Horde" and 0 or (mine == "Alliance" and 1 or nil)
  -- a different column first: sorting the same column twice flips it, and Arn may have clicked one
  pcall(SortBattlefieldScoreData, "name")
  local byHeal, ourHeal = sortRead("healing", myFaction)
  local byKill, ourKill = sortRead("kills", myFaction)
  byHeal, byKill, ourHeal, ourKill = byHeal or {}, byKill or {}, ourHeal or {}, ourKill or {}
  -- OUR side's best healer (a healing class, as theirs) and best killer: >MVP<
  B.mvps = {}
  for _, s in ipairs(ourHeal) do
    if s.name and B.HEAL_CLASSES[s.class or ""] then B.mvps[s.name] = "healer" break end
  end
  if ourKill[1] and ourKill[1].name then B.mvps[ourKill[1].name] = B.mvps[ourKill[1].name] or "killer" end
  local heals, healers = {}, {}
  for _, s in ipairs(byHeal) do
    if s.name and B.HEAL_CLASSES[s.class or ""] and #heals < B.TOP_HEALERS then
      heals[#heals + 1] = s
      healers[s.name] = #heals
    end
  end
  local killer = byKill[1] and byKill[1].name and byKill[1] or nil
  B.healers, B.killer = healers, killer
  B.read = { enemies = #byHeal, heals = heals, killer = killer, note = "numbers hidden - read by the board's order", byOrder = true }
  B.Remember(heals, killer)
  return true
end

------------------------------------------------------------------- drawing --

local function plateOf(u)
  local get = C_NamePlate and C_NamePlate.GetNamePlateForUnit
  if not get then return nil end
  local ok, plate = pcall(get, u)
  if not ok or not plate then return nil end
  local okF, forbidden = pcall(function() return plate.IsForbidden and plate:IsForbidden() end)
  if not okF or forbidden then return nil end
  return plate
end

local function tex(f, layer, c, a, add)
  local t = f:CreateTexture(nil, layer)
  t:SetColorTexture(c[1], c[2], c[3], a or 1)
  if add and t.SetBlendMode then pcall(t.SetBlendMode, t, "ADD") end
  return t
end

local function pulse(f, low, dur)
  if not f.CreateAnimationGroup then return end
  local ok, g = pcall(f.CreateAnimationGroup, f)
  if not (ok and g) then return end
  local a = g:CreateAnimation("Alpha")
  a:SetFromAlpha(1) a:SetToAlpha(low) a:SetDuration(dur)
  if a.SetSmoothing then a:SetSmoothing("IN_OUT") end
  g:SetLooping("BOUNCE")
  f.pulse = g
end

--- CROSSED SABERS, an X, glowing (Arn, 14 Oct: "lets make them sabers X and glowing same for
--- killer but red"): white on their healers, red on their killer. Each blade a white-hot core in two
--- soft glow layers with a dark hilt, drawn as Lines (a solid texture's SetRotation turns only its
--- image inside its box, so a thin bar cannot be tilted that way). A client without Lines: one
--- upright blade, as before.
B.X_W = 46                          -- the X's width before a plate sizes it; its height is B.SABER_H
B.X_SIZE = { 30, 35 }               -- BiS Healing's tank X (FN.TANK_W, FN.TANK_H): the same X

--- THE LOOKS (Arn, 14 Oct: "i also wanted different disigns not all want x"). Strokes in a box
--- from -1 to 1 each way, scaled to the size stepper; the X and the saber wear hilts. The same five,
--- in the same order, as BiS Healing's tank mark (Now.lua FN.LOOKS).
B.LOOKS = {
  { key = "x", word = "X", hilts = true, strokes = { { -1, -1, 1, 1 }, { 1, -1, -1, 1 } } },
  { key = "saber", word = "saber", hilts = true, strokes = { { 0, -1, 0, 1 } } },
  { key = "arrow", word = "arrow", strokes = { { -1, 1, 0, -0.3 }, { 1, 1, 0, -0.3 } } },
  { key = "diamond", word = "diamond", strokes = { { 0, 1, 1, 0 }, { 1, 0, 0, -1 }, { 0, -1, -1, 0 }, { -1, 0, 0, 1 } } },
  { key = "corners", word = "corners", strokes = {
    { -1, 1, -0.45, 1 }, { -1, 1, -1, 0.45 }, { 1, 1, 0.45, 1 }, { 1, 1, 1, 0.45 },
    { -1, -1, -0.45, -1 }, { -1, -1, -1, -0.45 }, { 1, -1, 0.45, -1 }, { 1, -1, 1, -0.45 } } },
  -- THE TAG (Arn, 14 Oct, with his own picture: ">Healer<" in red in a white box - "remove the black",
  -- "do white arrows instead of red"): drawn by the game, no background, white arrows, red word. The
  -- killer's reads >Killer<. BiS Tools only (BiS Healing's tank mark keeps its five).
  { key = "tag", word = "tag", tag = true, strokes = {} },
}
-- the tag's box at 100%; the size stepper scales it. 66x18 at first - Arn, 14 Oct, in the open world:
-- "very small and kinda hard to see". Bigger, outlined letters, a thicker box, a gentler pulse.
B.TAG = { 110, 28 }
B.TAG_EDGE = 2
-- THE FLASH: full to B.PULSE_LOW and back, B.PULSE_DUR each way. Borrowed from the threat tool until it was retired
-- (9 Nov 2026); the same numbers, now our own.
B.PULSE_LOW, B.PULSE_DUR = 0.3, 0.5
B.TAG_PULSE_LOW = 0.7               -- dims to 70% only: a tag must be read, not just noticed
B.TAG_WORD = { healer = "Healer", killer = "Killer" }

--- ">Healer<": white arrows, a red word.
B.TAG_WORD.mvp = "MVP"
B.TAG_INK = { healer = "ff1a1a", killer = "ff1a1a", mvp = "ffd100" }   -- their marks red; our MVP gold

function B.TagText(kind)
  return "|cffffffff>|r|cff" .. (B.TAG_INK[kind] or "ff1a1a") .. (B.TAG_WORD[kind] or "Healer") .. "|r|cffffffff<|r"
end

--- The chosen look's place in B.LOOKS (the stepper's number), 1 = X.
function B.LookIndex(db)
  db = db or R:DBFor(R:Get("bg"))
  local v = tonumber(db.look)
  v = v and math.floor(v) or 1
  return (v >= 1 and v <= #B.LOOKS) and v or 1
end

-- slim (Arn, 14 Oct, the X in the crosshair: "50% smaller"): half the glow it first had
local function blade(f, c, stroke, hilted)
  local W = B.SABER_W
  local bl = { stroke = stroke, lines = {} }
  for _, layer in ipairs({ { W + 4, 0.16 }, { W + 1.5, 0.45 }, { W, 1 } }) do
    local l = f:CreateLine(nil, "ARTWORK")
    l:SetTexture("Interface\\Buttons\\WHITE8X8")
    l:SetVertexColor(c[1], c[2], c[3], layer[2])
    if layer[2] < 1 and l.SetBlendMode then pcall(l.SetBlendMode, l, "ADD") end
    l:SetThickness(layer[1])
    l.w = layer[1]
    f.parts[#f.parts + 1] = l
    bl.lines[#bl.lines + 1] = l
  end
  if hilted then
    local h = f:CreateLine(nil, "OVERLAY")
    h:SetTexture("Interface\\Buttons\\WHITE8X8")
    h:SetVertexColor(0.2, 0.2, 0.22, 1)
    h:SetThickness(W + 2)
    bl.hilt = h
    f.hilts[#f.hilts + 1] = h
  end
  f.blades[#f.blades + 1] = bl
end

--- The strokes to a box (Arn: "like the tips of the x on the corners of the red cross hairs"). A
--- hilted stroke runs hilt-first: its lowest sixth is the hilt, the rest the blade.
local function fit(f, w, h)
  local x, y = w / 2 - 2, h / 2 - 2
  for _, bl in ipairs(f.blades) do
    local s = bl.stroke
    local x1, y1, x2, y2 = s[1] * x, s[2] * y, s[3] * x, s[4] * y
    local hx, hy = x1, y1
    if bl.hilt then
      hx, hy = x1 + (x2 - x1) * 0.16, y1 + (y2 - y1) * 0.16
      bl.hilt:SetStartPoint("CENTER", f, x1, y1)
      bl.hilt:SetEndPoint("CENTER", f, hx, hy)
    end
    for _, l in ipairs(bl.lines) do
      l:SetStartPoint("CENTER", f, hx, hy)
      l:SetEndPoint("CENTER", f, x2, y2)
    end
  end
end

function B.NewSaber(kind, look)
  kind = kind or "healer"
  look = look or 1
  local c = kind == "killer" and B.RED or B.WHITE
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetFrameStrata("BACKGROUND")
  f.kind, f.look = kind, look
  f.parts, f.hilts = {}, {}
  f.blades = {}
  -- our MVP always wears the tag (Arn: "mark them MVP with the same box style"), whatever the look
  if kind == "mvp" or (B.LOOKS[look] and B.LOOKS[look].tag) then
    -- the white box: four thin edges, nothing behind (no black)
    f.tag = true
    f.edges = {}
    for _, side in ipairs({ "top", "bottom", "left", "right" }) do
      local t = tex(f, "BORDER", B.WHITE, 1)
      f.edges[side] = t
      f.parts[#f.parts + 1] = t
    end
    f.text = f:CreateFontString(nil, "OVERLAY")
    f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
    -- THICKER LETTERS (Arn: "maybe thicker letters too"): the game's fonts have no bold, so the word
    -- is drawn twice, a pixel apart - every stroke a pixel heavier
    f.text2 = f:CreateFontString(nil, "OVERLAY")
    f.text2:SetPoint("CENTER", f, "CENTER", 1, 0)
    function f.Fit(_, w, h)
      local e, t = f.edges, B.TAG_EDGE
      e.top:ClearAllPoints() e.top:SetPoint("TOPLEFT", f, "TOPLEFT") e.top:SetPoint("TOPRIGHT", f, "TOPRIGHT") e.top:SetHeight(t)
      e.bottom:ClearAllPoints() e.bottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT") e.bottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT") e.bottom:SetHeight(t)
      e.left:ClearAllPoints() e.left:SetPoint("TOPLEFT", f, "TOPLEFT") e.left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT") e.left:SetWidth(t)
      e.right:ClearAllPoints() e.right:SetPoint("TOPRIGHT", f, "TOPRIGHT") e.right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT") e.right:SetWidth(t)
      -- OUTLINED letters: no background (Arn: "remove the black"), but red on sand and grass needs an
      -- edge on each letter to be read
      local size = math.max(8, math.floor(h * 0.6 + 0.5))
      for _, fs in ipairs({ f.text, f.text2 }) do
        pcall(fs.SetFont, fs, STANDARD_TEXT_FONT, size, "THICKOUTLINE")
        fs:SetText(B.TagText(f.kind))
      end
    end
    f:Fit(B.TAG[1], B.TAG[2])
    pulse(f, B.TAG_PULSE_LOW, B.PULSE_DUR)
    return f
  end
  if f.CreateLine and pcall(function()
    local L = B.LOOKS[look]
    for _, st in ipairs(L.strokes) do blade(f, c, st, L.hilts) end
    fit(f, B.X_W, B.SABER_H)
  end) then
    f.x = true
    f.Fit = fit
  else
    f.parts, f.hilts = {}, {}
    for _, layer in ipairs({ { B.SABER_W + 10, 0.12 }, { B.SABER_W + 4, 0.35 }, { B.SABER_W, 1 } }) do
      local t = tex(f, "ARTWORK", c, layer[2], true)
      t:SetPoint("TOP", f, "TOP", 0, 0)
      t:SetPoint("BOTTOM", f, "BOTTOM", 0, 7)
      t:SetWidth(layer[1])
      f.parts[#f.parts + 1] = t
    end
    local hilt = tex(f, "OVERLAY", { 0.18, 0.18, 0.2 }, 1)
    hilt:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
    hilt:SetSize(B.SABER_W + 4, 7)
    f.hilts[1] = hilt
  end
  f.hilt = f.hilts[1]
  -- the old threat meter's flash, the same for both (Arn: "i want that kind of pulsing")
  pulse(f, B.PULSE_LOW, B.PULSE_DUR)
  return f
end

function B.Undraw(u)
  local f = B.marks[u]
  if not f then return end
  if f.pulse then f.pulse:Stop() end
  f:Hide()
  f:ClearAllPoints()
  B.marks[u] = nil
  local pk = f.kind .. (f.look or 1)                -- pooled by kind AND look
  B.pool[pk] = B.pool[pk] or {}
  table.insert(B.pool[pk], f)
end

function B.Draw(u, kind)
  local f = B.marks[u]
  if f and f.kind == kind then return f end
  if f then B.Undraw(u) end
  local plate = plateOf(u)
  if not plate then return nil end
  local look = B.LookIndex()
  local pk = kind .. look
  B.pool[pk] = B.pool[pk] or {}
  f = table.remove(B.pool[pk]) or B.NewSaber(kind, look)
  B.Place(f, plate)
  f:SetAlpha(1)
  f:Show()
  if f.pulse then f.pulse:Play() end
  B.marks[u] = f
  return f
end

--- Where a mark sits on a plate - the real one, or the options' preview plate (the same code, so the
--- preview cannot lie about where it lands).
--- Pin a sized mark to its plate: ON THEM (under the plate, centred on the body) or ABOVE the plate
--- (Arn, 14 Oct: "some people also like them at the top of the name plate - lets let them"). The
--- height setting nudges it from whichever spot is picked.
local function pin(f, plate, h)
  local RC = NS.Recap
  if B.Spot() == "above" then
    f:SetPoint("BOTTOM", plate, "TOP", 0, 2 + B.Lift())
  else
    f:SetPoint("CENTER", plate, "BOTTOM", 0, -2 - RC.MARK_H / 2 + B.Lift())
  end
end

function B.Place(f, plate)
  f:ClearAllPoints()
  -- ON THEM, like the rival crosshair (Arn, 14 Oct: "on them... like crosshairs"): under the plate,
  -- centred on the body - or above the plate, by choice
  if f.tag then
    local k = B.Size() / 100
    local w, h = math.floor(B.TAG[1] * k + 0.5), math.floor(B.TAG[2] * k + 0.5)
    pin(f, plate, h)
    f:SetSize(w, h)
    pcall(f.Fit, f, w, h)
  elseif f.x then
    -- centred in the rival crosshair's box (Arn, 14 Oct, seeing it fill the box: "perfect now 50%
    -- smaller"), and since the same night THE SIZE OF BiS HEALING'S TANK X (Arn: "lets make bis
    -- tools bg the same size as these") - fixed, not a share of the plate, so the two read as one
    local k = B.Size() / 100
    local w, h = math.floor(B.X_SIZE[1] * k + 0.5), math.floor(B.X_SIZE[2] * k + 0.5)
    pin(f, plate, h)
    f:SetSize(w, h)
    pcall(f.Fit, f, w, h)
  else
    f:SetPoint("TOP", plate, "BOTTOM", 0, -2)
    f:SetSize(B.SABER_W + 10, B.SABER_H)
  end
end

-- ---------------------------------------------------------------- the preview
-- Arn, 14 Oct: "can we add a window to the helper thing to preview the look" - then "maybe a full on
-- rollout 3d model of self with the marks on them, like how we did for bisgamba". Hover "mark look",
-- "mark size" or "mark height" and a panel rolls out beside the options window: YOU, twice, as 3D
-- models (BiSGamba's DressUpModel + SetUnit), a nameplate over each head, wearing the healer mark and
-- the killer mark exactly as B.Place puts them - redrawn on every step. 1.43:1, the BiSTheme standard.
B.PREVIEW_H = 230                   -- before the options window says how tall it is
B.PREVIEW_W = math.floor(B.PREVIEW_H * 1.43 + 0.5)
-- room over each fake nameplate for a mark set ABOVE it (Arn, 14 Oct: "in game this looks perfect
-- right over their name plate - in the preview its cut off"): a full tag at 200%, nudged 40 up
B.PREVIEW_HEADROOM = 100

--- One half of the panel: a model of you, a nameplate over its head, a word under it.
local function previewCell(pv, x, w, kind, h)
  local cell = CreateFrame("Frame", nil, pv)
  cell:SetPoint("TOPLEFT", pv, "TOPLEFT", x, -18)
  cell:SetSize(w, h - 22)
  local ok, m = pcall(CreateFrame, "DressUpModel", nil, cell)
  if ok and m then
    m:SetPoint("TOPLEFT", cell, "TOPLEFT", 0, -(B.PREVIEW_HEADROOM + 4))
    m:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", 0, 14)
    cell.model = m
  end
  -- the plate stands where a nameplate stands: over the head, with the headroom above it
  local p = CreateFrame("Frame", nil, cell)
  p:SetSize(64, 7)
  p:SetPoint("TOP", cell, "TOP", 0, -B.PREVIEW_HEADROOM)
  tex(p, "BACKGROUND", { 0.10, 0.10, 0.12 }, 0.9):SetAllPoints(p)
  local fill = tex(p, "ARTWORK", { 0.75, 0.18, 0.18 }, 1)
  fill:SetPoint("TOPLEFT", p, "TOPLEFT", 1, -1) fill:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -12, 1)
  p.name = p:CreateFontString(nil, "OVERLAY")
  pcall(p.name.SetFont, p.name, STANDARD_TEXT_FONT, 8, "")
  p.name:SetPoint("BOTTOM", p, "TOP", 0, 1)
  cell.plate = p
  cell.word = cell:CreateFontString(nil, "OVERLAY")
  pcall(cell.word.SetFont, cell.word, STANDARD_TEXT_FONT, 9, "")
  cell.word:SetPoint("BOTTOM", cell, "BOTTOM", 0, 2)
  cell.word:SetText(kind == "killer" and "their top killer" or "their healers")
  cell.kind = kind
  return cell
end

--- You, in the models: the live player; facing a little to the side, the way BiSGamba poses a seat.
--- THE REAL NAMEPLATE'S SIZE, on screen (Arn, 14 Oct: the preview's rival crosshair "look squished
--- cause name plates are smaller than in game ... the width is what's important" - and no drawing an
--- EllesmereUI plate: "some people dont have that installed"). Whatever nameplates the player runs,
--- the first plate seen is measured once, in screen pixels; the preview's fake plate takes that size.
--- Until one is seen, B.PLATE_PX - a typical plate.
B.PLATE_PX = { 150, 12 }
B.PREVIEW_BAR_H = 8
function B.NotePlate(unit)
  if B.platePx then return end
  local plate = plateOf(unit)
  if not plate then return end
  local ok, w, h, s = pcall(function() return plate:GetWidth(), plate:GetHeight(), plate:GetEffectiveScale() end)
  if not ok then return end
  w = plain(w)
  h = plain(h)
  s = plain(s)
  if type(w) == "number" and type(h) == "number" and type(s) == "number" and w > 20 then
    B.platePx = { w * s, math.max(6, math.min(30, h * s)) }
  end
end

--- The fake plate at the real one's size, in the preview's own units (it hangs off a scaled window).
function B.SizePreviewPlates()
  local pv = B.preview
  if not pv then return end
  local px = B.platePx or B.PLATE_PX
  local okS, s = pcall(pv.GetEffectiveScale, pv)
  s = (okS and type(s) == "number" and s > 0) and s or 1
  local okU, us = pcall(function() return UIParent:GetEffectiveScale() end)
  local base = B.platePx and 1 or ((okU and type(us) == "number" and us > 0) and us or 1)   -- the default is in UI units
  -- the WIDTH only: a plate frame is its whole clickable area, far taller than the bar you see (Arn's
  -- screenshot: a red slab). The real crosshair is sized off that same frame width, so the width is
  -- the one that must match; the bar is drawn the thin height a health bar is.
  local w, h = px[1] * base / s, B.PREVIEW_BAR_H
  for _, cell in ipairs({ pv.cellH, pv.cellK }) do
    local cw = cell.GetWidth and cell:GetWidth() or w
    cell.plate:SetSize(math.min(w, (type(cw) == "number" and cw > 0) and cw - 8 or w), h)
  end
end

function B.DressPreview()
  B.SizePreviewPlates()
  local pv = B.preview
  if not pv then return end
  local me = yes(UnitName, "player")
  for _, cell in ipairs({ pv.cellH, pv.cellK }) do
    cell.plate.name:SetText(type(me) == "string" and me or "you")
    local m = cell.model
    if m then
      pcall(m.SetUnit, m, "player")
      pcall(m.SetFacing, m, cell.kind == "killer" and -0.35 or 0.35)
      if m.SetPortraitZoom then pcall(m.SetPortraitZoom, m, 0) end
    end
  end
end

--- (Re)draw the two marks in the current look, size and height.
function B.PaintPreview()
  local pv = B.preview
  if not (pv and pv:IsShown()) then return end
  for _, m in pairs(pv.marks or {}) do m:Hide() end
  pv.marks = {}
  for _, m in pairs(pv.rmarks or {}) do m:Hide() end
  -- TWO MODES (Arn: "need the preview for pals and rivals"): the rivals & pals tool's marks
  if pv.mode == "rivals" then
    if NS.Recap and NS.Recap.PaintPreview then NS.Recap.PaintPreview(pv) end
    return
  end
  pv.cellH.word:SetText("their healers")
  pv.cellK.word:SetText("their top killer")
  pv.made = pv.made or {}
  local look = B.LookIndex()
  local okS, strata = pcall(pv.GetFrameStrata, pv)
  local okL, level = pcall(pv.GetFrameLevel, pv)
  for kind, cell in pairs({ healer = pv.cellH, killer = pv.cellK }) do
    local key = kind .. look
    local f = pv.made[key]
    if not f then
      f = B.NewSaber(kind, look)
      f:SetParent(cell)
      pv.made[key] = f
    end
    if okS and strata then f:SetFrameStrata(strata) end
    if okL and type(level) == "number" then f:SetFrameLevel(level + 5) end
    B.Place(f, cell.plate)
    f:Show()
    if f.pulse then f.pulse:Play() end
    pv.marks[kind] = f
  end
end

--- The roll-out, hung off the options window's right edge; shown while a mark setting is hovered.
function B.AttachPreview(opt)
  if not opt or B.preview then return B.preview end
  local pv = CreateFrame("Frame", "BiSToolsMarkPreview", opt)
  -- THE OPTIONS WINDOW'S OWN SIZE (Arn: "make the preview same aspect as our windows"): as tall as it,
  -- 1.43:1 - side by side they read as a pair. Never smaller than the room the headroom needs.
  local okH, oh = pcall(opt.GetHeight, opt)
  local H = (okH and type(oh) == "number" and oh >= B.PREVIEW_H) and math.floor(oh + 0.5) or B.PREVIEW_H
  local W = math.floor(H * 1.43 + 0.5)
  pv:SetSize(W, H)
  pv:SetPoint("TOPLEFT", opt, "TOPRIGHT", 4, 0)
  tex(pv, "BACKGROUND", { 0.05, 0.05, 0.08 }, 0.92):SetAllPoints(pv)
  local title = pv:CreateFontString(nil, "OVERLAY")
  pcall(title.SetFont, title, STANDARD_TEXT_FONT, 9, "")
  title:SetPoint("TOPLEFT", pv, "TOPLEFT", 6, -5)
  title:SetText(NS.T and NS.T.text and NS.T.text("accent", "BiS>") .. " the marks, on you" or "the marks, on you")
  local half = math.floor((W - 12) / 2)
  pv.cellH = previewCell(pv, 6, half, "healer", H)
  pv.cellK = previewCell(pv, 6 + half, half, "killer", H)
  pv:Hide()
  B.preview = pv
  local function hover(r)
    local mode = r.opt and ((r.opt.markPreview and "bg") or (r.opt.rivalPreview and "rivals"))
    if mode then
      pv.mode = mode
      if not pv:IsShown() then pv:Show() B.DressPreview() end
      B.PaintPreview()
    elseif pv:IsShown() then
      pv:Hide()
    end
  end
  for _, r in ipairs(opt.rows) do
    if r.HookScript then pcall(r.HookScript, r, "OnEnter", function() hover(r) end) end
    if r.GetChildren then
      for _, c in ipairs({ r:GetChildren() }) do
        if c.HookScript then pcall(c.HookScript, c, "OnEnter", function() hover(r) end) end
      end
    end
  end
  return pv
end

------------------------------------------------------------------- memory --
-- REMEMBERED ACROSS BATTLEGROUNDS (Arn, 13 Oct: "a data file that only keeps track of bgs so if we
-- go into a new bg it knows these people are healers and this guy is dangerous"). An addon cannot
-- write a file; its saved variables are the one it gets. So db.known[name] = { guid, healer = how
-- many battlegrounds they were a top-three healer in, killer = how many they were the top killer
-- in, last = when }. Counted once per battleground per player. In the next battleground a known
-- player is marked the moment their plate appears - before the scoreboard has numbers - dimmer and
-- steady, so "known from before" reads apart from "doing it right now". Not seen for B.FORGET_DAYS:
-- dropped; never more than B.KEEP players.
B.FORGET_DAYS = 30
B.KEEP = 300
B.counted = {}                     -- "name:h" / "name:k" already counted this battleground
B.onBoard = {}                     -- guid/name of every enemy this battleground's scoreboard has read
B.mvps = {}                        -- our side's best healer and best killer, by name -> "healer" / "killer"

function B.Known()
  local db = R:DBFor(R:Get("bg"))
  db.known = type(db.known) == "table" and db.known or {}
  return db.known
end

function B.Remember(heals, killer)
  local known = B.Known()
  local now = time and time() or 0
  local function note(s, what)
    if not (s and s.name) then return end
    local rec = known[s.name] or { healer = 0, killer = 0 }
    rec.guid = s.guid or rec.guid
    rec.last = now
    if not B.counted[s.name .. ":" .. what] then
      B.counted[s.name .. ":" .. what] = true
      rec[what == "h" and "healer" or "killer"] = (rec[what == "h" and "healer" or "killer"] or 0) + 1
    end
    known[s.name] = rec
  end
  for i = 1, math.min(B.TOP_HEALERS, #heals) do note(heals[i], "h") end
  note(killer, "k")
end

--- Old entries out, and never more than B.KEEP (the longest unseen go first).
function B.Prune()
  local known = B.Known()
  local now = time and time() or 0
  local list = {}
  for name, rec in pairs(known) do
    if now - (rec.last or 0) > B.FORGET_DAYS * 86400 then known[name] = nil
    else list[#list + 1] = { name = name, last = rec.last or 0 } end
  end
  if #list > B.KEEP then
    table.sort(list, function(a, b) return a.last < b.last end)
    for i = 1, #list - B.KEEP do known[list[i].name] = nil end
  end
end

--- A remembered player on this plate: their record, or nil.
function B.Recall(guid, name)
  local known = B.Known()
  local rec = B.Look(known, name)
  if rec then return rec end
  if guid then
    for _, rec in pairs(known) do if rec.guid == guid then return rec end end
  end
  return nil
end

--- Who is on this plate: "killer", "healer" or nil - and whether that is remembered, not live.
--- Live (this battleground's scoreboard) first; then what earlier battlegrounds taught.
--- A plate's name, as the scoreboard writes it. Forever names have two parts ("Swig Xd"): the board
--- has both, a plate's UnitName may give only "Swig" (14 Oct: the right healers read, NO saber).
--- GetUnitName(u, false) carries the surname (as the rival tool learned); else the first part.
function B.PlateName(u)
  local full = yes(GetUnitName, u, false)
  if type(full) == "string" and full ~= "" then return bare(full) end
  return F.Name(u)
end

--- Look a name up in a table keyed by board names: exact, else a one-word name against the first
--- word of each key (cost: only for a one-word name, and these tables are a match's players).
function B.Look(tbl, name)
  if not name then return nil end
  if tbl[name] then return tbl[name] end
  if name:find(" ", 1, true) then return nil end
  for key, v in pairs(tbl) do
    if type(key) == "string" and key:match("^(%S+)") == name then return v end
  end
  return nil
end

local function sameName(a, b)
  if not (a and b) then return false end
  if a == b then return true end
  return a:match("^(%S+)") == b or b:match("^(%S+)") == a
end

function B.Which(u)
  local guid = yes(UnitGUID, u)
  local name = B.PlateName(u)
  -- OUR MVPs (Arn, 14 Oct: "can we do 2 for friendly players and just mark them MVP" - "best healer
  -- and best killer"): a friend the board puts first in healing or in kills
  if name and next(B.mvps) and B.Look(B.mvps, name) and yes(UnitCanAttack, "player", u) ~= true then return "mvp" end
  local k = B.killer
  if k and ((guid and k.guid == guid) or sameName(k.name, name)) then return "killer" end
  if (guid and B.healers[guid]) or B.Look(B.healers, name) then return "healer" end
  if not (guid or name) then return nil end
  -- the memory is for players this battleground's scoreboard has not judged yet: once the live
  -- scoreboard has them, IT decides (a healer who fell out of the top three loses the saber)
  if (guid and B.onBoard[guid]) or B.Look(B.onBoard, name) then return nil end
  -- an enemy only: a remembered name on our own side is somebody we play with now
  if yes(UnitCanAttack, "player", u) ~= true then return nil end
  local rec = B.Recall(guid, name)
  if rec then
    if (rec.killer or 0) > 0 then return "killer", true end
    if (rec.healer or 0) > 0 then return "healer", true end
  end
  return nil
end

function B.On() return R:Enabled("bg") and B.inBG end

B.REMEMBERED_ALPHA = 0.55

function B.Paint(u)
  if not B.plates[u] then return end
  local kind, remembered
  if B.On() then kind, remembered = B.Which(u) end
  if not kind then return B.Undraw(u) end
  local f = B.Draw(u, kind)
  if not f then return end
  -- remembered: dimmer and steady; live: full and humming
  if remembered then
    if f.pulse then f.pulse:Stop() end
    f:SetAlpha(B.REMEMBERED_ALPHA)
  else
    f:SetAlpha(1)
    if f.pulse and not f.pulse:IsPlaying() then f.pulse:Play() end
  end
  f.remembered = remembered and true or false
end

function B.PaintAll() for u in pairs(B.plates) do B.Paint(u) end end

--- The marks' size (% of B.X_SIZE) and lift (px up from the middle of the crosshair's box).
function B.Size(db)
  db = db or R:DBFor(R:Get("bg"))
  local v = tonumber(db.size)
  return v and math.max(50, math.min(200, v)) or 100
end
--- Where the marks sit: "on" them (the default) or "above" the nameplate.
function B.Spot(db)
  db = db or R:DBFor(R:Get("bg"))
  return db.spot == "above" and "above" or "on"
end

function B.Lift(db)
  db = db or R:DBFor(R:Get("bg"))
  local v = tonumber(db.lift)
  return v and math.max(-40, math.min(40, v)) or 0
end

--- A setting changed: every mark drawn again at the new size and height.
function B.Redraw()
  for u in pairs(B.marks) do B.Undraw(u) end
  B.PaintAll()
end

function B.ClearAll()
  for u in pairs(B.marks) do B.Undraw(u) end
  B.healers, B.killer, B.mvps = {}, nil, {}
end

------------------------------------------------------------------ the loop --

--- In a battleground: ask for the scoreboard now and every B.EVERY seconds. Out of one: stop.
--- The match, kept across a /reload (Arn, 14 Oct: "fix the reload double count" - a reload is a
--- fresh load, and every healer was counted twice). A match = its zone + when it started (now -
--- the run time), within a minute. The same match: its "already counted" list comes back.
function B.SameMatch()
  local db = R:DBFor(R:Get("bg"))
  local run = yes(GetBattlefieldInstanceRunTime)
  local start = (type(run) == "number" and run > 0) and ((time and time() or 0) - math.floor(run / 1000)) or nil
  local zone = yes(GetRealZoneText)
  local m = db.match
  if start and type(m) == "table" and m.zone == zone and type(m.start) == "number"
     and math.abs(m.start - start) < 60 and type(m.counted) == "table" then
    return m.counted
  end
  local counted = {}
  db.match = start and { zone = zone, start = start, counted = counted } or nil
  return counted
end

function B.Watch()
  local ok, inside, kind = pcall(IsInInstance)
  local was = B.inBG
  -- a battleground only: an arena is 2v2/3v3, nobody needs a scoreboard to find the healer there
  B.inBG = ok and plain(inside) == true and plain(kind) == "pvp"
  if B.inBG and not was then
    B.counted = B.SameMatch()         -- a new battleground: everyone may be counted once again
    B.healers, B.killer = {}, nil     -- and nothing live yet: what is drawn now is remembered
    B.mvps = {}
    B.onBoard = {}
    B.ended = nil
    B.Prune()
  end
  if B.On() then
    if not B.ticker then
      B.ticker = C_Timer.NewTicker(B.EVERY, function() B.Ask() end)
    end
    B.Ask()
  else
    if B.ticker then B.ticker:Cancel() B.ticker = nil end
    B.ClearAll()
  end
end

function B.Ask()
  if RequestBattlefieldScoreData then pcall(RequestBattlefieldScoreData) end
end

function B.OnScores()
  if not B.On() then return end
  local scores, note = B.Scores()
  for _, sc in ipairs(scores) do
    if sc.enemy then
      if sc.guid then B.onBoard[sc.guid] = true end
      if sc.name then B.onBoard[sc.name] = true end
    end
  end
  if note then
    -- hidden numbers (Forever, mid-match): by the board's order instead; between reads the last stays
    if not B.ReadOrder() and not (B.read and B.read.byOrder) then
      B.healers, B.killer = {}, nil
      local enemies = 0
      for _, sc in ipairs(scores) do if sc.enemy then enemies = enemies + 1 end end
      B.read = { enemies = enemies, heals = {}, note = (B.read and B.read.wait) or note }
    end
  else
    B.healers, B.killer = B.Pick(scores)
    B.Remember(B.read.heals or {}, B.killer)
  end
  B.PaintAll()
  B.ApplyMacro()
  B.Button()
end
-- (The match-end probe that stood here, 14 Oct, answered its question - the board DOES unlock when
-- a match ends, and B.OnScores reads it then - and came out before 0.7.0: it printed a scoreboard
-- row at the end of every battleground.)

function B.OnEvent(_, event, unit)
  if event == "NAME_PLATE_UNIT_ADDED" then
    if type(unit) == "string" and plain(unit) then
      B.plates[unit] = true
      B.Paint(unit)
      B.NotePlate(unit)
    end
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    if type(unit) == "string" and plain(unit) then B.Undraw(unit) B.plates[unit] = nil end
  elseif event == "UPDATE_BATTLEFIELD_SCORE" then
    B.OnScores()
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    B.Watch()
  elseif event == "PLAYER_REGEN_ENABLED" then
    if B.On() then B.ApplyMacro() end
  end
end

-- registered at load, never from a timer; an event this client does not know is pcalled
B.frame = CreateFrame("Frame")
for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UPDATE_BATTLEFIELD_SCORE",
                     "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED" }) do
  pcall(B.frame.RegisterEvent, B.frame, e)
end
B.frame:SetScript("OnEvent", B.OnEvent)

function B.Why()
  local r = B.read or {}
  NS.Print("bg: %s; %s; scoreboard every %d s", R:Enabled("bg") and "on" or "off",
    B.inBG and "in a battleground" or "not in a battleground - nothing is read", B.EVERY)
  B.WhyKnown()
  if not B.inBG then return end
  local heals = {}
  for i, s in ipairs(r.heals or {}) do
    if i > B.TOP_HEALERS then break end
    heals[#heals + 1] = ("%s %s"):format(tostring(s.name or "?"), s.heal and tostring(s.heal) or ("#" .. i))
  end
  DEFAULT_CHAT_FRAME:AddMessage("  enemies on the scoreboard: " .. tostring(r.enemies or 0)
    .. (r.note and ("  (" .. r.note .. ")") or ""))
  DEFAULT_CHAT_FRAME:AddMessage("  top healers (saber): " .. (#heals > 0 and table.concat(heals, ", ") or "none read"))
  DEFAULT_CHAT_FRAME:AddMessage("  top killer (red crosshair): " .. (r.killer and (r.killer.kb
    and ("%s, %d killing blows"):format(tostring(r.killer.name or "?"), r.killer.kb)
    or (tostring(r.killer.name or "?") .. ", most killing blows")) or "none read"))
  local marked, recalled = 0, 0
  for _, f in pairs(B.marks) do marked = marked + 1 if f.remembered then recalled = recalled + 1 end end
  DEFAULT_CHAT_FRAME:AddMessage(("  marked on screen now: %d (%d remembered from earlier battlegrounds)"):format(marked, recalled))
  if yes(UnitExists, "target") == true then
    local kind, rem = B.Which("target")
    DEFAULT_CHAT_FRAME:AddMessage(("  your target reads as \"%s\" (plate %s): %s"):format(tostring(B.PlateName("target") or "?"),
      tostring(yes(UnitName, "target") or "?"), kind and (kind .. (rem and ", remembered" or "")) or "not marked"))
  end
end

--- /bist bg raw: ONE enemy row of the scoreboard, every field as the game hands it over - a value,
--- or HIDDEN. Arn's first battleground, 14 Oct: "30 row(s) with the numbers hidden" - and a missing
--- field (Forever naming it differently) and a hidden one read alike in B.Scores. This tells them
--- apart, and shows what the old positional GetBattlefieldScore answers for the same row.
function B.Raw()
  local G = C_PvP and C_PvP.GetScoreInfo
  local n = yes(GetNumBattlefieldScores) or 0
  if not (G and type(n) == "number" and n > 0) then return NS.Print("bg raw: no scoreboard rows (in a battleground? /bist bg why)") end
  local mine = yes(UnitFactionGroup, "player")
  local myFaction = mine == "Horde" and 0 or (mine == "Alliance" and 1 or nil)
  local pick, info
  for i = 1, n do
    local ok, row = pcall(G, i)
    if ok and type(row) == "table" then
      local f = field(row, "faction")
      if pick == nil or (type(f) == "number" and f ~= myFaction) then pick, info = i, row end
      if type(f) == "number" and f ~= myFaction then break end
    end
  end
  if not info then return NS.Print("bg raw: C_PvP.GetScoreInfo gave no table for any of %d rows", n) end
  local function show(v)
    local okS, s = pcall(issecretvalue or function() return false end, v)
    if not okS or s then return "HIDDEN" end
    if type(v) == "table" then return "{table}" end
    return tostring(v)
  end
  local keys = {}
  local okP = pcall(function() for k in pairs(info) do keys[#keys + 1] = tostring(k) end end)
  table.sort(keys)
  NS.Print("bg raw: scoreboard row %d of %d, C_PvP.GetScoreInfo%s:", pick, n, okP and "" or " (its keys could not be listed)")
  local line = {}
  for _, k in ipairs(keys) do
    local okV, v = pcall(function() return info[k] end)
    line[#line + 1] = k .. "=" .. (okV and show(v) or "refused")
    if #line == 6 then DEFAULT_CHAT_FRAME:AddMessage("  " .. table.concat(line, "  ")) line = {} end
  end
  if #line > 0 then DEFAULT_CHAT_FRAME:AddMessage("  " .. table.concat(line, "  ")) end
  if GetBattlefieldScore then
    local res = { pcall(GetBattlefieldScore, pick) }
    local out = {}
    for i = 2, math.min(#res, 17) do out[#out + 1] = (i - 1) .. ":" .. show(res[i]) end
    DEFAULT_CHAT_FRAME:AddMessage("  GetBattlefieldScore(" .. pick .. "): " .. (res[1] and table.concat(out, " ") or "refused"))
  end
end

--- PROBE /bist bg sort [healing|kills|...]: Arn's idea, 14 Oct - "what about we can click the top
--- heals". The numbers are hidden, the names are not: ask the game to SORT the board by a column,
--- then read the names in row order. Printed now and again a second later, enemies marked "E".
function B.SortProbe(col)
  col = (col and col ~= "") and col or "healing"
  if not SortBattlefieldScoreData then return NS.Print("bg sort: this client has no SortBattlefieldScoreData") end
  local okS, err = pcall(SortBattlefieldScoreData, col)
  if not okS then return NS.Print("bg sort: refused (%s)", tostring(err)) end
  local mine = yes(UnitFactionGroup, "player")
  local myFaction = mine == "Horde" and 0 or (mine == "Alliance" and 1 or nil)
  local function list(when)
    local G = C_PvP and C_PvP.GetScoreInfo
    local n = yes(GetNumBattlefieldScores) or 0
    local out = {}
    for i = 1, math.min(type(n) == "number" and n or 0, 10) do
      local ok, row = pcall(G, i)
      local name = ok and type(row) == "table" and plain(field(row, "name"))
      local f = ok and type(row) == "table" and field(row, "faction")
      out[#out + 1] = i .. "." .. tostring(name or "?") .. ((type(f) == "number" and f ~= myFaction) and " E" or "")
    end
    NS.Print("bg sort %s, %s: %s", col, when, table.concat(out, ", "))
  end
  list("now")
  C_Timer.After(1, function() list("1 s later") end)
end

--- The memory, read out: how many healers and dangerous players it knows.
function B.WhyKnown()
  local h, k, n = 0, 0, 0
  for _, rec in pairs(B.Known()) do
    n = n + 1
    if (rec.healer or 0) > 0 then h = h + 1 end
    if (rec.killer or 0) > 0 then k = k + 1 end
  end
  DEFAULT_CHAT_FRAME:AddMessage(("  remembered from earlier battlegrounds: %d players - %d healers, %d dangerous"):format(n, h, k))
end

R:Register({
  name = "bg",
  desc = "battlegrounds: crossed sabers on their top 3 healers (white) and top killer (red)",
  usage = "/bist bg [why | mark | forget <name> | clear]",
  defaults = { known = {} },
  -- the marks, to taste (Arn, 14 Oct: "we add the stepper if they want to change the marks")
  options = {
    -- a stepper through names (Arn: "not all want x")
    { kind = "step", label = "mark look", markPreview = true, help = "The shape on their healers (white) and top killer (red): X, saber, arrow, diamond, corners, or tag - a white box reading >Healer< or >Killer<.", min = 1, max = #B.LOOKS, step = 1,
      get = function(db) return B.LookIndex(db) end,
      set = function(db, v) db.look = v B.Redraw() B.PaintPreview() end,
      show = function(db) return B.LOOKS[B.LookIndex(db)].word end },
    { kind = "step", label = "mark size", markPreview = true, help = "How big the battleground marks are.", min = 50, max = 200, step = 10,
      get = function(db) return B.Size(db) end,
      set = function(db, v) db.size = v B.Redraw() B.PaintPreview() end,
      show = function(db) return B.Size(db) .. "%" end },
    -- (Arn, 14 Oct: "some people also like them at the top of the name plate - lets let them"; at 40 up
    -- the tag sat ON the plate, over the name)
    { kind = "seg", label = "mark spot", markPreview = true, values = { "on", "above" },
      help = "Where the marks sit: on - on them, on the body under the nameplate; above - on top of the nameplate, over the name.",
      get = function(db) return B.Spot(db) == "above" and "above" or "on" end,
      set = function(db, v) db.spot = (v == "above") and "above" or nil B.Redraw() B.PaintPreview() end },
    { kind = "step", label = "mark height", markPreview = true, help = "Nudges the marks up or down from their spot.", min = -40, max = 40, step = 5,
      get = function(db) return B.Lift(db) end,
      set = function(db, v) db.lift = v B.Redraw() B.PaintPreview() end,
      show = function(db)
        local v = B.Lift(db)
        return v == 0 and (B.Spot(db) == "above" and "on top" or "on them") or (v > 0 and (v .. " up") or (-v .. " down"))
      end },
  },
  OnInit = function() end,
  OnLogin = function() B.Watch() end,
  OnEnable = function() B.Watch() end,
  OnDisable = function() B.Watch() end,
  OnSlash = function(_, _, args)
    args = args or ""
    local who = args:match("^forget%s+(.+)$")
    if who then
      local known = B.Known()
      local key
      for name in pairs(known) do if name:lower() == who:lower() then key = name end end
      if not key then return NS.Print("bg: nobody called %s is remembered", who) end
      known[key] = nil
      B.PaintAll()
      return NS.Print("bg: %s forgotten", key)
    end
    if args:lower() == "raw" then return B.Raw() end
    if args:lower() == "board" then return B.BoardWhy() end
    if args:lower() == "mark" then return B.Mark() end
    local col = args:lower():match("^sort%s*(%S*)$")
    if col then return B.SortProbe(col) end
    if args:lower() == "clear" then
      local db = R:DBFor(R:Get("bg"))
      db.known = {}
      B.PaintAll()
      return NS.Print("bg: everyone forgotten")
    end
    B.Why()
  end,
})
