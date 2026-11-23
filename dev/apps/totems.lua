-- The three Calls (22 Nov 2026, Arn: "if we can just have a manager that edits these so i can drop them all at once")
return function(H)
  local ok, T, C, Dk, R, W = H.ok, H.NS.Totems, H.NS.Combo, H.Dk, H.R, H.W
  local keep = { cls = _G.UnitClass, set = _G.SetMultiCastSpell, list = _G.GetMultiCastTotemSpells, info = _G.GetActionInfo, bar = _G.GetMultiCastBarIndex, sp = _G.C_Spell,
    knows = C.Knows, fight = _G.InCombatLockdown, is = _G.issecretvalue, try = C.TryNext, rank = C.Rank }
  _G.UnitClass = function() return "Mage", "MAGE" end
  ok(not T.Shaman() and Dk.defs["BiSTools:tool-combo"].page.icons(1) == nil, "not a shaman: no row of totems")
  _G.UnitClass = function() return "Shaman", "SHAMAN" end
  ok(Dk.defs["BiSTools:tool-combo"].name == "Totems" and Dk.defs["BiSTools:tool-combo"].page.title(1) == "BiS>totems" and not Dk.defs["BiSTools:totems"], "one app, BiS>totems")
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
  local function press(b) b.fn() end
  C.Rank = function() return { { combo = "a", imbue = "Windfury Weapon", totems = { "Flametongue Totem", "Strength of Earth Totem", "Windfury Totem" }, n = 5, adj = 1, dps = 1 } } end
  C.TryNext = function() return { combo = "b", imbue = "Frostbrand Weapon", totems = { "Magma Totem", "Strength of Earth Totem", "Grace of Air Totem" }, n = 0 }, 4, 2 end
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
    local kn2 = C.Knows
    C.Knows = function(n) return n == "Totemic Recall" or kn2(n) end
    ok(#cp.icons(1)[2] == 4 and cp.icons(1)[2][4].act.spell == "Totemic Recall" and cp.icons(1)[2][4].word == "Recall" and Dk.IsSecure(cp.icons(1)[2][4].act), "Totemic Recall next to it (Arn: \"next to bring we do the recall\")")
    C.Knows = kn2
    -- one totem changed, POPPED OUT over its icon (23 Nov, the game's totem bar): it and the Call glow no more
    Dk.page = "BiSTools:tool-combo"
    local fly = row()[2].fly
    ok(row()[2].act == nil and row()[2].flyKey == "slot1" and #fly == 3 and fly[1].word == "Flametongue" and fly[1].lit and fly[2].word == "Magma" and not fly[2].lit
      and fly[3].word == "None" and fly[3].done, "the fire totems, popped out over its icon", fly[1] and fly[1].word)
    press(fly[2].act)
    ok(at[133] == 1 and row()[2].word == "Magma" and glows() == "red - red red red" and call(1).glow == nil and call(2).glow == nil and cp.say(1):find("Changed", 1, true), "changed on the row only: that icon and the Call glow no more", glows())
    ok(row()[2].fly[2].lit and not row()[2].fly[1].lit, "the pop-out knows which is on the row")
    press(row()[2].fly[1].act)
    ok(cdb.draft == nil and glows() == "red red red red red" and call(1).glow == "red", "put back: it agrees again", glows())
    ok(cp.rows(1)[1].mark ~= "<", "no list of choices in the rows")
    -- changed, then saved in another Call: its colour
    press(row()[2].fly[2].act)
    refuse = true
    ok(call(2).act.ok() == false and T.said:find("click again", 1, true), "the game refuses: nothing is cast, it says so", T.said)
    refuse = false
    ok(call(2).act.ok() == true and at[141] == 2 and at[142] == 3 and at[143] == 5 and at[144] == 7 and at[133] == 1, "saved in the Spirits, water too; the Elements untouched", at[143])
    ok(T.Now() == 3 and glows() == "accent accent accent accent accent" and call(2).glow == "accent" and cdb.callImbue[3] == "Windfury Weapon" and cdb.draft == nil, "all purple: imbue and totems as set", glows())
    -- the imbue, popped out ("imbue too"); saved with the Call
    local cr = row()[1].fly
    ok(row()[1].flyKey == "imbue" and #cr == 2 and cr[1].word == "Windfury" and cr[1].glow == "good" and cr[1].lit and cr[2].act.spell == "Frostbrand Weapon" and Dk.IsSecure(cr[2].act), "the imbue's icon: your imbues popped out, each puts itself on", cr[1] and cr[1].word)
    ok(cr[2].act.ok() == true and row()[1].word == "Frostbrand" and glows() == "- accent accent accent accent" and call(2).glow == nil and row()[1].ink == "warn", "another imbue: only that one differs; not on the weapon yet is said", glows())
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
    local rows1 = cp.rows(1)
    ok(#rows1 == 5 and rows1[1].text == "BEST 1" and rows1[1].sub == "5 fights" and rows1[3].text == "TRY" and rows1[3].sub == "0/" .. C.TRY_ENOUGH .. " fights" and rows1[5].text == "Update healing deck", "BEST, TRY, then the healing deck", rows1[3].sub)
    ok(#rows1[1].icons == 4 and rows1[1].icons[1].word == "WF" and rows1[1].icons[1].act.spell == "Windfury Weapon" and rows1[1].icons[2].word == "FT" and rows1[1].icons[4].word == "WF", "its imbue and the totems of that data", rows1[1].icons[2].word)
    ok(rows1[2].low and #rows1[2].icons == 2 and rows1[2].icons[1].word == "Elements" and rows1[2].icons[1].glow == "red" and rows1[2].icons[2].glow == "accent" and rows1[2].icons[1].flat and not Dk.IsSecure(rows1[2].icons[1].act), "the Calls in their tints, to save it in: nothing is cast")
    at[143] = nil
    press(rows1[2].icons[2].act)
    moment()
    ok(at[141] == 1 and at[142] == 3 and at[144] == 7 and at[143] == 5 and T.Now() == 3 and cdb.callImbue[3] == "Windfury Weapon" and T.said:find("Saved in Call of the Spirits", 1, true), "BEST saved in the Spirits (an empty water place takes the row's)", at[143])
    ok(row()[1].word == "Windfury" and row()[2].word == "Flametongue" and glows() == "accent accent accent accent accent" and not cp.rows(1)[2].icons[2].soft and cp.rows(1)[2].icons[1].soft, "the row is it, in purple; its button says it holds it", glows())
    press(cp.rows(1)[4].icons[1].act)
    moment()
    ok(at[133] == 2 and at[134] == 3 and at[136] == 6 and cdb.callImbue[1] == "Frostbrand Weapon" and T.Now() == 1 and row()[1].word == "Frostbrand" and row()[1].ink == nil, "TRY saved in the Elements", at[136])
    refuse = true
    at[133] = 1
    press(cp.rows(1)[4].icons[1].act)
    ok(T.said:find("press again", 1, true), "the game refuses: said", T.said)
    refuse = false
    press(cp.rows(1)[4].icons[1].act)
    moment()
    -- the last row: the healing deck
    local api = rawget(_G, "BiSHealingAPI")
    _G.BiSHealingAPI = nil
    ok(line("Update healing deck").verb == "UPDATE" and line("Update healing deck").tip:find("Install BiS Healing", 1, true), "no BiS Healing: it says so")
    press(line("Update healing deck").act)
    ok(T.said:find("Install BiS Healing", 1, true), "a press too", T.said)
    local got, callGot
    _G.BiSHealingAPI = { version = 4, SetTotems = function(x) got = x return true end, Totems = function() return got or {} end, SetCall = function(x) callGot = x return true end, Call = function() return callGot end }
    press(line("Update healing deck").act)
    ok(got.fire == "Magma Totem" and got.earth == "Strength of Earth Totem" and got.water == "Mana Spring Totem" and got.air == "Grace of Air Totem" and callGot == "Call of the Elements", "the row's four totems on the deck, water too, and its CALL on this Call", got.air)
    ok(line("Update healing deck").verb == "IS ON IT", "and it says it is")
    press(row()[2].fly[1].act) moment()
    ok(line("Update healing deck").verb == "UPDATE", "a totem changed: it is not any more")
    _G.BiSHealingAPI = { version = 3, SetTotems = function() return nil, "in a fight" end, Totems = function() return {} end }
    press(line("Update healing deck").act)
    ok(T.said:find("in a fight", 1, true), "the deck says no: said", T.said)
    _G.BiSHealingAPI = api
    cdb.draft = nil
    -- a best combo without an imbue, and one without any totem (Arn's own list, 22 Nov: an error on his first look)
    do
      local rk = C.Rank
      C.Rank = function() return { { combo = "n", imbue = nil, totems = {}, n = 5, adj = 1, dps = 1 } } end
      moment()
      local fine, why = pcall(cp.rows, 1)
      ok(fine and line("BEST") and cp.rows(1)[1].icons[1].word == "None" and pcall(cp.hero, 1) and pcall(cp.icons, 1), "no imbue, no totems: said, no error", why)
      press(cp.rows(1)[2].icons[1].act)
      ok(pcall(cp.icons, 1) and row()[2].word == "Fire" and call(1).act.ok() == true, "and saved")
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
      ok(n == 5 and icons == 5 + 3 + 2 * (4 + 2) and say, "260 x 462: every row and every icon, and what the row is in words", n .. " rows, " .. icons .. " icons")
      Dk.page = "home" Dk.Hide()
      Dk.Store().open, Dk.Store().welcomed = false, nil
    end
    -- THE TOTEM CARD (Arn, 23 Nov: "two rows and draggable" - "a small dps number ... a little tab ... where they can drag the bar"
    -- - "it can just get the info from the phone"): the phone's two rows on screen, casting
    do
      local TC = H.NS.TotemCard
      local was, kn3 = R:Enabled("combo"), C.Knows
      C.Knows = function(n) return n == "Flametongue Totem" or kn3(n) end
      R:SetEnabled("combo", true)
      press(row()[2].fly[2].act)                             -- (Magma on the fire place)
      cdb.bar = nil
      TC.Paint()
      ok(not (TC.frame and TC.frame:IsShown()), "off until switched on")
      cdb.bar = true
      moment()
      ok(TC.Paint() and TC.frame:IsShown(), "switched on: shown")
      local f = TC.frame
      local top, low = f.top, f.low
      ok(top[1]:IsShown() and top[5]:IsShown() and top[2].attrs.type1 == "spell" and top[2].attrs.spell1 == row()[2].cast and row()[2].cast ~= nil,
        "the top row: the imbue and four totems, a click drops the one there", top[2].attrs.spell1)
      ok(low[1].attrs.spell1 == "Call of the Elements" and low[2].attrs.spell1 == "Call of the Spirits", "under it the Calls, each casts", low[2].attrs.spell1)
      ok(f.tab and f.tab.num.text and f.tab.num.text ~= "" and f.tab.dps.text:find("dps", 1, true), "the dps number on its tab", f.tab.num.text)
      ok(f.w > TC.TAB + 5 * TC.SIZE and f.h >= 2 * TC.SIZE and f.h < 3 * TC.SIZE, "two rows, the size of a bar", f.w .. "x" .. f.h)
      -- a Call clicked: the row goes into it first (the phone's own ok)
      local saved
      local okFn = top[1].item and low[1].item.act.ok
      low[1].item.act.ok = function() saved = true return true end
      low[1]:GetScript("PreClick")(low[1], "LeftButton")
      ok(saved and low[1].attrs.type1 == "spell", "a Call's click: the phone's own word first, then it casts")
      low[1].item.act.ok = function() return false end
      low[1]:GetScript("PreClick")(low[1], "LeftButton")
      ok(low[1].attrs.type1 == nil, "the phone says no: nothing is cast that click")
      low[1].item.act.ok = okFn
      TC.Paint()
      -- Shift over a totem: the others pop out; a click there drops it and puts it on the row
      W.shift = true
      top[2]:GetScript("OnEnter")(top[2])
      local fb = f.flyB
      ok(f.fly:IsShown() and fb[1]:IsShown() and fb[1].inFly and #row()[2].fly == 3 and fb[3]:IsShown(), "Shift over a totem: its kind pops out", #fb)
      -- it stays open while the mouse is on it or its icon, by the frame's own IsMouseOver (Arn: "holding shift does not pop out" -
      -- the global was missing on Forever and it shut itself at once); gone = closed, after a moment's grace
      local keepMO = rawget(_G, "MouseIsOver")
      _G.MouseIsOver = nil
      local overFly, overIcon = false, true
      f.fly.IsMouseOver = function() return overFly end
      top[2].IsMouseOver = function() return overIcon end
      f.fly.scripts.OnUpdate(f.fly)
      ok(f.fly:IsShown(), "the mouse still on its icon: open, with no MouseIsOver at all")
      overIcon, overFly = false, true
      W.now = W.now + 1 f.fly.scripts.OnUpdate(f.fly)
      ok(f.fly:IsShown(), "the mouse moved up onto the pop-out: open")
      overFly = false
      f.fly.scripts.OnUpdate(f.fly)
      ok(not f.fly:IsShown() and TC.why:find("mouse left", 1, true), "the mouse off both: closed, and why says so", TC.why)
      _G.MouseIsOver, f.fly.IsMouseOver, top[2].IsMouseOver = keepMO, nil, nil
      top[2]:GetScript("OnEnter")(top[2])
      local ft
      for _, b in ipairs(fb) do if b:IsShown() and b.attrs.spell1 == "Flametongue Totem" then ft = b end end
      ok(ft, "each one there drops itself")
      ft:GetScript("PostClick")(ft, "LeftButton", false)
      ok(row()[2].word == "Flametongue" and not f.fly:IsShown(), "a click there: onto the row, the pop-out away", row()[2].word)
      W.runAfters(1)
      ok(top[2].attrs.spell1 == "Flametongue Totem", "and the card drops it now")
      top[2]:GetScript("OnLeave")(top[2])
      W.shift = false
      top[2]:GetScript("OnEnter")(top[2])
      ok(not f.fly:IsShown(), "no Shift: no pop-out")
      top[2]:GetScript("OnLeave")(top[2])
      -- Shift pressed with the mouse already on it
      top[1]:GetScript("OnEnter")(top[1])
      TC.events.scripts.OnEvent(TC.events, "MODIFIER_STATE_CHANGED", "LSHIFT", 1)
      ok(f.fly:IsShown() and fb[1].attrs.spell1 == row()[1].fly[1].act.spell, "Shift pressed over the imbue: the imbues pop out")
      -- a fight: put away before the lockdown, nothing touched in it, painted after
      TC.events.scripts.OnEvent(TC.events, "PLAYER_REGEN_DISABLED")
      ok(not f.fly:IsShown(), "a pull: the pop-out away first")
      fighting, W.combat = true, true
      top[1]:GetScript("OnEnter")(top[1])
      TC.events.scripts.OnEvent(TC.events, "MODIFIER_STATE_CHANGED", "LSHIFT", 1)
      ok(pcall(TC.Paint) and not f.fly:IsShown() and TC.late, "in a fight: nothing aimed, nothing popped out")
      fighting, W.combat = false, false
      TC.events.scripts.OnEvent(TC.events, "PLAYER_REGEN_ENABLED")
      W.runAfters(1)
      ok(TC.late == nil and f:IsShown(), "after it: painted again")
      top[1]:GetScript("OnLeave")(top[1])
      -- the deck tab on the right (Arn: "send to bis heling deck ... on the right side"): only with BiS Healing there
      local api0 = rawget(_G, "BiSHealingAPI")
      _G.BiSHealingAPI = nil
      TC.Paint()
      ok(not f.deck:IsShown(), "no BiS Healing: no deck tab")
      local got2, call2
      _G.BiSHealingAPI = { version = 4, SetTotems = function(x) got2 = x return true end, Totems = function() return got2 or {} end, SetCall = function(x) call2 = x return true end, Call = function() return call2 end }
      TC.Paint()
      ok(f.deck:IsShown() and f.deck.state.text:find("SEND", 1, true), "BiS Healing there: the deck tab, SEND", f.deck.state.text)
      f.deck.scripts.OnClick(f.deck)
      ok(got2 and got2.fire == "Flametongue Totem", "a click: the row's totems onto the healing deck", got2 and got2.fire)
      W.runAfters(1)
      ok(f.deck.state.text:find("ON", 1, true), "and then it says ON", f.deck.state.text)
      _G.BiSHealingAPI = api0
      TC.Paint()
      -- the drag: by the tab, saved; ended by a pull
      f.tab.scripts.OnDragStart(f.tab)
      ok(f.moving, "the tab drags it")
      TC.events.scripts.OnEvent(TC.events, "PLAYER_REGEN_DISABLED")
      ok(not f.moving and type(cdb.barPos) == "table", "a pull ends the drag, where it is kept")
      local Cost = dofile("../_bisdev/dev/cost.lua")
      local cost, by = Cost.Count(function() TC.Paint() end)
      print(("   cost: totem card, one paint (after a fight or a press, never on a timer) = %d calls (%s)"):format(cost, Cost.Top(by, 3)))
      ok(cost < 400, "the totem card's paint stays light", cost)
      cdb.bar, cdb.barPos = nil, nil
      TC.Paint()
      ok(not f:IsShown(), "switched off: gone")
      R:SetEnabled("combo", was)
      C.Knows = kn3
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
  fighting = true ok(T.Set(1, 1, 2) == false, "a fight: nothing is written") fighting = false
  -- secrets, and a client without it
  local S = {}
  _G.issecretvalue = function(v) return v == S end
  _G.GetActionInfo = function() return S, S end
  _G.GetMultiCastTotemSpells = function() return S, S end
  ok(T.Get(1, 1) == nil and #T.List(1) == 0, "hidden answers: no error")
  _G.issecretvalue = keep.is
  _G.SetMultiCastSpell = nil
  ok(not T.Can() and Dk.defs["BiSTools:tool-combo"].page.icons(1) == nil, "a client without it: no row, no error")
  _G.UnitClass, _G.SetMultiCastSpell, _G.GetMultiCastTotemSpells, _G.GetActionInfo, _G.GetMultiCastBarIndex, _G.C_Spell = keep.cls, keep.set, keep.list, keep.info, keep.bar, keep.sp
  C.Knows, C.TryNext, C.Rank, _G.InCombatLockdown = keep.knows, keep.try, keep.rank, keep.fight
end
