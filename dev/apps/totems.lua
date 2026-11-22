-- The three Calls (22 Nov 2026, Arn: "if we can just have a manager that edits these so i can drop them all at once")
return function(H)
  local ok, T, C, Dk, R = H.ok, H.NS.Totems, H.NS.Combo, H.Dk, H.R
  local keep = { cls = _G.UnitClass, set = _G.SetMultiCastSpell, list = _G.GetMultiCastTotemSpells, info = _G.GetActionInfo, bar = _G.GetMultiCastBarIndex, sp = _G.C_Spell,
    knows = C.Knows, fight = _G.InCombatLockdown, is = _G.issecretvalue, try = C.TryNext, rank = C.Rank }
  _G.UnitClass = function() return "Mage", "MAGE" end
  ok(T.Register() == false, "not a shaman: no Totems app")
  _G.UnitClass = function() return "Shaman", "SHAMAN" end
  -- the client's bar: page 12, actions 133-144; a slot takes only its own element's spells (the client says nothing when it refuses)
  local NAME = { [1] = "Flametongue Totem II", [2] = "Magma Totem", [3] = "Strength of Earth Totem III", [4] = "Stoneskin Totem", [5] = "Mana Spring Totem", [6] = "Grace of Air Totem", [7] = "Windfury Totem II" }
  local FITS = { { 1, 2 }, { 3, 4 }, { 5 }, { 6, 7 } }
  local at, writes, refuse, fighting = { [133] = 2, [135] = 5 }, 0, false, false
  _G.InCombatLockdown = function() return fighting end
  _G.GetMultiCastBarIndex = function() return 12 end
  _G.GetMultiCastTotemSpells = function(s) return unpack(FITS[s] or {}) end
  _G.GetActionInfo = function(a) if at[a] then return "spell", at[a], "spell" end end
  _G.SetMultiCastSpell = function(a, id)
    if fighting then error("ADDON_ACTION_BLOCKED") end
    writes = writes + 1
    if refuse then return end
    local slot = (a - 133) % 4 + 1
    if id == 0 then at[a] = nil return end
    for _, x in ipairs(FITS[slot]) do if x == id then at[a] = id end end
  end
  _G.C_Spell = setmetatable({ GetSpellName = function(id) return NAME[id] end, GetSpellTexture = function(id) return 1000 + id end }, { __index = keep.sp })
  C.Knows = function(n) return n == "Call of the Elements" or n == "Call of the Spirits" end
  ok(T.Action(1, 1) == 133 and T.Action(3, 4) == 144, "the game's bar: fire of the Elements is 133, air of the Spirits 144")
  ok(T.Get(1, 1) == 2 and T.Get(1, 2) == nil and T.Find(1, "Flametongue Totem") == 1 and T.Find(4, "Windfury Totem") == 7, "what stands there; a totem by its plain name, whatever its rank")
  ok(T.Register() == true and T.Register() == false, "a shaman: the app, once")
  local def = Dk.defs["BiSTools:totems"]
  local p = def.page
  local function press(b) b.fn() end
  ok(#p.tabs() == 2 and p.tabs()[2] == "SPIRITS", "a tab for each Call you know")
  local rows = p.rows(1)
  ok(rows[1].text == "Fire: Magma" and rows[1].verb == "CHANGE" and rows[1].pic == 1002 and rows[2].text == "Earth: nothing" and rows[3].text == "Water: Mana Spring", "its four places", rows[1].text)
  ok(p.big(1).spell == "Call of the Elements" and p.big(1).word == "DROP: ELEMENTS", "the big button drops them all")
  press(rows[1].act)
  rows = p.rows(1)
  ok(rows[1].text == "Back" and rows[2].text == "Flametongue" and rows[2].verb == "PUT" and rows[3].verb == "HERE" and rows[4].text == "Nothing", "a place opened: what fits there", rows[2].text)
  press(rows[2].act)
  ok(at[133] == 1 and p.rows(1)[1].text == "Fire: Flametongue" and p.say() == nil, "put: it stands there")
  press(p.rows(1)[3].act) press(p.rows(1)[3].act)
  ok(at[135] == nil and p.rows(1)[3].text == "Water: nothing", "nothing: emptied")
  at[135] = 5
  refuse = true press(p.rows(1)[2].act) press(p.rows(1)[2].act) ok(p.say():find("did not take"), "the game refuses: said") refuse = false
  -- from the combos
  C.Rank = function() return { { combo = "a", imbue = "Windfury Weapon", totems = { "Flametongue Totem", "Strength of Earth Totem", "Windfury Totem" }, n = 5, adj = 1, dps = 1 } } end
  C.TryNext = function() return { combo = "b", imbue = "Frostbrand Weapon", totems = { "Magma Totem", "Strength of Earth Totem", "Grace of Air Totem" }, n = 0 }, 4, 2 end
  local function row(words) for _, r in ipairs(p.rows(1)) do if r.text:find(words, 1, true) then return r end end end
  ok(row("best combo").verb == "FILL" and not row("best combo").right, "FILL from your best combo")
  press(row("best combo").act)
  ok(at[133] == 1 and at[134] == 3 and at[135] == 5 and at[136] == 7 and row("best combo").right == "IN IT", "filled, the water totem left alone")
  -- DROP ALL: fills the Call you do not use every day, and casts it
  ok(T.ComboPage() == 3, "the last Call you know (the Spirits)", T.ComboPage())
  local b = T.DropAll({ "Magma Totem", "Strength of Earth Totem", "Grace of Air Totem" }, "DROP ALL")
  ok(b.spell == "Call of the Spirits" and Dk.IsSecure(b), "one secure button")
  ok(b.ok() == true and at[141] == 2 and at[142] == 3 and at[143] == nil and at[144] == 6 and at[133] == 1, "the click fills it first, the Elements untouched")
  local before = writes
  ok(b.ok() == true and writes == before, "again: it stands already, nothing written")
  -- THE COMBO APP'S ICONS: the chosen Call's four totems (the water one too), and the Calls you know
  do
    local cp = Dk.defs["BiSTools:tool-combo"].page
    local cdb = R:DBFor(R:Get("combo"))
    local was, fights = cdb.callNow, cdb.fights
    cdb.callNow, cdb.fights = nil, {}
    at[135] = 5
    local ic = cp.icons(1)
    ok(#ic == 2 and #ic[1] == 5 and #ic[2] == 2 and T.Now() == 1 and ic[2][1].lit and not ic[2][2].lit and ic[2][2].word == "Spirits", "two Calls known: the first is chosen", ic and #ic[2])
    ok(ic[1][1].word == "No imbue" and not ic[1][1].act and ic[1][2].word == "Flametongue" and ic[1][2].pic == 1001 and ic[1][3].word == "Strength" and ic[1][4].word == "Mana Spring" and ic[1][4].pic == 1005 and ic[1][5].word == "Windfury", "the imbue first, then its four totems, water too", ic[1][4].word)
    ok(cp.hero(1).big == "NEW" and cp.hero(1).small:find("FT, SoE, WF", 1, true) and cp.hero(1).under:find("never fought", 1, true), "the number is that set-up's: not fought yet", cp.hero(1).small)
    ok(cp.big(1) == nil and ic[2][1].act.spell == "Call of the Elements" and Dk.IsSecure(ic[2][2].act), "a Call's icon casts it; no big button beside them")
    ok(ic[2][2].act.spell == "Call of the Spirits" and ic[2][2].act.ok() == true and T.Now() == 3 and cp.icons(1)[2][2].lit, "another: chosen by the same click")
    local knows = C.Knows
    C.Knows = function(n) return n == "Totemic Call" or knows(n) end
    ok(#cp.icons(1)[2] == 3 and cp.icons(1)[2][3].act.spell == "Totemic Call", "Totemic Call beside them, when you know it")
    C.Knows = knows
    ok(cp.icons(1)[1][4].word == "Water" and cp.icons(1)[1][4].pic == nil and cp.icons(1)[1][2].word == "Magma", "its totems; an empty place says which", cp.icons(1)[1][2].word)
    H.Paint("combo", 1)
    press(cp.icons(1)[1][5].act)
    ok(Dk.page == "BiSTools:totems" and def.tab == 2 and p.rows(2)[1].text == "Back", "a totem's icon: that place, to change it", Dk.page)
    press(p.rows(2)[1].act)
    Dk.page = "home" Dk.Hide()
    -- TRY and LAST: their imbue and totems onto the row
    local function line(words) for _, x in ipairs(cp.rows(1)) do if x.text:find(words, 1, true) then return x end end end
    T.Choose(1)
    local knows2, mine = C.Knows, at[133]
    C.Knows = function(n) return n == "Frostbrand Weapon" or n == "Windfury Weapon" or knows2(n) end
    local function rowsOf(words) for i, x in ipairs(cp.rows(1)) do if x.text:find(words, 1, true) then return x.icons, cp.rows(1)[i + 1].icons, x end end end
    local it, calls, tr = rowsOf("TRY")
    ok(#it == 5 and it[1].word == "FB" and it[1].act.spell == "Frostbrand Weapon" and it[2].word == "Magma" and it[2].act == nil and it[4].word == "Windfury" == false and tr.sub == "never fought", "TRY: the imbue and the four totems, each its own press", it[1].word .. " " .. it[2].word)
    ok(#calls == 2 and calls[2].word == "Spirits" and Dk.IsSecure(calls[2].act) and calls[2].act.spell == "Call of the Spirits", "and the Calls under it")
    ok(#cp.keys(1) == 0, "no keys beside them")
    ok(calls[2].act.ok() == true, "a Call there: these go in")
    local top = cp.icons(1)[1]
    ok(T.Now() == 3 and at[141] == 2 and at[142] == 3 and at[144] == 6 and at[133] == mine, "its totems go into the combo's own Call, the everyday one untouched", at[141])
    ok(top[1].word == "Frostbrand" and top[1].act.spell == "Frostbrand Weapon" and Dk.IsSecure(top[1].act) and not top[1].lit and top[2].word == "Magma" and top[4].word == "Mana Spring", "on the row: the imbue, a press puts it on; the water totem came along", top[4].word)
    ok(cp.hero(1).small:find("FB + ", 1, true), "and the number is that set-up's", cp.hero(1).small)
    cdb.fights = { { at = 1, mob = "Boar", dur = 10, dmg = 100, imbue = "Windfury Weapon", totems = { "Flametongue Totem", "Grace of Air Totem" }, combo = "x", wf = 0, ft = 0, spells = {} } }
    ok(line("Last: ").verb == "SET", "the last fight: SET")
    press(line("Last: ").act)
    top = cp.icons(1)[1]
    ok(top[1].word == "Windfury" and top[2].word == "Flametongue" and top[5].word == "Grace", "its imbue and totems on the row", top[1].word .. " " .. top[2].word .. " " .. top[5].word)
    local _, _, best = rowsOf("TOP ")
    ok(best and best.text == "TOP 1" and best.sub == "5 fights" and best.icons[5].word == "WF" and rowsOf("TOP ")[4].word == "Mana Spring", "under it the top one, the same way", best and best.text)
    refuse = true
    local tc = select(2, rowsOf("TOP "))
    local said = #T.CALLS
    at[144] = 6
    ok(tc[2].act.ok() == false, "the game refuses: nothing is cast") refuse = false
    ok(tc[2].act.ok() == true and at[144] == 7 and cp.icons(1)[1][1].word == "Windfury", "else it is set and dropped, and is the row on top")
    H.Paint("combo", 1)
    cdb.imbueNow, cdb.imbueSeen = "Frostbrand Weapon", nil
    local we, nm = _G.GetWeaponEnchantInfo, cdb.imbueNames
    _G.GetWeaponEnchantInfo = function() return true, 100000, 0, 283 end
    cdb.imbueNames = { [283] = "Windfury Weapon" }
    ok(cp.icons(1)[1][1].word == "Windfury" and cp.icons(1)[1][1].lit, "imbued by hand: the row follows, lit", cp.icons(1)[1][1].word)
    _G.GetWeaponEnchantInfo, cdb.imbueNames = we, nm
    cdb.imbueNow, cdb.imbueSeen = nil, nil
    C.Knows = knows2
    cdb.callNow, cdb.fights = was, fights
    at[135] = 5
  end
  refuse, at[144] = true, 7 ok(b.ok() == false, "the game refuses: no cast of the wrong totems") refuse = false
  ok(b.ok() == true, "and the next click does it")
  press(row("The Combo app drops").act) ok(T.ComboPage() == 1 and row("The Combo app drops").verb == "YES", "or with the Call you say")
  R:DBFor(R:Get("combo")).callPage = nil
  fighting = true ok(T.Set(1, 1, 2) == false and T.Fill(1, { "Magma Totem" }) == 0, "a fight: nothing is written") fighting = false
  -- secrets, and a client without it
  local S = {}
  _G.issecretvalue = function(v) return v == S end
  _G.GetActionInfo = function() return S, S end
  _G.GetMultiCastTotemSpells = function() return S, S end
  ok(pcall(p.rows, 1) and T.Get(1, 1) == nil and #T.List(1) == 0, "hidden answers: no error")
  _G.issecretvalue = keep.is
  _G.SetMultiCastSpell = nil
  ok(not T.Can() and T.DropAll({ "Magma Totem" }, "x") == nil and p.text(1):find("does not let"), "a client without it: said, no button")
  for _, z in ipairs({ { 220, 300 }, { 260, 462 }, { 600, 420 } }) do
    BiSTheme.DECK_LOGIN = true
    Dk.Store().welcomed = true
    Dk.Show()
    Dk.W, Dk.H, Dk.shape, Dk.page = z[1], z[2], BiSTheme.DeckShape(z[1], z[2]), "BiSTools:totems"
    Dk.Paint()
    ok(Dk.page == "BiSTools:totems" and not def.parked, "it paints at " .. z[1])
  end
  Dk.page = "home"
  Dk.Hide()
  Dk.Store().open, Dk.Store().welcomed = false, nil
  Dk.defs["BiSTools:totems"] = nil
  T.done = nil
  _G.UnitClass, _G.SetMultiCastSpell, _G.GetMultiCastTotemSpells, _G.GetActionInfo, _G.GetMultiCastBarIndex, _G.C_Spell = keep.cls, keep.set, keep.list, keep.info, keep.bar, keep.sp
  C.Knows, C.TryNext, C.Rank, _G.InCombatLockdown = keep.knows, keep.try, keep.rank, keep.fight
end
