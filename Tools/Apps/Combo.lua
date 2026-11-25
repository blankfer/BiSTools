-- BiSTools / Tools / Apps / Combo.lua - BiS>totems, the combo tool in the phone (dev/APPS.md).
-- NOW = the last fight, and what to try next; BEST = the ranking, a row opens that combo's own page; FIGHTS = every fight kept.
-- All of it is Combo.lua's own: C.Rank, C.TryNext, C.StatTiles, C.SendDeck, C.ForgetAsk. The icons do not cast here yet (a cast is
-- a secure button): POP OUT has them.
local _, NS = ...
local DP, R = NS.DeckPages, NS.Registry
if not (DP and DP.App) then return end

DP.App.combo = function(tool, db)
  local C, D = NS.Combo, BiSTheme.Deck
  local ID = "BiSTools:tool-combo"
  local FRESH, MANY = 120, C.KEEP                            -- seconds a fight's card stays; as many fights as the tool keeps
  local pick                                                 -- the combo whose page is open in BEST
  local opened                                               -- NOW: the breakdown's boxes are open
  local flyImbue, flyTotems                                  -- NOW: the row's pop-outs (the imbue's, a totem's place)
  local kept = {}                                            -- what this very moment's paint already worked out

  local function int(n) return tostring(math.floor((tonumber(n) or 0) + 0.5)) end
  local function list() return db().fights or {} end
  local function last() local l = list() return l[#l] end
  local function counts(f) return C.Counts(f) end              -- (solo, and you swung: Tools/Combo.lua)
  local function dps(f) local t = C.Time(f) or 0 return t > 0 and (f.dmg or 0) / t or 0 end
  local function wall() return (time and time()) or 0 end
  local function plural(n, word) return n .. " " .. word .. (n == 1 and "" or "s") end
  -- one paint asks the same thing several times: worked out once a moment, again after a press or a new fight
  local function once(key, fn)
    local at = ("%s:%d:%s:%s"):format(tostring(GetTime and GetTime() or 0), #list(), tostring(db().lastSid), tostring(C.Min()) .. C.Scope())
    if kept.at ~= at or kept.from ~= db().fights then kept = { at = at, from = db().fights } end
    if kept[key] == nil then kept[key] = { fn() } end
    return unpack(kept[key], 1, 3)
  end
  local function rank() return (once("rank", C.Rank)) end
  local function try() return once("try", C.TryNext) end
  --- A combo's place, how many there are, and its row of the ranking.
  local function place(combo)
    local all = rank()
    for i, g in ipairs(all) do if g.combo == combo then return i, #all, g end end
    return nil, #all
  end

  -- the words: "FT, SoE, WF" = the totems in the order of their columns; beside the imbue's picture they are enough
  local function totems(imbue, names)
    local cells, out = C.Cells(imbue, names), {}
    for _, col in ipairs({ "fire", "earth", "air" }) do if cells[col] and cells[col] ~= "-" then out[#out + 1] = cells[col] end end
    return #out > 0 and table.concat(out, ", ") or "no totems"
  end
  local function short(imbue) return imbue and (C.IMBUE_SHORT[imbue] or imbue) or "no imbue" end
  local function whole(imbue, names) return short(imbue) .. " + " .. totems(imbue, names) end
  local function beside(imbue, names) return C.IconFor(imbue) and totems(imbue, names) or whole(imbue, names) end
  local function long(imbue, names)
    return (imbue or "No imbue") .. (#(names or {}) > 0 and ": " .. table.concat(names, ", ") or ", no totems")
  end

  -- one fight
  --- Your other fights: their dps (as if the mobs were your level - a harder mob does not make a fight look worse).
  local function others(f)
    local dmg, secs = 0, 0
    for _, x in ipairs(list()) do
      if x ~= f and counts(x) then dmg, secs = dmg + (x.dmg or 0) * C.AdjFactor(x.gap), secs + (C.Time(x) or 0) end
    end
    return secs > 0 and dmg / secs or nil
  end
  --- "+12%" of this fight against them, and its colour.
  local function versus(f)
    local avg = others(f)
    if not avg or avg <= 0 then return "-", "dim" end
    local k = math.floor((dps(f) * C.AdjFactor(f.gap) / avg - 1) * 100 + 0.5)
    return (k >= 0 and "+" or "") .. k .. "%", k >= 0 and "good" or "warn"
  end
  local function secs(f)
    if f.active and f.active > 0 then return int(f.active) .. " of " .. int(f.dur) .. " s swinging" end
    return int(f.dur) .. " s"
  end
  local function spells(f, n)
    local out = {}
    for i = 1, math.min(n, #(f.spells or {})) do out[i] = { f.spells[i].name, int((f.spells[i].share or 0) * 100) .. "%" } end
    return out
  end
  local function procWords(f)
    local p = f.procs
    if not p then return nil end
    local out, wf = {}, (p.extra1 or 0) + (p.extra2 or 0) + (p.more or 0)
    if wf > 0 then out[#out + 1] = wf .. " WF" end
    if (p.fire or 0) > 0 then out[#out + 1] = p.fire .. " FT" end
    if (p.frost or 0) > 0 then out[#out + 1] = p.frost .. " FB" end
    return #out > 0 and table.concat(out, ", ") or nil
  end
  local function fightTip(f)
    local out = { long(f.imbue, f.totems), int(dps(f)) .. " dps, " .. secs(f) }
    for _, s in ipairs(spells(f, 3)) do out[#out + 1] = s[1] .. " " .. s[2] end
    return table.concat(out, ". ") .. "."
  end

  -- the buttons
  local function open(combo, keepTab)
    return { word = "open", peek = true, fn = function()
      pick = combo
      if not keepTab then D.defs[ID].tab = 2 end
    end }
  end
  local function oldWindow()
    return DP.PopOut(function() C.Toggle(true) end, "The list with the icons you can click to cast, on your screen")
  end
  local function deckKey(names)
    if #(names or {}) == 0 then return nil end
    return { word = "SET DECK: " .. totems(nil, names), tip = C.DeckCan() and "These totems onto your BiS Healing deck" or C.DeckMissing(),
      fn = function() C.SendDeck(names) end }
  end
  -- it asks again: the word changes, the second press does it
  local sure = {}
  local function confirm(key, word, tip, fn)
    local function armed() return sure.key == key and (GetTime() - sure.at) <= 5 end
    return { word = armed() and "SURE?" or word, tip = tip, peek = true, fn = function()
      if armed() then
        sure, kept = {}, {}
        return fn()
      end
      sure = { key = key, at = GetTime() }
      if C_Timer and C_Timer.After then C_Timer.After(5.1, function() D.Dirty() end) end
    end }
  end

  -- NOW -------------------------------------------------------------------------------------------------------------------
  local function nowBoxes()
    local f = last()
    if not f then return {} end
    local k, n = place(f.combo)
    local vs, ink = versus(f)
    local out = { { "DPS", int(dps(f)), ink == "warn" and "gold" or "good" },
      { "PLACE", counts(f) and k and (k .. "/" .. n) or "-", k == 1 and "gold" or "ink" },
      { "VERSUS", vs, ink }, { "WF", int((f.wf or 0) * 100) .. "%", "gold" } }
    -- (the fight's numbers stand beside each other: Arn, 22 Nov - "should be boxes next to each other")
    local pw = procWords(f)
    if pw then out[#out + 1] = { "PROCS", (pw:gsub(", ", " ")), "gold" } end
    for _, s in ipairs(spells(f, pw and 3 or 4)) do
      out[#out + 1] = { (s[1] == "Attack" and "Attack" or s[1]:gsub(" Attack$", ""):gsub(" Weapon$", ""):gsub(" Totem$", "")):upper(), s[2], "ink" }
    end
    return out
  end
  --- The window's number boxes (C.StatTiles) by their label, and in their order.
  local function tiles(combo)
    local by, order = {}, {}
    for i, t in pairs((C.StatTiles(combo))) do
      by[t[1]] = t
      order[#order + 1] = { i = i, t = t }
    end
    table.sort(order, function(a, b) return a.i < b.i end)
    return by, order
  end
  local function cap(w) return w:sub(1, 1):upper() .. w:sub(2):lower() end
  --[[ THE ROW (Arn, 22 Nov, live): the imbue and the four totems you are working with, its dps huge over it, the Calls under it.
    "if i click a call of the button it sends the set up to that icon" - "if everything agrees its purple, if i go and change the healing
    totem the healing button is no longer purple and the call of the is no longer purple, now i can set it to another call of the button
    with another color" - "elements red tint, ancestors blue, spirits purple".
     - A Call has a colour. The row agrees with it = the Call and everything on the row glow in it.
     - Change one (an icon opens what fits there, in place), or put TRY / TOP / LAST on the row: what is different glows no more.
     - CHANGED, a Call's press saves the row into that Call - its totems in the game's bar, its imbue here - and drops it: all glows again.
     - UNCHANGED, another Call's press brings that Call onto the row and drops it. (Nothing is ever written over by looking.)
    What is changed is kept (db.draft = { imbue, t = { [place] = spell id or false } }) till it is saved; db.callImbue[Call] = its imbue.
    A weapon imbued by hand is followed. The fourth button is Totemic Call. ]]
  local GLOW = { "red", "rare", "accent" }                     -- (Elements, Ancestors, Spirits: the tint of their own icons)
  local GLOW_WORD = { "red", "blue", "purple" }
  local function calls() return NS.Totems and NS.Totems.Shaman() and NS.Totems.Can() and NS.Totems.Now() or nil end
  local function onNow() return not (InCombatLockdown and InCombatLockdown()) and C.ImbueNow() or nil end
  local function imbueOf(page)
    local im = type(db().callImbue) == "table" and db().callImbue[page] or nil
    return im or onNow() or (last() and last().imbue) or nil
  end
  --- What a Call holds: { imbue, t = { ids } }.
  local function held(page)
    local To, t = NS.Totems, {}
    for slot = 1, 4 do t[slot] = To.Get(page, slot) or false end
    return { imbue = imbueOf(page), t = t }
  end
  local function same(a, b)
    if a.imbue ~= b.imbue then return false end
    for slot = 1, 4 do if (a.t[slot] or false) ~= (b.t[slot] or false) then return false end end
    return true
  end
  --- The row, the Call it is compared with, is it changed.
  local function theRow()
    local page = calls()
    if not page then return nil end
    local d = db().draft
    if type(d) ~= "table" or type(d.t) ~= "table" then return held(page), page, false end
    return d, page, true
  end
  --- Agrees with a Call again (the one it came from first)? Then it is that Call, and nothing is changed.
  local function settle()
    local d, page, changed = theRow()
    if not changed then return end
    if same(d, held(page)) then db().draft = nil return end
    for _, p in ipairs(NS.Totems.Known()) do
      if same(d, held(p)) then db().draft = nil NS.Totems.Choose(p) return end
    end
  end
  local function touch(fn)
    local r = theRow()
    if not r then return end
    local d = { imbue = r.imbue, t = { r.t[1], r.t[2], r.t[3], r.t[4] } }
    fn(d)
    db().draft = d
    kept = {}
    settle()
    if C.CardSoon then C.CardSoon() end
  end
  local function setup()
    local To = NS.Totems
    local on = onNow()
    if on and on ~= db().imbueSeen then                          -- (imbued by hand: the row follows)
      local first = db().imbueSeen == nil
      db().imbueSeen = on
      local r = not first and theRow()
      if r and r.imbue ~= on then touch(function(d) d.imbue = on end) end
    end
    local r, page, changed = theRow()
    local set, names, at, im = {}, {}, {}, on or (last() and last().imbue)
    if r then
      im = r.imbue
      for slot = 1, 4 do
        local n = r.t[slot] and To.Name(r.t[slot]) or nil
        at[slot] = n and C.Base(n) or nil
        n = at[slot]
        if n and C.TOTEMS[n] and not set[n] then set[n] = true names[#names + 1] = n end
      end
    elseif last() then
      for _, n in ipairs(last().totems or {}) do set[n] = true names[#names + 1] = n end
    end
    local combo = C.Label(im, set)
    local k, n, g = place(combo)
    return { page = page, row = r, changed = changed, imbue = im, on = on, names = names, at = at, combo = combo, k = k, of = n, g = g }
  end
  local function breakdown(s)
    local out = {}
    if s.g then
      local _, order = tiles(s.combo)
      for _, x in ipairs(order) do if x.t[2] ~= "-" then out[#out + 1] = { cap(x.t[1]) .. (x.i <= 3 and " procs" or ""), x.t[2] } end end
      if s.k then table.insert(out, 1, { "Place", s.k .. " of " .. s.of }) end
    end
    local f = last()
    out[#out + 1] = { "Counted", ({ solo = "your solo fights", group = "your fights in a group", all = "all your fights" })[C.Scope()] }
    if f then
      out[#out + 1] = { " ", " " }
      if f.group then out[#out + 1] = { "The whole group", int(f.group) .. " dps, " .. (f.groupN or 0) .. " of you" } end
      out[#out + 1] = { "Last fight", (f.mob or "?") .. ", " .. secs(f) }
      for i, b in ipairs(nowBoxes()) do if b[1] ~= "PLACE" then out[#out + 1] = { i == 1 and "Its dps" or b[1] == "WF" and "Windfury damage" or cap(b[1]), b[2] } end end
    end
    return out
  end
  local function number()
    local s, f = setup(), last()
    if not (f or s.page) then return nil end
    local vs, ink
    if f then vs, ink = versus(f) end
    return { art = "number", big = s.g and int(s.g.dps) or "NEW", ink = s.g and (s.k == 1 and "gold" or "good") or "dim", small = (C.Scope() == "group" and "GROUP DPS  " or "DPS  ") .. whole(s.imbue, s.names),
      corner = f and f.grp and f.group and C.Scope() ~= "solo" and "group " .. int(f.group) or nil,
      right = f and ("last " .. int(dps(f)) .. (vs ~= "-" and "  " .. vs or "")) or "", rightInk = ink == "warn" and "warn" or ink == "good" and "good" or "ink2",
      under = s.g and (plural(s.g.n, "fight") .. (s.k and ", #" .. s.k .. " of " .. s.of or "")) or "never fought: go and fight",
      tip = long(s.imbue, s.names), lines = breakdown(s), peek = true, fn = function() opened = not opened end }
  end
  --- A Call's press, the last word before its cast: CHANGED = the row goes into it; unchanged = it comes onto the row.
  local function press(page)
    local To = NS.Totems
    local d, _, changed = theRow()
    if changed then
      local bad = 0
      for slot = 1, 4 do if not To.Set(page, slot, d.t[slot] or nil) then bad = bad + 1 end end
      if bad > 0 then
        To.said = bad .. " did not go into " .. To.CALLS[page].name .. ": click again"
        NS.Print("totems: %s", To.said)
        return false
      end
      db().callImbue = type(db().callImbue) == "table" and db().callImbue or {}
      db().callImbue[page] = d.imbue
      db().draft = nil
      To.said = "Saved in " .. To.CALLS[page].name
    else
      To.said = nil
    end
    To.Choose(page)
    kept = {}
    if C.CardSoon then C.CardSoon() end
    return true
  end
  --[[ THE BEST, AND THE ONE TO TRY (Arn, 22 Nov: "the next row first one shows the best dps set up, imbue with the totems in that data, and
    the call of the buttons in their tints. i click the call of the button and it saves the best to that call of the button" - "same
    with the try you recommend one to try and ill say 1/3 fights ... lets me set it to what ever call of the button"): its imbue and
    totems (a press casts that one), and the Calls in their colours - a press SAVES it there, and that Call is the row then. Nothing is
    cast by saving. The water totem of that Call stays (no fight's record speaks of it). ]]
  local function saveIn(page, imbue, names)
    local To = NS.Totems
    local by, bad = C.CellNames(nil, names), 0
    local water = (theRow() or {}).t
    for slot, el in pairs({ [1] = "fire", [2] = "earth", [4] = "air" }) do
      local id = by[el][1] and To.Find(slot, by[el][1]) or nil
      if (by[el][1] and not id) or not To.Set(page, slot, id) then bad = bad + 1 end
    end
    if water and water[3] and not To.Get(page, 3) then To.Set(page, 3, water[3]) end
    if bad > 0 then To.said = bad .. " did not go into " .. To.CALLS[page].name .. ": press again" return false end
    if imbue then
      db().callImbue = type(db().callImbue) == "table" and db().callImbue or {}
      db().callImbue[page] = imbue
    end
    db().draft = nil
    To.Choose(page)
    To.said = "Saved in " .. To.CALLS[page].name
    kept = {}
    return true
  end
  local function block(add, word, sub, ink, imbue, names, tip)
    local To = NS.Totems
    local by, row, saves = C.CellNames(imbue, names), {}, {}
    local function one(n, slot)
      if not n then row[#row + 1] = { word = slot and To.SLOTS[slot] or "None", done = true, tip = slot and To.SLOTS[slot] .. ": nothing" or "No imbue" } return end
      row[#row + 1] = { pic = C.IconFor(n), word = C.COL_WORD[n] or C.IMBUE_SHORT[n] or To.Short(n), tip = n .. (slot and ". Click: drops this one" or ". Click: onto your weapon"),
        act = C.Knows(n) and { word = slot and "DROP" or "IMBUE", spell = n, peek = true } or nil }
    end
    one(imbue) one(by.fire[1], 1) one(by.earth[1], 2) one(by.air[1], 4)
    for i, page in ipairs(To.Known()) do
      local has = imbueOf(page) == imbue
      for slot, el in pairs({ [1] = "fire", [2] = "earth", [4] = "air" }) do
        local id = by[el][1] and To.Find(slot, by[el][1]) or nil
        has = has and To.Get(page, slot) == id
      end
      saves[i] = { flat = true, word = cap(To.CALLS[page].tab), glow = GLOW[page] or "accent", soft = not has or nil, tip = To.CALLS[page].name .. (has and ": it is in it" or ". Click: saves it there"),
        act = { word = "SAVE", peek = true, fn = function() saveIn(page, imbue, names) end } }
    end
    add({ text = word, sub = sub, ink = ink, tip = tip, icons = row })
    add({ text = "", sub = "save in", ink = "dim", icons = saves, low = true, tip = "Saves it in that Call; nothing is cast" })
  end
  --- WHAT FITS THERE, POPPED OUT OVER IT (Arn, 22 Nov: "if i click a totem let me select another fire totem dont send me to another
  --- app"; 23 Nov, the game's own totem bar: "make it pop out like this to select another one in the first row" - "imbue too"): the
  --- kit's pop-out (BiSTheme Deck minor 2, `fly`), a column of icons over the one clicked; a press puts that one on the row.
  function flyImbue(s)
    local out = {}
    for _, n in ipairs(C.TRY.imbue) do
      if C.Knows(n) then
        out[#out + 1] = { pic = C.IconFor(n), word = NS.Totems.Short(n), lit = n == s.imbue or nil, glow = n == s.on and "good" or nil,
          tip = n .. (n == s.on and ": on your weapon" or "") .. ". Click: onto your weapon and the row",
          act = { word = "IMBUE", spell = n, peek = true, ok = function() touch(function(d) d.imbue = n end) return true end } }
      end
    end
    return out
  end
  function flyTotems(s, at)
    local To, out, now = NS.Totems, {}, s.row.t[at]
    for _, id in ipairs(To.List(at)) do
      local name = C.Base(To.Name(id)) or "?"
      out[#out + 1] = { pic = To.Icon(id), word = To.Short(name), lit = id == now or nil, tip = name .. (id == now and ": on the row" or ". Click: onto the row"),
        cast = C.Knows(name) and name or nil,                -- (the totem card drops it too; the phone only puts it on the row)
        act = { word = "put", peek = true, fn = function() touch(function(d) d.t[at] = id end) end } }
    end
    out[#out + 1] = { word = "None", done = true, lit = not now or nil, tip = "No " .. To.SLOTS[at]:lower() .. " totem on the row",
      act = { word = "put", peek = true, fn = function() touch(function(d) d.t[at] = false end) end } }
    return out
  end
  local function icons()
    local s = setup()
    if not s.page then return nil end
    local To = NS.Totems
    local row, list, ref = {}, {}, held(s.page)
    local glow = GLOW[s.page] or "accent"
    local there = s.imbue ~= nil and s.on == s.imbue
    row[1] = { pic = C.IconFor(s.imbue), word = s.imbue and To.Short(s.imbue) or "No imbue", done = s.imbue == nil, ink = not there and "warn" or nil,
      glow = s.imbue and s.imbue == ref.imbue and glow or nil,
      tip = (s.imbue and (s.imbue .. (there and ": on your weapon" or ": not on your weapon yet")) or "No imbue") .. ". Click: choose one",
      flyKey = "imbue", fly = flyImbue(s), cast = s.imbue and C.Knows(s.imbue) and s.imbue or nil }
    for slot = 1, 4 do
      local n, id = s.at[slot], s.row.t[slot]
      row[slot + 1] = { pic = n and (To.Icon(id) or C.IconFor(n)) or nil, word = n and To.Short(n) or To.SLOTS[slot], done = n == nil,
        glow = (id or false) == ref.t[slot] and n and glow or nil, tip = To.SLOTS[slot] .. ": " .. (n or "nothing") .. ". Click: choose another",
        flyKey = "slot" .. slot, fly = flyTotems(s, slot), cast = n and C.Knows(n) and n or nil }
    end
    for i, page in ipairs(To.Known()) do
      local c = To.CALLS[page]
      local is = not s.changed and page == s.page
      list[i] = { pic = C.IconFor(c.name) or To.Icon(c.id), word = cap(c.tab), glow = is and (GLOW[page] or "accent") or nil,
        tip = c.name .. (s.changed and ". Click: the row is saved in it, and drops" or is and ". The row is this one. Click: drops it" or ". Click: onto the row, and drops it"),
        act = { word = "DROP", spell = c.name, peek = true, ok = function() return press(page) end } }
    end
    if C.Knows(To.BRING) then list[#list + 1] = { pic = C.IconFor(To.BRING), word = "Bring", tip = To.BRING .. ": the ones that stand come to you", act = { word = "BRING", spell = To.BRING, peek = true } } end
    if C.Knows(To.RECALL) then list[#list + 1] = { pic = C.IconFor(To.RECALL), word = "Recall", tip = To.RECALL .. ": takes your totems back, and some of their mana", act = { word = "RECALL", spell = To.RECALL, peek = true } } end
    return { row, list }
  end
  --- THE LAST ROW (Arn, 22 Nov: "the last row should be like update healing deck click and it sets my healing deck row out of combat so i
  --- can drop during combat"): the row's four totems onto BiS Healing's deck, and its CALL button on the row's Call.
  local function deckRow()
    local s, To = setup(), NS.Totems
    local set, same = {}, C.DeckCan()
    local has
    if same then local fine, h = pcall(BiSHealingAPI.Totems) has = fine and type(h) == "table" and h or {} end
    for slot, el in ipairs({ "fire", "earth", "water", "air" }) do
      set[el] = s.at[slot] or false
      if same and (C.Base(has[el]) or false) ~= set[el] then same = false end
    end
    local call = not s.changed and To.CALLS[s.page].name or nil
    if same and call and type(BiSHealingAPI.Call) == "function" then local fine, c = pcall(BiSHealingAPI.Call) same = fine and c == call end
    return { pic = "Interface\\Icons\\Spell_Nature_HealingWaveGreater", text = "Update healing deck", verb = same and "IS ON IT" or "UPDATE", verbInk = same and "good" or "gold",
      tip = C.DeckCan() and "These four totems onto BiS Healing's deck, to drop in a fight" or C.DeckMissing(),
      act = { word = "UPDATE", peek = true, fn = function() local _, why = C.SendRow(set, call) To.said = why end } }
  end
  --- What the row is, in words (a colour is never the only sign).
  local function rowSays()
    local s = setup()
    if not s.page then return nil end
    if NS.Totems.said then return NS.Totems.said end
    if s.changed then return "Changed. Press a Call: the row is saved in it, and drops" end
    return "The row is " .. NS.Totems.CALLS[s.page].name .. " (" .. (GLOW_WORD[s.page] or "lit") .. ")"
  end
  local function nowRows()
    local out, f = {}, last()
    local function add(row) out[#out + 1] = row end
    local c, total, untried = try()
    if calls() then
      local top = rank()[1]
      if top then block(add, "BEST " .. int(top.dps), plural(top.n, "fight"), "good", top.imbue, top.totems, "Your best. " .. long(top.imbue, top.totems) .. ", " .. int(top.dps) .. " dps") end
      if c then block(add, "TRY", c.n .. "/" .. C.TRY_ENOUGH .. " fights", "gold", c.imbue, c.totems, "Try next. " .. long(c.imbue, c.totems) .. ". " .. (untried or 0) .. " of " .. (total or 0) .. " combos never tried.") end
      add(deckRow())
      return out
    end
    if f then
      add({ pic = C.IconFor(f.imbue), mark = "-", text = "Last: " .. beside(f.imbue, f.totems), right = f.mixed and "MIXED" or "", ink = "gold", tip = fightTip(f), verb = "OPEN", act = open(f.combo) })
    end
    if c then
      add({ pic = C.IconFor(c.imbue), mark = ">", text = "Try: " .. beside(c.imbue, c.totems), sub = c.n == 0 and "never fought" or plural(c.n, "fight") .. " so far",
        tip = "Try next. " .. long(c.imbue, c.totems) .. ". " .. (untried or 0) .. " of " .. (total or 0) .. " combos never tried." })
    elseif total then
      add({ mark = ">", text = "Every combo is tried", right = C.TRY_ENOUGH .. "+ each", ink = "good", tip = "Each has enough fights: the ranking holds" })
    end
    if not (InCombatLockdown and InCombatLockdown()) then
      local im, up = C.ImbueNow(), C.ScanTotems({})
      local names = {}
      for n in pairs(up) do names[#names + 1] = n end
      table.sort(names)
      if im or #names > 0 then
        local k, n = place(C.Label(im, up))
        add({ pic = C.IconFor(im), mark = "=", text = "Up now: " .. beside(im, names), right = k and (k .. "/" .. n) or "",
          tip = "On you now. " .. long(im, names) .. "." })
      end
    end
    return out
  end

  -- BEST ------------------------------------------------------------------------------------------------------------------
  local function bestBoxes()
    local all = rank()
    if #all == 0 then return {} end
    local crit = tiles(nil).CRIT
    return { { "COMBOS", #all, "accent" }, { "FIGHTS", (C.CountKept()), "ink" }, { "BEST", int(all[1].adj), "gold" }, { "CRIT", crit and crit[2] or "-", "good" } }
  end
  local function bestRows()
    local out = {}
    for i, g in ipairs(rank()) do
      out[i] = { pic = C.IconFor(g.imbue), mark = tostring(i), text = beside(g.imbue, g.totems), right = int(g.adj) .. " (" .. g.n .. ")", ink = i == 1 and "gold" or g.n >= C.SURE and "good" or "dim",
        act = open(g.combo, true), tip = "#" .. i .. ". " .. long(g.imbue, g.totems) .. ". " .. plural(g.n, "fight") .. ", " .. int(g.dps) .. " dps, "
          .. int(g.adj) .. " as if the mobs were your level." }
    end
    return out
  end
  local function comboBoxes()
    local by = tiles(pick)
    local function box(label, key, ink) return { label, by[key] and by[key][2] or "-", ink } end
    return { box("FIGHTS", "FIGHTS"), box("AVERAGE", "AVERAGE", "good"), box("BEST", "BEST", "gold"), box("WF", "WINDFURY", "gold") }
  end
  local SMALL = { FLAMETONGUE = "Flametongue procs", FROSTBRAND = "Frostbrand procs", SWINGS = "Swings counted", ["MOB LEVEL"] = "Mobs against you",
    CRIT = "Your crit now", ["ATTACK POWER"] = "Your attack power", WEAPON = "Your weapon", DAMAGE = "Its damage" }
  local function comboRows()
    local k, n, g = place(pick)
    local out = { { mark = "<", text = "All combos", act = { word = "back", peek = true, fn = function() pick = nil end } } }
    if g then
      out[2] = { pic = C.IconFor(g.imbue), mark = "#", text = beside(g.imbue, g.totems), right = "#" .. k .. " of " .. n, ink = k == 1 and "gold" or "ink2",
        tip = long(g.imbue, g.totems) }
    end
    if g and calls() then block(function(r) out[#out + 1] = r end, "THIS ONE", "save it", "gold", g.imbue, g.totems, long(g.imbue, g.totems)) end
    local _, order = tiles(pick)
    for _, x in ipairs(order) do
      local t = x.t
      if SMALL[t[1]] and t[2] ~= "-" then
        out[#out + 1] = { mark = "-", text = SMALL[t[1]], right = t[2], ink = "gold", tip = t[4] and table.concat(t[4], ". ") or nil }
      end
    end
    local l, shown = list(), 0
    for i = #l, 1, -1 do
      local f = l[i]
      if f.combo == pick and shown < MANY then
        shown = shown + 1
        out[#out + 1] = { pic = C.IconFor(f.imbue), mark = "x", text = f.mob or "?", sub = secs(f) .. (f.grp and ", group" or ""), right = int(dps(f)), ink = counts(f) and "good" or "dim", done = not counts(f), tip = fightTip(f) }
      end
    end
    return out
  end
  --- Is one combo's page open (its fights may be gone: then it is not)?
  local function inCombo(tab)
    if pick then
      local has = false
      for _, f in ipairs(list()) do if f.combo == pick then has = true break end end
      if not has then pick = nil end
    end
    return tab == 2 and pick ~= nil
  end

  -- FIGHTS ----------------------------------------------------------------------------------------------------------------
  local function fightBoxes()
    local l = list()
    if #l == 0 then return {} end
    local best, all = 0, 0
    for _, f in ipairs(l) do all = all + (f.dur or 0) if counts(f) then best = math.max(best, dps(f)) end end
    local avg = others(nil)
    return { { "COUNT", (C.CountKept()), "accent" }, { "AVERAGE", avg and int(avg) or "-", "good" }, { "BEST", int(best), "gold" },
      { "TIME", all >= 3600 and ("%.1f h"):format(all / 3600) or (math.floor(all / 60) .. " m"), "ink2" } }
  end
  local function fightRows()
    local out, l = {}, list()
    for i = #l, math.max(1, #l - MANY + 1), -1 do
      local f = l[i]
      -- (the colour pass, 22 Nov: how long, mixed, group under the name instead of glued onto it)
      out[#out + 1] = { pic = C.IconFor(f.imbue), mark = "-", text = f.mob or "?", sub = secs(f) .. (f.mixed and ", mixed set-ups" or "") .. (f.grp and ", group" or ""), right = int(dps(f)),
        ink = counts(f) and "good" or "dim", done = not counts(f), tip = fightTip(f), act = open(f.combo) }
    end
    return out
  end

  -- the deck paints when it is told: a fight was just read (Combo.lua calls C.Close by its name, 1.5 s after the fight)
  local close = C.Close
  C.Close = function(...)
    local rec = close(...)
    if rec and D then D.Dirty() end                          -- (a flag: nothing is drawn while nothing is shown)
    if rec and C.CardSoon then C.CardSoon() end              -- (the totem card's small dps line, after each fight)
    return rec
  end

  -- THE ROW, FOR THE TOTEM CARD (Arn, 23 Nov: "it can just get the info from the phone"): Tools/TotemCard.lua draws these.
  C.Phone = { icons = icons, number = number, deck = deckRow }
  if C.CardSoon then C.CardSoon() end
  return {
    name = "Totems", art = "Interface\\Icons\\Spell_Nature_EarthBindTotem",
    card = {
      prio = function(out)
        local f = R:Enabled("combo") and last() or nil
        if not f or not counts(f) then return nil end
        if wall() - (f.at or 0) <= FRESH then return 6 end
        return out and 2 or nil
      end,
      lines = function()
        local f = last()
        if not f then return nil end
        local k, n, g = place(f.combo)
        local vs, ink = versus(f)
        local ranked = counts(f) and k
        return { "TOTEMS", "", (ranked and "#" .. k .. " " or "") .. short(f.imbue) .. ", " .. totems(f.imbue, f.totems),
          int(dps(f)) .. " dps", ink == "warn" and "gold" or "good", hot = ranked == 1 and n > 1,
          list = { { "Place", ranked and (k .. " of " .. n) or "too short" }, { "Against your average", vs }, { "This combo's average", g and int(g.dps) or "-" } } }
      end,
      buttons = function()
        local out = { { word = "OPEN", peek = true, fn = function() D.defs[ID].tab = 1 D.Open(ID) end } }
        local c = try()
        if c and #c.totems > 0 and C.DeckCan() then
          out[2] = { word = "SET DECK", tip = "Try next, onto your BiS Healing deck: " .. totems(nil, c.totems), fn = function() C.SendDeck(c.totems) end }
        end
        return out
      end,
    },
    page = {
      tour = { { text = "Fight with an imbue and totems up: each fight lands here, and the best combo rises to the top.",
        note = "BEST: press a combo for its numbers." },
        { text = "Try: what you have fought with least.", note = "SET DECK sends its totems to BiS Healing." } },
      title = function() return "BiS>totems" end,              -- (Arn, 22 Nov: "instead of combo we call this BiS>totems")
      kicker = function() return "imbue + totems" end,
      tabs = function() return { "NOW", "BEST", "FIGHTS" } end,
      boxes = function(tab)
        if tab == 1 then return opened and nowBoxes() or {} end
        if tab == 3 then return fightBoxes() end
        return inCombo(tab) and comboBoxes() or bestBoxes()
      end,
      hero = function(tab) return tab == 1 and number() or nil end,
      icons = function(tab) return tab == 1 and icons() or nil end,
      rows = function(tab)
        if tab == 1 then return nowRows() end
        if tab == 3 then return fightRows() end
        return inCombo(tab) and comboRows() or bestRows()
      end,
      text = function(tab)
        if #list() > 0 then return nil end
        if tab == 1 and setup().page then return nil end
        if tab == 1 then return "No fight yet. Put an imbue on your weapon, drop your totems and fight: the result comes here." end
        return "No fight yet. Each one is kept here once you have fought."
      end,
      say = function(tab)
        local f = last()
        if tab == 1 and calls() then return rowSays() end
        if not f then return C.lastWhy end
        if tab == 1 then return (f.grp and C.Scope() == "solo" and "In a group: not counted. " or "") .. secs(f) .. (f.mob and ", " .. f.mob or "") end
        if tab == 2 and not inCombo(tab) then return "dps as if the mobs were your level (fights)" end
        if tab == 3 and C.Min() > 0 then return "fights under " .. C.Min() .. " s are not ranked" end
        if tab == 3 then local _, g = C.CountKept() if g > 0 then return g .. " with others: kept, not counted" end end
        return "dps over the time you swing"
      end,
      big = function(tab)
        if tab == 1 then
          local c, To = try(), NS.Totems
          if To and To.Shaman() and To.Can() and To.Now() then return nil end       -- (the Calls' icons drop them)
          return c and deckKey(c.totems) or nil
        elseif inCombo(tab) then
          local _, _, g = place(pick)
          return g and not calls() and deckKey(g.totems) or nil
        end
      end,
      keys = function(tab)
        local out = {}
        if tab == 1 then
          local c = try()
          if calls() then return {} end                          -- (the icons are the buttons there)
          if c and c.imbue then out[1] = { word = "IMBUE " .. short(c.imbue), spell = c.imbue, peek = true } end
        elseif inCombo(tab) then
          local combo = pick
          out[1] = { word = C.Armed(combo) and "SURE?" or "FORGET", peek = true, tip = "Forget every fight with this combo", fn = function()
            kept = {}
            C.ForgetAsk(combo)
            if C_Timer and C_Timer.After then C_Timer.After(C.FORGET_ARM + 0.2, function() D.Dirty() end) end
          end }
        elseif tab == 3 and #list() > 0 then
          out[1] = confirm("all", "FORGET ALL", "Every fight kept, gone", function() tool.OnSlash(tool, db(), "forget") end)
        end
        out[#out + 1] = oldWindow()
        return out
      end,
    },
  }
end
