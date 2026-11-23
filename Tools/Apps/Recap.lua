-- BiSTools / Tools / Apps / Recap.lua - the tool in the phone (dev/APPS.md): what killed you.
--
-- The old window shows your LAST death; the game's own record holds no more. The phone keeps this session's (the last ten, in
-- memory only): each one is noted as the tool reads it (RC.Summary at PLAYER_DEAD), nothing is asked of the game twice.
local _, NS = ...
local DP, R = NS.DeckPages, NS.Registry
if not (DP and DP.App) then return end
local RC = NS.Recap
local D = BiSTheme and BiSTheme.Deck
local ID = "BiSTools:tool-recap"
local MAX, SURE = 10, 5
local deaths = {}                                         -- newest first: { s = the summary, at = time() | nil, where }
DP.Deaths = deaths

local function note(s, at)
  if not s or not (s.hits and s.hits[1]) then return end
  for _, d in ipairs(deaths) do if d.s == s then return end end
  table.insert(deaths, 1, { s = s, at = at, where = at and RC.Place() or nil })
  deaths[MAX + 1] = nil
end
do
  local summary = RC.Summary
  RC.Summary = function(...)
    local s = summary(...)
    -- (waitFight = the game just said you died; a summary asked for later is not a new death)
    if RC.waitFight then
      note(s, time and time() or nil)
      if D and D.frame and D.frame:IsShown() then D.Dirty() end
    end
    return s
  end
end
--- The death the tool holds, when it came before this file could note it (a /reload at your corpse): asked once, as the window does.
local asked
local function look()
  if not RC.last and not asked then
    asked = true
    local events = RC.Fetch()
    if events and #events > 0 then RC.last = RC.Summary(RC.Hits(events), RC.MaxHP()) end
  end
  if RC.last and #deaths == 0 then note(RC.last) end
end

local open                                                -- the death whose page is open
local function go(d)
  open = d
  if D then D.skip = 0 end
end
local function shown() look() return open or deaths[1] end
local function when(d) return d.at and date and date("%H:%M", d.at) or "earlier" end
local function who(a)
  if not a then return "something" end
  return a.names and a.names[1] and a.title or "someone"
end
local function dead()
  local ok, v = pcall(function() return UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") end)
  if not ok or v == nil or (issecretvalue and issecretvalue(v)) then return false end
  return v and true or false
end

local function hitRows(d)
  local s, out = d.s, {}
  out[1] = { mark = "<", text = "Back", right = when(d), tip = "Back to the list", act = { word = "back", peek = true, fn = function() go(nil) end } }
  local newest = s.hits[1] and s.hits[1].t
  for i, h in ipairs(s.hits) do
    local what, amt = RC.HitWords(h)
    local name = h.name or "someone"
    local ago = newest and h.t and i > 1 and (" (%.1f s before)"):format(newest - h.t) or ""
    -- (the colour pass, 22 Nov: when and how much health you had, under it; the killing blow's words in red)
    local when2 = i == 1 and "the killing blow" or (newest and h.t and ("%.1f s before"):format(newest - h.t)) or nil
    local subw = (when2 or "") .. ((when2 and h.hp) and ", " or "") .. (h.hp and ("you had " .. h.hp) or "")
    out[#out + 1] = { mark = i == 1 and "x" or tostring(i), text = what .. " - " .. name, right = amt, ink = i == 1 and "warn" or h.crit and "gold" or "ink2",
      tint = i == 1 and "warn" or nil, sub = subw ~= "" and subw or nil,
      tip = name .. ": " .. what .. ", " .. amt .. ago .. (h.hp and (". You had " .. h.hp .. " health.") or ".") }
  end
  return out
end

local arm = {}                                            -- the rival about to be dropped: { name, till }
local function rivalKey(db, a)
  if not RC.Rivals(db)[a.title] then
    return { word = "RIVAL", tip = "Add to your rivals: the tracker watches for them", fn = function() RC.ToggleRival(db, a) end }
  end
  local now = GetTime()
  local sure = arm.name == a.title and now < arm.till
  return { word = sure and "SURE?" or "DROP", tip = "Take them off your rivals (press twice)", fn = function()
    if arm.name == a.title and GetTime() < arm.till then arm.name = nil RC.ToggleRival(db, a)
    else arm.name, arm.till = a.title, GetTime() + SURE end
  end }
end
local function whoRows(db)
  local d, out = shown(), {}
  if not d then return out end
  local s = d.s
  local list = {}
  for _, a in ipairs(s.attackers or {}) do list[#list + 1] = a end
  table.sort(list, function(x, y) return (x.total or 0) > (y.total or 0) end)
  for _, a in ipairs(list) do
    local amt = a.whole and (tostring(a.total) .. RC.Pct(a.total, s.total)) or "?"
    local tip = who(a) .. ": " .. a.hits .. (a.hits == 1 and " hit" or " hits") .. (a.crits > 0 and (", " .. a.crits .. " crit") or "")
      .. (a.top and a.topAmt and (", mostly " .. a.top .. " " .. a.topAmt) or "")
      .. (a.nicks and #a.nicks > 0 and (". Called " .. table.concat(a.nicks, ", ")) or "")
    local subw = a.hits .. (a.hits == 1 and " hit" or " hits") .. (a.crits > 0 and (", " .. a.crits .. " crit") or "") .. (a.top and (", mostly " .. a.top) or "")
    local row = { mark = a == s.killer and "x" or "", text = who(a), right = amt, ink = a == s.killer and "warn" or "ink2", tip = tip, sub = subw,
      tint = a == s.killer and "warn" or (a.player and type(a.class) == "string" and a.class:upper()) or nil }
    if a.player and a.names and a.names[1] then
      row.text, row.right = who(a) .. "  " .. amt, nil
      row.side = rivalKey(db, a)
    end
    out[#out + 1] = row
  end
  local phys, magic, word = RC.Kinds(s)
  local sum = phys + magic
  if phys > 0 then out[#out + 1] = { mark = "-", text = "physical", right = phys .. RC.Pct(phys, sum), ink = "dim" } end
  if magic > 0 then out[#out + 1] = { mark = "-", text = word, right = magic .. RC.Pct(magic, sum), ink = "dim" } end
  return out
end

DP.App.recap = function(tool, db)
  return {
    name = "Recap",
    card = {
      tick = true,
      -- it comes by itself while you are dead, and goes when you stand
      prio = function() return deaths[1] and deaths[1].at and dead() and 6 or nil end,
      lines = function()
        local s = deaths[1].s
        local list = {}
        for i, a in ipairs({ s.killer, s.assists[1], s.assists[2] }) do list[i] = { who(a), a.whole and tostring(a.total) or "?" } end
        return { "YOU DIED", "", who(s.killer), s.whole and tostring(s.total) or "", "warn", list = list }
      end,
      buttons = function()
        local out = { { word = "WHAT HIT YOU", peek = true, fn = function()
          go(deaths[1])
          if D then D.defs[ID].tab = 1 D.Open(ID) end
        end } }
        -- a player killed you (Arn, 22 Nov: "if we get killed the rival live tile will pop out"): make them a rival from here
        local k = deaths[1].s and deaths[1].s.killer
        if k and k.player and type(k.title) == "string" and R:Enabled("rivals") then out[2] = rivalKey(db(), k) end
        return out
      end,
    },
    page = {
      tick = true,
      tour = { { text = "Each death of this evening is a row. Click one: what hit you, newest first.", note = "WHO adds it up, attacker by attacker." } },
      title = function() return open and who(open.s.killer) or "Recap" end,
      kicker = function() return open and (open.where and open.where ~= "" and open.where or "what killed you") or "what killed you" end,
      tabs = function() return { open and "HITS" or "DEATHS", "WHO" } end,
      boxes = function(tab)
        look()
        if tab == 1 and not open then
          if not deaths[1] then return {} end
          return { { "DEATHS", #deaths, "warn" }, { "LAST", when(deaths[1]), "ink" } }
        end
        local d = shown()
        if not d then return {} end
        local s = d.s
        return { { "DAMAGE", s.whole and s.total or "?", "warn" }, { "SECONDS", s.seconds and ("%.1f"):format(s.seconds) or "?", "ink" },
          { "HITS", #s.hits, "ink2" }, { "HEALTH", s.startHP or "?", "good" } }
      end,
      hero = function(tab)
        local a = tab == 1 and open and open.s.killer
        local npc = a and not a.player and tonumber(a.kind)
        if not npc then return nil end
        local what, amt = "", ""
        if open.s.blow then what, amt = RC.HitWords(open.s.blow) end
        return { art = "model", creature = npc, big = who(a), small = "killing blow: " .. what .. " " .. amt }
      end,
      rows = function(tab)
        if tab == 2 then return whoRows(db()) end
        look()
        if open then return hitRows(open) end
        local out = {}
        for i, d in ipairs(deaths) do
          local s = d.s
          local blow = s.blow and table.concat({ RC.HitWords(s.blow) }, " ") or nil
          local subw = (blow or "") .. ((blow and d.where and d.where ~= "") and ", " or "") .. ((d.where and d.where ~= "") and d.where or "")
          out[i] = { mark = tostring(i), text = who(s.killer), right = when(d), ink = "ink2", tint = "warn", sub = subw ~= "" and subw or nil,
            tip = RC.Foot(s) .. (d.where and d.where ~= "" and (" - " .. d.where) or ""), act = { word = "open", peek = true, fn = function() go(d) end } }
        end
        return out
      end,
      text = function()
        look()
        return #deaths == 0 and "Nothing has killed you this session. When something does, it is here: who, with what, how hard." or nil
      end,
      say = function(tab)
        local d = (tab == 2 or open) and shown()
        local words = d and RC.Foot(d.s) or ""
        return words ~= "" and words or nil
      end,
      keys = function()
        if not (D and D.defs["BiSTools:tool-rivals"]) then return {} end
        return { { word = "RIVALS", peek = true, tip = "Your rivals and pals", fn = function() D.Open("BiSTools:tool-rivals") end } }
      end,
    },
  }
end
