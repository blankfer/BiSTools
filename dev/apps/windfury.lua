-- dev/apps/windfury.lua - the windfury app: the lamp's state, the shamans, the log, the card.
return function(H)
  local ok, NS, R, W, Dk = H.ok, H.NS, H.R, H.W, H.Dk
  local WF, C = NS.WF, NS.Combo
  local def = H.Page("windfury")
  local p = def.page
  local db = R:DBFor(R:Get("windfury"))
  local keep = { cls = _G.UnitClass, ex = _G.UnitExists, name = _G.UnitName, ua = _G.C_UnitAuras, we = _G.GetWeaponEnchantInfo, is = _G.issecretvalue, rest = _G.IsResting,
    dead = _G.UnitIsDeadOrGhost, log = db.log, key = db.key, wfdb = WF.db, knows = C.Knows, can = WF.CanAsk, test = WF.Test, ref = WF.refused, combat = W.combat, tab = def.tab }
  WF.db = db
  db.log, db.key = nil, nil
  WF.refused = nil
  local classes, names, weapon, buff, resting = { player = "WARRIOR" }, { party2 = "Thrall Song" }, nil, false, false
  _G.UnitClass = function(u) local c = classes[u] return c and c:lower(), c end
  _G.UnitExists = function(u) return classes[u] ~= nil end
  _G.UnitName = function(u) return names[u] end
  _G.IsResting = function() return resting end
  _G.UnitIsDeadOrGhost = function() return false end
  _G.GetWeaponEnchantInfo = function() if weapon then return true, 1500000, 0, weapon end return false end
  _G.C_UnitAuras = { GetAuraDataBySpellName = function(_, n) if W.combat then return nil end return buff and n == "Windfury Totem" and { spellId = 10609 } or nil end }
  WF.CanAsk = function() return true end
  C.Knows = function() return false end
  local function row(tab, words) for _, r in ipairs(p.rows(tab)) do if r.text:find(words, 1, true) then return r end end end

  -- alone
  ok(#p.tabs() == 3, "LAMP, LOG and the settings")
  ok(p.boxes(1)[1][2] == "NO" and p.boxes(1)[2][2] == 0 and row(1, "No shaman in your party") and row(1, "ASK aims at").right == "nobody", "a warrior alone: no Windfury, nobody to ask")
  ok(def.card.prio() == nil and def.card.prio(true) == 2, "and no card about it, unless you put it on your screen")
  ok(#p.keys(1) == 0 and p.text(2):find("No ask yet", 1, true) and #p.boxes(2) == 0, "no ASK, an empty log says so")
  H.Paint("windfury", 1) H.Paint("windfury", 2)

  -- a shaman in the party
  classes.party2 = "SHAMAN"
  ok(def.card.prio() == 5 and def.card.lines()[3] == "No Windfury" and def.card.lines().hot and def.card.lines().list[3][2] == "Thrall Song", "a shaman near and no Windfury: the card")
  ok(row(1, "Thrall Song").right == "HEARS" and row(1, "ASK aims at").right == "Thrall Song", "who it is, and that they hear it")
  ok(p.keys(1)[1].word == "ASK" and Dk.IsSecure(p.keys(1)[1]) and not p.keys(1)[1].fn, "ASK is secure: drawn, dim")
  WF.CanAsk = function() return false end
  ok(row(1, "Thrall Song").right == "NO BIS", "no BiS Tools heard from them: said")
  WF.CanAsk = function() return true end
  resting = true
  ok(def.card.prio() == nil, "in town: no card")
  resting = false
  buff = true
  ok(def.card.prio() == nil and p.boxes(1)[1][2] == "ON" and row(1, "Totem on you").right == "YES" and def.card.lines()[4] == "TOTEM", "the totem on you: all is well, no card")
  buff = false
  weapon = 284
  ok(def.card.prio() == nil and row(1, "On your weapon").right == "YES" and def.card.lines()[4] == "WEAPON", "your own imbue too")
  weapon = nil
  -- in a fight the game does not say
  W.combat = true
  ok(p.boxes(1)[1][2] == "?" and row(1, "Totem on you").right == "?" and def.card.prio() == nil and def.card.lines()[3]:find("in a fight", 1, true), "in a fight: the lamp, not a guess")
  W.combat = keep.combat
  -- secrets
  local meta = { __index = function() error("secret") end, __eq = function() error("secret") end, __concat = function() error("secret") end }
  local S = setmetatable({}, meta)
  _G.issecretvalue = function(v) return type(v) == "table" and getmetatable(v) == meta end
  local plainName = _G.UnitName
  _G.UnitName = function() return S end
  _G.GetWeaponEnchantInfo = function() return S, S, S, S end
  _G.IsResting = function() return S end
  ok(pcall(p.rows, 1) and row(1, "party2") and pcall(def.card.lines) and pcall(def.card.prio), "hidden answers: no error, the unit instead of the name")
  H.Paint("windfury", 1)
  _G.UnitName, _G.issecretvalue = plainName, keep.is
  _G.GetWeaponEnchantInfo = function() if weapon then return true, 1500000, 0, weapon end return false end
  _G.IsResting = function() return resting end

  -- the shaman's side
  classes = { player = "SHAMAN" }
  C.Knows = function() return true end
  ok(row(1, "You, a shaman").right == "READY" and p.keys(1)[1].spell == "Windfury Totem" and p.keys(1)[2].spell == "Windfury Weapon" and def.card.prio() == 5, "a shaman: his totem and his imbue, both secure")
  weapon = 5
  ok(def.card.prio() == nil, "alone with another imbue on: his own choice, no card")
  classes.party1 = "WARRIOR"
  ok(def.card.prio() == nil, "a warrior beside him is not a second shaman")
  weapon = nil

  -- the log
  db.log = { { k = "sent", n = 4, span = 1.6, fight = true, to = "Thrall Song", at = W.now }, { k = "heard", who = "Grom", unit = "party1", n = 3, span = 1.2, lit = true, at = W.now },
    { k = "heard", who = "Jaina", unit = "party3", n = 2, span = 1, notBis = true } }
  ok(#p.rows(2) == 3 and p.rows(2)[1].right == "NO BIS" and row(2, "Grom").right == "LIT" and row(2, "you asked Thrall Song").right == "4 x", "the log, the newest first")
  ok(p.boxes(2)[1][2] == 1 and p.boxes(2)[2][2] == 2 and p.boxes(2)[3][2] == 1 and p.text(2) == nil, "sent, heard, lit")
  H.Paint("windfury", 2)

  -- the lamp
  local tested
  WF.Test = function() tested = true return true end
  Dk.Press(def, p.big(1))()
  ok(tested, "SHOW THE LAMP is the tool's own test")
  WF.refused = "the game refused"
  ok(row(1, "The lamp").right == "CANNOT" and p.say(1):find("the game refused", 1, true), "no lamp: it says why")
  R:SetEnabled("windfury", false)
  ok(def.card.prio() == nil and def.card.prio(true) == nil, "switched off: no card")
  R:SetEnabled("windfury", true)

  db.log, db.key, WF.db, WF.refused, WF.CanAsk, WF.Test, C.Knows, def.tab = keep.log, keep.key, keep.wfdb, keep.ref, keep.can, keep.test, keep.knows, keep.tab
  _G.UnitClass, _G.UnitExists, _G.UnitName, _G.C_UnitAuras, _G.GetWeaponEnchantInfo = keep.cls, keep.ex, keep.name, keep.ua, keep.we
  _G.IsResting, _G.UnitIsDeadOrGhost, _G.issecretvalue, W.combat = keep.rest, keep.dead, keep.is, keep.combat
end
