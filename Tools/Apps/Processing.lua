-- BiSTools / Tools / Apps / Processing.lua - the tool in the phone (dev/APPS.md).
-- ONE APP FOR WHAT YOU TAKE APART (22 Nov 2026, Arn: "there are two things that do the same thing disenchanting and processing" -
-- "processing is also going to do something if they are miner that need to smelt"): the Disenchant app's parts live here now
-- (DP.DisenchantParts: the gear with its sets and levels, the SETS list, one item's page).
-- READY = what can be disenchanted now, each with its level against what you wear, SKIP beside it; then LATER (above your skill, needs
-- a rod, skipped). SETS = your equipment sets' gear, never taken. HAUL = what it gave. Without the processing tool (or not an
-- enchanter) READY only looks. The click that disenchants is secure: the next one is drawn dim, POP OUT has the working buttons.
local _, NS = ...
local DP, R = NS.DeckPages, NS.Registry
if not (DP and DP.App) then return end

DP.App.processing = function(tool, db)
  local P, D = NS.Proc, BiSTheme.Deck
  local X = DP.DisenchantParts()
  local function works() return R:Enabled("processing") and P.Knows() end
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
    -- SOULBOUND AT THE BOTTOM (Arn, 23 Nov: "if they are bound send them to the bottom of the list"), each half in its old order
    local free, bound = {}, {}
    for _, e in ipairs(kept.ready) do if e.kind == "bound" then bound[#bound + 1] = e else free[#free + 1] = e end end
    for _, e in ipairs(bound) do free[#free + 1] = e end
    kept.ready = free
    return kept
  end
  --- The next plain one: never soulbound, never enchanted, never one of a mixed name - those are your own decision.
  local function nextOne()
    for _, e in ipairs(work().ready) do if e.kind == "free" and not e.enchanted and not e.warn then return e end end
  end
  local function tip(e)
    local out = { e.name .. " (" .. (COLOUR[e.quality] or "gear") .. (e.ilvl and ", level " .. e.ilvl or "") .. ")" }
    if e.sets then out[#out + 1] = "In your set " .. table.concat(e.sets, ", ") .. ": left alone" end
    if e.kind == "bound" then out[#out + 1] = "Soulbound" end
    if e.enchanted then out[#out + 1] = "Somebody enchanted it" end
    if e.warn then out[#out + 1] = "Another of the same name is not like it: look twice" end
    if e.above then out[#out + 1] = "Needs enchanting " .. tostring(e.need) end
    if e.blocked then out[#out + 1] = tostring(e.blocked) end
    return table.concat(out, ". ") .. "."
  end
  --- A click that disenchants THAT item (Arn, 23 Nov: "when i click an item it should disenchant ... shift click if its a soulbound
  --- item"): secure, aimed at its bag slot; the last word before the cast is still that item there, and Shift for soulbound or a set's.
  local function deAct(e)
    return { word = "DISENCHANT", spell = P.SpellName(), bag = e.bag, slot = e.slot, guid = e.guid, peek = true,
      ok = function()
        if not e.guid or P.GUID(e.bag, e.slot) ~= e.guid then P.Say("ITEM MOVED - LIST REFRESHED, CLICK AGAIN") kept = nil return false end
        local shift = IsShiftKeyDown and IsShiftKeyDown()
        local sets = NS.DE.InSets(e.bag, e.slot)
        if sets and not shift then P.Say("IN YOUR SET " .. table.concat(sets, ", "):upper() .. " - SHIFT-CLICK TO DISENCHANT") kept = nil return false end
        if e.kind == "bound" and not shift then P.Say("SOULBOUND - SHIFT-CLICK TO DISENCHANT") return false end
        P.clicked = { e = e, at = GetTime() }
        P.Say("")
        return true
      end }
  end
  local laterRows
  local function ignore(e, word, words) return { word = word, tip = words, fn = function() P.Ignore(e) kept = nil end } end
  local function slotOf(bag, slot) for _, g in ipairs(X.gear()) do if g.bag == bag and g.slot == slot then return g end end end
  --- ORE: a click smelts it all, Shift-click one bar (Arn: "smelt if its a ore"; Tools/Smelt.lua).
  local function oreRows()
    local SM, out = NS.Smelt, {}
    if not SM then return out end
    local ores = SM.Ores()
    if #ores == 0 then return out end
    out[1] = { head = true, text = "SMELT", right = "at a forge" }
    for _, o in ipairs(ores) do
      local can = o.known and o.bars > 0
      out[#out + 1] = { pic = o.icon, text = o.name, sub = o.count .. " ore = " .. o.bars .. (o.bars == 1 and " bar" or " bars"),
        right = not o.known and "NOT KNOWN" or o.bars == 0 and ("NEEDS " .. o.per) or "SMELT", ink = can and "gold" or "dim", done = not can or nil,
        tip = (SM.Name(o.spell) or o.name) .. (can and (". Click: smelts all " .. o.bars .. ". Shift-click: one bar. Stand at a forge.") or o.known and (": " .. o.per .. " ore a bar.") or ": you do not know it."),
        act = can and { word = "SMELT", peek = true, fn = function() SM.Smelt(o, (IsShiftKeyDown and IsShiftKeyDown()) and 1 or o.bars) kept = nil end } or nil }
    end
    return out
  end
  local function readyRows()
    local out = oreRows()
    if not works() then                                       -- (looking only: the gear in no set)
      for _, g in ipairs(X.gear()) do if not g.sets then out[#out + 1] = X.row(g) end end
      return out
    end
    for _, e in ipairs(work().ready) do
      local g = slotOf(e.bag, e.slot)
      local r = g and X.row(g) or { pic = e.icon or 134400, text = e.name }
      r.right = e.kind == "bound" and "BOUND" or e.enchanted and "ENCH" or e.warn and "CHECK" or (g and X.keptBack(g) and "KEPT") or ""
      r.ink = e.kind == "bound" and "warn" or "gold"
      r.tip = tip(e) .. (e.kind == "bound" and " Shift-click: disenchants it." or " Click: disenchants it.")
      r.bagItem = { e.bag, e.slot }                            -- (the game's item tooltip, your worn one beside it)
      r.act = e.guid and deAct(e) or r.act
      r.side = e.guid and ignore(e, "SKIP", "Out of the list, into KEEP: never disenchanted") or nil
      out[#out + 1] = r
    end
    local later = laterRows()
    if #later > 0 then
      out[#out + 1] = { head = true, text = "LATER", right = #later .. "" }
      for _, r in ipairs(later) do out[#out + 1] = r end
    end
    return out
  end
  local function skipped()
    local out = {}
    for guid, n in pairs(db().ignore or {}) do out[#out + 1] = { guid = guid, name = type(n) == "string" and n or "an item" } end
    table.sort(out, function(a, b) if a.name ~= b.name then return a.name < b.name end return tostring(a.guid) < tostring(b.guid) end)
    return out
  end
  function laterRows()
    local out = {}
    for _, e in ipairs(work().later) do
      if not e.sets then                                      -- (your sets' gear is under SETS)
      out[#out + 1] = { pic = e.icon or 134400, text = e.name, right = e.sets and table.concat(e.sets, ", ") or e.above and ("SKILL " .. tostring(e.need)) or "ROD",
        ink = e.above and not e.sets and "accent" or "gold",
        done = true, tip = tip(e), bagItem = { e.bag, e.slot } }
      end
    end
    -- (skipped ones are hidden - Arn: "i click skip hide them"; ALL BACK brings them all back)
    return out
  end
  --- KEEP (Arn, 23 Nov: "skip does not hide the item ... maybe put it in a hidden tab, not a set but not wanting to disenchant"):
  --- what you skipped, out of READY, listed here with its picture and level; BACK puts one back, ALL BACK them all.
  local function keepRows()
    local out, seen = {}, {}
    local probe = {}
    for k, v in pairs(db()) do probe[k] = v end
    probe.showIgnored = true
    for _, e in ipairs((P.Items(probe))) do
      if e.ignored and e.guid then
        seen[e.guid] = true
        out[#out + 1] = { pic = e.icon or 134400, text = e.name, sub = e.ilvl and ("level " .. e.ilvl) or nil, bagItem = { e.bag, e.slot },
          tip = "You keep it: never disenchanted from here.", side = ignore(e, "BACK", "Back into READY") }
      end
    end
    for _, s in ipairs(skipped()) do                          -- (kept, but not in your bags now: sold, banked, mailed)
      if not seen[s.guid] then
        out[#out + 1] = { mark = "-", text = s.name, sub = "not in your bags", done = true, tip = "You kept it; it is not in your bags now",
          side = ignore({ guid = s.guid, name = s.name }, "FORGET", "Off the list") }
      end
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
    return DP.PopOut(function() P.Toggle(true) end, "The window with the buttons that disenchant, on your screen")
  end

  local function counts()
    local all, sets = X.gear(), 0
    for _, g in ipairs(all) do if g.sets then sets = sets + 1 end end
    return all, sets
  end
  local function boxes(tab)
    if tab == 4 then return { { "SESSION", session(), "good" }, { "ALL TIME", P.Total(), "gold" } } end
    if tab == 3 then return { { "KEPT", #skipped(), "accent" } } end
    local all, sets = counts()
    if not works() then
      if #all == 0 then return {} end
      return { { "SPARE", #all - sets, "good" }, { "IN A SET", sets, sets > 0 and "gold" or "dim" } }
    end
    local w = work()
    local later = 0
    for _, e in ipairs(w.later) do if not e.sets then later = later + 1 end end
    return { { "READY", #w.ready, "good" }, { "IN A SET", sets, sets > 0 and "gold" or "dim" }, { "LATER", later, "accent" }, { "SKILL", P.Skill() or "-", "gold" } }
  end

  return {
    name = "Processing",
    alsoTools = { "disenchant" },                              -- (its switch and options under SETTINGS)
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
      tour = { { text = "What you can take apart now, with its level against what you wear. SKIP leaves one item alone.", note = "BOUND, ENCH, CHECK: look twice." },
        { text = "The big button takes the next one apart. One click, one item. Your equipment sets' gear is never taken: SETS." } },
      kicker = function() return X.picked() and "one item" or "enchanting" end,
      tabs = function() return { "READY", "SETS", "KEEP", "HAUL" } end,
      boxes = function(tab)
        local e = X.picked()
        if e then return X.itemBoxes(e) end
        return boxes(tab)
      end,
      rows = function(tab)
        local e = X.picked()
        if e then return X.itemRows(e) end
        if tab == 2 then return X.setRows() end
        if tab == 3 then return keepRows() end
        if tab == 4 then return haulRows() end
        return readyRows()
      end,
      text = function(tab)
        if X.picked() then return nil end
        if tab == 4 then return not next(db().totals or {}) and "Nothing yet. What your disenchanting gives is counted here." or nil end
        if tab == 3 then return not next(db().ignore or {}) and "Nothing kept. SKIP on an item in READY puts it here: never disenchanted, out of the list." or nil end
        if tab == 2 then
          local _, all = NS.DE.Sets()
          return #all == 0 and "No equipment sets yet. Make one in the game's Equipment Manager (character window): its gear is marked here and never taken." or nil
        end
        if #readyRows() == 0 then return "Nothing in your bags that you can disenchant now. Green, blue and epic weapons and armor show up here." end
      end,
      say = function(tab)
        local e = X.picked()
        if e then return X.itemSay(e) end
        if tab ~= 1 then return nil end
        if R:Enabled("processing") and not P.Knows() then return "Not an enchanter: this only looks" end
        if not works() then return #X.gear() > 0 and "Hold " .. (NS.DE.KeyWord and NS.DE.KeyWord() or "Alt") .. " over your bags: it glows there" or nil end
        if type(P.said) == "string" and P.said ~= "" then return P.said end
        if #work().ready == 0 then return nil end
        return nextOne() and "One click, one item" or "All of these want a second look"
      end,
      big = function(tab)
        local e = tab == 1 and not X.picked() and works() and nextOne()
        if not e then return nil end
        local a = deAct(e)
        a.word = "NEXT: " .. e.name
        return a
      end,
      keys = function(tab)
        local e = X.picked()
        if e then return X.itemKeys(e) end
        local out = {}
        if R:Enabled("processing") then out[1] = oldWindow() end
        if tab == 4 then
          out[#out + 1] = { word = "HOARD", peek = true, tip = "Everything ever processed, in a heap, with you on top", fn = function() P.ToggleHoard(true) end }
        end
        if tab == 3 and next(db().ignore or {}) then
          out[#out + 1] = confirm("skip", "ALL BACK", "Every kept item back into READY", slash("ignored clear"))
        end
        if tab == 1 and next(db().blocked or {}) then out[#out + 1] = confirm("rods", "NO RODS", "Forget what the game said about rods", slash("rods clear")) end
        return out
      end,
    },
  }
end
