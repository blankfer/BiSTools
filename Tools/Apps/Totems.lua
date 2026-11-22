--[[ BiSTools / Tools / Apps / Totems.lua  --  THE THREE CALLS (22 Nov 2026).

  Arn, 22 Nov: "if we can just have a manager that edits these so i can drop them all at once, because right now i gotta click them
  all one at a time" (Call of the Elements, Call of the Ancestors, Call of the Spirits).

  A Call drops what stands in its four places of the game's own totem bar: fire, earth, water, air. The client lets an addon fill
  them out of a fight (SetMultiCastSpell, in Forever's census 21 Oct; the game's bar is three pages of four actions, from
  (GetMultiCastBarIndex() - 1) * 12 on). UNVERIFIED live: every fill is read back (GetActionInfo) and said when it did not take.
  Casting a Call is the player's own click on a secure button (the deck's overlay). No frames, no events here. A shaman's app only. ]]
local _, NS = ...
local DP, R = NS.DeckPages, NS.Registry
if not (DP and DP.App) then return end
local T = {}
NS.Totems = T

T.CALLS = {
  { id = 66842, name = "Call of the Elements", tab = "ELEMENTS" },
  { id = 66843, name = "Call of the Ancestors", tab = "ANCESTORS" },
  { id = 66844, name = "Call of the Spirits", tab = "SPIRITS" },
}
T.SLOTS = { "Fire", "Earth", "Water", "Air" }
T.SLOT_OF = { fire = 1, earth = 2, water = 3, air = 4 }

local function plain(v) if v == nil or (issecretvalue and issecretvalue(v)) then return nil end return v end
local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, ...)
  if not ok then return nil end
  return plain(a), plain(b)
end
local function fighting() return ask(InCombatLockdown) and true or false end

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
--- Fill a Call with these totems (by name; the places they say nothing about stay as they are). Answers how many took, how many not.
function T.Fill(page, names)
  local C, ok, bad = NS.Combo, 0, 0
  for _, name in ipairs(names or {}) do
    local slot = C and C.ELEMENT and T.SLOT_OF[C.ELEMENT[name] or ""]
    local id = slot and T.Find(slot, name)
    if id and T.Set(page, slot, id) then ok = ok + 1 else bad = bad + 1 end
  end
  return ok, bad
end
--- Do these totems stand in it already?
function T.Holds(page, names)
  local C = NS.Combo
  for _, name in ipairs(names or {}) do
    local slot = C and C.ELEMENT and T.SLOT_OF[C.ELEMENT[name] or ""]
    if not slot or T.Get(page, slot) ~= T.Find(slot, name) then return false end
  end
  return #(names or {}) > 0
end
--- The Call the combo fills: your pick, else the last one you know (so the one you use every day stays yours).
function T.ComboPage()
  local db = R:Get("combo") and R:DBFor(R:Get("combo")) or {}
  if T.CALLS[db.callPage or 0] and T.Knows(db.callPage) then return db.callPage end
  for i = #T.CALLS, 1, -1 do if T.Knows(i) then return i end end
end
--- The Calls you know: their places.
function T.Known()
  local out = {}
  for i in ipairs(T.CALLS) do if T.Knows(i) then out[#out + 1] = i end end
  return out
end
--- The Call that is chosen (the Combo app's icons), else the first you know.
function T.Now()
  local db = R:Get("combo") and R:DBFor(R:Get("combo")) or {}
  if T.CALLS[db.callNow or 0] and T.Knows(db.callNow) then return db.callNow end
  return T.Known()[1]
end
function T.Choose(page)
  local db = R:Get("combo") and R:DBFor(R:Get("combo"))
  if db and T.CALLS[page or 0] then db.callNow = page end
end
--- Its totems by their plain names: { [slot] = name }.
function T.Names(page)
  local C, out = NS.Combo, {}
  for slot = 1, 4 do
    local n = T.Name(T.Get(page, slot))
    if n then out[slot] = C and C.Base and C.Base(n) or n end
  end
  return out
end
--- A button that fills that Call with these totems and casts it, in one click (nil = this character cannot).
function T.DropAll(names, word)
  local page = T.Can() and T.ComboPage()
  if not page or #(names or {}) == 0 then return nil end
  return { word = word, spell = T.CALLS[page].name, tip = "Fills " .. T.CALLS[page].name .. " with these and drops them all. Its water totem stays as you have it.",
    ok = function()
      local _, bad = T.Fill(page, names)
      T.said = bad > 0 and (bad .. " did not go into " .. T.CALLS[page].name) or nil
      if bad == 0 then T.Choose(page) end
      if bad > 0 then NS.Print("totems: %s - click again, or open the Totems app", T.said) end
      return bad == 0
    end }
end

-- THE APP ------------------------------------------------------------------------------------------------------------------
local D = BiSTheme and BiSTheme.Deck
local pick                                                 -- the place being changed: { page, slot }
local function known() return T.Known() end
--- The app on one Call, on one of its places.
function T.Open(page, slot)
  for i, x in ipairs(known()) do
    if x == page and D and D.defs["BiSTools:totems"] then
      D.defs["BiSTools:totems"].tab = i
      pick = slot and { page = page, slot = slot } or nil
      D.Open("BiSTools:totems")
      return true
    end
  end
  return false
end
local function words(id) local n = T.Name(id) local C = NS.Combo return n and (C and C.Base and C.Base(n) or n):gsub(" Totem$", "") or nil end

function T.Register()
  if T.done or not (D and D.Register) or not T.Shaman() then return false end
  T.done = true
  if D.ART then D.ART["BiSTools:totems"] = "Interface\\Icons\\Spell_Nature_EarthBindTotem" end
  D.Register{
    owner = "BiSTools", key = "totems", name = "Totems", icon = "To", order = 35,
    about = "What each of your Calls drops: four places each, changed with a click.",
    page = {
      tour = { { text = "A Call drops its four totems at once. Click a place to change it.", note = "Out of a fight." } },
      kicker = function() return "your calls" end,
      title = function() return "Totems" end,
      tabs = function() local t = {} for i, n in ipairs(known()) do t[i] = T.CALLS[n].tab end return t end,
      text = function(tab)
        if #known() == 0 then return "You learn Call of the Elements first: it drops all four totems at once." end
        if not T.Can() then return "This client does not let an addon fill the totem bar." end
      end,
      rows = function(tab)
        local page = known()[tab]
        local out = {}
        if not page then return out end
        if pick and pick.page == page then
          out[1] = { mark = "<", text = "Back", act = { word = "back", peek = true, fn = function() pick = nil end } }
          local now = T.Get(page, pick.slot)
          for _, id in ipairs(T.List(pick.slot)) do
            out[#out + 1] = { pic = T.Icon(id), text = words(id) or "?", verb = id == now and "HERE" or "PUT", verbInk = id == now and "good" or nil,
              act = { word = "put", peek = true, fn = function()
                if not T.Set(page, pick.slot, id) then T.said = "The game did not take it" else T.said = nil end
                pick = nil
              end } }
          end
          out[#out + 1] = { mark = "-", text = "Nothing", verb = now and "PUT" or "HERE", act = { word = "put", peek = true, fn = function() T.Set(page, pick.slot, nil) pick = nil end } }
          return out
        end
        for slot, name in ipairs(T.SLOTS) do
          local id = T.Get(page, slot)
          out[slot] = { pic = T.Icon(id), mark = "-", text = name .. ": " .. (words(id) or "nothing"), verb = "CHANGE",
            act = { word = "change", peek = true, fn = function() pick = { page = page, slot = slot } end } }
        end
        local C = NS.Combo
        local best = C and C.Rank and C.Rank()[1]
        local try = C and C.TryNext and C.TryNext()
        local function fill(head, x, tip)
          if not x or #(x.totems or {}) == 0 then return end
          out[#out + 1] = { pic = C.IconFor and C.IconFor(x.imbue), mark = "-", text = head, right = T.Holds(page, x.totems) and "IN IT" or nil, ink = "good", verb = "FILL", tip = tip .. table.concat(x.totems, ", "),
            act = { word = "fill", peek = true, fn = function()
              local ok, bad = T.Fill(page, x.totems)
              T.said = bad > 0 and (bad .. " did not go in") or (ok .. " in")
            end } }
        end
        fill("From your best combo", best, "Your best combo's totems: ")
        fill("From the one to try next", try, "The combo to try next: ")
        out[#out + 1] = { mark = "-", text = "The Combo app drops with this one", verb = T.ComboPage() == page and "YES" or "NO", verbInk = T.ComboPage() == page and "good" or nil,
          tip = "DROP ALL in the Combo app fills this Call and casts it",
          act = { word = "use", peek = true, fn = function() local db = R:DBFor(R:Get("combo")) db.callPage = page end } }
        return out
      end,
      say = function() return T.said end,
      big = function(tab)
        local page = known()[tab]
        return page and { word = "DROP: " .. T.CALLS[page].tab, spell = T.CALLS[page].name, tip = T.CALLS[page].name } or nil
      end,
      keys = function() return { { word = "RECALL", spell = "Totemic Recall", tip = "Totemic Recall: they go, some mana back" } } end,
    },
  }
  return true
end
