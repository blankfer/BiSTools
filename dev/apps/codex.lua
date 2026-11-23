-- the book of creatures in the phone (Tools/Apps/Codex.lua)
return function(H)
  local NS, ok, W = H.NS, H.ok, H.W
  local C = NS.Codex
  local X = C.UI
  local def = H.Page("codex")
  local p = def.page
  local db = C.DB()
  local keep = { ti = rawget(_G, "C_TooltipInfo"), sp = rawget(_G, "C_Spell"), item = rawget(_G, "C_Item"), zone = _G.GetRealZoneText, is = _G.issecretvalue,
    names = db.names, met = db.met, seen = db.seen, casts = db.casts, pending = C.pending, gave = C.gaveUp, count = C.metCount, db = C.DB, asked = C.spellAsked, sel = X.sel, view = X.view }
  local names = { [11520] = "Taragaman the Hungerer", [11517] = "Oggleflint", [11518] = "Jergosh the Invoker", [999001] = "Tarren Mill Bear" }
  local fetched, asks = {}, 0
  _G.C_TooltipInfo = { GetHyperlink = function(link)                    -- nil on the first ask, as the client
    asks = asks + 1
    local npc = tonumber(link:match("(%d+)%-0$"))
    if not fetched[npc] then fetched[npc] = true return nil end
    return names[npc] and { lines = { { leftText = names[npc] } } } or nil
  end }
  local words
  _G.C_Spell = { GetSpellName = function(id) return id == 11970 and "Fire Nova" or id == 18072 and "Uppercut" or nil end, GetSpellTexture = function() return 135824 end,
    GetSpellDescription = function() return words or "" end, RequestLoadSpellData = function() end }
  _G.C_Item = { GetItemNameByID = function(id) return id == 14149 and "Subterranean Cape" or nil end, GetItemQualityByID = function() return 3 end,
    GetItemIconByID = function() return 132260 end, RequestLoadItemDataByID = function() end }
  _G.GetRealZoneText = function() return "Ragefire Chasm" end
  db.names, db.met, db.seen, db.casts, C.pending, C.gaveUp, C.metCount, C.spellAsked = {}, {}, {}, {}, {}, {}, nil, {}
  C.DeckFresh()
  -- not ready: no error
  C.DB = function() return nil end
  ok(#p.rows(1) == 0 and p.text(1):find("being opened", 1, true) and #p.boxes(1) == 0 and p.hero(1) == nil, "codex: before its save is there, it says so")
  H.Paint("codex", 1)
  C.DB = keep.db
  -- the places: where you stand first
  local r = p.rows(1)
  ok(#r == #X.Order(), "every place of the book", #r)
  ok(r[1].text == "Ragefire Chasm" and r[1].right == "HERE", "the one you stand in on top", r[1].text)
  ok(p.boxes(1)[1][2] == 240 and p.boxes(1)[2][2] == 0, "240 in the book, none met", p.boxes(1)[1][2])
  ok(p.rows(1) == r, "built once and kept")
  r[1].act.fn()
  r = p.rows(1)
  ok(p.title() == "Ragefire Chasm" and #r == 6 and r[1].text == "Back" and r[2].text == "creature 11517" and r[2].right == "BOSS", "a place: Back, its creatures (the names on their way)", r[2].text)
  ok(p.hero(1).art == "model" and p.hero(1).display == 2007 and p.hero(1).creature == nil and p.boxes(1)[2][2] == 5, "its last boss on top, by model id")
  ok(p.say(1):find("sending names", 1, true), "and it says names are coming")
  W.runAfters(1.1)
  ok(p.rows(1)[2].text == "Oggleflint", "a second later: the names", p.rows(1)[2].text)
  H.Paint("codex", 1)
  -- one creature
  db.met[11520], db.seen[11520] = { n = 2, level = 16, rank = "elite", type = "Demon" }, { [14149] = 3, [99] = 1 }
  W.runAfters(20)
  p.rows(1)[4].act.fn()
  r = p.rows(1)
  ok(p.title() == "Taragaman the Hungerer" and r[1].text == "Back" and r[2].text == "ABILITIES" and r[3].text == "Fire Nova" and r[3].pic == 135824, "a creature: Back, its abilities with their pictures", tostring(p.title()))
  ok(r[3].tip:find("fetching", 1, true) and p.find(1) == nil, "the spell's words are on their way; no search line here")
  words = "Burns."
  W.runAfters(1.1)
  r = p.rows(1)
  ok(r[3].tip == "Burns.", "and come", r[3].tip)
  ok(r[5].text == "SEEN TO DROP" and r[6].text == "Subterranean Cape" and r[6].right == "x3" and r[6].tint == "rare" and r[6].pic == 132260 and r[7].text == "item 99" and r[7].right == "once",
    "its drops, most often first", r[6].text)
  local hero, b = p.hero(1), p.boxes(1)
  ok(hero.display == 7970 and hero.big == "Taragaman the Hungerer" and hero.small == "Boss, Demon" and b[1][2] == 16 and b[2][2] == 2 and b[3][2] == 2 and b[4][2] == 2, "the model, the facts", hero.small)
  ok(p.rows(1) == r, "kept, not made again at every look")
  local before = asks
  for _ = 1, 20 do p.rows(1) p.boxes(1) p.hero(1) end
  ok(asks == before, "twenty looks ask the game nothing")
  H.Paint("codex", 1)
  -- the old windows, at this creature
  p.keys(1)[1].fn()
  ok(X.IsOpen() and X.sel == 11520, "POP OUT: the book, at his page")
  X.Toggle(false)
  p.keys(1)[2].fn()
  ok(C.Drive.IsOpen() and X.sel == 11520, "FULL SCREEN: there too")
  C.Drive.Close()
  if X.IsOpen() then X.Toggle(false) end
  p.rows(1)[1].act.fn()
  ok(p.title() == "Ragefire Chasm", "Back: the place")
  p.rows(1)[1].act.fn()
  ok(p.title() == "Codex" and p.rows(1)[1].right == "HERE", "Back: the places")
  -- each tab has its own place; ALL by name, the nameless last
  local a = p.rows(2)
  ok(#a == 240 and a[1].text == "Jergosh the Invoker" and a[2].text == "Oggleflint" and a[4].text:find("^creature"), "ALL: by name, those without one last", a[1].text)
  ok(a == p.rows(2), "the long list is built once")
  for _ = 1, 4 do W.runAfters(1.1) end
  ok(next(C.pending) == nil, "three asks, then it stops")
  H.Paint("codex", 2)
  local m = p.rows(3)
  ok(#m == 1 and m[1].text == "Taragaman the Hungerer" and m[1].right == "x2", "MET: yours, with how often")
  -- a search, on any tab; Enter opens the first
  p.find(1).set("ogg")
  ok(#p.rows(1) == 1 and p.rows(1)[1].text == "Oggleflint", "a name typed")
  p.find(1).enter("ogg")
  def.tab = 1
  ok(p.title() == "Oggleflint" and p.rows(1)[4].text == "SEEN TO DROP" and p.rows(1)[3].done, "Enter opens it; nothing learned yet is said", p.title())
  p.rows(1)[1].act.fn()
  p.find(1).set("zzzz")
  ok(#p.rows(1) == 0 and p.text(1):find("No creature", 1, true), "nobody by that name")
  p.find(1).set("ogg")
  ok(#p.rows(3) == 0, "MET keeps to the ones you met")
  p.find(1).set("")
  db.met = {}
  W.runAfters(20)
  ok(#p.rows(3) == 0 and p.text(3):find("Nobody met yet", 1, true), "nobody met: how to")
  H.Paint("codex", 3)
  -- met in the wild, its zone and an item's name hidden
  local secret = setmetatable({}, { __concat = function() error("secret") end, __index = function() error("secret") end })
  _G.issecretvalue = function(v) return rawequal(v, secret) end
  _G.GetRealZoneText = function() return secret end
  _G.C_Item.GetItemNameByID = function() return secret end
  _G.C_Item.GetItemIconByID = function() return secret end
  db.met, db.names[999001], db.seen[999001] = { [999001] = { n = 1 } }, "Tarren Mill Bear", { [5] = 1 }
  C.DeckFresh()
  ok(p.rows(1)[1].right ~= "HERE", "a hidden zone: no HERE, no error")
  p.rows(3)[1].act.fn()
  ok(p.hero(3).creature == 999001 and p.hero(3).display == nil and p.rows(3)[5].text == "item 5", "no model id: by creature; a hidden name is its id", tostring(p.rows(3)[5].text))
  H.Paint("codex", 3)
  p.rows(3)[1].act.fn()
  _G.C_TooltipInfo, _G.C_Spell, _G.C_Item, _G.GetRealZoneText, _G.issecretvalue = keep.ti, keep.sp, keep.item, keep.zone, keep.is
  db.names, db.met, db.seen, db.casts, C.pending, C.gaveUp, C.metCount, C.spellAsked = keep.names, keep.met, keep.seen, keep.casts, keep.pending, keep.gave, keep.count, keep.asked
  C.byName, X.sel, X.view = nil, keep.sel, keep.view
  C.DeckFresh()
end
