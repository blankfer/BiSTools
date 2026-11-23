-- The three Calls (22 Nov 2026, Arn: "if we can just have a manager that edits these so i can drop them all at once")
return function(H)
  local ok, T, C, Dk, R, W = H.ok, H.NS.Totems, H.NS.Combo, H.Dk, H.R, H.W
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
  -- THE COMBO APP'S ROW: the imbue and four totems, saved in a Call by a press on it; what agrees with a Call glows in its colour
  do
    local cp = Dk.defs["BiSTools:tool-combo"].page
    local cdb = R:DBFor(R:Get("combo"))
    local keepDb = { callNow = cdb.callNow, fights = cdb.fights, draft = cdb.draft, callImbue = cdb.callImbue, seen = cdb.imbueSeen, names = cdb.imbueNames }
    local we, kn = _G.GetWeaponEnchantInfo, C.Knows
    cdb.callNow, cdb.fights, cdb.draft, cdb.callImbue, cdb.imbueSeen = nil, {}, nil, nil, nil
    cdb.imbueNames = { [283] = "Windfury Weapon", [2] = "Frostbrand Weapon" }
    local weapon = 283
    _G.GetWeaponEnchantInfo = function() return weapon ~= nil, 100000, 0, weapon end
    C.Knows = function(n) return n == "Frostbrand Weapon" or n == "Windfury Weapon" or n == "Magma Totem" or kn(n) end
    at[133], at[134], at[135], at[136] = 1, 3, 5, 7
    at[141], at[142], at[143], at[144] = 2, 3, nil, 6
    T.said = nil
    local function moment() W.now = W.now + 1 end
    local function row() moment() return cp.icons(1)[1] end
    local function call(i) moment() return cp.icons(1)[2][i] end
    local function line(words) moment() for _, x in ipairs(cp.rows(1)) do if x.text:find(words, 1, true) == 1 then return x end end end
    local function glows() local o = {} for k, x in ipairs(row()) do o[k] = x.glow or "-" end return table.concat(o, " ") end
    local ic = cp.icons(1)
    ok(#ic == 2 and #ic[1] == 5 and #ic[2] == 2 and T.Now() == 1 and ic[1][1].word == "Windfury" and ic[1][2].word == "Flametongue" and ic[1][2].pic == 1001 and ic[1][3].word == "Strength"
      and ic[1][4].word == "Mana Spring" and ic[1][5].word == "Windfury", "the row: the imbue, then the Call's four totems, water too", ic[1][4].word)
    ok(glows() == "red red red red red" and call(1).glow == "red" and call(2).glow == nil and cp.say(1):find("The row is Call of the Elements (red)", 1, true), "all agrees: the row and its Call in its colour", glows())
    ok(cp.hero(1).big == "NEW" and cp.hero(1).small:find("WF + FT, SoE, WF", 1, true) and cp.big(1) == nil and #cp.keys(1) == 0, "its number over it; no other buttons", cp.hero(1).small)
    -- another Call, nothing changed: it comes onto the row
    ok(call(2).act.spell == "Call of the Spirits" and Dk.IsSecure(call(2).act) and call(2).act.ok() == true, "a Call's press casts it")
    ok(T.Now() == 3 and glows() == "accent accent accent - accent" and call(2).glow == "accent" and call(1).glow == nil and row()[4].word == "Water" and row()[4].pic == nil, "the Spirits on the row, in purple; an empty place says which", glows())
    call(1).act.ok()
    C.Knows = function(n) return n == "Totemic Call" or n == "Frostbrand Weapon" or n == "Windfury Weapon" or n == "Magma Totem" or kn(n) end
    ok(#cp.icons(1)[2] == 3 and cp.icons(1)[2][3].act.spell == "Totemic Call" and not cp.icons(1)[2][3].glow, "Totemic Call beside them, when you know it")
    -- one totem changed, in place: it and the Call glow no more
    Dk.page = "BiSTools:tool-combo"
    press(row()[2].act)
    moment()
    local cr = cp.rows(1)
    ok(Dk.page == "BiSTools:tool-combo" and cr[1].text == "Fire totem" and cr[2].text == "Flametongue" and cr[2].verb == "HERE" and cr[3].text == "Magma" and cr[3].verb == "PUT" and cr[4].text == "Nothing" and row()[2].lit, "the fire totems, right there", cr[2].text)
    press(cr[3].act)
    ok(at[133] == 1 and row()[2].word == "Magma" and glows() == "red - red red red" and call(1).glow == nil and call(2).glow == nil and cp.say(1):find("Changed", 1, true), "changed on the row only: that icon and the Call glow no more", glows())
    press(row()[2].act) moment()
    press(cp.rows(1)[2].act)
    ok(cdb.draft == nil and glows() == "red red red red red" and call(1).glow == "red", "put back: it agrees again", glows())
    press(row()[2].act) moment()
    press(cp.rows(1)[1].act)
    moment()
    ok(cp.rows(1)[1].mark ~= "<", "BACK: nothing changed")
    -- changed, then saved in another Call: its colour
    press(row()[2].act) moment()
    press(cp.rows(1)[3].act)
    refuse = true
    ok(call(2).act.ok() == false and T.said:find("click again", 1, true), "the game refuses: nothing is cast, it says so", T.said)
    refuse = false
    ok(call(2).act.ok() == true and at[141] == 2 and at[142] == 3 and at[143] == 5 and at[144] == 7 and at[133] == 1, "saved in the Spirits, water too; the Elements untouched", at[143])
    ok(T.Now() == 3 and glows() == "accent accent accent accent accent" and call(2).glow == "accent" and cdb.callImbue[3] == "Windfury Weapon" and cdb.draft == nil, "all purple: imbue and totems as set", glows())
    -- the imbue, in place; saved with the Call
    press(row()[1].act) moment()
    cr = cp.rows(1)
    ok(cr[1].text == "Imbue" and cr[2].text == "Windfury Weapon" and cr[2].right == "ON" and cr[3].act.spell == "Frostbrand Weapon" and Dk.IsSecure(cr[3].act), "the imbue's icon: your imbues, each puts itself on", cr[2] and cr[2].text)
    ok(cr[3].act.ok() == true and row()[1].word == "Frostbrand" and glows() == "- accent accent accent accent" and call(2).glow == nil and row()[1].ink == "warn", "another imbue: only that one differs; not on the weapon yet is said", glows())
    weapon = 2
    ok(row()[1].ink == nil and glows():find("^%-"), "on the weapon now")
    ok(call(1).act.ok() == true and cdb.callImbue[1] == "Frostbrand Weapon" and at[133] == 2 and T.Now() == 1 and glows() == "red red red red red", "saved in the Elements: all red", glows())
    ok(call(2).act.ok() == true and row()[1].word == "Windfury" and row()[1].ink == "warn" and glows() == "accent accent accent accent accent", "the Spirits again: its own imbue on the row, not on the weapon yet")
    -- imbued by hand: the row follows
    weapon = 283
    row()
    weapon = 2
    ok(row()[1].word == "Frostbrand" and T.Now() == 1 and glows() == "red red red red red", "imbued by hand: the row follows - and is what the Elements hold, so it is them", glows())
    cdb.draft = nil
    -- TRY, TOP and LAST: one line each, put on the row
    cdb.fights = { { at = 1, mob = "Boar", dur = 10, dmg = 100, imbue = "Windfury Weapon", totems = { "Flametongue Totem", "Grace of Air Totem" }, combo = "x", wf = 0, ft = 0, spells = {} } }
    moment()
    ok(#cp.rows(1) == 3 and line("TRY").sub == "never fought" and line("TOP").sub == "1 dps, 5 fights" and line("LAST").sub == "10 dps, Boar" and not line("TRY").icons, "TRY, TOP and LAST: a line each, the icons stand on the page once", line("TOP").sub)
    ok(line("TRY").verb == "SET" and not Dk.IsSecure(line("TRY").act), "SET: onto the row")
    press(line("LAST").act)
    ok(row()[1].word == "Windfury" and row()[2].word == "Flametongue" and row()[3].word == "Earth" and row()[5].word == "Grace" and row()[4].word == "Mana Spring" and line("LAST").verb == "ON IT", "its imbue and totems on the row, the water totem stays", row()[2].word .. " " .. row()[3].word)
    ok(cp.hero(1).small:find("WF + FT, GoA", 1, true) and at[133] == 2, "and the number is that set-up's; no Call was written", cp.hero(1).small)
    press(line("TRY").act)
    ok(row()[1].word == "Frostbrand" and row()[2].word == "Magma" and cp.hero(1).small:find("FB + ", 1, true), "the one to try")
    -- a best combo without an imbue, and one without any totem (Arn's own list, 22 Nov: an error on his first look)
    do
      local rk = C.Rank
      C.Rank = function() return { { combo = "n", imbue = nil, totems = {}, n = 5, adj = 1, dps = 1 } } end
      moment()
      local fine, why = pcall(cp.rows, 1)
      ok(fine and line("TOP") and pcall(cp.hero, 1) and pcall(cp.icons, 1), "no imbue, no totems: said, no error", why)
      press(line("TOP").act)
      ok(pcall(cp.icons, 1) and row()[2].word == "Fire" and call(1).act.ok() == true, "and on the row, and saved")
      C.Rank = rk
      moment()
    end
    -- all of it at the normal size (Arn, 22 Nov: "lets always make stuff fit the 100% size")
    do
      BiSTheme.DECK_LOGIN = true
      Dk.Store().welcomed = true
      Dk.Show()
      local was = R:Enabled("combo")
      R:SetEnabled("combo", true)
      Dk.W, Dk.H, Dk.shape, Dk.page = 260, 462, "portrait", "BiSTools:tool-combo"
      Dk.Store().toured = type(Dk.Store().toured) == "table" and Dk.Store().toured or {}
      Dk.Store().toured["BiSTools:tool-combo"] = true
      Dk.defs["BiSTools:tool-combo"].tab = 1
      Dk.Paint()
      R:SetEnabled("combo", was)
      local icons, n, say = 0, 0, false
      for _, w in ipairs(Dk.frame.pieces) do if w:IsShown() then if w.kind == "row" then n = n + 1 elseif w.kind == "icon" then icons = icons + 1 elseif w.kind == "say" then say = true end end end
      ok(n == 3 and icons == 5 + 3 and say, "260 x 462: every row and every icon, and what the row is in words", n .. " rows, " .. icons .. " icons")
      Dk.page = "home" Dk.Hide()
      Dk.Store().open, Dk.Store().welcomed = false, nil
    end
    -- hidden answers: no error
    local S2 = {}
    local is = _G.issecretvalue
    _G.issecretvalue = function(v) return v == S2 end
    local gi = _G.GetActionInfo
    _G.GetActionInfo = function() return S2, S2 end
    moment()
    ok(pcall(cp.icons, 1) and pcall(cp.rows, 1) and pcall(cp.hero, 1) and pcall(cp.say, 1), "the bar hidden: no error")
    _G.GetActionInfo, _G.issecretvalue = gi, is
    for k, v in pairs({ "callNow", "fights", "draft", "callImbue" }) do cdb[v] = keepDb[v] end
    cdb.imbueSeen, cdb.imbueNames = keepDb.seen, keepDb.names
    _G.GetWeaponEnchantInfo, C.Knows, T.said = we, kn, nil
    at[133], at[134], at[135], at[136] = 1, 3, 5, 7
    at[141], at[142], at[143], at[144] = 2, 3, nil, 6
    moment()
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
