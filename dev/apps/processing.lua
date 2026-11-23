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
  local function ready() local o = {} for _, r in ipairs(p.rows(1)) do if r.head then break end o[#o + 1] = r end return o end
  local function row(tab, words) for _, r in ipairs(p.rows(tab)) do if r.text:find(words, 1, true) then return r end end end
  local function key(tab, word) for _, b in ipairs(p.keys(tab)) do if b.word == word then return b end end end
  local function press(b) ok(type(b) == "table" and type(b.fn) == "function", "there is something to press", b and b.word) Dk.Press(def, b)() end
  moment()

  -- READY
  ok(#p.tabs() == 5 and p.tabs()[2] == "SETS" and p.tabs()[3] == "KEEP", "READY, SETS, KEEP, HAUL and the settings")
  local list = ready()
  ok(#list == 4 and list[1].text == "Belt" and list[1].pic == 132001 and list[1].right == "CHECK" and list[2].right == "ENCH" and row(1, "Shield").right == "BOUND" and row(1, "Cloak").right == "",
    "READY: each item, and what to look twice at", #list)
  local b = p.boxes(1)
  ok(b[1][2] == 4 and b[2][2] == 0 and b[3][2] == 1 and b[4][2] == 60, "counted: ready, in a set, later, skill")
  ok(p.rows(1)[5].head and p.rows(1)[5].text == "LATER" and p.rows(1)[6].text == "Sword", "LATER under READY: above your skill")
  local big = p.big(1)
  local last = ready()[#ready()]
  ok(last.text == "Shield" and last.right == "BOUND", "soulbound at the bottom of READY (Arn: \"if they are bound send them to the bottom\")", last.text)
  ok(big.word == "NEXT: Cloak" and Dk.IsSecure(big) and not big.fn and big.slot == 3 and big.guid == "G-C", "the next plain one, never bound, enchanted or of a mixed name; secure, so dim", big.word)
  -- A CLICK ON AN ITEM DISENCHANTS IT (Arn, 23 Nov: "when i click an item it should disenchant ... shift click if its a soulbound
  -- item"), and its tooltip is the game's own, your worn one beside it ("so i can compare it to my currently equiped item")
  do
    local cl, sh = row(1, "Cloak"), row(1, "Shield")
    ok(cl.act and Dk.IsSecure(cl.act) and cl.act.spell == P.SpellName() and cl.act.bag == 0 and cl.act.slot == 3 and cl.bagItem and cl.bagItem[1] == 0 and cl.bagItem[2] == 3,
      "an item's row: a click disenchants that bag slot; its tooltip is the item's", cl.act and cl.act.spell)
    ok(cl.act.ok() == true and P.clicked and P.clicked.e.guid == "G-C", "a plain one: cast")
    local shKeep = _G.IsShiftKeyDown
    _G.IsShiftKeyDown = function() return false end
    ok(sh.act and sh.act.ok() == false and P.said:find("SHIFT-CLICK", 1, true) and sh.tip:find("Shift-click: disenchants it", 1, true), "soulbound, a plain click: nothing, it says shift-click", P.said)
    _G.IsShiftKeyDown = function() return true end
    ok(sh.act.ok() == true, "soulbound, shift-click: cast")
    _G.IsShiftKeyDown = shKeep
    SLOT[3][2] = "G-X"
    ok(cl.act.ok() == false and P.said:find("MOVED", 1, true), "the item moved since: nothing is cast, it says so")
    SLOT[3][2] = "G-C"
    P.said = nil
    moment()
  end
  H.Paint("processing", 1)
  do                                                        -- in an equipment set of yours: never the next one, and in LATER by its name
    local was, kept = rawget(_G, "C_EquipmentSet"), NS.DE.setsKept
    _G.C_EquipmentSet = { GetEquipmentSetIDs = function() return { 0 } end, GetEquipmentSetInfo = function() return "DMg" end, GetItemIDs = function() return { [15] = 2002 } end }
    NS.DE.setsKept = nil
    moment()
    ok(not row(1, "Cloak") and p.big(1) == nil and row(2, "Cloak").right == "DMg" and row(2, "Cloak").ink == "gold" and row(2, "Cloak").tip:find("In your set DMg", 1, true), "in a set: under SETS, left alone")
    local n = P.Recount()
    _G.C_EquipmentSet, NS.DE.setsKept = was, nil
    moment()
    ok(P.Recount() == n + 1 and row(1, "Cloak"), "and not counted as ready", n)
    NS.DE.setsKept = kept
  end
  press(row(1, "Cloak").side)
  local inReady = false
  for _, r in ipairs(ready()) do if r.text == "Cloak" then inReady = true end end
  ok(db.ignore["G-C"] == "Cloak" and not inReady and p.big(1) == nil and p.say(1):find("second look", 1, true), "SKIP leaves it alone; nothing plain is left")
  H.Paint("processing", 1)

  -- LATER
  ok(row(1, "Sword").right == "SKILL 125" and row(1, "Sword").done and not row(1, "Cloak"), "LATER: above your skill; what you skipped is hidden (Arn: \"i click skip hide them\")")
  -- KEEP (Arn: "maybe put it in a hidden tab, not a set but not wanting to disenchant"): what you skipped, with its picture
  local kr = p.rows(3)
  ok(#kr == 1 and kr[1].text == "Cloak" and kr[1].pic == 132002 and kr[1].bagItem and kr[1].side.word == "BACK" and p.boxes(3)[1][2] == 1, "KEEP: the skipped Cloak, its picture, BACK", kr[1] and kr[1].text)
  H.Paint("processing", 3)
  press(kr[1].side)
  ok(next(db.ignore) == nil and row(1, "Cloak") and #p.rows(3) == 0 and p.text(3):find("Nothing kept", 1, true), "BACK: into READY again")
  press(row(1, "Cloak").side)
  press(key(3, "ALL BACK"))
  press(key(3, "SURE?"))
  ok(next(db.ignore) == nil and row(1, "Cloak"), "ALL BACK puts them all back")
  db.blocked[12] = "Requires Runed Copper Rod"
  moment()
  ok(row(1, "Cloak").right == "ROD" and row(1, "Cloak").tip:find("Runed Copper Rod", 1, true) and not ready()[3], "a rod the game asked for")
  press(key(1, "NO RODS"))
  ok(key(1, "SURE?") and next(db.blocked), "it asks first")
  press(key(1, "SURE?"))
  ok(next(db.blocked) == nil and row(1, "Cloak") and not key(1, "NO RODS"), "then they are forgotten")
  press(row(1, "Cloak").side)
  press(key(3, "ALL BACK"))
  press(key(3, "SURE?"))
  ok(next(db.ignore) == nil and row(1, "Cloak"), "ALL BACK the same way")
  P.said = "REQUIRES A ROD"
  ok(p.say(1) == "REQUIRES A ROD", "the game's own words, as on the old window's scratchpad")
  P.said = nil

  -- HAUL
  ok(p.text(4):find("Nothing yet", 1, true), "no haul yet: said")
  H.Paint("processing", 4)
  db.totals, P.haul, P.haulName = { [10940] = 12, [10938] = 40 }, { [10940] = 3 }, {}
  ok(#p.rows(4) == 2 and p.rows(4)[1].right == "x40" and p.rows(4)[1].text == "item 10938" and p.rows(4)[2].text == "Strange Dust" and p.rows(4)[2].right == "+3 / 12" and p.boxes(4)[2][2] == 52,
    "the haul: all time, and this session's")
  H.Paint("processing", 4)
  press(key(4, "HOARD"))
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
  ok(#p.rows(1) == 5 and p.say(1):find("Not an enchanter", 1, true) and p.big(1) == nil and not p.rows(1)[1].side, "not an enchanter: the gear, looking only, and said")
  H.Paint("processing", 1)

  -- SMELTING (Arn, 23 Nov: "smelt if its a ore" - "build it"): ore in your bags = a SMELT row; a click hands the game the recipe,
  -- all the bars (Shift: one); nothing begun with Mining closed = the next click opens it first
  do
    local SM = NS.Smelt
    local keepT, keepSp, keepCast = rawget(_G, "C_TradeSkillUI"), _G.C_Spell, rawget(_G, "UnitCastingInfo")
    local crafted, opened, isOpen, casting = {}, 0, false, nil
    _G.C_TradeSkillUI = { CraftRecipe = function(id, n) crafted[#crafted + 1] = { id = id, n = n } end,
      OpenTradeSkill = function(id) opened = opened + 1 isOpen = id == 186 return true end,
      GetBaseProfessionInfo = function() return { professionID = isOpen and 186 or 0 } end }
    _G.C_Spell = setmetatable({ GetSpellName = function(id) return ({ [2657] = "Smelt Copper", [14891] = "Smelt Dark Iron" })[id] end }, { __index = keepSp })
    _G.UnitCastingInfo = function() return casting end
    _G.IsPlayerSpell = function(id) return id == 2657 or id == P.SPELL end
    SLOT[7] = { 2770, "G-O", 0 } SLOT[8] = { 11370, "G-D", 0 }
    ITEMS[2770] = { 1, 7, "", 1, "Copper Ore" } ITEMS[11370] = { 1, 7, "", 1, "Dark Iron Ore" }
    local function oreInfo(bag, slot)
      local i = info(bag, slot)
      if i and (i.itemID == 2770 or i.itemID == 11370) then i.stackCount = i.itemID == 2770 and 12 or 5 end
      return i
    end
    _G.C_Container.GetContainerItemInfo = oreInfo
    _G.C_Item.GetItemNameByID = function(id) return ITEMS[id] and ITEMS[id][5] end
    KNOWN = true
    moment()
    local cu, di, head
    for _, r in ipairs(p.rows(1)) do
      if r.head and r.text == "SMELT" then head = r end
      if r.text == "Copper Ore" then cu = r elseif r.text == "Dark Iron Ore" then di = r end
    end
    ok(head and p.rows(1)[1].head and p.rows(1)[1].text == "SMELT" and cu and cu.sub == "12 ore = 12 bars" and cu.right == "SMELT" and cu.act and type(cu.act.fn) == "function",
      "ore in your bags: SMELT on top, a row for it, a click to smelt", cu and cu.sub)
    ok(di and di.right == "NOT KNOWN" and not di.act and di.done, "an ore you cannot smelt yet: it only looks")
    local shKeep = _G.IsShiftKeyDown
    _G.IsShiftKeyDown = function() return false end
    Dk.Press(def, cu.act)()
    ok(crafted[1] and crafted[1].id == 2657 and crafted[1].n == 12 and opened == 0, "a click: the game is handed Smelt Copper, all 12", crafted[1] and crafted[1].n)
    W.runAfters(SM.WAIT + 0.1)
    ok(SM.needOpen and SM.last.why:find("Mining closed", 1, true) and P.said:find("CLICK AGAIN", 1, true), "nothing began with Mining closed: it says click again", P.said)
    _G.IsShiftKeyDown = function() return true end
    for _, r in ipairs(p.rows(1)) do if r.text == "Copper Ore" then cu = r end end
    Dk.Press(def, cu.act)()
    ok(opened == 1 and crafted[2].n == 1, "the next click opens Mining first; Shift-click: one bar")
    SM.events.scripts.OnEvent(SM.events, "UNIT_SPELLCAST_START", "player", "guid", 2657)
    W.runAfters(SM.WAIT + 0.1)
    ok(SM.last.began and P.said:find("SMELTING 1 BAR", 1, true), "it began: said", P.said)
    _G.IsShiftKeyDown = shKeep
    Dk.Press(def, cu.act)()
    SM.events.scripts.OnEvent(SM.events, "UI_ERROR_MESSAGE", 50, "Requires Forge")
    W.runAfters(SM.WAIT + 0.1)
    ok(SM.last.why == "Requires Forge" and P.said == "REQUIRES FORGE", "away from a forge: the game's own words", P.said)
    W.combat = true
    local n0 = #crafted
    Dk.Press(def, cu.act)()
    ok(#crafted == n0 and P.said == "NOT IN A FIGHT", "in a fight: nothing")
    W.combat = false
    local said = {}
    NS.Print = function(f, ...) said[#said + 1] = select("#", ...) > 0 and f:format(...) or f end
    R:Get("processing"):OnSlash(db, "smelt")
    ok(said[1] and said[1]:find("Smelt Copper", 1, true) == nil and said[1]:find("recipe 2657", 1, true), "/bist processing smelt: what the last click did", said[1])
    NS.Print = function() end
    SLOT[7], SLOT[8] = nil, nil
    _G.C_TradeSkillUI, _G.C_Spell, _G.UnitCastingInfo = keepT, keepSp, keepCast
    _G.C_Container.GetContainerItemInfo = info
    moment()
  end

  _G.C_Container, _G.C_Item, _G.ItemLocation, _G.IsPlayerSpell = keep.cont, keep.item, keep.loc, keep.known
  _G.GetProfessions, _G.GetProfessionInfo, _G.IsResting = keep.profs, keep.info, keep.rest
  db.ignore, db.blocked, db.totals, db.showIgnored = keep.ignore, keep.blocked, keep.totals, keep.show
  P.haul, P.haulName, P.said, P.count, P.db, NS.Print, def.tab, W.combat = keep.haul, keep.name, keep.said, keep.count, keep.pdb, keep.print, keep.tab, keep.combat
  moment()
end
