-- BiSTools / Tools / QuestMob.lua - the `questmob` tool: the NEXT QUEST MOB key (23 Nov 2026).
--
-- Arn pasted a levelling macro ("/cleartarget /tar MobYouAreLookingFor /cleartarget [dead] /tm [exists,nodead] !8 /ping
-- [@target,exists,nodead] Ping /startattack") and said "yes build it no attack": the same press, but nobody types a name.
-- The names come from YOUR QUEST LOG - every kill objective you have not finished ("0/8 Kobold Vermin slain" names its
-- creature; an item objective names its creatures only when the QuestieDB addon is installed, read through its own door
-- LibQuestieDB, the way BossQuests.lua does). No /startattack: a press marks and pings, it never pulls.
--
-- ONE SECURE MACRO BUTTON (BiSToolsQuestMob), never shown: a key presses it - the game's Key Bindings (the BiS>Keybinds
-- section, Bindings.xml) or `/bist qm key <KEY>`. Not in the BiS> tools box (Arn, 23 Nov: "dont use this box anymore").
-- What it will go for next is on the deck's Farm page. Its macro, written out of a fight only (targeting, marking and pinging are protected):
--   /cleartarget
--   /targetexact [noexists] <name>     one pair per creature still needed, the nearest first:
--   /cleartarget [dead]                a corpse never stops the search
--   ...
--   /tm [exists,nodead] !8             the skull, never on a corpse ("!" = set it, never toggle it off)
--   /ping [@target,exists,nodead] attack
-- As many names as fit QM.MACRO_MAX letters. "The nearest first" = a creature whose nameplate you saw in the last
-- QM.NEAR_FOR s, then the quest you last made progress on, then the log's order.
--
-- WHERE: everywhere but inside a dungeon or raid (BiS> bosses' QUESTS tab has those; a living creature's name is secret
-- inside). The log's dungeon quests (a header named like a dungeon) are left out outside too - their creatures are in it.
--
-- ONE KEY, THREE JOBS (Arn, 23 Nov: "in dungeon it does boss, out in world quest, in pvp rival"), QM.Mode():
--   in a dungeon or raid BiS> bosses knows   the boss FIND press (BF's own macro copied; our PostClick runs BF.AfterFind)
--   in a battleground or arena               the rival press (RC.TargetMacro: your gold rivals)
--   anywhere else                            the next quest mob
-- Each copy is fresh: BF.Write and RC.ApplyButton are followed by QM.Write (wrapped below).
--
-- WHAT IT COSTS: nothing while off. On: QUEST_LOG_UPDATE (one look QM.WAIT after a burst), the zone events and the fight's
-- two; nameplates only while the log needs a kill (one name asked, one table lookup).
local _, NS = ...
local R = NS.Registry
local QM = {}
NS.QuestMob = QM

QM.MACRO_MAX = 255
QM.WAIT = 0.5
QM.MARK = 8
QM.PING = "attack"
QM.NEAR_FOR = 60
QM.NAMES = 4              -- creatures one item objective may name (QuestieDB)
QM.ICON = "Interface\\GossipFrame\\AvailableQuestIcon"
QM.GLOW = 0.35
-- THE GAME'S KEY BINDINGS (Arn, 23 Nov: "can you add a keybind here pls" - "call the addon section BiS>Keybinds"):
-- Bindings.xml clicks the button by name, so it is made when the file loads, before the client reads the bindings.
QM.BINDING = "CLICK BiSToolsQuestMob:LeftButton"
_G["BINDING_NAME_" .. QM.BINDING] = "Next target: boss, quest mob, rival"
QM.BASE = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "QUEST_LOG_UPDATE", "PLAYER_REGEN_ENABLED" }

local function K() return NS.Farm end
local function plain(v)
  if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
  return v
end
local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a = pcall(fn, ...)
  if not ok then return nil end
  return plain(a)
end
local function words(v) v = plain(v) return type(v) == "string" and v ~= "" and v or nil end
local function fighting() return (InCombatLockdown and InCombatLockdown()) and true or false end
local function now() return (GetTime and GetTime()) or 0 end
local function db() return QM.db or {} end

-- ------------------------------------------------------------------ what the log still needs

--- Inside a dungeon, raid, battleground or arena: the key stands aside.
function QM.Inside()
  local inside, kind = false, nil
  if IsInInstance then
    local ok, a, b = pcall(IsInInstance)
    if ok then inside, kind = plain(a), plain(b) end
  end
  return inside == true and kind ~= "none"
end

--- The log headers that are dungeons (BossData's names, BQ.ALSO's other names), lower case without "the".
function QM.DungeonHeads()
  if QM.heads then return QM.heads end
  local BQ, out = NS.BossQuests, {}
  if BQ then
    for id, d in pairs(NS.BossData or {}) do
      local n = BQ.Norm(d.name)
      if n then out[n] = true end
      for _, a in ipairs(BQ.ALSO[id] or {}) do out[BQ.Norm(a)] = true end
    end
  end
  QM.heads = out
  return out
end

--- The creatures an item objective's item drops from, by QuestieDB (nil without it).
function QM.ItemNames(L, quest, nth)
  local BQ = NS.BossQuests
  local Q = L and L.Quest
  if not (BQ and type(Q) == "table" and type(Q.objectives) == "function") then return nil end
  local ok, book = pcall(Q.objectives, quest)
  local row = ok and type(book) == "table" and type(book[3]) == "table" and book[3][nth] or nil
  local item = row and tonumber(row[1])
  local I = L.Item
  if not (item and type(I) == "table" and type(I.npcDrops) == "function") then return nil end
  local ok2, npcs = pcall(I.npcDrops, item)
  if not ok2 then return nil end
  local names = BQ.Pick(L, npcs, { heads = {} })
  if #names == 0 then return nil end
  while #names > QM.NAMES do table.remove(names) end
  return names
end

--- Every creature your quests still need, in the log's order: { name, names, quest, title, have, need, what }.
function QM.Rows()
  local BQ = NS.BossQuests
  local rows = {}
  if not (BQ and C_QuestLog and C_QuestLog.GetQuestObjectives) then return rows end
  local heads = QM.DungeonHeads()
  local L = BQ.DB()
  for _, q in ipairs(BQ.Log()) do
    if not heads[BQ.Norm(q.header) or ""] then
      local ok, objs = pcall(C_QuestLog.GetQuestObjectives, q.id)
      objs = ok and type(objs) == "table" and objs or {}
      local items = 0
      for _, o in ipairs(objs) do
        local kind = words(o.type)
        if kind == "item" then items = items + 1 end
        if plain(o.finished) ~= true then
          local names
          if kind == "monster" then
            local n = BQ.Kill(o.text)
            names = n and { n } or nil
          elseif kind == "item" and L then
            names = QM.ItemNames(L, q.id, items)
          end
          if names then
            rows[#rows + 1] = { name = names[1], names = names, quest = q.id, title = q.title,
              have = tonumber(plain(o.numFulfilled)) or 0, need = tonumber(plain(o.numRequired)) or 1, what = words(o.text) }
          end
        end
      end
    end
  end
  return rows
end

--- The order a press tries them: seen near (newest first), then the quest you last made progress on, then the log.
function QM.Order(rows)
  local t = now()
  local function near(e)
    local best
    for _, n in ipairs(e.names) do
      local at = QM.near[n]
      if at and t - at <= QM.NEAR_FOR and (not best or at > best) then best = at end
    end
    return best
  end
  for i, e in ipairs(rows) do e.at, e.seen = i, near(e) end
  table.sort(rows, function(a, b)
    if (a.seen ~= nil) ~= (b.seen ~= nil) then return a.seen ~= nil end
    if a.seen and b.seen and a.seen ~= b.seen then return a.seen > b.seen end
    local la, lb = a.quest == QM.lastQuest, b.quest == QM.lastQuest
    if la ~= lb then return la end
    return a.at < b.at
  end)
  return rows
end

-- ------------------------------------------------------------------ the macro (the suite runs it)

--- One press: clear, every name that fits (a corpse cleared after each), then the skull and the ping on a living one.
function QM.Macro(rows)
  local head = "/cleartarget"
  local tail = "/tm [exists,nodead] !" .. QM.MARK .. "\n/ping [@target,exists,nodead] " .. QM.PING
  local out, len, seen, n = { head }, #head + 1 + #tail, {}, 0
  for _, e in ipairs(rows or {}) do
    for _, name in ipairs(e.names) do
      if not seen[name] then
        local pair = "/targetexact [noexists] " .. name .. "\n/cleartarget [dead]"
        if len + #pair + 1 > QM.MACRO_MAX then break end
        seen[name] = true
        out[#out + 1] = pair
        len, n = len + #pair + 1, n + 1
      end
    end
  end
  if n == 0 then return "", 0 end
  out[#out + 1] = tail
  return table.concat(out, "\n"), n
end

-- ------------------------------------------------------------------ the button (secure: written out of a fight)

function QM.Button()
  if QM.btn then return QM.btn end
  local k = K()
  local b = CreateFrame("Button", "BiSToolsQuestMob", UIParent, "SecureActionButtonTemplate")
  b:SetSize(26, 26)
  b:RegisterForClicks("AnyDown")
  b:SetAttribute("type", "macro")
  b:SetAttribute("macrotext", "")
  if k then
    k.tex(b, "BACKGROUND", "field", 0.95)
    b.edge = k.border(b, "accent", 1)
    b.wash = k.tex(b, "BORDER", "accent", 0)
  end
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon:SetTexture(QM.ICON)
  b:SetScript("PostClick", function()
    if not R:Enabled("questmob") then NS.Print("quest mob is off: /bist on qm") return end
    if QM.mode == "boss" and NS.Bosses and NS.Bosses.AfterFind then NS.Bosses.AfterFind() end
  end)
  b:SetScript("OnEnter", function(self) QM.Tip(self) end)
  b:SetScript("OnLeave", function(self)
    if self.wash then self.wash:SetAlpha(0) end
    if self.edge then self.edge:set("accent", 1) end
    if GameTooltip then GameTooltip:Hide() end
  end)
  b:Hide()
  QM.btn = b
  return b
end

--- The button's tooltip: who a press looks for, in its order.
function QM.Tip(b)
  if b.wash then b.wash:SetAlpha(QM.GLOW) end
  if b.edge then b.edge:set("gold", 1) end
  if not GameTooltip then return end
  GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
  GameTooltip:AddLine("Next quest mob")
  for i, e in ipairs(QM.rows or {}) do
    if i > 6 then GameTooltip:AddLine(("... and %d more"):format(#QM.rows - 6), 0.6, 0.6, 0.6) break end
    GameTooltip:AddDoubleLine(e.name .. (e.seen and "  (near)" or ""), ("%d/%d"):format(e.have, e.need), 1, 1, 1, 0.6, 0.6, 0.6)
  end
  GameTooltip:AddLine("A press targets the nearest one alive, puts the skull on it and pings it. It never attacks.", 0.6, 0.6, 0.6, true)
  local key = QM.KeyName()
  GameTooltip:AddLine(key and ("Key: " .. key) or "Bind it: Key Bindings > BiS>Keybinds", 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

--- Which job the key does here: "boss" / "rival" / "quest" / "none" (a dungeon BiS> bosses does not know, or it is off).
function QM.Mode()
  local BF, RC = NS.Bosses, NS.Recap
  if RC and RC.InPvP and RC.InPvP() then return R:Enabled("rivals") and "rival" or "none" end
  if QM.Inside() then return (BF and BF.map and R:Enabled("bosses")) and "boss" or "none" end
  return "quest"
end

--- The press for a job that is not the quest mob: the boss FIND's own macro, or your rivals'.
function QM.Borrowed(mode)
  if mode == "boss" then
    local k = NS.Bosses.FindKey()
    return tostring(k:GetAttribute("macrotext") or ""), NS.Bosses.findFor and 1 or 0
  end
  if mode == "rival" then return NS.Recap.TargetMacro(R:DBFor(R:Get("recap"))) end
  return "", 0
end

--- The log read, the order made, the macro written - now, or after the fight.
function QM.Write()
  if fighting() then QM.dirty = true return false end
  QM.dirty = nil
  local mode = R:Enabled("questmob") and QM.Mode() or "none"
  local on = mode == "quest"
  local rows = on and QM.Rows() or {}
  QM.Progress(rows)
  QM.rows = QM.Order(rows)
  QM.want = {}
  for _, e in ipairs(QM.rows) do for _, n in ipairs(e.names) do QM.want[n] = true end end
  local m, n
  if on then m, n = QM.Macro(QM.rows) else m, n = QM.Borrowed(mode) end
  QM.mode, QM.macro, QM.count = mode, m, n
  QM.Button():SetAttribute("macrotext", m)
  QM.Plates(on and next(QM.want) ~= nil)
  return true
end

--- The quest you last made progress on (its count went up) moves to the front.
function QM.Progress(rows)
  local counts = {}
  for _, e in ipairs(rows) do counts[e.quest] = (counts[e.quest] or 0) + e.have end
  for q, c in pairs(counts) do
    if QM.counts and QM.counts[q] and c > QM.counts[q] then QM.lastQuest = q end
  end
  QM.counts = counts
end

-- ------------------------------------------------------------------ the key

function QM.ApplyKey()
  if InCombatLockdown() then QM.keyDirty = true return false end   -- (a binding is protected in a fight)
  QM.keyDirty = nil
  local b = QM.Button()
  ClearOverrideBindings(b)
  if db().key and R:Enabled("questmob") then SetOverrideBindingClick(b, true, db().key, "BiSToolsQuestMob") end
  return true
end

--- The key that presses it: yours from /bist qm key, else the game's Key Bindings (BiS>Keybinds).
function QM.KeyName()
  if db().key then return db().key end
  return GetBindingKey and words(ask(GetBindingKey, QM.BINDING)) or nil
end

function QM.Key(word)
  if fighting() then NS.Print("quest mob: not in a fight") return false end
  word = tostring(word or ""):upper()
  if word == "" or word == "NONE" then
    db().key = nil
    QM.ApplyKey()
    NS.Print("quest mob: no key")
    return false
  end
  db().key = word
  QM.ApplyKey()
  NS.Print("quest mob: %s targets the next creature your quests need (skull + ping, never attacks)", word)
  return word
end

-- ------------------------------------------------------------------ events

QM.near = {}
local ev = CreateFrame("Frame")
QM.events = ev

--- Nameplates: only while the log names someone (a seen one goes to the front at the next look).
function QM.Plates(on)
  if (QM.plates and true or false) == (on and true or false) then return end
  QM.plates = on and true or false
  if on then pcall(ev.RegisterEvent, ev, "NAME_PLATE_UNIT_ADDED") else pcall(ev.UnregisterEvent, ev, "NAME_PLATE_UNIT_ADDED") end
end

--- One look QM.WAIT after a burst of events.
function QM.Soon()
  if QM.pending then return end
  QM.pending = true
  C_Timer.After(QM.WAIT, function()
    QM.pending = nil
    if R:Enabled("questmob") then QM.Write() end
  end)
end

function QM.Listen(on)
  for _, e in ipairs(QM.BASE) do
    if on then pcall(ev.RegisterEvent, ev, e) else pcall(ev.UnregisterEvent, ev, e) end
  end
  if not on then QM.Plates(false) end
end

ev:SetScript("OnEvent", function(_, e, unit)
  if e == "NAME_PLATE_UNIT_ADDED" then
    local name = words(ask(UnitName, unit))
    if name and QM.want and QM.want[name] then
      local fresh = not QM.near[name] or now() - QM.near[name] > QM.NEAR_FOR
      QM.near[name] = now()
      if fresh and not fighting() then QM.Soon() end
    end
    return
  end
  if e == "PLAYER_REGEN_ENABLED" then
    if QM.keyDirty then QM.ApplyKey() end
    if QM.dirty then QM.Soon() end
    return
  end
  if fighting() then QM.dirty = true return end
  QM.Soon()
end)

-- ------------------------------------------------------------------ the tool

function QM.Status()
  local rows = QM.rows or {}
  NS.Print("quest mob: %s, key %s, %d creature%s in the press", R:Enabled("questmob") and "on" or "off",
    tostring(QM.KeyName() or "none - Key Bindings > BiS>Keybinds"), QM.count or 0, (QM.count == 1) and "" or "s")
  local job = { boss = "here it does BiS> bosses' FIND", rival = "here it targets your rivals", none = "here it does nothing (turn on bosses / rivals)" }
  if job[QM.mode] then NS.Print("  %s", job[QM.mode]) end
  for i, e in ipairs(rows) do
    if i > 8 then break end
    NS.Print("  %d. %s  %d/%d%s  (%s)", i, e.name, e.have, e.need, e.seen and "  near" or "", tostring(e.title or ""))
  end
end

QM.Button()                                    -- (now: the game's binding clicks it by name)

-- the borrowed presses stay fresh: after the boss finder or the rival button writes, so does the key
local function after(t, key)
  local fn = t and t[key]
  if type(fn) ~= "function" then return end
  t[key] = function(...)
    local a, b = fn(...)
    if R:Enabled("questmob") and not fighting() and (QM.mode ~= "quest" or QM.Mode() ~= "quest") then QM.Write() end
    return a, b
  end
end
after(NS.Bosses, "Write")
after(NS.Recap, "ApplyButton")

R:Register({
  name = "questmob",
  short = "qm",
  defaultOff = true,
  desc = "next quest mob: one key targets the nearest creature your quests still need, puts the skull on it and pings it",
  usage = "/bist qm [key <KEY> | why]",
  defaults = {},
  OnInit = function(_, d) QM.db = d end,
  OnLogin = function(_, d)
    QM.db = d
    if R:Enabled("questmob") then QM.Listen(true) QM.Write() QM.ApplyKey() end
  end,
  OnEnable = function(_, d) QM.db = d QM.Listen(true) QM.Write() QM.ApplyKey() end,
  OnDisable = function()
    QM.Listen(false)
    QM.Write()
    QM.ApplyKey()
  end,
  OnSlash = function(_, d, args)
    QM.db = d
    local cmd, rest = tostring(args or ""):match("^(%S*)%s*(.-)%s*$")
    if cmd == "key" then QM.Key(rest) return end
    if cmd == "why" then
      QM.Write()
      NS.Print("quest mob: the press (%d letters):", #(QM.macro or ""))
      for l in tostring(QM.macro or ""):gmatch("[^\n]+") do NS.Print("  %s", l) end
      return
    end
    QM.Write()
    QM.Status()
  end,
})
