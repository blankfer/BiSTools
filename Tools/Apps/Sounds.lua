-- BiSTools / Tools / Apps / Sounds.lua - the sound explorer in the phone (dev/APPS.md). Its work is Tools/Sounds.lua's (NS.Sounds).
local _, NS = ...
local DP, R = NS.DeckPages, NS.Registry
if not (DP and DP.App) then return end

local function plain(v)
  if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
  return v
end
local function now() return GetTime and plain(GetTime()) or 0 end
--- "IG_MAINMENU_OPTION" -> "Mainmenu option": the game's own names are too wide in capitals (the whole one is under the mouse).
local function pretty(name)
  if not name:find("^[%u%d_]+$") then return name end
  local s = name:lower():gsub("^ig_", ""):gsub("_", " ")
  return s:sub(1, 1):upper() .. s:sub(2)
end
local function base(path) return tostring(path):match("([^\\/]+)$") or tostring(path) end

DP.App.sounds = function(_, db)
  local X = NS.Sounds
  local words, typed = "", ""                             -- the search line; the file being typed
  local rowOf = setmetatable({}, { __mode = "k" })
  local kept, sig, names, armed, armedAt

  local function on() return R:Enabled("sounds") end
  --- Is the last one still on? The client's own answer where it has one; without it: until STOP.
  local function sounding()
    if X.handle == nil then return false end
    local ask = C_Sound and C_Sound.IsPlaying
    if not ask then return true end
    local ok, v = pcall(ask, X.handle)
    if not ok or (issecretvalue and issecretvalue(v)) then return true end
    return v and true or false
  end
  local function lastName()
    local last = X.last
    if type(last) == "string" then return base(last) end
    local fav = (db().favs or {})[last]
    if fav then return pretty(tostring(fav)) end
    if not names then
      names = {}
      for _, e in ipairs(X.All()) do names[e.id] = e.name end
    end
    return names[last] and pretty(names[last]) or ("Sound " .. tostring(last))
  end
  local function again() X.Play(type(X.last) == "string" and { file = X.last } or X.last) end
  local function hot(what) return what ~= nil and armed == what and now() - armedAt < 5 end

  --- The tool's own search, with the phone's words (the old window keeps its own).
  local function found(q)
    local keepF, keepT = X.filter, X.typed
    X.filter, X.typed = q, nil
    local ok, out = pcall(X.Shown, { files = {}, favs = {} })
    X.filter, X.typed = keepF, keepT
    return ok and out or {}
  end
  local function list(tab)
    local d, out = db(), {}
    if tab == 3 then
      for _, p in ipairs(d.files or {}) do out[#out + 1] = { name = p, file = p } end
      return out
    end
    local want = words:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if tab == 2 then
      for _, e in ipairs(X.Favs(d)) do
        if want == "" or e.name:lower():find(want, 1, true) or pretty(e.name):lower():find(want, 1, true) or tostring(e.id) == want then out[#out + 1] = e end
      end
      return out
    end
    out = found((want:gsub("%s+", "_")))
    if #out == 0 and want:find(" ", 1, true) then out = found(want) end
    local n = tonumber(want)                              -- an id the game has no name for
    if n and n > 0 and n == math.floor(n) then
      local has
      for _, e in ipairs(out) do if e.id == n then has = true end end
      if not has then table.insert(out, 1, { name = "id " .. n, id = n, typed = true }) end
    end
    return out
  end
  --- Everything the rows hang on, as words: they are made again only when this moved (there are thousands).
  local function mark(tab)
    -- the list itself too: a page drawn before the list was read again (the first visit, now that no card stands in
    -- front of it) must not keep the old rows
    local d, t = db(), { tab, words, tostring(X.last), hot(armed) and armed or "", tostring(X.All()) }
    for id in pairs(d.favs or {}) do t[#t + 1] = id end
    for _, p in ipairs(d.files or {}) do t[#t + 1] = p end
    return table.concat(t, "|")
  end
  local function row(e, d)
    local r = rowOf[e]
    if not r then
      r = { text = e.file and base(e.file) or e.typed and ("Sound " .. e.id) or pretty(e.name),
        tip = (e.file or (e.name .. "  " .. tostring(e.id))) .. "\nClick: hear it", act = { word = "hear", fn = function() X.Play(e) end }, side = { peek = true } }
      if e.file then
        r.side.tip = "Forget this file (the file itself stays)"
        r.side.fn = function()
          if hot(e.file) then armed = nil X.Star(db(), e) else armed, armedAt = e.file, now() end
        end
      else
        r.side.tip = "A star keeps it on the STARS tab, with its number"
        r.side.fn = function() X.Star(db(), e) end
      end
      rowOf[e] = r
    end
    local star = not e.file and d.favs and d.favs[e.id]
    local heard = X.last ~= nil and (e.file or e.id) == X.last
    r.mark = heard and ">" or star and "*" or ""
    r.side.word = e.file and (hot(e.file) and "SURE?" or "FORGET") or star and "UNSTAR" or "STAR"
    return r
  end
  local function rows(tab)
    local s = mark(tab)
    if kept and sig == s then return kept end
    local d, out = db(), {}
    for i, e in ipairs(list(tab)) do out[i] = row(e, d) end
    kept, sig = out, s
    return out
  end

  return {
    card = {
      when = "use", tick = true,
      alive = function() return on() and X.last ~= nil end,
      prio = function() return on() and X.last ~= nil and (sounding() and 5 or 3) or nil end,
      lines = function()
        local p = sounding()
        return { "SOUNDS", "", lastName(), p and "PLAYING" or "", "good", hot = p }
      end,
      buttons = function()
        local out = {}
        if sounding() then out[1] = { word = "STOP", peek = true, fn = function() X.Stop() end } end
        out[#out + 1] = { word = "AGAIN", fn = again }
        return out
      end,
    },
    page = {
      tick = true,
      tour = { { text = "Every sound the game has. Click one to hear it.", note = "STAR keeps it, with its number." },
        { text = "MINE plays your own .ogg files. STOP ends a sound that goes on." } },
      kicker = function() return X.last == nil and "click one to hear it" or sounding() and "playing" or "heard" end,
      tabs = function() return { "ALL", "STARS", "MINE" } end,
      boxes = function()                                     -- (the colour pass, 22 Nov: what there is, in numbers)
        local d = db()
        return { { "STARS", #X.Favs(d), "gold" }, { "MINE", #(d.files or {}), "accent" }, { "LAST", type(X.last) == "number" and X.last or X.last and "FILE" or "-", "ink2" } }
      end,
      find = function(tab)
        if tab == 3 then
          return { hint = "BiSHealing\\Media\\click.ogg, enter", get = function() return typed end, set = function(w) typed = w end,
            enter = function(w)
              typed = ""
              local p = X.AddFile(db(), w)
              if p then X.Play({ file = p }) end
            end }
        end
        return { hint = "bell, click, chime... or a number", get = function() return words end, set = function(w) words = w end,
          enter = function()
            local first = rows(tab)[1]
            if words ~= "" and first then first.act.fn() end
          end }
      end,
      rows = rows,
      text = function(tab)
        if #rows(tab) > 0 then return nil end
        if tab == 3 then return "Your own .ogg: put it in a folder under Interface\\AddOns, start the game again, type its path above, press enter." end
        if tab == 2 then return words == "" and "No stars yet. On ALL, press STAR beside a sound." or "No star is called that." end
        return "Nothing is called that. A number plays the sound with that id."
      end,
      say = function()
        if X.last == nil then return "Click a row to hear it." end
        return (sounding() and "PLAYING: " or "Last heard: ") .. lastName() .. (type(X.last) == "number" and ("  " .. X.last) or "")
      end,
      big = function() return { word = "STOP", peek = true, fn = function() X.Stop() end, tip = "Stop the sound: some go on for ever" } end,
      keys = function() return X.last ~= nil and { { word = "AGAIN", fn = again, tip = "Hear the last one again" } } or {} end,
    },
  }
end
