--[[
  BiSTools / Tools / Combo.lua - THE IMBUE + TOTEM COMBO (17 Nov 2026, Arn: "after fight want to see what imbue and
  totem combo is best"). Step one is the PROBE (the new-feature rule: what only the game can answer, first):

    /bist combo probe      - after a fight: what an addon can read on Forever

  It prints, each value as plain / secret / nil (never compared, never added):
    - your weapon imbues: GetWeaponEnchantInfo (main hand, off hand - the enchant id says which imbue)
    - your totems: GetTotemInfo 1-4 (the names)
    - the game's own damage meter: C_DamageMeter - is it on, which fights it kept, the newest one's sources (you), and
      YOUR spells in it (Windfury Attack, Flametongue Attack, Stormstrike ...) with their totals
  The feature (each fight's combo and its damage per second, the best combo per fight length) is built on what this
  answers - nothing guessed.
]]
local _, NS = ...
local R = NS.Registry
local C = {}
NS.Combo = C

local function kind(v)
  if v == nil then return "nil" end
  if issecretvalue and issecretvalue(v) then return "SECRET" end
  return tostring(v)
end
local function say(fmt, ...) NS.Print(fmt, ...) end

--- One table's keys and the kinds of their values, on one line (to learn the shape the game hands back).
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
  -- the imbues
  if GetWeaponEnchantInfo then
    local ok, mh, mhExp, mhCh, mhId, oh, ohExp, ohCh, ohId = pcall(GetWeaponEnchantInfo)
    if ok then
      out("imbue: main hand %s (id %s, %s ms left, charges %s) | off hand %s (id %s)", kind(mh), kind(mhId), kind(mhExp), kind(mhCh), kind(oh), kind(ohId))
    else
      out("imbue: GetWeaponEnchantInfo refused")
    end
  else
    out("imbue: no GetWeaponEnchantInfo")
  end
  -- the totems
  if GetTotemInfo then
    local t = {}
    for slot = 1, 4 do
      local ok, have, name = pcall(GetTotemInfo, slot)
      t[#t + 1] = slot .. "=" .. (ok and (kind(have) .. ":" .. kind(name)) or "refused")
    end
    out("totems: %s", table.concat(t, "  "))
  end
  -- the game's damage meter
  local D = C_DamageMeter
  if not D then out("damage meter: no C_DamageMeter") return lines end
  local okA, avail = pcall(D.IsDamageMeterAvailable)
  out("damage meter: available %s", okA and kind(avail) or "refused")
  local E = Enum or {}
  local T = E.DamageMeterType or {}
  local ST = E.DamageMeterSessionType or {}
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
  local okD, dur = pcall(D.GetSessionDurationSeconds, s.sessionID or s.combatSessionID)
  if okD then out("duration: %s s", kind(dur)) end
  local me = UnitGUID and UnitGUID("player")
  local mine
  local okL = pcall(function()
    for i, src in ipairs(s.combatSources or {}) do
      if i <= 5 then out("source %d: %s", i, shape(src, 10)) end
      local g = src.sourceGUID or src.guid
      if g ~= nil and not (issecretvalue and issecretvalue(g)) and g == me then mine = src end
    end
  end)
  if not okL then out("sources: refused") end
  out("you in it: %s", mine and "yes" or "not found")
  -- YOUR spells in that fight
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

R:Register({
  name = "combo",
  short = "cmb",
  desc = "which weapon imbue and totems did the most damage (first: the probe)",
  usage = "/bist combo probe  (short: cmb)",
  slashWhenOff = true,
  defaultOff = true,
  defaults = {},
  OnSlash = function(_, _, args)
    local cmd = tostring(args or ""):match("^(%S*)") or ""
    if cmd == "probe" then
      C.Probe()
      return
    end
    say("combo: /bist combo probe - after a fight, what the game lets an addon read (imbues, totems, the damage meter)")
  end,
})
