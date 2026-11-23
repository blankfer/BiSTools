-- dev/apps/social.lua - the friendly emotes in the phone (Tools/Apps/Social.lua)
return function(H)
  local NS, R, ok, W, Dk = H.NS, H.R, H.ok, H.W, H.Dk
  local S, db, d = NS.Social, R:DBFor(R:Get("social")), H.Page("social")
  local p = d.page
  local function press(b) Dk.Press(d, b)() end
  Dk.Store().toured = Dk.Store().toured or {}
  Dk.Store().toured[d.id] = true
  local keep = { thanks = db.thanks, group = db.groupToo, emotes = db.emotes, history = S.history, thanked = S.thanked, last = S.lastThanked, next = S.next,
    DoEmote = _G.DoEmote, isP = _G.UnitIsPlayer, isU = _G.UnitIsUnit, name = _G.UnitName, inP = _G.UnitInParty, is = _G.issecretvalue, combat = W.combat }
  db.thanks, db.groupToo, db.emotes, S.history, S.thanked, S.lastThanked, S.next = false, nil, nil, {}, {}, nil, nil
  W.combat = false

  local t = p.tabs()
  ok(t[1] == "RECENT" and t[2] == "EMOTES" and t[3] == "RULES" and t[4] == "SETTINGS", "social: RECENT, EMOTES, RULES, SETTINGS")
  ok(#p.rows(1) == 0 and p.text(1):find("Not thanking") and p.big(1).word == "START THANKING", "off: it says so, and how")
  ok(p.boxes(1)[2][2] == "OFF", "off in the box")
  press(p.big(1))
  ok(db.thanks == true and p.big(1).word == "STOP THANKING" and p.boxes(1)[2][2] == "READY" and p.text(1):find("Nobody has buffed"), "one press: on, ready")
  -- a stranger buffs you: the tool's own road
  local done = {}
  _G.DoEmote = function(e, who) done[#done + 1] = e .. " " .. who end
  _G.UnitIsPlayer = function() return true end
  _G.UnitIsUnit = function(a, b) return a == b end
  _G.UnitName = function() return "Nice Stranger" end
  _G.UnitInParty = function() return false end
  local buff = { addedAuras = { { isHelpful = true, sourceUnit = "nameplate1", name = "Arcane Intellect" } } }
  S.OnBuffs(db, buff)
  local rows = p.rows(1)
  ok(#done == 1 and #rows == 1 and rows[1].text == "Nice Stranger" and rows[1].right:find("^/%a+$") and rows[1].ink == "good", "thanked: who, and the emote", rows[1] and rows[1].right)
  ok(rows[1].tip:find("Arcane Intellect"), "the buff is under the mouse")
  ok(p.boxes(1)[1][2] == 1 and tostring(p.boxes(1)[2][2]):find("^%d:%d%d$") and p.say(1):find("Nice Stranger"), "one thanked, the wait counts down", p.boxes(1)[2][2])
  W.now = W.now + 10
  _G.UnitName = function() return "Second Stranger" end
  S.OnBuffs(db, buff)
  ok(#done == 1 and p.rows(1)[1].right == "WAITING" and p.rows(1)[1].tip:find("cooldown"), "the next one too soon: WAITING, the reason under the mouse", p.rows(1)[1].right)
  for why, word in pairs({ ["a groupmate - switched off"] = "GROUP", ["in a fight - never then"] = "IN A FIGHT", ["the game did not say who"] = "NO NAME",
    ["thanked them less than ten minutes ago"] = "TWICE", ["not a player (a pet or a creature)"] = "NO PLAYER", ["/hug - the game complained: x"] = "REFUSED", ["/hug - thanked"] = "/hug", ["new"] = "LEFT OUT" }) do
    S.history = { { why = why, at = W.now } }
    ok(p.rows(1)[1].right == word and p.rows(1)[1].text == "Someone", "'" .. why .. "' in a word", p.rows(1)[1].right)
  end
  -- the emotes
  ok(#p.rows(2) == #S.EMOTES and p.rows(2)[1].right == "ON" and p.rows(2)[1].text == "/thank", "every emote, all on")
  press(p.rows(2)[1].act)
  ok(#db.emotes == #S.EMOTES - 1 and p.rows(2)[1].right == "OFF", "a click leaves one out")
  for i = 2, #S.EMOTES do press(p.rows(2)[i].act) end
  ok(#db.emotes == 1 and p.rows(2)[#S.EMOTES].right == "ON", "the last one stays")
  for i = 1, #S.EMOTES - 1 do press(p.rows(2)[i].act) end
  ok(db.emotes == nil, "all on again: nothing kept")
  -- the rules
  rows = p.rows(3)
  ok(rows[2].right == "NO" and rows[4].right == "2-5 min" and rows[5].right == "10 min", "the rules are the tool's own numbers", rows[4].right)
  press(rows[2].act)
  ok(db.groupToo == true and p.rows(3)[2].right == "YES", "the group too: a click")
  press(p.big(1))
  ok(db.thanks == false, "STOP: off")
  -- a secret caster
  local secret = setmetatable({}, { __eq = function() error("compared a secret") end, __concat = function() error("joined a secret") end })
  _G.issecretvalue = function(v) return rawequal(v, secret) end
  db.thanks = true
  S.OnBuffs(db, { addedAuras = { { isHelpful = true, sourceUnit = secret, name = secret } } })
  _G.issecretvalue = keep.is
  for i = 1, 4 do H.Paint("social", i) end
  ok(not d.errors, "no error handed to the deck", d.errors)
  db.thanks, db.groupToo, db.emotes, S.history, S.thanked, S.lastThanked, S.next = keep.thanks, keep.group, keep.emotes, keep.history, keep.thanked, keep.last, keep.next
  _G.DoEmote, _G.UnitIsPlayer, _G.UnitIsUnit, _G.UnitName, _G.UnitInParty = keep.DoEmote, keep.isP, keep.isU, keep.name, keep.inP
  W.combat = keep.combat
end
