-- dev/apps/disenchant.lua - the disenchant app: the gear in the bags, soulbound ones marked.
return function(H)
  local ok, R, W, Dk = H.ok, H.R, H.W, H.Dk
  local def = H.Page("disenchant")
  local p = def.page
  local keep = { cont = _G.C_Container, item = _G.C_Item, is = _G.issecretvalue, tab = def.tab, page = Dk.page }
  -- id = { quality, class, slot, name, enchant, bound }
  local ITEMS = { [1001] = { 2, 2, "INVTYPE_WEAPON", "Green Sword", 0, false }, [1002] = { 3, 4, "INVTYPE_CHEST", "Blue Chest", 0, true },
    [1003] = { 4, 4, "INVTYPE_FINGER", "Epic Ring", 723, false }, [1004] = { 0, 4, "INVTYPE_FEET", "Grey Boots", 0, false }, [1005] = { 2, 7, "", "Herb", 0, false } }
  local SLOTS = { [0] = { 1001, 1002, 1003, 1004, 1005 }, [1] = { 1001 } }
  local function info(bag, slot)
    local id = SLOTS[bag] and SLOTS[bag][slot]
    local it = id and ITEMS[id]
    return it and { itemID = id, quality = it[1], isBound = it[6], iconFileID = 130000 + id, hyperlink = ("|Hitem:%d:%d::::|h[%s]|h|r"):format(id, it[5], it[4]) } or nil
  end
  _G.C_Container = { GetContainerNumSlots = function(b) return b < 2 and 8 or 0 end, GetContainerItemInfo = info,
    GetContainerItemLink = function(b, s) local i = info(b, s) return i and i.hyperlink end, GetContainerItemID = function(b, s) return SLOTS[b] and SLOTS[b][s] end }
  _G.C_Item = setmetatable({ GetItemInfoInstant = function(id) local it = ITEMS[id] if it then return id, "", "", it[3], 1, it[2], 0 end end }, { __index = keep.item })
  W.now = W.now + 1

  ok(#p.tabs() == 4, "ALL, FREE, BOUND and the settings")
  local all = p.rows(1)
  ok(#all == 4 and all[1].text == "Green Sword" and all[1].pic == 131001 and all[1].right == "" and all[2].right == "BOUND" and all[2].ink == "warn" and all[3].right == "ENCHANTED",
    "the gear with its pictures; soulbound and enchanted marked; no grey, no herb", #all)
  ok(all[2].tip:find("Soulbound", 1, true) and all[4].tip:find("bag 2 slot 1", 1, true), "and where it is")
  ok(#p.rows(2) == 3 and #p.rows(3) == 1 and p.rows(3)[1].text == "Blue Chest", "FREE and BOUND")
  local b = p.boxes(1)
  ok(b[1][2] == 4 and b[2][2] == 3 and b[3][2] == 1 and b[4][2] == 2, "counted")
  for tab = 1, 3 do H.Paint("disenchant", tab) end
  -- the processing app is one key away
  Dk.Press(def, p.keys(1)[1])()
  ok(Dk.page == "BiSTools:tool-processing", "PROCESSING opens that app")
  Dk.page = "home"
  Dk.Hide()
  -- secrets, and a client that refuses
  local meta = { __index = function() error("secret") end, __eq = function() error("secret") end, __lt = function() error("secret") end, __concat = function() error("secret") end }
  local S = setmetatable({}, meta)
  _G.issecretvalue = function(v) return type(v) == "table" and getmetatable(v) == meta end
  _G.C_Container.GetContainerItemInfo = function(bag, slot)
    local i = info(bag, slot)
    if i then i.hyperlink, i.isBound, i.iconFileID = S, S, S end
    return i
  end
  _G.C_Container.GetContainerItemLink = function() return S end
  W.now = W.now + 1
  ok(pcall(p.rows, 1) and p.rows(1)[1].text == "item 1001" and p.rows(1)[1].pic == 134400, "hidden names and pictures: the item's number, no error")
  H.Paint("disenchant", 1)
  _G.C_Container.GetContainerItemInfo = function() error("no") end
  W.now = W.now + 1
  ok(#p.rows(1) == 0 and #p.boxes(1) == 0 and p.text(1):find("Nothing to disenchant", 1, true), "nothing: it says what would come")
  H.Paint("disenchant", 1)
  _G.C_Container, _G.C_Item, _G.issecretvalue, def.tab = keep.cont, keep.item, keep.is, keep.tab
  Dk.page = keep.page
  W.now = W.now + 1
  ok(R:Enabled("disenchant"), "the tool itself untouched")
end
