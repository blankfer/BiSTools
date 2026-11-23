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
      -- the client's secure handlers, as far as the card uses them (WrapScript, frame refs, a state driver): recorded, run below
      local keepCF, keepRef, keepRSD, keepWS = _G.CreateFrame, rawget(_G, "SecureHandlerSetFrameRef"), rawget(_G, "RegisterStateDriver"), rawget(_G, "SecureHandlerWrapScript")
      local wrapped, drivers = {}, {}
      _G.SecureHandlerWrapScript = function(b, script, header, pre, post)
        assert(header == TC.header, "wrapped by the card's header")
        wrapped[#wrapped + 1] = { b = b, script = script, pre = pre, post = post }
      end
      _G.SecureHandlerSetFrameRef = function(b, k, to) b.refs = b.refs or {} b.refs[k] = to end
      _G.RegisterStateDriver = function(fr, state, cond) drivers[#drivers + 1] = { fr = fr, state = state, cond = cond } end
      -- a snippet runs as the game runs it: `self` a handle (Show/Hide legal in a fight), refs, the mouse, [combat] and Shift
      local function handle(fr)
        if not fr then return nil end
        return { Show = function() fr.shown = true end, Hide = function() fr.shown = false end, IsShown = function() return fr.shown end,
          IsVisible = function() return fr.shown end, IsUnderMouse = function() return fr.under and true or false end,
          GetFrameRef = function(_, k) return handle(fr.refs and fr.refs[k]) end,
          SetAttribute = function(_, k, v) fr.attrs[k] = v end, GetAttribute = function(_, k) return fr.attrs[k] end }
      end
      local function snip(code, fr, newstate, down)
        local fn = assert(loadstring(code))
        setfenv(fn, { self = handle(fr), newstate = newstate, down = down, PlayerInCombat = function() return W.combat and true or false end,
          IsShiftKeyDown = function() return W.shift and true or false end })
        return fn()
      end
      local function wrapOf(b, script) for _, w in ipairs(wrapped) do if w.b == b and w.script == script then return w end end end
      cdb.bar = nil
      TC.Paint()
      ok(not (TC.frame and TC.frame:IsShown()), "off until switched on")
      cdb.bar = true
      moment()
      ok(TC.Paint() and TC.frame:IsShown(), "switched on: shown")
      local f = TC.frame
      local top, low = f.top, f.low
      ok(top[1]:IsShown() and top[5]:IsShown() and top[2].attrs["*type1"] == "spell" and top[2].attrs["*spell1"] == row()[2].cast and row()[2].cast ~= nil,
        "the top row: the imbue and four totems, a click drops the one there", top[2].attrs["*spell1"])
      ok(low[1].attrs["*spell1"] == "Call of the Elements" and low[2].attrs["*spell1"] == "Call of the Spirits", "under it the Calls, each casts", low[2].attrs["*spell1"])
      ok(f.tab and f.tab.num.text and f.tab.num.text ~= "" and f.tab.dps.text:find("dps", 1, true), "the dps number on its tab", f.tab.num.text)
      ok(f.w > TC.TAB + 5 * TC.SIZE and f.h >= 2 * TC.SIZE and f.h < 3 * TC.SIZE, "two rows, the size of a bar", f.w .. "x" .. f.h)
      -- a Call clicked: the row goes into it first (the phone's own ok)
      local saved
      local okFn = top[1].item and low[1].item.act.ok
      low[1].item.act.ok = function() saved = true return true end
      low[1]:GetScript("PreClick")(low[1], "LeftButton")
      ok(saved and low[1].attrs["*type1"] == "spell", "a Call's click: the phone's own word first, then it casts")
      low[1].item.act.ok = function() return false end
      low[1]:GetScript("PreClick")(low[1], "LeftButton")
      ok(low[1].attrs["*type1"] == nil, "the phone says no: nothing is cast that click")
      low[1].item.act.ok = okFn
      TC.Paint()
      -- Shift over a totem: the others pop out; a click there drops it and puts it on the row
      ok(TC.secure == "ready" and TC.header and f.cols[2] and not f.cols[2]:IsShown() and #f.cols[2].b == 3 and f.cols[1].b[1],
        "every icon's pop-out built and aimed before it is wanted, hidden", tostring(TC.secure))
      W.shift = true
      top[2]:GetScript("OnEnter")(top[2])
      local col = f.cols[2]
      local fb = col.b
      ok(col:IsShown() and fb[1]:IsShown() and fb[1].inFly and #row()[2].fly == 3 and fb[3]:IsShown() and not f.cols[1]:IsShown(), "Shift over a totem: its kind pops out", #fb)
      f.fly = col
      -- it stays open while the mouse is on it or its icon, by the frame's own IsMouseOver (Arn: "holding shift does not pop out" -
      -- the global was missing on Forever and it shut itself at once); gone = closed, after a moment's grace
      local keepMO = rawget(_G, "MouseIsOver")
      _G.MouseIsOver = nil
      local overFly, overIcon = false, true
      f.fly.IsMouseOver = function() return overFly end
      top[2].IsMouseOver = function() return overIcon end
      local watch = TC.watch
      ok(watch:IsShown(), "out of a fight its watcher looks at the mouse while it is open")
      watch.scripts.OnUpdate(watch)
      ok(f.fly:IsShown(), "the mouse still on its icon: open, with no MouseIsOver at all")
      overIcon, overFly = false, true
      W.now = W.now + 1 watch.scripts.OnUpdate(watch)
      ok(f.fly:IsShown(), "the mouse moved up onto the pop-out: open")
      overFly = false
      watch.scripts.OnUpdate(watch)
      ok(f.fly:IsShown(), "one frame off it (the gap between icon and column): still open")
      overFly = true W.now = W.now + 0.1 watch.scripts.OnUpdate(watch)
      overFly = false W.now = W.now + 0.2 watch.scripts.OnUpdate(watch)
      ok(f.fly:IsShown(), "back on it in between: the wait starts again")
      W.now = W.now + TC.OFF + 0.01 watch.scripts.OnUpdate(watch)
      ok(not f.fly:IsShown() and TC.why:find("mouse left", 1, true), "off both for a moment: closed, and why says so", TC.why)
      _G.MouseIsOver, f.fly.IsMouseOver, top[2].IsMouseOver = keepMO, nil, nil
      top[2]:GetScript("OnEnter")(top[2])
      local ft
      for _, b in ipairs(fb) do if b:IsShown() and b.attrs["*spell1"] == "Flametongue Totem" then ft = b end end
      ok(ft, "each one there drops itself")
      ok(TC.Tip(ft):find("Click: drops it, onto the row", 1, true) and not TC.Tip(ft):find("Click: onto the row$"), "its words say what a click does on the card", TC.Tip(ft))
      ok(TC.Tip(top[2]):find("Click: drops it$") and not TC.Tip(top[2]):find("choose another", 1, true), "and the row's icon too", TC.Tip(top[2]))
      ft:GetScript("PostClick")(ft, "LeftButton", false)
      ok(row()[2].word == "Flametongue" and not f.fly:IsShown(), "a click there: onto the row, the pop-out away", row()[2].word)
      W.runAfters(1)
      ok(top[2].attrs["*spell1"] == "Flametongue Totem", "and the card drops it now")
      top[2]:GetScript("OnLeave")(top[2])
      W.shift = false
      top[2]:GetScript("OnEnter")(top[2])
      ok(not f.fly:IsShown(), "no Shift: no pop-out")
      top[2]:GetScript("OnLeave")(top[2])
      -- Shift pressed with the mouse already on it
      top[1]:GetScript("OnEnter")(top[1])
      TC.events.scripts.OnEvent(TC.events, "MODIFIER_STATE_CHANGED", "LSHIFT", 1)
      ok(f.cols[1]:IsShown() and f.cols[1].b[1].attrs["*spell1"] == row()[1].fly[1].act.spell, "Shift pressed over the imbue: the imbues pop out")
      top[1]:GetScript("OnLeave")(top[1])
      -- out of a fight the snippets stand aside (the plain code does it)
      W.shift = true
      TC.CloseFly()
      snip(TC.SNIP_ENTER, top[2])
      ok(not col:IsShown(), "out of a fight: the snippets stand aside")
      -- A FIGHT (Arn: "how is blizz able to pop them out during a fight" - "yes build it"): put away before the lockdown...
      TC.events.scripts.OnEvent(TC.events, "PLAYER_REGEN_DISABLED")
      ok(not col:IsShown() and not f.cols[1]:IsShown(), "a pull: the pop-outs away first")
      fighting, W.combat = true, true
      ok(pcall(TC.Paint) and TC.late, "in a fight the plain code touches nothing")
      -- ...and the game's own snippets do it: wrapped on every top icon and every pop-out icon
      ok(wrapOf(top[2], "OnEnter") and wrapOf(top[2], "OnLeave") and wrapOf(fb[1], "OnLeave") and wrapOf(fb[1], "OnClick") and wrapOf(fb[1], "OnClick").post,
        "the snippets wrapped: Shift-over, mouse-off, the pick")
      ok(top[2].refs.fly == col and fb[1].refs.src == top[2] and fb[1].refs.fly == col and TC.header.refs.top2 == top[2] and TC.header.refs.fly2 == col,
        "each knows its column and its icon")
      W.shift = false
      snip(TC.SNIP_ENTER, top[2])
      ok(not col:IsShown(), "in a fight, no Shift: nothing")
      W.shift = true
      snip(TC.SNIP_ENTER, top[2])
      ok(col:IsShown(), "in a fight, Shift over a totem: its column")
      top[2].under, col.under = false, true
      snip(TC.SNIP_LEAVE, top[2])
      ok(col:IsShown(), "the mouse up onto the column: open")
      local pick
      for _, b in ipairs(fb) do if b:IsShown() and b.attrs["*spell1"] == "Magma Totem" then pick = b end end
      ok(pick, "Magma there, aimed before the pull")
      local _, msgDown = snip(TC.SNIP_PICK, pick, nil, true)
      ok(top[2].attrs["*spell1"] == "Magma Totem" and top[2].attrs["*type1"] == "spell" and msgDown == nil, "a pick in a fight: the row's icon now drops Magma; the column stays for the mouse coming up", top[2].attrs["*spell1"])
      local _, msg = snip(TC.SNIP_PICK, pick, nil, false)
      ok(msg, "the mouse up: now the column may close")
      snip(TC.SNIP_PICKED, pick)
      ok(not col:IsShown(), "and the column closes after the cast")
      pick:GetScript("PostClick")(pick, "LeftButton", false)
      ok(top[2].pic.file == pick.item.pic and pick.item.pic ~= nil, "its picture onto the row at once", tostring(top[2].pic.file))
      ok(TC.queue and TC.queue[1] == pick.item and row()[2].word == "Flametongue", "the phone hears of it after the fight, not now")
      -- Shift pressed with the mouse already on it: the state driver
      local dr
      for _, x in ipairs(drivers) do if x.fr == TC.header and x.state == "shift" then dr = x end end
      ok(dr and dr.cond:find("mod:shift", 1, true) and TC.header.attrs["_onstate-shift"] == TC.SNIP_SHIFT, "a state driver on Shift, its snippet on the header")
      top[1].under = true
      snip(TC.SNIP_SHIFT, TC.header, "down")
      ok(f.cols[1]:IsShown() and not col:IsShown(), "Shift pressed with the mouse on the imbue: the imbues")
      top[1].under, f.cols[1].under = false, false
      snip(TC.SNIP_LEAVE, top[1])
      ok(not f.cols[1]:IsShown(), "the mouse off both: closed")
      fighting, W.combat = false, false
      TC.events.scripts.OnEvent(TC.events, "PLAYER_REGEN_ENABLED")
      W.runAfters(1)
      ok(TC.late == nil and f:IsShown() and TC.queue == nil and row()[2].word == "Magma" and top[2].attrs["*spell1"] == "Magma Totem",
        "after it: the fight's pick onto the phone's row, painted again", row()[2].word)
      W.shift = false
      _G.CreateFrame, _G.SecureHandlerSetFrameRef, _G.RegisterStateDriver, _G.SecureHandlerWrapScript = keepCF, keepRef, keepRSD, keepWS
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
      ok(got2 and got2.fire == "Magma Totem", "a click: the row's totems onto the healing deck (Magma, picked in the fight)", got2 and got2.fire)
      W.runAfters(1)
      ok(f.deck.state.text:find("ON", 1, true), "and then it says ON", f.deck.state.text)
      _G.BiSHealingAPI = api0
      TC.Paint()
      -- THE WHEEL PICKS A RANK (Arn: "scroll wheel up to select a rank" - "yes build the wheel ranks on the card"): your ranks from
      -- your spellbook; the card casts the one picked, by its id; the Calls stay newest
      do
        local keepSB, keepEnum = rawget(_G, "C_SpellBook"), rawget(_G, "Enum")
        NAME[20], NAME[21] = "Magma Totem", "Magma Totem"
        local book = { 3, 20, 21, 5 }                         -- (Strength of Earth, Magma 1, Magma 2, Mana Spring - as the spellbook lists them)
        _G.C_SpellBook = { GetNumSpellBookSkillLines = function() return 1 end, GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #book } end,
          GetSpellBookItemInfo = function(i) return book[i] and { spellID = book[i] } end }
        local sp1 = _G.C_Spell
        _G.C_Spell = setmetatable({ GetSpellSubtext = function(id) return ({ [20] = "Rank 1", [21] = "Rank 2" })[id] end }, { __index = sp1 })
        TC.rankCache = nil
        cdb.barRank = nil
        local mag = TC.Ranks("Magma Totem")
        ok(#mag == 2 and mag[1].id == 20 and mag[2].id == 21 and mag[2].rank == 2, "your Magma ranks, read from your spellbook, lowest first", #mag)
        TC.Paint()
        ok(top[2].attrs["*spell1"] == 21 and top[2].rank.text == "", "the newest by default, by its id; no rank word", tostring(top[2].attrs["*spell1"]))
        top[2].scripts.OnMouseWheel(top[2], -1)
        ok(cdb.barRank["Magma Totem"] == 1 and top[2].attrs["*spell1"] == 20 and top[2].rank.text:find("R1", 1, true), "the wheel down: rank 1, R1 on the icon", top[2].rank.text)
        top[2].scripts.OnMouseWheel(top[2], -1)
        ok(top[2].attrs["*spell1"] == 20, "no lower than your lowest")
        TC.Paint()
        ok(top[2].attrs["*spell1"] == 20, "kept through a paint")
        W.combat, fighting = true, true
        top[2].scripts.OnMouseWheel(top[2], 1)
        ok(top[2].attrs["*spell1"] == 20 and TC.why:find("not in a fight", 1, true), "in a fight: the rank stays")
        W.combat, fighting = false, false
        top[2].scripts.OnMouseWheel(top[2], 1)
        ok(cdb.barRank["Magma Totem"] == nil and top[2].attrs["*spell1"] == 21, "the wheel up: the newest again")
        TC.events.scripts.OnEvent(TC.events, "SPELLS_CHANGED")
        ok(TC.rankCache == nil, "your spells change: read again")
        _G.C_SpellBook, _G.C_Spell = keepSB, sp1
        NAME[20], NAME[21] = nil, nil
        TC.rankCache = nil
        TC.Paint()
        ok(top[2].attrs["*spell1"] == "Magma Totem", "no spellbook answer: by its name, as before", tostring(top[2].attrs["*spell1"]))
      end
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
  -- NEWEST RANKS (Arn, 23 Nov: "i just leveled and the totems did not update to the newest ranks")
  do
    local kn4 = C.Knows
    C.Knows = function(n) return n == "Call of the Elements" or n == "Call of the Spirits" end
    NAME[8] = "Flametongue Totem III"
    at[133], at[141] = 1, 1                                  -- (Flametongue II in both Calls)
    local said = {}
    local keepP = H.NS.Print
    H.NS.Print = function(f, ...) said[#said + 1] = f:format(...) end
    ok(T.Upgrade() == 0 and at[133] == 1, "nothing newer offered: left alone")
    FITS[1] = { 1, 2, 8 }                                    -- (a level: the bar offers rank III now)
    fighting = true
    ok(T.Upgrade() == 0 and at[133] == 1 and T.upLate, "in a fight: waits")
    fighting = false
    T.upEvents.scripts.OnEvent(T.upEvents, "PLAYER_REGEN_ENABLED")
    W.runAfters(T.UP_WAIT + 0.1)
    ok(at[133] == 8 and at[141] == 8 and T.upN == 2 and said[1] and said[1]:find("2 moved up", 1, true), "after it: both Calls' Flametongue to rank III, and said", said[1])
    ok(at[134] == 3 and at[144] == 6, "the others untouched")
    -- the bar may list the newest first: the rank the game names decides
    local sp0 = _G.C_Spell
    _G.C_Spell = setmetatable({ GetSpellSubtext = function(id) return ({ [1] = "Rank 2", [8] = "Rank 3" })[id] end }, { __index = sp0 })
    FITS[1] = { 8, 2, 1 }
    ok(T.Find(1, "Flametongue Totem") == 8, "newest listed first: still rank 3")
    _G.C_Spell = sp0
    FITS[1] = { 1, 2, 8 }
    T.upEvents.scripts.OnEvent(T.upEvents, "PLAYER_LEVEL_UP")
    W.runAfters(3.1)
    ok(T.upN == 0, "a level with nothing newer: nothing")
    local Cost = dofile("../_bisdev/dev/cost.lua")
    local cost, by = Cost.Count(function() T.Upgrade() end)
    print(("   cost: totems to the newest rank, one look (after a level / a spell change) = %d calls (%s)"):format(cost, Cost.Top(by, 3)))
    ok(cost < 300, "one look stays light", cost)
    H.NS.Print, C.Knows = keepP, kn4
    FITS[1] = { 1, 2 } NAME[8] = nil
    at[133], at[141] = 1, 2
  end
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
