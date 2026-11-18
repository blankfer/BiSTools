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
function C.Pull()
  local tot = C.ScanTotems({})
  local imbue = C.ImbueNow()
  C.cur = { imbue = imbue, totems = copySet(tot), active = 0, swing = C.Swinging(), start = now(),
            nowImbue = imbue, nowTot = tot, segs = { { imbue = imbue, tot = copySet(tot), at = now() } } }
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
  if added and cur.headed and db().scroll ~= false then
    local secs = math.max(0, now() - (cur.start or now()))
    C.TapePrint(("- - - - CUT %d:%02d - - - -"):format(math.floor(secs / 60), math.floor(secs % 60)))
    C.TapeSet(imbue, tot)
    return true
  end
  return false
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
  if cur then cur.endAt = now() C.lastHits, C.lastForeign = cur.hitStats, cur.foreign C.TapeEnd(cur) end
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
                procs = cur.procs, mixed = mixed or nil }
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
      t = f:CreateTexture(nil, "ARTWORK")
      t:SetSize(C.CARD_ICON, C.CARD_ICON)
      if t.SetTexCoord then t:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
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
    self:StartMoving() self.moving = true
  end)
  local function keep(self)
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
  f.heads = { K.fs(f, "", 9, "dim"), K.fs(f, "fights", 9, "dim"), K.fs(f, "dps", 9, "dim") }
  f.colHeads = {}
  for _, c in ipairs(C.COLS) do f.colHeads[c] = K.fs(f, c, 9, "dim") end
  f.rows = {}
  f.detail = K.fs(f, "", 9, "muted")
  f.detail:SetJustifyH("LEFT")
  f.foot = K.fs(f, "", 9, "dim")
  f.foot:SetPoint("BOTTOMLEFT", 8, 7)
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
      r.icons = {}
      for _, c in ipairs(C.COLS) do
        r.icons[c] = {}
        for k = 1, 2 do                                       -- (two totems of one element stack on Forever: two icons)
          local t = r:CreateTexture(nil, "ARTWORK")
          t:SetSize(C.ROW - 2, C.ROW - 2)
          if t.SetTexCoord then t:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
          t:Hide()
          r.icons[c][k] = t
        end
      end
      r.n = K.fs(r, "", 9, "muted") r.n:SetJustifyH("RIGHT")
      r.dps = K.fs(r, "", 9, "good") r.dps:SetJustifyH("RIGHT")
      r:SetScript("OnClick", function(self) if self.g then C.sel = self.g.combo C.Paint() end end)
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

--- A row's names on hover (the icons carry no words).
function C.RowTip(r)
  if not (r.g and GameTooltip) then return end
  GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
  GameTooltip:AddLine(r.g.imbue or "no imbue", 1, 1, 1)
  for _, n in ipairs(r.g.totems or {}) do GameTooltip:AddLine(n, 0.8, 0.8, 0.8) end
  GameTooltip:AddLine(("%d fights  -  %d dps"):format(r.g.n or 0, math.floor((r.g.dps or 0) + 0.5)), 0.6, 0.9, 0.6)
  GameTooltip:Show()
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
  if action ~= nil and (type(action) ~= "string" or not C.SWING_ACTIONS[action]) then return end   -- (a heal, a plain non-swing)
  local fire = type(school) == "number" and school == 4
  local b = cur.burst
  local win = C.BurstWindow()
  if not b or now - b.at > win then
    b = { at = now, swings = 0, fire = 0 }
    cur.burst = b
    if C_Timer and C_Timer.After then C_Timer.After(win + 0.02, function() C.CloseBurst(cur, b) end) end
  end
  if fire then b.fire = b.fire + 1 else b.swings = b.swings + 1 end
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
  local totem = (cur.nowTot or cur.totems or {})["Windfury Totem"] and true or false
  if extra == 1 and weapon and not totem then extra = 2 end
  if extra == 1 then cur.procs.extra1 = cur.procs.extra1 + 1 words[#words + 1] = "+1 extra hit"
  elseif extra == 2 then cur.procs.extra2 = cur.procs.extra2 + 1 words[#words + 1] = "+2 extra hits"
  elseif extra > 2 then cur.procs.more = cur.procs.more + 1 words[#words + 1] = ("+%d extra hits"):format(extra) end
  if b.fire > 0 and b.swings > 0 then cur.procs.fire = cur.procs.fire + 1 words[#words + 1] = "Flametongue" end
  -- (17 Nov, Arn's shot of the tape: "+1 EXTRA HIT  FLAMETONGUE" wrapped onto two lines and the next line printed over
  -- it - each word is its own line now, and a line never wraps)
  if db().scroll ~= false then for _, w in ipairs(words) do C.Scroll(w, w == "Flametongue") end end
end
--[[ THE RECEIPT TAPE (17 Nov 2026, Arn: "make it like a receipt calculator printer, it scrolling from bottom to top"): a
  small strip of paper beside the card's spot. Each proc prints a line at the bottom - the fight's clock, then the words
  ("0:12  +1 EXTRA HIT") - and the paper rolls up a line, the oldest going off the top. When the fight ends it prints a
  rule and the total ("TOTAL  7 PROCS"), lingers C.TAPE.linger s (held while the mouse is on it) and fades. Out of a
  fight it drags anywhere (db.tapePos). Nothing ticks while it is away. ]]
-- (17 Nov, Arn's first look: "more warm white candle light" - "its so bright" - "30 sec idle time before it fades away":
-- the paper a dim warm cream, brown ink, and it waits C.TAPE.linger s after the LAST line it printed, in a fight or not)
C.TAPE = { w = 190, lines = 7, lh = 15, roll = 0.15, linger = 30, fade = 1.5, pad = 5, alpha = 0.82, keep = 300 }
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
  t:SetSize(T.w, T.lines * T.lh + 2 * T.pad)
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
  t.edge = t:CreateTexture(nil, "BORDER")                       -- the printer's lip at the bottom, where the paper comes out
  t.edge:SetPoint("BOTTOMLEFT") t.edge:SetPoint("BOTTOMRIGHT") t.edge:SetHeight(2)
  t.edge:SetColorTexture(0.25, 0.24, 0.22, 1)
  t.rows, t.spare, t.shift, t.log, t.back = {}, {}, 0, {}, 0
  -- SCROLL BACK (17 Nov 2026, Arn: "does the receipt keep going or is it scrollable?"): the whole fight is kept (t.log, up
  -- to C.TAPE.keep lines); the mouse wheel over the paper rolls it back, and new lines wait below while you read
  if t.EnableMouseWheel then t:EnableMouseWheel(true) end
  t:SetScript("OnMouseWheel", function(self, delta) C.TapeBack(self, (tonumber(delta) or 0) > 0 and 1 or -1) end)
  t.hint = t:CreateFontString(nil, "OVERLAY")
  t.hint:SetFont("Fonts\\ARIALN.TTF", 10, "")
  t.hint:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -T.pad, 2)
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
    r.y = T.pad + (n - i) * T.lh - t.shift
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
    r:SetWidth(T.w - 2 * T.pad - 4)
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
    t.back = math.min(t.back + 1, math.max(0, #t.log - T.lines))
    C.TapeHint(t)
    return nil
  end
  local r = newRow(t)
  ink(r, fire)
  r:SetText(text)
  r:Show()
  t.rows[#t.rows + 1] = r
  while #t.rows > T.lines + 1 do                               -- (one spare line rides off the top as the paper rolls)
    local old = table.remove(t.rows, 1)
    old:Hide()
    t.spare[#t.spare + 1] = old
  end
  t.shift = T.lh
  C.TapeLay(t)
  return r
end
--- Roll back (+1, older) or forward (-1) a line; the paper shows the log from there, no animation.
function C.TapeBack(t, step)
  local T = C.TAPE
  t.back = math.max(0, math.min((t.back or 0) + step, math.max(0, #t.log - T.lines)))
  for _, r in ipairs(t.rows) do r:Hide() t.spare[#t.spare + 1] = r end
  t.rows, t.shift = {}, 0
  local last = #t.log - t.back
  for k = math.max(1, last - T.lines + 1), last do
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
  local words = {}
  for n in pairs(tot or {}) do words[#words + 1] = ((C.TOTEMS[n] or n):gsub(" totem$", "")) end
  table.sort(words)
  C.TapePrint("IMBUE  " .. string.upper(imbue and (C.IMBUE_SHORT[imbue] or imbue) or "none"))
  C.TapePrint("TOTEMS  " .. (#words > 0 and string.upper(table.concat(words, " · ")) or "NONE"))
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
  add(pr.fire, "FLAMETONGUE", true)
  add(pr.extra2, "WF IMBUE")
  add(pr.extra1, totem and "WF TOTEM" or "+1 EXTRA HIT")
  add(pr.more, "BIG WINDFURY (+3 OR MORE)")
  table.sort(out, function(a, b) return a[1] > b[1] end)
  return out
end
--- The fight over: a rule, the total and what it was made of, then it lingers and fades.
function C.TapeEnd(cur)
  local t = C.tape
  if not (t and t:IsShown() and cur and cur.procs) then return end
  local pr = cur.procs
  local n = (pr.extra1 or 0) + (pr.extra2 or 0) + (pr.more or 0) + (pr.fire or 0)
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
    if okG and plain(grouped) == true then C.TapePrint("IN A GROUP: OTHERS MAY SLIP IN") end
  end
  local now = GetTime and GetTime() or 0
  local secs = (cur and cur.start) and math.max(0, now - cur.start) or 0
  return C.TapePrint(("%d:%02d  %s"):format(math.floor(secs / 60), math.floor(secs % 60), string.upper(text)), fireOnly)
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
    if C.cur then C.ScanTotems(C.cur.totems) C.SwitchCheck(C.cur, C.cur.nowImbue, C.ScanTotems({})) end
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
    if cmd == "forget" then d.fights, d.lastSid = {}, nil if C.IsOpen() then C.Paint() end say("combo: every fight forgotten") return end
    -- OPENING THE LIST MEANS "RECORD" (17 Nov, Arn's first try: the list opened with the tool still off, the fight went by)
    if not R:Enabled("combo") then
      R:SetEnabled("combo", true)
      say("combo: recording your fights from now on - /bist off combo stops it")
    end
    C.Toggle()
  end,
})
