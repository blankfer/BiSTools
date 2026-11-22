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
function DP.Rows(tab)
  local BF = DP.Place()
  local out = {}
  for i, e in ipairs(BF and (tab == 2 and BF.quests or BF.bosses) or {}) do
    local st = BF.State(e)
    local word, ink = BF.Word(e, st)
    out[i] = { mark = st == "down" and "v" or tostring(i), text = e.name, right = word, ink = ink, done = st == "down", tip = e.title,
      act = st ~= "down" and not e.group and { word = "MARK", macro = BF.RowMacro(e) } or nil }
  end
  return out
end
--- A dungeon run as steps: the quests outside and in, then the bosses.
function DP.Steps()
  local BF = DP.Place()
  local out = {}
  for _, e in ipairs(BF and BF.quests or {}) do
    out[#out + 1] = { phase = e.out and "OUTSIDE" or "INSIDE", text = (e.note and (e.note:sub(1, 1) .. e.note:sub(2):lower() .. ", then ") or "") .. e.name, note = e.title,
      done = function() return e.done end, button = { word = "FIND", macro = BF.One(e, "always") } }
  end
  for _, e in ipairs(BF and BF.map and BF.bosses or {}) do
    out[#out + 1] = { phase = "BOSS", text = e.name, done = function() return BF.State(e) == "down" end,
      button = not e.group and { word = "FIND", macro = BF.One(e, "always") } or nil }
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
function DP.Ride()
  local best
  for _, r in ipairs(DP.Rides()) do
    if r.timed and type(r.left) == "number" and (r.docked or r.left <= 120) and (not best or (r.docked and not best.docked) or (r.docked == best.docked and r.left < best.left)) then best = r end
  end
  return best
end

-- what it hands in ---------------------------------------------------------------------------------------------------------

function DP.Register()
  if not (D and D.Register) or DP.done then return false end
  DP.done = true
  local store = function() local d = NS.DB() d.deckStore = type(d.deckStore) == "table" and d.deckStore or {} return d.deckStore end
  DP.bosses = D.Register{
    owner = "BiSTools", key = "bosses", name = "Bosses", icon = "Bo", order = 10, store = store,
    badge = function() local c = DP.Boss() return c and (c.all - c.down) or nil end,
    card = {
      prio = function() local c = DP.Boss() return c and c.down < c.all and 8 or nil end,
      lines = function()
        local c = DP.Boss()
        return { "BOSSES", c.down .. " of " .. c.all .. " down", "Next: " .. (c.next and c.next.name or "-"), c.down .. " / " .. c.all, "ink2", hot = c.found > 0 }
      end,
      buttons = function() return { { word = "OPEN", fn = function() D.Open("BiSTools:bosses") end }, { word = "BOSS PHONE", fn = function() if NS.Bosses then NS.Bosses.Toggle(true) end end } } end,
    },
    page = {
      title = function() local BF = DP.Place() return BF and (BF.data and BF.data.name or BF.outName) or "Bosses" end,
      kicker = function() return "bosses" end,
      boxes = function()
        local c = DP.Boss()
        if not c then return {} end
        return { { "DOWN", c.down .. " / " .. c.all, "good" }, { "LEFT", c.all - c.down, "gold" }, { "FOUND", c.found, "accent" } }
      end,
      tabs = function() local BF = DP.Place() return { "BOSSES", "QUESTS " .. (BF and BF.quests and #BF.quests or 0) } end,
      rows = DP.Rows,
      text = function() return not DP.Place() and "Walk into a dungeon, or the zone of one's entrance." or nil end,
      big = function() return { word = "OPEN THE BOSS PHONE", fn = function() if NS.Bosses then NS.Bosses.Toggle(true) end end } end,
    },
  }
  D.Register{
    owner = "BiSTools", key = "run", name = "Run", icon = "Rn", order = 11,
    badge = function() local n = 0 for _, s in ipairs(DP.Steps()) do if not s.done() then n = n + 1 end end return n > 0 and n or nil end,
    page = { title = function() local BF = DP.Place() return BF and ((BF.data and BF.data.name or BF.outName or "") .. " run") or "Run" end, steps = DP.Steps,
      text = function() return "Walk into a dungeon: its quests and bosses come up as steps." end },
  }
  D.Register{
    owner = "BiSTools", key = "rides", name = "Rides", icon = "Ri", order = 30,
    card = {
      prio = function() local r = DP.Ride() return r and (r.docked and 9 or 5) or nil end,
      lines = function() local r = DP.Ride() return { "RIDES", "", (r.kind == "boat" and "Boat to " or "Zeppelin to ") .. tostring(r.to or r.name), clock(r.left), "gold", hot = r.docked } end,
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
  usage = "/bist deck  |  /bist deck wide|tall|pin <profile>|unpin",
  defaultOff = true,
  defaults = {},
  OnEnable = function() if D then D.Show() end end,
  OnDisable = function() if D then D.Hide() end end,
  OnOpen = function() if D then D.Toggle() end end,
  OnSlash = function(_, _, args)
    if not D then return NS.Print("deck: the kit did not load") end
    local cmd, rest = (args or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "wide" or cmd == "tall" then D.Show() D.Flip(cmd == "wide" and "landscape" or "portrait")
    elseif cmd == "pin" then
      for _, p in ipairs(D.PROFILES) do if p:lower() == rest:lower() then D.Pin(p) return NS.Print("deck: pinned to %s", p) end end
      NS.Print("deck: profiles are %s", table.concat(D.PROFILES, ", "))
    elseif cmd == "unpin" then D.Pin(nil) NS.Print("deck: it follows you again")
    else D.Toggle() end
  end,
})

-- what moves a card, only while the deck is shown (D.Dirty is a flag; the deck paints once a second at most)
if NS.Bosses then
  local paint = NS.Bosses.Paint
  NS.Bosses.Paint = function(...)
    if D and D.frame and D.frame:IsShown() then D.Dirty() end
    return paint(...)
  end
end
