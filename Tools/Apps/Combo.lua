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
    return { { "DPS", int(dps(f)), ink == "warn" and "gold" or "good" },
      { "PLACE", counts(f) and k and (k .. "/" .. n) or "-", k == 1 and "gold" or "ink" },
      { "VERSUS", vs, ink }, { "WF", int((f.wf or 0) * 100) .. "%", "gold" } }
  end
  local function nowRows()
    local out, f = {}, last()
    local function add(row) out[#out + 1] = row end
    if f then
      add({ pic = C.IconFor(f.imbue), mark = "-", text = "Last: " .. beside(f.imbue, f.totems), right = f.mixed and "MIXED" or "", ink = "gold",
        tip = fightTip(f), act = open(f.combo) })
      local pw = procWords(f)
      if pw then add({ mark = "-", text = "Procs", right = pw, ink = "gold", tip = f.swings and ("Over " .. f.swings .. " swings of yours") or nil }) end
      for _, s in ipairs(spells(f, 3)) do add({ mark = "-", text = s[1], right = s[2], tip = "Its share of your damage" }) end
    end
    local c, total, untried = try()
    if c then
      add({ pic = C.IconFor(c.imbue), mark = ">", text = "Try: " .. beside(c.imbue, c.totems), right = c.n == 0 and "NEW" or plural(c.n, "fight"), ink = "accent",
        tip = "Try next. " .. long(c.imbue, c.totems) .. ". " .. (untried or 0) .. " of " .. (total or 0) .. " combos never tried." })
      local names = {}
      if c.imbue then names[1] = c.imbue end
      for _, n in ipairs(c.totems) do names[#names + 1] = n end
      for _, n in ipairs(names) do
        add({ pic = C.IconFor(n), mark = " ", text = n, act = { word = "CAST", spell = n }, tip = "Click: cast it" })
      end
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
        if tab == 1 then return nowBoxes() end
        if tab == 3 then return fightBoxes() end
        return inCombo(tab) and comboBoxes() or bestBoxes()
      end,
      rows = function(tab)
        if tab == 1 then return nowRows() end
        if tab == 3 then return fightRows() end
        return inCombo(tab) and comboRows() or bestRows()
      end,
      text = function(tab)
        if #list() > 0 then return nil end
        if tab == 1 then return "No fight yet. Put an imbue on your weapon, drop your totems and fight: the result comes here." end
        return "No fight yet. Each one is kept here once you have fought."
      end,
      say = function(tab)
        local f = last()
        if not f then return C.lastWhy end
        if tab == 1 then return (f.grp and C.Scope() == "solo" and "In a group: not counted. " or "") .. secs(f) .. (f.mob and ", " .. f.mob or "") end
        if tab == 2 and not inCombo(tab) then return "dps as if the mobs were your level (fights)" end
        if tab == 3 and C.Min() > 0 then return "fights under " .. C.Min() .. " s are not ranked" end
        if tab == 3 then local _, g = C.CountKept() if g > 0 then return g .. " with others: kept, not counted" end end
        return "dps over the time you swing"
      end,
      big = function(tab)
        if tab == 1 then
          local c = try()
          return c and deckKey(c.totems) or nil
        elseif inCombo(tab) then
          local _, _, g = place(pick)
          return g and deckKey(g.totems) or nil
        end
      end,
      keys = function(tab)
        local out = {}
        if tab == 1 then
          local c = try()
          if c and c.imbue then out[1] = { word = "CAST " .. short(c.imbue), spell = c.imbue } end
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
