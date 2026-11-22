-- BiSTools / Tools / DeckPages.lua - what BiS Tools hands to the one BiS deck (21 Nov 2026, dev/DECK.md). v0.
--
-- Arn, 21 Nov: "our next big project is making bis tools a deck, this time we are going 9:16"; "unifed ui". The deck itself is
-- BiSTheme's (Libs\BiSTheme\Deck.lua): this file makes no frame and picks no colour - it answers questions about what the
-- tools already know. The old windows are untouched; the deck is its own tool, off until asked for (`/bist on deck`).
--
-- v0: the bosses and quest rows are read off the boss finder; their buttons target by a macro, so they wait for the deck's
-- secure overlay (bisdev plans/deckkit.lua) - the boss phone still does the targeting.
local _, NS = ...
local R = NS.Registry
local T = BiSTheme
local D = T and T.Deck
local DP = {}
NS.DeckPages = DP

local function on(tool) return R:Enabled(tool) and true or false end
local function clock(s) s = math.max(0, math.floor(s or 0)) return ("%d:%02d"):format(math.floor(s / 60), s % 60) end

-- the bosses and the quests of where you stand ---------------------------------------------------------------------------

function DP.Place()
  local BF = NS.Bosses
  if not (BF and on("bosses") and BF.key) then return nil end
  return BF
end
--- { down, left, found, next } of the bosses here, or nil.
function DP.Boss()
  local BF = DP.Place()
  if not BF or not BF.bosses or not BF.map then return nil end
  local c = { down = 0, all = #BF.bosses, found = 0 }
  for _, e in ipairs(BF.bosses) do
    local st = BF.State(e)
    if st == "down" then c.down = c.down + 1
    else
      if not c.next and not e.group then c.next = e c.nextState = st end
      if st == "marked" or st == "near" then c.found = c.found + 1 end
    end
  end
  return c
end
--- A secure button that looks for a boss (or a quest's mob): the boss phone's own macro, and what the phone does after it.
function DP.Seek(e, word, macro, after)
  local BF = NS.Bosses
  if not macro or macro == "" then return nil end
  return { word = word, macro = macro, peek = true, tip = "Target it and mark it. Hold shift: ping it too.", ok = function() BF.heard = nil BF.Hit() return true end,
    after = after or function() BF.Took(e) end }
end
--- Which list the finder walks (the boss phone's own tab follows the app's).
function DP.SyncTab(tab)
  local BF = DP.Place()
  if not BF then return nil end
  local want = tab == 2 and "quest" or "boss"
  if BF.tab ~= want and BF.SetTab then BF.SetTab(want) end
  return BF
end
--- The one on the app's picture: the one you clicked to look at, else the next to find.
function DP.Focus(BF)
  local e = BF.FindNext() or (BF.list and BF.list[1])
  return e
end
function DP.Rows(tab)
  local BF = DP.SyncTab(tab)
  local out = {}
  for i, e in ipairs(BF and (tab == 2 and BF.quests or BF.bosses) or {}) do
    local st = BF.State(e)
    local word, ink = BF.Word(e, st)
    out[i] = { mark = st == "down" and "v" or tostring(i), text = e.name, right = word, ink = ink, done = st == "down", tip = e.title,
      act = st ~= "down" and not e.group and DP.Seek(e, "MARK", BF.RowMacro(e)) or nil }
  end
  return out
end
--- A dungeon run as steps: the quests outside and in, then the bosses.
function DP.Steps()
  local BF = DP.Place()
  local out = {}
  for _, e in ipairs(BF and BF.quests or {}) do
    out[#out + 1] = { phase = e.out and "OUTSIDE" or "INSIDE", text = (e.note and (e.note:sub(1, 1) .. e.note:sub(2):lower() .. ", then ") or "") .. e.name, note = e.title,
      done = function() return e.done end, button = DP.Seek(e, "FIND", BF.One(e, "always")) }
  end
  for _, e in ipairs(BF and BF.map and BF.bosses or {}) do
    out[#out + 1] = { phase = "BOSS", text = e.name, done = function() return BF.State(e) == "down" end,
      button = not e.group and DP.Seek(e, "FIND", BF.One(e, "always")) or nil }
  end
  return out
end

-- the rides ---------------------------------------------------------------------------------------------------------------

function DP.Rides()
  local API = _G.BiSToolsAPI
  if not (API and API.Rides and on("rides")) then return {} end
  local ok, list = pcall(API.Rides)
  return ok and type(list) == "table" and list or {}
end
--- The ride worth a card: one at the dock, else the next timed one within two minutes.
--- The other timed rides from here, soonest first (a large card's lines).
function DP.OtherRides(mine)
  local out = {}
  for _, r in ipairs(DP.Rides()) do if r ~= mine and r.timed and type(r.left) == "number" and not (mine and r.to == mine.to and r.left == mine.left) then out[#out + 1] = r end end
  table.sort(out, function(a, b) return a.left < b.left end)
  local lines = {}
  for i = 1, math.min(2, #out) do lines[i] = { tostring(out[i].to or out[i].name), clock(out[i].left) } end
  if mine and mine.by then lines[#lines + 1] = { "timed by " .. tostring(mine.by), type(mine.sure) == "number" and mine.sure .. "% sure" or nil } end
  return lines
end
function DP.Ride(any)
  local best
  for _, r in ipairs(DP.Rides()) do
    if r.timed and type(r.left) == "number" and (any or r.docked or r.left <= 120) and (not best or (r.docked and not best.docked) or (r.docked == best.docked and r.left < best.left)) then best = r end
  end
  return best
end

-- what it hands in ---------------------------------------------------------------------------------------------------------

--- A tool's own switch as the deck asks it: off = its icon is gray and its page has one button, TURN ON.
local function gate(tool)
  return function() return on(tool) and "on" or "off" end,
    { word = "TURN ON", fn = function() R:SetEnabled(tool, true) end }
end

-- FARM (Arn, 22 Nov: "they open farm app they click around in it it'll show up as a live card if it makes sense if they just looks
-- at it and exit they just took a peek"): its card comes after you picked a mob here, and goes when you stop farming.
function DP.FarmDB() local tool = R:Get("farm") return tool and R:DBFor(tool) end
--- { mob, up, next (seconds), spots } of what is farmed now, or nil.
function DP.Farm()
  local F, db = NS.Farm, DP.FarmDB()
  if not (F and db and on("farm") and db.active) then return nil end
  local c = { mob = db.active, up = 0, spots = {} }
  local S = F.Spots
  local now = time()
  for _, z in ipairs(S and S.List(db, db.active) or {}) do
    local words, ink, key = S.ZoneTimer(z, now)
    if words == "up" then c.up = c.up + 1
    elseif type(key) == "number" and key > 0 and key < 1e5 and (not c.next or key < c.next) then c.next = key end
    c.spots[#c.spots + 1] = { z = z, words = words, ink = ink, key = key }
  end
  table.sort(c.spots, function(a, b) return (a.key or 0) < (b.key or 0) end)
  return c
end
function DP.SpotLines(c)
  local out = {}
  for i = 1, math.min(3, #c.spots) do out[i] = { "Spot " .. tostring(c.spots[i].z.mark or i), c.spots[i].words } end
  return out
end
function DP.FarmRows(tab)
  local F, db = NS.Farm, DP.FarmDB()
  local out = {}
  if not (F and db) then return out end
  if tab == 2 then
    local c = DP.Farm()
    for i, s in ipairs(c and c.spots or {}) do
      out[i] = { mark = tostring(s.z.mark or i), text = "Spot " .. tostring(s.z.mark or i), right = s.words, ink = s.ink == "good" and "good" or s.ink == "gold" and "gold" or "ink2" }
    end
    return out
  end
  for i, e in ipairs(F.Entries(db)) do
    local isOn = e.name == db.active
    out[i] = { mark = isOn and "v" or tostring(i), text = e.name, right = isOn and "FARMING" or (e.guide and "RXP" or (e.count or 0) > 1 and ("x" .. e.count) or ""), ink = isOn and "good" or "ink2",
      tip = isOn and "Click: stop farming it" or "Click: farm it", act = { word = "farm", fn = function() F.SetActive(db, e.name) end } }
  end
  return out
end

-- A PAGE FOR EVERY TOOL (Arn, 22 Nov: "we need to make all the tools into apps"): a tool without a page of its own gets one made of
-- what it already told the options window - its switch, its options, its window. Off, it is in the Apps page with TURN ON.
DP.OWN = { bosses = true, rides = true, farm = true, deck = true }
--- One option as a row. `tool` = whose settings.
function DP.OptionRow(tool, opt)
  local db = R:DBFor(tool)
  local row = { text = opt.label, tip = opt.help }
  local v
  if opt.get then v = opt.get(db) end
  if opt.kind == "toggle" then
    row.right, row.ink = v and "ON" or "OFF", v and "good" or "dim"
    row.act = { word = "switch", chip = true, fn = function() opt.set(db, not opt.get(db)) end }
  elseif opt.kind == "seg" then
    row.right = tostring(v)
    row.act = { word = "next", chip = true, fn = function()
      local at = 0
      for i, x in ipairs(opt.values) do if x == opt.get(db) then at = i end end
      opt.set(db, opt.values[at % #opt.values + 1])
    end }
  elseif opt.kind == "step" then
    row.right = tostring(opt.show and opt.show(db) or v)
    local function by(sign)
      local n = (tonumber(opt.get(db)) or 0) + sign * (opt.step or 1)
      opt.set(db, math.max(opt.min or n, math.min(opt.max or n, n)))
    end
    row.less = { word = "-", fn = function() by(-1) end }
    row.more = { word = "+", fn = function() by(1) end }
  elseif opt.kind == "button" then
    row.right, row.ink = tostring(opt.button or "press"):upper(), "accent"
    row.act = { word = "press", chip = true, fn = function() opt.action(db) end }
  end
  return row
end
function DP.ToolRows(tool)
  local out = {}
  for _, opt in ipairs(tool.options or {}) do out[#out + 1] = DP.OptionRow(tool, opt) end
  return out
end
-- THE TOOL ITSELF, IN THE PHONE (Arn, 22 Nov: "these apps i want them to open in the phone like apps, right now the apps are just
-- options"): Tools/Apps/<Name>.lua hands DP.App[key] = function(tool, db) -> { page, card, badge, art } (dev/APPS.md). Its options
-- are the last tab, SETTINGS. A tool without one shows its options alone.
DP.App = DP.App or {}
DP.SET = "SETTINGS"
function DP.Page(key, tool, name, app)
  local about = (tool.desc:sub(1, 1):upper() .. tool.desc:sub(2)) .. "."
  local p = app and app.page or {}
  local function own(tab) return app and (tab or 1) <= DP.OwnTabs(p) end
  local function part(k) return p[k] and function(tab) if own(tab) then return p[k](tab) end end or nil end
  local out = {}
  for k, v in pairs(p) do out[k] = v end                     -- (tour, tick, steps as they are)
  out.title = p.title or function() return name end
  out.kicker = p.kicker or function() return "BiS Tools" end
  for _, k in ipairs({ "boxes", "hero", "say", "find", "big" }) do out[k] = part(k) end
  out.tabs = app and function()
    local t = {}
    for i, x in ipairs(p.tabs and p.tabs() or { name:upper() }) do t[i] = x end
    t[#t + 1] = DP.SET
    return t
  end or nil
  out.rows = function(tab) if own(tab) then return p.rows and p.rows(tab) or {} end return DP.ToolRows(tool) end
  out.text = function(tab) if own(tab) then return p.text and p.text(tab) or nil end return about end
  out.keys = function(tab)
    if own(tab) then return p.keys and p.keys(tab) or {} end
    return { { word = "TURN OFF", peek = true, fn = function() R:SetEnabled(key, false) D.page = "home" end } }
  end
  return out
end
function DP.OwnTabs(p) return p.tabs and #p.tabs() or 1 end
function DP.Tools()
  if not (D and D.Register) or DP.toolsIn then return false end
  DP.toolsIn = true
  if DP.InnervateHello then DP.InnervateHello() end        -- (the first day's card for who gives or asks)
  if NS.Totems then NS.Totems.Register() end               -- (a shaman's: the three Calls)
  local n = 0
  for key, tool in R:Each() do
    n = n + 1
    if not DP.OWN[key] then
      local name = tool.title or tool.name
      name = ({ bg = "BG", xp = "XP", ["rivals & pals"] = "Rivals" })[name] or (name:sub(1, 1):upper() .. name:sub(2))
      local app = DP.App[key]
      if app then
        local fine, a = pcall(app, tool, function() return R:DBFor(tool) end)
        if not fine and geterrorhandler then geterrorhandler()(a) end
        app = fine and type(a) == "table" and a or nil
      end
      D.Register{
        owner = "BiSTools", key = "tool-" .. key, name = app and app.name or name, icon = name:sub(1, 2), art = app and app.art, order = 40 + n / 100, quietOff = true,
        about = (tool.desc:sub(1, 1):upper() .. tool.desc:sub(2)) .. ".",
        state = function() return on(key) and "on" or "off" end,
        turnOn = { word = "TURN ON", fn = function() R:SetEnabled(key, true) end },
        badge = app and app.badge, card = app and app.card,
        page = DP.Page(key, tool, name, app),
      }
    end
  end
  return true
end

function DP.Register()
  if not (D and D.Register) or DP.done then return false end
  DP.done = true
  local store = function() local d = NS.DB() d.deckStore = type(d.deckStore) == "table" and d.deckStore or {} return d.deckStore end
  local state, turnOn = gate("bosses")
  DP.bosses = D.Register{
    owner = "BiSTools", key = "bosses", name = "Bosses", icon = "Bo", order = 10, store = store,
    state = state, turnOn = turnOn, about = "The bosses of the dungeon you are in, and your quests for it: who is down, who is found, one button to mark them.",
    badge = function() local c = DP.Boss() return c and (c.all - c.down) or nil end,
    card = {
      prio = function() local c = DP.Boss() return c and c.down < c.all and 8 or nil end,
      lines = function()
        local c = DP.Boss()
        -- (a large card: who comes after)
        local list, BF = {}, DP.Place()
        for _, e in ipairs(BF and BF.bosses or {}) do if e ~= c.next and BF.State(e) ~= "down" and #list < 3 then list[#list + 1] = { e.name, BF.State(e) == "marked" and "MARKED" or nil } end end
        return { "BOSSES", c.down .. " of " .. c.all .. " down", "Next: " .. (c.next and c.next.name or "-"), c.down .. " / " .. c.all, "ink2", hot = c.found > 0, list = list }
      end,
      buttons = function()
        local BF, out = DP.Place(), {}
        if BF and BF.tab ~= "quest" then
          local m, e = BF.FindMacro()
          if e then out[1] = DP.Seek(e, "FIND", m, function() BF.findFor = e BF.AfterFind() end) end
        end
        out[#out + 1] = { word = "OPEN", peek = true, fn = function() D.Open("BiSTools:bosses") end }
        return out
      end,
    },
    page = {
      tour = { { text = "The bosses of where you stand, in order. MARK targets and marks one; FIND looks for the next.", note = "QUESTS has what your log wants here." },
        { text = "In a fight the buttons go away: the old boss phone stays for that." } },
      title = function() local BF = DP.Place() return BF and (BF.data and BF.data.name or BF.outName) or "Bosses" end,
      kicker = function() return "bosses" end,
      boxes = function()
        local c = DP.Boss()
        if not c then return {} end
        return { { "DOWN", c.down .. " / " .. c.all, "good" }, { "LEFT", c.all - c.down, "gold" }, { "FOUND", c.found, "accent" } }
      end,
      tabs = function() local BF = DP.Place() return { "BOSSES", "QUESTS " .. (BF and BF.quests and #BF.quests or 0) } end,
      rows = DP.Rows,
      tick = true,
      hero = function(tab)
        local BF = DP.SyncTab(tab)
        local e = BF and DP.Focus(BF)
        if not e then return nil end
        local npc, display
        if not e.group then npc, display = BF.NpcOf(e) end
        local word = BF.Word(e, BF.State(e))
        return { art = "model", creature = npc, display = display, big = e.name, small = e.note or (word ~= "" and word) or "next to find" }
      end,
      say = function() local BF = DP.Place() return BF and BF.said ~= "" and BF.said or nil end,
      text = function() return not DP.Place() and "Walk into a dungeon, or the zone of one's entrance." or nil end,
      big = function(tab)
        local BF = DP.SyncTab(tab)
        if not BF then return nil end
        local m, e = BF.FindMacro()
        return e and DP.Seek(e, "FIND: " .. e.name, m, function() BF.findFor = e BF.AfterFind() end) or nil
      end,
      keys = function(tab)
        local BF, out = DP.SyncTab(tab), {}
        if not BF then return out end
        local m, n = BF.AllMacro()
        if n > 0 then out[1] = DP.Seek(nil, "MARK ALL " .. n, m, function() BF.AfterAll({ count = n }) end) end
        if tab ~= 2 then
          local sure = DP.resetAt and GetTime() - DP.resetAt <= 5
          out[#out + 1] = { word = sure and "SURE?" or "RESET", peek = true, tip = "A new run: every boss stands again", fn = function()
            if sure then DP.resetAt = nil BF.Reset() else DP.resetAt = GetTime() end
          end }
        end
        out[#out + 1] = { word = "OLD PHONE", peek = true, tip = "The boss phone: its buttons stay in a fight", fn = function() BF.Toggle(true) end }
        return out
      end,
    },
  }
  D.Register{
    owner = "BiSTools", key = "run", name = "Run", icon = "Rn", order = 11,
    state = state, turnOn = turnOn, about = "A dungeon as steps: the quests outside, the quests inside, then the bosses. It goes on by itself as you do them.",
    badge = function() local n = 0 for _, s in ipairs(DP.Steps()) do if not s.done() then n = n + 1 end end return n > 0 and n or nil end,
    page = { tour = { { text = "A dungeon as steps. It goes on by itself when the game says a step is done.", note = "Back, skip and next are yours." } },
      title = function() local BF = DP.Place() return BF and ((BF.data and BF.data.name or BF.outName or "") .. " run") or "Run" end, steps = DP.Steps,
      text = function() return "Walk into a dungeon: its quests and bosses come up as steps." end },
  }
  local fState, fTurnOn = gate("farm")
  D.Register{
    owner = "BiSTools", key = "farm", name = "Farm", icon = "Fa", order = 20,
    state = fState, turnOn = fTurnOn, quietOff = true, about = "Pick a mob you kill: fresh copies are found and marked, its spots are timed.",
    badge = function() local c = DP.Farm() return c and c.up or nil end,
    card = {
      when = "use", tick = true,
      alive = function() return DP.Farm() ~= nil end,
      prio = function() local c = DP.Farm() return c and (c.up > 0 and 6 or 3) or nil end,
      lines = function()
        local c = DP.Farm()
        return { "FARM", "", c.mob, c.up > 0 and (c.up .. " up") or c.next and clock(c.next) or "", c.up > 0 and "good" or "ink2", list = DP.SpotLines(c) }
      end,
      buttons = function()
        return { { word = "STOP", fn = function() NS.Farm.SetActive(DP.FarmDB(), nil) end },
          { word = "SPOTS", peek = true, fn = function() D.defs["BiSTools:farm"].tab = 2 D.Open("BiSTools:farm") end } }
      end,
    },
    page = {
      tour = { { text = "Pick a mob: it becomes a live card on home.", note = "Just looking changes nothing." }, { text = "Drag that card onto your screen if you want it there. Its x puts it back." } },
      title = function() return "Farm" end,
      kicker = function() local c = DP.Farm() return c and "farming" or "pick a mob" end,
      boxes = function()
        local c, db = DP.Farm(), DP.FarmDB()
        if not c then return {} end
        return { { "KILLS", db.last and db.last.name == c.mob and db.last.count or "-", "ink" }, { "UP NOW", c.up, "good" }, { "NEXT", c.next and clock(c.next) or "-", "gold" } }
      end,
      tabs = function() local c = DP.Farm() return { "MOBS", "SPOTS " .. (c and #c.spots or 0) } end,
      rows = DP.FarmRows,
      text = function() return #DP.FarmRows(1) == 0 and "Kill something: it shows up here. Your guide's targets do too." or nil end,
      keys = function() return { { word = "WINDOW", peek = true, fn = function() NS.Farm.Toggle(DP.FarmDB(), true) end }, { word = "FORGET", peek = true, fn = function() NS.Farm.Clear(DP.FarmDB()) end } } end,
    },
  }
  local rState, rTurnOn = gate("rides")
  D.Register{
    owner = "BiSTools", key = "rides", name = "Rides", icon = "Ri", order = 30,
    state = rState, turnOn = rTurnOn, about = "When the next zeppelin or boat leaves, timed by your guild.",
    card = {
      tick = true,
      -- pulled out, it always shows the next ride (you put it there on purpose); in the deck only one that is close
      prio = function(out) local r = DP.Ride(out) return r and (r.docked and 9 or 5) or nil end,
      lines = function(out) local r = DP.Ride(out) return { r.docked and "RIDES - LEAVES IN" or "RIDES - ARRIVES IN", "", (r.kind == "boat" and "Boat to " or "Zeppelin to ") .. tostring(r.to or r.name), clock(r.left), "gold", hot = r.docked, list = DP.OtherRides(r) } end,
    },
    page = {
      title = function() return "Rides" end, kicker = function() return "timed by your guild" end,
      rows = function()
        local out = {}
        for i, r in ipairs(DP.Rides()) do out[i] = { mark = tostring(i), text = tostring(r.to or r.name), right = r.timed and clock(r.left) or "?", ink = r.docked and "gold" or "ink2", tip = r.line } end
        return out
      end,
      text = function() return #DP.Rides() == 0 and "No zeppelin or boat from here." or nil end,
    },
  }
  return true
end
DP.Register()

R:Register({
  name = "deck",
  desc = "the one BiS deck, tall or wide: live cards, pages, steps (first try: look, do not lean on it yet)",
  usage = "/bist deck  |  /bist deck wide|tall|pad|welcome|theme <name>|pin <profile>|unpin",
  defaultOff = true,
  defaults = {},
  OnLogin = function() DP.Tools() end,
  OnEnable = function() if D then DP.Tools() if D.Off then D.Off(false) end D.Show() end end,
  OnDisable = function() if D then D.Hide() if D.Off then D.Off(true) end end end,
  OnOpen = function() if D then D.Toggle() end end,
  OnSlash = function(_, _, args)
    if not D then return NS.Print("deck: the kit did not load") end
    local cmd, rest = (args or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "wide" or cmd == "tall" then D.Show() D.Flip(cmd == "wide" and "landscape" or "portrait")
    elseif cmd == "pin" then
      for _, p in ipairs(D.PROFILES) do if p:lower() == rest:lower() then D.Pin(p) return NS.Print("deck: pinned to %s", p) end end
      NS.Print("deck: profiles are %s", table.concat(D.PROFILES, ", "))
    elseif cmd == "pad" then
      -- the pad holds the deck only while asked to (B gives it back): it stands open all evening
      if not D.Focus(not D.focused) then NS.Print("deck: no gamepad kit, or a fight") end
    elseif cmd == "welcome" then D.Show() if D.Replay then D.Replay() end
    elseif cmd == "theme" then
      local names = {}
      for _, t in ipairs(D.THEMES) do
        if rest ~= "" and (t.key == rest:lower() or t.name:lower() == rest:lower()) then D.Show() D.SetTheme(t.key) return NS.Print("deck: theme %s", t.name) end
        names[#names + 1] = t.name
      end
      NS.Print("deck: themes are %s (now %s)", table.concat(names, ", "), D.Theme().name)
    elseif cmd == "unpin" then D.Pin(nil) NS.Print("deck: it follows you again")
    else D.Toggle() end
  end,
})

--- The minimap button's left click (Tools/Hub.lua): is the deck switched on? Then open / close it. Answers true when it did.
--- A tool's app on the phone, when the deck is on. Answers whether it opened.
function DP.OpenApp(key)
  if not (DP.IsOn() and D.defs["BiSTools:tool-" .. key]) then return false end
  return D.Open("BiSTools:tool-" .. key) and true or false
end
function DP.IsOn() return (D and R:Enabled("deck")) and true or false end
function DP.Toggle()
  if not DP.IsOn() then return false end
  D.Toggle()
  return true
end
function BiSTools_ToggleDeck() if not DP.Toggle() and D then R:SetEnabled("deck", true) end end    -- the key (Key Bindings > BiS Tools)
_G.BINDING_NAME_BISTOOLS_DECK = "The deck"

--- Into a dungeon with the deck on: its Bosses app instead of the old boss phone (Arn, 22 Nov: "move the boss phone into the Bosses app").
function DP.BossesHere()
  if not (D and D.Open and R:Enabled("deck")) then return false end
  D.defs["BiSTools:bosses"].tab = 1
  return D.Open("BiSTools:bosses") and true or false
end
--- Does the phone show this app's live card now (home open, or the card or its app out on the screen)? Then the old card stays away.
function DP.CardSeen(id)
  if not (D and D.IsPinned and R:Enabled("deck")) then return false end
  if D.IsPinned(id) or (D.IsOut and D.IsOut(id)) then return true end
  local f = D.mainSurf and D.surf ~= D.mainSurf and D.mainSurf.frame or D.frame
  return f and f:IsShown() and (D.page or "home") == "home" or false
end
--- Is the Rides card out on the screen? Then the old rides card stays away: one or the other (Tools/Rides.lua asks).
-- (... or on the open phone: Arn, 22 Nov, both of them side by side)
function DP.RidePinned()
  if not (D and D.IsPinned and R:Enabled("deck")) then return false end
  if D.IsPinned("BiSTools:rides") or (D.IsOut and D.IsOut("BiSTools:rides")) then return true end
  local f = D.mainSurf and D.surf ~= D.mainSurf and D.mainSurf.frame or D.frame
  if not (f and f:IsShown()) then return false end
  return D.page == "BiSTools:rides" or ((D.page or "home") == "home" and DP.Ride() ~= nil)
end

-- what moves a card, only while the deck is shown (D.Dirty is a flag; the deck paints once a second at most)
if NS.Bosses then
  local paint = NS.Bosses.Paint
  NS.Bosses.Paint = function(...)
    if D and D.frame and D.frame:IsShown() then D.Dirty() end
    return paint(...)
  end
end
