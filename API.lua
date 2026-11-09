--------------------------------------------------------------------------------
-- BiSToolsAPI: for other addons - BiS Guild first (16 Oct 2026).
--
-- Arn: "I like OpenMap, that opens its stuff via API - what do you think if we do that too" ...
-- "if installed it can API-call it", and "bisg can do its own thing if no BiS Tools". So a caller
-- never reaches into BiS Tools' insides (NS.Party, its saved table): it asks here, and here stays the
-- same while the insides change. Shaped like OpenMapAPI:
--   * BiSToolsAPI.version goes up when something is added; nothing is changed or taken away without
--     a new BiSToolsAPI.major.
--   * Nothing here changes BiS Tools' settings. Every call is safe before login (it answers nil,
--     "not ready") and with the tool switched off (nil, "party tool off").
--
-- People: a list of names (Forever's whole "Name Surname" - an invite needs it), or of tables
-- { name = , class = (shown, e.g. "Mage"), classFile = "MAGE", rank = }.
--
-- Since version 2 (21 Oct 2026, for BiS Memories - a death at a rival's hands is worth a picture):
--   IsRival(name) -> true when that name is on your rivals list (gold or silver), false when not, or
--                    nil, "not ready". Read-only; the rivals tool switched off still answers.
--
-- Since version 3 (21 Oct 2026, the ride clock - Arn: "can other addons api call BiS Tools for that flight timer"):
--   Rides(map)     -> the zeppelins and boats from that map (default: where you stand; a capital counts as its zone),
--                     a list of { id, name, ship, kind = "zeppelin"|"boat", to, docked, left (seconds: to the
--                     arrival, or while docked to the departure), timed (false until somebody rode it), by, via,
--                     age, line = the card's words }. The clock itself is LibBiSComm's (any BiS addon learns and
--                     shares it); this is the same answer the card shows. nil, "not ready" without the lib.
--   RideCard()     -> the lines the card shows now (a copy), or an empty list when it is hidden.
--
-- Since version 4 (8 Nov 2026, BiS> Codex - Arn: "whenever we make a game we have everything ... we can api call bis
-- tools for information on 3d models"). Creatures by their npc id (a number). Every answer is a copy; the codex tool
-- switched off still answers (it only stops learning). Before the saved table loads: nil, "not ready".
--   CodexCreature(npcId) -> { id, name (nil until the game has told us), display (the model id for
--                    PlayerModel:SetDisplayInfo; nil = use SetCreature(id)), level, type, family, rank (the client's
--                    classification word: "elite", "worldboss" ...), dungeon (a dungeon id, as CodexDungeon takes),
--                    boss (true/false), spells = { spell ids: the shipped ones, then the ones seen cast },
--                    seen = { [itemId] = times seen to drop }, met = times met (one per spawn) }
--                    - level/type/family/rank only once met. nil, "unknown" for an id the book has never seen.
--   CodexDungeon(dungeonId) -> the creature ids on that dungeon's plates, in room order ("rfc", "mc" ... - the ids
--                    in BiS Tools' Tools/CodexData.lua, the same as ADVENT's), or nil, "unknown".
--   CodexShow(npcId) -> opens the Codex at that creature's page (as a player's click would; it never switches the
--                    tool on). true, or nil, "unknown".
--   CodexName(npcId) -> the creature's name when the book has it, else nil - and the game is asked (the client answers
--                    the second ask, about a second later; ask again then). Any npc id, shipped or not.
--
-- Since version 5 (8 Nov 2026, BiS> bosses - Arn: "boss finder in dungeons"). Places by their instance map id
-- (GetInstanceInfo's 8th answer); the list is the game's own (DungeonEncounter).
--   Bosses(mapId) -> { map, name, kind = "dungeon"|"raid", here (true when you stand in it), bosses = { { id (the
--                    encounter id ENCOUNTER_END gives), name, group (a fight of several: never targeted by name),
--                    state = "down"|"near"|"marked"|"far"|"group" (this run's, only for where you stand), mark (the
--                    raid mark index it is given, 8 = skull) } } } - a copy. No mapId: where you stand (nil, "not in
--                    a boss place" outside). nil, "unknown" for a map the list does not have.
--   BossesShow()   -> opens the boss list (as a player's click would; never switches the tool on, never in a fight):
--                    true, or nil and why.
--
-- Since version 6 (8 Nov 2026, for BiS Memories - Arn: "this shows the boss from adventure the ones from acutal dungeon
-- dont"; inside a dungeon the game hides the creature's id at the kill, so a memory keeps only the boss's name).
--   BossFace(name) -> npcId, displayId (either may be nil) for a boss by its name: the one the boss finder met there,
--                    else the Codex's boss of that name (its names come in live, so an unknown one may answer a
--                    second later). nil when nobody knows it.
--------------------------------------------------------------------------------
local _, NS = ...

local API = { major = 1, version = 6 }
BiSToolsAPI = API

local function Party()
  local P = NS.Party
  if not (P and P.db) then return nil, "not ready" end
  local R = NS.Registry
  if R and R.Enabled and not R:Enabled("party") then return nil, "party tool off" end
  return P
end

-- whether the party tool can take invites now
function API.PartyReady()
  local P = Party()
  return P ~= nil
end

local function Entries(people)
  local out = {}
  for _, p in ipairs(type(people) == "table" and people or {}) do
    if type(p) == "string" and p ~= "" then
      out[#out + 1] = { name = p }
    elseif type(p) == "table" and type(p.name) == "string" and p.name ~= "" then
      out[#out + 1] = { name = p.name, class = p.class, classFile = p.classFile, rank = p.rank }
    end
  end
  return out
end

-- these people on the party tool's confirm list ("look it over, then Send"): sorted by class, an x
-- per person, the little inviting box. Whoever is with you already is shown as such, not invited.
-- Answers how many wait to be sent, or nil and why.
function API.InviteList(label, people)
  local P, why = Party()
  if not P then return nil, why end
  local here = { [P.Key(UnitName("player")) or "?"] = true }
  for _, m in ipairs(P.Members()) do here[m.key] = true end
  local go, with = {}, {}
  for _, e in ipairs(Entries(people)) do
    if here[P.Key(e.name) or "?"] then with[#with + 1] = e else go[#go + 1] = e end
  end
  if #go == 0 then return 0 end
  if not P.Leads() then return nil, "not leader" end
  P.wave = nil          -- a list from outside is its own; Refresh rechecks it (P.Recheck), never a wave
  return P.Confirm(P.db, type(label) == "string" and label or "invites", go, with)
end

-- one person, at once - the caller's click was the choice. Answers 1, or nil and why.
function API.InviteOne(name)
  local P, why = Party()
  if not P then return nil, why end
  if type(name) ~= "string" or name == "" then return nil, "no name" end
  if not P.Leads() then return nil, "not leader" end
  return P.InviteNames(P.db, { name }) > 0 and 1 or 0
end

-- is this name one of your rivals? (version 2). Read straight off the recap's rival list - never changed here.
function API.IsRival(name)
  local RC = NS.Recap
  if not (RC and RC.DB and RC.Rivals) then return nil, "not ready" end
  if type(name) ~= "string" or name == "" then return false end
  if issecretvalue then
    local ok, yes = pcall(issecretvalue, name)
    if not ok or yes then return false end
  end
  local ok, db = pcall(RC.DB)
  if not ok or type(db) ~= "table" then return nil, "not ready" end
  return RC.Rivals(db)[name] ~= nil
end

-- the rides from a map (version 3): read off the shared lib's clock - never changed here
function API.Rides(map)
  local RD = NS.Rides
  local lib = RD and RD.Lib()
  if not lib then return nil, "not ready" end
  if map == nil then map = RD.Map() end
  if type(map) ~= "number" then return {} end
  local out = {}
  for _, e in ipairs(lib:RidesAt(map)) do
    local s, sc = e.stop, e.sched
    out[#out + 1] = {
      id = s.id, name = s.name, ship = s.ship, kind = s.kind, to = s.toName,
      timed = sc ~= nil, docked = sc and sc.docked or false, left = sc and sc.left or nil,
      by = sc and sc.by or nil, via = sc and sc.via or nil, age = sc and sc.age or nil,
      line = lib:RideLine(s, sc),
    }
  end
  return out
end

-- what the ride card shows now (version 3): a copy of its lines, empty while it is hidden
function API.RideCard()
  local RD = NS.Rides
  local f = RD and RD.frame
  local out = {}
  if not (f and f:IsShown()) then return out end
  for _, row in ipairs(f.rows or {}) do
    if row:IsShown() then out[#out + 1] = row.say:GetText() end   -- a row of the card: its words
  end
  return out
end

-- the Codex (version 4): read off the book's own tables - copies, never the tables themselves
local function Codex()
  local C = NS.Codex
  if not (C and C.DB) then return nil end
  local ok, db = pcall(C.DB)
  if not ok or not db then return nil end
  return C
end

local function copy(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = copy(v) end
  return out
end

function API.CodexCreature(npcId)
  local C = Codex()
  if not C then return nil, "not ready" end
  if type(npcId) ~= "number" then return nil, "unknown" end
  local ok, c = pcall(C.Creature, npcId)
  if not ok or not c then return nil, "unknown" end
  return copy(c)
end

function API.CodexDungeon(dungeonId)
  local C = Codex()
  if not C then return nil, "not ready" end
  local d = C.DATA and C.DATA.dungeons[dungeonId]
  if not d then return nil, "unknown" end
  return copy(d.list)
end

function API.CodexShow(npcId)
  local C = Codex()
  if not (C and C.UI) then return nil, "not ready" end
  local ok, done, why = pcall(C.UI.Show, npcId)
  if not ok then return nil, "not ready" end
  if not done then return nil, why or "unknown" end
  return true
end

function API.CodexName(npcId)
  local C = Codex()
  if not C then return nil, "not ready" end
  local ok, name = pcall(C.Name, npcId)
  return ok and name or nil
end

-- the boss finder (version 5): read off its own tables - copies, never the tables themselves
function API.Bosses(mapId)
  local BF, D = NS.Bosses, NS.BossData
  if not (BF and D) then return nil, "not ready" end
  local here = BF.map
  mapId = mapId or here
  if not mapId then return nil, "not in a boss place" end
  local place = D[mapId]
  if not place then return nil, "unknown" end
  local out = { map = mapId, name = place.name, kind = place.kind, here = (mapId == here), bosses = {} }
  for _, e in ipairs(place.bosses) do
    local row = { id = e.id, name = e.name, group = e.group and true or false }
    if out.here then
      row.state = BF.State(e)
      row.mark = BF.mark and BF.mark[e.id] or nil
    end
    out.bosses[#out.bosses + 1] = row
  end
  return out
end

-- a boss's look by its name (version 6): the boss finder's own lookup, plain numbers only
function API.BossFace(name)
  local BF = NS.Bosses
  if type(name) ~= "string" or name == "" or not (BF and BF.NpcOf) then return nil end
  local ok, npc, display = pcall(BF.NpcOf, { name = name })
  if not ok then return nil end
  npc, display = tonumber(npc), tonumber(display)
  if not npc and not display then return nil end
  return npc, display
end

function API.BossesShow()
  local BF, R = NS.Bosses, NS.Registry
  if not (BF and BF.db) then return nil, "not ready" end
  if R and R.Enabled and not R:Enabled("bosses") then return nil, "bosses tool off" end
  if InCombatLockdown and InCombatLockdown() then return nil, "in a fight" end
  return BF.Toggle(true) and true or nil, "could not open"
end
