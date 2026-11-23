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
--- The id of a totem by its plain name among the ones that fit (the highest rank the client offers).
function T.Find(slot, name)
  local C, best = NS.Combo, nil
  for _, id in ipairs(T.List(slot)) do
    local n = T.Name(id)
    if n == name or (n and C and C.Base and C.Base(n) == name) then best = id end
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
