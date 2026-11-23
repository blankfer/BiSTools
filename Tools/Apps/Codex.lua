-- BiSTools / Tools / Apps / Codex.lua - the tool in the phone (dev/APPS.md): the book of creatures.
--
-- DUNGEONS (a place, then its creatures), ALL (by name), MET (yours). A click opens a creature: its model on top, its facts, its
-- abilities, what you saw it drop. Names and spell words come from the client a second late (Codex.lua asks), so a list is built
-- once and kept: FRESH while something is still coming, KEEP otherwise. The turning and the poses are the old windows'.
local _, NS = ...
local DP, R = NS.DeckPages, NS.Registry
if not (DP and DP.App) then return end
local C = NS.Codex
local X = C and C.UI
if not X then return end
local D = BiSTheme and BiSTheme.Deck
local FRESH, KEEP = 1, 15
local TEXT_H = 440                                        -- under this height the place's words give their room to the list
local QUALITY = { [2] = "good", [3] = "slate", [4] = "accent", [5] = "gold" }

local at = { {}, {}, {} }                                 -- where you are, per tab: { d = dungeon, npc, skip }
local find = ""
local kept = {}                                           -- what was built: key -> { at, v, wait }

--- Built once, kept: `make` answers the thing and whether something in it is still on its way.
local function keep(slot, key, make)
  local now, k = GetTime(), kept[slot]
  if k and k.key == key and now - k.at < (k.wait and FRESH or KEEP) and now >= k.at then return k.v end
  local v, wait = make()
  kept[slot] = { key = key, at = now, v = v, wait = wait or next(C.pending) ~= nil }
  return v
end
local function fresh() for k in pairs(kept) do kept[k] = nil end end
C.DeckFresh = fresh

local function into(tab, what, id)
  local p = at[tab]
  p.back = p.back or {}
  p.back[#p.back + 1] = { d = p.d, npc = p.npc, skip = D and D.skip or 0 }
  p[what] = id
  if D then D.skip = 0 end
end
local function back(tab)
  local p = at[tab]
  local b = p.back and table.remove(p.back) or {}
  p.d, p.npc = b.d, b.npc
  if D then D.skip = b.skip or 0 end
end
local function backRow(tab, tip)
  return { mark = "<", text = "Back", tip = tip, act = { word = "back", peek = true, fn = function() back(tab) end } }
end

local function name(npc) return C.Name(npc) or ("creature " .. npc) end
local function row(tab, npc, how)
  local db, s = C.DB(), C.DATA.creatures[npc]
  local m = db.met[npc]
  local n = m and m.n or 0
  local right, ink = "", "ink2"
  if how == "met" then right = "x" .. n
  elseif s and s.boss then right, ink = "BOSS", "gold"
  elseif m and m.level then right = "lvl " .. m.level end
  local dd = s and C.DATA.dungeons[s.d]
  return { mark = n > 0 and "v" or "", text = name(npc), right = right, ink = ink,
    tip = (dd and dd.name or "The wild") .. (n > 0 and (", met " .. n .. (n == 1 and " time" or " times")) or ", not met yet"),
    act = { word = "open", peek = true, fn = function() into(tab, "npc", npc) end } }
end

--- The place you stand in, as the book calls it ("the deadmines" = "deadmines").
local function here()
  local ok, z = pcall(function() return GetRealZoneText and GetRealZoneText() end)
  z = ok and C.Plain(z) or nil
  return type(z) == "string" and z:lower():gsub("^the ", "") or nil
end
local function places()
  local out, mine, db = {}, here(), C.DB()
  for _, v in ipairs(C.DATA.volumes) do
    for _, d in ipairs(v.list) do
      local dd = C.DATA.dungeons[d]
      local isHere = mine ~= nil and dd.name:lower():gsub("^the ", "") == mine
      local met = 0
      for _, npc in ipairs(dd.list) do if db.met[npc] then met = met + 1 end end
      local r = { mark = isHere and ">" or tostring(dd.level), text = dd.name,
        right = isHere and "HERE" or met > 0 and (met .. " / " .. #dd.list) or tostring(#dd.list),
        ink = isHere and "gold" or met > 0 and "good" or "dim",
        tip = dd.where .. ", level " .. dd.level .. ": " .. #dd.list .. " creatures, " .. met .. " met",
        act = { word = "open", peek = true, fn = function() into(1, "d", d) end } }
      if isHere then table.insert(out, 1, r) else out[#out + 1] = r end
    end
  end
  return out
end
--- The creatures of a tab (or of a search), as rows.
local function list(tab)
  local words = find:gsub("^%s+", ""):gsub("%s+$", "")
  if words ~= "" then
    return keep("list", tab .. ":find:" .. words:lower(), function()
      C.Warm(C.All())
      local db, out = C.DB(), {}
      for _, npc in ipairs(C.Index("A", words)) do if tab ~= 3 or db.met[npc] then out[#out + 1] = row(tab, npc, tab == 3 and "met") end end
      return out
    end)
  end
  local d = tab == 1 and at[1].d
  if d then
    return keep("list", "1:" .. d, function()
      local out = { backRow(1, "Back to the places") }
      for _, npc in ipairs(C.DATA.dungeons[d].list) do out[#out + 1] = row(1, npc) end
      return out
    end)
  end
  if tab == 1 then return keep("list", "1:" .. tostring(here()), places) end
  return keep("list", tab, function()
    local db, ids, out = C.DB(), {}, {}
    if tab == 3 then for npc in pairs(db.met) do ids[#ids + 1] = npc end
    else ids = C.All() C.Warm(ids) end
    table.sort(ids, function(a, b)
      if tab == 3 then
        local x, y = db.met[a].n or 0, db.met[b].n or 0
        if x ~= y then return x > y end
      end
      local na, nb = db.names[a], db.names[b]
      if na and nb and na ~= nb then return na < nb end
      if (na ~= nil) ~= (nb ~= nil) then return na ~= nil end
      return a < b
    end)
    for i, npc in ipairs(ids) do out[i] = row(tab, npc, tab == 3 and "met") end
    return out
  end)
end
--- { all, met } of the book.
local function count()
  return keep("count", 1, function() return { all = #C.All(), met = C.CountMet(C.DB()) } end)
end

--- One creature's page, kept: { c, name, rows (without Back), hero, boxes }.
local function creature(npc)
  return keep("creature", npc, function()
    local c = C.Creature(npc)
    if not c then return false end
    local called, wait = name(npc), false
    local dd = c.dungeon and C.DATA.dungeons[c.dungeon]
    local kind = c.type and (c.family and c.family ~= c.type and (c.type .. ", " .. c.family) or c.type) or nil
    local rank = X.Rank(c)
    local v = { c = c, name = called, rows = {}, drops = X.Drops(c) }
    local function add(r) v.rows[#v.rows + 1] = r end
    local function head(words, n) add({ mark = "-", text = words, right = n and tostring(n) or "", ink = "dim", done = true }) end
    head("ABILITIES", #c.spells)
    for _, id in ipairs(c.spells) do
      local s = C.Spell(id)
      if not s.desc then wait = true end
      add({ pic = s.icon or X.QUESTION, text = s.name or ("spell " .. id), tip = s.desc or "The game is fetching its words." })
    end
    if #c.spells == 0 then add({ text = "Learned when you see it cast.", done = true }) end
    head("SEEN TO DROP", #v.drops)
    for _, e in ipairs(v.drops) do
      local iname, q = C.Item(e.item)
      if not iname then wait = true end
      local icon
      if C_Item and C_Item.GetItemIconByID then
        local ok, t = pcall(C_Item.GetItemIconByID, e.item)
        icon = ok and C.Plain(t) or nil
      end
      add({ pic = icon or X.QUESTION, text = iname or ("item " .. e.item), right = e.n == 1 and "once" or ("x" .. e.n), ink = QUALITY[q or 1] or "ink2",
        tip = (iname or "item") .. ": seen " .. (e.n == 1 and "once" or (e.n .. " times")) })
    end
    if #v.drops == 0 then add({ text = "Loot one and it is written here.", done = true }) end
    head("THE BOOK SAYS")
    add({ text = "Rank", right = rank, ink = c.boss and "gold" or "ink2" })
    add({ text = "Type", right = kind or "-" })
    add({ text = "Found in", right = dd and dd.name or "the wild" })
    add({ text = "Creature id", right = tostring(npc), ink = "dim" })
    add({ text = "Model id", right = c.display and tostring(c.display) or "by creature", ink = "dim" })
    local small = (c.boss and "Boss" or rank ~= "-" and (rank:sub(1, 1) .. rank:sub(2):lower()) or "Creature") .. (kind and (", " .. kind) or "")
    v.hero = { art = "model", big = called, small = small, display = c.display, creature = not c.display and npc or nil }
    v.boxes = { { "LEVEL", c.level or "-", "gold" }, { "MET", c.met, c.met > 0 and "good" or "dim" },
      { "SPELLS", #c.spells, "ink" }, { "DROPS", #v.drops, "ink" } }
    return v, wait
  end) or nil
end
--- The creature open on a tab, or nil.
local function cur(tab) return C.Ready() and at[tab] and at[tab].npc and creature(at[tab].npc) or nil end
--- The place open on the first tab, while nothing is searched for.
local function place(tab) return tab == 1 and find == "" and at[1].d and C.DATA.dungeons[at[1].d] or nil end

DP.App.codex = function(tool, db)
  return {
    name = "Codex",
    page = {
      tick = true,
      tour = { { text = "The book of creatures: pick a place, or type a name. A click opens one, in 3D.",
        note = "What you target, loot and see cast is written in by itself." } },
      title = function()
        local tab = math.max(1, math.min(3, D and D.defs["BiSTools:tool-codex"] and D.defs["BiSTools:tool-codex"].tab or 1))
        local v = cur(tab)
        if v then return v.name end
        local dd = place(tab)
        return dd and dd.name or "Codex"
      end,
      kicker = function() return "the book of creatures" end,
      tabs = function() return { "DUNGEONS", "ALL", "MET" } end,
      find = function(tab)
        if cur(tab) then return nil end
        return { hint = "a creature's name", get = function() return find end,
          set = function(words) find = type(words) == "string" and words or "" end,
          enter = function()
            local first = C.Ready() and find ~= "" and list(tab)[1]
            if first then first.act.fn() end
          end }
      end,
      hero = function(tab)
        local v = cur(tab)
        if v then return v.hero end
        local dd = place(tab)
        local npc = dd and dd.list[#dd.list]
        if not npc or not C.Ready() then return nil end
        local s = C.DATA.creatures[npc]
        return { art = "model", display = s and s.display, creature = not (s and s.display) and npc or nil,
          big = name(npc), small = dd.where .. ", level " .. dd.level }
      end,
      boxes = function(tab)
        if not C.Ready() then return {} end
        local v = cur(tab)
        if v then return v.boxes end
        local dd = place(tab)
        if dd then
          local met, mine = 0, C.DB().met
          for _, npc in ipairs(dd.list) do if mine[npc] then met = met + 1 end end
          return { { "LEVEL", dd.level, "gold" }, { "HERE", #dd.list, "ink" }, { "MET", met, "good" } }
        end
        local n = count()
        return { { "IN THE BOOK", n.all, "ink" }, { "MET", n.met, "good" } }
      end,
      rows = function(tab)
        if not C.Ready() then return {} end
        local v = cur(tab)
        if v then
          if not v.shown or v.shownOn ~= tab then
            v.shown, v.shownOn = { backRow(tab, "Back to the list") }, tab
            for _, r in ipairs(v.rows) do v.shown[#v.shown + 1] = r end
          end
          return v.shown
        end
        return list(tab)
      end,
      text = function(tab)
        if not C.Ready() then return "The book is still being opened." end
        if cur(tab) then return nil end
        local dd = place(tab)
        if dd then return (D and D.H or 0) >= TEXT_H and dd.about or nil end
        if #list(tab) > 0 then return nil end
        if find ~= "" then return "No creature by that name in the book yet." end
        return "Nobody met yet: target a creature, or let its nameplate show, and it is written here."
      end,
      say = function(tab)
        if not C.Ready() or cur(tab) then return nil end
        return next(C.pending) and "The game is sending names ..." or nil
      end,
      keys = function(tab)
        local npc = at[tab].npc
        return {
          DP.PopOut(function() if npc then X.Show(npc) else X.Toggle(true) end end, "The book's own window on your screen: it turns, it attacks, it casts"),
          { word = "FULL SCREEN", peek = true, tip = "The book, the whole screen", fn = function()
            if C.Drive and C.Drive.Open() and npc then C.Drive.Pick(npc, true) end
          end },
        }
      end,
    },
  }
end
