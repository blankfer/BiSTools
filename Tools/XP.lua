-- BiSTools / Tools / XP.lua - THE XP BUFFS (6 Nov 2026), two buttons in the BiS> tools box.
--
-- Arn, 6 Nov, three tooltips - Well-Rested (spell 429959, "Experience gains increased by 3%"), Well Fed ("+10 Attack
-- Power ... Experience gained from kills increased by 5%"), the Cozy Sleeping Bag (item 211527: "Resting inside for
-- at least one minute will provide a bonus to experience earned, stacking up to 3 times") - and: "i want a super light
-- weight figure out what i want and im going to test you".
--
-- So: while you level, a button comes into the BiS> tools box when an XP buff needs you, and one click fixes it.
--   - THE SLEEPING BAG: Well-Rested missing, under its 3 stacks, or under 10 minutes left - and the bag in your bags.
--   - XP FOOD: Well Fed XP Boost missing or under 2 minutes left - and cooked XP food in your bags (its use text says
--     "experience"; vendor food never does). Yours first - the last XP food you ate (the cast, matched to the bag
--     item), or `/bist xp food <item link>` - else the XP food you carry most of.
-- Out of combat only (a box of secure buttons is laid out then), nothing at the level cap.
--
-- SUPER LIGHT: no ticker. The player's own aura changes, bags, a level and the end of a fight make it look - one aura
-- question per buff and one item count each - and the moment a buff crosses "low" is ONE timer, set to that moment.
-- In a fight, nothing runs at all. Your own buffs answer plainly out of combat (GetPlayerAuraBySpellID; probe round 1,
-- 4 Nov) - a hidden answer counts as "don't know", never "missing".
local _, NS = ...
local R = NS.Registry
local X = {}
NS.XP = X

X.BAG_ITEM, X.BAG_ICON = 211527, 133662      -- Cozy Sleeping Bag (Arn's tooltip: ItemID 211527, IconID 133662)
X.RESTED, X.RESTED_MAX = 429959, 3           -- Well-Rested (Arn's tooltip: Spell ID 429959), up to 3 stacks
X.LOW_RESTED, X.LOW_FOOD = 600, 120          -- seconds left that count as "top it up"
X.FOOD_WINDOW = 60                           -- seconds from eating to its Well Fed, to learn which food it was
X.CAP = 60
X.WELL_FED = "Well Fed"
-- Forever's cooked food (the runner, 6 Nov, Wowhead's Forever tooltips): the XP part is its OWN aura, "Well Fed XP
-- Boost" (+5% from kills, flat at every food level), beside the stat Well Fed. Most cooked food gives it, vendor food
-- never; the food's use text ends "Additionally, experience gained from kills is increased by 5%."
X.XP_AURA = 1243969

local function plain(v)
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d, e = pcall(fn, ...)
  if not ok then return nil end
  return a, b, c, d, e
end

local function now() return (GetTime and GetTime()) or 0 end

local function count(item)
  local f = (C_Item and C_Item.GetItemCount) or GetItemCount
  local n = plain(ask(f, item))
  return type(n) == "number" and n or 0
end

function X.Fighting() return InCombatLockdown and InCombatLockdown() and true or false end

function X.Levelling()
  local l = plain(ask(UnitLevel, "player"))
  return type(l) == "number" and l < X.CAP
end

--- An aura of mine: "missing", or its stacks and seconds left, or nil when the client will not say.
local function mine(aura)
  if aura == nil then return "missing" end
  if type(aura) ~= "table" then return nil end
  local exp, apps = plain(aura.expirationTime), plain(aura.applications)
  if type(exp) ~= "number" then return nil end
  local left = exp > 0 and (exp - now()) or math.huge          -- 0 = no end
  return { left = left, stacks = type(apps) == "number" and math.max(apps, 1) or 1, id = plain(aura.spellId) }
end

function X.Rested()
  local f = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
  if not f then return nil end
  local ok, aura = pcall(f, X.RESTED)
  if not ok or (aura ~= nil and plain(aura) == nil) then return nil end
  return mine(aura)
end

--- Is this Well Fed the experience one? Its own description says so.
function X.IsXPFood(spellId)
  if type(spellId) ~= "number" then return false end
  local d = plain(ask(C_Spell and C_Spell.GetSpellDescription, spellId))
  return type(d) == "string" and d:lower():find("experience", 1, true) ~= nil
end

--- The XP food buff: Well Fed XP Boost by its id; failing that, a Well Fed whose own text says experience (Arn's
--- tooltip, 6 Nov, read that way - whichever shape the client shows, both count).
function X.Fed()
  local by = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
  if by then
    local ok, a = pcall(by, X.XP_AURA)
    if not ok or (a ~= nil and plain(a) == nil) then return nil end
    if a ~= nil then return mine(a) end
  end
  local f = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
  if not f then return nil end
  local ok, aura = pcall(f, "player", X.WELL_FED, "HELPFUL")
  if not ok or (aura ~= nil and plain(aura) == nil) then return nil end
  local m = mine(aura)
  if type(m) == "table" and not X.IsXPFood(m.id) then return "missing" end   -- a Well Fed with no experience in it
  return m
end

--- Should the sleeping bag's button be up? (the bag in your bags, Well-Rested missing / short of 3 / running low)
function X.ShowBag(db)
  db = db or X.db or {}
  if db.bag == false or not R:Enabled("xp") or X.Fighting() or not X.Levelling() then return false end
  if count(X.BAG_ITEM) == 0 then return false end
  local r = X.Rested()
  if r == nil then return false end                             -- the client would not say: no guess
  if r == "missing" then return true end
  return r.stacks < X.RESTED_MAX or r.left < X.LOW_RESTED
end

--- Is this item an XP food? Its use spell's text says experience. Remembered per item; an empty text (not loaded
--- yet) is "don't know" and is asked again.
X.xpItem, X.tries = {}, {}
function X.IsXPItem(id)
  if type(id) ~= "number" then return false end
  if X.xpItem[id] ~= nil then return X.xpItem[id] end
  local _, sid = ask(C_Item and C_Item.GetItemSpell, id)
  sid = plain(sid)
  if type(sid) ~= "number" then X.xpItem[id] = false return false end        -- not a usable item
  local d = plain(ask(C_Spell and C_Spell.GetSpellDescription, sid))
  if type(d) ~= "string" or d == "" then                       -- three asks, then it is not food (a blank-text item)
    X.tries[id] = (X.tries[id] or 0) + 1
    if X.tries[id] >= 3 then X.xpItem[id] = false return false end
    return nil
  end
  X.xpItem[id] = d:lower():find("experience", 1, true) ~= nil
  return X.xpItem[id]
end

--- Which XP food the button eats: yours (learned or named) while you have it, else the XP food you carry most of.
--- A bag scan - only after a bag change (X.dirty), never on an aura change.
function X.Pick(db)
  db = db or X.db or {}
  local unsure = false
  local best, most
  if db.food and count(db.food) > 0 then
    best = db.food
  else
    local C = C_Container
    local seen = {}
    if C and C.GetContainerNumSlots and C.GetContainerItemID then
      for bag = 0, 4 do
        local n = plain(ask(C.GetContainerNumSlots, bag)) or 0
        for slot = 1, n do
          local id = plain(ask(C.GetContainerItemID, bag, slot))
          if type(id) == "number" and not seen[id] then
            seen[id] = true
            local xp = X.IsXPItem(id)
            if xp == nil then unsure = true
            elseif xp then
              local c = count(id)
              if not most or c > most then best, most = id, c end
            end
          end
        end
      end
    end
  end
  X.dirty = unsure                                              -- a text still loading: look again next time
  if best ~= X.pick then
    X.pick = best
    X.ArmFood(db)
  end
  return best
end

function X.ShowFood(db)
  db = db or X.db or {}
  if db.eat == false or not X.pick or not R:Enabled("xp") or X.Fighting() or not X.Levelling() then return false end
  if count(X.pick) == 0 then return false end
  local fed = X.Fed()
  if fed == nil then return false end
  if fed == "missing" then return true end
  return fed.left < X.LOW_FOOD
end

-- ------------------------------------------------------------------ the buttons

local function icon(item)
  local f = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
  local t = plain(ask(f, item))
  return t or 134400                                            -- the question mark
end

local function button(name, item, tip)
  local K = NS.Farm
  local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
  b:SetSize(26, 26)
  b:SetFrameStrata("MEDIUM")
  b:RegisterForClicks("AnyDown")
  b:SetAttribute("type1", "item")
  b:SetAttribute("item1", item and ("item:" .. item) or "")
  K.tex(b, "BACKGROUND", "field", 0.95)
  b.edge = K.border(b, "accent", 1)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon:SetTexture(item and icon(item) or 134400)
  b.word = K.fs(b, "", 9, "ink")
  b.word:SetPoint("BOTTOMRIGHT", -2, 2)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    for i, line in ipairs(tip()) do
      if i == 1 then GameTooltip:AddLine(line) else GameTooltip:AddLine(line, 1, 1, 1, true) end
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  b:Hide()
  return b
end

local function mins(s) return s == math.huge and "no end" or (math.floor(s / 60) .. " min") end

function X.Buttons()
  if X.bag then return X.bag, X.food end
  X.bag = button("BiSToolsXPBag", X.BAG_ITEM, function()
    local r = X.Rested()
    local state = r == "missing" and "Well-Rested is gone." or type(r) == "table"
      and ("Well-Rested: %d of %d, %s left."):format(r.stacks, X.RESTED_MAX, mins(r.left)) or "Well-Rested: unknown."
    return { "Unfurl your Cozy Sleeping Bag", state, "Rest inside a minute for each stack, up to " .. X.RESTED_MAX .. "." }
  end)
  X.food = button("BiSToolsXPFood", X.pick, function()
    local f = X.Fed()
    local state = f == "missing" and "Its Well Fed is gone." or type(f) == "table" and ("Well Fed: " .. mins(f.left) .. " left.")
      or "Well Fed: unknown."
    return { "Eat your XP food", state }
  end)
  return X.bag, X.food
end

--- Point the food button at the picked food (out of combat: a secure attribute).
function X.ArmFood()
  if not X.food or X.Fighting() then return false end
  local item = X.pick
  X.food:SetAttribute("item1", item and ("item:" .. item) or "")
  X.food.icon:SetTexture(item and icon(item) or 134400)
  return true
end

-- ------------------------------------------------------------------ looking

--- Anything changed? Only then does the box lay out (a secure layout, out of combat). And the one timer for "low".
function X.Look()
  if X.Fighting() then return false end
  if X.dirty then X.Pick() end
  local bag, food = X.ShowBag(), X.ShowFood()
  if X.bag then
    local r = X.Rested()
    X.bag.word:SetText(type(r) == "table" and tostring(r.stacks) or "")
  end
  local changed = bag ~= X.showBag or food ~= X.showFood
  X.showBag, X.showFood = bag, food
  if changed and NS.Box and NS.Box.Refresh then NS.Box.Refresh() end
  X.Arm()
  return changed
end

--- One timer, for the soonest moment a buff we hold turns "low". A fresh one replaces the last (X.token).
function X.Arm()
  local soon
  local r = not X.showBag and X.Rested()
  if type(r) == "table" and r.left ~= math.huge then soon = r.left - X.LOW_RESTED end
  local f = not X.showFood and X.pick and X.Fed()
  if type(f) == "table" and f.left ~= math.huge then
    local s = f.left - X.LOW_FOOD
    if not soon or s < soon then soon = s end
  end
  X.token = (X.token or 0) + 1
  X.due = nil
  if not soon or not (C_Timer and C_Timer.After) then return nil end
  local token = X.token
  X.due = math.max(1, soon + 1)
  C_Timer.After(X.due, function() if X.token == token then X.Look() end end)
  return X.due
end

--- What did I just eat? The bag item whose use is this spell.
function X.ItemForSpell(spellId)
  local C = C_Container
  if type(spellId) ~= "number" or not (C and C.GetContainerNumSlots and C.GetContainerItemID) then return nil end
  local spellOf = C_Item and C_Item.GetItemSpell
  if not spellOf then return nil end
  for bag = 0, 4 do
    local n = plain(ask(C.GetContainerNumSlots, bag)) or 0
    for slot = 1, n do
      local id = plain(ask(C.GetContainerItemID, bag, slot))
      if type(id) == "number" then
        local _, sid = ask(spellOf, id)
        if plain(sid) == spellId then return id end
      end
    end
  end
  return nil
end

--- Learn the food: a cast of a bag item, then within X.FOOD_WINDOW an experience Well Fed on me.
function X.Ate(spellId)
  local item = X.ItemForSpell(spellId)
  if item then X.ate = { item = item, at = now() } end
  return item
end

function X.Learn(db)
  db = db or X.db
  local a = X.ate
  if not (db and a) or now() - a.at > X.FOOD_WINDOW then return false end
  local fed = X.Fed()
  if type(fed) ~= "table" then return false end
  X.ate = nil
  if db.food == a.item then return false end
  db.food = a.item
  X.dirty = true
  NS.Print("xp: learned your XP food - eaten first while you have it")
  return true
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "UNIT_AURA", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
                     "UNIT_SPELLCAST_SUCCEEDED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, unit, _, spellId)
  if event == "BAG_UPDATE_DELAYED" or event == "PLAYER_ENTERING_WORLD" then X.dirty = true end   -- even in a fight
  if not (X.db and R:Enabled("xp")) or not X.Levelling() then return end
  if (event == "UNIT_AURA" or event == "UNIT_SPELLCAST_SUCCEEDED") and unit ~= "player" then return end
  if X.Fighting() then return end                               -- nothing in a fight; the fight's end looks again
  if event == "UNIT_SPELLCAST_SUCCEEDED" then X.Ate(plain(spellId)) return end
  if event == "UNIT_AURA" and X.ate then X.Learn() end
  X.Look()
end)
X.events = ev

R:Register({
  name = "xp",
  desc = "a button when your XP buffs run low: the sleeping bag, your XP food",
  usage = "/bist xp [food <item link> | food off | bag on|off]",
  defaults = {},
  options = {
    { kind = "toggle", label = "sleeping bag button", help = "While you level: a button in the BiS> tools box when Well-Rested is gone, short of 3 stacks or under 10 minutes - one click unfurls your Cozy Sleeping Bag.",
      get = function(db) return db.bag ~= false end, set = function(db, on) db.bag = on and true or false X.Look() end },
    { kind = "toggle", label = "XP food button", help = "While you level: a button when Well Fed XP Boost is gone or under 2 minutes - one click eats cooked XP food from your bags (the one you last ate first). Vendor food has no XP buff.",
      get = function(db) return db.eat ~= false end, set = function(db, on) db.eat = on and true or false X.Look() end },
  },
  OnInit = function(_, db) X.db = db end,
  OnLogin = function(_, db) X.db = db X.Buttons() X.dirty = true X.Look() end,
  OnEnable = function(_, db) X.db = db X.Look() end,
  OnDisable = function() X.showBag, X.showFood = nil, nil X.token = (X.token or 0) + 1 end,
  OnSlash = function(_, db, args)
    X.db = db
    args = tostring(args or "")
    local link = args:match("^food%s+(.+)$")
    if args == "food off" then
      db.food = nil X.dirty = true X.Look()
      return NS.Print("xp: no favourite - any XP food in your bags will do")
    elseif link then
      local id = tonumber(link:match("item:(%d+)") or link:match("^(%d+)$"))
      if not id then return NS.Print("xp: shift-click the food into the chat line after /bist xp food") end
      db.food = id X.dirty = true X.Look()
      return NS.Print("xp: your XP food is item %d - eaten first while you have it", id)
    elseif args == "bag on" or args == "bag off" then
      db.bag = args == "bag on" X.Look()
      return NS.Print("xp: sleeping bag button %s", db.bag and "on" or "off")
    end
    local r, f = X.Rested(), X.Fed()
    NS.Print("xp: Well-Rested %s; Well Fed %s; XP food %s", r == "missing" and "gone" or type(r) == "table"
      and (r.stacks .. "/" .. X.RESTED_MAX .. ", " .. mins(r.left)) or "unknown", f == "missing" and "gone" or type(f) == "table"
      and mins(f.left) or "unknown", X.pick and ("item " .. X.pick .. (X.pick == db.food and " (yours)" or ""))
      or "none in your bags")
  end,
})
