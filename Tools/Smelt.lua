-- BiSTools / Tools / Smelt.lua - smelting from the Processing app (23 Nov 2026).
--
-- Arn: "when i click an item it should disenchant if its a items and smelt if its a ore" - "build it".
--
-- HOW FOREVER CRAFTS: the newer profession calls (the old DoTradeSkill is not on Forever - the fence). A craft is
-- C_TradeSkillUI.CraftRecipe(recipe spell id, how many), and the game takes it only from a click of yours - so it runs inside
-- the row's press, never by itself. It may want the profession open first (learned from ProfessionMaster, which meets the same on
-- Forever - learn only): a click whose craft does not begin is followed by C_TradeSkillUI.OpenTradeSkill(Mining) on the next
-- click, and from then on within the click. You stand at a forge, as by hand; the game's own refusal ("Requires Forge") is caught
-- and said. Nothing ticks: a press, then one look a moment later (did a cast begin?). `/bist processing smelt` = what happened.
--
-- THE ORES (classic recipe spell ids, UNVERIFIED on Forever - each one is asked of the game: its name must say Smelt and you must
-- know it, or the row only looks): ore item id -> { recipe spell, ores per bar }.
local _, NS = ...
local SM = { MINING = 186, WAIT = 1.2 }
NS.Smelt = SM
SM.ORES = {
  [2770] = { 2657, 1 },    -- Copper Ore -> Smelt Copper
  [2771] = { 3304, 1 },    -- Tin Ore -> Smelt Tin
  [2775] = { 2658, 1 },    -- Silver Ore -> Smelt Silver
  [2772] = { 3307, 1 },    -- Iron Ore -> Smelt Iron
  [2776] = { 3308, 1 },    -- Gold Ore -> Smelt Gold
  [3858] = { 10097, 1 },   -- Mithril Ore -> Smelt Mithril
  [7911] = { 10098, 1 },   -- Truesilver Ore -> Smelt Truesilver
  [10620] = { 16153, 1 },  -- Thorium Ore -> Smelt Thorium
  [11370] = { 14891, 8 },  -- Dark Iron Ore -> Smelt Dark Iron
}

local function plain(v) if v ~= nil and issecretvalue and issecretvalue(v) then return nil end return v end
local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, ...)
  if ok then return plain(a), plain(b) end
end
local function fighting() return InCombatLockdown and InCombatLockdown() and true or false end
local function now() return GetTime and GetTime() or 0 end

--- The recipe's name from the game ("Smelt Copper"), or nil.
function SM.Name(spell) return ask(C_Spell and C_Spell.GetSpellName, spell) end
--- Do you know this recipe? (a learned recipe is a spell of yours)
function SM.Knows(spell)
  local n = SM.Name(spell)
  if type(n) ~= "string" or not n:find("Smelt", 1, true) then return false end
  return ask(IsPlayerSpell, spell) == true
end
--- Any smelting at all? (Copper is every miner's first)
function SM.Miner()
  for _, o in pairs(SM.ORES) do if SM.Knows(o[1]) then return true end end
  return false
end

--- The ores in your bags: { { item, count, spell, per, bars, known, name, icon }, ... }, most bars first.
function SM.Ores()
  local by = {}
  local C = C_Container
  if not (C and C.GetContainerNumSlots) then return {} end
  for bag = 0, 4 do
    for slot = 1, (ask(C.GetContainerNumSlots, bag) or 0) do
      local info = ask(C.GetContainerItemInfo, bag, slot)
      local id = type(info) == "table" and plain(info.itemID) or nil
      if id and SM.ORES[id] then by[id] = (by[id] or 0) + (plain(info.stackCount) or 1) end
    end
  end
  local out = {}
  for id, n in pairs(by) do
    local o = SM.ORES[id]
    out[#out + 1] = { item = id, count = n, spell = o[1], per = o[2], bars = math.floor(n / o[2]), known = SM.Knows(o[1]),
      name = ask(C_Item and C_Item.GetItemNameByID, id) or ("ore " .. id), icon = ask(C_Item and C_Item.GetItemIconByID, id) or 134400 }
  end
  table.sort(out, function(a, b) if a.bars ~= b.bars then return a.bars > b.bars end return a.item < b.item end)
  return out
end

--- Is Mining the profession the game has open right now?
function SM.Open()
  local T = C_TradeSkillUI
  if not T then return false end
  if T.IsTradeSkillReady and ask(T.IsTradeSkillReady) == false then return false end
  local info = ask(T.GetChildProfessionInfo)
  if type(info) ~= "table" or not info.professionID or info.professionID == 0 then info = ask(T.GetBaseProfessionInfo) end
  local id = type(info) == "table" and (info.parentProfessionID or info.professionID) or nil
  return id == SM.MINING
end

local function say(text) if NS.Proc and NS.Proc.Say then NS.Proc.Say(text) end SM.said = text end

--- Smelt `n` of an ore row - from a click only (the game takes a craft from nothing else).
function SM.Smelt(o, n)
  local T = C_TradeSkillUI
  SM.last = { at = now(), spell = o and o.spell, n = n, name = o and o.name }
  if fighting() then say("NOT IN A FIGHT") SM.last.why = "in a fight" return false end
  if not (T and T.CraftRecipe) then say("THIS GAME CANNOT CRAFT FROM AN ADDON") SM.last.why = "no CraftRecipe" return false end
  if not (o and o.known) then say("YOU DO NOT KNOW " .. tostring(o and SM.Name(o.spell) or "IT"):upper()) SM.last.why = "not known" return false end
  n = math.max(1, math.min(n or 1, o.bars))
  local was = SM.Open()
  SM.last.open = was
  if not was and SM.needOpen and T.OpenTradeSkill then
    local fine, opened = pcall(T.OpenTradeSkill, SM.MINING)
    SM.last.opened = fine and opened
  end
  SM.began, SM.err = nil, nil
  local fine, err = pcall(T.CraftRecipe, o.spell, n)
  SM.last.handed, SM.last.err = fine, not fine and tostring(err) or nil
  if not fine then say("THE GAME REFUSED: " .. tostring(err)) return false end
  say(("SMELTING %d %s"):format(n, n == 1 and "BAR" or "BARS"))
  local mine = SM.last
  if C_Timer and C_Timer.After then C_Timer.After(SM.WAIT, function() SM.Look(mine) end) end
  return true
end

--- A moment later: did it begin? No cast and no word from the game = this client wants Mining open: the next click opens it.
function SM.Look(mine)
  if SM.last ~= mine then return end
  local casting = ask(UnitCastingInfo, "player")
  mine.began = SM.began or (casting ~= nil) or nil
  if mine.began then return end
  if SM.err then mine.why = SM.err say(tostring(SM.err):upper()) return end
  if not mine.open then
    SM.needOpen = true
    mine.why = "nothing began with Mining closed: the next click opens it"
    say("CLICK AGAIN: MINING OPENS FIRST")
  else
    mine.why = "nothing began, with Mining open"
    say("NOTHING HAPPENED - /bist processing smelt")
  end
end

local ev = CreateFrame("Frame")
SM.events = ev
pcall(ev.RegisterEvent, ev, "UNIT_SPELLCAST_START")
pcall(ev.RegisterEvent, ev, "UI_ERROR_MESSAGE")
ev:SetScript("OnEvent", function(_, e, a1, a2, a3)
  local l = SM.last
  if not l or now() - l.at > SM.WAIT + 0.5 then return end      -- (only the moment after our own click)
  if e == "UNIT_SPELLCAST_START" and a1 == "player" and plain(a3) == l.spell then SM.began = true
  elseif e == "UI_ERROR_MESSAGE" then SM.err = plain(a2) or plain(a1) end
end)

--- `/bist processing smelt`: what the last click did.
function SM.Why()
  local l = SM.last
  if not l then return NS.Print("smelt: no click yet since the reload; a miner: %s", tostring(SM.Miner())) end
  NS.Print("smelt: %s x%s (recipe %s) - Mining was open: %s, opened: %s, handed to the game: %s, began: %s%s",
    tostring(l.name), tostring(l.n), tostring(l.spell), tostring(l.open), tostring(l.opened), tostring(l.handed), tostring(l.began),
    (l.why or l.err) and (" - " .. tostring(l.why or l.err)) or "")
end
