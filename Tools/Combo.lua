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

-- (C.MIN 0, 17 Nov - Arn: "fight under 10 sec should count because lucky procs means it can kill things fast": every
-- fight counts by default; damage over TIME already weighs a short one by its few seconds. The setting stays.)
C.MIN, C.KEEP, C.READ_WAIT, C.CARD_FOR, C.CARD_FADE = 0, 300, 1.5, 8, 1
C.W, C.H, C.ROWS, C.ROW = 330, 236, 7, 16
-- THE SIZE AND THE SWITCHES (17 Nov 2026, Arn: "we forgot the rule of letting us resize the window that we did with bis
-- healing deck" - the family rule: every window a switches panel with its toggles, width and height, RESET): the list's
-- SET button opens the panel over its lower half; width / height in C.STEP px steps between the bounds, kept in
-- db.w / db.h; the rows follow the height. RESET puts the look back (never your fights).
C.W_MIN, C.W_MAX, C.H_MIN, C.H_MAX, C.STEP = 280, 560, 200, 440, 20
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

local function plain(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
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
function C.Pull()
  C.cur = { imbue = C.ImbueNow(), totems = C.ScanTotems({}), active = 0, swing = C.Swinging() }
  if C.activeTicker and C.activeTicker.Cancel then C.activeTicker:Cancel() end
  if C_Timer and C_Timer.NewTicker then C.activeTicker = C_Timer.NewTicker(C.ACTIVE_EVERY, C.ActiveTick) end
end
function C.Cast(spellID)
  if not (C_Spell and C_Spell.GetSpellName) then return end
  local ok, name = pcall(C_Spell.GetSpellName, spellID)
  name = C.Base(ok and plain(name) or nil)
  if not name then return end
  if C.cur and C.TOTEMS[name] then C.cur.totems[name] = true end
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
    end)
  end
end
function C.FightOver()
  local cur = C.cur
  C.cur = nil
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
  local totems = {}
  for n in pairs(cur.totems or {}) do totems[#totems + 1] = n end
  table.sort(totems)
  local imbue = cur.imbue or C.ImbueNow()
  local set = {}
  for _, n in ipairs(totems) do set[n] = true end
  local active = (cur.active or 0) >= C.ACTIVE_MIN and math.min(cur.active, dur) or nil
  local rec = { at = (time and time()) or 0, sid = sid, mob = plain(last.name) or plain(s.name), dur = dur, dmg = dmg,
                active = active, how = active and (cur.reachKnown and ("swinging in reach - " .. tostring(cur.reachHow)) or "swinging") or "the whole fight",
                imbue = imbue, totems = totems, combo = C.Label(imbue, set),
                wf = dmg > 0 and wf / dmg or 0, ft = dmg > 0 and ft / dmg or 0, spells = C.TopSpells(spells, dmg),
                procs = cur.procs }
  d.fights = d.fights or {}
  d.fights[#d.fights + 1] = rec
  while #d.fights > C.KEEP do table.remove(d.fights, 1) end
  C.lastWhy = ("kept fight %d: %s, %d s (%s %s), %d dps"):format(sid, rec.combo, math.floor(dur + 0.5),
    active and math.floor(active + 0.5) .. " s" or "-", rec.how, math.floor(dmg / C.Time(rec) + 0.5))
  if d.card ~= false then C.ShowCard(rec) end
  if C.IsOpen() then C.Paint() end
  return rec
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
      if not g then g = { combo = f.combo, n = 0, dmg = 0, dur = 0, imbue = f.imbue, totems = f.totems } by[f.combo] = g list[#list + 1] = g end
      g.n, g.dmg, g.dur = g.n + 1, g.dmg + f.dmg, g.dur + C.Time(f)
    end
  end
  for _, g in ipairs(list) do g.dps = g.dur > 0 and g.dmg / g.dur or 0 end
  table.sort(list, function(a, b) return a.dps > b.dps end)
  return list
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
  f:SetScript("OnEnter", function(self) self.hold = true self:SetAlpha(1) end)
  f:SetScript("OnLeave", function(self) self.hold = nil end)
  K.tex(f, "BACKGROUND", "frame", 0.94)
  K.border(f, "edge", 1)
  f.title = K.fs(f, "BiS> combo", 9, "accent")
  f.title:SetPoint("TOPLEFT", 6, -5)
  f.where = K.fs(f, "", 9, "muted")
  f.where:SetPoint("TOPRIGHT", -6, -5)
  f.combo = K.fs(f, "", 11, "ink")
  f.combo:SetPoint("LEFT", f, "LEFT", 6, 2)
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
function C.ShowCard(rec)
  local f = C.BuildCard()
  f.where:SetText(("%s%s"):format(rec.active and ("%d of %d s swinging"):format(math.floor(rec.active + 0.5), math.floor(rec.dur + 0.5))
    or ("%d s"):format(math.floor(rec.dur + 0.5)), rec.mob and (" · " .. rec.mob) or ""))
  f.combo:SetText(rec.combo)
  f.dps:SetText(("%d dps"):format(math.floor(rec.dmg / C.Time(rec) + 0.5)))
  if rec.dur < C.Min() then
    f.place:SetText(("short fight - not ranked (under %d s)"):format(C.Min()))
  else
    local k, n = C.Place(rec.combo)
    local wf = rec.wf and rec.wf > 0 and ("  ·  Windfury %d%%"):format(math.floor(rec.wf * 100 + 0.5)) or ""
    local pr = rec.procs
    if pr and (pr.extra1 + pr.extra2 + pr.more) > 0 then
      wf = wf .. ("  ·  %d procs"):format(pr.extra1 + pr.extra2 + pr.more)
    end
    f.place:SetText(("#%d of %d combos · click for the list%s"):format(k or 1, n, wf))
  end
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
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    if InCombatLockdown and InCombatLockdown() then return end
    self:StartMoving() self.moving = true
  end)
  f:SetScript("OnDragStop", endDrag)
  f:SetScript("OnHide", endDrag)
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
  f.heads = { K.fs(f, "", 9, "dim"), K.fs(f, "fights", 9, "dim"), K.fs(f, "dps", 9, "dim") }
  f.colHeads = {}
  for _, c in ipairs(C.COLS) do f.colHeads[c] = K.fs(f, c, 9, "dim") end
  f.rows = {}
  f.detail = K.fs(f, "", 9, "muted")
  f.detail:SetJustifyH("LEFT")
  f.foot = K.fs(f, "", 9, "dim")
  f.foot:SetPoint("BOTTOMLEFT", 8, 7)
  -- NEVER ON THE ESCAPE LIST (17 Nov, Arn: "I pressed esc when not in the window and it closed it" - the boss list's
  -- lesson again): the x or /bist combo closes it, nothing else
  f:Hide()
  C.frame = f
  return f
end
--- The list's size: the saved one, inside the bounds.
function C.Size()
  local d = db()
  local w = math.max(C.W_MIN, math.min(C.W_MAX, tonumber(d.w) or C.W))
  local h = math.max(C.H_MIN, math.min(C.H_MAX, tonumber(d.h) or C.H))
  return w, h
end
--- How many rows the height holds.
function C.RowCount()
  local _, h = C.Size()
  return math.max(3, math.floor((h - 38 - 62 - 22) / C.ROW))
end
--- Lay the list out on its size: the columns on the width, as many rows as the height holds.
function C.Layout()
  local f = C.frame
  if not f then return end
  local K = F()
  local w, h = C.Size()
  f:SetSize(w, h)
  local nameW = w - 16 - 120
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
  f.heads[3]:ClearAllPoints() f.heads[3]:SetPoint("TOPLEFT", 10 + nameW + 54, -24) f.heads[3]:SetWidth(56) f.heads[3]:SetJustifyH("RIGHT")
  local n = C.RowCount()
  for i = 1, math.max(n, #f.rows) do
    local r = f.rows[i]
    if i <= n and not r then
      r = CreateFrame("Button", nil, f)
      r.lit = K.tex(r, "BACKGROUND", "accent", 0)               -- rows glow on hover (the family rule): a wash + a bar
      r.bar = r:CreateTexture(nil, "ARTWORK")
      r.bar:SetPoint("TOPLEFT") r.bar:SetPoint("BOTTOMLEFT") r.bar:SetWidth(3)
      do local rr, g, b = K.color("accent") r.bar:SetColorTexture(rr, g, b, 1) end
      r.bar:SetAlpha(0)
      r.name = K.fs(r, "", 9, "ink") r.name:SetJustifyH("LEFT")
      r.cells = {}
      for _, c in ipairs(C.COLS) do r.cells[c] = K.fs(r, "", 9, "ink") r.cells[c]:SetJustifyH("LEFT") end
      r.n = K.fs(r, "", 9, "muted") r.n:SetJustifyH("RIGHT")
      r.dps = K.fs(r, "", 9, "good") r.dps:SetJustifyH("RIGHT")
      r:SetScript("OnClick", function(self) if self.g then C.sel = self.g.combo C.Paint() end end)
      r:SetScript("OnEnter", function(self) self.hover = true C.PaintRow(self) end)
      r:SetScript("OnLeave", function(self) self.hover = nil C.PaintRow(self) end)
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
          x = x + cw
        end
        r.n:ClearAllPoints() r.n:SetPoint("LEFT", 2 + nameW, 0) r.n:SetWidth(52)
        r.dps:ClearAllPoints() r.dps:SetPoint("LEFT", 2 + nameW + 54, 0) r.dps:SetWidth(56)
        r:Show()
      else
        r.g = nil
        r:Hide()
      end
    end
  end
  f.detail:ClearAllPoints()
  f.detail:SetPoint("TOPLEFT", 10, -42 - n * C.ROW)
  f.detail:SetWidth(w - 20)
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
  p:SetSize(C.Size() - 16, 128)
  K.tex(p, "BACKGROUND", "header", 0.98)
  K.border(p, "edge", 1)
  local d = function() return db() end
  p.card = swRow(p, -4, "card after each fight")
  p.card:SetScript("OnClick", function() d().card = d().card == false and true or false C.PaintSet() end)
  p.card.paint = function() p.card.value:SetText(d().card ~= false and "ON" or "OFF") end
  p.scroll = swRow(p, -22, "proc text in a fight")
  p.scroll:SetScript("OnClick", function() d().scroll = d().scroll == false and true or false C.PaintSet() end)
  p.scroll.paint = function() p.scroll.value:SetText(d().scroll ~= false and "ON" or "OFF") end
  p.min = stepRow(p, -40, "shortest fight counted", C.Min, function(v) d().min = v end, 0, 60, 5, " s")
  p.wid = stepRow(p, -58, "width", function() return (C.Size()) end, function(v) d().w = v C.Layout() end, C.W_MIN, C.W_MAX, C.STEP, " px")
  p.hei = stepRow(p, -76, "height", function() return select(2, C.Size()) end, function(v) d().h = v C.Layout() end, C.H_MIN, C.H_MAX, C.STEP, " px")
  p.reset = swRow(p, -100, "RESET  (the look - never your fights)")
  p.reset:SetScript("OnClick", function() local x = d() x.w, x.h, x.card, x.min, x.scroll = nil, nil, nil, nil, nil C.Layout() C.PaintSet() end)
  p:Hide()
  f.sw = p
  return p
end
function C.PaintSet()
  local p = C.frame and C.frame.sw
  if not p then return end
  for _, k in ipairs({ "card", "scroll", "min", "wid", "hei" }) do if p[k] and p[k].paint then p[k].paint() end end
  C.Paint()
end
function C.ToggleSet(want)
  local p = C.BuildSet()
  if not p then return false end
  if want == nil then want = not p:IsShown() end
  if want then p:Show() C.PaintSet() else p:Hide() end
  return p:IsShown()
end

function C.PaintRow(r)
  local sel = r.g and r.g.combo == C.sel
  r.lit:SetAlpha(sel and 0.35 or ((r.hover and r.g) and 0.16 or 0))
  r.bar:SetAlpha((sel or (r.hover and r.g)) and 1 or 0)
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
    for _, c in ipairs(C.COLS) do
      local v = cells and cells[c] or ""
      r.cells[c]:SetText(v)
      local col = (i == 1 and g) and "gold" or (v == "-" and "muted" or "ink")
      r.cells[c]:SetTextColor(F().color(col))
    end
    r.n:SetText(g and tostring(g.n) or "")
    r.dps:SetText(g and tostring(math.floor(g.dps + 0.5)) or "")
    C.PaintRow(r)
  end
  local lines = {}
  if C.sel then
    local n = 0
    local fights = db().fights or {}
    for k = #fights, 1, -1 do
      local fi = fights[k]
      if fi.combo == C.sel and (fi.dur or 0) >= C.Min() then
        n = n + 1
        if n > 4 then break end
        lines[#lines + 1] = ("%s  %s  %d dps%s"):format(fi.mob or "?", fi.active and ("%d/%d s"):format(math.floor(fi.active + 0.5), math.floor(fi.dur + 0.5))
          or ("%d s"):format(math.floor(fi.dur + 0.5)), math.floor(fi.dmg / C.Time(fi) + 0.5),
          (fi.wf or 0) > 0 and ("  Windfury %d%%"):format(math.floor(fi.wf * 100 + 0.5)) or
          ((fi.ft or 0) > 0 and ("  Flametongue %d%%"):format(math.floor(fi.ft * 100 + 0.5)) or ""))
      end
    end
  end
  if C.sel then                                    -- the newest fight of that combo, spell by spell
    local fights = db().fights or {}
    for k = #fights, 1, -1 do
      local fi = fights[k]
      if fi.combo == C.sel and fi.spells and #fi.spells > 0 then
        local parts = {}
        for i = 1, math.min(3, #fi.spells) do
          parts[#parts + 1] = ("%s %d%%"):format(fi.spells[i].name, math.floor(fi.spells[i].share * 100 + 0.5))
        end
        lines[#lines + 1] = "last fight: " .. table.concat(parts, "  -  ")
        break
      end
    end
  end
  f.detail:SetText(#lines > 0 and table.concat(lines, "\n") or (#list > 0 and "click a combo: its last fights" or
    "no fights yet - fight something with an imbue and totems up"))
  f.foot:SetText(C.Min() > 0 and ("%d fights kept  ·  fights under %d s are not counted"):format(#(db().fights or {}), C.Min())
    or ("%d fights kept  ·  dps over the time you swing"):format(#(db().fights or {})))
end
function C.IsOpen() return C.frame ~= nil and C.frame:IsShown() end
function C.Toggle(want)
  local f = C.Build()
  if want == nil then want = not f:IsShown() end
  if want then C.Layout() f:Show() C.Paint() else f:Hide() end
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
  proc (it is a solo tool first). Each fight counts its procs (rec.procs). The words rise beside the card's spot and fade;
  db.scroll turns them off. ]]
C.BURST, C.SCROLL_FOR, C.SCROLL_RISE, C.SCROLL_MAX = 0.12, 1.6, 46, 8
C.SWING_ACTIONS = { WOUND = true, MISS = true, DODGE = true, PARRY = true, BLOCK = true, DEFLECT = true, ABSORB = true, RESIST = true, IMMUNE = true, EVADE = true }
function C.Hit(action, school)
  local cur = C.cur
  if not cur then return end
  action = plain(action)
  if type(action) ~= "string" or not C.SWING_ACTIONS[action] then return end
  school = plain(school)
  local fire = type(school) == "number" and school == 4
  local now = GetTime and GetTime() or 0
  local b = cur.burst
  if not b or now - b.at > C.BURST then
    b = { at = now, swings = 0, fire = 0 }
    cur.burst = b
    if C_Timer and C_Timer.After then C_Timer.After(C.BURST + 0.02, function() C.CloseBurst(cur, b) end) end
  end
  if fire then b.fire = b.fire + 1 else b.swings = b.swings + 1 end
end
function C.CloseBurst(cur, b)
  if b.done then return end
  b.done = true
  cur.procs = cur.procs or { extra1 = 0, extra2 = 0, more = 0, fire = 0 }
  local extra = b.swings - 1
  local words = {}
  if extra == 1 then cur.procs.extra1 = cur.procs.extra1 + 1 words[#words + 1] = "+1 extra hit"
  elseif extra == 2 then cur.procs.extra2 = cur.procs.extra2 + 1 words[#words + 1] = "+2 extra hits"
  elseif extra > 2 then cur.procs.more = cur.procs.more + 1 words[#words + 1] = ("+%d extra hits"):format(extra) end
  if b.fire > 0 and b.swings > 0 then cur.procs.fire = cur.procs.fire + 1 words[#words + 1] = "Flametongue" end
  if #words > 0 and db().scroll ~= false then C.Scroll(table.concat(words, "  "), b.fire > 0 and b.swings < 2) end
end
--- One word rising beside the card's spot.
function C.Scroll(text, fireOnly)
  local K = F()
  local host = C.scrollHost
  if not host then
    host = CreateFrame("Frame", "BiSToolsComboScroll", UIParent)
    host:SetSize(200, 120)
    host:SetFrameStrata("MEDIUM")
    host.pool = {}
    host:SetScript("OnUpdate", function(self, e)
      local live = 0
      for _, w in ipairs(self.pool) do
        if w.left and w.left > 0 then
          w.left = w.left - (tonumber(e) or 0)
          local k = 1 - math.max(0, w.left) / C.SCROLL_FOR
          w:ClearAllPoints()
          w:SetPoint("BOTTOM", self, "BOTTOM", 0, k * C.SCROLL_RISE + (w.lane or 0) * 14)
          w:SetAlpha(math.min(1, math.max(0, w.left) / (C.SCROLL_FOR * 0.4)))
          if w.left <= 0 then w:Hide() else live = live + 1 end
        end
      end
      if live == 0 then self:Hide() end
    end)
    C.scrollHost = host
  end
  host:ClearAllPoints()
  if C.card and C.card:GetPoint() then host:SetPoint("BOTTOM", C.card, "TOP", 0, 4)
  else
    local p = db().cardPos
    if type(p) == "table" and p[1] then host:SetPoint("BOTTOM", UIParent, p[2] or p[1], p[3] or 0, (p[4] or 0) + 4)
    else host:SetPoint("BOTTOM", UIParent, "TOP", 0, -170 + 4) end
  end
  local w
  for _, x in ipairs(host.pool) do if not (x.left and x.left > 0) then w = x break end end
  if not w then
    if #host.pool >= C.SCROLL_MAX then w = host.pool[1] else w = K.fs(host, "", 14, "gold") host.pool[#host.pool + 1] = w end
  end
  local lanes = {}
  for _, x in ipairs(host.pool) do if x ~= w and x.left and x.left > C.SCROLL_FOR * 0.6 then lanes[x.lane or 0] = true end end
  local lane = 0
  while lanes[lane] do lane = lane + 1 end
  w.lane = lane
  w:SetText(text)
  w:SetTextColor(F().color(fireOnly and "warn" or "gold"))
  w.left = C.SCROLL_FOR
  w:SetAlpha(1)
  w:Show()
  host:Show()
  return w
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
                    "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "UNIT_COMBAT" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, a1, a2, a3, a4, a5)
  if event == "UNIT_COMBAT" then                       -- (first and quick: it fires for every unit hit, all the time)
    if a1 == "target" and C.cur then C.Hit(a2, a5) end
    return
  end
  if event == "PLAYER_REGEN_DISABLED" then             -- a drag still on ends before the fight takes the mouse
    endDrag(C.frame) endDrag(C.card)
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
  elseif event == "PLAYER_TOTEM_UPDATE" then if C.cur then C.ScanTotems(C.cur.totems) end
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
      help = "Words rising beside the card while you fight: +1 extra hit (Windfury Totem), +2 extra hits (Windfury Weapon), Flametongue. Read from hits landing in the same instant.",
      get = function(d) return d.scroll ~= false end, set = function(d, v) d.scroll = v and true or false end },
    { kind = "step", label = "shortest fight counted", help = "0 = every fight counts (a long fight weighs more than a short one). Above 0, shorter fights are kept but not ranked.",
      min = 0, max = 60, step = 5, get = function(d) return tonumber(d.min) or C.MIN end,
      set = function(d, v) d.min = v if C.IsOpen() then C.Paint() end end, show = function(d) return (tonumber(d.min) or C.MIN) .. " s" end },
    { kind = "button", label = "the combo list", button = "open",
      help = "Every imbue + totem combo you fought with, ranked by damage per second, with how many fights each is based on.",
      action = function(d) C.db = d C.Toggle(true) end },
  },
  OnInit = function(_, d) C.db = d end,
  OnOpen = function(_, d, recenter)
    C.db = d
    if recenter then
      if C.frame then C.frame:ClearAllPoints() C.frame:SetPoint("CENTER") end
      if C.card then C.card:ClearAllPoints() C.card:SetPoint("TOP", UIParent, "TOP", 0, -170) d.cardPos = nil end
      return
    end
    C.Toggle(true)
  end,
  IsOpen = function() return C.IsOpen() end,
  OnClose = function() C.Toggle(false) end,
  OnDisable = function() C.cur = nil if C.frame then C.frame:Hide() end if C.card then C.card:Hide() end end,
  OnSlash = function(_, d, args)
    C.db = d
    local cmd = tostring(args or ""):match("^(%S*)") or ""
    if cmd == "probe" then C.Probe() return end
    if cmd == "live" then C.LiveArm() return end
    if cmd == "reach" then C.ReachProbe() return end
    if cmd == "why" then
      say("combo: recording %s - last fight: %s", R:Enabled("combo") and "ON" or "OFF (/bist on combo)", C.lastWhy or "none since the reload")
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
