-- dev/apps/xp.lua - the xp app: what your XP gets now, an hour's worth, the food in the bags, the card.
return function(H)
  local ok, NS, R, W, Dk = H.ok, H.NS, H.R, H.W, H.Dk
  local X = NS.XP
  local def = H.Page("xp")
  local p = def.page
  local tool = R:Get("xp")
  local db = R:DBFor(tool)
  local keep = { ua = _G.C_UnitAuras, item = _G.C_Item, cont = _G.C_Container, spell = _G.C_Spell, level = _G.UnitLevel, exh = _G.GetXPExhaustion, max = _G.UnitXPMax,
    xp = _G.UnitXP, is = _G.issecretvalue, food = db.food, xdb = X.db, pick = X.pick, bag = X.showBag, eat = X.showFood, tent = X.showTent, cache = X.xpItem, combat = W.combat,
    print = NS.Print, tab = def.tab, dirty = X.dirty }
  X.db, X.xpItem, db.food, X.pick = db, {}, nil, nil
  W.combat = false
  local AURA, FED, LEVEL, XP, MAX, REST = nil, nil, 20, 1000, 10000, 300
  local BAGS = { [X.BAG_ITEM] = 1, [5477] = 5, [2680] = 12, [4599] = 3 }
  local SLOTS = { [0] = { X.BAG_ITEM, 5477, 2680, 4599, 5477 } }
  _G.UnitLevel = function(u) return u == "player" and LEVEL or 1 end
  _G.UnitXP, _G.UnitXPMax, _G.GetXPExhaustion = function() return XP end, function() return MAX end, function() return REST end
  _G.C_UnitAuras = { GetPlayerAuraBySpellID = function(id) return id == X.RESTED and AURA or nil end,
    GetAuraDataBySpellName = function(_, n) return n == "Well Fed" and FED or nil end }
  _G.C_Item = { GetItemCount = function(id) return BAGS[id] or 0 end, GetItemIconByID = function(id) return 100000 + id end,
    GetItemNameByID = function(id) return ({ [5477] = "Strider Stew", [2680] = "Spiced Wolf Meat" })[id] end,
    GetItemSpell = function(id) return "Food", ({ [5477] = 1, [2680] = 2, [4599] = 3 })[id] end,
    GetItemInfoInstant = function(id) if id == X.BAG_ITEM then return id, "", "", "", 1, 15, 0 end return id, "", "", "", 1, 0, 5 end }
  _G.C_Container = { GetContainerNumSlots = function(b) return b == 0 and 6 or 0 end, GetContainerItemID = function(b, s) return SLOTS[b] and SLOTS[b][s] end,
    GetItemCooldown = function() return 0, 0, 1 end }
  _G.C_Spell = setmetatable({ GetSpellDescription = function(id) return id == 3 and "Restores health." or "experience gained from kills is increased by 5%." end }, { __index = keep.spell })
  NS.Print = function() end
  local function row(tab, words) for _, r in ipairs(p.rows(tab)) do if r.text:find(words, 1, true) then return r end end end
  local function press(b) ok(type(b) == "table" and type(b.fn) == "function", "there is something to press", b and b.word) Dk.Press(def, b)() end
  local function moment(s) W.now = W.now + (s or 1) end
  moment()

  -- NOW
  ok(#p.tabs() == 3, "NOW, BAGS and the settings")
  ok(p.boxes(1)[1][2] == "3%" and p.boxes(1)[2][2] == "0" and p.boxes(1)[3][2] == "NO" and p.boxes(1)[4][2] == "-", "nothing on you: 3% rested, no stacks, not fed, no hour yet", p.boxes(1)[1][2])
  ok(row(1, "Well-Rested").right == "GONE" and row(1, "Well-Rested").ink == "warn" and row(1, "To level 21").right == "9,000 XP", "gone, and how far the next level is")
  AURA = { expirationTime = W.now + 1800, applications = 2, duration = 3600, spellId = X.RESTED }
  FED = { expirationTime = W.now + 840, applications = 0, duration = 900, spellId = 1249519 }
  ok(row(1, "Well-Rested").right == "2 of 3, 30 min" and row(1, "Well Fed").right == "14 min" and row(1, "Well Fed").ink == "good" and p.boxes(1)[3][2] == "14m", "on you: how many and how long")
  H.Paint("xp", 1)

  -- an hour's worth: from START AGAIN, over a level too
  press(p.keys(1)[1])
  moment(600)
  XP = 2000
  ok(p.boxes(1)[4][2] == "6,000" and row(1, "Since the start").right == "1,000 XP" and row(1, "At this pace").right == "1 h 20 min", "1,000 XP in ten minutes: 6,000 an hour", p.boxes(1)[4][2])
  LEVEL, XP, MAX = 21, 500, 12000
  ok(row(1, "Since the start").right == "9,500 XP" and row(1, "To level 22").right == "11,500 XP", "over a level: what was left of it, and the new one's")
  ok(p.boxes(1)[4][2] == "57.0k", "an hour's worth, short", p.boxes(1)[4][2])

  -- what the tool would have you click
  X.pick, X.showFood, X.showBag, X.showTent = 5477, true, false, false
  FED = nil
  ok(def.card.prio() == 6 and def.card.lines()[3] == "Time to eat" and def.card.lines()[4] == "GONE" and def.card.lines().hot, "the food is due: the card comes")
  local b = def.card.buttons()
  ok(b[1].word == "EAT" and b[1].item == "item:5477" and Dk.IsSecure(b[1]) and b[2].word == "OPEN", "EAT is secure, OPEN opens the app")
  ok(p.big(1).word == "EAT: Strider Stew" and p.big(1).item == "item:5477" and p.say(1):find("tools box", 1, true), "and the app says where its button is")
  H.Paint("xp", 1)
  X.showFood, X.showBag, X.showTent = false, true, true
  ok(def.card.lines()[3] == "Time to rest" and def.card.lines()[4] == "2/3" and p.big(1).word == "CAMP TENT" and def.card.buttons()[1].word == "TENT" and def.card.buttons()[2].word == "BAG",
    "the bag: the tent first, as the tool has it")
  X.showBag, X.showTent = false, false
  ok(def.card.prio() == nil and def.card.prio(true) == 2 and p.big(1) == nil and def.card.buttons()[1].word == "OPEN", "nothing due: no card, no big button")

  -- BAGS
  moment()
  local rows = p.rows(2)
  ok(#rows == 3 and rows[1].pic == 100000 + X.BAG_ITEM and not rows[1].act and rows[2].text == "Spiced Wolf Meat" and rows[2].right == "x12" and rows[3].right == "NEXT x5",
    "the bag, then the XP food, most first; vendor food is not in it", #rows)
  ok(p.boxes(2)[1][2] == 17 and p.boxes(2)[2][2] == 2 and p.boxes(2)[3][2] == "YES" and p.boxes(2)[4][2] == "NO", "counted")
  H.Paint("xp", 2)
  press(rows[2].act)
  ok(db.food == 2680 and p.rows(2)[2].right:find("YOURS", 1, true) and not p.rows(2)[2].act, "a click makes it yours")
  ok(p.keys(2)[1].word == "ANY FOOD", "and a key takes it back")
  press(p.keys(2)[1])
  ok(db.food == nil and #p.keys(2) == 0, "any food again")
  SLOTS, BAGS = { [0] = {} }, {}
  moment()
  ok(#p.rows(2) == 0 and p.text(2):find("Nothing for XP", 1, true), "empty bags say what would come")
  H.Paint("xp", 2)

  -- secrets
  local meta = { __index = function() error("secret") end, __eq = function() error("secret") end, __lt = function() error("secret") end, __concat = function() error("secret") end }
  local S = setmetatable({}, meta)
  _G.issecretvalue = function(v) return type(v) == "table" and getmetatable(v) == meta end
  _G.UnitXP, _G.GetXPExhaustion = function() return S end, function() return S end
  _G.C_UnitAuras = { GetPlayerAuraBySpellID = function() return S end, GetAuraDataBySpellName = function() return S end }
  _G.C_Container.GetContainerItemID = function() return S end
  moment()
  ok(p.boxes(1)[1][2] == "?" and p.boxes(1)[2][2] == "?" and row(1, "Well-Rested").right == "?" and #p.rows(2) == 0, "hidden answers: ?, never an error")
  H.Paint("xp", 1)
  _G.issecretvalue = keep.is

  -- the top level
  LEVEL = 60
  ok(#p.rows(1) == 0 and #p.boxes(1) == 0 and p.text(1):find("top level", 1, true) and def.card.prio(true) == nil, "at the top level it says so, and no card")
  H.Paint("xp", 1)

  _G.C_UnitAuras, _G.C_Item, _G.C_Container, _G.C_Spell, _G.UnitLevel = keep.ua, keep.item, keep.cont, keep.spell, keep.level
  _G.GetXPExhaustion, _G.UnitXPMax, _G.UnitXP, _G.issecretvalue, NS.Print = keep.exh, keep.max, keep.xp, keep.is, keep.print
  db.food, X.db, X.pick, X.showBag, X.showFood, X.showTent = keep.food, keep.xdb, keep.pick, keep.bag, keep.eat, keep.tent
  X.xpItem, X.dirty, W.combat, def.tab = keep.cache, keep.dirty, keep.combat, keep.tab
end
