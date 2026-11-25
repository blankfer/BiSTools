--[[ BiSTools / Tools / Apps / Totems.lua  --  THE CALLS (NS.Totems; 22 Nov 2026).

  Arn, 22 Nov: "if we can just have a manager that edits these so i can drop them all at once" (Call of the Elements, Call of the
  Ancestors, Call of the Spirits) - and, the same evening: "the totem set up fold into this because now we can select our totems and
  set them to the calls from here, instead of combo we call this BiS>totems". So there is no app of its own any more: this is what the
  Totems app (Tools/Apps/Combo.lua) asks about the game's totem bar.

  A Call drops what stands in its four places of that bar: fire, earth, water, air. The client lets an addon fill them out of a fight
  (SetMultiCastSpell; the bar is three pages of four actions, from (GetMultiCastBarIndex() - 1) * 12 on - READ right on Arn's client
  22 Nov; a WRITE is unverified live: every one is read back and said when it did not take). Casting a Call is the player's own click
  on a secure button (the deck's overlay). No frames, no events here. ]]
local _, NS = ...
local R = NS.Registry
local T = {}
NS.Totems = T

T.CALLS = {
  { id = 66842, name = "Call of the Elements", tab = "ELEMENTS" },
  { id = 66843, name = "Call of the Ancestors", tab = "ANCESTORS" },
  { id = 66844, name = "Call of the Spirits", tab = "SPIRITS" },
}
T.BRING = "Totemic Call"
T.RECALL = "Totemic Recall"                               -- (Arn, 23 Nov: "next to bring we do the recall"; 36936 on Forever)
T.SLOTS = { "Fire", "Earth", "Water", "Air" }

local function plain(v) if v == nil or (issecretvalue and issecretvalue(v)) then return nil end return v end
local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, ...)
  if not ok then return nil end
  return plain(a), plain(b)
end
local function fighting() return ask(InCombatLockdown) and true or false end
local function db() local tool = R:Get("combo") return tool and R:DBFor(tool) or {} end

function T.Shaman()
  if type(UnitClass) ~= "function" then return false end
  local ok, _, class = pcall(UnitClass, "player")
  return ok and plain(class) == "SHAMAN"
end
--- Does this client let the bar be filled?
function T.Can()
  return type(SetMultiCastSpell) == "function" and type(GetMultiCastTotemSpells) == "function" and type(GetActionInfo) == "function"
end
function T.Knows(i)
  local c = T.CALLS[i]
  local C = NS.Combo
  return c and C and C.Knows and C.Knows(c.name) or false
end
--- The Calls you know: their places.
function T.Known()
  local out = {}
  for i in ipairs(T.CALLS) do if T.Knows(i) then out[#out + 1] = i end end
  return out
end
--- The Call that is chosen, else the first you know.
function T.Now()
  local now = db().callNow
  if T.CALLS[now or 0] and T.Knows(now) then return now end
  return T.Known()[1]
end
function T.Choose(page) if T.CALLS[page or 0] then db().callNow = page end end
function T.Action(page, slot)
  local bar = ask(GetMultiCastBarIndex)
  return ((type(bar) == "number" and bar > 0 and bar or 12) - 1) * 12 + (page - 1) * 4 + slot
end
--- The spell that stands there (its id), or nil.
function T.Get(page, slot)
  local kind, id = ask(GetActionInfo, T.Action(page, slot))
  return kind == "spell" and type(id) == "number" and id > 0 and id or nil
end
function T.Name(id)
  if not (id and C_Spell and C_Spell.GetSpellName) then return nil end
  local n = ask(C_Spell.GetSpellName, id)
  return type(n) == "string" and n ~= "" and n or nil
end
function T.Icon(id) return id and C_Spell and C_Spell.GetSpellTexture and ask(C_Spell.GetSpellTexture, id) or nil end
--- The totems of yours that fit there: ids.
function T.List(slot)
  if type(GetMultiCastTotemSpells) ~= "function" then return {} end
  local got = { pcall(GetMultiCastTotemSpells, slot) }
  if not got[1] then return {} end
  local out = {}
  for i = 2, #got do local id = plain(got[i]) if type(id) == "number" and id > 0 then out[#out + 1] = id end end
  return out
end
--- Put a totem there (nil = nothing). Out of a fight only. true = it stands there now.
function T.Set(page, slot, id)
  if fighting() or not T.Can() then return false end
  if T.Get(page, slot) == id then return true end
  pcall(SetMultiCastSpell, T.Action(page, slot), id or 0)
  return T.Get(page, slot) == id
end
--- A rank's number ("Rank 3" -> 3), or nil when the game does not say.
function T.Rank(id)
  local sub = id and C_Spell and C_Spell.GetSpellSubtext and ask(C_Spell.GetSpellSubtext, id)
  return type(sub) == "string" and tonumber(sub:match("(%d+)")) or nil
end
--- The id of a totem by its plain name among the ones that fit: the highest rank the client offers (by its "Rank N"; the game
--- not saying = the last one it lists, as before).
function T.Find(slot, name)
  local C, best, top = NS.Combo, nil, nil
  for _, id in ipairs(T.List(slot)) do
    local n = T.Name(id)
    if n == name or (n and C and C.Base and C.Base(n) == name) then
      local r = T.Rank(id)
      if not best or not r or not top or r >= top then best, top = id, r or top end
    end
  end
  return best
end
--- A totem's name under an icon: short enough to be read there.
T.SHORT = { ["Strength of Earth"] = "Strength", ["Grace of Air"] = "Grace", ["Frost Resistance"] = "Frost Res", ["Fire Resistance"] = "Fire Res", ["Nature Resistance"] = "Nature Res",
  ["Healing Stream"] = "Healing", ["Poison Cleansing"] = "Poison", ["Disease Cleansing"] = "Disease", ["Tranquil Air"] = "Tranquil" }
function T.Short(name)
  local n = tostring(name or ""):gsub(" Totem$", ""):gsub(" Weapon$", "")
  return T.SHORT[n] or (#n > 12 and n:match("^%S+")) or n
end

--[[ NEWEST RANKS (Arn, 23 Nov: "i just leveled and the totems did not update to the newest ranks"): the game's totem bar keeps
  the rank it was given. After a level, or anything that changes your spells, every Call's totem and the phone's row move up to
  the newest rank of the same totem the bar offers (T.Find: its plain name, the highest it gives). Out of a fight only - a fight
  waits for its end. One look a moment after the burst; nothing ticks. ]]
T.UP_WAIT = 1.5
function T.Upgrade()
  -- ONLY WITH THE COMBO TOOL ON (25 Nov 2026, the release bug hunt): it rewrites the game's totem bar - never for a shaman who
  -- never switched the tool on (it is off on a new install)
  if not (R and R.Enabled and R:Enabled("combo")) then return 0 end
  if not (T.Shaman() and T.Can()) then return 0 end
  if fighting() then T.upLate = true return 0 end
  T.upLate = nil
  local C, n = NS.Combo, 0
  local function newest(slot, id)
    local name = id and T.Name(id)
    local base = name and C and C.Base and C.Base(name) or name
    local best = base and T.Find(slot, base)
    return best and best ~= id and best or nil
  end
  for _, page in ipairs(T.Known()) do
    for slot = 1, 4 do
      local best = newest(slot, T.Get(page, slot))
      if best and T.Set(page, slot, best) then n = n + 1 end
    end
  end
  local d = db().draft                                         -- (the phone's row, if it is changed and not saved yet)
  if type(d) == "table" and type(d.t) == "table" then
    for slot = 1, 4 do local best = d.t[slot] and newest(slot, d.t[slot]) if best then d.t[slot] = best n = n + 1 end end
  end
  if n > 0 and NS.Print then NS.Print("totems: %d moved up to their newest rank", n) end
  if n > 0 and C and C.CardSoon then C.CardSoon() end
  T.upN = n
  return n
end
function T.UpSoon(wait)
  if T.upPending then return end
  T.upPending = true
  local function go() T.upPending = nil T.Upgrade() end
  if C_Timer and C_Timer.After then C_Timer.After(wait or T.UP_WAIT, go) else go() end
end
local up = CreateFrame("Frame")
T.upEvents = up
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED" }) do pcall(up.RegisterEvent, up, e) end
up:SetScript("OnEvent", function(_, e)
  if e == "PLAYER_REGEN_ENABLED" then if T.upLate then T.UpSoon() end return end
  if not T.Shaman() then return end
  T.UpSoon(e == "PLAYER_LEVEL_UP" and 3 or nil)                -- (a level: the new ranks come a moment after it)
end)
