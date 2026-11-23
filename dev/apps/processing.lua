-- dev/apps/processing.lua - the processing app: ready, later, the haul, the card.
return function(H)
  local ok, NS, R, W, Dk = H.ok, H.NS, H.R, H.W, H.Dk
  local P = NS.Proc
  local def = H.Page("processing")
  local p = def.page
  local db = R:DBFor(R:Get("processing"))
  local keep = { cont = _G.C_Container, item = _G.C_Item, loc = _G.ItemLocation, known = _G.IsPlayerSpell, profs = _G.GetProfessions, info = _G.GetProfessionInfo, rest = _G.IsResting,
    is = _G.issecretvalue, ignore = db.ignore, blocked = db.blocked, totals = db.totals, show = db.showIgnored, haul = P.haul, name = P.haulName, said = P.said, count = P.count,
    pdb = P.db, print = NS.Print, tab = def.tab, combat = W.combat }
  P.db = db
  db.ignore, db.blocked, db.totals, db.showIgnored = {}, {}, {}, nil
  P.haul, P.haulName, P.said = {}, {}, nil
  W.combat = false
  NS.Print = function() end
  local ITEMS = { [2001] = { 2, 4, "INVTYPE_WAIST", 18, "Belt" }, [2002] = { 2, 4, "INVTYPE_CLOAK", 12, "Cloak" }, [2003] = { 3, 4, "INVTYPE_SHIELD", 24, "Shield" },
    [2004] = { 2, 2, "INVTYPE_WEAPON", 44, "Sword" } }
  local SLOT = { { 2001, "G-A", 0 }, { 2001, "G-B", 723 }, { 2002, "G-C", 0 }, { 2003, "G-S", 0, true }, { 2004, "G-W", 0 } }
  local function info(bag, slot)
    local s = bag == 0 and SLOT[slot]
    return s and { itemID = s[1], quality = ITEMS[s[1]][1], isBound = s[4] or false, iconFileID = 130000 + s[1],
      hyperlink = ("|Hitem:%d:%d::::|h[%s]|h|r"):format(s[1], s[3], ITEMS[s[1]][5]) } or nil
  end
  _G.C_Container = { GetContainerNumSlots = function(b) return b == 0 and 8 or 0 end, GetContainerItemInfo = info,
    GetContainerItemLink = function(b, s) local i = info(b, s) return i and i.hyperlink end, GetContainerItemID = function(b, s) return b == 0 and SLOT[s] and SLOT[s][1] end }
  _G.C_Item = { GetItemInfoInstant = function(id) local it = ITEMS[id] if it then return id, "", "", it[3], 1, it[2], 0 end end,
    GetDetailedItemLevelInfo = function(l) return ITEMS[tonumber(l:match("item:(%d+)"))][4] end, GetItemGUID = function(loc) return SLOT[loc.slot] and SLOT[loc.slot][2] end,
    DoesItemExist = function(loc) return SLOT[loc.slot] ~= nil end, GetItemIconByID = function(id) return 100000 + id end,
    GetItemNameByID = function(id) return id == 10940 and "Strange Dust" or nil end }
  _G.ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
  local KNOWN, resting = true, true
  _G.IsPlayerSpell = function(id) return KNOWN and id == P.SPELL end
  _G.GetProfessions = function() return 1 end
  _G.GetProfessionInfo = function() return "Enchanting", 1, 60, 75, 1, 0, P.LINE end
  _G.IsResting = function() return resting end
  local function moment() W.now = W.now + 1 end
  local function row(tab, words) for _, r in ipairs(p.rows(tab)) do if r.text:find(words, 1, true) then return r end end end
  local function key(tab, word) for _, b in ipairs(p.keys(tab)) do if b.word == word then return b end end end
  local function press(b) ok(type(b) == "table" and type(b.fn) == "function", "there is something to press", b and b.word) Dk.Press(def, b)() end
  moment()

  -- READY
  ok(#p.tabs() == 4, "READY, LATER, HAUL and the settings")
  local list = p.rows(1)
  ok(#list == 4 and list[1].text == "Belt" and list[1].pic == 132001 and list[1].right == "CHECK" and list[2].right == "ENCH" and row(1, "Shield").right == "BOUND" and row(1, "Cloak").right == "",
    "READY: each item, and what to look twice at", #list)
  local b = p.boxes(1)
  ok(b[1][2] == 4 and b[2][2] == 1 and b[3][2] == 0 and b[4][2] == 60, "counted")
  local big = p.big(1)
  ok(big.word == "NEXT: Cloak" and Dk.IsSecure(big) and not big.fn and big.slot == 3 and big.guid == "G-C", "the next plain one, never bound, enchanted or of a mixed name; secure, so dim", big.word)
  H.Paint("processing", 1)
  do                                                        -- in an equipment set of yours: never the next one, and in LATER by its name
    local was, kept = rawget(_G, "C_EquipmentSet"), NS.DE.setsKept
    _G.C_EquipmentSet = { GetEquipmentSetIDs = function() return { 0 } end, GetEquipmentSetInfo = function() return "DMg" end, GetItemIDs = function() return { [15] = 2002 } end }
    NS.DE.setsKept = nil
    moment()
    ok(not row(1, "Cloak") and p.big(1) == nil and row(2, "Cloak").right == "DMg" and row(2, "Cloak").ink == "gold" and row(2, "Cloak").tip:find("In your set DMg", 1, true), "in a set: left alone")
    local n = P.Recount()
    _G.C_EquipmentSet, NS.DE.setsKept = was, nil
    moment()
    ok(P.Recount() == n + 1 and row(1, "Cloak"), "and not counted as ready", n)
    NS.DE.setsKept = kept
  end
  press(row(1, "Cloak").side)
  ok(db.ignore["G-C"] == "Cloak" and not row(1, "Cloak") and p.big(1) == nil and p.say(1):find("second look", 1, true), "SKIP leaves it alone; nothing plain is left")
  H.Paint("processing", 1)

  -- LATER
  ok(row(2, "Sword").right == "SKILL 125" and row(2, "Sword").done and row(2, "Cloak").side.word == "BACK", "LATER: above your skill, and what you skipped")
  H.Paint("processing", 2)
  press(row(2, "Cloak").side)
  ok(next(db.ignore) == nil and row(1, "Cloak"), "BACK puts it back")
  db.blocked[12] = "Requires Runed Copper Rod"
  moment()
  ok(row(2, "Cloak").right == "ROD" and row(2, "Cloak").tip:find("Runed Copper Rod", 1, true) and not row(1, "Cloak"), "a rod the game asked for")
  press(key(2, "NO RODS"))
  ok(key(2, "SURE?") and next(db.blocked), "it asks first")
  press(key(2, "SURE?"))
  ok(next(db.blocked) == nil and row(1, "Cloak") and not key(2, "NO RODS"), "then they are forgotten")
  press(row(1, "Cloak").side)
  press(key(2, "ALL BACK"))
  press(key(2, "SURE?"))
  ok(next(db.ignore) == nil and row(1, "Cloak"), "ALL BACK the same way")
  P.said = "REQUIRES A ROD"
  ok(p.say(1) == "REQUIRES A ROD", "the game's own words, as on the old window's scratchpad")
  P.said = nil

  -- HAUL
  ok(p.text(3):find("Nothing yet", 1, true), "no haul yet: said")
  H.Paint("processing", 3)
  db.totals, P.haul, P.haulName = { [10940] = 12, [10938] = 40 }, { [10940] = 3 }, {}
  ok(#p.rows(3) == 2 and p.rows(3)[1].right == "x40" and p.rows(3)[1].text == "item 10938" and p.rows(3)[2].text == "Strange Dust" and p.rows(3)[2].right == "+3 / 12" and p.boxes(3)[2][2] == 52,
    "the haul: all time, and this session's")
  H.Paint("processing", 3)
  press(key(3, "HOARD"))
  ok(P.hoard and P.hoard:IsShown(), "HOARD opens the heap")
  P.ToggleHoard(false)
  press(key(1, "POP OUT"))
  ok(P.IsOpen(), "POP OUT opens the one with the buttons")
  P.Toggle(false)

  -- the card and the badge: the tool's own rule, in town only
  P.Recount()
  ok(P.count == 4 and def.badge() == 4 and def.card.prio() == 3 and def.card.lines()[3] == "4 to disenchant" and def.card.lines().list[1][2] == "Cloak", "in town with work: a quiet card")
  resting = false
  ok(def.card.prio() == nil and def.card.prio(true) == 2, "out questing: no card")
  resting = true
  -- secrets
  local meta = { __index = function() error("secret") end, __eq = function() error("secret") end, __lt = function() error("secret") end, __concat = function() error("secret") end }
  local S = setmetatable({}, meta)
  _G.issecretvalue = function(v) return type(v) == "table" and getmetatable(v) == meta end
  _G.C_Container.GetContainerItemInfo = function(bag, slot) local i = info(bag, slot) if i then i.hyperlink, i.iconFileID, i.quality = S, S, S end return i end
  moment()
  ok(pcall(p.rows, 1) and #p.rows(1) == 0 and p.text(1):find("Nothing in your bags", 1, true), "hidden answers: nothing, no error")
  H.Paint("processing", 1)
  _G.issecretvalue = keep.is
  _G.C_Container.GetContainerItemInfo = info
  KNOWN = false
  moment()
  ok(#p.rows(1) == 0 and #p.boxes(1) == 0 and p.text(1):find("does not know", 1, true) and p.big(1) == nil, "not an enchanter: said")
  H.Paint("processing", 1)

  _G.C_Container, _G.C_Item, _G.ItemLocation, _G.IsPlayerSpell = keep.cont, keep.item, keep.loc, keep.known
  _G.GetProfessions, _G.GetProfessionInfo, _G.IsResting = keep.profs, keep.info, keep.rest
  db.ignore, db.blocked, db.totals, db.showIgnored = keep.ignore, keep.blocked, keep.totals, keep.show
  P.haul, P.haulName, P.said, P.count, P.db, NS.Print, def.tab, W.combat = keep.haul, keep.name, keep.said, keep.count, keep.pdb, keep.print, keep.tab, keep.combat
  moment()
end
