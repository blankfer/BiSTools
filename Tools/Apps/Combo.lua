-- BiSTools / Tools / Apps / Combo.lua - the tool in the phone (dev/APPS.md).
-- NOW = the last fight, and what to try next; BEST = the ranking, a row opens that combo's own page; FIGHTS = every fight kept.
-- All of it is Combo.lua's own: C.Rank, C.TryNext, C.StatTiles, C.SendDeck, C.ForgetAsk. The icons do not cast here yet (a cast is
-- a secure button): OLD WINDOW has them.
local _, NS = ...
local DP, R = NS.DeckPages, NS.Registry
if not (DP and DP.App) then return end

DP.App.combo = function(tool, db)
  local C, D = NS.Combo, BiSTheme.Deck
  local ID = "BiSTools:tool-combo"
  local FRESH, MANY = 120, C.KEEP                            -- seconds a fight's card stays; as many fights as the tool keeps
  local pick                                                 -- the combo whose page is open in BEST
  local opened                                               -- NOW: the breakdown's boxes are open
  local choosing                                             -- NOW: what is being changed on the row: 0 = the imbue, 1-4 = a totem's place
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
    return { word = "OLD WINDOW", peek = true, tip = "The list with the icons you can click to cast", fn = function() C.Toggle(true) end }
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
  --[[ THE SET-UP THAT IS CHOSEN (Arn, 22 Nov: "combo DPS number huge of current selected set up, all the break down numbers when hover
    over it , under the DPS use the totem api choose which Call of the icons" - "on top of the icons show the icons of the totems that
    is in the current set up" - "even the water one" - "under the totem row have the 4 call buttons and it sets it and drops it"): the imbue on your weapon and the totems of the chosen Call. Its number is the
    average of its fights; a Call's icon chooses it and drops it, a totem's icon changes that place. The fourth is Totemic Call. The imbue is
    first on the row ("add the imbue to to top row"): a press puts it on. LAST and TRY put theirs on the row ("if i click the last it
    should put that imbue and totems on the row"); a weapon imbued by hand is followed. ]]
  local function setup()
    local To = NS.Totems
    local page = To and To.Shaman() and To.Can() and To.Now() or nil
    local on = not (InCombatLockdown and InCombatLockdown()) and C.ImbueNow() or nil
    if on and on ~= db().imbueSeen then db().imbueSeen, db().imbueNow = on, nil end
    local im = db().imbueNow or on
    if not im and last() then im = last().imbue end
    local set, names, at = {}, {}, {}
    if page then
      at = To.Names(page)
      for slot = 1, 4 do local n = at[slot] if n and C.TOTEMS[n] and not set[n] then set[n] = true names[#names + 1] = n end end
    elseif last() then
      for _, n in ipairs(last().totems or {}) do set[n] = true names[#names + 1] = n end
    end
    local combo = C.Label(im, set)
    local k, n, g = place(combo)
    return { page = page, imbue = im, on = on, names = names, at = at, combo = combo, k = k, of = n, g = g }
  end
  local function breakdown(s)
    local out = {}
    if s.g then
      local _, order = tiles(s.combo)
      for _, x in ipairs(order) do if x.t[2] ~= "-" then out[#out + 1] = { cap(x.t[1]) .. (x.i <= 3 and " procs" or ""), x.t[2] } end end
      if s.k then table.insert(out, 1, { "Place", s.k .. " of " .. s.of }) end
    end
    local f = last()
    if f then
      out[#out + 1] = { " ", " " }
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
    return { art = "number", big = s.g and int(s.g.dps) or "NEW", ink = s.g and (s.k == 1 and "gold" or "good") or "dim", small = "DPS  " .. whole(s.imbue, s.names),
      right = f and ("last " .. int(dps(f)) .. (vs ~= "-" and "  " .. vs or "")) or "", rightInk = ink == "warn" and "warn" or ink == "good" and "good" or "ink2",
      under = s.g and (plural(s.g.n, "fight") .. (s.k and ", #" .. s.k .. " of " .. s.of or "")) or "never fought: go and fight",
      tip = long(s.imbue, s.names), lines = breakdown(s), peek = true, fn = function() opened = not opened end }
  end
  --- Put a set-up on the row: its imbue, its totems.
  local function put(imbue, names)
    db().imbueNow = imbue or nil
    if NS.Totems then NS.Totems.Load(names) end
    kept = {}
  end
  local function setKey(imbue, names, tip)
    local To = NS.Totems
    if not (To and To.Shaman() and To.Can() and To.ComboPage()) then return nil end
    return { word = "SET", peek = true, tip = tip, fn = function() put(imbue, names) end }
  end
  --[[ TRY, and the TOP ONE (Arn, 22 Nov: "on the try next just say try: imbue and 4 totem icons can click them and have the 4 call of the
    icons to set it" - "on the bottom of try have Tops dps and same have the imbue and totems and the 4 call of the icons"): two lines
    of icons each - the set-up, a press casts that one; the Calls, a press puts the set-up into that Call and drops it. ]]
  local function block(word, sub, ink, imbue, names, tip)
    local To, s = NS.Totems, setup()
    if not s.page then return nil end
    local by = C.CellNames(imbue, names)
    local function one(n, slot)
      if not n then return slot and { word = To.SLOTS[slot], done = true, tip = To.SLOTS[slot] .. ": nothing" } or { word = "No imbue", done = true, tip = "No imbue" } end
      return { pic = C.IconFor(n), word = C.COL_WORD[n] or C.IMBUE_SHORT[n] or To.Short(n), tip = n .. (slot and ". Click: drops it" or ". Click: puts it on your weapon"),
        act = C.Knows(n) and { word = slot and "DROP" or "IMBUE", spell = n, peek = true } or nil }
    end
    local water = To.Get(s.page, 3)
    local row = { one(imbue), one(by.fire[1], 1), one(by.earth[1], 2), one(s.at[3], 3), one(by.air[1], 4) }
    local calls = {}
    for i, page in ipairs(To.Known()) do
      local c = To.CALLS[page]
      calls[i] = { pic = C.IconFor(c.name) or To.Icon(c.id), word = cap(c.tab), lit = To.Holds(page, names) or nil, tip = c.name .. ". Click: these go into it, and all drop",
        act = To.SetDrop(page, names, water, function() db().imbueNow = imbue or nil kept = {} end) }
    end
    if C.Knows(To.BRING) then calls[#calls + 1] = { pic = C.IconFor(To.BRING), word = "Bring", tip = To.BRING .. ": the ones that stand come to you", act = { word = "BRING", spell = To.BRING, peek = true } } end
    return { text = word, sub = sub, ink = ink, tip = tip, icons = row }, { text = "", sub = "set in", ink = "dim", icons = calls, tip = "Puts it into that Call and drops it" }
  end
  local function icons()
    local s = setup()
    if not s.page then return nil end
    local To = NS.Totems
    local row, calls = {}, {}
    local isOn = s.imbue ~= nil and s.on == s.imbue
    row[1] = { pic = C.IconFor(s.imbue), word = s.imbue and To.Short(s.imbue) or "No imbue", lit = choosing == 0 or (choosing == nil and isOn), done = s.imbue == nil,
      tip = (s.imbue and (s.imbue .. (isOn and ": on your weapon" or ": not on your weapon")) or "No imbue") .. ". Click: choose one",
      act = { word = "choose", peek = true, fn = function() choosing = choosing ~= 0 and 0 or nil D.skip = 0 end } }
    for slot = 1, 4 do
      local n = s.at[slot]
      row[slot + 1] = { pic = n and (To.Icon(To.Get(s.page, slot)) or C.IconFor(n)) or nil, word = n and To.Short(n) or To.SLOTS[slot], done = n == nil, tip = To.SLOTS[slot] .. ": " .. (n or "nothing") .. ". Click: choose another", lit = choosing == slot or nil,
        act = { word = "choose", peek = true, fn = function() choosing = choosing ~= slot and slot or nil D.skip = 0 end } }
    end
    for i, page in ipairs(To.Known()) do
      local c = To.CALLS[page]
      calls[i] = { pic = C.IconFor(c.name) or To.Icon(c.id), word = cap(c.tab), lit = page == s.page, tip = c.name .. ". Click: it is chosen, and drops all four",
        act = { word = "DROP", spell = c.name, peek = true, ok = function() To.Choose(page) return true end } }
    end
    if C.Knows(To.BRING) then calls[#calls + 1] = { pic = C.IconFor(To.BRING), word = "Bring", tip = To.BRING .. ": the ones that stand come to you", act = { word = "BRING", spell = To.BRING, peek = true } } end
    return { row, calls }
  end
  --- WHAT FITS THERE, IN PLACE (Arn, 22 Nov: "if i click imbue let me select a new imbue from there dont send me to another app. if i
  --- click a totem let me select another fire totem dont send me to another app"): the list under the row, instead of the rest.
  local function chooseRows()
    local s, To = setup(), NS.Totems
    if not (choosing and s.page) then choosing = nil return nil end
    local done = function() choosing = nil D.skip = 0 end
    local out = { { mark = "<", text = choosing == 0 and "Imbue" or To.SLOTS[choosing] .. " totem", right = choosing > 0 and To.CALLS[s.page].name or nil, ink = "dim", act = { word = "back", peek = true, fn = done }, verb = "BACK" } }
    if choosing == 0 then
      for _, n in ipairs(C.TRY.imbue) do
        if C.Knows(n) then
          out[#out + 1] = { pic = C.IconFor(n), text = n, right = n == s.on and "ON" or nil, ink = "good", tip = "Click: onto your weapon",
            act = { word = "IMBUE", spell = n, peek = true, ok = function() db().imbueNow = n choosing = nil kept = {} return true end } }
        end
      end
      return out
    end
    local now = To.Get(s.page, choosing)
    for _, id in ipairs(To.List(choosing)) do
      out[#out + 1] = { pic = To.Icon(id), text = (C.Base(To.Name(id)) or "?"):gsub(" Totem$", ""), verb = id == now and "HERE" or "PUT", verbInk = id == now and "good" or nil,
        act = { word = "put", peek = true, fn = function()
          To.said = not To.Set(s.page, choosing, id) and "The game did not take it" or nil
          kept = {}
          done()
        end } }
    end
    out[#out + 1] = { mark = "-", text = "Nothing", verb = now and "PUT" or "HERE", act = { word = "put", peek = true, fn = function() To.Set(s.page, choosing, nil) kept = {} done() end } }
    return out
  end
  local function nowRows()
    local pickList = chooseRows()
    if pickList then return pickList end
    local out, f = {}, last()
    local lastRow
    local function add(row) out[#out + 1] = row end
    if f then
      lastRow = ({ pic = C.IconFor(f.imbue), mark = "-", text = "Last: " .. beside(f.imbue, f.totems), right = f.mixed and "MIXED" or "", ink = "gold",
        tip = fightTip(f), verb = setKey() and "SET" or "OPEN", act = setKey(f.imbue, f.totems, "Its imbue and totems onto the row") or open(f.combo) })
    end
    local c, total, untried = try()
    local a, b
    if c then a, b = block("TRY", c.n == 0 and "never fought" or plural(c.n, "fight"), "gold", c.imbue, c.totems, "Try next. " .. long(c.imbue, c.totems) .. ". " .. (untried or 0) .. " of " .. (total or 0) .. " combos never tried.") end
    if a then add(a) add(b)
      local top = rank()[1]
      local x, y
      if top then x, y = block("TOP " .. int(top.dps), plural(top.n, "fight"), "good", top.imbue, top.totems, "Your best. " .. long(top.imbue, top.totems) .. ", " .. int(top.dps) .. " dps") end
      if x then add(x) add(y) end
    elseif c then
      -- (Arn, 22 Nov: "we can get rid of the imbue and drop" - one row: what to try, and one press that fills a Call with it and drops it)
      add({ pic = C.IconFor(c.imbue), mark = ">", text = "Try: " .. beside(c.imbue, c.totems), sub = c.n == 0 and "never fought" or plural(c.n, "fight") .. " so far",         tip = "Try next. " .. long(c.imbue, c.totems) .. ". " .. (untried or 0) .. " of " .. (total or 0) .. " combos never tried." })
    elseif total then
      local top = rank()[1]
      local x, y
      if top then x, y = block("TOP " .. int(top.dps), plural(top.n, "fight"), "good", top.imbue, top.totems, "Your best. " .. long(top.imbue, top.totems)) end
      if x then add(x) add(y) end
      add({ mark = ">", text = "Every combo is tried", right = C.TRY_ENOUGH .. "+ each", ink = "good", tip = "Each has enough fights: the ranking holds" })
    end
    if lastRow then table.insert(out, a and #out + 1 or 1, lastRow) end
    if not a and not (InCombatLockdown and InCombatLockdown()) then       -- (the row on top says it)
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
    return { { "COMBOS", #all }, { "FIGHTS", (C.CountKept()) }, { "BEST", int(all[1].adj), "gold" }, { "CRIT", crit and crit[2] or "-", "good" } }
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
    local _, order = tiles(pick)
    for _, x in ipairs(order) do
      local t = x.t
      if SMALL[t[1]] and t[2] ~= "-" then
        out[#out + 1] = { mark = "-", text = SMALL[t[1]], right = t[2], tip = t[4] and table.concat(t[4], ". ") or nil }
      end
    end
    local l, shown = list(), 0
    for i = #l, 1, -1 do
      local f = l[i]
      if f.combo == pick and shown < MANY then
        shown = shown + 1
        out[#out + 1] = { mark = "x", text = f.mob or "?", right = int(dps(f)), ink = counts(f) and "good" or "dim", done = not counts(f), tip = fightTip(f) }
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
    return { { "COUNT", (C.CountKept()) }, { "AVERAGE", avg and int(avg) or "-", "good" }, { "BEST", int(best), "gold" },
      { "TIME", all >= 3600 and ("%.1f h"):format(all / 3600) or (math.floor(all / 60) .. " m"), "ink2" } }
  end
  local function fightRows()
    local out, l = {}, list()
    for i = #l, math.max(1, #l - MANY + 1), -1 do
      local f = l[i]
      out[#out + 1] = { pic = C.IconFor(f.imbue), mark = "-", text = (f.mob or "?") .. (f.mixed and " (mixed)" or "") .. (f.grp and " - group" or ""), right = int(dps(f)),
        ink = counts(f) and "good" or "dim", done = not counts(f), tip = fightTip(f), act = open(f.combo) }
    end
    return out
  end

  -- the deck paints when it is told: a fight was just read (Combo.lua calls C.Close by its name, 1.5 s after the fight)
  local close = C.Close
  C.Close = function(...)
    local rec = close(...)
    if rec and D then D.Dirty() end                          -- (a flag: nothing is drawn while nothing is shown)
    return rec
  end

  return {
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
        return { "COMBO", "", (ranked and "#" .. k .. " " or "") .. short(f.imbue) .. ", " .. totems(f.imbue, f.totems),
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
        if tab == 1 and setup().page then return NS.Totems.said end
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
          local To = NS.Totems
          return g and (To and To.DropAll(g.totems, "DROP ALL: " .. totems(nil, g.totems)) or deckKey(g.totems)) or nil
        end
      end,
      keys = function(tab)
        local out = {}
        if tab == 1 then
          local c = try()
          if setKey() and setup().page then return {} end       -- (the icons are the buttons there)
          if c and c.imbue then out[1] = { word = "IMBUE " .. short(c.imbue), spell = c.imbue, peek = true } end
          local dk = c and NS.Totems and NS.Totems.DropAll(c.totems, "x") and deckKey(c.totems)
          if dk then dk.word = "SET DECK" out[#out + 1] = dk end
        elseif inCombo(tab) then
          local combo = pick
          local _, _, g = place(pick)
          local set = g and setKey(g.imbue, g.totems, "Its imbue and totems onto the row (NOW)")
          if set then out[2] = set end
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
