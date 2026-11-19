--[[
  BiSTools / Tools / Combo.lua - THE IMBUE + TOTEM COMBO (17 Nov 2026, Arn: "after fight want to see what imbue and
  totem combo is best" - picked C of https://claude.ai/artifact/NgaCjSTrXU5HcZ6qqtFWee: a card after each fight, the
  ranked list behind it).

  THE PROBE first (/bist combo probe, kept), answered live the same day: GetWeaponEnchantInfo is plain (the main hand's
  enchant id - 284 for Windfury Weapon rank 2); GetTotemInfo answers true, "" with nothing down (a fight's totems still
  unprobed - so they are ALSO caught by name from your own casts); Blizzard's damage meter (C_DamageMeter) keeps the last
  30 fights, each {sessionID, name = the mob, durationSeconds}; a fight's sources carry isLocalPlayer, totalAmount,
  amountPerSecond; YOUR breakdown (GetCombatSessionSourceFromID) carries combatSpells {spellID, totalAmount}. All plain
  once the fight is over.

  THE RECORDER (only while the tool is on): at the pull, your imbue and the totems already standing; in the fight, every
  totem you drop (PLAYER_TOTEM_UPDATE's name, else the name of your own cast); C.READ_WAIT s after the fight, the game's
  newest fight - if it is a new one - read once: its length, your damage, your Windfury / Flametongue share. One record
  in db.fights (at most C.KEEP). Only the totems that change damage count toward a combo (C.TOTEMS); the imbue by kind,
  not rank (Windfury rank 2 and 3 are one Windfury).
  THE RANKING: fights at least db.min s long (C.MIN 10), grouped by combo, damage over time (a long fight weighs more).
  THE CARD after each fight (db.card, on with the tool): the combo, your DPS, its place in the ranking; fades after
  C.CARD_FOR s, holds while the mouse is on it; a click opens THE LIST (/bist combo): every combo, fights, DPS; a click on
  a row shows its last fights. Nothing ticks while nothing shows.
]]
local _, NS = ...
local R = NS.Registry
local C = {}
NS.Combo = C
local function plain(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

-- (C.MIN 0, 17 Nov - Arn: "fight under 10 sec should count because lucky procs means it can kill things fast": every
-- fight counts by default; damage over TIME already weighs a short one by its few seconds. The setting stays.)
C.MIN, C.KEEP, C.READ_WAIT, C.CARD_FOR, C.CARD_FADE = 0, 300, 1.5, 8, 1
C.W, C.H, C.ROWS, C.ROW = 330, 320, 7, 16
-- THE SIZE AND THE SWITCHES (17 Nov 2026, Arn: "we forgot the rule of letting us resize the window that we did with bis
-- healing deck" - the family rule: every window a switches panel with its toggles, width and height, RESET): the list's
-- SET button opens the panel over its lower half; width / height in C.STEP px steps between the bounds, kept in
-- db.w / db.h; the rows follow the height. RESET puts the look back (never your fights).
C.W_MIN, C.W_MAX, C.H_MIN, C.H_MAX, C.STEP = 300, 560, 280, 520, 20   -- (17 Nov: taller for the number boxes)
-- the imbues by enchant id (Classic's numbers; a cast of yours teaches the rest - db.imbueNames)
C.IMBUE_IDS = {
  [283] = "Windfury Weapon", [284] = "Windfury Weapon", [525] = "Windfury Weapon", [1669] = "Windfury Weapon",
  [5] = "Flametongue Weapon", [4] = "Flametongue Weapon", [3] = "Flametongue Weapon", [523] = "Flametongue Weapon",
  [1665] = "Flametongue Weapon", [1666] = "Flametongue Weapon",
  [29] = "Rockbiter Weapon", [6] = "Rockbiter Weapon", [1] = "Rockbiter Weapon", [503] = "Rockbiter Weapon",
  [1663] = "Rockbiter Weapon", [683] = "Rockbiter Weapon", [1664] = "Rockbiter Weapon",
  [2] = "Frostbrand Weapon", [12] = "Frostbrand Weapon", [524] = "Frostbrand Weapon", [1667] = "Frostbrand Weapon",
  [1668] = "Frostbrand Weapon",
}
C.IMBUE_SHORT = { ["Windfury Weapon"] = "WF", ["Flametongue Weapon"] = "FT", ["Rockbiter Weapon"] = "RB", ["Frostbrand Weapon"] = "FB" }
-- the totems that change your damage, and their short words (the rest - healing, mana, cleansing - never split a combo)
C.TOTEMS = {
  ["Strength of Earth Totem"] = "SoE", ["Grace of Air Totem"] = "GoA", ["Windfury Totem"] = "WF totem",
  ["Flametongue Totem"] = "FT totem", ["Searing Totem"] = "Searing", ["Magma Totem"] = "Magma", ["Fire Nova Totem"] = "Nova",
}

-- THE COLUMNS (17 Nov 2026, Arn's list: "can you make the imbue and totems line up"): the imbue, then each totem under its
-- element - fire, earth, air - two of one element (they stack on Forever now) joined with "+"; nothing there = "-".
C.ELEMENT = { ["Strength of Earth Totem"] = "earth", ["Grace of Air Totem"] = "air", ["Windfury Totem"] = "air",
  ["Flametongue Totem"] = "fire", ["Searing Totem"] = "fire", ["Magma Totem"] = "fire", ["Fire Nova Totem"] = "fire" }
C.COL_WORD = { ["Strength of Earth Totem"] = "SoE", ["Grace of Air Totem"] = "GoA", ["Windfury Totem"] = "WF",
  ["Flametongue Totem"] = "FT", ["Searing Totem"] = "Searing", ["Magma Totem"] = "Magma", ["Fire Nova Totem"] = "Nova" }
C.COLS = { "imbue", "fire", "earth", "air" }
C.COL_SHARE = { imbue = 0.22, fire = 0.27, earth = 0.21, air = 0.30 }
--[[ ICONS, NOT LETTERS (17 Nov 2026, Arn: "in bis combo can you put icons instead of wf ft soe goa"): every imbue and
  totem is drawn as its spell's icon - the client's own texture for the spell by name (C_Spell.GetSpellTexture), else
  the classic icon file below (a spell you have not learned yet). Hover a row, or the card, for the names. ]]
C.ICON_FILES = {
  ["Windfury Weapon"] = "Interface\\Icons\\Spell_Nature_Cyclone", ["Flametongue Weapon"] = "Interface\\Icons\\Spell_Fire_FlameTounge",
  ["Rockbiter Weapon"] = "Interface\\Icons\\Spell_Nature_RockBiter", ["Frostbrand Weapon"] = "Interface\\Icons\\Spell_Frost_FrostBrand",
  ["Strength of Earth Totem"] = "Interface\\Icons\\Spell_Nature_EarthBindTotem", ["Grace of Air Totem"] = "Interface\\Icons\\Spell_Nature_InvisibilityTotem",
  ["Windfury Totem"] = "Interface\\Icons\\Spell_Nature_Windfury", ["Flametongue Totem"] = "Interface\\Icons\\Spell_Nature_GuardianWard",
  ["Searing Totem"] = "Interface\\Icons\\Spell_Fire_SearingTotem", ["Magma Totem"] = "Interface\\Icons\\Spell_Fire_SelfDestruct",
  ["Fire Nova Totem"] = "Interface\\Icons\\Spell_Fire_SealOfFire",
}
C.iconCache = {}
function C.IconFor(name)
  if type(name) ~= "string" then return nil end
  local hit = C.iconCache[name]
  if hit then return hit end
  local tex
  if C_Spell and C_Spell.GetSpellTexture then
    local ok, t = pcall(C_Spell.GetSpellTexture, name)
    if ok then t = plain(t) if t ~= nil and t ~= 0 and t ~= "" then tex = t end end
  end
  tex = tex or C.ICON_FILES[name]
  if tex then C.iconCache[name] = tex end
  return tex
end
--[[ CLICK AN ICON TO CAST IT (17 Nov 2026, Arn, of the icons: "maybe we can make these buttons clickable?"): every icon
  (list, TRY NEXT, card) is a plain button; pointing at one out of a fight moves ONE secure button (BiSToolsComboCast,
  type "spell") over it with that spell - a click puts the imbue on your weapon or drops the totem. Nothing secure is
  written in a fight: there the icons only tell their names. The secure button goes away at the pull and when the
  mouse leaves it. ]]
local function fighting() return InCombatLockdown and InCombatLockdown() and true or false end
function C.IconButton(parent, size)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  b.tex = b:CreateTexture(nil, "ARTWORK")
  b.tex:SetAllPoints(b)
  if b.tex.SetTexCoord then b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  b.SetTexture = function(self, t) self.tex:SetTexture(t) end
  b:SetScript("OnEnter", function(self) C.IconEnter(self) end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  b:Hide()
  return b
end
function C.CastButton()
  if C.cast then return C.cast end
  local c = CreateFrame("Button", "BiSToolsComboCast", UIParent, "SecureActionButtonTemplate")
  c:RegisterForClicks("AnyUp", "AnyDown")
  c:SetFrameStrata("FULLSCREEN_DIALOG")
  c:SetAttribute("type", "spell")
  c.hl = c:CreateTexture(nil, "OVERLAY")
  c.hl:SetAllPoints(c)
  c.hl:SetColorTexture(1, 1, 1, 0.25)
  c:SetScript("OnEnter", function(self) C.CastTip(self) end)
  -- (SET DECK sat under it: the imbue is cast by the click, the totems go to the deck right after - C.AimDeck)
  c:SetScript("PostClick", function(self) if self.deckTotems then C.SendDeck(self.deckTotems) end end)
  c:SetScript("OnLeave", function(self)
    if GameTooltip then GameTooltip:Hide() end
    C.CastAway()
  end)
  c:Hide()
  C.cast = c
  return c
end
--- The cast button put away AND let go of the icon it sat on (17 Nov 2026, Arn's BugSack: "BiSTools tried to call the
--- protected function BiSToolsCombo:StartSizing()" - a secure button anchored to an icon, even hidden, makes the list a
--- protected frame in a fight). Out of a fight only - at PLAYER_REGEN_DISABLED the lockdown has not started yet.
function C.CastAway()
  local c = C.cast
  if not c or fighting() then return end
  c:Hide()
  c:ClearAllPoints()
  c:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -200, -200)
  c.spell, c.deckTotems = nil, nil
end
function C.CastTip(c)
  if not (GameTooltip and c.spell) then return end
  GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
  GameTooltip:AddLine(c.spell, 1, 1, 1)
  GameTooltip:AddLine(c.spell:find("Weapon", 1, true) and "click: put it on your weapon" or "click: drop it", 0.4, 1, 0.4)
  if c.deckTotems then
    GameTooltip:AddLine("and these totems onto your BiS Healing deck:", 1, 0.82, 0, true)
    for _, n in ipairs(c.deckTotems) do GameTooltip:AddLine(n, 0.8, 0.8, 0.8) end
  end
  GameTooltip:Show()
end
--[[ SET DECK CASTS THE IMBUE TOO (18 Nov 2026, Arn: "when they click SET DECK it casts the imbue on that test strip and sends
  the deck to BiS Healing"): pointing at SET DECK out of a fight puts the secure cast button over it with the suggestion's
  imbue; the click casts it (the game's own click - an addon may not cast any other way) and PostClick sends the totems.
  With no imbue to cast (none known, or a fight), SET DECK's own click just sends the totems. ]]
function C.AimDeck(b, imbue, totems)
  if fighting() or not (imbue and C.Knows(imbue)) then return false end
  local c = C.CastButton()
  c:ClearAllPoints()
  c:SetAllPoints(b)
  c:SetAttribute("spell", imbue)
  c.spell, c.deckTotems = imbue, totems
  c:Show()
  C.CastTip(c)
  return true
end
--- The mouse on an icon: out of a fight, the secure cast button over it with its spell; in one, its name.
function C.IconEnter(b)
  if not b.name then return end
  if fighting() or not C.Knows(b.name) then
    if GameTooltip then
      GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
      GameTooltip:AddLine(b.name, 1, 1, 1)
      GameTooltip:AddLine(fighting() and "out of a fight: click to cast" or "not known yet", 0.6, 0.6, 0.6)
      GameTooltip:Show()
    end
    return
  end
  local c = C.CastButton()
  c:ClearAllPoints()
  c:SetAllPoints(b)
  c:SetAttribute("spell", b.name)
  c.spell = b.name
  c:Show()
  C.CastTip(c)
end
--- The names in each column: { imbue = { name }, fire = { ... }, earth = { ... }, air = { ... } }.
function C.CellNames(imbue, totems)
  local out = { imbue = {}, fire = {}, earth = {}, air = {} }
  if imbue then out.imbue[1] = imbue end
  for _, name in ipairs(totems or {}) do
    local el = C.ELEMENT[name]
    if el then out[el][#out[el] + 1] = name end
  end
  for _, list in pairs(out) do table.sort(list) end
  return out
end
--- A combo's four cells: imbue, fire, earth, air.
function C.Cells(imbue, totems)
  local out = { imbue = (imbue and (C.IMBUE_SHORT[imbue] or imbue)) or "-" }
  local by = { fire = {}, earth = {}, air = {} }
  for _, name in ipairs(totems or {}) do
    local el = C.ELEMENT[name]
    if el then by[el][#by[el] + 1] = C.COL_WORD[name] or name end
  end
  for el, list in pairs(by) do table.sort(list) out[el] = #list > 0 and table.concat(list, "+") or "-" end
  return out
end


local function say(fmt, ...) NS.Print(fmt, ...) end
local function F() return NS.Farm end
-- (the tool's own saved table, always - never a throwaway one when the tool had not been handed it yet)
local function db()
  if not C.db and R.DBFor and R.Get and R:Get("combo") then C.db = R:DBFor(R:Get("combo")) end
  return C.db or {}
end

--- A spell's name without its rank ("Strength of Earth Totem III", "... (Rank 3)" -> "Strength of Earth Totem").
function C.Base(name)
  if type(name) ~= "string" then return nil end
  name = name:gsub("%s*%(Rank %d+%)", ""):gsub("%s+Rank %d+$", ""):gsub("%s+[IVX]+$", "")
  return name
end
--- Your main hand's imbue by kind ("Windfury Weapon"), or nil.
function C.ImbueNow()
  if not GetWeaponEnchantInfo then return nil end
  local ok, has, _, _, id = pcall(GetWeaponEnchantInfo)
  if not ok then return nil end
  has = plain(has)
  id = plain(id)
  if not has or type(id) ~= "number" then return nil end
  local learned = db().imbueNames and db().imbueNames[id]
  return learned or C.IMBUE_IDS[id] or ("imbue " .. id)
end
--- The damage totems standing now (plain names only), into the set `into`.
function C.ScanTotems(into)
  if not GetTotemInfo then return into end
  for slot = 1, 4 do
    local ok, have, name = pcall(GetTotemInfo, slot)
    name = ok and plain(have) and C.Base(plain(name)) or nil
    if name and name ~= "" and C.TOTEMS[name] then into[name] = true end
  end
  return into
end
--- A combo's words: the imbue's short word, then the totems' in order ("WF · GoA · SoE").
function C.Label(imbue, totems)
  local parts = { (imbue and (C.IMBUE_SHORT[imbue] or imbue)) or "no imbue" }
  local t = {}
  for name in pairs(totems or {}) do t[#t + 1] = C.TOTEMS[name] or name end
  table.sort(t)
  for _, w in ipairs(t) do parts[#parts + 1] = w end
  return table.concat(parts, " · ")
end

-- ---------------------------------------------------------------- the recorder
--[[ ONLY THE TIME YOU SWING (17 Nov 2026, Arn: "the dps takes all the fight into account, sometimes these mobs run away
  and it hurts a dps number ... only consider the active time of melee attacks"). Every C.ACTIVE_EVERY s of the fight
  (one ticker, only in a fight with the tool on) counts toward the ACTIVE time while your auto-attack is on
  (PLAYER_ENTER_COMBAT / _LEAVE_COMBAT, C_Spell.IsCurrentSpell 6603 at the pull) AND the target is in melee reach as far
  as the game says (C_Spell.IsSpellInRange of Auto Attack, else CheckInteractDistance 3; an answer it will not give =
  counted, a plain "no" = not). A fleeing mob, a run back, standing still: none of it. DPS = damage / active time when
  there was at least C.ACTIVE_MIN s of it, else the fight's length; the record says which (rec.active, rec.how). ]]
C.ACTIVE_EVERY, C.ACTIVE_MIN, C.AUTO_ATTACK = 0.25, 2, 6603
--[[ MELEE REACH, THE HONEST WAY (17 Nov 2026, Arn: "some of those were not in range and it said I was" - a fight of 22 s
  read 19 s "in reach"). CheckInteractDistance 3 is the DUEL distance, about 10 yd - a mob that ran a few steps still
  "counted". The order now: a MELEE spell you know (C.MELEE_SPELLS: Stormstrike, Lava Lash, Primal Strike - their range
  is melee), then Auto Attack itself, then the 10 yd check only as the last word (C.reachHow says which decided);
  /bist combo reach prints every check's answer on your target, to settle which one tells the truth on Forever. ]]
C.MELEE_SPELLS = { "Stormstrike", "Lava Lash", "Primal Strike" }
local function spellReach(spell)
  if not (C_Spell and C_Spell.IsSpellInRange) then return nil end
  local ok, r = pcall(C_Spell.IsSpellInRange, spell, "target")
  if ok then r = plain(r) else r = nil end              -- (never `ok and plain(r) or nil`: a plain false would turn nil)
  if r == true or r == false then return r end
  if r == 1 or r == 0 then return r == 1 end
  return nil
end
local function knows(spell)
  local FM = NS.FM
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, spell)
    if ok and type(info) == "table" and plain(info.spellID) then return true end
  end
  return false
end
--- Is the target in melee reach: true / false when the game says plainly, nil when it will not. C.reachHow = which check.
function C.InReach()
  if not (UnitExists and UnitExists("target")) then C.reachHow = "no target" return false end
  for _, sp in ipairs(C.MELEE_SPELLS) do
    if knows(sp) then
      local r = spellReach(sp)
      if r ~= nil then C.reachHow = sp return r end
    end
  end
  local r = spellReach(C.AUTO_ATTACK)
  if r ~= nil then C.reachHow = "Auto Attack" return r end
  if CheckInteractDistance then
    local ok, v = pcall(CheckInteractDistance, "target", 3)
    if ok then v = plain(v) else v = nil end
    if v == true or v == false then C.reachHow = "about 10 yd (duel distance)" return v end
  end
  C.reachHow = "nothing answers"
  return nil
end
--- /bist combo reach: every check's answer on your target now (stand in melee, then a few steps back, and compare).
function C.ReachProbe()
  local function k(v) if v == nil then return "nil" end if issecretvalue and issecretvalue(v) then return "SECRET" end return tostring(v) end
  local parts = {}
  for _, sp in ipairs(C.MELEE_SPELLS) do
    local okI, r = false, nil
    if C_Spell and C_Spell.IsSpellInRange then okI, r = pcall(C_Spell.IsSpellInRange, sp, "target") end
    parts[#parts + 1] = ("%s%s=%s"):format(sp, knows(sp) and "" or "(not known)", okI and k(r) or "refused")
  end
  local okA, a = false, nil
  if C_Spell and C_Spell.IsSpellInRange then okA, a = pcall(C_Spell.IsSpellInRange, C.AUTO_ATTACK, "target") end
  parts[#parts + 1] = "Auto Attack=" .. (okA and k(a) or "refused")
  for i = 1, 4 do
    local okD, d = false, nil
    if CheckInteractDistance then okD, d = pcall(CheckInteractDistance, "target", i) end
    parts[#parts + 1] = ("interact%d=%s"):format(i, okD and k(d) or "refused")
  end
  local line = "combo reach: " .. table.concat(parts, "  ")
  say("%s", line)
  local r = C.InReach()
  say("combo reach: decided by %s -> %s", tostring(C.reachHow), tostring(r))
  return line
end
function C.Swinging()
  if C_Spell and C_Spell.IsCurrentSpell then
    local ok, v = pcall(C_Spell.IsCurrentSpell, C.AUTO_ATTACK)
    if ok then v = plain(v) else v = nil end
    if v ~= nil then return v and true or false end
  end
  return false
end
function C.ActiveTick()
  local cur = C.cur
  if not cur then return end
  if not cur.swing then return end
  local reach = C.InReach()
  if reach == false then return end
  cur.active = cur.active + C.ACTIVE_EVERY
  if reach == true then cur.reachKnown = true cur.reachHow = C.reachHow end
end
--[[ A SWITCH MID-FIGHT (17 Nov 2026, Arn swapped imbue and totems in one fight: "if people switch stuff mid fight can we
  do a break in the receipt, a cutoff, so we know when the switch happened" - and yes to "file it under what was up the
  longest, with (mixed) on the card"): the fight keeps SEGMENTS - { imbue, tot = set, at } each time what is up changes
  (a totem dropped, gone, an imbue cast). A new totem or another imbue prints a CUT on the tape and the new set. At the end
  the fight is filed under the set up the longest; (mixed) when another one held at least C.MIX_SHARE of it (and
  C.MIX_MIN s) - the totems you drop right after a pull never make a fight "mixed". ]]
C.MIX_SHARE, C.MIX_MIN = 0.2, 3
local function now() return GetTime and GetTime() or 0 end
local function copySet(t) local o = {} for k in pairs(t or {}) do o[k] = true end return o end
--[[ THE LEVEL PENALTY (17 Nov 2026, Arn: "fighting higher level mobs comes with a lot of penalties, like misses and dodges
  - can you find the Forever math for them, and maybe a dps column and an adjusted dps column taking higher and lower
  level enemies into account"). Nothing Forever-specific is published; this is Classic's melee table (warcraft.wiki.gg
  Hit / Glancing blow), your weapon skill taken as maxed (5 x your level) against the mob's defense (5 x its level):
    d = 5 x (mob level - your level)
    miss    5% + 0.1% x d (d <= 10), 5% + 0.2% x d (above: +3 = 8%); a lower mob 5% + 0.04% x d (never under 0)
    dodge   5% + 0.1% x d, never under 0
    glance  only a mob at your level or above: 10% + 2% x d of your swings (+3 = 40%), each doing 5% less up to d 5,
            15% at d 10, 35% from d 15 (between, a straight line)
  How much of your swing damage lands at a level gap: (1 - miss - dodge) x (1 - glance x its cut). The ADJUSTED dps is
  a fight's dps as if the mob were your level: dps x landed(0) / landed(gap). Parry (from the front) and crits are left
  out; spells too (it is the swing's table). A "??" (skull) mob counts as +3. Fights from before the level was kept
  count as your level. ]]
C.LVL_MIN, C.LVL_MAX = -10, 5
function C.LevelPenalty(gap)
  gap = math.max(C.LVL_MIN, math.min(C.LVL_MAX, tonumber(gap) or 0))
  local d = 5 * gap
  local miss
  if d <= 0 then miss = math.max(0, 5 + 0.04 * d)
  elseif d <= 10 then miss = 5 + 0.1 * d
  else miss = 5 + 0.2 * d end
  local dodge = math.max(0, 5 + 0.1 * d)
  local glance, cut = 0, 0
  if d >= 0 then
    glance = 10 + 2 * d
    if d <= 5 then cut = 5 elseif d <= 10 then cut = 5 + (d - 5) * 2 elseif d < 15 then cut = 15 + (d - 10) * 4 else cut = 35 end
  end
  local landed = (1 - (miss + dodge) / 100) * (1 - glance / 100 * cut / 100)
  return { miss = miss, dodge = dodge, glance = glance, cut = cut, landed = landed }
end
--- A fight's dps as if the mob had been your level.
function C.AdjFactor(gap)
  if gap == nil then return 1 end
  return C.LevelPenalty(0).landed / C.LevelPenalty(gap).landed
end
--- The level gap to your target now (nil when it can't be read): its level minus yours; "??" = +3.
function C.TargetGap()
  if not UnitLevel then return nil end
  local okE, there = pcall(UnitExists, "target")
  if not (okE and plain(there) == true) then return nil end
  local ok1, mob = pcall(UnitLevel, "target")
  local ok2, me = pcall(UnitLevel, "player")
  if ok1 then mob = plain(mob) else mob = nil end
  if ok2 then me = plain(me) else me = nil end
  if type(mob) ~= "number" or type(me) ~= "number" then return nil end
  if mob <= 0 then return 3, true end
  return mob - me
end
--- A buff on you by name (a party member's totem), plain answers only.
function C.AuraUp(name)
  if not (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) then return false end
  local ok, a = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
  if not ok or a == nil or (issecretvalue and issecretvalue(a)) then return false end
  return type(a) == "table"
end
function C.Pull()
  local tot = C.ScanTotems({})
  local imbue = C.ImbueNow()
  C.cur = { imbue = imbue, totems = copySet(tot), active = 0, swing = C.Swinging(), start = now(),
            nowImbue = imbue, nowTot = tot, segs = { { imbue = imbue, tot = copySet(tot), at = now() } } }
  C.cur.gap, C.cur.skull = C.TargetGap()
  C.cur.wfAura, C.cur.ftAura = C.AuraUp("Windfury Totem"), C.AuraUp("Flametongue Totem")   -- (a party member's totems)
  C.TapeClear()
  if C.activeTicker and C.activeTicker.Cancel then C.activeTicker:Cancel() end
  if C_Timer and C_Timer.NewTicker then C.activeTicker = C_Timer.NewTicker(C.ACTIVE_EVERY, C.ActiveTick) end
end
--- What is up now changed? A new segment; a new totem or another imbue also cuts the tape. Answers true when it cut.
function C.SwitchCheck(cur, imbue, tot)
  if not (cur and cur.segs) then return false end
  if C.Label(imbue, tot) == C.Label(cur.nowImbue, cur.nowTot) then cur.nowTot = tot return false end
  local added = imbue ~= cur.nowImbue
  for n in pairs(tot) do if not (cur.nowTot or {})[n] then added = true end end
  cur.nowImbue, cur.nowTot = imbue, tot
  cur.segs[#cur.segs + 1] = { imbue = imbue, tot = copySet(tot), at = now() }
  -- (17 Nov, Arn's tape: three totems dropped in a row printed three CUTs - the changes settle C.CUT_SETTLE s first and
  -- print as ONE cut, at the first change's time, with the set as it ended up)
  if added and cur.headed and db().scroll ~= false then
    cur.cutFrom = cur.cutFrom or now()
    cur.cutTok = (cur.cutTok or 0) + 1
    local tok = cur.cutTok
    if C_Timer and C_Timer.After then
      C_Timer.After(C.CUT_SETTLE, function() if cur.cutTok == tok and not cur.endAt then C.PrintCut(cur) end end)
    else
      C.PrintCut(cur)
    end
    return true
  end
  return false
end
C.CUT_SETTLE = 2
function C.PrintCut(cur)
  local secs = math.max(0, (cur.cutFrom or now()) - (cur.start or now()))
  cur.cutFrom = nil
  C.TapePrint(("- - - - CUT %d:%02d - - - -"):format(math.floor(secs / 60), math.floor(secs % 60)))
  C.TapeSet(cur.nowImbue, cur.nowTot)
end
--- The fight's set filed under: the one up the longest (to `endAt`); answers imbue, totem set, mixed.
function C.Longest(cur, endAt)
  local segs = cur.segs
  if not (segs and segs[1]) then return cur.imbue, cur.totems, false end
  endAt = endAt or now()
  local by, order = {}, {}
  for i, g in ipairs(segs) do
    local to = segs[i + 1] and segs[i + 1].at or endAt
    local key = C.Label(g.imbue, g.tot)
    if not by[key] then by[key] = { g = g, secs = 0 } order[#order + 1] = key end
    by[key].secs = by[key].secs + math.max(0, to - g.at)
  end
  table.sort(order, function(a, b) return by[a].secs > by[b].secs end)
  local best, second = by[order[1]], order[2] and by[order[2]]
  local total = math.max(0.01, endAt - segs[1].at)
  local mixed = second and second.secs >= C.MIX_MIN and second.secs >= total * C.MIX_SHARE or false
  return best.g.imbue, best.g.tot, mixed and true or false
end
function C.Cast(spellID)
  if not (C_Spell and C_Spell.GetSpellName) then return end
  local ok, name = pcall(C_Spell.GetSpellName, spellID)
  name = C.Base(ok and plain(name) or nil)
  if not name then return end
  if C.cur and C.TOTEMS[name] then
    C.cur.totems[name] = true
    local tot = copySet(C.cur.nowTot)
    tot[name] = true
    C.SwitchCheck(C.cur, C.cur.nowImbue, tot)
  end
  if C.IMBUE_SHORT[name] and C_Timer and C_Timer.After then   -- learn this enchant id's name from your own cast
    C_Timer.After(0.5, function()
      if not GetWeaponEnchantInfo then return end
      local ok2, has, _, _, id = pcall(GetWeaponEnchantInfo)
      id = ok2 and plain(has) and plain(id)
      if type(id) == "number" then
        local d = db()
        d.imbueNames = d.imbueNames or {}
        d.imbueNames[id] = name
      end
      if C.cur then C.SwitchCheck(C.cur, C.ImbueNow(), copySet(C.cur.nowTot)) end   -- (a new imbue mid-fight: cut)
    end)
  end
end
function C.FightOver()
  local cur = C.cur
  C.cur = nil
  if cur then cur.endAt = now() C.lastHits, C.lastForeign = cur.hitStats, cur.foreign C.TapeEnd(cur) C.FloatEnd() end
  if C.activeTicker and C.activeTicker.Cancel then C.activeTicker:Cancel() end
  C.activeTicker = nil
  if not cur or not (C_Timer and C_Timer.After) then return end
  C.token = (C.token or 0) + 1
  local tok = C.token
  C_Timer.After(C.READ_WAIT, function() if C.token == tok then C.Close(cur) end end)
end
--- The game's newest fight, read once: answers the record it kept, or nil.
--- WHY THE LAST FIGHT WAS (NOT) KEPT (17 Nov, Arn: "had a fight nothing"): every road out of C.Close says it - /bist combo why.
local function why(text) C.lastWhy = text return nil end
function C.Close(cur)
  local D = C_DamageMeter
  if not (D and D.GetAvailableCombatSessions) then return why("the game's damage meter is not there") end
  local okS, sessions = pcall(D.GetAvailableCombatSessions)
  if not (okS and type(sessions) == "table" and #sessions > 0) then return why("the damage meter kept no fights") end
  -- the NEWEST fight is the highest session id (never trust the list's order)
  local last, sid
  for _, e in ipairs(sessions) do
    local id = type(e) == "table" and plain(e.sessionID) or nil
    if type(id) == "number" and (not sid or id > sid) then last, sid = e, id end
  end
  if not sid then return why("the fights had no readable id") end
  if sid == db().lastSid then return why("no new fight in the meter yet (newest " .. sid .. ")") end
  local dmgType = (Enum and Enum.DamageMeterType and Enum.DamageMeterType.DamageDone) or 0
  local ok, s = pcall(D.GetCombatSessionFromID, sid, dmgType)
  if not (ok and type(s) == "table") then return why("fight " .. sid .. " would not open") end
  local mine
  pcall(function()
    for _, src in ipairs(s.combatSources or {}) do
      if plain(src.isLocalPlayer) == true then mine = src break end
    end
  end)
  local dmg = mine and plain(mine.totalAmount)
  local dur = plain(s.durationSeconds) or plain(last.durationSeconds)
  if not mine then return why("you were not in fight " .. sid) end
  if type(dmg) ~= "number" or type(dur) ~= "number" or dur <= 0 then return why("fight " .. sid .. ": damage or length hidden") end
  -- what Windfury and Flametongue added (your breakdown, by the spells' names)
  local wf, ft = 0, 0
  local spells = {}                                  -- every spell's share (the weapon's Windfury and the totem's apart, if named apart)
  local guid = UnitGUID and plain(UnitGUID("player"))
  local okB, br = pcall(D.GetCombatSessionSourceFromID, sid, dmgType, guid)
  if okB and type(br) == "table" then
    pcall(function()
      for _, sp in ipairs(br.combatSpells or {}) do
        local id, amt = plain(sp.spellID), plain(sp.totalAmount)
        local okN, name = false, nil
        if id and C_Spell and C_Spell.GetSpellName then okN, name = pcall(C_Spell.GetSpellName, id) end
        name = okN and plain(name) or ""
        if type(amt) == "number" and type(name) == "string" then
          if name:find("Windfury", 1, true) then wf = wf + amt elseif name:find("Flametongue", 1, true) then ft = ft + amt end
          spells[#spells + 1] = { name = (name ~= "" and name) or ("spell " .. tostring(id)), amt = amt }
        end
      end
    end)
  end
  local d = db()
  d.lastSid = sid
  local imbue, longTot, mixed = C.Longest(cur, cur.endAt)
  local totems = {}
  for n in pairs(longTot or {}) do totems[#totems + 1] = n end
  table.sort(totems)
  imbue = imbue or C.ImbueNow()
  local set = {}
  for _, n in ipairs(totems) do set[n] = true end
  local active, how
  if (cur.beats or 0) >= C.CADENCE_MIN then                -- the swing cadence decides (Arn's WeakAura way)
    active = math.min((cur.cadence or 0) + (cur.lastSpeed or C.SPEED_GUESS), dur)
    how = ("swing cadence - %d swings"):format(cur.beats)
  else
    active = (cur.active or 0) >= C.ACTIVE_MIN and math.min(cur.active, dur) or nil
    how = active and (cur.reachKnown and ("swinging in reach - " .. tostring(cur.reachHow)) or "swinging") or "the whole fight"
  end
  local rec = { at = (time and time()) or 0, sid = sid, mob = plain(last.name) or plain(s.name), dur = dur, dmg = dmg,
                active = active, how = how,
                imbue = imbue, totems = totems, combo = C.Label(imbue, set),
                wf = dmg > 0 and wf / dmg or 0, ft = dmg > 0 and ft / dmg or 0, spells = C.TopSpells(spells, dmg),
                procs = cur.procs, mixed = mixed or nil, swings = cur.beats, gap = cur.gap, skull = cur.skull }
  d.fights = d.fights or {}
  d.fights[#d.fights + 1] = rec
  while #d.fights > C.KEEP do table.remove(d.fights, 1) end
  C.lastWhy = ("kept fight %d: %s, %d s (%s %s), %d dps"):format(sid, rec.combo, math.floor(dur + 0.5),
    active and math.floor(active + 0.5) .. " s" or "-", rec.how, math.floor(dmg / C.Time(rec) + 0.5))
  rec.foreign = cur.foreign
  C.MeterCheck(rec)
  if d.card ~= false then C.ShowCard(rec) end
  if C.IsOpen() then C.Paint() end
  return rec
end

--- After the fight the meter is plain: no Windfury in YOUR damage but Windfury procs on the tape = they were someone
--- else's swings landing on your clock. Said on the tape while it is still up.
function C.MeterCheck(rec)
  local pr = rec.procs or {}
  local wfProcs = (pr.extra1 or 0) + (pr.extra2 or 0) + (pr.more or 0)
  if (rec.wf or 0) > 0 or wfProcs == 0 then return false end
  rec.notMine = true
  local t = C.tape
  if t and t:IsShown() and db().scroll ~= false then
    C.TapePrint("METER: NO WINDFURY OF YOURS", true)
    C.TapePrint("THOSE WERE SOMEONE ELSE'S")
  end
  return true
end
--- A fight's biggest spells as shares, at most C.TOP_SPELLS (kept small in the save). (17 Nov, Arn: "they let you stack
--- totems and imbue now" - "totem is 1 extra hit, imbue is 2": Windfury Weapon and Windfury Totem both proc on Forever
--- since the 11-12 Nov hotfix; if the game names their hits apart, the list shows each one's share.)
C.TOP_SPELLS = 5
function C.TopSpells(list, dmg)
  table.sort(list, function(a, b) return a.amt > b.amt end)
  local out = {}
  for i = 1, math.min(C.TOP_SPELLS, #list) do out[i] = { name = list[i].name, share = dmg > 0 and list[i].amt / dmg or 0 } end
  return out
end

-- ---------------------------------------------------------------- the ranking
function C.Min() return tonumber(db().min) or C.MIN end
--- The time a fight's DPS is counted over: the time you were swinging, else (none measured) the fight's length.
function C.Time(f) return (f.active and f.active > 0) and f.active or f.dur end
--- Every combo with enough fight in it, best first: { combo, n, dmg, dur, dps }.
function C.Rank()
  local by, list = {}, {}
  for _, f in ipairs(db().fights or {}) do
    if (f.dur or 0) >= C.Min() then
      local g = by[f.combo]
      if not g then g = { combo = f.combo, n = 0, dmg = 0, dur = 0, adjDmg = 0, imbue = f.imbue, totems = f.totems } by[f.combo] = g list[#list + 1] = g end
      g.n, g.dmg, g.dur = g.n + 1, g.dmg + f.dmg, g.dur + C.Time(f)
      g.adjDmg = g.adjDmg + f.dmg * C.AdjFactor(f.gap)
    end
  end
  for _, g in ipairs(list) do
    g.dps = g.dur > 0 and g.dmg / g.dur or 0
    g.adj = g.dur > 0 and g.adjDmg / g.dur or 0
  end
  -- (sorted by the ADJUSTED dps: a combo tried on harder mobs is not ranked down for it)
  table.sort(list, function(a, b) if a.adj ~= b.adj then return a.adj > b.adj end return a.dps > b.dps end)
  return list
end
--[[ TRY NEXT (17 Nov 2026, Arn: "it seems Flametongue Totem is best with WF imbue ... or is there a combination I am not
  trying - maybe the combo box can smartly suggest combos to get more data"): every combo you COULD run - each imbue you
  know, times one totem per element you know (the damage ones only: C.TRY), each slot filled - and how many fights each
  has. The one with the fewest fights is next; a tie goes to the one most like your best (fewest changes to try). When
  every combo has C.TRY_ENOUGH fights the ranking stands on its own. ]]
C.TRY = {
  imbue = { "Windfury Weapon", "Flametongue Weapon", "Rockbiter Weapon", "Frostbrand Weapon" },
  fire = { "Flametongue Totem" },   -- (17 Nov, Arn: no Magma, no Searing - "everything else lasts 5 min, so it's more neat")
  earth = { "Strength of Earth Totem" },
  air = { "Grace of Air Totem", "Windfury Totem" },
}
C.TRY_ENOUGH = 5
--- Do you know this spell? (by name: the client's spell info, then whether it is yours)
function C.Knows(name)
  if not (C_Spell and C_Spell.GetSpellInfo) then return false end
  local ok, info = pcall(C_Spell.GetSpellInfo, name)
  if not ok or type(info) ~= "table" then return false end
  local id = plain(info.spellID)
  if type(id) ~= "number" then return false end
  local known = IsPlayerSpell or IsSpellKnown
  if not known then return true end
  local ok2, yes = pcall(known, id)
  return ok2 and plain(yes) == true
end
--- Every combo you could run: { imbue, totems = { names }, combo = label, n = fights } for each.
function C.Possible()
  local have = {}
  for slot, names in pairs(C.TRY) do
    have[slot] = {}
    for _, n in ipairs(names) do if C.Knows(n) then have[slot][#have[slot] + 1] = n end end
    if #have[slot] == 0 then have[slot] = { false } end   -- (none known for that element: the slot stays empty)
  end
  local counts = {}
  for _, g in ipairs(C.Rank()) do counts[g.combo] = g.n end
  local out = {}
  for _, im in ipairs(have.imbue) do
    for _, fi in ipairs(have.fire) do
      for _, ea in ipairs(have.earth) do
        for _, ai in ipairs(have.air) do
          local set, list = {}, {}
          for _, t in ipairs({ fi, ea, ai }) do if t then set[t] = true list[#list + 1] = t end end
          local imbue = im or nil
          local label = C.Label(imbue, set)
          out[#out + 1] = { imbue = imbue, totems = list, combo = label, n = counts[label] or 0 }
        end
      end
    end
  end
  return out
end
--- The combo to try next, or nil when every one has enough fights (or nothing is known).
function C.TryNext()
  local all = C.Possible()
  if #all == 0 or (#all == 1 and not all[1].imbue and #all[1].totems == 0) then return nil end
  local best = C.Rank()[1]
  local function like(c)
    if not best then return 0 end
    local k = (c.imbue == best.imbue) and 1 or 0
    local bt = {}
    for _, t in ipairs(best.totems or {}) do bt[t] = true end
    for _, t in ipairs(c.totems) do if bt[t] then k = k + 1 end end
    return k
  end
  table.sort(all, function(a, b)
    if a.n ~= b.n then return a.n < b.n end
    local la, lb = like(a), like(b)
    if la ~= lb then return la > lb end
    return a.combo < b.combo
  end)
  local pick = all[1]
  if pick.n >= C.TRY_ENOUGH then return nil, #all end
  local untried = 0
  for _, c in ipairs(all) do if c.n == 0 then untried = untried + 1 end end
  return pick, #all, untried
end
function C.Place(combo)
  local list = C.Rank()
  for i, g in ipairs(list) do if g.combo == combo then return i, #list end end
  return nil, #list
end

-- ---------------------------------------------------------------- the card
local function endDrag(f) if f and f.moving then f.moving = nil f:StopMovingOrSizing() end end
function C.BuildCard()
  if C.card then return C.card end
  local K = F()
  local f = CreateFrame("Frame", "BiSToolsComboCard", UIParent)
  f:SetSize(250, 58)
  local p = db().cardPos
  if type(p) == "table" and p[1] then f:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
  else f:SetPoint("TOP", UIParent, "TOP", 0, -170) end
  f:SetFrameStrata("MEDIUM")
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    if InCombatLockdown and InCombatLockdown() then return end
    C.CastAway()
    self:StartMoving() self.moving, self.dragged = true, true
  end)
  f:SetScript("OnDragStop", function(self)
    endDrag(self)
    local ok, pt, _, rp, x, y = pcall(self.GetPoint, self)
    if ok and pt then db().cardPos = { pt, rp, x, y } end
  end)
  f:SetScript("OnHide", endDrag)
  f:SetScript("OnMouseUp", function(self)
    if self.dragged then self.dragged = nil return end
    C.Toggle(true)
  end)
  f:SetScript("OnEnter", function(self)
    self.hold = true self:SetAlpha(1)
    local rec = self.rec
    if rec and GameTooltip then                                  -- (the names behind the icons)
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:AddLine(rec.imbue or "no imbue", 1, 1, 1)
      for _, n in ipairs(rec.totems or {}) do GameTooltip:AddLine(n, 0.8, 0.8, 0.8) end
      GameTooltip:AddLine("click: the list", 0.6, 0.6, 0.6)
      GameTooltip:Show()
    end
  end)
  f:SetScript("OnLeave", function(self) self.hold = nil if GameTooltip then GameTooltip:Hide() end end)
  K.tex(f, "BACKGROUND", "frame", 0.94)
  K.border(f, "edge", 1)
  f.title = K.fs(f, "BiS> combo", 9, "accent")
  f.title:SetPoint("TOPLEFT", 6, -5)
  f.where = K.fs(f, "", 9, "muted")
  f.where:SetPoint("TOPRIGHT", -6, -5)
  f.combo = K.fs(f, "", 11, "ink")
  f.combo:SetPoint("LEFT", f, "LEFT", 6, 2)
  f.icons = {}                                         -- (the combo as icons; f.combo keeps "(mixed)" after them)
  f.dps = K.fs(f, "", 16, "good")
  f.dps:SetPoint("RIGHT", f, "RIGHT", -6, 2)
  f.place = K.fs(f, "", 9, "gold")
  f.place:SetPoint("BOTTOMLEFT", 6, 5)
  f:SetScript("OnUpdate", function(self, e)
    if self.hold then self.left = C.CARD_FOR return end
    self.left = (self.left or C.CARD_FOR) - (tonumber(e) or 0)
    if self.left <= 0 then self:Hide() return end
    if self.left < C.CARD_FADE then self:SetAlpha(self.left / C.CARD_FADE) end
  end)
  f:Hide()
  C.card = f
  return f
end
C.CARD_ICON = 20
--- The card's combo: the imbue's icon, then each totem's, then "(mixed)" when it was; words for anything with no icon.
function C.CardIcons(f, rec)
  local names = {}
  if rec.imbue then names[#names + 1] = rec.imbue end
  for _, n in ipairs(rec.totems or {}) do names[#names + 1] = n end
  local x, words = 6, {}
  for i, n in ipairs(names) do
    local tex = C.IconFor(n)
    local t = f.icons[i]
    if tex and not t then
      t = C.IconButton(f, C.CARD_ICON)
      f.icons[i] = t
    end
    if tex then
      t:ClearAllPoints() t:SetPoint("LEFT", f, "LEFT", x, 2)
      t:SetTexture(tex) t.name = n t:Show()
      x = x + C.CARD_ICON + 2
    else
      if t then t:Hide() t.name = nil end
      words[#words + 1] = C.TOTEMS[n] or C.IMBUE_SHORT[n] or n
    end
  end
  for i = #names + 1, #f.icons do f.icons[i]:Hide() f.icons[i].name = nil end
  f.iconW = x - 6
  f.combo:ClearAllPoints()
  f.combo:SetPoint("LEFT", f, "LEFT", x + 2, 2)
  local text = table.concat(words, " · ")
  if rec.mixed then text = text .. (text ~= "" and "  " or "") .. "(mixed)" end
  if #names == 0 then text = "no imbue" .. (rec.mixed and "  (mixed)" or "") end
  f.combo:SetText(text)
  f.rec = rec
end
--- THE CARD GROWS TO FIT (17 Nov 2026, Arn's shot: "WF · FT totem · GoA · SoE · WF totem" ran under "100 dps"): as wide as
--- its widest line - the combo with the dps beside it, the top line, the bottom line - never under C.CARD_W.
C.CARD_W, C.CARD_GAP = 250, 14
local function textW(fs)
  local ok, w = pcall(fs.GetStringWidth, fs)
  if ok and tonumber(w) and w > 0 then return w end
  return #(fs:GetText() or "") * 6
end
function C.FitCard(f)
  local need = math.max((f.iconW or 0) + 4 + textW(f.combo) + C.CARD_GAP + textW(f.dps), textW(f.title) + C.CARD_GAP + textW(f.where), textW(f.place)) + 12
  f:SetWidth(math.max(C.CARD_W, math.ceil(need)))
  return f:GetWidth()
end
function C.ShowCard(rec)
  local f = C.BuildCard()
  f.where:SetText(("%s%s"):format(rec.active and ("%d of %d s swinging"):format(math.floor(rec.active + 0.5), math.floor(rec.dur + 0.5))
    or ("%d s"):format(math.floor(rec.dur + 0.5)), rec.mob and (" · " .. rec.mob) or ""))
  C.CardIcons(f, rec)
  f.dps:SetText(("%d dps"):format(math.floor(rec.dmg / C.Time(rec) + 0.5)))
  if rec.dur < C.Min() then
    f.place:SetText(("short fight - not ranked (under %d s)"):format(C.Min()))
  else
    local k, n = C.Place(rec.combo)
    local wf = rec.wf and rec.wf > 0 and ("  ·  Windfury %d%%"):format(math.floor(rec.wf * 100 + 0.5)) or ""
    local pr = rec.procs
    if pr then                                       -- (the same split as the tape's breakdown: Windfury's, Flametongue's)
      local w, ft = (pr.extra1 or 0) + (pr.extra2 or 0) + (pr.more or 0), pr.fire or 0
      if w > 0 then wf = wf .. ("  ·  %d WF"):format(w) end
      if ft > 0 then wf = wf .. ("  ·  %d FT"):format(ft) end
      if w + ft > 0 then wf = wf .. " procs" end
    end
    f.place:SetText(("#%d of %d combos · click for the list%s"):format(k or 1, n, wf))
  end
  C.FitCard(f)
  f.left, f.hold = C.CARD_FOR, nil
  f:SetAlpha(1)
  f:Show()
  return f
end

-- ---------------------------------------------------------------- the list
function C.Build()
  if C.frame then return C.frame end
  local K = F()
  local f = CreateFrame("Frame", "BiSToolsCombo", UIParent)
  f:SetSize(C.Size())
  f:SetScale(1.2)                                   -- (small windows read at 1.2 - the family rule)
  -- (17 Nov, Arn: "it keeps resetting the combo window to the center of the screen" - its spot was never kept: db.listPos)
  local lp = db().listPos
  if type(lp) == "table" and lp[1] then f:SetPoint(lp[1], UIParent, lp[2] or lp[1], lp[3] or 0, lp[4] or 0)
  else f:SetPoint("CENTER") end
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    if InCombatLockdown and InCombatLockdown() then return end
    C.CastAway()
    self:StartMoving() self.moving = true
  end)
  local function keep(self)
    if not self:IsShown() then C.CastAway() end
    if self.sizing then C.EndSizing(self) end                  -- (hidden mid-size: let go, as a drag does)
    if not self.moving then return end
    endDrag(self)
    local ok, pt, _, rp, x, y = pcall(self.GetPoint, self)
    if ok and pt then db().listPos = { pt, rp, x, y } end
  end
  f:SetScript("OnDragStop", keep)
  f:SetScript("OnHide", keep)
  K.tex(f, "BACKGROUND", "frame", 0.95)
  K.border(f, "edge", 1)
  f.title = K.fs(f, "BiS> combo", 10, "accent")
  f.title:SetPoint("TOPLEFT", 8, -6)
  f.close = CreateFrame("Button", nil, f)
  f.close:SetSize(16, 16)
  f.close:SetPoint("TOPRIGHT", -4, -4)
  K.tex(f.close, "BACKGROUND", "field", 0.9)
  f.close.label = K.fs(f.close, "x", 9, "ink")
  f.close.label:SetPoint("CENTER")
  f.close:SetScript("OnClick", function() C.Toggle(false) end)
  f.set = CreateFrame("Button", nil, f)               -- the switches panel's button
  f.set:SetSize(28, 16)
  f.set:SetPoint("RIGHT", f.close, "LEFT", -4, 0)
  K.tex(f.set, "BACKGROUND", "field", 0.9)
  f.set.label = K.fs(f.set, "SET", 9, "ink")
  f.set.label:SetPoint("CENTER")
  f.set:SetScript("OnClick", function() C.ToggleSet() end)
  f.heads = { K.fs(f, "", 9, "dim"), K.fs(f, "fights", 9, "dim"), K.fs(f, "dps", 9, "dim"), K.fs(f, "adj", 9, "dim") }
  f.colHeads = {}
  for _, c in ipairs(C.COLS) do f.colHeads[c] = K.fs(f, c, 9, "dim") end
  f.rows = {}
  f.detail = K.fs(f, "", 9, "muted")
  f.detail:SetJustifyH("LEFT")
  f.foot = K.fs(f, "", 9, "dim")
  f.foot:SetPoint("BOTTOMLEFT", 8, 7)
  -- TRY NEXT: the combo with the fewest fights, as icons, over the foot (C.TryNext)
  local tr = CreateFrame("Button", nil, f)
  tr:SetHeight(C.TRY_H - 2)
  tr:SetPoint("BOTTOMLEFT", 8, 22) tr:SetPoint("BOTTOMRIGHT", -8, 22)
  tr.lit = K.tex(tr, "BACKGROUND", "accent", 0.08)
  tr.word = K.fs(tr, "TRY NEXT", 9, "gold")
  tr.word:SetPoint("LEFT", 4, 0)
  tr.icons = {}
  for k = 1, 4 do
    local t = C.IconButton(tr, C.TRY_H - 4)
    t:SetPoint("LEFT", tr, "LEFT", 62 + (k - 1) * (C.TRY_H - 2), 0)
    tr.icons[k] = t
  end
  tr.note = K.fs(tr, "", 9, "muted")
  tr.note:SetPoint("LEFT", tr, "LEFT", 62 + 4 * (C.TRY_H - 2) + 4, 0)
  -- SET DECK: the suggestion's totems onto BiS Healing's deck boxes (C.SendDeck), shown only when the deck can take them
  tr.deck = CreateFrame("Button", nil, tr)
  tr.deck:SetSize(62, C.TRY_H - 6)
  tr.deck:SetPoint("RIGHT", tr, "RIGHT", -4, 0)
  K.tex(tr.deck, "BACKGROUND", "field", 0.9)
  tr.deck.label = K.fs(tr.deck, "SET DECK", 8, "gold")
  tr.deck.label:SetPoint("CENTER")
  tr.deck:SetScript("OnClick", function() if tr.c then C.SendDeck(tr.c.totems) end end)
  tr.deck:SetScript("OnEnter", function(self)
    if tr.c and C.AimDeck(self, tr.c.imbue, tr.c.totems) then return end   -- (the imbue cast with it)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Set these totems on your BiS Healing deck" .. ((tr.c and tr.c.imbue) and " (the imbue: out of a fight)" or ""), 1, 0.82, 0)
    if C.DeckCan() then
      GameTooltip:AddLine("Its totem boxes drop them from your next click. Out of a fight only. Right-click a combo in the list to send that one.", 0.9, 0.9, 0.9, true)
    else
      GameTooltip:AddLine(C.DeckMissing(), 1, 0.5, 0.4, true)
    end
    GameTooltip:Show()
  end)
  tr.deck:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  tr.deck:Hide()
  tr:SetScript("OnEnter", function(self)
    self.lit:SetAlpha(0.2)
    local c = self.c
    if not (c and GameTooltip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Try next: " .. (c.n == 0 and "never fought with" or ("only %d fights"):format(c.n)), 1, 0.82, 0)
    GameTooltip:AddLine(c.imbue or "no imbue", 1, 1, 1)
    for _, n in ipairs(c.totems) do GameTooltip:AddLine(n, 0.8, 0.8, 0.8) end
    GameTooltip:AddLine("A few fights with it and the ranking knows where it stands.", 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
  end)
  tr:SetScript("OnLeave", function(self) self.lit:SetAlpha(0.08) if GameTooltip then GameTooltip:Hide() end end)
  f.try = tr
  -- DRAG THE CORNER (17 Nov 2026, Arn: "let me resize the window by dragging the corner"): the grip at the bottom right
  -- sizes the list inside the same bounds as SET's steps, the rows following live; db.w / db.h on letting go
  if f.SetResizable then f:SetResizable(true) end
  if f.SetResizeBounds then pcall(f.SetResizeBounds, f, C.W_MIN, C.H_MIN, C.W_MAX, C.H_MAX)
  elseif f.SetMinResize then pcall(f.SetMinResize, f, C.W_MIN, C.H_MIN) pcall(f.SetMaxResize, f, C.W_MAX, C.H_MAX) end
  local grip = CreateFrame("Button", nil, f)
  grip:SetSize(14, 14)
  grip:SetPoint("BOTTOMRIGHT", -2, 2)
  grip.tex = grip:CreateTexture(nil, "OVERLAY")
  grip.tex:SetAllPoints(grip)
  grip.tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip.tex:SetAlpha(0.7)
  grip:SetScript("OnEnter", function(self) self.tex:SetAlpha(1) end)
  grip:SetScript("OnLeave", function(self) self.tex:SetAlpha(0.7) end)
  grip:SetScript("OnMouseDown", function()
    if fighting() then return end                       -- (never in a fight)
    C.CastAway()
    if f.StartSizing then f.sizing = true f:StartSizing("BOTTOMRIGHT") end
  end)
  grip:SetScript("OnMouseUp", function() C.EndSizing(f) end)
  f.grip = grip
  f:SetScript("OnSizeChanged", function(self, w, h)
    if not self.sizing then return end
    local d = db()
    d.w = math.max(C.W_MIN, math.min(C.W_MAX, math.floor((tonumber(w) or C.W) + 0.5)))
    d.h = math.max(C.H_MIN, math.min(C.H_MAX, math.floor((tonumber(h) or C.H) + 0.5)))
    C.Layout() C.Paint()
    if C.PaintSet then C.PaintSet() end
  end)
  -- NEVER ON THE ESCAPE LIST (17 Nov, Arn: "I pressed esc when not in the window and it closed it" - the boss list's
  -- lesson again): the x or /bist combo closes it, nothing else
  f:Hide()
  C.frame = f
  return f
end
--- Let go of the corner: the size kept, its spot kept (sizing re-anchors it).
function C.EndSizing(f)
  if not f.sizing then return end
  f.sizing = nil
  f:StopMovingOrSizing()
  local d = db()
  d.w = math.max(C.W_MIN, math.min(C.W_MAX, math.floor((f:GetWidth() or C.W) + 0.5)))
  d.h = math.max(C.H_MIN, math.min(C.H_MAX, math.floor((f:GetHeight() or C.H) + 0.5)))
  local ok, pt, _, rp, x, y = pcall(f.GetPoint, f)
  if ok and pt then d.listPos = { pt, rp, x, y } end
  C.Layout() C.Paint()
  if C.PaintSet then C.PaintSet() end
end
--- The list's size: the saved one, inside the bounds.
function C.Size()
  local d = db()
  local w = math.max(C.W_MIN, math.min(C.W_MAX, tonumber(d.w) or C.W))
  local h = math.max(C.H_MIN, math.min(C.H_MAX, tonumber(d.h) or C.H))
  return w, h
end
--[[ THE NUMBER BOXES (17 Nov 2026, Arn, of the text under the list: "can you clean up the text, easier to read - boxes"):
  three rows of four boxes, each a small label over one big number - the procs (% of your own swings), the fights
  (count, average, best, the mobs' level), and you now (crit, attack power, weapon speed, damage) - the last fight on one
  short line under them. Hover a box for what it means. ]]
C.TILE_H, C.TILE_GAP, C.TILE_COLS, C.TILE_ROWS = 28, 4, 4, 3
C.TILES_H = C.TILE_ROWS * (C.TILE_H + C.TILE_GAP) + 18
--- How many rows the height holds (the TRY NEXT strip takes C.TRY_H above the foot).
C.TRY_H = 20
function C.RowCount()
  local _, h = C.Size()
  return math.max(3, math.floor((h - 38 - C.TILES_H - 22 - C.TRY_H) / C.ROW))
end
--- Lay the list out on its size: the columns on the width, as many rows as the height holds.
function C.Layout()
  local f = C.frame
  if not f then return end
  local K = F()
  local w, h = C.Size()
  f:SetSize(w, h)
  local nameW = w - 16 - 168                           -- (fights, dps and adj on the right)
  f.heads[1]:ClearAllPoints() f.heads[1]:SetPoint("TOPLEFT", 10, -24) f.heads[1]:SetWidth(nameW)
  do                                                   -- the column heads: imbue, fire, earth, air
    local x = 10
    for _, c in ipairs(C.COLS) do
      local cw = math.floor(nameW * C.COL_SHARE[c])
      f.colHeads[c]:ClearAllPoints() f.colHeads[c]:SetPoint("TOPLEFT", x, -24) f.colHeads[c]:SetWidth(cw - 2)
      f.colHeads[c]:SetJustifyH("LEFT")
      x = x + cw
    end
  end
  f.heads[2]:ClearAllPoints() f.heads[2]:SetPoint("TOPLEFT", 10 + nameW, -24) f.heads[2]:SetWidth(52) f.heads[2]:SetJustifyH("RIGHT")
  f.heads[3]:ClearAllPoints() f.heads[3]:SetPoint("TOPLEFT", 10 + nameW + 54, -24) f.heads[3]:SetWidth(46) f.heads[3]:SetJustifyH("RIGHT")
  f.heads[4]:ClearAllPoints() f.heads[4]:SetPoint("TOPLEFT", 10 + nameW + 102, -24) f.heads[4]:SetWidth(52) f.heads[4]:SetJustifyH("RIGHT")
  local n = C.RowCount()
  for i = 1, math.max(n, #f.rows) do
    local r = f.rows[i]
    if i <= n and not r then
      r = CreateFrame("Button", nil, f)
      r.lit = K.tex(r, "BACKGROUND", "accent", 0)               -- rows glow on hover (the family rule): a wash + a bar
      r.armed = K.tex(r, "BACKGROUND", "warn", 0)               -- (pink while one shift-click more forgets it: C.ForgetAsk)
      r.bar = r:CreateTexture(nil, "ARTWORK")
      r.bar:SetPoint("TOPLEFT") r.bar:SetPoint("BOTTOMLEFT") r.bar:SetWidth(3)
      do local rr, g, b = K.color("accent") r.bar:SetColorTexture(rr, g, b, 1) end
      r.bar:SetAlpha(0)
      r.name = K.fs(r, "", 9, "ink") r.name:SetJustifyH("LEFT")
      r.cells = {}
      for _, c in ipairs(C.COLS) do r.cells[c] = K.fs(r, "", 9, "ink") r.cells[c]:SetJustifyH("LEFT") end
      r.icons = {}
      for _, c in ipairs(C.COLS) do
        r.icons[c] = {}
        for k = 1, 2 do                                       -- (two totems of one element stack on Forever: two icons)
          r.icons[c][k] = C.IconButton(r, C.ROW - 2)
        end
      end
      r.n = K.fs(r, "", 9, "muted") r.n:SetJustifyH("RIGHT")
      r.dps = K.fs(r, "", 9, "muted") r.dps:SetJustifyH("RIGHT")
      r.adj = K.fs(r, "", 9, "good") r.adj:SetJustifyH("RIGHT")
      if r.RegisterForClicks then r:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
      r:SetScript("OnClick", function(self, button)
        if not self.g then return end
        if IsShiftKeyDown and IsShiftKeyDown() then C.ForgetAsk(self.g.combo) return end   -- (shift-click twice: forget it)
        if button == "RightButton" then C.SendDeck(self.g.totems) return end   -- (right-click: onto the deck)
        C.sel = self.g.combo C.Paint()
      end)
      r:SetScript("OnEnter", function(self) self.hover = true C.PaintRow(self) C.RowTip(self) end)
      r:SetScript("OnLeave", function(self) self.hover = nil C.PaintRow(self) if GameTooltip then GameTooltip:Hide() end end)
      f.rows[i] = r
    end
    if r then
      if i <= n then
        r:SetSize(w - 16, C.ROW)
        r:ClearAllPoints() r:SetPoint("TOPLEFT", 8, -38 - (i - 1) * C.ROW)
        r.name:ClearAllPoints() r.name:SetPoint("LEFT", 4, 0) r.name:SetWidth(nameW - 6)
        local x = 2
        for _, c in ipairs(C.COLS) do
          local cw = math.floor(nameW * C.COL_SHARE[c])
          r.cells[c]:ClearAllPoints() r.cells[c]:SetPoint("LEFT", x, 0) r.cells[c]:SetWidth(cw - 2)
          for k, t in ipairs(r.icons[c]) do t:ClearAllPoints() t:SetPoint("LEFT", r, "LEFT", x + (k - 1) * C.ROW, 0) end
          x = x + cw
        end
        r.n:ClearAllPoints() r.n:SetPoint("LEFT", 2 + nameW, 0) r.n:SetWidth(52)
        r.dps:ClearAllPoints() r.dps:SetPoint("LEFT", 2 + nameW + 54, 0) r.dps:SetWidth(46)
        r.adj:ClearAllPoints() r.adj:SetPoint("LEFT", 2 + nameW + 102, 0) r.adj:SetWidth(52)
        r:Show()
      else
        r.g = nil
        r:Hide()
      end
    end
  end
  local top = -42 - n * C.ROW
  local tw = math.floor((w - 16 - (C.TILE_COLS - 1) * C.TILE_GAP) / C.TILE_COLS)
  f.tiles = f.tiles or {}
  for i = 1, C.TILE_COLS * C.TILE_ROWS do
    local t = f.tiles[i] or C.MakeTile(f)
    f.tiles[i] = t
    local col, row = (i - 1) % C.TILE_COLS, math.floor((i - 1) / C.TILE_COLS)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", 8 + col * (tw + C.TILE_GAP), top - row * (C.TILE_H + C.TILE_GAP))
    t:SetSize(tw, C.TILE_H)
    t.value:SetWidth(tw - 8)
  end
  f.detail:ClearAllPoints()
  f.detail:SetPoint("TOPLEFT", 10, top - C.TILE_ROWS * (C.TILE_H + C.TILE_GAP) - 1)
  f.detail:SetWidth(w - 20)
  if f.detail.SetWordWrap then f.detail:SetWordWrap(false) end
  if f.sw then f.sw:SetWidth(w - 16) end
end

-- the switches panel: toggles, steppers, RESET - over the list's lower half
local function swRow(p, y, label)
  local K = F()
  local r = CreateFrame("Button", nil, p)
  r:SetHeight(16)
  r:SetPoint("TOPLEFT", 4, y) r:SetPoint("TOPRIGHT", -4, y)
  r.lit = K.tex(r, "BACKGROUND", "accent", 0)
  r.bar = r:CreateTexture(nil, "ARTWORK")
  r.bar:SetPoint("TOPLEFT") r.bar:SetPoint("BOTTOMLEFT") r.bar:SetWidth(3)
  do local rr, g, b = K.color("accent") r.bar:SetColorTexture(rr, g, b, 1) end
  r.bar:SetAlpha(0)
  r.label = K.fs(r, label, 9, "ink") r.label:SetPoint("LEFT", 6, 0)
  r.value = K.fs(r, "", 9, "gold") r.value:SetPoint("RIGHT", -6, 0)
  r:SetScript("OnEnter", function(self) self.lit:SetAlpha(0.16) self.bar:SetAlpha(1) end)
  r:SetScript("OnLeave", function(self) self.lit:SetAlpha(0) self.bar:SetAlpha(0) end)
  return r
end
local function stepRow(p, y, label, get, set, lo, hi, step, unit)
  local r = swRow(p, y, label)
  local K = F()
  local function btn(word, dir)
    local b = CreateFrame("Button", nil, r)
    b:SetSize(16, 14)
    K.tex(b, "BACKGROUND", "field", 0.9)
    b.label = K.fs(b, word, 9, "ink") b.label:SetPoint("CENTER")
    b:SetScript("OnClick", function() set(math.max(lo, math.min(hi, get() + dir * step))) C.PaintSet() end)
    return b
  end
  r.plus = btn("+", 1) r.plus:SetPoint("RIGHT", -4, 0)
  r.value:ClearAllPoints() r.value:SetPoint("RIGHT", r.plus, "LEFT", -6, 0)
  r.minus = btn("-", -1)
  r.minus:SetPoint("RIGHT", r.value, "LEFT", -40, 0)
  r.paint = function() r.value:SetText(tostring(get()) .. (unit or "")) end
  return r
end
function C.BuildSet()
  local f = C.frame
  if not f or f.sw then return f and f.sw end
  local K = F()
  local p = CreateFrame("Frame", nil, f)
  p:SetFrameLevel((f:GetFrameLevel() or 0) + 5)
  p:SetPoint("BOTTOMLEFT", 8, 22)
  p:SetSize(C.Size() - 16, 146)
  K.tex(p, "BACKGROUND", "header", 0.98)
  K.border(p, "edge", 1)
  local d = function() return db() end
  p.card = swRow(p, -4, "card after each fight")
  p.card:SetScript("OnClick", function() d().card = d().card == false and true or false C.PaintSet() end)
  p.card.paint = function() p.card.value:SetText(d().card ~= false and "ON" or "OFF") end
  p.scroll = swRow(p, -22, "proc text in a fight")
  p.scroll:SetScript("OnClick", function() d().scroll = d().scroll == false and true or false C.PaintSet() end)
  p.scroll.paint = function() p.scroll.value:SetText(d().scroll ~= false and "ON" or "OFF") end
  p.style = swRow(p, -40, "proc text style")
  p.style:SetScript("OnClick", function() d().tapeStyle = (d().tapeStyle == "clean") and "receipt" or "clean" C.StyleChanged() C.PaintSet() end)
  p.style.paint = function() p.style.value:SetText(d().tapeStyle == "clean" and "CLEAN" or "RECEIPT") end
  p.min = stepRow(p, -58, "shortest fight counted", C.Min, function(v) d().min = v end, 0, 60, 5, " s")
  p.wid = stepRow(p, -76, "width", function() return (C.Size()) end, function(v) d().w = v C.Layout() end, C.W_MIN, C.W_MAX, C.STEP, " px")
  p.hei = stepRow(p, -94, "height", function() return select(2, C.Size()) end, function(v) d().h = v C.Layout() end, C.H_MIN, C.H_MAX, C.STEP, " px")
  p.reset = swRow(p, -118, "RESET  (the look - never your fights)")
  p.reset:SetScript("OnClick", function() local x = d() x.w, x.h, x.card, x.min, x.scroll, x.tapeStyle = nil, nil, nil, nil, nil, nil C.Layout() C.StyleChanged() C.PaintSet() end)
  p:Hide()
  f.sw = p
  return p
end
function C.PaintSet()
  local p = C.frame and C.frame.sw
  if not p then return end
  for _, k in ipairs({ "card", "scroll", "style", "min", "wid", "hei" }) do if p[k] and p[k].paint then p[k].paint() end end
  C.Paint()
end
--- The style switched: the other one's paper or floating text put away.
function C.StyleChanged()
  if C.Clean() then if C.tape then C.TapeClear() end
  elseif C.float then
    for _, l in ipairs(C.float.lines) do l:Hide() C.float.spare[#C.float.spare + 1] = l end
    C.float.lines = {}
    C.float.due:Hide()
    C.float:Hide()
  end
end
function C.ToggleSet(want)
  local p = C.BuildSet()
  if not p then return false end
  if want == nil then want = not p:IsShown() end
  if want then p:Show() C.PaintSet() else p:Hide() end
  return p:IsShown()
end

--- A row's names on hover (the icons carry no words).
function C.RowTip(r)
  if not (r.g and GameTooltip) then return end
  GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
  GameTooltip:AddLine(r.g.imbue or "no imbue", 1, 1, 1)
  for _, n in ipairs(r.g.totems or {}) do GameTooltip:AddLine(n, 0.8, 0.8, 0.8) end
  GameTooltip:AddLine(("%d fights  -  %d dps"):format(r.g.n or 0, math.floor((r.g.dps or 0) + 0.5)), 0.6, 0.9, 0.6)
  GameTooltip:AddLine("shift-click twice: forget these fights", 0.6, 0.6, 0.6)
  GameTooltip:Show()
end
--[[ FORGET ONE COMBO (18 Nov 2026, Arn: "a way to clear a row? sometimes it does not pick up the totems and it stays there
  at the top spot"): shift-click a row = it turns pink and the foot asks; shift-click it again within C.FORGET_ARM s = every
  kept fight filed under that combo is gone (the rest stay). Anything else - another row, waiting - and nothing is lost. ]]
C.FORGET_ARM = 4
function C.Armed(combo)
  return combo ~= nil and C.forgetArm == combo and (now() - (C.forgetAt or 0)) <= C.FORGET_ARM
end
--- Every kept fight filed under `combo` gone; answers how many.
function C.ForgetCombo(combo)
  local d, keep, gone = db(), {}, 0
  for _, f in ipairs(d.fights or {}) do
    if f.combo == combo then gone = gone + 1 else keep[#keep + 1] = f end
  end
  d.fights = keep
  if C.sel == combo then C.sel = nil end
  return gone
end
--- The first shift-click arms the row, the second (in time, same row) forgets it.
function C.ForgetAsk(combo)
  if not combo then return false end
  if C.Armed(combo) then
    C.forgetArm = nil
    local gone = C.ForgetCombo(combo)
    say("combo: forgot %d %s of %s", gone, gone == 1 and "fight" or "fights", combo)
    if C.IsOpen() then C.Paint() end
    return gone
  end
  C.forgetArm, C.forgetAt = combo, now()
  C.forgetTok = (C.forgetTok or 0) + 1
  local tok = C.forgetTok
  if C_Timer and C_Timer.After then        -- (the pink goes again once the time is up)
    C_Timer.After(C.FORGET_ARM + 0.1, function() if C.forgetTok == tok and C.IsOpen() then C.Paint() end end)
  end
  if C.IsOpen() then C.Paint() end
  return false
end
function C.PaintRow(r)
  local sel = r.g and r.g.combo == C.sel
  r.lit:SetAlpha(sel and 0.35 or ((r.hover and r.g) and 0.16 or 0))
  r.bar:SetAlpha((sel or (r.hover and r.g)) and 1 or 0)
  if r.armed then r.armed:SetAlpha((r.g and C.Armed(r.g.combo)) and 0.45 or 0) end
end
function C.Paint()
  local f = C.frame
  if not f then return end
  local list = C.Rank()
  local shownRows = C.RowCount()
  for i, r in ipairs(f.rows) do
    local g = i <= shownRows and list[i] or nil
    r.g = g
    r.name:SetText("")                              -- (the four columns say it now; the name keeps the combo for tests and tips)
    r.name.combo = g and g.combo or nil
    local cells = g and C.Cells(g.imbue, g.totems) or nil
    local names = g and C.CellNames(g.imbue, g.totems) or nil
    for _, c in ipairs(C.COLS) do
      local v = cells and cells[c] or ""
      local list = names and names[c] or {}
      local drawn = 0
      for k, t in ipairs(r.icons[c]) do
        local tex = list[k] and C.IconFor(list[k])
        if tex then t:SetTexture(tex) t.name = list[k] t:Show() drawn = drawn + 1 else t.name = nil t:Hide() end
      end
      if drawn > 0 and drawn == #list then v = "" end          -- (the icons say it; a name with no icon keeps its word)
      r.cells[c]:SetText(v)
      local col = (i == 1 and g) and "gold" or (v == "-" and "muted" or "ink")
      r.cells[c]:SetTextColor(F().color(col))
    end
    r.n:SetText(g and tostring(g.n) or "")
    r.dps:SetText(g and tostring(math.floor(g.dps + 0.5)) or "")
    r.adj:SetText(g and tostring(math.floor(g.adj + 0.5)) or "")
    C.PaintRow(r)
  end
  local tiles, last = C.StatTiles(C.sel or (list[1] and list[1].combo))
  for i, t in ipairs(f.tiles or {}) do C.PaintTile(t, tiles[i]) end
  f.detail:SetText(last or (#list > 0 and "click a combo: its numbers" or "no fights yet - fight something with an imbue and totems up"))
  f.foot:SetText(C.Min() > 0 and ("%d fights kept  ·  fights under %d s are not counted"):format(#(db().fights or {}), C.Min())
    or ("%d fights kept  ·  dps over the time you swing"):format(#(db().fights or {})))
  f.foot:SetTextColor(F().color("dim"))
  if C.forgetArm and C.Armed(C.forgetArm) then
    local n = 0
    for _, fi in ipairs(db().fights or {}) do if fi.combo == C.forgetArm then n = n + 1 end end
    f.foot:SetText(("shift-click it again: forget its %d %s"):format(n, n == 1 and "fight" or "fights"))
    f.foot:SetTextColor(F().color("warn"))
  end
  C.PaintTry()
end
--[[ THE NUMBERS UNDER THE LIST (17 Nov 2026, Arn: "maybe we can put better information at the bottom, like proc %, lifetime,
  other relevant info, maybe something to do with gear, crit chance"): for the combo clicked (else the best one), over
  every fight it has - how often Windfury and Flametongue came on YOUR swings (procs / your own swings, counted since the
  tape learned to tell yours: rec.swings), its average and best dps and Windfury's share of the damage; its newest fight;
  and you now: melee crit, attack power, weapon speed and damage, read out of a fight (C.Gear). ]]
function C.StatLines(combo)
  local out = {}
  if not combo then out[1] = C.GearLine() return out end
  local n, dmg, secs, best, wfDmg, sw, wfP, ftP, lastF = 0, 0, 0, 0, 0, 0, 0, 0, nil
  local fbP = 0
  for _, fi in ipairs(db().fights or {}) do
    if fi.combo == combo and (fi.dur or 0) >= C.Min() then
      n = n + 1
      local t = C.Time(fi)
      dmg, secs = dmg + (fi.dmg or 0), secs + t
      wfDmg = wfDmg + (fi.dmg or 0) * (fi.wf or 0)
      if t > 0 and fi.dmg / t > best then best = fi.dmg / t end
      if fi.swings and fi.swings > 0 and fi.procs then
        sw = sw + fi.swings
        wfP = wfP + (fi.procs.extra1 or 0) + (fi.procs.extra2 or 0) + (fi.procs.more or 0)
        ftP = ftP + (fi.procs.fire or 0)
        fbP = fbP + (fi.procs.frost or 0)
      end
      lastF = fi
    end
  end
  if n == 0 then out[1] = C.GearLine() return out end
  if sw > 0 then
    out[#out + 1] = ("PROCS  Windfury on %d%% of your swings  -  Flametongue %d%%%s   (%d swings)"):format(
      math.floor(wfP / sw * 100 + 0.5), math.floor(ftP / sw * 100 + 0.5),
      fbP > 0 and ("  -  Frostbrand %d%%"):format(math.floor(fbP / sw * 100 + 0.5)) or "", sw)
  else
    out[#out + 1] = "PROCS  counted from your next fight with it"
  end
  local gaps, gn = 0, 0
  for _, fi in ipairs(db().fights or {}) do
    if fi.combo == combo and fi.gap ~= nil and (fi.dur or 0) >= C.Min() then gaps, gn = gaps + fi.gap, gn + 1 end
  end
  if gn > 0 then
    local avg = gaps / gn
    local P = C.LevelPenalty(math.floor(avg + 0.5))
    out[#out + 1] = ("LEVELS  mobs %s%.1f on average: miss %.0f%%, dodge %.0f%%%s"):format(avg >= 0 and "+" or "", avg, P.miss, P.dodge,
      P.glance > 0 and (", glancing %.0f%% (-%.0f%%)"):format(P.glance, P.cut) or "")
  end
  out[#out + 1] = ("%d %s  -  %d dps average, best %d  -  Windfury %d%% of the damage"):format(n, n == 1 and "fight" or "fights",
    math.floor((secs > 0 and dmg / secs or 0) + 0.5), math.floor(best + 0.5), math.floor((dmg > 0 and wfDmg / dmg or 0) * 100 + 0.5))
  if lastF then
    out[#out + 1] = ("last: %s  %s  %d dps"):format(lastF.mob or "?", lastF.active and ("%d/%d s"):format(math.floor(lastF.active + 0.5),
      math.floor(lastF.dur + 0.5)) or ("%d s"):format(math.floor(lastF.dur + 0.5)), math.floor(lastF.dmg / C.Time(lastF) + 0.5))
    local parts = {}
    for k = 1, math.min(3, #(lastF.spells or {})) do
      parts[#parts + 1] = ("%s %d%%"):format(lastF.spells[k].name, math.floor(lastF.spells[k].share * 100 + 0.5))
    end
    if #parts > 0 then out[#out] = out[#out] .. "  -  " .. table.concat(parts, ", ") end
  end
  out[#out + 1] = C.GearLine()
  return out
end
function C.MakeTile(f)
  local K = F()
  local t = CreateFrame("Frame", nil, f)
  K.tex(t, "BACKGROUND", "field", 0.85)
  K.border(t, "edge", 1)
  t.label = K.fs(t, "", 8, "dim")
  t.label:SetPoint("TOPLEFT", 4, -3)
  t.value = K.fs(t, "", 12, "ink")
  t.value:SetPoint("BOTTOMLEFT", 4, 3)
  t.value:SetJustifyH("LEFT")
  if t.value.SetWordWrap then t.value:SetWordWrap(false) end
  t:EnableMouse(true)
  t:SetScript("OnEnter", function(self)
    if not (self.tip and GameTooltip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    for k, line in ipairs(self.tip) do
      if k == 1 then GameTooltip:AddLine(line, 1, 1, 1) else GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
    end
    GameTooltip:Show()
  end)
  t:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return t
end
--- One box: { label, value, colour key, tip lines } - nil = an empty box, its frame still there (the grid keeps its shape).
function C.PaintTile(t, d)
  if not d then t.label:SetText("") t.value:SetText("") t.tip = nil t:SetAlpha(0.35) return end
  t:SetAlpha(1)
  t.label:SetText(d[1])
  t.value:SetText(d[2])
  t.value:SetTextColor(F().color(d[3] or "ink"))
  t.tip = d[4]
end
--- The twelve boxes for a combo (nil = the best), and the last fight's line.
function C.StatTiles(combo)
  local out = {}
  local n, dmg, secs, best, wfDmg, sw, wfP, ftP, fbP, lastF, gaps, gn = 0, 0, 0, 0, 0, 0, 0, 0, 0, nil, 0, 0
  for _, fi in ipairs(combo and db().fights or {}) do
    if fi.combo == combo and (fi.dur or 0) >= C.Min() then
      n = n + 1
      local t = C.Time(fi)
      dmg, secs = dmg + (fi.dmg or 0), secs + t
      wfDmg = wfDmg + (fi.dmg or 0) * (fi.wf or 0)
      if t > 0 and fi.dmg / t > best then best = fi.dmg / t end
      if fi.swings and fi.swings > 0 and fi.procs then
        sw = sw + fi.swings
        wfP = wfP + (fi.procs.extra1 or 0) + (fi.procs.extra2 or 0) + (fi.procs.more or 0)
        ftP = ftP + (fi.procs.fire or 0)
        fbP = fbP + (fi.procs.frost or 0)
      end
      if fi.gap ~= nil then gaps, gn = gaps + fi.gap, gn + 1 end
      lastF = fi
    end
  end
  local function pct(x) return sw > 0 and (math.floor(x / sw * 100 + 0.5) .. "%") or "-" end
  if n > 0 then
    out[1] = { "WINDFURY", pct(wfP), "gold", { "Windfury procs", "On this share of your own swings, over every fight with this combo since the tape counts your swings.",
      ("Windfury did %d%% of the damage."):format(math.floor((dmg > 0 and wfDmg / dmg or 0) * 100 + 0.5)) } }
    out[2] = { "FLAMETONGUE", pct(ftP), "warn", { "Flametongue procs", "On this share of your own swings (the imbue's and the totem's fire hits)." } }
    out[3] = { "FROSTBRAND", pct(fbP), "accent", { "Frostbrand procs", "On this share of your own swings." } }
    out[4] = { "SWINGS", tostring(sw), "ink", { "Your swings counted", "Only your own (someone else's hits on your target are left out)." } }
    out[5] = { "FIGHTS", tostring(n), "ink", { "Fights with this combo" } }
    out[6] = { "AVERAGE", tostring(math.floor((secs > 0 and dmg / secs or 0) + 0.5)), "good", { "Average dps", "Over the time you were swinging." } }
    out[7] = { "BEST", tostring(math.floor(best + 0.5)), "good", { "Best fight's dps" } }
    if gn > 0 then
      local avg = gaps / gn
      local P = C.LevelPenalty(math.floor(avg + 0.5))
      out[8] = { "MOB LEVEL", ("%s%.1f"):format(avg >= 0 and "+" or "", avg), avg > 0.5 and "warn" or "ink",
        { "Mobs' level against yours, on average", ("Miss %.1f%%, dodge %.1f%%%s (Classic's melee table)."):format(P.miss, P.dodge,
          P.glance > 0 and (", glancing %d%% for %d%% less"):format(P.glance, P.cut) or ""), "The adj column counts every fight as if the mob were your level." } }
    else
      out[8] = { "MOB LEVEL", "-", "muted", { "Mobs' level", "Kept from tonight's fights on." } }
    end
  end
  local g, base = C.Gear(), n > 0 and 8 or 0
  out[base + 1] = { "CRIT", g.crit and ("%.1f%%"):format(g.crit) or "-", "ink", { "Your melee crit chance now" } }
  out[base + 2] = { "ATTACK POWER", g.ap and tostring(g.ap) or "-", "ink", { "Your attack power now" } }
  out[base + 3] = { "WEAPON", g.speed and ("%.1f s"):format(g.speed) or "-", "ink", { "Your weapon's speed now" } }
  out[base + 4] = { "DAMAGE", g.lo and ("%d-%d"):format(math.floor(g.lo + 0.5), math.floor(g.hi + 0.5)) or "-", "ink", { "Your weapon's damage now" } }
  local line
  if lastF then
    line = ("last: %s  %s  %d dps"):format(lastF.mob or "?", lastF.active and ("%d/%d s"):format(math.floor(lastF.active + 0.5),
      math.floor(lastF.dur + 0.5)) or ("%d s"):format(math.floor(lastF.dur + 0.5)), math.floor(lastF.dmg / C.Time(lastF) + 0.5))
    local parts = {}
    for k = 1, math.min(3, #(lastF.spells or {})) do
      parts[#parts + 1] = ("%s %d%%"):format(lastF.spells[k].name, math.floor(lastF.spells[k].share * 100 + 0.5))
    end
    if #parts > 0 then line = line .. "  -  " .. table.concat(parts, ", ") end
  end
  return out, line
end
--- You now: melee crit, attack power, the weapon's speed and damage (plain answers only; read out of a fight, kept).
function C.Gear()
  if not (InCombatLockdown and InCombatLockdown()) then
    local g = {}
    if GetCritChance then local ok, v = pcall(GetCritChance) v = ok and plain(v) if type(v) == "number" then g.crit = v end end
    if UnitAttackPower then
      local ok, base, pos, neg = pcall(UnitAttackPower, "player")
      base, pos, neg = plain(base), plain(pos), plain(neg)
      if ok and type(base) == "number" then g.ap = base + (type(pos) == "number" and pos or 0) + (type(neg) == "number" and neg or 0) end
    end
    local mh = C.Speeds()
    g.speed = mh
    if UnitDamage then
      local ok, lo, hi = pcall(UnitDamage, "player")
      lo, hi = plain(lo), plain(hi)
      if ok and type(lo) == "number" and type(hi) == "number" then g.lo, g.hi = lo, hi end
    end
    C.gear = g
  end
  return C.gear or {}
end
function C.GearLine()
  local g, parts = C.Gear(), {}
  if g.crit then parts[#parts + 1] = ("crit %.1f%%"):format(g.crit) end
  if g.ap then parts[#parts + 1] = ("attack power %d"):format(g.ap) end
  if g.speed then parts[#parts + 1] = ("%.1f s weapon"):format(g.speed) end
  if g.lo then parts[#parts + 1] = ("%d-%d damage"):format(math.floor(g.lo + 0.5), math.floor(g.hi + 0.5)) end
  return #parts > 0 and ("YOU NOW  " .. table.concat(parts, "  -  ")) or ""
end
--[[ ONTO THE DECK (18 Nov 2026, Arn: "can we API-send the totems to BiS Healing's totem click areas - it's having me test a new
  totem setup, I click something and it changes the totems on my BiS Healing deck - out of combat of course"): a combo's
  totems, each under its element, go to BiSHealingAPI.SetTotems (version 3+); its totem boxes drop them from the next click.
  Water is never touched (no combo has one). Out of a fight only. ]]
function C.DeckCan()
  local A = rawget(_G, "BiSHealingAPI")
  return type(A) == "table" and type(A.SetTotems) == "function" and (tonumber(A.version) or 0) >= 3
end
--- Why the deck can't take totems: BiS Healing missing, or too old.
function C.DeckMissing()
  if type(rawget(_G, "BiSHealingAPI")) ~= "table" then return "Install BiS Healing to send these totems to its deck." end
  return "Update BiS Healing to send these totems to its deck."
end
function C.SendDeck(totems)
  if not C.DeckCan() then say("combo: %s", C.DeckMissing()) return false end
  if InCombatLockdown and InCombatLockdown() then say("combo: out of a fight only") return false end
  local set, words = {}, {}
  for _, name in ipairs(totems or {}) do
    local el = C.ELEMENT[name]
    if el and not set[el] then set[el] = name words[#words + 1] = C.COL_WORD[name] or name end
  end
  if not next(set) then say("combo: that combo has no totems to send") return false end
  local ok, a, why = pcall(BiSHealingAPI.SetTotems, set)
  if ok and a then
    say("combo: your deck's totem boxes now drop %s", table.concat(words, " · "))
    return true
  end
  say("combo: the deck said no (%s)", tostring(ok and why or a))
  return false
end
function C.PaintTry()
  local tr = C.frame and C.frame.try
  if not tr then return end
  local c, total, untried = C.TryNext()
  tr.c = c
  local names = {}
  if c then
    if c.imbue then names[#names + 1] = c.imbue end
    for _, n in ipairs(c.totems) do names[#names + 1] = n end
  end
  for k, t in ipairs(tr.icons) do
    local tex = names[k] and C.IconFor(names[k])
    if tex then t:SetTexture(tex) t.name = names[k] t:Show() else t.name = nil t:Hide() end
  end
  if c then
    tr.note:SetText(c.n == 0 and ("never tried  -  %d of %d combos untried"):format(untried or 0, total or 0)
      or ("only %d fights  -  %d combos to compare"):format(c.n, total or 0))
  elseif total then
    tr.note:SetText(("every combo you know has %d+ fights: the ranking holds"):format(C.TRY_ENOUGH))
  else
    tr.note:SetText("learn an imbue or a totem first")
  end
  tr.note:SetPoint("LEFT", tr, "LEFT", 62 + #names * (C.TRY_H - 2) + 4, 0)
  -- (18 Nov, Arn: "the button would still be clickable but say install BiS Healing to send to deck" - always there with a
  -- suggestion, dimmed when the deck can't take it; a click says what to install)
  if tr.deck then
    if c then tr.deck:Show() else tr.deck:Hide() end
    tr.deck.label:SetTextColor(F().color(C.DeckCan() and "gold" or "muted"))
  end
end
function C.IsOpen() return C.frame ~= nil and C.frame:IsShown() end
-- OPEN STAYS OPEN (17 Nov 2026, Arn: "combo window closes every time I reload and it says on in the options"): the
-- list remembers it was up (db.open) and comes back at login; the x / /bist combo closing it writes that down too.
function C.Toggle(want)
  local f = C.Build()
  if want == nil then want = not f:IsShown() end
  if want then C.Layout() f:Show() C.Paint() else f:Hide() end
  db().open = f:IsShown() and true or false
  if not want and debugstack then C.closedBy = (debugstack(2, 1, 0) or ""):gsub("%s+$", "") end
  return f:IsShown()
end

-- ---------------------------------------------------------------- the probe (kept: /bist combo probe)
local function kind(v)
  if v == nil then return "nil" end
  if issecretvalue and issecretvalue(v) then return "SECRET" end
  return tostring(v)
end
local function shape(t, max)
  if type(t) ~= "table" then return kind(t) end
  local parts, n = {}, 0
  local ok = pcall(function()
    for k, v in pairs(t) do
      n = n + 1
      if n > (max or 12) then break end
      parts[#parts + 1] = tostring(k) .. "=" .. (type(v) == "table" and "{table}" or kind(v))
    end
  end)
  if not ok then return "(refused)" end
  return "{" .. table.concat(parts, ", ") .. "}"
end
function C.Probe()
  local lines = {}
  local function out(fmt, ...) local l = string.format(fmt, ...) lines[#lines + 1] = l say("%s", l) end
  if GetWeaponEnchantInfo then
    local ok, mh, mhExp, mhCh, mhId, oh, _, _, ohId = pcall(GetWeaponEnchantInfo)
    if ok then
      out("imbue: main hand %s (id %s, %s ms left, charges %s) | off hand %s (id %s)", kind(mh), kind(mhId), kind(mhExp), kind(mhCh), kind(oh), kind(ohId))
    else out("imbue: GetWeaponEnchantInfo refused") end
  else out("imbue: no GetWeaponEnchantInfo") end
  if GetTotemInfo then
    local t = {}
    for slot = 1, 4 do
      local ok, have, name = pcall(GetTotemInfo, slot)
      t[#t + 1] = slot .. "=" .. (ok and (kind(have) .. ":" .. kind(name)) or "refused")
    end
    out("totems: %s", table.concat(t, "  "))
  end
  local D = C_DamageMeter
  if not D then out("damage meter: no C_DamageMeter") return lines end
  local okA, avail = pcall(D.IsDamageMeterAvailable)
  out("damage meter: available %s", okA and kind(avail) or "refused")
  local E = Enum or {}
  local T, ST = E.DamageMeterType or {}, E.DamageMeterSessionType or {}
  out("enums: type %s | session %s", shape(T, 10), shape(ST, 6))
  local okS, sessions = pcall(D.GetAvailableCombatSessions)
  out("sessions: %s", okS and (type(sessions) == "table" and ("#" .. #sessions .. " " .. shape(sessions[#sessions] or sessions[1], 8)) or kind(sessions)) or "refused")
  local dmg = T.DamageDone or 0
  local s, how
  if okS and type(sessions) == "table" and #sessions > 0 then
    local last = sessions[#sessions]
    local id = type(last) == "table" and (last.sessionID or last.combatSessionID or last.id) or last
    local ok, v = pcall(D.GetCombatSessionFromID, id, dmg)
    s, how = ok and v or nil, "by id " .. kind(id)
  end
  if not s and ST.Current then
    local ok, v = pcall(D.GetCombatSessionFromType, ST.Current, dmg)
    s, how = ok and v or nil, "current"
  end
  out("newest fight (%s): %s", tostring(how), shape(s, 10))
  if type(s) ~= "table" then return lines end
  local me = UnitGUID and UnitGUID("player")
  local mine
  local okL = pcall(function()
    for i, src in ipairs(s.combatSources or {}) do
      if i <= 5 then out("source %d: %s", i, shape(src, 10)) end
      if plain(src.isLocalPlayer) == true then mine = src end
    end
  end)
  if not okL then out("sources: refused") end
  out("you in it: %s", mine and "yes" or "not found")
  local okP, mineSpells
  if s.sessionID or s.combatSessionID then
    okP, mineSpells = pcall(D.GetCombatSessionSourceFromID, s.sessionID or s.combatSessionID, dmg, me)
  end
  if not (okP and type(mineSpells) == "table") and ST.Current then
    okP, mineSpells = pcall(D.GetCombatSessionSourceFromType, ST.Current, dmg, me)
  end
  out("your breakdown: %s", okP and shape(mineSpells, 10) or "refused")
  if okP and type(mineSpells) == "table" then
    pcall(function()
      for i, sp in ipairs(mineSpells.combatSpells or {}) do
        if i > 8 then break end
        local id = sp.spellID
        local name = (id ~= nil and not (issecretvalue and issecretvalue(id)) and C_Spell and C_Spell.GetSpellName) and C_Spell.GetSpellName(id) or "?"
        out("  spell %d: %s (%s) total %s %s", i, tostring(name), kind(id), kind(sp.totalAmount), shape(sp, 6))
      end
    end)
  end
  C.lastProbe = lines
  return lines
end

-- ---------------------------------------------------------------- the proc text (scrolling, in a fight)
--[[ THE PROC TEXT (17 Nov 2026, Arn: "a scrolling proc text so we can see when we get procs, dont need numbers, just you
  got 1 extra hit, 1 extra flametongue" - then, the meter hidden in a fight: "can we just see when we got 2 melee hits back
  to back and 3"). UNIT_COMBAT still fires on Forever (solved.md, 1 Oct), one call per hit your TARGET takes - "target"
  only (the same mob also arrives as nameplateN, softenemy... - asked once). Windfury's extra swings land in the same
  instant as the swing that procced it: hits within C.BURST s are one burst. Physical hits in a burst: 2 = "+1 extra hit"
  (the totem's), 3 = "+2 extra hits" (the weapon's; Arn: "totem is 1 extra hit, imbue is 2"), more = "+N extra hits";
  a fire hit inside a burst with a swing = "Flametongue". Nothing compared but the action word and the school, and only
  when plain; a hidden school counts as a swing. In a group, others hitting your target in the same instant can read as a
  proc (it is a solo tool first). Each fight counts its procs (rec.procs). Each one prints on the receipt tape (below);
  db.scroll turns it off. ]]
-- (C.BURST 0.25, 17 Nov - Arn: "still not seeing the live procs": 0.12 s may be shorter than the gap the extra swings
-- arrive with; a swing is 1.5 s or more, so a quarter second is still one instant. A HIDDEN action word now counts as a
-- swing (it was dropped); C.hitStats is what the game sent, for /bist combo why.)
C.BURST = 0.25
-- THE BATCH (17 Nov 2026, Arn's /bist combo why after two fights: 57 hits heard, all plain - but the gaps sat at 0.3-0.6 s
-- (19), only one under 0.05 s, and fire hits (his Flametongue Totem) about one per swing): Forever hands combat results
-- out in batches, so the extra hits land a batch after the swing, not in its instant. A burst is now C.BURST_MAX s, or
-- C.BURST_K of your swing time when that is shorter - never reaching into the next real swing.
C.BURST_MAX, C.BURST_K = 0.7, 0.45
function C.BurstWindow()
  local sp = (C.Speed and C.Speed()) or 2.5
  return math.min(C.BURST_MAX, sp * C.BURST_K)
end
C.SWING_ACTIONS = { WOUND = true, MISS = true, DODGE = true, PARRY = true, BLOCK = true, DEFLECT = true, ABSORB = true, RESIST = true, IMMUNE = true, EVADE = true }
--- What the game sent this fight: how many hits, the action word plain / hidden, the schools, the gaps between hits.
local function stat(cur, action, school, now)
  local st = cur.hitStats
  if not st then st = { n = 0, actPlain = 0, actHidden = 0, acts = {}, schools = {}, gaps = { 0, 0, 0, 0, 0 } } cur.hitStats = st end
  st.n = st.n + 1
  if action == nil then st.actHidden = st.actHidden + 1 else st.actPlain = st.actPlain + 1 st.acts[action] = (st.acts[action] or 0) + 1 end
  local sk = school == nil and "hidden" or tostring(school)
  st.schools[sk] = (st.schools[sk] or 0) + 1
  if st.last then
    local g = now - st.last
    local i = (g < 0.05 and 1) or (g < 0.15 and 2) or (g < 0.3 and 3) or (g < 0.6 and 4) or 5
    st.gaps[i] = st.gaps[i] + 1
  end
  st.last = now
end
function C.HitLine(st)
  if not st then return "no hits on your target were heard" end
  local acts, schools = {}, {}
  for k, v in pairs(st.acts) do acts[#acts + 1] = k .. " " .. v end
  for k, v in pairs(st.schools) do schools[#schools + 1] = k .. " " .. v end
  local g = st.gaps
  return ("%d hits heard - action plain %d (%s), hidden %d - school %s - gaps <0.05s %d, <0.15 %d, <0.3 %d, <0.6 %d, longer %d"):format(
    st.n, st.actPlain, table.concat(acts, ", "), st.actHidden, table.concat(schools, ", "), g[1], g[2], g[3], g[4], g[5])
end
function C.Hit(action, school)
  local cur = C.cur
  if not cur then return end
  local now = GetTime and GetTime() or 0
  action = plain(action)
  school = plain(school)
  stat(cur, action, school, now)
  if cur.gap == nil then cur.gap, cur.skull = C.TargetGap() end
  if action ~= nil and (type(action) ~= "string" or not C.SWING_ACTIONS[action]) then return end   -- (a heal, a plain non-swing)
  -- ONLY A PHYSICAL HIT IS A SWING (17 Nov 2026, Arn on Frostbrand: "+1"s printed with no Windfury - its frost hits were
  -- counted as swings). Fire (4) is Flametongue's, frost (16) Frostbrand's, any other magic school nobody's swing; a
  -- hidden school still counts as a swing (it usually is one).
  local sch = type(school) == "number" and school or nil
  local b = cur.burst
  local win = C.BurstWindow()
  if not b or now - b.at > win then
    b = { at = now, swings = 0, fire = 0, frost = 0 }
    cur.burst = b
    if C_Timer and C_Timer.After then C_Timer.After(win + 0.02, function() C.CloseBurst(cur, b) end) end
  end
  if sch == 4 then b.fire = b.fire + 1
  elseif sch == 16 then b.frost = (b.frost or 0) + 1
  elseif sch == nil or sch == 1 then b.swings = b.swings + 1 end
end
--[[ THE SWING CADENCE (17 Nov 2026, Arn: "a weak aura used to determine range as idle time in the swings ... as long as I'm in
  combat and my melee is not in cadence it's considered out of range"). Each burst with a swing is a beat; the active time
  is the sum of the gaps between beats, each gap at most C.CADENCE x your weapon speed (UnitAttackSpeed, plain; else
  C.SPEED_GUESS) - a longer gap means the mob ran, you ran, or auto-attack was off, and only the swing's own time counts.
  The last beat adds one swing. With C.CADENCE_MIN beats or more it decides the fight's active time; fewer, the reach
  ticker (above) does. Two weapons interleave into short gaps that add up to the real time. ]]
C.CADENCE, C.CADENCE_MIN, C.SPEED_GUESS = 1.25, 3, 2.5
function C.Speed()
  if not UnitAttackSpeed then return C.SPEED_GUESS end
  local ok, mh = pcall(UnitAttackSpeed, "player")
  if ok then mh = plain(mh) else mh = nil end
  if type(mh) == "number" and mh > 0.5 and mh < 6 then return mh end
  return C.SPEED_GUESS
end
function C.Beat(cur, at)
  local sp = C.Speed()
  cur.beats = (cur.beats or 0) + 1
  if cur.lastBeat then cur.cadence = (cur.cadence or 0) + math.min(at - cur.lastBeat, sp * C.CADENCE) end
  cur.lastBeat, cur.lastSpeed = at, sp
end
--[[ ONLY YOUR OWN SWINGS (17 Nov 2026, Arn: "I think the tape is reading other shaman hits"; his save: 30 s fights with 29
  "swings", 20 Windfury procs - and the meter after them said none of his damage was Windfury). UNIT_COMBAT says what your
  target took, never from whom, so a burst is yours only if it lands on YOUR swing clock: at least C.OWN_K x your weapon's
  speed after your last one (each hand its own clock when you hold two). Anything sooner is someone else's - no proc, no
  beat - counted in cur.foreign for /bist combo why. In a group a stranger's swing can still land on your clock now and
  then; after the fight the meter checks (C.MeterCheck). ]]
C.OWN_K = 0.75
function C.Speeds()
  if not UnitAttackSpeed then return C.SPEED_GUESS, nil end
  local ok, mh, oh = pcall(UnitAttackSpeed, "player")
  if not ok then return C.SPEED_GUESS, nil end
  mh, oh = plain(mh), plain(oh)
  if not (type(mh) == "number" and mh > 0.5 and mh < 6) then mh = C.SPEED_GUESS end
  if not (type(oh) == "number" and oh > 0.5 and oh < 6) then oh = nil end
  return mh, oh
end
--- Is this burst on your swing clock? (and if so the clock moves to it)
function C.OwnSwing(cur, at)
  local mh, oh = C.Speeds()
  if not cur.lastMH or at - cur.lastMH >= mh * C.OWN_K then cur.lastMH = at return true end
  if oh and (not cur.lastOH or at - cur.lastOH >= oh * C.OWN_K) then cur.lastOH = at return true end
  return false
end
function C.CloseBurst(cur, b)
  if b.done then return end
  b.done = true
  if b.swings > 0 and not C.OwnSwing(cur, b.at) then
    cur.foreign = (cur.foreign or 0) + 1
    return
  end
  if b.swings > 0 then C.Beat(cur, b.at) end
  cur.procs = cur.procs or { extra1 = 0, extra2 = 0, more = 0, fire = 0 }
  local extra = b.swings - 1
  local words = {}
  -- WHOSE WINDFURY (17 Nov 2026, Arn: "if I have imbue WF we can safely assume it's +2 hits - right now it's showing as 1;
  -- people can have the WF imbue and totem, so it's going to be hard to say for sure"): Forever's batches split the
  -- weapon's two extra swings, so a burst often holds only one of them. With the weapon's Windfury on and no Windfury
  -- Totem down this fight, any extra swing is the weapon's: +2. With both, the count decides as before.
  local im = cur.nowImbue or cur.imbue
  local weapon = type(im) == "string" and im:find("Windfury", 1, true) and true or false
  local tot = cur.nowTot or cur.totems or {}
  local totem = (tot["Windfury Totem"] or cur.wfAura) and true or false
  -- NO WINDFURY, NO WINDFURY PROC (17 Nov 2026, Arn's tape: "I don't have Windfury but it's counting ... like I have
  -- Windfury" - and the meter agreed none were his): two hits in one moment with no Windfury up (your imbue, your totem,
  -- or a party member's Windfury Totem buff on you - cur.wfAura) were someone else's - nothing counted. Flametongue the
  -- same: no more fire hits counted on a swing than Flametongue sources you have up (the imbue, the totem: Forever stacks
  -- them, so two can be real).
  if not (weapon or totem) then extra = 0 end
  local ftSources = ((type(im) == "string" and im:find("Flametongue", 1, true)) and 1 or 0)
    + ((tot["Flametongue Totem"] or cur.ftAura) and 1 or 0)
  local fireN = math.min(b.fire, ftSources)
  local frostN = ((type(im) == "string" and im:find("Frostbrand", 1, true)) and math.min(b.frost or 0, 1)) or 0
  if extra == 1 and weapon and not totem then extra = 2 end
  -- ICONS ON THE TAPE (17 Nov 2026, Arn: "on the receipt we can actually save so much space by just using icons"): one line
  -- a swing - the Windfury that procced as its icon and +N, Flametongue's icon and +N beside it (the totem's when one
  -- stands, else the weapon's), drawn inside the text (C.Ico), so a line stays short and never wraps
  local wfIcon = (extra == 1 and totem) and "Windfury Totem" or "Windfury Weapon"
  if extra == 1 then cur.procs.extra1 = cur.procs.extra1 + 1 words[#words + 1] = C.Ico(wfIcon, "WF") .. " +1"
  elseif extra == 2 then cur.procs.extra2 = cur.procs.extra2 + 1 words[#words + 1] = C.Ico("Windfury Weapon", "WF") .. " +2"
  elseif extra > 2 then cur.procs.more = cur.procs.more + 1 words[#words + 1] = C.Ico("Windfury Weapon", "WF") .. " +" .. extra end
  local fireOnly = false
  if fireN > 0 and b.swings > 0 then
    cur.procs.fire = cur.procs.fire + 1
    local ft = (cur.nowTot or cur.totems or {})["Flametongue Totem"] and "Flametongue Totem" or "Flametongue Weapon"
    words[#words + 1] = C.Ico(ft, "FT") .. " +" .. fireN
    fireOnly = #words == 1
  end
  if frostN > 0 and b.swings > 0 then                            -- (Frostbrand: its frost hit with your swing)
    cur.procs.frost = (cur.procs.frost or 0) + 1
    words[#words + 1] = C.Ico("Frostbrand Weapon", "FB") .. " +1"
    fireOnly = false
  end
  if db().scroll ~= false and C.Clean() then
    local parts = {}
    if extra >= 1 then parts[#parts + 1] = { C.Ico(extra == 1 and wfIcon or "Windfury Weapon", "WF") .. " WINDFURY +" .. extra, "wf" } end
    if fireN > 0 and b.swings > 0 then
      local ft = tot["Flametongue Totem"] and "Flametongue Totem" or "Flametongue Weapon"
      parts[#parts + 1] = { C.Ico(ft, "FT") .. " FT +" .. fireN, "ft" }
    end
    if frostN > 0 and b.swings > 0 then parts[#parts + 1] = { C.Ico("Frostbrand Weapon", "FB") .. " FB +1", "fb" } end
    if #parts > 0 then C.FloatLine(parts) end
    local kind = C.DueKind(weapon or totem, im, ftSources)
    if b.swings > 0 and kind then
      C.DueTick(cur, (kind == "wf" and extra >= 1) or (kind == "fb" and frostN > 0) or (kind == "ft" and fireN > 0), kind)
    elseif b.swings > 0 and C.float and C.float.due then
      C.float.due:Hide()                                         -- (no proc up at all, e.g. Rockbiter alone: no gauge)
    end
    return
  end
  if #words > 0 and db().scroll ~= false then C.Scroll(table.concat(words, "    "), fireOnly) end
end
--[[ THE CLEAN TAPE (17 Nov 2026, Arn: "my cousin does not want any extra information on the tape - make the background
  transparent, like scrolling combat text ... it'll just say WINDFURY +2 FT +1 in the same line ... and maybe a % proc chance
  rolling, like so far you have 18% lifetime getting a Windfury proc, a fake one due any second" - then "build the clean
  tape mode for my cousin"). db.tapeStyle = "clean": no paper, no setup / CUT / TOTAL lines - each swing's procs float up
  on one line in big outlined letters (Windfury gold, Flametongue orange, Frostbrand blue) and fade; under them the
  WINDFURY DUE gauge: your lifetime Windfury rate (C.WFRate, from your own swings in fights with Windfury up) times the
  swings since your last proc - full = "any second". Just for fun: every swing is its own roll; its tooltip says so. The
  gauge is the handle: drag it out of a fight (db.tapePos, the tape's spot). Nothing ticks once the last line has faded. ]]
C.FLOAT = { w = 320, h = 130, rise = 70, life = 1.8, fade = 0.6, size = 17, push = 20, dueW = 150, dueH = 8, dueHold = 6 }
C.FLOAT_COL = { wf = "ffd33a", ft = "ff7a2a", fb = "7ec4ff" }
function C.Clean() return db().tapeStyle == "clean" end
--[[ THE GAUGE NAMES YOUR PROC (18 Nov 2026, Arn: "if no wf imbue or totem detected change to any proc name where it says
  windfury"): Windfury when it is up (your imbue, your totem, a party member's totem buff), else Frostbrand (your imbue),
  else Flametongue (imbue or totem); none of them (Rockbiter alone) = no gauge. Each its own rate, from the fights it was
  up in. A change of kind mid-fight starts the count again. ]]
C.DUE_NAME = { wf = "WINDFURY", fb = "FROSTBRAND", ft = "FLAMETONGUE" }
C.AURA_LINGER = 11
C.DUE_TIP = { wf = "Windfury", fb = "Frostbrand", ft = "Flametongue" }
--- Which proc the gauge follows: "wf", else "fb", else "ft", else nil.
function C.DueKind(wfUp, imbue, ftSources)
  if wfUp then return "wf" end
  if type(imbue) == "string" and imbue:find("Frostbrand", 1, true) then return "fb" end
  if (ftSources or 0) > 0 then return "ft" end
  return nil
end
--- Your rate for one proc kind: procs / your own swings, over fights it was up in (nil under C.WF_MIN_SWINGS swings).
C.WF_MIN_SWINGS, C.WF_GUESS = 20, 0.2
function C.ProcRate(kind)
  local sw, n = 0, 0
  for _, fi in ipairs(db().fights or {}) do
    local im = type(fi.imbue) == "string" and fi.imbue or ""
    local t = {}
    for _, name in ipairs(fi.totems or {}) do t[name] = true end
    local up
    if kind == "fb" then up = im:find("Frostbrand", 1, true)
    elseif kind == "ft" then up = im:find("Flametongue", 1, true) or t["Flametongue Totem"]
    else up = im:find("Windfury", 1, true) or t["Windfury Totem"] end
    local p = fi.procs
    if up and fi.swings and fi.swings > 0 and p then
      sw = sw + fi.swings
      if kind == "fb" then n = n + (p.frost or 0)
      elseif kind == "ft" then n = n + (p.fire or 0)
      else n = n + (p.extra1 or 0) + (p.extra2 or 0) + (p.more or 0) end
    end
  end
  if sw < C.WF_MIN_SWINGS then return nil, sw end
  return n / sw, sw
end
function C.WFRate() return C.ProcRate("wf") end
local function floatPlace(g)
  g:ClearAllPoints()
  local p = db().tapePos
  if type(p) == "table" and p[1] then g:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0) return end
  local card = C.BuildCard()
  if card then g:SetPoint("TOP", card, "BOTTOM", 0, -6) else g:SetPoint("TOP", UIParent, "TOP", 0, -234) end
end
function C.Float()
  if C.float then return C.float end
  local Q = C.FLOAT
  local g = CreateFrame("Frame", "BiSToolsComboFloat", UIParent)
  g:SetSize(Q.w, Q.h)
  g:SetFrameStrata("HIGH")
  if g.EnableMouse then g:EnableMouse(false) end            -- (never in the way of a click in a fight)
  g.lines, g.spare = {}, {}
  -- the due gauge, the handle
  local d = CreateFrame("Frame", nil, g)
  d:SetSize(Q.dueW, Q.dueH + 14)
  d:SetPoint("TOP", g, "BOTTOM", 0, -2)
  d:EnableMouse(true)
  d:SetMovable(false)
  d.label = d:CreateFontString(nil, "OVERLAY")
  d.label:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
  d.label:SetPoint("TOPLEFT", 0, 0)
  d.label:SetTextColor(1, 0.82, 0.23, 1)
  d.track = d:CreateTexture(nil, "BACKGROUND")
  d.track:SetPoint("BOTTOMLEFT") d.track:SetPoint("BOTTOMRIGHT") d.track:SetHeight(Q.dueH)
  d.track:SetColorTexture(0, 0, 0, 0.55)
  d.fill = d:CreateTexture(nil, "ARTWORK")
  d.fill:SetPoint("BOTTOMLEFT", d.track, "BOTTOMLEFT", 1, 1)
  d.fill:SetHeight(Q.dueH - 2)
  d.fill:SetColorTexture(1, 0.82, 0.23, 0.9)
  d.fill:SetWidth(0.01)
  d:RegisterForDrag("LeftButton")
  d:SetScript("OnDragStart", function()
    if InCombatLockdown and InCombatLockdown() then return end
    g:SetMovable(true) g:StartMoving() g.moving = true
  end)
  local function stop()
    if not g.moving then return end
    g.moving = nil
    g:StopMovingOrSizing()
    local ok, pt, _, rp, x, y = pcall(g.GetPoint, g)
    if ok and pt then db().tapePos = { pt, rp, x, y } end
  end
  d:SetScript("OnDragStop", stop)
  g:SetScript("OnHide", stop)
  d:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    local kind = self.kind or "wf"
    local r, sw = C.ProcRate(kind)
    local word = C.DUE_TIP[kind] or "Windfury"
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(word .. " due", 1, 0.82, 0.23)
    GameTooltip:AddLine(r and ("%s has come on %d%% of your swings (%d swings so far)."):format(word, math.floor(r * 100 + 0.5), sw)
      or ("Learning your rate - %d of %d swings so far (it guesses 20%% until then)."):format(sw or 0, C.WF_MIN_SWINGS), 0.9, 0.9, 0.9, true)
    GameTooltip:AddLine("Just for fun: every swing is its own roll - a long dry spell doesn't make the next one more likely.", 0.6, 0.6, 0.6, true)
    GameTooltip:AddLine("Drag me to move the floating text (out of a fight).", 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
  end)
  d:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  g.due = d
  d:Hide()
  g:SetScript("OnUpdate", function(self, e) C.FloatStep(self, tonumber(e) or 0) end)
  g:Hide()
  floatPlace(g)
  C.float = g
  return g
end
--- One swing's procs, floating up: parts = { { text, "wf" | "ft" | "fb" }, ... }.
function C.FloatLine(parts)
  local g, Q = C.Float(), C.FLOAT
  local bits = {}
  for _, pt in ipairs(parts) do bits[#bits + 1] = "|cff" .. (C.FLOAT_COL[pt[2]] or "ffffff") .. pt[1] .. "|r" end
  local fs = table.remove(g.spare)
  if not fs then
    fs = g:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\ARIALN.TTF", Q.size, "THICKOUTLINE")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
  end
  fs:SetText(table.concat(bits, "     "))
  for _, l in ipairs(g.lines) do l.push = (l.push or 0) + Q.push end   -- (the older ones make room)
  fs.age, fs.push = 0, 0
  fs:SetAlpha(1)
  fs:Show()
  g.lines[#g.lines + 1] = fs
  g.hideAt = nil
  C.FloatLay(g)
  g:Show()
  return fs
end
function C.FloatLay(g)
  local Q = C.FLOAT
  for _, l in ipairs(g.lines) do
    l:ClearAllPoints()
    l.y = (l.push or 0) + Q.rise * math.min(1, (l.age or 0) / Q.life)
    l:SetPoint("BOTTOM", g, "BOTTOM", 0, l.y)
  end
end
function C.FloatStep(g, e)
  local Q = C.FLOAT
  for i = #g.lines, 1, -1 do
    local l = g.lines[i]
    l.age = (l.age or 0) + e
    if l.age >= Q.life then
      l:Hide()
      table.remove(g.lines, i)
      g.spare[#g.spare + 1] = l
    elseif l.age > Q.life - Q.fade then
      l:SetAlpha((Q.life - l.age) / Q.fade)
    end
  end
  C.FloatLay(g)
  local d = g.due
  if d and d:IsShown() then
    if d.flash and d.flash > 0 then d.flash = math.max(0, d.flash - e) end
    if d.full then d:SetAlpha(0.6 + 0.4 * math.abs(math.sin(GetTime and GetTime() * 4 or 0))) else d:SetAlpha(1) end
    if d.hideIn then
      d.hideIn = d.hideIn - e
      if d.hideIn <= 0 then d.hideIn = nil d:Hide() end
    end
  end
  if #g.lines == 0 and not (d and d:IsShown()) then g:Hide() end   -- (nothing left: no ticking)
end
--- Your own swing with a proc up (`kind`: C.DueKind): the gauge moves on (a proc empties it).
local function hexRGB(h) return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 end
function C.DueTick(cur, procced, kind)
  local g, Q = C.Float(), C.FLOAT
  local d = g.due
  kind = kind or "wf"
  if cur.dueKind ~= kind then cur.dueKind = kind cur.dry = 0 end   -- (another proc now: its own count)
  local r = C.ProcRate(kind) or C.WF_GUESS
  if procced then cur.dry = 0 else cur.dry = (cur.dry or 0) + 1 end
  local k = math.min(1, (cur.dry or 0) * r)
  d.fill:SetWidth(math.max(0.01, (Q.dueW - 2) * k))
  d.full = k >= 1 or nil
  local name = C.DUE_NAME[kind] or "WINDFURY"
  d.label:SetText(procced and (name .. "!") or (d.full and (name .. " DUE - ANY SECOND...") or (name .. " DUE")))
  if d.kind ~= kind then
    local rr, gg, bb = hexRGB(C.FLOAT_COL[kind] or C.FLOAT_COL.wf)
    d.label:SetTextColor(rr, gg, bb, 1)
    d.fill:SetColorTexture(rr, gg, bb, 0.9)
    d.kind = kind
  end
  d.flash = procced and 0.4 or nil
  d.hideIn = nil
  d.k = k
  d:Show()
  g:Show()
end
--- The fight over: the gauge waits a moment, then goes.
function C.FloatEnd()
  local g = C.float
  if g and g.due and g.due:IsShown() then g.due.hideIn = C.FLOAT.dueHold end
end
--- A spell's icon inside a line of text (|T...|t, the tape's line height), else its short word.
C.ICO = 13
function C.Ico(name, word)
  local tex = C.IconFor(name)
  if not tex then return word or name end
  return ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t"):format(tostring(tex), C.ICO, C.ICO)
end
--[[ THE RECEIPT TAPE (17 Nov 2026, Arn: "make it like a receipt calculator printer, it scrolling from bottom to top"): a
  small strip of paper beside the card's spot. Each proc prints a line at the bottom - the fight's clock, then the words
  ("0:12  +1 EXTRA HIT") - and the paper rolls up a line, the oldest going off the top. When the fight ends it prints a
  rule and the total ("TOTAL  7 PROCS"), lingers C.TAPE.linger s (held while the mouse is on it) and fades. Out of a
  fight it drags anywhere (db.tapePos). Nothing ticks while it is away. ]]
-- (17 Nov, Arn's first look: "more warm white candle light" - "its so bright" - "30 sec idle time before it fades away":
-- the paper a dim warm cream, brown ink, and it waits C.TAPE.linger s after the LAST line it printed, in a fight or not)
C.TAPE = { w = 190, lines = 7, lh = 15, roll = 0.15, linger = 30, fade = 1.5, pad = 5, alpha = 0.82, keep = 300,
           foot = 15, wMin = 130, wMax = 360, hMin = 70, hMax = 420 }
--[[ THE FOOTER AND THE SIZE (17 Nov 2026, Arn, of the tape: "let's get rid of this empty space, and maybe draggable bigger,
  drag icon smaller, only words" - "let's give this one a BiS> Procs footer"): the strip under the newest line is the
  footer now - "BiS> Procs" in words, a thin rule over it, the lines printing up out of it. A small grip in its corner
  sizes the paper (db.tapeW / db.tapeH, inside the bounds); taller holds more lines, re-read from the fight's log. ]]
local function tapeLines(t) return t.lines or C.TAPE.lines end
function C.TapeSize()
  local T, d = C.TAPE, db()
  local w = math.max(T.wMin, math.min(T.wMax, tonumber(d.tapeW) or T.w))
  local h = math.max(T.hMin, math.min(T.hMax, tonumber(d.tapeH) or (T.lines * T.lh + T.foot + 2 + T.pad)))
  return w, h
end
function C.TapeFit(t)
  local T = C.TAPE
  local w, h = C.TapeSize()
  t:SetSize(w, h)
  t.lines = math.max(2, math.floor((h - T.foot - 2 - T.pad) / T.lh))
  for _, r in ipairs(t.rows or {}) do r:SetWidth(w - 2 * T.pad - 4) end
  for _, r in ipairs(t.spare or {}) do r:SetWidth(w - 2 * T.pad - 4) end
end
C.PAPER, C.INK, C.INK_FIRE = { 0.78, 0.69, 0.53 }, { 0.20, 0.13, 0.07 }, { 0.62, 0.20, 0.06 }
local function tapePlace(t, dx, dy)
  dx, dy = dx or 0, dy or 0
  t.tossX, t.tossY = dx, dy
  t:ClearAllPoints()
  local p = db().tapePos
  if type(p) == "table" and p[1] then t:SetPoint(p[1], UIParent, p[2] or p[1], (p[3] or 0) + dx, (p[4] or 0) + dy) return end
  -- (17 Nov, Arn's first fight with it: above the card's spot it sat under his XP bar and AutoLayer's box at the top of the
  -- screen - it hangs UNDER the card now, following the card wherever it was dragged)
  local card = C.BuildCard()
  if card then t:SetPoint("TOP", card, "BOTTOM", dx, -6 + dy) else t:SetPoint("TOP", UIParent, "TOP", dx, -234 + dy) end
end
C.TapePlace = tapePlace
--[[ TORN OFF AND TOSSED (17 Nov 2026, Arn: "jagged look when it fades away, like I ripped it from the calculator and tossed
  it to the side - random left or right fading out, 1 in 100 it jams and fades away"): when the idle clock runs out the
  printer's lip goes, a row of paper teeth shows along the bottom (the tear), and the strip flies off to a random side,
  dropping a little, as it fades (C.TOSS.secs). One time in C.TOSS.jamOdds it jams instead: PAPER JAM prints, the strip
  rattles where it is, then fades. A new line while it goes: back in place, printing again. ]]
C.TOSS = { secs = 0.7, far = 180, drop = 40, hop = 12, jamOdds = 100, jamShake = 1.0, jamFade = 0.6, jamPx = 3, teeth = 14, tooth = 9 }
local function teethFrame(t)
  if t.teeth then return t.teeth end
  local Q, T = C.TOSS, C.TAPE
  local g = CreateFrame("Frame", nil, UIParent)               -- (its own frame: never cut by the paper's clipping)
  g:SetFrameStrata("HIGH")
  g:SetSize(T.w, Q.tooth)
  g:SetPoint("TOP", t, "BOTTOM", 0, Q.tooth / 2)
  g.bits = {}
  local step = T.w / Q.teeth
  for i = 1, Q.teeth do
    local x = g:CreateTexture(nil, "ARTWORK")
    x:SetSize(Q.tooth * 0.75, Q.tooth * 0.75)
    x:SetPoint("CENTER", g, "LEFT", step * (i - 0.5), 0)
    x:SetColorTexture(C.PAPER[1], C.PAPER[2], C.PAPER[3], T.alpha)
    if x.SetRotation then x:SetRotation(math.pi / 4) end      -- (a square on its corner: one tooth of the tear)
    g.bits[i] = x
  end
  g:Hide()
  t.teeth = g
  return g
end
--- Put the strip back where it prints, whole (the lip on, no tear).
function C.TossReset(t)
  t.toss = nil
  tapePlace(t)
  if t.teeth then t.teeth:Hide() end
  if t.edge then t.edge:Show() end
  t:SetAlpha(1)
end
--- The idle clock ran out: tear it off and toss it (dir -1 left / 1 right, jam true = the 1 in 100; both random if nil).
function C.TossStart(t, dir, jam)
  local Q = C.TOSS
  if jam == nil then jam = math.random(Q.jamOdds) == 1 end
  if jam then C.TapePrint("** PAPER JAM **", true) end
  t.left = nil
  t.toss = { at = 0, dir = dir or (math.random(2) == 1 and -1 or 1), jam = jam or nil }
  if not jam then
    if t.edge then t.edge:Hide() end
    local g = teethFrame(t)
    g:SetAlpha(1)
    g:Show()
  end
end
function C.TossStep(t, e)
  local Q, s = C.TOSS, t.toss
  s.at = s.at + e
  local a
  if s.jam then
    if s.at < Q.jamShake then
      tapePlace(t, (math.random() * 2 - 1) * Q.jamPx, (math.random() * 2 - 1) * Q.jamPx * 0.5)
      a = 1
    else
      tapePlace(t)
      a = 1 - (s.at - Q.jamShake) / Q.jamFade
    end
  else
    local k = math.min(1, s.at / Q.secs)
    tapePlace(t, s.dir * Q.far * k * k, -Q.drop * k * k + Q.hop * math.sin(k * math.pi))
    a = 1 - k
  end
  if a <= 0 then
    t:Hide()
    C.TossReset(t)
    return
  end
  t:SetAlpha(a)
  if t.teeth then t.teeth:SetAlpha(a) end
end
function C.Tape()
  if C.tape then return C.tape end
  local T = C.TAPE
  local t = CreateFrame("Frame", "BiSToolsComboTape", UIParent)
  t:SetFrameStrata("HIGH")                                     -- (over bars other addons keep at the top of the screen)
  if t.SetClipsChildren then t:SetClipsChildren(true) end    -- (the paper's top edge cuts the oldest line off)
  t:EnableMouse(true)
  t:SetMovable(true)
  t:SetClampedToScreen(true)
  t:RegisterForDrag("LeftButton")
  t:SetScript("OnDragStart", function(self)
    if InCombatLockdown and InCombatLockdown() then return end
    self:StartMoving() self.moving = true
  end)
  local function stop(self)
    if not self.moving then return end
    self.moving = nil
    self:StopMovingOrSizing()
    local ok, pt, _, rp, x, y = pcall(self.GetPoint, self)
    if ok and pt then db().tapePos = { pt, rp, x, y } end
  end
  t:SetScript("OnDragStop", stop)
  t:SetScript("OnHide", function(self) stop(self) if self.teeth then self.teeth:Hide() end end)
  t:SetScript("OnEnter", function(self) if not self.toss then self.hold = true self:SetAlpha(1) end end)
  t:SetScript("OnLeave", function(self) self.hold = nil end)
  t.paper = t:CreateTexture(nil, "BACKGROUND")
  t.paper:SetAllPoints(t)
  t.paper:SetColorTexture(C.PAPER[1], C.PAPER[2], C.PAPER[3], T.alpha)
  t.edge = t:CreateTexture(nil, "BORDER")                       -- the rule over the footer: where the paper comes out
  t.edge:SetPoint("BOTTOMLEFT", 0, T.foot) t.edge:SetPoint("BOTTOMRIGHT", 0, T.foot) t.edge:SetHeight(1)
  t.edge:SetColorTexture(C.INK[1], C.INK[2], C.INK[3], 0.35)
  t.footBg = t:CreateTexture(nil, "BORDER")                     -- the footer a shade darker, under the lines rolling out
  t.footBg:SetPoint("BOTTOMLEFT") t.footBg:SetPoint("BOTTOMRIGHT") t.footBg:SetHeight(T.foot)
  t.footBg:SetColorTexture(C.PAPER[1] * 0.88, C.PAPER[2] * 0.88, C.PAPER[3] * 0.88, T.alpha)
  t.foot = CreateFrame("Frame", nil, t)                         -- (its own frame, over the rows: the words stay clean)
  t.foot:SetPoint("BOTTOMLEFT") t.foot:SetPoint("BOTTOMRIGHT") t.foot:SetHeight(T.foot)
  t.foot:SetFrameLevel((t:GetFrameLevel() or 1) + 3)
  t.foot.bg = t.foot:CreateTexture(nil, "BACKGROUND")
  t.foot.bg:SetAllPoints(t.foot)
  t.foot.bg:SetColorTexture(C.PAPER[1] * 0.88, C.PAPER[2] * 0.88, C.PAPER[3] * 0.88, 1)
  t.foot.word = t.foot:CreateFontString(nil, "OVERLAY")
  t.foot.word:SetFont("Fonts\\ARIALN.TTF", 10, "")
  t.foot.word:SetPoint("CENTER", 0, 0)
  t.foot.word:SetTextColor(C.INK[1], C.INK[2], C.INK[3], 0.7)
  t.foot.word:SetText("BiS> Procs")
  if t.SetResizable then t:SetResizable(true) end
  if t.SetResizeBounds then pcall(t.SetResizeBounds, t, T.wMin, T.hMin, T.wMax, T.hMax) end
  local grip = CreateFrame("Button", nil, t.foot)               -- small, in the footer's corner
  grip:SetSize(9, 9)
  grip:SetPoint("BOTTOMRIGHT", -1, 1)
  grip.tex = grip:CreateTexture(nil, "OVERLAY")
  grip.tex:SetAllPoints(grip)
  grip.tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip.tex:SetVertexColor(C.INK[1], C.INK[2], C.INK[3], 0.8)
  grip:SetScript("OnMouseDown", function()
    if InCombatLockdown and InCombatLockdown() then return end
    if t.StartSizing then t.sizing = true t:StartSizing("BOTTOMRIGHT") end
  end)
  grip:SetScript("OnMouseUp", function() C.TapeEndSize(t) end)
  t.grip = grip
  t:SetScript("OnSizeChanged", function(self, w, h)
    if not self.sizing then return end
    local d = db()
    d.tapeW = math.floor((tonumber(w) or T.w) + 0.5)
    d.tapeH = math.floor((tonumber(h) or 100) + 0.5)
    C.TapeFit(self)
    C.TapeBack(self, 0)
  end)
  t.rows, t.spare, t.shift, t.log, t.back = {}, {}, 0, {}, 0
  -- SCROLL BACK (17 Nov 2026, Arn: "does the receipt keep going or is it scrollable?"): the whole fight is kept (t.log, up
  -- to C.TAPE.keep lines); the mouse wheel over the paper rolls it back, and new lines wait below while you read
  if t.EnableMouseWheel then t:EnableMouseWheel(true) end
  t:SetScript("OnMouseWheel", function(self, delta) C.TapeBack(self, (tonumber(delta) or 0) > 0 and 1 or -1) end)
  t.hint = t:CreateFontString(nil, "OVERLAY")
  t.hint:SetFont("Fonts\\ARIALN.TTF", 10, "")
  t.hint:SetPoint("TOPRIGHT", t, "TOPRIGHT", -T.pad, -2)
  t.hint:SetTextColor(C.INK_FIRE[1], C.INK_FIRE[2], C.INK_FIRE[3], 1)
  t.hint:Hide()
  t:SetScript("OnUpdate", function(self, e)
    e = tonumber(e) or 0
    if self.shift > 0 then
      self.shift = math.max(0, self.shift - e * (T.lh / T.roll))
      C.TapeLay(self)
    end
    if self.toss then C.TossStep(self, e) return end
    if self.left then
      if self.hold then self.left = T.linger
      else
        self.left = self.left - e
        if self.left <= 0 then C.TossStart(self) end
      end
    end
  end)
  C.TapeFit(t)
  t:Hide()
  tapePlace(t)
  C.tape = t
  return t
end
--- Every printed line in its place: the newest at the bottom, each older one a line up (plus the roll still running).
function C.TapeLay(t)
  local T = C.TAPE
  local n = #t.rows
  for i, r in ipairs(t.rows) do
    r:ClearAllPoints()
    r.y = T.foot + 2 + (n - i) * T.lh - t.shift
    r:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", T.pad + 2, r.y)
  end
end
--- Print one line at the bottom; the paper rolls up a line.
local function newRow(t)
  local T = C.TAPE
  local r = table.remove(t.spare)
  if not r then
    r = t:CreateFontString(nil, "OVERLAY")
    r:SetFont("Fonts\\ARIALN.TTF", 12, "")
    r:SetWidth((t:GetWidth() or T.w) - 2 * T.pad - 4)
    r:SetJustifyH("LEFT")
    if r.SetWordWrap then r:SetWordWrap(false) end
    if r.SetMaxLines then r:SetMaxLines(1) end
  end
  return r
end
local function ink(r, fire)
  local col = fire and C.INK_FIRE or C.INK
  r:SetTextColor(col[1], col[2], col[3], 1)
end
function C.TapePrint(text, fire)
  local t = C.Tape()
  local T = C.TAPE
  t.log[#t.log + 1] = { text, fire }
  while #t.log > T.keep do table.remove(t.log, 1) end
  if t.toss then C.TossReset(t) end                            -- (printing again while it flew off: back in place)
  t.left = T.linger                                            -- (the idle clock starts again at every line)
  t:SetAlpha(1)
  t:Show()
  if (t.back or 0) > 0 then                                    -- (reading back: the new line waits below)
    t.back = math.min(t.back + 1, math.max(0, #t.log - tapeLines(t)))
    C.TapeHint(t)
    return nil
  end
  local r = newRow(t)
  ink(r, fire)
  r:SetText(text)
  r:Show()
  t.rows[#t.rows + 1] = r
  while #t.rows > tapeLines(t) + 1 do                               -- (one spare line rides off the top as the paper rolls)
    local old = table.remove(t.rows, 1)
    old:Hide()
    t.spare[#t.spare + 1] = old
  end
  t.shift = T.lh
  C.TapeLay(t)
  return r
end
--- Let go of the tape's corner: its size kept, its spot kept.
function C.TapeEndSize(t)
  if not t.sizing then return end
  t.sizing = nil
  t:StopMovingOrSizing()
  local d = db()
  d.tapeW, d.tapeH = math.floor((t:GetWidth() or C.TAPE.w) + 0.5), math.floor((t:GetHeight() or 100) + 0.5)
  local ok, pt, _, rp, x, y = pcall(t.GetPoint, t)
  if ok and pt then d.tapePos = { pt, rp, x, y } end
  C.TapeFit(t)
  C.TapeBack(t, 0)
end
--- Roll back (+1, older) or forward (-1) a line; the paper shows the log from there, no animation.
function C.TapeBack(t, step)
  local T = C.TAPE
  t.back = math.max(0, math.min((t.back or 0) + step, math.max(0, #t.log - tapeLines(t))))
  for _, r in ipairs(t.rows) do r:Hide() t.spare[#t.spare + 1] = r end
  t.rows, t.shift = {}, 0
  local last = #t.log - t.back
  for k = math.max(1, last - tapeLines(t) + 1), last do
    local r = newRow(t)
    ink(r, t.log[k][2])
    r:SetText(t.log[k][1])
    r:Show()
    t.rows[#t.rows + 1] = r
  end
  C.TapeLay(t)
  C.TapeHint(t)
  t.left = T.linger
  return t.back
end
function C.TapeHint(t)
  if (t.back or 0) > 0 then
    t.hint:SetText(("%d newer - scroll down"):format(t.back))
    t.hint:Show()
  else
    t.hint:Hide()
  end
end
--- The set on the tape: the imbue, then the totems (short words), each its own line.
function C.TapeSet(imbue, tot)
  local names = {}
  for n in pairs(tot or {}) do names[#names + 1] = n end
  table.sort(names)
  local parts = { imbue and C.Ico(imbue, C.IMBUE_SHORT[imbue] or imbue) or "NO IMBUE" }
  parts[#parts + 1] = " "
  for _, n in ipairs(names) do parts[#parts + 1] = C.Ico(n, C.TOTEMS[n] or n) end
  if #names == 0 then parts[#parts + 1] = "NO TOTEMS" end
  C.TapePrint(table.concat(parts, " "))                         -- (one line of icons: the imbue, a gap, the totems)
end
--- A new fight: a fresh stretch of paper.
function C.TapeClear()
  local t = C.tape
  if not t then return end
  for _, r in ipairs(t.rows) do r:Hide() t.spare[#t.spare + 1] = r end
  t.rows, t.shift, t.left, t.log, t.back = {}, 0, nil, {}, 0
  if t.hint then t.hint:Hide() end
  if t.toss then C.TossReset(t) end
  t:Hide()
end
--- THE BREAKDOWN under the total (17 Nov 2026, Arn: "total 5 procs - break it down: 4 flame, 1 wf imbue"): one line a
--- kind that happened, most first: { count, text, fire }. Windfury's +2 is the imbue's, +1 the totem's while one was down.
function C.TapeBreakdown(cur)
  local pr, out = cur.procs or {}, {}
  local totem = cur.totems and cur.totems["Windfury Totem"]
  local function add(n, word, fire) if (n or 0) > 0 then out[#out + 1] = { n, ("%d  %s"):format(n, word), fire } end end
  local ft = (cur.totems or {})["Flametongue Totem"] and "Flametongue Totem" or "Flametongue Weapon"
  add(pr.fire, C.Ico(ft, "FT") .. "  Flametongue", true)
  add(pr.extra2, C.Ico("Windfury Weapon", "WF") .. "  +2")
  add(pr.extra1, totem and (C.Ico("Windfury Totem", "WF totem") .. "  +1") or (C.Ico("Windfury Weapon", "WF") .. "  +1"))
  add(pr.more, C.Ico("Windfury Weapon", "WF") .. "  +3 or more")
  add(pr.frost, C.Ico("Frostbrand Weapon", "FB") .. "  Frostbrand")
  table.sort(out, function(a, b) return a[1] > b[1] end)
  return out
end
--- The fight over: a rule, the total and what it was made of, then it lingers and fades.
function C.TapeEnd(cur)
  local t = C.tape
  if not (t and t:IsShown() and cur and cur.procs) then return end
  local pr = cur.procs
  local n = (pr.extra1 or 0) + (pr.extra2 or 0) + (pr.more or 0) + (pr.fire or 0) + (pr.frost or 0)
  C.TapePrint("- - - - - - - - - - - - -")
  C.TapePrint(("TOTAL  %d PROC%s"):format(n, n == 1 and "" or "S"))
  for _, row in ipairs(C.TapeBreakdown(cur)) do C.TapePrint(row[2], row[3]) end
  t.left = C.TAPE.linger
end
--- One proc line, with the fight's clock.
function C.Scroll(text, fireOnly)
  local cur = C.cur
  if cur and not cur.headed then                               -- (the receipt's head: what you started with)
    cur.headed = true
    C.TapeSet(cur.nowImbue or cur.imbue, cur.nowTot or cur.totems)
    local okG, grouped = pcall(function() return IsInGroup and IsInGroup() end)
    if okG and plain(grouped) == true then C.TapePrint("GROUP: OTHERS MAY SLIP IN") end
  end
  local now = GetTime and GetTime() or 0
  local secs = (cur and cur.start) and math.max(0, now - cur.start) or 0
  return C.TapePrint(("%d:%02d  %s"):format(math.floor(secs / 60), math.floor(secs % 60), text), fireOnly)   -- (never upper: icon codes)
end

-- ---------------------------------------------------------------- the LIVE probe (/bist combo live)
--[[ (17 Nov 2026, Arn: "a scrolling proc text so we can see when we get procs ... 1 extra hit, 1 extra flametongue,
  during combat"). Forever's combat log never reaches an addon (solved.md: COMBAT_LOG_EVENT_UNFILTERED fires zero
  times, the log window's lines are tickets) - so the one road left is the game's damage meter DURING the fight: if your
  breakdown's per-spell totals are plain and move while you fight, a jump in Windfury's total is a proc. Armed for ONE
  fight: every C.LIVE_EVERY s it reads the current fight's breakdown (kinds only - plain / SECRET - and, when plain,
  whether a spell's total moved); after the fight it prints what it saw, and the shape of a spell's details (hit counts?). ]]
C.LIVE_EVERY = 0.5
function C.LiveArm()
  C.live = { armed = true }
  say("combo live probe: armed for your next fight - fight something with your imbue up, then read the lines after it")
end
local function liveRead(L)
  local D = C_DamageMeter
  local ST = Enum and Enum.DamageMeterSessionType
  local dmg = (Enum and Enum.DamageMeterType and Enum.DamageMeterType.DamageDone) or 0
  if not (D and D.GetCombatSessionSourceFromType and ST and ST.Current) then L.noApi = true return end
  L.polls = L.polls + 1
  local guid = UnitGUID and UnitGUID("player")
  local ok, br = pcall(D.GetCombatSessionSourceFromType, ST.Current, dmg, guid)
  if not ok then L.refused = L.refused + 1 return end
  if type(br) ~= "table" then L.empty = L.empty + 1 return end
  if issecretvalue and issecretvalue(br) then L.secretTable = L.secretTable + 1 return end
  L.tables = L.tables + 1
  pcall(function()
    for _, sp in ipairs(br.combatSpells or {}) do
      local id, amt = sp.spellID, sp.totalAmount
      local idPlain = id ~= nil and not (issecretvalue and issecretvalue(id))
      local key = idPlain and id or "secret-id"
      local e = L.spells[key]
      if not e then
        local name = "?"
        if idPlain and C_Spell and C_Spell.GetSpellName then
          local okN, n = pcall(C_Spell.GetSpellName, id)
          if okN and n and not (issecretvalue and issecretvalue(n)) then name = n end
        end
        e = { name = name, plain = 0, secret = 0, moves = 0 }
        L.spells[key] = e
        L.order[#L.order + 1] = key
      end
      if amt ~= nil and issecretvalue and issecretvalue(amt) then e.secret = e.secret + 1
      elseif type(amt) == "number" then
        e.plain = e.plain + 1
        if e.last and amt ~= e.last then e.moves = e.moves + 1 end
        e.last = amt
      end
    end
  end)
end
function C.LiveStart()
  local L = C.live
  if not (L and L.armed) then return end
  L.armed = nil
  L.polls, L.refused, L.empty, L.secretTable, L.tables, L.spells, L.order = 0, 0, 0, 0, 0, {}, {}
  if C_Timer and C_Timer.NewTicker then
    L.ticker = C_Timer.NewTicker(C.LIVE_EVERY, function() liveRead(L) end)
  end
  liveRead(L)
end
function C.LiveEnd()
  local L = C.live
  if not (L and L.polls) or L.done then return end
  L.done = true
  if L.ticker and L.ticker.Cancel then L.ticker:Cancel() end
  local lines = {}
  local function out(fmt, ...) local l = string.format(fmt, ...) lines[#lines + 1] = l say("%s", l) end
  out("combo live probe: %d reads in the fight - %d readable, %d hidden tables, %d empty, %d refused%s", L.polls, L.tables,
    L.secretTable, L.empty, L.refused, L.noApi and " (no meter API)" or "")
  for i, key in ipairs(L.order) do
    if i > 8 then break end
    local e = L.spells[key]
    out("  %s (%s): total plain %d / SECRET %d, moved %d times", e.name, tostring(key), e.plain, e.secret, e.moves)
  end
  if #L.order == 0 then out("  no spells listed while you fought") end
  -- after the fight: the details of the first spell (counts of hits?)
  local D = C_DamageMeter
  local ST = Enum and Enum.DamageMeterSessionType
  if D and ST and ST.Current then
    local ok, br = pcall(D.GetCombatSessionSourceFromType, ST.Current, (Enum.DamageMeterType and Enum.DamageMeterType.DamageDone) or 0, UnitGUID and UnitGUID("player"))
    if ok and type(br) == "table" then
      pcall(function()
        for i, sp in ipairs(br.combatSpells or {}) do
          if i > 3 then break end
          local det = sp.combatSpellDetails
          local parts = {}
          if type(det) == "table" then
            for k, v in pairs(det) do
              parts[#parts + 1] = tostring(k) .. "=" .. (type(v) == "table" and "{table}" or tostring(v))
              if #parts >= 10 then break end
            end
          end
          out("  after: spell %s details {%s}", tostring(sp.spellID), table.concat(parts, ", "))
        end
      end)
    end
  end
  C.liveLines = lines
  C.live = nil
  return lines
end

-- ---------------------------------------------------------------- events (heard always, acted on only while the tool is on)
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TOTEM_UPDATE", "UNIT_SPELLCAST_SUCCEEDED",
                    "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "UNIT_COMBAT", "PLAYER_LOGOUT" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, a1, a2, a3, a4, a5)
  if event == "UNIT_COMBAT" then                       -- (first and quick: it fires for every unit hit, all the time)
    if a1 == "target" and C.cur then C.Hit(a2, a5) end
    return
  end
  -- (17 Nov, Arn again: "every time I reload it closes the combo window" - db.open read false after two reloads with the
  -- list up; whoever wrote it, the list's own state at the logout is the answer, written last)
  if event == "PLAYER_LOGOUT" then
    if C.frame then db().open = C.frame:IsShown() and true or false end
    return
  end
  if event == "PLAYER_REGEN_DISABLED" then             -- a drag still on ends before the fight takes the mouse
    endDrag(C.frame) endDrag(C.card)
    C.CastAway()                                       -- (the secure cast button: away, and off the icon, before the lockdown)
    if C.live then C.LiveStart() end                  -- (the live probe, armed by hand: on or off with the tool)
  elseif event == "PLAYER_REGEN_ENABLED" and C.live and C.live.polls then
    C.LiveEnd()
  end
  if not R:Enabled("combo") then
    if event == "PLAYER_REGEN_ENABLED" then C.lastWhy = "the tool was off (/bist on combo)" end
    return
  end
  if event == "PLAYER_REGEN_DISABLED" then C.Pull()
  elseif event == "PLAYER_REGEN_ENABLED" then C.FightOver()
  elseif event == "PLAYER_TOTEM_UPDATE" then
    if C.cur then
      local up = C.ScanTotems({})
      C.ScanTotems(C.cur.totems) C.SwitchCheck(C.cur, C.cur.nowImbue, up)
      -- (18 Nov, Arn: the gauge said WINDFURY after he swapped his Windfury Totem away mid-fight - the buff was read
      -- once at the pull. A totem change reads the buffs again, and once more C.AURA_LINGER s later - a totem's buff
      -- stays a while after it goes; an unreadable answer counts as not up)
      local cur = C.cur
      local function again()
        if C.cur ~= cur then return end
        local tot = cur.nowTot or {}
        if not tot["Windfury Totem"] then cur.wfAura = C.AuraUp("Windfury Totem") end
        if not tot["Flametongue Totem"] then cur.ftAura = C.AuraUp("Flametongue Totem") end
      end
      again()
      if C_Timer and C_Timer.After then C_Timer.After(C.AURA_LINGER, again) end
    end
  elseif event == "PLAYER_ENTER_COMBAT" then if C.cur then C.cur.swing = true end    -- auto-attack on
  elseif event == "PLAYER_LEAVE_COMBAT" then if C.cur then C.cur.swing = false end   -- and off
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then if a1 == "player" then C.Cast(a3) end
  end
end)
C.events = ev

R:Register({
  name = "combo",
  short = "cmb",
  desc = "after each fight: your weapon imbue + totems and the damage they did; which combo is best",
  usage = "/bist combo  (short: cmb)  |  /bist combo probe",
  slashWhenOff = true,
  defaultOff = true,
  defaults = { fights = {}, card = true, min = C.MIN },
  options = {
    { kind = "toggle", label = "card after each fight",
      help = "A small card after a fight: your imbue + totems, your DPS, and where that combo ranks. Click it for the list.",
      get = function(d) return d.card ~= false end, set = function(d, v) d.card = v and true or false end },
    { kind = "toggle", label = "proc text in a fight",
      help = "A receipt tape beside the card prints each proc as you fight, newest at the bottom: +1 extra hit (Windfury Totem), +2 extra hits (Windfury Weapon), Flametongue, then the fight's total.",
      get = function(d) return d.scroll ~= false end, set = function(d, v) d.scroll = v and true or false end },
    { kind = "toggle", label = "clean proc text",
      help = "No paper: each swing's procs float up in big letters (WINDFURY +2  FT +1) and fade, with a small Windfury-due gauge under them. Off = the receipt tape.",
      get = function(d) return d.tapeStyle == "clean" end, set = function(d, v) d.tapeStyle = v and "clean" or "receipt" C.StyleChanged() end },
    { kind = "step", label = "shortest fight counted", help = "0 = every fight counts (a long fight weighs more than a short one). Above 0, shorter fights are kept but not ranked.",
      min = 0, max = 60, step = 5, get = function(d) return tonumber(d.min) or C.MIN end,
      set = function(d, v) d.min = v if C.IsOpen() then C.Paint() end end, show = function(d) return (tonumber(d.min) or C.MIN) .. " s" end },
    { kind = "button", label = "the combo list", button = "open",
      help = "Every imbue + totem combo you fought with, ranked by damage per second, with how many fights each is based on.",
      action = function(d) C.db = d C.Toggle(true) end },
  },
  OnInit = function(_, d) C.db = d end,
  OnLogin = function(_, d)
    C.db = d
    if d.open and R:Enabled("combo") then C.Toggle(true) end       -- (it was up when you left: up again)
  end,
  OnOpen = function(_, d, recenter)
    C.db = d
    if recenter then
      if C.frame then C.frame:ClearAllPoints() C.frame:SetPoint("CENTER") end
      d.listPos = nil
      if C.card then C.card:ClearAllPoints() C.card:SetPoint("TOP", UIParent, "TOP", 0, -170) d.cardPos = nil end
      d.tapePos = nil
      if C.tape then C.TapePlace(C.tape) end
      return
    end
    C.Toggle(true)
  end,
  IsOpen = function() return C.IsOpen() end,
  OnClose = function() C.Toggle(false) end,
  OnDisable = function() C.cur = nil if C.frame then C.frame:Hide() db().open = false end if C.card then C.card:Hide() end end,
  OnSlash = function(_, d, args)
    C.db = d
    local cmd = tostring(args or ""):match("^(%S*)") or ""
    if cmd == "probe" then C.Probe() return end
    if cmd == "live" then C.LiveArm() return end
    if cmd == "reach" then C.ReachProbe() return end
    if cmd == "why" then
      say("combo: recording %s - last fight: %s", R:Enabled("combo") and "ON" or "OFF (/bist on combo)", C.lastWhy or "none since the reload")
      say("combo: hits - %s", C.HitLine(C.lastHits))
      say("combo: last fight - %d bursts too soon after your own swing (someone else's) were left out", C.lastForeign or 0)
      say("combo: list %s, comes back after a reload: %s%s", C.IsOpen() and "open" or "closed", db().open and "yes" or "no",
        C.closedBy and (" - last closed by " .. C.closedBy) or "")
      return
    end
    if cmd == "clean" or cmd == "receipt" then
      d.tapeStyle = cmd
      C.StyleChanged()
      if C.frame and C.frame.sw and C.frame.sw:IsShown() then C.PaintSet() end
      say("combo: proc text style - %s", cmd == "clean" and "CLEAN (floating text, no paper)" or "RECEIPT (the paper tape)")
      return
    end
    if cmd == "forget" then d.fights, d.lastSid = {}, nil if C.IsOpen() then C.Paint() end say("combo: every fight forgotten") return end
    -- OPENING THE LIST MEANS "RECORD" (17 Nov, Arn's first try: the list opened with the tool still off, the fight went by)
    if not R:Enabled("combo") then
      R:SetEnabled("combo", true)
      say("combo: recording your fights from now on - /bist off combo stops it")
    end
    C.Toggle()
  end,
})
