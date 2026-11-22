-- battlegrounds in the phone (Tools/Apps/BG.lua)
return function(H)
  local NS, ok, R, Dk = H.NS, H.ok, H.R, H.Dk
  local B = NS.BG
  local def = H.Page("bg")
  local p = def.page
  local db = R:DBFor(R:Get("bg"))
  local keep = { known = db.known, inBG = B.inBG, read = B.read, healers = B.healers, killer = B.killer, mvps = B.mvps, marks = B.marks, gun = _G.GetUnitName,
    mark = B.Mark, is = _G.issecretvalue, un = _G.UnitName }
  db.known, B.inBG, B.marks = {}, false, {}
  ok(#p.rows(1) == 0 and p.text(1):find("not in a battleground", 1, true) and p.big(1) == nil and #p.keys(1) == 0 and def.card.prio() == nil and def.badge() == nil,
    "bg: outside it says so, and offers nothing")
  ok(p.text(2):find("Nobody yet", 1, true) and #p.keys(2) == 0, "nobody known: nothing to clear")
  H.Paint("bg", 1)
  H.Paint("bg", 2)
  -- in one, nothing read yet: the tool's own reason
  B.inBG, B.read, B.killer, B.healers, B.mvps = true, { enemies = 0, heals = {}, note = "the match has only just started" }, nil, {}, {}
  ok(p.text(1) == "The match has only just started." and p.big(1).word == "MARK NOW", "nothing read: why", p.text(1))
  -- read: three healers, the killer, ours
  B.read = { enemies = 10, heals = { { name = "Swig Xd", heal = 900 }, { name = "Grape Vine" } }, byOrder = true }
  B.killer, B.healers, B.mvps = { name = "Bad Man", kb = 12 }, { ["Swig Xd"] = 1, ["Grape Vine"] = 2 }, { ["My Friend"] = "healer" }
  local r = p.rows(1)
  ok(#r == 4 and r[1].text == "Swig Xd" and r[1].right == "900 healed" and r[2].right == "healer 2" and r[3].right == "12 kills" and r[3].ink == "warn" and r[4].right == "our healer",
    "who is marked and why", r[1].right .. " " .. r[2].right .. " " .. r[3].right)
  ok(def.badge() == 4 and def.card.prio() == 5 and def.card.lines()[3] == "Bad Man" and #def.card.lines().list == 3, "the badge and the live card")
  ok(p.boxes(1)[1][2] == 10 and p.boxes(1)[2][2] == 2 and p.say(1):find("order", 1, true), "the boxes; hidden numbers said")
  ok(Dk.IsSecure(p.keys(1)[1]) and p.keys(1)[1].macro:find("/target Swig Xd", 1, true) and not p.keys(1)[1].fn, "TARGET is the game's macro, never a fn")
  -- a remembered one on a plate, its name hidden
  local secret = setmetatable({}, { __concat = function() error("secret") end, __index = function() error("secret") end })
  _G.issecretvalue = function(v) return rawequal(v, secret) end
  _G.GetUnitName = function() return secret end
  _G.UnitName = function() return secret end
  B.marks = { nameplate3 = { kind = "healer", remembered = true } }
  r = p.rows(1)
  ok(#r == 5 and r[5].text == "someone" and r[5].right == "healer, known" and p.boxes(1)[3][2] == 1, "a remembered one, the name hidden: someone")
  H.Paint("bg", 1)
  _G.issecretvalue, _G.GetUnitName, _G.UnitName, B.marks = keep.is, keep.gun, keep.un, {}
  local pressed = 0
  B.Mark = function() pressed = pressed + 1 end
  Dk.Press(def, p.big(1))()
  Dk.Press(def, def.card.buttons()[1])()
  ok(pressed == 2, "MARK NOW is the tool's own mark")
  B.Mark = keep.mark
  -- KNOWN
  db.known = { ["Swig Xd"] = { healer = 3, killer = 0, last = 100 }, ["Bad Man"] = { healer = 0, killer = 1, last = 200 } }
  r = p.rows(2)
  ok(#r == 2 and r[1].text == "Bad Man  1 kill" and r[2].text == "Swig Xd  3 heals" and p.boxes(2)[2][2] == 1 and p.boxes(2)[3][2] == 1, "everybody remembered, last seen first", r[1].text .. " | " .. r[2].text)
  p.find(2).set("swig")
  ok(#p.rows(2) == 1 and p.find(1) == nil and p.find(2).get() == "swig", "found by name")
  p.find(2).set("zzz")
  ok(#p.rows(2) == 0 and p.text(2) == "Nobody by that name.", "nobody by that name")
  p.find(2).set("")
  H.Paint("bg", 2)
  p.rows(2)[2].side.fn()
  ok(db.known["Swig Xd"] and p.rows(2)[2].side.word == "SURE?" and p.rows(2)[1].side.word == "FORGET", "FORGET asks first, that row only")
  p.rows(2)[2].side.fn()
  ok(not db.known["Swig Xd"] and db.known["Bad Man"], "twice: that one forgotten")
  p.keys(2)[1].fn()
  ok(next(db.known) and p.keys(2)[1].word == "SURE?", "CLEAR ALL asks first")
  H.W.now = H.W.now + 6
  p.keys(2)[1].fn()
  ok(next(db.known), "too late: it asks again")
  p.keys(2)[1].fn()
  ok(next(db.known) == nil, "twice: everybody forgotten")
  db.known, B.inBG, B.read, B.healers, B.killer, B.mvps, B.marks = keep.known, keep.inBG, keep.read, keep.healers, keep.killer, keep.mvps, keep.marks
end
