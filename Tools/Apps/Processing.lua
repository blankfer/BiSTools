-- BiSTools / Tools / Apps / Processing.lua - the tool in the phone (dev/APPS.md).
-- READY = what can be disenchanted now, LATER = above your skill, needs a rod, in an equipment set of yours, skipped; HAUL = what it gave. All of it is P.Items /
-- P.haul / db.totals. The click that disenchants is secure: the next one is drawn dim, OLD WINDOW has the working buttons.
local _, NS = ...
local DP, R = NS.DeckPages, NS.Registry
if not (DP and DP.App) then return end

DP.App.processing = function(tool, db)
  local P, D = NS.Proc, BiSTheme.Deck
  local COLOUR = { [2] = "Green", [3] = "Blue", [4] = "Epic" }

  local function plain(v) if v == nil or (issecretvalue and issecretvalue(v)) then return nil end return v end
  local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok then return plain(v) end
  end
  --- The bags, walked once a moment: { ready, later } (a paint asks several times; a press asks again).
  local kept
  local function work()
    local at = GetTime and GetTime() or 0
    if kept and kept.at == at then return kept end
    kept = { at = at, ready = {}, later = {} }
    for _, e in ipairs((P.Items(db()))) do
      if not e.ignored then
        local to = (e.above or e.blocked or e.sets) and kept.later or kept.ready
        to[#to + 1] = e
      end
    end
    return kept
  end
  --- The next plain one: never soulbound, never enchanted, never one of a mixed name - those are your own decision.
  local function nextOne()
    for _, e in ipairs(work().ready) do if e.kind == "free" and not e.enchanted and not e.warn then return e end end
  end
  local function tip(e)
    local out = { e.name .. " (" .. (COLOUR[e.quality] or "gear") .. (e.ilvl and ", level " .. e.ilvl or "") .. ")" }
    if e.sets then out[#out + 1] = "In your set " .. table.concat(e.sets, ", ") .. ": left alone" end
    if e.kind == "bound" then out[#out + 1] = "Soulbound: shift-click it in the old window" end
    if e.enchanted then out[#out + 1] = "Somebody enchanted it" end
    if e.warn then out[#out + 1] = "Another of the same name is not like it: look twice" end
    if e.above then out[#out + 1] = "Needs enchanting " .. tostring(e.need) end
    if e.blocked then out[#out + 1] = tostring(e.blocked) end
    return table.concat(out, ". ") .. "."
  end
  local function ignore(e, word, words) return { word = word, tip = words, fn = function() P.Ignore(e) kept = nil end } end
  local function readyRows()
    local out = {}
    for i, e in ipairs(work().ready) do
      out[i] = { pic = e.icon or 134400, text = e.name, right = e.kind == "bound" and "BOUND" or e.enchanted and "ENCH" or e.warn and "CHECK" or "",
        ink = e.kind == "bound" and "warn" or "gold", tip = tip(e), side = e.guid and ignore(e, "SKIP", "Leave this one item alone") or nil }
    end
    return out
  end
  local function skipped()
    local out = {}
    for guid, n in pairs(db().ignore or {}) do out[#out + 1] = { guid = guid, name = type(n) == "string" and n or "an item" } end
    table.sort(out, function(a, b) if a.name ~= b.name then return a.name < b.name end return tostring(a.guid) < tostring(b.guid) end)
    return out
  end
  local function laterRows()
    local out = {}
    for _, e in ipairs(work().later) do
      out[#out + 1] = { pic = e.icon or 134400, text = e.name, right = e.sets and table.concat(e.sets, ", ") or e.above and ("SKILL " .. tostring(e.need)) or "ROD",
        ink = e.above and not e.sets and "accent" or "gold",
        done = true, tip = tip(e) }
    end
    for _, e in ipairs(skipped()) do
      out[#out + 1] = { mark = "-", text = e.name, done = true, tip = "You skipped it", side = ignore(e, "BACK", "Back into the list") }
    end
    return out
  end
  local function session() local n = 0 for _, c in pairs(P.haul or {}) do n = n + c end return n end
  local function haulRows()
    local all, out = {}, {}
    for id, n in pairs(db().totals or {}) do all[#all + 1] = { id = id, n = n } end
    table.sort(all, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.id < b.id end)
    for i, e in ipairs(all) do
      local s, n = P.haul[e.id] or 0, P.haulName[e.id] or ask(C_Item and C_Item.GetItemNameByID, e.id)
      out[i] = { pic = ask(C_Item and C_Item.GetItemIconByID, e.id) or 134400, text = type(n) == "string" and n ~= "" and n or ("item " .. tostring(e.id)),
        right = (s > 0 and "+" .. s .. " / " or "x") .. e.n, ink = s > 0 and "good" or "ink2", tip = "This session " .. s .. ", all time " .. e.n }
    end
    return out
  end
  -- it asks again: the word changes, the second press does it
  local sure = {}
  local function confirm(key, word, words, fn)
    local function armed() return sure.key == key and (GetTime() - sure.at) <= 5 end
    return { word = armed() and "SURE?" or word, tip = words, peek = true, fn = function()
      if armed() then
        sure, kept = {}, nil
        return fn()
      end
      sure = { key = key, at = GetTime() }
      if C_Timer and C_Timer.After then C_Timer.After(5.1, function() D.Dirty() end) end
    end }
  end
  local function slash(words) return function() tool.OnSlash(tool, db(), words) end end
  local function oldWindow()
    return { word = "OLD WINDOW", peek = true, tip = "The window with the buttons that disenchant", fn = function() P.Toggle(true) end }
  end

  return {
    badge = function() return R:Enabled("processing") and (P.count or 0) > 0 and P.count or nil end,
    card = {
      moments = { town = true },                               -- (where it belongs, for the deck's guessed cards - 22 Nov)
      prio = function(out)
        if P.ShowBox() then return 3 end                       -- (in town only: the tool's own rule)
        return out and R:Enabled("processing") and 2 or nil
      end,
      lines = function()
        local n, e, list = P.count or 0, nextOne(), {}
        if e then list[1] = { "Next", e.name } end
        list[#list + 1] = { "This session", tostring(session()) }
        list[#list + 1] = { "All time", tostring(P.Total()) }
        return { "PROCESSING", "", n > 0 and (n .. " to disenchant") or "Nothing ready", P.Skill() and ("skill " .. P.Skill()) or "", "ink2", list = list }
      end,
      buttons = function() return { oldWindow() } end,
    },
    page = {
      tour = { { text = "What your enchanting can take apart now. SKIP leaves one item alone.", note = "BOUND, ENCH, CHECK: look twice." },
        { text = "The big button takes the next one apart. One click, one item." } },
      kicker = function() return "enchanting" end,
      tabs = function() return { "READY", "LATER", "HAUL" } end,
      boxes = function(tab)
        if tab == 3 then return { { "SESSION", session(), "good" }, { "ALL TIME", P.Total(), "gold" } } end
        if not P.Knows() then return {} end
        local w = work()
        return { { "READY", #w.ready, "good" }, { "LATER", #w.later, "accent" }, { "SKIPPED", #skipped(), "dim" }, { "SKILL", P.Skill() or "-", "gold" } }
      end,
      rows = function(tab)
        if tab == 3 then return haulRows() end
        if not P.Knows() then return {} end
        return tab == 2 and laterRows() or readyRows()
      end,
      text = function(tab)
        if tab == 3 then return not next(db().totals or {}) and "Nothing yet. What your disenchanting gives is counted here." or nil end
        if not P.Knows() then return "This character does not know Disenchant. Enchanting is the one profession it works on so far." end
        if tab == 1 and #work().ready == 0 then return "Nothing in your bags that you can disenchant now." end
        if tab == 2 and #work().later == 0 and #skipped() == 0 then return "Nothing is waiting: no gear above your skill or in your sets, none you skipped." end
      end,
      say = function(tab)
        if tab ~= 1 or not P.Knows() then return nil end
        if type(P.said) == "string" and P.said ~= "" then return P.said end
        if #work().ready == 0 then return nil end
        return nextOne() and "One click, one item" or "All of these want a second look"
      end,
      big = function(tab)
        local e = tab == 1 and nextOne()
        return e and { word = "NEXT: " .. e.name, spell = P.SpellName(), bag = e.bag, slot = e.slot, guid = e.guid, peek = true,
          ok = function()                                   -- (the last word: is it still that item?)
            if not e.guid or P.GUID(e.bag, e.slot) ~= e.guid then P.Say("ITEM MOVED - LIST REFRESHED, CLICK AGAIN") kept = nil return false end
            local sets = NS.DE.InSets(e.bag, e.slot)
            if sets then P.Say("IN YOUR SET " .. table.concat(sets, ", "):upper() .. " - LEFT ALONE") kept = nil return false end
            P.clicked = { e = e, at = GetTime() }
            P.Say("")
            return true
          end } or nil
      end,
      keys = function(tab)
        local out = { oldWindow() }
        if tab == 3 then
          out[2] = { word = "HOARD", peek = true, tip = "Everything ever processed, in a heap, with you on top", fn = function() P.ToggleHoard(true) end }
        end
        if tab == 2 and next(db().ignore or {}) then
          out[#out + 1] = confirm("skip", "ALL BACK", "Every skipped item back into the list", slash("ignored clear"))
        end
        if tab == 2 and next(db().blocked or {}) then out[#out + 1] = confirm("rods", "NO RODS", "Forget what the game said about rods", slash("rods clear")) end
        return out
      end,
    },
  }
end
