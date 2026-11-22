-- BiSTools / Tools / Apps / Disenchant.lua - the tool in the phone (dev/APPS.md).
-- The gear in your bags that can be disenchanted, as the glow marks it (D.Kind), and what you need to know before you do (Arn, 22 Nov:
-- "need more info on this if we can tie it to the equipment manager like how it says dmg"): which of your equipment sets it is in, its
-- item level against what you wear there, what it has and sells for. A row opens the item. Looking only: the disenchanting is the
-- processing app's (it knows each item by its own id, so it can never take the wrong one, and it leaves your sets alone).
local _, NS = ...
local DP = NS.DeckPages
if not (DP and DP.App) then return end

DP.App.disenchant = function()
  local DE, P, D = NS.DE, NS.Proc, BiSTheme.Deck
  local COLOUR = { [2] = "Green", [3] = "Blue", [4] = "Epic" }
  local TINT = { [2] = "uncommon", [3] = "rare", [4] = "epic" }
  -- where it is worn: the word, and the slots on you (two rings: the weaker one is what it would replace)
  local WORN = { INVTYPE_HEAD = { "head", 1 }, INVTYPE_NECK = { "neck", 2 }, INVTYPE_SHOULDER = { "shoulders", 3 }, INVTYPE_CHEST = { "chest", 5 }, INVTYPE_ROBE = { "chest", 5 },
    INVTYPE_WAIST = { "waist", 6 }, INVTYPE_LEGS = { "legs", 7 }, INVTYPE_FEET = { "feet", 8 }, INVTYPE_WRIST = { "wrists", 9 }, INVTYPE_HAND = { "hands", 10 },
    INVTYPE_FINGER = { "ring", 11, 12 }, INVTYPE_TRINKET = { "trinket", 13, 14 }, INVTYPE_CLOAK = { "cloak", 15 }, INVTYPE_WEAPON = { "one-hand", 16, 17 },
    INVTYPE_2HWEAPON = { "two-hand", 16 }, INVTYPE_WEAPONMAINHAND = { "main hand", 16 }, INVTYPE_WEAPONOFFHAND = { "off hand", 17 }, INVTYPE_HOLDABLE = { "off hand", 17 },
    INVTYPE_SHIELD = { "shield", 17 }, INVTYPE_RANGED = { "ranged", 18 }, INVTYPE_RANGEDRIGHT = { "ranged", 18 }, INVTYPE_THROWN = { "thrown", 18 }, INVTYPE_RELIC = { "relic", 18 } }
  local MOST = 12                                              -- stat lines of one item

  local function plain(v) if v == nil or (issecretvalue and issecretvalue(v)) then return nil end return v end
  local function asks(fn, ...)                                 -- every answer, a hidden one as nil
    if type(fn) ~= "function" then return nil end
    local r = { pcall(fn, ...) }
    if not r[1] then return nil end
    for i = 2, 13 do r[i] = plain(r[i]) end
    return unpack(r, 2, 13)
  end
  local function ask(fn, ...) return (asks(fn, ...)) end
  local function num(v) return type(v) == "number" and v or nil end
  local function level(link) return num(link and ask(C_Item and C_Item.GetDetailedItemLevelInfo, link)) end
  --- What you wear where it would go: its link and level (the lower of two), nil = nothing there.
  local function wornFor(where)
    local best, low
    for i = 2, where and #where or 0 do
      local link = ask(GetInventoryItemLink, "player", where[i])
      link = type(link) == "string" and link or nil
      local lv = level(link)
      if lv and (not low or lv < low) then best, low = link, lv end
    end
    return best, low
  end
  --- Every piece, the bags in order - walked once a moment (a paint asks several times). Those in no set first, the lowest first.
  local kept
  local function gear()
    local at = GetTime and GetTime() or 0
    if kept and kept.at == at then return kept end
    kept = { at = at }
    local K = C_Container or {}
    for bag = 0, DE.BAGS do
      for slot = 1, tonumber(ask(K.GetContainerNumSlots, bag)) or 0 do
        local kind = DE.Kind(bag, slot)
        if kind then
          local info = ask(K.GetContainerItemInfo, bag, slot)
          info = type(info) == "table" and info or {}
          local link = plain(info.hyperlink) or ask(K.GetContainerItemLink, bag, slot)
          link = type(link) == "string" and link or nil
          local id = num(plain(info.itemID))
          local _, _, _, loc = asks((C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant, id)
          local where = WORN[loc or ""]
          local wlink, wl = wornFor(where)
          kept[#kept + 1] = { text = link and link:match("%[(.-)%]") or ("item " .. tostring(id or "?")), kind = kind, id = id, link = link, bag = bag, slot = slot,
            quality = num(plain(info.quality)), icon = plain(info.iconFileID) or 134400, enchanted = link and P and P.Enchanted(link) or false,
            sets = DE.InSets(bag, slot), ilvl = level(link), where = where and where[1] or nil, worn = wl, wornLink = wlink, guid = P and P.GUID and P.GUID(bag, slot) or nil }
        end
      end
    end
    table.sort(kept, function(a, b)
      if (a.sets ~= nil) ~= (b.sets ~= nil) then return a.sets == nil end
      if (a.ilvl or 0) ~= (b.ilvl or 0) then return (a.ilvl or 0) < (b.ilvl or 0) end
      if a.bag ~= b.bag then return a.bag < b.bag end
      return a.slot < b.slot
    end)
    return kept
  end

  -- one item's page
  local pick                                                   -- { bag, slot, guid, text }
  local function picked()
    if not pick then return nil end
    for _, e in ipairs(gear()) do
      if e.bag == pick.bag and e.slot == pick.slot and e.text == pick.text and e.guid == pick.guid then return e end
    end
    pick = nil                                                 -- (it moved or went: back to the list)
  end
  local function names(e) return e.sets and table.concat(e.sets, ", ") or nil end
  local function keptBack(e) local i = P and P.db and P.db.ignore return e.guid and i and i[e.guid] ~= nil or false end
  local function status(e)
    if e.sets then return names(e), "gold" end
    if keptBack(e) then return "KEPT", "good" end
    if e.enchanted then return "ENCHANTED", "gold" end
    if e.kind == "bound" then return "BOUND", "warn" end
    return "", "ink2"
  end
  local function under(e)
    local out = {}
    if e.ilvl then out[1] = "level " .. e.ilvl end
    if e.where then out[#out + 1] = e.where end
    if e.worn then out[#out + 1] = "you wear " .. e.worn end
    return #out > 0 and table.concat(out, ", ") or (COLOUR[e.quality] or "gear")
  end
  local function row(e)
    local right, ink = status(e)
    return { pic = e.icon, text = e.text, tint = TINT[e.quality], sub = under(e), right = right, ink = ink,
      act = { word = "open", peek = true, fn = function() pick = { bag = e.bag, slot = e.slot, guid = e.guid, text = e.text } D.skip = 0 end },
      tip = (COLOUR[e.quality] or "Gear") .. ", bag " .. (e.bag + 1) .. " slot " .. e.slot .. "." .. (e.sets and " In your set " .. names(e) .. "." or "")
        .. (e.kind == "bound" and " Soulbound: you may still want it." or "") .. (e.enchanted and " Somebody enchanted it: look twice." or "") }
  end
  local function setRows()
    local out, _, all = {}, DE.Sets()
    for _, set in ipairs(all) do
      local here = {}
      for _, e in ipairs(gear()) do
        for _, n in ipairs(e.sets or {}) do if n == set then here[#here + 1] = row(e) end end
      end
      out[#out + 1] = { head = true, text = set, right = #here .. " here" }
      for _, r in ipairs(here) do out[#out + 1] = r end
    end
    return out
  end
  local function listRows(tab)
    if tab == 3 then return setRows() end
    local out = {}
    for _, e in ipairs(gear()) do if tab == 1 or not e.sets then out[#out + 1] = row(e) end end
    return out
  end
  --- Its stats against what you wear there: { name, +n, worn n }, by the game's own names.
  local function stats(link)
    local t = link and ask(C_Item and C_Item.GetItemStats, link)
    local out = {}
    for k, v in pairs(type(t) == "table" and t or {}) do
      v = num(plain(v))
      local name = type(k) == "string" and plain(rawget(_G, k)) or nil
      if v and type(name) == "string" and name ~= "" then out[name] = v end
    end
    return out
  end
  local function money(c)
    if not c then return nil end
    local g, s = math.floor(c / 10000), math.floor(c / 100) % 100
    return g > 0 and (g .. "g " .. s .. "s") or s > 0 and (s .. "s") or (c .. "c")
  end
  local function itemRows(e)
    local out = { { mark = "<", text = "All the gear", act = { word = "back", peek = true, fn = function() pick = nil D.skip = 0 end } } }
    local function add(text, right, ink, tip) if right and right ~= "" then out[#out + 1] = { mark = "-", text = text, right = tostring(right), ink = ink, tip = tip } end end
    if e.sets then
      for _, n in ipairs(e.sets) do add("In your set", n, "gold", "From the game's Equipment Manager") end
    else
      add("In your sets", "none", "ink2", "From the game's Equipment Manager")
    end
    add("Soulbound", e.kind == "bound" and "yes" or "no", e.kind == "bound" and "warn" or "good")
    if e.enchanted then add("Enchanted", "yes", "gold", "Somebody enchanted it: look twice") end
    local need, skill = P and e.ilvl and P.Need(e.ilvl), P and P.Skill()
    if need and skill then add("Enchanting needed", need .. " (you " .. skill .. ")", skill >= need and "good" or "warn") end
    add("Where", "bag " .. (e.bag + 1) .. ", slot " .. e.slot)
    local mine, its, order = stats(e.wornLink), stats(e.link), {}
    for n in pairs(its) do order[#order + 1] = n end
    for n in pairs(mine) do if not its[n] then order[#order + 1] = n end end
    table.sort(order)
    if #order > 0 then out[#out + 1] = { head = true, text = "AGAINST WHAT YOU WEAR", right = e.wornLink and e.wornLink:match("%[(.-)%]") or "nothing there" } end
    for i = 1, math.min(MOST, #order) do
      local n = order[i]
      local a, b = its[n] or 0, mine[n] or 0
      local function say(v) return v == math.floor(v) and tostring(v) or ("%.1f"):format(v) end
      out[#out + 1] = { mark = a > b and "+" or a < b and "-" or "=", text = n, right = say(a) .. " (worn " .. say(b) .. ")", ink = a > b and "good" or a < b and "warn" or "ink2" }
    end
    return out
  end

  return {
    page = {
      tour = { { text = "The gear in your bags that can be disenchanted. A gold name at the right is one of your equipment sets.",
        note = "Press an item for everything about it." }, { text = "Hold Alt over your bags: gold edge = in a set, red = soulbound, purple = free to go.", note = "SPARE is what is in no set." } },
      kicker = function() return "what can go" end,
      tabs = function() return { "ALL", "SPARE", "SETS" } end,
      boxes = function()
        local e = picked()
        if e then
          local _, _, _, _, req, _, _, _, _, _, sells = asks(e.link and ((C_Item and C_Item.GetItemInfo) or GetItemInfo), e.link)
          return { { "LEVEL", e.ilvl or "-", TINT[e.quality] }, { "YOU WEAR", e.worn or "-", e.worn and e.ilvl and (e.ilvl > e.worn and "good" or "ink2") or "dim" },
            { "NEEDS", num(req) and req > 0 and req or "-" }, { "SELLS", num(sells) and sells > 0 and money(sells) or "-", "gold" } }
        end
        local all, sets, bound, blue = gear(), 0, 0, 0
        if #all == 0 then return {} end
        for _, x in ipairs(all) do
          if x.sets then sets = sets + 1 end
          if x.kind == "bound" and not x.sets then bound = bound + 1 end
          if (x.quality or 0) >= 3 then blue = blue + 1 end
        end
        return { { "SPARE", #all - sets, "good" }, { "IN A SET", sets, sets > 0 and "gold" or "dim" }, { "BOUND", bound, bound > 0 and "warn" or "dim" },
          { "BLUE UP", blue, blue > 0 and "accent" or "dim" } }
      end,
      rows = function(tab)
        local e = picked()
        if e then return itemRows(e) end
        return listRows(tab)
      end,
      text = function(tab)
        if picked() then return nil end
        if tab == 3 then
          local _, all = DE.Sets()
          return #all == 0 and "No equipment sets yet. Make one in the game's Equipment Manager (character window): its gear is marked here and left alone." or nil
        end
        if #gear() == 0 then return "Nothing to disenchant in your bags. Green, blue and epic weapons and armor show up here." end
        if tab == 2 and #listRows(2) == 0 then return "Everything here is in one of your sets." end
      end,
      say = function()
        local e = picked()
        if e then return e.sets and "in a set: the processing app leaves it alone" or e.text end
        return #gear() > 0 and "Hold Alt over your bags: it glows there" or nil
      end,
      keys = function()
        local e, out = picked(), {}
        if e and e.guid and P and P.Ignore then
          out[1] = keptBack(e) and { word = "LET GO", tip = "Processing may take it again", fn = function() P.Ignore({ guid = e.guid, name = e.text }) end }
            or { word = "KEEP", tip = "The processing app leaves this one alone", fn = function() P.Ignore({ guid = e.guid, name = e.text }) end }
        end
        out[#out + 1] = { word = "PROCESSING", peek = true, tip = "Where it is disenchanted, one item at a time", fn = function() D.Open("BiSTools:tool-processing") end }
        return out
      end,
    },
  }
end
