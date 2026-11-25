-- dev/apps/disenchant.lua - the disenchant parts, in the Processing app since 22 Nov (Arn: "two things that do the same thing"):
-- the gear in the bags, your equipment sets, one item's page. Not an enchanter here: READY only looks.
return function(H)
  local ok, NS, R, W, Dk = H.ok, H.NS, H.R, H.W, H.Dk
  local DE, P = NS.DE, NS.Proc
  ok(H.Page("disenchant").hidden, "the Disenchant app has no icon of its own any more")
  local def = H.Page("processing")
  local p = def.page
  local keep = { cont = _G.C_Container, item = _G.C_Item, is = _G.issecretvalue, tab = def.tab, page = Dk.page, sets = rawget(_G, "C_EquipmentSet"), inv = rawget(_G, "GetInventoryItemLink"),
    loc = rawget(_G, "ItemLocation"), agi = rawget(_G, "ITEM_MOD_AGILITY_SHORT"), sta = rawget(_G, "ITEM_MOD_STAMINA_SHORT"), pdb = P.db, kept = DE.setsKept }
  -- id = { quality, class, slot, name, enchant, bound, item level }
  local ITEMS = { [1001] = { 2, 2, "INVTYPE_WEAPON", "Green Sword", 0, false, 20 }, [1002] = { 3, 4, "INVTYPE_CHEST", "Blue Chest", 0, true, 45 },
    [1003] = { 4, 4, "INVTYPE_FINGER", "Epic Ring", 723, false, 50 }, [1004] = { 0, 4, "INVTYPE_FEET", "Grey Boots", 0, false, 9 }, [1005] = { 2, 7, "", "Herb", 0, false, 1 },
    [2001] = { 3, 4, "INVTYPE_CHEST", "Worn Chest", 0, true, 40 }, [2002] = { 3, 4, "INVTYPE_FINGER", "Good Ring", 0, true, 55 }, [2003] = { 3, 4, "INVTYPE_FINGER", "Poor Ring", 0, true, 30 } }
  local SLOTS = { [0] = { 1001, 1002, 1003, 1004, 1005 }, [1] = { 1001 } }
  local WEAR = { [5] = 2001, [11] = 2002, [12] = 2003 }
  local function link(id) return ("|Hitem:%d:%d::::|h[%s]|h|r"):format(id, ITEMS[id][5], ITEMS[id][4]) end
  local function info(bag, slot)
    local id = SLOTS[bag] and SLOTS[bag][slot]
    local it = id and ITEMS[id]
    return it and { itemID = id, quality = it[1], isBound = it[6], iconFileID = 130000 + id, hyperlink = link(id) } or nil
  end
  local function idOf(l) return type(l) == "number" and l or tonumber(l:match("item:(%d+)")) end
  _G.C_Container = { GetContainerNumSlots = function(b) return b < 2 and 8 or 0 end, GetContainerItemInfo = info,
    GetContainerItemLink = function(b, s) local i = info(b, s) return i and i.hyperlink end, GetContainerItemID = function(b, s) return SLOTS[b] and SLOTS[b][s] end }
  _G.C_Item = setmetatable({ GetItemInfoInstant = function(id) local it = ITEMS[id] if it then return id, "", "", it[3], 1, it[2], 0 end end,
    GetDetailedItemLevelInfo = function(l) return ITEMS[idOf(l)][7] end,
    GetItemInfo = function(l) local it = ITEMS[idOf(l)] return it[4], l, it[1], it[7], 41, "", "", 1, it[3], 1, 12345 end,
    GetItemStats = function(l) return ({ [1002] = { ITEM_MOD_AGILITY_SHORT = 12, ITEM_MOD_NOT_A_NAME = 3 }, [2001] = { ITEM_MOD_AGILITY_SHORT = 9, ITEM_MOD_STAMINA_SHORT = 7 } })[idOf(l)] end,
    GetItemGUID = function(loc) return "G-" .. loc.bag .. "-" .. loc.slot end, DoesItemExist = function() return true end }, { __index = keep.item })
  _G.ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
  _G.ITEM_MOD_AGILITY_SHORT, _G.ITEM_MOD_STAMINA_SHORT = "Agility", "Stamina"
  _G.GetInventoryItemLink = function(unit, slot) return unit == "player" and WEAR[slot] and link(WEAR[slot]) or nil end
  P.db = { ignore = {} }
  local asked = 0
  local SET = { [0] = { "DMg", { [1] = 1002, [2] = -1, [3] = 0, [4] = 1 } }, [3] = { "Heal", { [11] = 1002, [12] = 777 } } }
  _G.C_EquipmentSet = { GetEquipmentSetIDs = function() asked = asked + 1 return { 0, 3 } end, GetEquipmentSetInfo = function(i) return SET[i][1], 1, i end,
    GetItemIDs = function(i) return SET[i][2] end, GetItemLocations = function() error("the client would crash here") end }
  DE.setsKept = nil
  local function moment(n) W.now = W.now + (n or 1) end
  local function find(tab, words) for _, r in ipairs(p.rows(tab)) do if r.text == words then return r end end end
  moment()

  ok(#p.tabs() == 5 and p.tabs()[1] == "READY" and p.tabs()[2] == "SETS" and p.tabs()[3] == "KEEP" and p.tabs()[4] == "HAUL", "READY, SETS, KEEP, HAUL and the settings")
  local all = p.rows(1)
  ok(#all == 3 and all[1].text == "Green Sword" and all[1].pic == 131001 and all[1].right == "" and all[1].tint == "uncommon" and all[3].right == "ENCHANTED" and all[3].tint == "epic",
    "READY: the gear in no set, with its pictures, in its quality, the lowest first; no grey, no herb", #all)
  ok(all[3].sub == "level 50, ring, you wear 30" and all[1].sub == "level 20, one-hand" and all[2].tip:find("bag 2 slot 1", 1, true),
    "its level, where it goes, what you wear there (the weaker of two)", all[3].sub)
  local s = p.rows(2)
  ok(#s == 4 and s[1].head and s[1].text == "DMg" and s[1].right == "1 here" and s[2].text == "Blue Chest" and s[3].text == "Heal" and s[4].text == "Blue Chest", "SETS: each with what of it is in the bags", #s)
  ok(s[2].right == "DMg, Heal" and s[2].ink == "gold" and s[2].tip:find("In your set DMg, Heal", 1, true) and s[2].tip:find("Soulbound", 1, true) and s[2].sub == "level 45, chest, you wear 40",
    "in a set: its names, its level against what you wear", s[2].right)
  local b = p.boxes(1)
  ok(b[1][2] == 3 and b[2][2] == 1, "counted: spare, in a set")
  asked = 0
  for tab = 1, 3 do H.Paint("processing", tab) end
  ok(asked <= 1, "the sets are not read at every paint", asked)
  -- bound and in no set: still said
  local was = SET[0][2]
  SET[0][2], SET[3][2] = {}, {}
  ok(not find(1, "Blue Chest"), "kept for a moment")
  moment(3)
  ok(find(1, "Blue Chest").right == "BOUND" and find(1, "Blue Chest").ink == "warn" and p.boxes(1)[1][2] == 4, "taken out of the set: in READY, soulbound, and read again")
  SET[0][2], SET[3][2] = was, { [11] = 1002 }
  moment(3)
  -- one item
  Dk.Press(def, find(2, "Blue Chest").act)()
  local r = p.rows(1)
  ok(r[1].text == "All the gear" and r[2].right == "DMg" and r[3].right == "Heal", "a press opens the item: its sets")
  local function line(words) for _, x in ipairs(p.rows(1)) do if x.text == words then return x end end end
  ok(line("Soulbound").right == "yes" and line("Where").right == "bag 1, slot 2" and line("Agility").right == "12 (worn 9)" and line("Agility").ink == "good"
    and line("Stamina").right == "0 (worn 7)" and line("Stamina").ink == "warn" and not line("ITEM_MOD_NOT_A_NAME") and line("AGAINST WHAT YOU WEAR").right == "Worn Chest", "and against what you wear")
  local bx = p.boxes(1)
  ok(bx[1][2] == 45 and bx[2][2] == 40 and bx[3][2] == 41 and bx[4][2] == "1g 23s", "its numbers", bx[4][2])
  H.Paint("processing", 1)
  ok(p.keys(1)[1].word == "KEEP", "KEEP it")
  Dk.Press(def, p.keys(1)[1])()
  ok(P.db.ignore["G-0-2"] == "Blue Chest" and p.keys(1)[1].word == "LET GO", "the processing app's own list")
  Dk.Press(def, p.keys(1)[1])()
  ok(P.db.ignore["G-0-2"] == nil, "and let go")
  Dk.Press(def, p.rows(1)[1].act)()
  ok(#p.rows(1) == 3 and p.rows(1)[1].text == "Green Sword", "back")
  Dk.Press(def, find(1, "Epic Ring").act)()
  ok(p.rows(1)[2].text == "In your sets" and p.rows(1)[2].right == "none" and line("Enchanted"), "in no set: said")
  SLOTS[0][3] = nil
  moment()
  ok(p.rows(1)[1].text == "Green Sword" and #p.rows(1) == 2, "gone from the bags: back to the list")
  SLOTS[0][3] = 1003
  moment()
  -- the processing side: never by a plain click
  ok(DE.InSets(0, 2)[1] == "DMg" and DE.InSets(0, 1) == nil, "the tool says it for any bag slot")
  Dk.Hide()
  -- no Equipment Manager, none of your own, or it refuses
  _G.C_EquipmentSet = nil
  moment(3)
  ok(#p.rows(2) == 0 and p.text(2):find("No equipment sets yet", 1, true) and #p.rows(1) == 4 and p.text(1) == nil, "no sets: it says where to make one")
  H.Paint("processing", 2)
  _G.C_EquipmentSet = { GetEquipmentSetIDs = function() error("no") end }
  moment(3)
  ok(#p.rows(1) == 4, "it refuses: the list is there")
  -- secrets, and a client that refuses
  local meta = { __index = function() error("secret") end, __eq = function() error("secret") end, __lt = function() error("secret") end, __concat = function() error("secret") end }
  local S = setmetatable({}, meta)
  _G.issecretvalue = function(v) return type(v) == "table" and getmetatable(v) == meta end
  _G.C_EquipmentSet = { GetEquipmentSetIDs = function() return { 0 } end, GetEquipmentSetInfo = function() return S end, GetItemIDs = function() return { S, S } end }
  _G.C_Container.GetContainerItemInfo = function(bag, slot)
    local i = info(bag, slot)
    if i then i.hyperlink, i.isBound, i.iconFileID = S, S, S end
    return i
  end
  _G.C_Container.GetContainerItemLink = function() return S end
  moment(3)
  ok(pcall(p.rows, 1) and p.rows(1)[1].text == "item 1001" and p.rows(1)[1].pic == 134400, "hidden names and pictures: the item's number, no error")
  H.Paint("processing", 1)
  Dk.Press(def, p.rows(1)[1].act)()
  ok(pcall(p.rows, 1) and pcall(p.boxes, 1), "and its page")
  H.Paint("processing", 1)
  Dk.Press(def, p.rows(1)[1].act)()
  _G.C_Container.GetContainerItemInfo = function() error("no") end
  moment()
  ok(#p.rows(1) == 0 and #p.boxes(1) == 0 and p.text(1):find("Nothing in your bags", 1, true), "nothing: it says what would come")
  H.Paint("processing", 1)
  _G.C_Container, _G.C_Item, _G.issecretvalue, def.tab = keep.cont, keep.item, keep.is, keep.tab
  _G.C_EquipmentSet, _G.GetInventoryItemLink, _G.ItemLocation = keep.sets, keep.inv, keep.loc
  _G.ITEM_MOD_AGILITY_SHORT, _G.ITEM_MOD_STAMINA_SHORT, P.db, DE.setsKept = keep.agi, keep.sta, keep.pdb, nil
  Dk.page = keep.page
  moment()
  ok(R:Enabled("disenchant"), "the tool itself untouched")
end
