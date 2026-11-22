-- dev/apps/combo.lua - the combo app: NOW, BEST (a combo's own page), FIGHTS, the card.
return function(H)
  local ok, NS, R, W, Dk = H.ok, H.NS, H.R, H.W, H.Dk
  local C = NS.Combo
  local def = H.Page("combo")
  local p = def.page
  local tool = R:Get("combo")
  local db = R:DBFor(tool)
  local keep = { fights = db.fights, sid = db.lastSid, min = db.min, names = db.imbueNames, db = C.db, knows = C.Knows, why = C.lastWhy, tab = def.tab, api = _G.BiSHealingAPI,
    we = _G.GetWeaponEnchantInfo, ti = _G.GetTotemInfo, is = _G.issecretvalue, print = NS.Print, open = db.open }
  C.db = db
  db.fights, db.lastSid, db.min, db.imbueNames = {}, nil, nil, nil
  _G.BiSHealingAPI = nil
  _G.GetWeaponEnchantInfo = function() return false end
  _G.GetTotemInfo = function() return true, "" end
  C.Knows = function() return false end
  local said = {}
  NS.Print = function(f, ...) said[#said + 1] = f:format(...) end
  local function press(b) ok(type(b) == "table" and type(b.fn) == "function", "there is something to press", b and b.word) Dk.Press(def, b)() end
  local function row(tab, words)
    for _, r in ipairs(p.rows(tab)) do if r.text:find(words, 1, true) then return r end end
  end
  local function key(tab, word) for _, b in ipairs(p.keys(tab)) do if b.word == word then return b end end end
  local later = W.now
  local function moment() later = later + 1 W.now = later end

  -- nothing yet
  ok(#p.tabs() == 4 and p.tabs()[4] == "SETTINGS", "NOW, BEST, FIGHTS and the settings")
  for tab = 1, 3 do
    ok(#p.boxes(tab) == 0 and p.text(tab):find("No fight yet", 1, true), "no fight: tab " .. tab .. " says what to do")
    ok(key(tab, "OLD WINDOW"), "and the old window is one key away")
    H.Paint("combo", tab)
  end
  ok(def.card.prio() == nil and def.card.prio(true) == nil, "no fight, no card")

  -- five fights, two combos
  local WF = { imbue = "Windfury Weapon", totems = { "Grace of Air Totem", "Strength of Earth Totem" } }
  local FT = { imbue = "Flametongue Weapon", totems = { "Strength of Earth Totem" } }
  local function fight(set, dmg, dur, mob, more)
    local t = {}
    for _, n in ipairs(set.totems) do t[n] = true end
    local f = { at = W.now, sid = #db.fights + 1, mob = mob, dur = dur, dmg = dmg, imbue = set.imbue, totems = set.totems, combo = C.Label(set.imbue, t), wf = 0, ft = 0,
      spells = { { name = "Melee", share = 0.7 }, { name = "Windfury Attack", share = 0.3 } } }
    for k, v in pairs(more or {}) do f[k] = v end
    db.fights[#db.fights + 1], db.lastSid = f, f.sid
    return f
  end
  fight(FT, 900, 10, "Boar")
  fight(FT, 1100, 10, "Wolf")
  moment()
  ok(def.card.prio() == 6, "a fight just read: the card comes by itself")
  fight(WF, 1500, 10, "Bloodsnout", { wf = 0.3, active = 8, procs = { extra1 = 2, extra2 = 1, more = 0, fire = 0 }, swings = 20 })
  moment()
  -- the huge number: this set-up's own, the breakdown on hover, its boxes at a press
  local h = p.hero(1)
  ok(h.art == "number" and h.big == "188" and h.small == "DPS  WF + SoE, GoA" and h.right == "last 188  +88%" and h.under == "1 fight, #1 of 2" and h.ink == "gold", "NOW: the set-up's dps, huge", h.big .. " / " .. h.small .. " / " .. h.right .. " / " .. h.under)
  local lines = {}
  for _, x in ipairs(h.lines) do lines[x[1]] = x[2] end
  ok(lines.Place == "1 of 2" and lines.Fights == "1" and lines.Average == "188" and lines["Last fight"] == "Bloodsnout, 8 of 10 s swinging" and lines.Versus == "+88%" and lines.Procs == "3 WF", "every number on hover", tostring(lines.Place))
  ok(p.hero(2) == nil and p.icons(1) == nil and #p.boxes(1) == 0, "only on NOW; no Calls on this character: no icons; no boxes")
  H.Paint("combo", 1)
  h.fn()
  local b = p.boxes(1)
  ok(b[1][2] == "188" and b[2][2] == "1/2" and b[3][2] == "+88%" and b[3][3] == "good" and b[4][2] == "30%",
    "NOW: 188 dps over the 8 s of swinging, first of two, 88% over the others, 30% Windfury", b[1][2] .. " " .. b[2][2] .. " " .. b[3][2])
  local last = p.rows(1)[1]
  ok(last.text == "Last: SoE, GoA" and last.pic == C.IconFor("Windfury Weapon") and last.tip:find("Grace of Air Totem", 1, true), "its row: the imbue's picture, the totems' short names", last.text)
  ok(b[5][1] == "PROCS" and b[5][2] == "3 WF" and b[6][1] == "MELEE" and b[6][2] == "70%" and b[7][1] == "WINDFURY" and last.verb == "OPEN", "its procs and its spells stand beside each other, in boxes", b[7] and b[7][1])
  ok(p.say(1) == "8 of 10 s swinging, Bloodsnout", "the mob and the time under it", p.say(1))
  ok(not row(1, "Try: ") and p.big(1) == nil, "nothing learned: nothing to try")
  H.Paint("combo", 1)

  -- the card
  local l = def.card.lines()
  ok(l[3] == "#1 WF, SoE, GoA" and l[4] == "188 dps" and l.hot and l.list[1][2] == "1 of 2" and l.list[2][2] == "+88%" and l.list[3][2] == "188", "the card: place, dps, against your average", l[3] .. " " .. l[4])
  ok(#def.card.buttons() == 1 and def.card.buttons()[1].word == "OPEN", "no BiS Healing: OPEN alone")
  W.now = W.now + 300
  ok(def.card.prio() == nil and def.card.prio(true) == 2, "later it is gone; on your screen it stays")
  later = W.now

  -- a worse fight on a harder mob is not worse
  local hard = fight(WF, 1200, 10, "Ogre", { gap = 3 })
  moment()
  ok(p.boxes(1)[1][2] == "120" and p.boxes(1)[3][3] == "good", "a mob three levels up: its 120 counts for more", p.boxes(1)[3][2])
  table.remove(db.fights)
  ok(hard.gap == 3, "(taken out again)")
  moment()

  -- TRY NEXT: what Combo.lua says
  C.Knows = function(n) return n == "Windfury Weapon" or n == "Flametongue Weapon" or n == "Strength of Earth Totem" or n == "Grace of Air Totem" end
  moment()
  local c = C.TryNext()
  local t = row(1, "Try: ")
  ok(c and t and t.sub == (c.n == 0 and "never fought" or (c.n .. " fights so far")) and t.tip:find(c.imbue, 1, true) and not t.act, "Try: the one the tool would try, in one row (no Calls on this character: nothing to press)", t and t.sub)
  ok(not row(1, c.totems[1]) and Dk.IsSecure(p.keys(1)[1]) and p.keys(1)[1].spell == c.imbue, "its imbue is a secure key, drawn dim")
  local big = p.big(1)
  ok(big.word:find("SET DECK", 1, true) and big.tip:find("Install BiS Healing", 1, true), "SET DECK says what is missing")
  press(big)
  ok(said[#said]:find("Install BiS Healing", 1, true), "and so does a press")
  local sent
  _G.BiSHealingAPI = { version = 3, SetTotems = function(set) sent = set return true end }
  press(p.big(1))
  ok(sent and sent.earth == "Strength of Earth Totem", "with it: the totems go to its deck")
  ok(#def.card.buttons() == 2, "and the card has it too")
  H.Paint("combo", 1)

  -- what is up now
  _G.GetWeaponEnchantInfo = function() return true, 1500000, 0, 284 end
  _G.GetTotemInfo = function(s) return true, ({ [2] = "Strength of Earth Totem II", [4] = "Grace of Air Totem" })[s] or "" end
  ok(row(1, "Up now: SoE, GoA").right == "1/2", "what is on you now, and its place")
  -- a fight's secrets
  local meta = { __index = function() error("secret") end, __eq = function() error("secret") end, __lt = function() error("secret") end, __concat = function() error("secret") end }
  local S = setmetatable({}, meta)
  _G.issecretvalue = function(v) return type(v) == "table" and getmetatable(v) == meta end
  _G.GetWeaponEnchantInfo = function() return S, S, S, S end
  _G.GetTotemInfo = function() return S, S end
  ok(pcall(p.rows, 1) and not row(1, "Up now"), "hidden answers: no error, nothing said")
  _G.issecretvalue = keep.is
  _G.GetWeaponEnchantInfo = function() return false end
  _G.GetTotemInfo = function() return true, "" end

  -- BEST
  local rows = p.rows(2)
  ok(#rows == 2 and rows[1].right == "188 (1)" and rows[1].ink == "gold" and rows[1].text == "SoE, GoA" and rows[2].right == "100 (2)" and rows[2].text == "SoE", "BEST: the ranking, with how many fights")
  ok(p.boxes(2)[1][2] == 2 and p.boxes(2)[2][2] == 3 and p.boxes(2)[3][2] == "188", "its boxes")
  H.Paint("combo", 2)
  press(rows[2].act)
  rows = p.rows(2)
  ok(rows[1].text == "All combos" and rows[2].right == "#2 of 2" and p.boxes(2)[1][2] == "2" and p.boxes(2)[2][2] == "100" and p.boxes(2)[3][2] == "110", "a press: that combo's own page")
  ok(row(2, "Wolf").right == "110" and row(2, "Boar").right == "90" and not row(2, "Bloodsnout") and p.big(2).word == "SET DECK: SoE", "its own fights, newest first, and its deck")
  H.Paint("combo", 2)
  press(rows[1].act)
  ok(p.rows(2)[1].right == "188 (1)", "back to all of them")
  -- forget one combo: it asks first
  press(p.rows(2)[2].act)
  local gone = key(2, "FORGET")
  press(gone)
  ok(key(2, "SURE?") and #db.fights == 3, "FORGET asks first")
  press(key(2, "SURE?"))
  ok(#db.fights == 1 and p.rows(2)[1].right == "188 (1)", "the second press forgets it, and only it; the page goes back")

  -- FIGHTS
  moment()
  ok(#p.rows(3) == 1 and p.rows(3)[1].text == "Bloodsnout" and p.boxes(3)[1][2] == 1, "FIGHTS: every one kept")
  H.Paint("combo", 3)
  press(p.rows(3)[1].act)
  ok(def.tab == 2 and p.rows(2)[1].text == "All combos", "a press on a fight: its combo's page")
  press(p.rows(2)[1].act)
  press(key(3, "FORGET ALL"))
  ok(key(3, "SURE?") and #db.fights == 1, "FORGET ALL asks first")
  W.now = W.now + 6
  ok(key(3, "FORGET ALL"), "and five seconds later it has forgotten that you asked")
  press(key(3, "FORGET ALL"))
  press(key(3, "SURE?"))
  ok(#db.fights == 0 and not key(3, "FORGET ALL"), "the second press: all gone")

  -- the old window
  press(key(1, "OLD WINDOW"))
  ok(C.IsOpen(), "OLD WINDOW opens the list")
  C.Toggle(false)

  db.fights, db.lastSid, db.min, db.imbueNames, db.open = keep.fights, keep.sid, keep.min, keep.names, keep.open
  C.db, C.Knows, C.lastWhy, def.tab, NS.Print, _G.BiSHealingAPI = keep.db, keep.knows, keep.why, keep.tab, keep.print, keep.api
  _G.GetWeaponEnchantInfo, _G.GetTotemInfo, _G.issecretvalue = keep.we, keep.ti, keep.is
end
