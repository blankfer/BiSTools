-- the death recap in the phone (Tools/Apps/Recap.lua)
return function(H)
  local NS, ok, Dk = H.NS, H.ok, H.Dk
  local RC, DP = NS.Recap, NS.DeckPages
  local def = H.Page("recap")
  local p = def.page
  local db = RC.DB()
  local keep = { dr = _G.C_DeathRecap, dead = _G.UnitIsDeadOrGhost, info = _G.GetPlayerInfoByGUID, last = RC.last, wait = RC.waitFight,
    popup = db.popup, rivals = db.rivals, is = _G.issecretvalue, date = rawget(_G, "date"), deaths = {} }
  _G.date = os.date
  for i, d in ipairs(DP.Deaths) do keep.deaths[i] = d end
  for i = #DP.Deaths, 1, -1 do DP.Deaths[i] = nil end
  db.popup, db.rivals, RC.last = false, {}, nil
  local MOB, PLAYER = "Creature-0-4621-389-178375-11321-0003CD6", "Player-4619-00ABCDEF"
  local events
  _G.C_DeathRecap = { HasRecapEvents = function() return events ~= nil end, GetRecapMaxHealth = function() return 1192 end, GetRecapEvents = function() return events end }
  local isDead = false
  _G.UnitIsDeadOrGhost = function() return isDead end
  _G.GetPlayerInfoByGUID = function() return "Hunter", "HUNTER" end
  local function hit(amount, name, guid, t, extra)
    local r = { event = "SWING_DAMAGE", amount = amount, critical = false, currentHP = amount + 100, timestamp = 1000 + t, sourceName = name, sourceGUID = guid, overkill = -1, school = 1 }
    for k, v in pairs(extra or {}) do r[k] = v end
    return r
  end
  -- nothing yet
  ok(#p.rows(1) == 0 and #p.rows(2) == 0 and p.text(1):find("Nothing has killed you", 1, true) and #p.boxes(1) == 0 and p.hero(1) == nil, "recap: no death, and it says so")
  ok(def.card.prio() == nil, "and no card")
  H.Paint("recap", 1)
  H.Paint("recap", 2)
  -- a death by a mob, a player in it
  events = { hit(27, "Molten Elemental Smitecrust", MOB, 9, { overkill = 14 }), hit(44, "Molten Elemental Flashs", MOB, 7, { critical = true }),
    hit(60, "Kumlust Surname", PLAYER, 6, { school = 8, spellName = "Arcane Shot", event = "SPELL_DAMAGE" }) }
  isDead = true
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_DEAD")
  ok(#DP.Deaths == 1 and #p.rows(1) == 1 and p.rows(1)[1].text == "Molten Elemental", "dying writes a row", p.rows(1)[1] and p.rows(1)[1].text)
  ok(p.rows(1)[1].right:find("^%d%d:%d%d$") and p.boxes(1)[2][2] == p.rows(1)[1].right, "with when", p.rows(1)[1].right)
  ok(def.card.prio() == 6, "the card comes by itself while you are dead")
  local l = def.card.lines()
  ok(l[3] == "Molten Elemental" and l[4] == "131" and #l.list == 2 and l.list[2][1] == "Kumlust Surname", "who, and how much", tostring(l[3]) .. " " .. tostring(l[4]))
  ok(#def.card.buttons() == 1, "a mob killed you: no RIVAL on the card")
  Dk.Press(def, def.card.buttons()[1])()
  ok(p.tabs()[1] == "HITS" and Dk.page == def.id, "its button opens the death")
  local rows = p.rows(1)
  ok(#rows == 4 and rows[1].text == "Back" and rows[2].right == "27 +14" and rows[2].ink == "warn" and rows[3].text == "melee crit - Molten Elemental Flashs", "Back first, then the hits, newest first", rows[3].text)
  ok(rows[4].text == "Arcane Shot - Kumlust Surname" and rows[2].tip:find("You had 127 health", 1, true), "what and who; the rest on hover", rows[2].tip)
  local hero = p.hero(1)
  ok(hero and hero.art == "model" and hero.creature == 11321 and hero.big == "Molten Elemental" and hero.small:find("melee 27 +14", 1, true), "the killer's model on top")
  ok(p.boxes(1)[1][2] == 131 and p.boxes(1)[2][2] == "3.0" and p.say(1):find("131 damage in 3.0 seconds", 1, true), "the boxes and the total line", p.say(1))
  H.Paint("recap", 1)
  rows[1].act.fn()
  ok(p.tabs()[1] == "DEATHS" and #p.rows(1) == 1, "Back: the list")
  -- WHO: attackers by damage, what kind, and the rival key
  local w = p.rows(2)
  ok(#w == 4 and w[1].text == "Molten Elemental" and w[1].right == "71 (54%)" and w[2].text == "Kumlust Surname  60 (46%)" and w[3].text == "physical" and w[4].text == "magic - mostly nature",
    "WHO: by damage, then the kinds", tostring(w[1].right) .. " | " .. w[2].text .. " | " .. tostring(w[4] and w[4].text))
  ok(w[2].side.word == "RIVAL" and not w[1].side, "a player has the rival key, a mob has none")
  w[2].side.fn()
  ok(RC.Rivals(db)["Kumlust Surname"] and p.rows(2)[2].side.word == "DROP", "pressed: a rival")
  p.rows(2)[2].side.fn()
  ok(RC.Rivals(db)["Kumlust Surname"] and p.rows(2)[2].side.word == "SURE?", "DROP asks first")
  H.W.now = H.W.now + 6
  ok(p.rows(2)[2].side.word == "DROP", "five seconds later it has forgotten")
  p.rows(2)[2].side.fn()
  p.rows(2)[2].side.fn()
  ok(not RC.Rivals(db)["Kumlust Surname"], "twice: dropped")
  H.Paint("recap", 2)
  -- standing again; a second death is a second row, and a summary asked for outside a death is none
  isDead = false
  ok(def.card.prio() == nil, "alive: the card goes")
  events = { hit(80, "Kumlust Surname", PLAYER, 20) }
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_DEAD")
  RC.waitFight = nil
  RC.Summary(RC.Hits(events), 1192)
  ok(#p.rows(1) == 2 and p.rows(1)[1].text == "Kumlust Surname" and p.boxes(1)[1][2] == 2, "the second death on top, counted once")
  do
    local R = NS.Registry
    local was = R:Enabled("rivals")
    R:SetEnabled("rivals", true)
    local b2 = def.card.buttons()[2]
    ok(b2 and b2.word == "RIVAL", "a player killed you: RIVAL on the card (Arn, 22 Nov)")
    b2.fn()
    ok(RC.Rivals(db)["Kumlust Surname"] and def.card.buttons()[2].word == "DROP", "pressed: a rival")
    RC.Rivals(db)["Kumlust Surname"] = nil
    R:SetEnabled("rivals", was)
  end
  p.rows(1)[1].act.fn()
  ok(p.hero(1) == nil, "a player has no model by id: no picture, never a wrong one")
  p.rows(1)[1].act.fn()
  for _ = 1, 14 do RC.frame.scripts.OnEvent(RC.frame, "PLAYER_DEAD") end
  ok(#DP.Deaths == 10, "ten are kept", #DP.Deaths)
  -- the fields hidden: no name, no amount, no error
  local meta = { __concat = function() error("secret") end, __lt = function() error("secret") end, __index = function() error("secret") end }
  local secret = setmetatable({}, meta)
  _G.issecretvalue = function(v) return rawequal(v, secret) end
  events = { { event = "SWING_DAMAGE", amount = secret, sourceName = secret, sourceGUID = secret, currentHP = secret, timestamp = secret, school = secret } }
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_DEAD")
  isDead = true
  ok(p.rows(1)[1].text == "someone" and def.card.lines()[3] == "someone", "a hidden name: someone")
  p.rows(1)[1].act.fn()
  ok(p.rows(1)[2].right == "?" and p.boxes(1)[1][2] == "?" and #p.rows(2) >= 1 and not p.rows(2)[1].side, "hidden numbers are ?")
  H.Paint("recap", 1)
  H.Paint("recap", 2)
  p.rows(1)[1].act.fn()
  _G.issecretvalue = keep.is
  p.keys(1)[1].fn()
  ok(Dk.page == "BiSTools:tool-rivals", "RIVALS opens that app")
  Dk.page = "home"
  Dk.Hide()
  _G.C_DeathRecap, _G.UnitIsDeadOrGhost, _G.GetPlayerInfoByGUID, _G.date = keep.dr, keep.dead, keep.info, keep.date
  db.popup, db.rivals, RC.last, RC.waitFight = keep.popup, keep.rivals, keep.last, keep.wait
  for i = #DP.Deaths, 1, -1 do DP.Deaths[i] = nil end
  for i, d in ipairs(keep.deaths) do DP.Deaths[i] = d end
end
