-- BiSTools / Tools / Apps / XP.lua - the tool in the phone (dev/APPS.md).
-- NOW = what your XP gets now (rested, Well-Rested, Well Fed), an hour's worth, how far the next level is; BAGS = what you carry for
-- it, and which food is yours. Eating is a secure click: the button in the BiS> tools box does it, the ones here wait.
local _, NS = ...
local DP, R = NS.DeckPages, NS.Registry
if not (DP and DP.App) then return end

DP.App.xp = function(tool, db)
  local X, D = NS.XP, BiSTheme.Deck
  local ID = "BiSTools:tool-xp"

  local function plain(v) if v == nil or (issecretvalue and issecretvalue(v)) then return nil end return v end
  local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok then return plain(v) end
  end
  local function num(fn, ...) local v = ask(fn, ...) return type(v) == "number" and v or nil end
  local function now() return GetTime and GetTime() or 0 end
  local function pct(s) return type(s) == "number" and (math.floor(s * 100 + 0.5) .. "%") or "?" end
  local function commas(n)
    local s = tostring(math.floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (s:gsub("^,", ""))
  end
  local function big(n) return n >= 10000 and ("%.1fk"):format(n / 1000) or commas(n) end
  local function mins(s)
    if s == math.huge then return "no end" end
    return s >= 3600 and ("%d h %d min"):format(math.floor(s / 3600), math.floor(s % 3600 / 60)) or (math.floor(s / 60) .. " min")
  end
  local function name(id)
    local n = ask((C_Item and C_Item.GetItemNameByID) or GetItemInfo, id)
    return type(n) == "string" and n ~= "" and n or ("item " .. tostring(id))
  end
  local function item(id) return "item:" .. id end

  -- AN HOUR'S WORTH: counted from the login (or START AGAIN), at every look - the level's own XP and, over a level, what was left of it
  local run
  local function look()
    local xp, max, lvl = num(UnitXP, "player"), num(UnitXPMax, "player"), num(UnitLevel, "player")
    if not (xp and max and lvl) or max <= 0 then return run end
    if not run then run = { at = now(), got = 0 }
    elseif lvl == run.lvl then run.got = run.got + math.max(0, xp - run.xp)
    elseif lvl > run.lvl then run.got = run.got + math.max(0, run.max - run.xp) + xp end
    run.xp, run.max, run.lvl = xp, max, lvl
    return run
  end
  local function hour()
    local r = look()
    if not r or r.got <= 0 or now() - r.at < 60 then return nil, r end
    return r.got / (now() - r.at) * 3600, r
  end
  look()

  --- One look: what the buffs say, in words and colours.
  local function buffs()
    local b = { r = X.Rested(), f = X.Fed(), rest = X.Rest() }
    b.rWords = b.r == "missing" and "GONE" or type(b.r) == "table" and (b.r.stacks .. " of " .. X.RESTED_MAX .. ", " .. mins(b.r.left)) or "?"
    b.fWords = b.f == "missing" and "GONE" or type(b.f) == "table" and mins(b.f.left) or "?"
    b.rInk = b.r == nil and "dim" or X.BagDue(b.r) and "warn" or "good"
    b.fInk = b.f == nil and "dim" or X.FoodDue(b.f) and "warn" or "good"
    return b
  end
  --- What the tool itself would have you click now (its own order: tent, bag, food), as secure buttons.
  local function due()
    local out = {}
    if X.showTent then out[#out + 1] = { word = "CAMP TENT", item = item(X.TENT_ITEM) } end
    if X.showBag then out[#out + 1] = { word = "SLEEPING BAG", item = item(X.BAG_ITEM) } end
    if X.showFood and X.pick then out[#out + 1] = { word = "EAT: " .. name(X.pick), item = item(X.pick) } end
    return out
  end
  local function nowRows()
    local b, out = buffs(), {}
    local function add(row) out[#out + 1] = row end
    add({ pic = X.BAG_ICON, text = "Well-Rested", right = b.rWords, ink = b.rInk,
      tip = "The sleeping bag: rest inside a minute for each stack, up to " .. X.RESTED_MAX })
    add({ pic = X.pick and X.Icon(X.pick) or nil, mark = "F", text = "Well Fed", right = b.fWords, ink = b.fInk, tip = "Cooked XP food: more XP from kills" })
    local known = type(b.rest) == "number"
    local low = known and b.rest < X.TENT_SHARE
    add({ pic = X.Icon(X.TENT_ITEM), mark = "R", text = "Rested XP", right = known and (pct(b.rest) .. " of a level") or "?", ink = not known and "dim" or low and "gold" or "good",
      tip = "The Camp Tent fills it to " .. pct(X.TENT_SHARE) .. " of a level" })
    if X.Count(X.TENT_ITEM) > 0 then
      local off = X.Boosted()
      add({ pic = X.Icon(X.TENT_ITEM), text = "Camp Tent", right = off == true and "NOT YET" or off == nil and "?" or low and "READY" or "NO NEED",
        ink = off == false and low and "good" or "dim", tip = "Once an hour, only under " .. pct(X.TENT_SHARE) .. " rested. Needs a campfire." })
    end
    if X.Count(X.BAG_ITEM) > 0 and X.BagCD() > 0 then
      add({ pic = X.Icon(X.BAG_ITEM), text = "Sleeping bag in", right = mins(X.BagCD()), ink = "gold" })
    end
    local ph, r = hour()
    if r then
      local left = r.max - r.xp
      add({ mark = "L", text = "To level " .. (r.lvl + 1), right = commas(left) .. " XP", ink = "accent", tint = "gold",
        sub = "you have " .. commas(r.xp) .. " of " .. commas(r.max), tip = "You have " .. commas(r.xp) .. " of " .. commas(r.max) })
      if ph then add({ mark = "L", text = "At this pace", right = mins(left / ph * 3600), ink = "gold", tip = "From what you got since the count started" }) end
      add({ mark = "L", text = "Since the start", right = commas(r.got) .. " XP", tip = mins(now() - r.at) .. " ago. START AGAIN counts from now." })
    end
    return out
  end
  --- What is in the bags for it: { id, n, food }. The food's own check is the tool's (X.IsXPItem, remembered per item). Walked
  --- once a moment: a paint asks several times.
  local kept
  local function carried()
    if kept and kept.at == now() then return kept end
    kept = { at = now() }
    for _, id in ipairs({ X.TENT_ITEM, X.BAG_ITEM }) do
      local n = X.Count(id)
      if n > 0 then kept[#kept + 1] = { id = id, n = n } end
    end
    local K, food, seen = C_Container or {}, {}, {}
    for bag = 0, 4 do
      for slot = 1, num(K.GetContainerNumSlots, bag) or 0 do
        local id = num(K.GetContainerItemID, bag, slot)
        if id and not seen[id] then
          seen[id] = true
          if X.IsXPItem(id) then food[#food + 1] = { id = id, n = X.Count(id), food = true } end
        end
      end
    end
    table.sort(food, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.id < b.id end)
    for _, e in ipairs(food) do kept[#kept + 1] = e end
    return kept
  end
  local function slash(words) return function() tool.OnSlash(tool, db(), words) kept = nil end end
  local function bagRows()
    local out = {}
    for i, e in ipairs(carried()) do
      local mine, next = e.food and e.id == db().food, e.food and e.id == X.pick
      out[i] = { pic = X.Icon(e.id), text = name(e.id), right = (mine and "YOURS " or next and "NEXT " or "") .. "x" .. e.n,
        ink = (mine or next) and "good" or "ink2", tint = (mine or next) and "good" or nil,
        sub = e.food and (mine and "yours: eaten first" or next and "eaten next" or "XP food") or (e.id == X.BAG_ITEM and "for Well-Rested" or "for rested XP, at a campfire"),
        act = e.food and not mine and { word = "mine", fn = slash("food " .. e.id) } or nil,
        tip = e.food and (mine and "Yours: eaten first while you have it" or "Click: make it yours, eaten first")
          or (e.id == X.BAG_ITEM and "For Well-Rested" or "For rested XP, at a campfire") }
    end
    return out
  end

  return {
    card = {
      tick = true,
      prio = function(out)
        if not R:Enabled("xp") or not X.Levelling() then return nil end
        if X.showBag or X.showFood then return 6 end
        return out and 2 or nil
      end,
      lines = function()
        local b = buffs()
        local ph = hour()
        local list = { { "Well-Rested", b.rWords }, { "Well Fed", b.fWords }, { "An hour", ph and (big(ph) .. " XP") or "-" } }
        if X.showFood and X.FoodDue(b.f) then
          return { "XP", "", "Time to eat", b.f == "missing" and "GONE" or b.fWords, "warn", hot = true, list = list }
        end
        if X.showBag or X.showFood then
          local at = b.r == "missing" and "GONE" or type(b.r) == "table" and (b.r.stacks .. "/" .. X.RESTED_MAX) or ""
          return { "XP", "", "Time to rest", at, "warn", hot = true, list = list }
        end
        return { "XP", "", "Rested " .. pct(b.rest), ph and (big(ph) .. " / h") or "", "good", list = list }
      end,
      buttons = function()
        local out = {}
        for i, b in ipairs(due()) do out[i] = { word = b.word:match("^(%u+):") or b.word:match("(%u+)$"), item = b.item } end
        if #out < 3 then out[#out + 1] = { word = "OPEN", peek = true, fn = function() D.Open(ID) end } end
        return out
      end,
    },
    page = {
      tick = true,
      tour = { { text = "What your XP gets now, and what is running low.", note = "BAGS: what you carry, and your food." } },
      kicker = function() return X.Levelling() and "levelling" or "top level" end,
      tabs = function() return { "NOW", "BAGS" } end,
      boxes = function(tab)
        if tab == 2 then
          local food, kinds = 0, 0
          for _, e in ipairs(carried()) do if e.food then food, kinds = food + e.n, kinds + 1 end end
          return { { "XP FOOD", food, food > 0 and "good" or "warn" }, { "KINDS", kinds, "accent" }, { "BAG", X.Count(X.BAG_ITEM) > 0 and "YES" or "NO", "ink2" },
            { "TENT", X.Count(X.TENT_ITEM) > 0 and "YES" or "NO", "ink2" } }
        end
        if not X.Levelling() then return {} end
        local b, ph = buffs(), hour()
        return { { "RESTED", pct(b.rest), b.rest and "accent" or "dim" },
          { "STACKS", type(b.r) == "table" and (b.r.stacks .. "/" .. X.RESTED_MAX) or b.r == "missing" and "0" or "?", b.rInk },
          { "FED", type(b.f) == "table" and (b.f.left == math.huge and "YES" or math.floor(b.f.left / 60) .. "m") or b.f == "missing" and "NO" or "?", b.fInk },
          { "AN HOUR", ph and big(ph) or "-", "gold" } }
      end,
      rows = function(tab)
        if tab == 2 then return bagRows() end
        return X.Levelling() and nowRows() or {}
      end,
      text = function(tab)
        if tab == 1 and not X.Levelling() then return "You are at the top level: no more XP to get. The buttons stay away by themselves." end
        if tab == 2 and #carried() == 0 then
          return "Nothing for XP in your bags. Cooked food that says experience in its text, a Cozy Sleeping Bag or a Camp Tent shows up here."
        end
      end,
      say = function(tab)
        if tab == 2 then return db().food and "Yours is eaten first while you have it" or "Click a food: yours, eaten first" end
        if not X.Levelling() then return nil end
        return due()[1] and "Its button is in the BiS> tools box" or "Nothing is due now"
      end,
      big = function(tab) return tab == 1 and X.Levelling() and due()[1] or nil end,
      keys = function(tab)
        if tab == 2 then return db().food and { { word = "ANY FOOD", tip = "No favourite: the one you carry most of", fn = slash("food off") } } or {} end
        if not X.Levelling() then return {} end
        return { { word = "START AGAIN", peek = true, tip = "The count of an hour's worth, from now", fn = function() run = nil look() end } }
      end,
    },
  }
end
