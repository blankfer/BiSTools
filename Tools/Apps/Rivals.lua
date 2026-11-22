-- BiSTools / Tools / Apps / Rivals.lua - rivals, pals and griefers in the phone (dev/APPS.md). The engine and the lists are Recap.lua's
-- (NS.Recap, read through RC.DB()); every change goes through its own functions. A click on a row shows what is known about them.
local _, NS = ...
local DP, R = NS.DeckPages, NS.Registry
if not (DP and DP.App) then return end

local function plain(v)
  if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
  return v
end
local function now() return GetTime and plain(GetTime()) or 0 end
local function clean(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")) end
--- A typed name as the game writes one: every word with a capital.
local function proper(s) return (clean(s):gsub("(%S)(%S*)", function(a, b) return a:upper() .. b:lower() end)) end
local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  return ok and plain(v) or nil
end

DP.App.rivals = function()
  local RC, P = NS.Recap, NS.Party
  local words, sel = { "", "", "" }, {}                   -- the search line and who is looked at, a tab
  local mates, note, noteAt, noteTab, armed, armedAt, who, whoAt, guild, guildAt
  local NEWS = 120                                        -- seen this long ago (seconds) is still news

  local function on() return R:Enabled("rivals") end
  local function say(tab, w) note, noteAt, noteTab = w, now(), tab end
  local function wall() return time and time() or 0 end
  local function ago(t) return t and P.Ago(t) or "-" end                     -- (a saved time)
  local function agoNow(t) return t and P.Ago(t, now()) or "-" end           -- (one of this session)
  local function sure(key, word, fn, tip)
    local hot = armed == key and now() - armedAt < 5
    return { word = hot and "SURE?" or word, peek = true, tip = tip, fn = function()
      if armed == key and now() - armedAt < 5 then armed = nil return fn() end
      armed, armedAt = key, now()
    end }
  end
  local function lookup()                                 -- (the whole guild and friends list: at most every 5 s)
    if not who or now() - whoAt > 5 or now() < whoAt then who, whoAt = ask(P.Lookup) or {}, now() end
    return who
  end
  local function guildOnline()
    if not guild or now() - guildAt > 5 or now() < guildAt then guild, guildAt = ask(P.GuildOnline) or {}, now() end
    return guild
  end
  local function fits(tab, name)
    local w = clean(words[tab]):lower()
    if tab == 3 then w = w:match("^(.-)%s+%-%s") or w end                    -- ("Name Surname - why")
    return w == "" or name:lower():find(w, 1, true) ~= nil
  end
  local function className(file)
    if type(file) ~= "string" or file == "" then return nil end
    return (LOCALIZED_CLASS_NAMES_MALE or {})[file] or (file:sub(1, 1) .. file:sub(2):lower())
  end

  -- the people ---------------------------------------------------------------------------------------------------------

  --- The rivals as their window sorts them: gold, the guild's, silver, the last seen first; then the surnames.
  local function rivals()
    local d, out = RC.DB(), {}
    for name, r in pairs(RC.Rivals(d)) do out[#out + 1] = { name = name, r = r, rank = r.active and 1 or 3, kind = r.active and "gold" or "silver" } end
    if d.guildShow ~= false then
      for name, e in pairs(RC.GuildRivals(d)) do
        if not RC.Rivals(d)[name] then out[#out + 1] = { name = name, r = e, rank = 2, kind = "guild" } end
      end
    end
    for _, w in pairs(RC.Surnames(d)) do out[#out + 1] = { name = w, r = {}, rank = 4, kind = "surname" } end
    return out
  end
  local function pals()
    local out = {}
    for name, p in pairs(RC.Pals(RC.DB())) do out[#out + 1] = { name = name, r = p, rank = 1, kind = "pal" } end
    return out
  end
  local function griefers()
    local out = {}
    for name, g in pairs(RC.Griefers(RC.DB())) do out[#out + 1] = { name = name, r = g, rank = 1, kind = "griefer" } end
    return out
  end
  local function people(tab)
    local out = {}
    for _, e in ipairs(tab == 1 and rivals() or tab == 2 and pals() or griefers()) do if fits(tab, e.name) then out[#out + 1] = e end end
    table.sort(out, function(a, b)
      if a.rank ~= b.rank then return a.rank < b.rank end
      local x, y = tonumber(a.r.seen or a.r.added) or 0, tonumber(b.r.seen or b.r.added) or 0
      if x ~= y then return x > y end
      return a.name < b.name
    end)
    return out
  end
  --- Who is looked at: the one clicked, else the first.
  local function picked(tab)
    local list = people(tab)
    for _, e in ipairs(list) do if e.name == sel[tab] then return e end end
    return list[1]
  end

  -- what is known ------------------------------------------------------------------------------------------------------

  local function known(e)
    local out, r = {}, e.r
    if e.kind == "surname" then return "Everyone with this surname wears a gold crown. Enemies are called out." end
    local w = e.kind == "pal" and lookup()[P.Key(e.name) or "?"] or nil
    out[#out + 1] = className(r.class) or (w and (w.class or className(w.classFile))) or nil
    if e.kind == "gold" then out[#out + 1] = "gold, you are told when near"
    elseif e.kind == "silver" then out[#out + 1] = "silver, kept but quiet"
    elseif e.kind == "guild" then out[#out + 1] = "your guild's" .. (r.by and (", from " .. tostring(r.by)) or "") end
    if r.bg then out[#out + 1] = "this match only" end
    if type(r.where) == "string" and r.where ~= "" then out[#out + 1] = r.where .. (r.seenBy and (" (" .. tostring(r.seenBy) .. ")") or "") end
    if e.kind == "griefer" then out[#out + 1] = (type(r.why) == "string" and r.why ~= "") and r.why or "No note yet: press WHY" end
    if #out == 0 then out[1] = "A green heart over them, out of a fight" end
    return table.concat(out, " - ")
  end
  local function boxes(tab)
    local e = not (tab == 2 and mates) and picked(tab) or nil
    if not e or e.kind == "surname" then return nil end
    local r = e.r
    if tab == 1 then
      return { { "KILLED YOU", r.kills or 0, (r.kills or 0) > 0 and "gold" or "dim" }, { "SEEN", ago(r.seen), "ink" }, { "ADDED", ago(r.added), "ink2" } }
    end
    if tab == 2 then
      local w = lookup()[P.Key(e.name) or "?"]
      return { { "ONLINE", w and (w.online and "YES" or "NO") or "?", w and w.online and "good" or "dim" }, { "NEAR", agoNow((RC.palSeenAt or {})[e.name]), "ink" },
        { "ADDED", ago(r.added), "ink2" } }
    end
    return { { "IN GROUP", (RC.griefInGroup or {})[e.name] and "YES" or "NO", (RC.griefInGroup or {})[e.name] and "gold" or "dim" },
      { "NEAR", agoNow((RC.griefSeen or {})[e.name .. "|near"]), "ink" }, { "ADDED", ago(r.added), "ink2" } }
  end

  -- changes: the tool's own ----------------------------------------------------------------------------------------------

  local function remove(e)
    local d = RC.DB()
    RC.db = RC.db or d
    if e.kind == "gold" or e.kind == "silver" then RC.ToggleRival(d, { player = true, title = e.name })
    elseif e.kind == "guild" then RC.GuildDel(d, e.name)
    elseif e.kind == "surname" then RC.Surname(d, e.name) RC.PaintRivals()
    elseif e.kind == "pal" then RC.MatePal(d, e.name)
    else local recap = R:Get("recap") recap.OnSlash(recap, d, "grief forget " .. e.name) end
    say((e.kind == "pal" and 2) or (e.kind == "griefer" and 3) or 1, e.name .. " is off the list.")
  end
  local TIP = { gold = "Click: what is known. Gold: you are told when they are near.", silver = "Click: what is known. Silver: kept, but quiet.",
    guild = "Click: what is known. Your guild shares this one.", surname = "Click: what is known. Everyone with this surname.",
    pal = "Click: what is known.", griefer = "Click: what is known." }
  local MARK = { gold = "*", silver = "-", guild = "+", surname = "=", pal = "", griefer = "!" }
  local function rows(tab)
    local out, d = {}, RC.DB()
    if tab == 2 and mates then
      local list = {}
      for _, m in ipairs(guildOnline()) do if fits(2, m.name) then list[#list + 1] = m end end
      table.sort(list, function(a, b)
        local x, y = RC.IsMatePal(d, a.name) and 1 or 0, RC.IsMatePal(d, b.name) and 1 or 0
        if x ~= y then return x > y end
        return a.name < b.name
      end)
      for i, m in ipairs(list) do
        local pal = RC.IsMatePal(d, m.name)
        out[i] = { mark = pal and "v" or "", text = m.name, tip = (m.class and (m.class .. "\n") or "") .. (m.rank or ""),
          side = pal and sure("mate" .. m.name, "- PAL", function() RC.MatePal(d, m.name) end, "No longer a pal")
            or { word = "+ PAL", tip = "A pal: a green heart over them", peek = true, fn = function() RC.MatePal(d, m.name) end } }
      end
      return out
    end
    local e0 = picked(tab)
    for i, e in ipairs(people(tab)) do
      local mine = e0 and e.name == e0.name and e.kind == e0.kind
      out[i] = { mark = mine and ">" or MARK[e.kind], text = e.kind == "surname" and ("All named " .. e.name) or e.name,
        done = e.kind == "silver" and not mine or nil,
        tip = TIP[e.kind] .. (e.kind == "surname" and "" or "\n" .. known(e)),
        act = { word = "look", peek = true, fn = function() sel[tab], note = e.name, nil end },
        side = sure(tab .. e.kind .. e.name, "REMOVE", function() remove(e) end, e.kind == "guild" and "Off your guild's list, for everyone" or "Off your list") }
    end
    return out
  end
  --- Your target's whole name, when it is a player who is not you and the game says so plainly.
  local function target()
    if ask(UnitExists, "target") ~= true or ask(UnitIsPlayer, "target") ~= true or ask(UnitIsUnit, "target", "player") == true then return nil end
    local name = ask(GetUnitName, "target", false)
    if type(name) ~= "string" or name == "" then name = ask(UnitName, "target") end
    if type(name) ~= "string" or name == "" or name == (UNKNOWNOBJECT or "Unknown") then return nil end
    return name
  end
  local function addTarget(tab)
    local d, name = RC.DB(), target()
    RC.db = RC.db or d
    if not name then return say(tab, tab == 1 and "Target an enemy player first." or "Target a friendly player first.") end
    local friendly = RC.Friendly("target")
    if tab == 1 then
      local _, key = RC.Find(d, name)
      if key then sel[1] = key return say(1, key .. " is on the list already.") end
      if friendly then return say(1, name .. " is friendly: rivals are enemies.") end
      RC.RivalFromTarget(d)
    elseif not friendly then return say(tab, name .. " is an enemy: that is a rival.")
    elseif tab == 2 then
      local _, key = RC.PalFor(d, "target")
      if key then sel[2] = key return say(2, key .. " is a pal already.") end
      RC.PalFromTarget(d)
    else
      local _, key = RC.GrieferNamed(d, name)
      if key then sel[3] = key return say(3, key .. " is on the list already.") end
      RC.AskGriefer(d, name, ask(UnitGUID, "target"))
    end
    sel[tab], note = name, nil
  end
  local function badName(name) return name == "" or #name > 40 or name:find("[%d%%%(%)%[%]%.,;:!%?/\\|]") ~= nil end
  --- Enter on the search line: a pal or a griefer by name (a rival is only ever somebody you saw).
  local function enter(tab, w)
    local d = RC.DB()
    local name, why = clean(w), nil
    if tab == 3 then
      local a, b = name:match("^(.-)%s+%-%s+(.+)$")
      name, why = a or name, b
    end
    if name == "" then return end
    name = proper(name)
    for _, e in ipairs(tab == 1 and rivals() or tab == 2 and pals() or griefers()) do       -- there already: shown, never switched off
      local key, first = e.name:lower(), e.name:match("^(%S+)")
      if key == name:lower() or (tab == 2 and (not name:find(" ", 1, true) or not e.name:find(" ", 1, true)) and first:lower() == name:match("^(%S+)"):lower()) then
        sel[tab] = e.name
        if why then RC.AddGriefer(d, e.name, why) note = nil else say(tab, e.name .. " is on the list already.") end
        words[tab] = ""
        return
      end
    end
    if tab == 1 then return end
    if badName(name) then return say(tab, "That is not a name.") end
    if tab == 2 then RC.PalByName(d, name) else RC.AddGriefer(d, name, why) end
    sel[tab], words[tab], note = name, "", nil
  end

  -- the news -----------------------------------------------------------------------------------------------------------

  --- Who was seen just now, the newest first: { word, name, at (seconds ago), list }.
  local function news()
    local d, best = RC.DB(), nil
    local function take(word, name, s, list) if s >= 0 and s < NEWS and (not best or s < best.s) then best = { word = word, name = name, s = s, list = list } end end
    for name, r in pairs(RC.Rivals(d)) do
      if r.active and type(r.seen) == "number" then
        local list = {}
        if type(r.where) == "string" and r.where ~= "" then list[1] = { r.where } end
        if (r.kills or 0) > 0 then list[#list + 1] = { "Killed you", tostring(r.kills) } end
        take("RIVAL NEAR", name, wall() - r.seen, list)
      end
    end
    for name, g in pairs(RC.Griefers(d)) do
      local why = (type(g.why) == "string" and g.why ~= "") and { { g.why } } or nil
      local at, inv = (RC.griefSeen or {})[name .. "|near"], (RC.griefSeen or {})[name .. "|invite"]
      if type(at) == "number" then take("GRIEFER NEAR", name, now() - at, why) end
      if type(inv) == "number" then take("GRIEFER INVITED YOU", name, now() - inv, why) end
    end
    return best
  end
  local function inGroup() return (next(RC.griefInGroup or {})) end

  return {
    name = "Rivals",
    badge = function() return on() and (inGroup() or news()) and 1 or nil end,
    card = {
      tick = true,
      prio = function()
        if not on() then return nil end
        local g = inGroup()
        if g then                                         -- (urgent when they come in; after that it only stays there)
          local at = (RC.griefSeen or {})[g .. "|group"]
          if type(at) == "number" and now() - at < NEWS then return 9 end
        end
        return news() and 8 or g and 4 or nil
      end,
      lines = function()
        local g, n = inGroup(), news()
        local at = g and (RC.griefSeen or {})[g .. "|group"]
        local fresh = type(at) == "number" and now() - at < NEWS
        if g and (fresh or not n) then
          local why = (RC.Griefers(RC.DB())[g] or {}).why
          return { "GRIEFER IN YOUR GROUP", "", g, "", "gold", hot = fresh, list = (type(why) == "string" and why ~= "") and { { why } } or {} }
        end
        if not n then return { "RIVALS", "", "Nobody near", "", "dim" } end
        return { n.word, "", n.name, ("%ds"):format(math.floor(n.s)), "gold", hot = n.s < 30, list = n.list or {} }
      end,
    },
    page = {
      tick = true,
      title = function() return "Rivals & pals" end,
      kicker = function() local n = news() return n and (n.word:lower() .. ": " .. n.name) or "who you hunt, who you like" end,
      tour = { { text = "RIVALS are enemies you hunt, PALS are friends, GRIEFERS are your own side.", note = "You are told when one is near." },
        { text = "Target somebody and press the big button, or type a name. Click a name: what is known." } },
      tabs = function() return { "RIVALS", "PALS", "GRIEFERS" } end,
      find = function(tab)
        local hint = tab == 1 and "search, or a surname" or tab == 2 and (mates and "search the guild" or "search, or add: Name Surname") or "add: Name Surname - why"
        return { hint = hint, get = function() return words[tab] or "" end, set = function(w) words[tab] = w end,
          enter = function(w) if not (tab == 2 and mates) then enter(tab, w) end end }
      end,
      boxes = boxes,
      rows = rows,
      text = function(tab)
        if #rows(tab) > 0 then return nil end
        if clean(words[tab]) ~= "" then
          return tab == 1 and "No rival is called that." or (tab == 2 and mates) and "Nobody online is called that." or "Nobody is called that. Enter adds them."
        end
        if tab == 1 then return "No rivals yet. Target an enemy player and press the big button, or click a killer on your death recap." end
        if tab == 2 and mates then return "Nobody else in your guild is online." end
        if tab == 2 then return "No pals yet. Target a friend and press the big button, type a name, or press GUILD." end
        return "Nobody yet. Somebody on your own side stole or spoiled? Target them and press the big button, or type: Name Surname - why."
      end,
      say = function(tab)
        if note and noteTab == tab and now() - noteAt < 6 then return note end
        local e = not (tab == 2 and mates) and picked(tab) or nil
        return e and (e.name .. ": " .. known(e)) or nil
      end,
      big = function(tab)
        if tab == 2 and mates then return nil end
        local name = target()
        return { word = name and ("ADD " .. name) or "ADD MY TARGET", peek = true, fn = function() addTarget(tab) end }
      end,
      keys = function(tab)
        local d, out, e = RC.DB(), {}, not (tab == 2 and mates) and picked(tab) or nil
        if tab == 1 then
          if e and (e.kind == "gold" or e.kind == "silver") then
            out[1] = { word = e.kind == "gold" and "SILVER" or "GOLD", peek = true, tip = e.kind == "gold" and "Kept, but quiet" or "Tell me when they are near",
              fn = function() RC.db = RC.db or d RC.SetActive(d, e.name, e.kind ~= "gold") sel[1] = e.name end }
            if IsInGuild and ask(IsInGuild) and d.guildShow ~= false and not RC.GuildRivals(d)[e.name] then
              out[2] = sure("share" .. e.name, "SHARE", function() RC.GuildAdd(d, e.name, e.r.class, nil, false) end, "A guild rival: your guild sees them in amber")
            end
          elseif e and e.kind == "guild" then
            out[1] = { word = "MAKE MINE", peek = true, tip = "Gold on your own list too",
              fn = function() RC.ToggleRival(d, { player = true, title = e.name, class = e.r.class }) sel[1] = e.name end }
          end
          local w = clean(words[1])
          if w ~= "" and not w:find(" ", 1, true) and not badName(w) and not RC.Surnames(d)[w:lower()] then
            out[#out + 1] = { word = "CROWN", peek = true, tip = "Everyone with the surname " .. w .. ": a gold crown, enemies called out",
              fn = function() RC.Surname(d, proper(w)) words[1] = "" say(1, "Everyone named " .. proper(w) .. " wears a crown.") end }
          end
        elseif tab == 2 then
          if mates or (IsInGuild and ask(IsInGuild)) then
            out[1] = { word = mates and "MY PALS" or "GUILD", peek = true, tip = mates and "Back to your pals" or "Guildmates online: add them", fn = function()
              mates, words[2] = not mates or nil, ""
              if mates then guild = nil ask((C_GuildInfo and C_GuildInfo.GuildRoster) or GuildRoster) end
            end }
          end
          if e and ChatFrame_SendTell then
            out[#out + 1] = { word = "WHISPER", peek = true, tip = "Write to " .. e.name, fn = function() pcall(ChatFrame_SendTell, e.name) end }
          end
        elseif e then
          out[1] = { word = "WHY", peek = true, tip = "Write down what they did", fn = function() RC.AskGriefer(d, e.name, e.r.guid) end }
        end
        return out
      end,
    },
  }
end
