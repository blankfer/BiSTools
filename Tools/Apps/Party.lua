-- BiSTools / Tools / Apps / Party.lua - your usual group in the phone (dev/APPS.md). Its work is Tools/Party.lua's (NS.Party): the list,
-- who is missing, the waves, the invites (P.InviteNames: a few at a time, a raid by itself past five). The old window's inviting box
-- does not come up from here: the rows say who was asked.
local _, NS = ...
local DP, R = NS.DeckPages, NS.Registry
local D = BiSTheme and BiSTheme.Deck
if not (DP and DP.App) then return end

local function plain(v)
  if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
  return v
end
local function now() return GetTime and plain(GetTime()) or 0 end
local function try(fn, ...)
  if not fn then return nil end
  local ok, v = pcall(fn, ...)
  return ok and plain(v) or nil
end

DP.App.party = function(_, db)
  local P = NS.Party
  local wave, edit, typed, note, noteAt                   -- the list being sent; taking names off; the name typed; the last answer
  local armed, armedAt, snap, snapAt
  local LOOK = 5                                          -- the guild and friends lists are long: asked at most this often (seconds)
  local asked = {}

  local function on() return R:Enabled("party") end
  local function say(words, ...) note, noteAt = words:format(...), now() end
  --- A long list, kept for a few seconds (a press that changes something drops them all).
  local function slow(key, fn)
    local e, t = asked[key], now()
    if not e or t - e.at > LOOK or t < e.at then e = { at = t, v = try(fn) or {} } asked[key] = e end
    return e.v
  end
  local function drop(lists) snap = nil if lists then asked = {} end end
  --- Two presses for what hurts: the first asks, for 5 s.
  local function sure(key, word, fn, tip)
    local hot = armed == key and now() - armedAt < 5
    return { word = hot and "SURE?" or word, peek = true, tip = tip, fn = function()
      if armed == key and now() - armedAt < 5 then armed = nil drop() return fn() end
      armed, armedAt = key, now()
    end }
  end
  local function leads() return try(P.Leads) and true or false end
  local function isLeader() return try(UnitIsGroupLeader, "player") == true end

  --- Everybody on the list and where they are, once a paint.
  local function look()
    local t = now()
    if snap and snapAt == t then return snap end
    local s = { list = {}, here = {}, waits = {}, with = 0, off = 0, todo = {}, members = try(P.Members) or {} }
    for _, m in ipairs(s.members) do s.here[m.key] = true end
    s.out = P.Out(s.members)                              -- (and forgets those who came, or whose invite ran out)
    for _, n in ipairs(P.queue or {}) do s.waits[P.Key(n) or "?"] = true end
    for _, n in ipairs(P.held and P.held.names or {}) do s.waits[P.Key(n) or "?"] = true end
    local who = slow("who", P.Lookup)
    for i, n in ipairs(P.List(db())) do
      local e = { name = n, key = P.Key(n) or "?" }
      local w = who[e.key]
      if s.here[e.key] then e.right, e.ink, e.st = "WITH YOU", "good", "with" s.with = s.with + 1
      elseif P.out[e.key] then e.right, e.ink, e.st = "ASKED", "gold", "asked"
      elseif s.waits[e.key] then e.right, e.ink, e.st = "NEXT", "gold", "asked"
      elseif w and w.online == false then e.right, e.ink, e.st = "OFFLINE", "dim", "off" s.off = s.off + 1
      else
        e.right, e.ink, e.st = w and "ONLINE" or "?", w and "ink" or "ink2", "todo"
        s.todo[#s.todo + 1] = n
      end
      s.list[i] = e
    end
    snap, snapAt = s, t
    return s
  end
  local function state(name, s)
    local k = P.Key(name) or "?"
    if s.here[k] then return "WITH YOU", "good" end
    if P.out[k] then return "ASKED", "gold" end
    if P.Suggested and P.Suggested(name) then return "SUGGESTED", "gold" end
    if s.waits[k] then return "NEXT", "gold" end
  end
  local function pending()
    local n = #(P.queue or {}) + #(P.held and P.held.names or {})
    if next(P.out) ~= nil then n = n + look().out end
    return n
  end

  --- The window's own wave, worked out with ours in its place (the old window may have one of its own).
  local function withWave(fn)
    local kw, kp, kh, ko = P.wave, P.pending, P.pendingHere, P.pendingOff
    P.wave = wave
    local ok, a, b = pcall(fn)
    P.wave, P.pending, P.pendingHere, P.pendingOff = kw, kp, kh, ko
    if not ok then error(a, 0) end
    return a, b
  end
  --- The wave now: { lines (the confirm list's own), send = names to ask, asked, here, label }.
  local function waveNow()
    local s = look()
    local out = { send = {}, asked = 0, here = 0 }
    withWave(function()
      local entries, here, off, label = P.WaveList(wave)
      P.pending, P.pendingHere, P.pendingOff = entries, here, off
      out.lines, out.label, out.here = P.ConfirmLines(), label, #here
      for _, e in ipairs(entries) do
        if state(e.name, s) then out.asked = out.asked + 1 else out.send[#out.send + 1] = e.name end
      end
    end)
    return out
  end
  local function suggests() return P.Suggests and P.Suggests() or false end
  local function suggest(name)
    P.saidError, P.failed, P.lastError = nil, 0, nil
    if P.Suggest(name) then say("Suggested %s to the leader.", name) end
    drop()
  end
  local function invite(names, one)
    if #names == 0 then return end
    P.saidError, P.failed, P.lastError = nil, 0, nil                        -- (as the window's own run starts: a refusal is said once)
    local n = P.InviteNames(db(), names, true)
    if n > 0 then say(one and "Asked %s." or "Asked %d.", one or n) else say("Only the leader or an assistant can invite.") end
    drop()
  end
  local function open(grow)
    wave = wave or { db = db(), dropped = {} }
    grow(wave)
    edit = nil
    drop(true)
    local w = waveNow()
    if #w.send == 0 and w.asked == 0 then
      wave = nil
      say("Nobody to ask: all with you, or offline.")
      return false
    end
    if D and D.defs["BiSTools:tool-party"] then D.defs["BiSTools:tool-party"].tab = 1 end
    return true
  end
  local function refresh()
    try((C_GuildInfo and C_GuildInfo.GuildRoster) or GuildRoster)
    drop(true)
    say("Looked again.")
  end

  -- the three lists --------------------------------------------------------------------------------------------------

  local function waveRows()
    local out, s = {}, look()
    for i, l in ipairs(waveNow().lines) do
      local r = { text = l.text, done = (l.head or l.here) and true or nil }
      if l.entry then
        local e = l.entry
        r.text = e.name
        r.right, r.ink = state(e.name, s)
        if not r.right then
          r.side = { word = "OUT", peek = true, tip = "Not this time", fn = function() wave.dropped[P.Key(e.name) or "?"] = true drop() end }
        end
      elseif l.here and not l.head then r.mark = "-" end
      out[i] = r
    end
    return out
  end
  local function listRows()
    local out, s, lead = {}, look(), leads()
    local last = db().lastWith
    for i, e in ipairs(s.list) do
      local l = type(last) == "table" and last[e.key] or nil
      local ago = l and P.Ago(l.t)
      local tip = ago and ("Last grouped " .. (ago == "now" and "now" or ago .. " ago") .. (l.zone and (", " .. l.zone) or "")) or "Not grouped yet"
      -- (the colour pass, 22 Nov: when you last grouped, under the name)
      local r = { mark = tostring(i), text = e.name, right = e.right, ink = e.ink, done = e.st == "off",
        sub = ago and ((ago == "now" and "grouped now" or "grouped " .. ago .. " ago") .. (l.zone and (", " .. l.zone) or "")) or "not grouped yet" }
      if e.right == "?" then tip = tip .. "\nNot in your guild or friends: the game does not say if they are on" end
      if edit then
        r.right = nil
        r.side = sure("off" .. e.key, "REMOVE", function() P.Remove(db(), e.name) P.Changed() say("%s is off the list.", e.name) end, "Off your list")
      elseif e.st == "todo" and lead then
        r.act = { word = "invite", fn = function() invite({ e.name }, e.name) end }
        tip = tip .. "\nClick: invite"
      elseif e.st == "todo" and suggests() and P.Suggested(e.name) then
        r.right, r.ink = "SUGGESTED", "gold"
      elseif e.st == "todo" and suggests() and not P.Suggested(e.name) then
        r.act, r.verb = { word = "suggest", fn = function() suggest(e.name) end }, "SUGGEST"
        tip = tip .. "\nClick: the leader is asked to invite them"
      end
      r.tip = tip
      out[i] = r
    end
    return out
  end
  local function picks() local n = 0 for _ in pairs(P.picked or {}) do n = n + 1 end return n end
  local function rankRows()
    local out = {}
    for i, r in ipairs(slow("ranks", P.Ranks)) do
      local k = r.rank:lower()
      local picked = P.picked and P.picked[k]
      out[i] = { mark = picked and "v" or "", text = r.rank, right = r.n > 0 and (r.n .. " ON") or "-", ink = picked and "good" or "ink2", done = r.n == 0,
        tip = r.n == 0 and "Nobody else online" or picked and "Click: not this rank" or "Click: pick this rank",
        act = r.n > 0 and { word = "pick", peek = true, fn = function()
          P.picked = P.picked or {}
          P.picked[k] = (not P.picked[k]) or nil
          P.PaintWindow()
        end } or nil }
    end
    return out
  end
  local function friendRows()
    local out, s, lead = {}, look(), leads()
    for i, f in ipairs(slow("friends", P.FriendsOnline)) do
      local has = P.Has(db(), f.name)
      local r = { mark = has and "v" or "", text = f.name }
      r.right, r.ink = state(f.name, s)
      local free = not r.right
      if free then r.right, r.ink = "ONLINE", "good" end
      if free then
        if lead then r.act = { word = "invite", fn = function() invite({ f.name }, f.name) end }
        elseif suggests() then r.act, r.verb = { word = "suggest", fn = function() suggest(f.name) end }, "SUGGEST" end
        r.tip = lead and "Click: invite" or suggests() and "Click: the leader is asked to invite them" or "Only the leader or an assistant can invite"
        r.side = { word = has and "- LIST" or "+ LIST", peek = true, tip = has and "Off your list" or "On your list", fn = function()
          if has then P.Remove(db(), f.name) else
            local ok, why = P.Add(db(), f.name)
            if not ok then say("%s", tostring(why)) end
          end
          drop() P.Changed()
        end }
      end
      out[i] = r
    end
    return out
  end

  local function save()
    local n = P.SaveGroup(db())
    drop() P.Changed()
    say(n > 0 and "Saved: %d on your list." or "Nobody to save: you are not in a group.", n)
  end
  --- What the big button of the list asks for: the whole list, checked first.
  local function bigList()
    local s = look()
    if wave then
      local w = waveNow()
      if #w.send > 0 and leads() then
        return { word = "SEND " .. #w.send .. (#w.send == 1 and " INVITE" or " INVITES"), tip = w.label, fn = function() invite(waveNow().send) end }
      end
      return { word = "DONE", peek = true, fn = function() wave = nil drop() end, tip = "Back to your list" }
    end
    if edit then return nil end
    if #s.list == 0 then return #s.members > 0 and { word = "SAVE MY GROUP", fn = save } or nil end
    if #s.todo > 0 and leads() then
      return { word = "INVITE " .. #s.todo, peek = true, tip = "Look the list over, then send", fn = function() open(function(w) w.party = true end) end }
    end
  end

  return {
    badge = function() local n = on() and pending() or 0 return n > 0 and n or nil end,
    card = {
      when = "use", tick = true,
      alive = function() return on() and (wave ~= nil or pending() > 0) end,
      prio = function() return on() and (pending() > 0 and 6 or wave and 4) or nil end,
      lines = function()
        local s, n = look(), pending()
        local list = {}
        for _, e in ipairs(s.list) do if e.st ~= "with" and e.st ~= "off" and #list < 3 then list[#list + 1] = { e.name, e.right } end end
        local words = #s.list > 0 and (s.with .. " of " .. #s.list .. " with you") or ((#s.members + 1) .. " in the group")
        return { "PARTY", "", words, n > 0 and (n .. " ASKED") or "", "gold", hot = n > 0, list = list }
      end,
      buttons = function()
        local names = wave and waveNow().send or look().todo
        if #names == 0 or not leads() then return {} end
        local b = sure("card", "INVITE " .. #names, function() invite(wave and waveNow().send or look().todo) end)
        b.peek = nil
        return { b }
      end,
    },
    page = {
      tick = true,
      tour = { { text = "Your usual group: who is with you, who is on, who is missing.", note = "SAVE keeps the group you are in now." },
        { text = "INVITE shows who would be asked. Nothing goes out before SEND." } },
      kicker = function()
        if wave then return "look it over, then send" end
        local s = look()
        return #s.members > 0 and ((#s.members + 1) .. " in the group") or "on your own"
      end,
      tabs = function() return { wave and "SEND" or "LIST", "GUILD", "FRIENDS" } end,
      find = function(tab)
        if tab ~= 1 or wave then return nil end
        return { hint = "add a name, enter", get = function() return typed or "" end, set = function(w) typed = w end, enter = function(w)
          local name = (w or ""):match("^%s*(.-)%s*$")
          typed = nil
          if name == "" then return end
          local ok, why = P.Add(db(), name)
          drop() P.Changed()
          if ok then say("%s is on your list.", name) else say("%s: %s.", name, tostring(why)) end
        end }
      end,
      boxes = function(tab)
        local s = look()
        if tab == 2 then return nil end
        if wave and tab == 1 then
          local w = waveNow()
          return { { "TO SEND", #w.send, "gold" }, { "ASKED", w.asked, "accent" }, { "WITH YOU", w.here, "good" } }
        end
        if tab == 3 then return { { "ONLINE", #slow("friends", P.FriendsOnline), "good" }, { "ASKED", pending(), "gold" } } end
        if #s.list == 0 then return nil end
        return { { "WITH YOU", s.with .. " / " .. #s.list, "good" }, { "TO ASK", #s.todo, "gold" }, { "OFFLINE", s.off, "dim" } }
      end,
      rows = function(tab)
        if tab == 2 then return rankRows() end
        if tab == 3 then return friendRows() end
        return wave and waveRows() or listRows()
      end,
      text = function(tab)
        if tab == 2 then return #slow("ranks", P.Ranks) == 0 and "You are not in a guild, or its list has not come yet: press REFRESH." or nil end
        if tab == 3 then return #slow("friends", P.FriendsOnline) == 0 and "None of your friends is online in this game." or nil end
        return not wave and #P.List(db()) == 0 and "Your list is empty. In a group: SAVE. Or type a name above, or take friends from the FRIENDS tab." or nil
      end,
      say = function(tab)
        if note and now() - noteAt < 8 then return note end
        if P.held then return #P.held.names .. " wait for the raid: they are asked once somebody joins." end
        if P.lastError and pending() > 0 then return "The game said: " .. tostring(P.lastError) end
        if not leads() then return suggests() and "Not the leader: SUGGEST asks the leader to invite them." or "Only the leader or an assistant can invite." end
        if tab == 2 then return picks() > 0 and (picks() .. " picked") or "Click the ranks you want." end
        if db().keyword then return "Whisper \"" .. P.Keyword(db()) .. "\": they are invited by themselves." end
      end,
      big = function(tab)
        if tab == 3 then return nil end
        if tab == 2 then
          local n = picks()
          if n == 0 or not leads() then return nil end
          return { word = (wave and "ADD " or "INVITE ") .. n .. (n == 1 and " RANK" or " RANKS"), peek = true, tip = "Look them over, then send", fn = function()
            open(function(w)
              w.ranks = w.ranks or {}
              for k in pairs(P.picked or {}) do w.ranks[k] = true end
            end)
          end }
        end
        return bigList()
      end,
      keys = function(tab)
        local s, out = look(), {}
        if tab == 1 and wave then
          out[1] = { word = "REFRESH", peek = true, fn = refresh, tip = "Who is online now" }
          out[2] = { word = "CANCEL", peek = true, fn = function() wave = nil drop() end, tip = "Nobody is asked" }
          return out
        end
        if tab ~= 1 then
          out[1] = { word = "REFRESH", peek = true, fn = refresh, tip = "Who is online now" }
          if tab == 2 and picks() > 0 then out[2] = { word = "NONE", peek = true, fn = function() P.picked = {} P.PaintWindow() end, tip = "No rank picked" } end
          return out
        end
        if #s.members > 0 then
          out[#out + 1] = #s.list > 0 and sure("save", "SAVE", save, "The group you are in now becomes your list") or { word = "SAVE", fn = save }
        end
        if #s.list > 0 then
          out[#out + 1] = { word = edit and "DONE" or "EDIT", peek = true, fn = function() edit = not edit or nil end, tip = "Take names off your list" }
          if not edit then out[#out + 1] = { word = "REFRESH", peek = true, fn = refresh, tip = "Who is online now" } end
        end
        if #s.members > 0 and not edit then
          out[#out + 1] = sure("disband", isLeader() and "DISBAND" or "LEAVE", function() P.Disband() drop(true) end,
            isLeader() and "Everyone out of the group" or "You leave the group")
        end
        return out
      end,
    },
  }
end
