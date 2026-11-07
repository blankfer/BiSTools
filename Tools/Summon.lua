-- BiSTools / Tools / Summon.lua
-- The summoner's window: who still needs a summon, furthest first, one click
-- to target. SummonScan v0.4 folded onto the Registry, with its guesses swapped
-- for facts wherever the other client carries LibBiSComm.
--
--   fact   the peer runs a BiS addon: THEY say whether they are inside an
--          instance, where they stand, and what happened to the offer
--   guess  everyone else: roster zone string, UnitPosition (nil across an
--          instance line), the instance-name blacklist, and a park timer
--
-- The two never look alike on screen. A guess row is muted with a "?".
--
-- Two things in this file are NOT gated by /bist off summon:
--   * the lib itself (booted in Core/Init.lua, never touched here)
--   * the NAG - the reward for the peer who installed and configured nothing:
--     a summon offer makes noise until they answer it. /bist summon nag off is
--     its own switch. The tool toggle only kills the summoner's window.
local ADDON, NS = ...

-- NOT ON WOW FOREVER (6 Oct 2026). Arn: "no more summoning stone so let's sunset the summon
-- module" - and then "off on Forever only": TBC players keep it. So on Forever this file stops
-- here: no tool registered, no window, no nag, no /bist summon, no `the key`. The saved keys are left
-- alone, because the same account may still play TBC.
--
-- Asked by INTERFACE NUMBER, not by a feature, on purpose: whether stones exist is game content,
-- not an API, and Forever carries every API a summon needs. 16000-19999 is Forever's range (it says
-- 16001; NovaInstanceTracker and ProfessionMaster draw the same line). WOW_PROJECT_ID cannot tell
-- them apart - on the beta it still reads 1, retail's (Overlord, Sync.lua).
do
  local iface = GetBuildInfo and select(4, GetBuildInfo())
  if type(iface) == "number" and iface >= 16000 and iface < 20000 then
    NS.SummonSunset = true
    return
  end
end

local T = NS.T
local K = NS.Farm                -- the Innervate-style kit: tex / fs / border / HeaderButton / color

local SM = { rows = {} }
NS.Summon = SM

--- Is the summon tool switched on? (Forever 1.0: the nag, the request pings and the window popping up for
--- everyone at a stone all answer to it now - a new install has it off and must hear nothing.)
function SM.On()
  local R = NS.Registry
  local ok, on = pcall(function() return R and NS.DB() and R:Enabled("summon") end)
  return ok and on and true or false
end

--- A value the client will let us look at, or nil (Forever hides names, positions and flags in a fight).
local function plain(v)
  if v == nil then return nil end
  if K and K.Plain then return K.Plain(v) end
  if issecretvalue then
    local ok, s = pcall(issecretvalue, v)
    if not ok or s then return nil end
  end
  return v
end
SM.Plain = plain

SM.SCORE_OTHER_WORLD = 2e9       -- Azeroth <-> Outland: summon first, always
SM.SCORE_OTHER_ZONE  = 1e9       -- same world, other zone
SM.SCORE_UNKNOWN_POS = 5e8       -- same zone, cannot place them
-- which world a zone string lives in; everything not listed is Azeroth
SM.OUTLAND_ZONES = {}
for _, z in ipairs({ "Hellfire Peninsula", "Zangarmarsh", "Terokkar Forest", "Nagrand",
  "Blade's Edge Mountains", "Netherstorm", "Shadowmoon Valley", "Shattrath City" }) do
  SM.OUTLAND_ZONES[z:lower()] = true
end
function SM.WorldOf(mapId, zone)
  local id = tonumber(mapId)
  if id == 530 then return "Outland" end
  if id == 0 or id == 1 then return "Azeroth" end
  if type(zone) == "string" and SM.OUTLAND_ZONES[zone:lower()] then return "Outland" end
  if type(zone) == "string" and zone ~= "" then return "Azeroth" end
  return nil
end
SM.DEFAULT_NEAR      = 80        -- visible inside this = already at the stone
SM.DEFAULT_LINGER    = 8
SM.DEFAULT_RETRY     = 120       -- park for a guess (no word back)
SM.FACT_PARK         = 15        -- park for a fact: their client reports the offer inside the cast
SM.DEFAULT_ROWS      = 6
SM.MAX_ROWS          = 10
SM.ROW_H, SM.W       = 14, 170
SM.FOOT_H            = 16
SM.ALL_W             = 44        -- the "all" button on the footer's right
SM.STATUS_H          = 12        -- the "N at stone - M in" line under the rows
-- the "BiS> _" prompt lives in the header title (BiSTheme.Console); it cycles the
-- addon name and the state slots and says events. SM.Log / SM.PaintConsole wrap it.
SM.REQ_TTL           = 600       -- a request nobody answered dies after 10 min
SM.NAG_EVERY         = 20
SM.STONE_PATTERNS    = { "summoning stone", "meeting stone" }

-- Zones nobody gets summoned out of. Only a GUESS needs this: a fact peer says
-- inInstance itself. enUS; "/bist summon ban" adds the rest.
SM.INSTANCE_ZONES = {}
for _, z in ipairs({
  "Karazhan", "Zul'Aman", "Gruul's Lair", "Magtheridon's Lair", "Serpentshrine Cavern",
  "Tempest Keep", "The Eye", "Hyjal Summit", "The Battle for Mount Hyjal", "Black Temple",
  "Sunwell Plateau", "Hellfire Ramparts", "The Blood Furnace", "The Shattered Halls",
  "Mana-Tombs", "Auchenai Crypts", "Sethekk Halls", "Shadow Labyrinth", "The Slave Pens",
  "The Underbog", "The Steamvault", "Old Hillsbrad Foothills", "The Black Morass",
  "The Arcatraz", "The Botanica", "The Mechanar", "Magisters' Terrace", "Molten Core",
  "Onyxia's Lair", "Blackwing Lair", "Zul'Gurub", "Ruins of Ahn'Qiraj", "Temple of Ahn'Qiraj",
  "Ahn'Qiraj", "Naxxramas", "Ragefire Chasm", "Wailing Caverns", "The Deadmines",
  "Shadowfang Keep", "Blackfathom Deeps", "The Stockade", "Gnomeregan", "Razorfen Kraul",
  "Razorfen Downs", "Scarlet Monastery", "Uldaman", "Zul'Farrak", "Maraudon",
  "The Temple of Atal'Hakkar", "Blackrock Depths", "Blackrock Spire", "Lower Blackrock Spire",
  "Upper Blackrock Spire", "Dire Maul", "Stratholme", "Scholomance",
}) do SM.INSTANCE_ZONES[z:lower()] = z end

-- ---------------------------------------------------------------- pure logic
-- entry = { unit, name, zone, online, visible, x, y, instanceID, index,
--           fact = bool, where = peer.where or nil, summon = peer.summon or nil }
-- me    = { zone, x, y, instanceID }

function SM.IsBannedZone(zone, ban, allow)
  if type(zone) ~= "string" or zone == "" then return false end
  local z = zone:lower()
  if allow and allow[z] then return false end
  if ban and ban[z] then return true end
  return SM.INSTANCE_ZONES[z] ~= nil
end

local function dist(ax, ay, bx, by)
  local dx, dy = ax - bx, ay - by
  return math.sqrt(dx * dx + dy * dy)
end

-- nil = not a candidate (inside). A fact peer is scored from what it SAID.
-- Arn's order (8 Sep): other world first, then same world other zone, then
-- same zone by yards, furthest first. Returns score, and the world they are in.
function SM.Score(e, me)
  if not e.online then return nil end
  local myWorld = SM.WorldOf(me.instanceID, me.zone)
  if e.fact and e.where then
    local w = e.where
    if w.inInstance then return nil end
    local theirWorld = SM.WorldOf(w.mapId, w.zone)
    if theirWorld and myWorld and theirWorld ~= myWorld then return SM.SCORE_OTHER_WORLD, theirWorld end
    if w.x and w.y and me.x and me.y and tostring(w.mapId) == tostring(me.instanceID or "") then
      return dist(w.x, w.y, me.x, me.y), theirWorld
    end
    -- their WHERE cannot be placed against mine (lib 1 sent no mapId outdoors),
    -- but the client can see them: UnitPosition is good enough for yards
    if e.x and e.y and me.x and me.y and e.instanceID and e.instanceID == me.instanceID then
      return dist(e.x, e.y, me.x, me.y), theirWorld
    end
    if w.zone ~= "" and me.zone and w.zone ~= me.zone then return SM.SCORE_OTHER_ZONE, theirWorld end
    return SM.SCORE_UNKNOWN_POS, theirWorld
  end
  local theirWorld = SM.WorldOf(e.instanceID, e.zone)
  if theirWorld and myWorld and theirWorld ~= myWorld then return SM.SCORE_OTHER_WORLD, theirWorld end
  if e.zone and me.zone and e.zone ~= me.zone then return SM.SCORE_OTHER_ZONE, theirWorld end
  local samePlace = e.instanceID and me.instanceID and e.instanceID == me.instanceID
  if samePlace and e.x and e.y and me.x and me.y then return dist(e.x, e.y, me.x, me.y), theirWorld end
  return SM.SCORE_UNKNOWN_POS, theirWorld
end

-- what the row says about a summon already in flight, or nil
--   fact: OFFER -> seconds their client says are left; OK -> 0 ("ok", they took it)
--   guess: the park timer we set when the summoner clicked them
function SM.Waiting(e, tried, now)
  if e.fact and e.summon then
    if e.summon.state == "OK" then return 0, "ok" end
    if e.summon.state == "OFFER" then
      local left = (e.summon.at or now) + (e.summon.left or SM.DEFAULT_RETRY) - now
      if left > 0 then return left, "offer" end
      return nil
    end
  end
  local until_ = tried and tried[e.name]
  if until_ and until_ > now then return until_ - now, "park" end
  return nil
end

-- opts = { near, ban, allow, tried, now }
-- Returns ranked list + how many were skipped for being inside.
function SM.Rank(entries, me, opts)
  opts = opts or {}
  local nearYards = opts.near or SM.DEFAULT_NEAR
  local now = opts.now or 0
  local out, inside, atStone = {}, 0, 0
  for _, e in ipairs(entries) do
    if not e.online then
      -- offline: not listed, not counted
    elseif e.asked then
      -- "request a summon" beats every filter: he asked, he is listed, on top
      local sc, world = SM.Score(e, me)
      out[#out + 1] = { unit = e.unit, name = e.name, score = sc or SM.SCORE_UNKNOWN_POS, world = world,
        index = e.index or 0, fact = e.fact and true or false, asked = true }
      local w, why = SM.Waiting(e, opts.tried, now)
      out[#out].waiting, out[#out].why = w, why
    elseif e.atStone then
      atStone = atStone + 1                              -- standing at a known stone: no summon needed
      if opts.all then out[#out + 1] = { unit = e.unit, name = e.name, score = -2, index = e.index or 0,
        fact = e.fact and true or false, here = true } end
    elseif (e.fact and e.where and e.where.inInstance)
        or (not e.fact and SM.IsBannedZone(e.zone, opts.ban, opts.allow)) then
      inside = inside + 1
      if opts.all then out[#out + 1] = { unit = e.unit, name = e.name, score = -1, index = e.index or 0,
        fact = e.fact and true or false, inside = true } end
    else
      local score, world = SM.Score(e, me)
      if score and (score < nearYards and e.visible) then
        -- standing with me: no summon needed
        if opts.all then out[#out + 1] = { unit = e.unit, name = e.name, score = -2, index = e.index or 0,
          fact = e.fact and true or false, here = true } end
      elseif score then
        local waiting, why = SM.Waiting(e, opts.tried, now)
        out[#out + 1] = {
          unit = e.unit, name = e.name, score = score, world = world, index = e.index or 0,
          fact = e.fact and true or false, waiting = waiting, why = why, asked = false,
        }
      end
    end
  end
  table.sort(out, function(a, b)
    local ai, bi = (a.inside or a.here) and true or false, (b.inside or b.here) and true or false
    if ai ~= bi then return bi end                       -- inside / here: last of all (unrolled only)
    local aw, bw = a.waiting ~= nil, b.waiting ~= nil
    if aw ~= bw then return bw end                       -- in-flight sink
    if aw and a.waiting ~= b.waiting then return a.waiting < b.waiting end
    if a.asked ~= b.asked then return a.asked end        -- "request a summon" jumps the queue
    if a.score ~= b.score then return a.score > b.score end
    if a.fact ~= b.fact then return a.fact end           -- a fact outranks a guess at equal score
    if a.name ~= b.name then return a.name < b.name end
    return a.index < b.index
  end)
  return out, inside, atStone
end

function SM.ClockText(secs)
  secs = math.floor(secs or 0)
  if secs < 0 then secs = 0 end
  return ("%d:%02d"):format(math.floor(secs / 60), secs % 60)
end

function SM.IsStoneText(text, custom)
  -- hidden FIRST: on Forever the tooltip's line can be a secret string - type() says "string", and even
  -- `== ""` is refused (the 7 Nov sweep)
  text = plain(text)
  if type(text) ~= "string" or text == "" then return false end
  custom = plain(custom)
  local t = text:lower()
  if type(custom) == "string" and custom ~= "" and t:find(custom:lower(), 1, true) then return true end
  for _, p in ipairs(SM.STONE_PATTERNS) do
    if t:find(p, 1, true) then return true end
  end
  return false
end

-- mode: "on" (pinned) | "off" | "auto" (stone mouseover, then linger)
function SM.ShouldShow(mode, seenAt, now, linger)
  if mode == "on" then return true end
  if mode == "off" then return false end
  if type(seenAt) ~= "number" then return false end
  return (now - seenAt) < (linger or SM.DEFAULT_LINGER)
end

-- yards are only worth showing when the summoner stands at the stone (or is
-- looking at one): then "120y" means 120 yards from the stone. Anywhere else
-- a number would be distance from wherever you happen to be, which is noise.
function SM.InfoText(e, atStone)
  if e.inside then return "inside" end
  if e.here then return "here" end
  if e.why == "ok" then return "ok" end
  if e.waiting then return SM.ClockText(e.waiting) end
  if e.asked then return "asks" end
  if e.score >= SM.SCORE_OTHER_WORLD then return e.world or "world" end
  if e.score >= SM.SCORE_OTHER_ZONE then return "far" end
  if e.score >= SM.SCORE_UNKNOWN_POS then return "" end
  if atStone then return math.floor(e.score) .. "y" end
  return ""
end

-- am I at (or looking at) a stone right now?
function SM.MeAtStone(db)
  if SM.stoneSeen and (GetTime() - SM.stoneSeen) < 3 then return true end
  local py, px, _, pinst = UnitPosition("player")
  local zone = (GetRealZoneText and GetRealZoneText()) or ""
  return SM.NearStone(db, pinst, zone, px, py, db.near or SM.DEFAULT_NEAR)
end

-- ---------------------------------------------------------------- gather
function SM.Lib() return _G.LibBiSComm end

function SM.Gather()
  local entries = {}
  local lib = SM.Lib()
  local n = GetNumGroupMembers and GetNumGroupMembers() or 0
  local function add(unit, name, zone, online, visible, x, y, inst, i)
    local e = { unit = unit, name = name, zone = zone, online = online, visible = visible,
      x = x, y = y, instanceID = inst, index = i }
    if lib and lib:HasLib(name) then
      e.fact = true
      local p = lib:Peer(name)
      if p then
        e.where, e.summon = p.where, p.summon
        -- a peer still on lib minor 4 announces a bystander's CONFIRM_SUMMON as an
        -- OFFER with no summoner: not an offer, do not park him on it
        if e.summon and e.summon.state == "OFFER" and (e.summon.summoner or "") == "" then e.summon = nil end
      end
    end
    e.asked = SM.Asked(name, GetTime())
    local near = (SM.db and SM.db.near) or SM.DEFAULT_NEAR
    if e.fact and e.where and not e.where.inInstance then
      e.atStone = SM.NearStone(SM.db, e.where.mapId, e.where.zone, e.where.x, e.where.y, near)
    elseif not e.fact and x and y then
      e.atStone = SM.NearStone(SM.db, inst, zone or ((GetRealZoneText and GetRealZoneText()) or ""), x, y, near)
    end
    entries[#entries + 1] = e
  end
  -- EVERY ANSWER ASKED "HIDDEN?" FIRST (the 7 Nov sweep): this runs every 2 s while the window shows, raid fights
  -- included, where Forever can hide a member's position, visibility, connection and even the name - and a hidden
  -- value refuses arithmetic, a truth test and being a table key. A member the client will not tell us about is
  -- left out of this pass (the next one, 2 s later, asks again).
  local function hid(v) return v ~= nil and plain(v) == nil end
  local function member(unit, name, zone, online, i)
    if hid(name) or hid(zone) or hid(online) or type(name) ~= "string" or name == "" then return end
    local okU, me = pcall(UnitIsUnit, unit, "player")
    if not okU or hid(me) or me then return end
    local okP, y, x, _, inst = pcall(UnitPosition, unit)
    if not okP or hid(y) or hid(x) or hid(inst) then return end
    local okV, vis = pcall(UnitIsVisible, unit)
    if not okV or hid(vis) then return end
    if online == nil then
      local okC, con = pcall(UnitIsConnected, unit)
      if not okC or hid(con) then return end
      online = con
    end
    local okS, short = pcall(function() return lib and lib.Short(name) or name end)
    short = okS and plain(short) or nil
    add(unit, type(short) == "string" and short or name, zone, online and true or false, vis and true or false, x, y, inst, i)
  end
  if IsInRaid and IsInRaid() then
    for i = 1, n do
      local okR, name, _, _, _, _, _, zone, online = pcall(GetRaidRosterInfo, i)
      if okR then member("raid" .. i, name, zone, online == nil and false or online, i) end
    end
  elseif n > 0 then
    for i = 1, n - 1 do
      local unit = "party" .. i
      local okE, exists = pcall(UnitExists, unit)
      if okE and not hid(exists) and exists then
        local okN, name = pcall(UnitName, unit)
        if okN then member(unit, name, nil, nil, i) end
      end
    end
  end
  local py, px, _, pinst = UnitPosition("player")
  local me = { zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()),
    x = px, y = py, instanceID = pinst }
  return entries, me
end

-- ---------------------------------------------------------------- state
SM.tried = {}          -- name -> GetTime() the park lapses (session only)
SM.pending = {}        -- combat queue: units / visibility / rows

function SM.Park(db, name, secs)
  if not name then return end
  local lib = SM.Lib()
  local fact = lib and lib:HasLib(name)
  SM.tried[name] = GetTime() + (secs or (fact and SM.FACT_PARK) or db.retry or SM.DEFAULT_RETRY)
  SM.Refresh(db)
end

function SM.Unpark(db, name)
  if name then SM.tried[name] = nil else wipe(SM.tried) end
  SM.Refresh(db)
end

-- ---------------------------------------------------------------- stones
-- No wowhead. A client that hovers a stone is standing on it: record its own
-- position under map|zone, tell the raid (SUMMON|STONE), keep it in the db.
-- "At the stone" is then a distance to a known stone, not to the summoner.
function SM.StoneKey(map, zone) return tostring(map or "") .. "|" .. tostring(zone or "") end

function SM.LearnStone(db, broadcast)
  local py, px, _, pinst = UnitPosition("player")
  if not px or not py then return nil end
  local zone = (GetRealZoneText and GetRealZoneText()) or ""
  local key = SM.StoneKey(pinst, zone)
  db.stones = db.stones or {}
  local st = db.stones[key]
  if st then
    -- drift toward the newest sighting, they are all within a few yards
    st.x, st.y = (st.x * 3 + px) / 4, (st.y * 3 + py) / 4
  else
    st = { map = pinst, zone = zone, x = px, y = py }
    db.stones[key] = st
    SM.Log("stone learned", "ink2")
  end
  if broadcast then
    local lib = SM.Lib()
    if lib and not SM.stoneTold then
      SM.stoneTold = key
      lib:Send("SUMMON", "STONE", pinst, zone, ("%.1f"):format(px), ("%.1f"):format(py))
    elseif lib and SM.stoneTold ~= key then
      SM.stoneTold = key
      lib:Send("SUMMON", "STONE", pinst, zone, ("%.1f"):format(px), ("%.1f"):format(py))
    end
  end
  return st
end

function SM.OnStone(db, sender, map, zone, x, y)
  x, y = tonumber(x), tonumber(y)
  if not x or not y or not db then return end
  db.stones = db.stones or {}
  local key = SM.StoneKey(map, zone)
  if not db.stones[key] then db.stones[key] = { map = map, zone = zone, x = x, y = y } end
end

-- The other way a stone gets learned, no hover anywhere: a peer says OK and
-- lands ON the stone. Ask once, and the WHERE that comes back is the stone.
function SM.LearnFromLanding(db, name)
  local lib = SM.Lib()
  if not lib then return end
  SM.landing = SM.landing or {}
  SM.landing[name] = GetTime()
  C_Timer.After(4, function() lib:Ask() end)   -- the teleport takes a beat
end

function SM.OnLandingWhere(db, name, where)
  local at = SM.landing and SM.landing[name]
  if not at then return end
  if (GetTime() - at) > 30 then SM.landing[name] = nil return end
  if not where or where.inInstance or not where.x or not where.y then return end
  if (where.at or 0) <= at then return end          -- a stale position from before the trip
  SM.landing[name] = nil
  db.stones = db.stones or {}
  local key = SM.StoneKey(where.mapId, where.zone)
  local st = db.stones[key]
  if st then st.x, st.y = (st.x * 3 + where.x) / 4, (st.y * 3 + where.y) / 4
  else db.stones[key] = { map = where.mapId, zone = where.zone, x = where.x, y = where.y } end
  return db.stones[key]
end

-- is (map, zone, x, y) within `near` of a stone we know in that zone?
function SM.NearStone(db, map, zone, x, y, near)
  if not db or not db.stones or not x or not y then return false end
  for _, st in pairs(db.stones) do
    if tostring(st.map) == tostring(map) and st.zone == zone then
      if dist(st.x, st.y, x, y) < near then return true end
    end
  end
  return false
end

-- ---------------------------------------------------------------- requests
-- MOD "SUMMON", CMD "REQ", arg 1 = asking, 0 = never mind. Only clients with
-- BiSTools understand it; everyone else ignores an unknown MOD in silence.
SM.requests = {}       -- name -> GetTime() they asked

function SM.Request(db, on)
  local lib = SM.Lib()
  SM.myRequest = on and true or false
  SM.PaintRequest()
  if lib then
    lib:Send("SUMMON", "REQ", on and 1 or 0)
    if on then lib:SendWhere(true) end   -- and where I am, so the row scores right
  end
  SM.Log(on and "requested" or "request off", on and "gold" or "muted")
  SM.PaintSlots()
end

-- a label must fit its box (BiSTheme.Fit; Arn, 8 Sep: "summon requested - click
-- to cancel" ran into the "all" button)
function SM.Fit(fs, text, width) return BiSTheme.Fit(fs, text, width) end

function SM.SetUnrolled(db, on)
  SM.unrolled = on and true or false
  if SM.allBtn then
    SM.allBtn.edge:set(SM.unrolled and "accent" or "edge", 1)
    local r, g, b = K.color(SM.unrolled and "accent" or "muted")
    SM.allBtn.label:SetTextColor(r, g, b, 1)
  end
  SM.Refresh(db)
end

function SM.PaintRequest()
  if not SM.foot then return end
  local r, g, b
  local maxW = (SM.W - SM.ALL_W) - 8
  if SM.myRequest then
    SM.Fit(SM.foot.label, "requested - cancel", maxW)
    r, g, b = K.color("gold")
  else
    SM.Fit(SM.foot.label, "request a summon", maxW)
    r, g, b = K.color("accent")
  end
  SM.foot.label:SetTextColor(r, g, b, 1)
end

function SM.OnRequest(sender, flag)
  if flag == "1" then
    local fresh = SM.requests[sender] == nil
    SM.requests[sender] = GetTime()
    if fresh and SM.On() then                      -- the tool off: the request is kept, nothing is said
      SM.Log(sender .. " asks", "gold")
      local db0 = SM.db
      if db0 and db0.summoner then
        -- the summoner: this is his job tonight, it should reach him mid-fight
        NS.Alert(sender .. " asks for a summon")
        if PlaySound then PlaySound(8959, "Master") end
        if K and K.Speak then K.Speak("Summon") end
      elseif PlaySound then
        PlaySound(3081, "Master")
      end
    end
  else
    SM.requests[sender] = nil
  end
  local db = NS.DB and NS.DB() and NS.DB().tools and NS.DB().tools.summon
  if db and flag == "1" and (db.mode or "auto") == "auto" and SM.On() then
    -- somebody asked: the summoner should see the window even away from a stone
    SM.seenAt = GetTime()
    SM.ApplyVisible(true)
  end
  if db and SM.frame and SM.shown then SM.Refresh(db) end
end

function SM.Asked(name, now)
  local at = SM.requests[name]
  if not at then return false end
  if (now - at) > SM.REQ_TTL then SM.requests[name] = nil return false end
  return true
end

-- ---------------------------------------------------------------- freshness
-- The lib pushes WHERE on a zone change only. Walking 30 yards off the stone
-- is not a zone change, so a summoner would keep seeing "at stone". Two fixes,
-- both inside the no-chatter rule:
--   peer side: every 3 s, if "am I at a known stone" flipped, push a WHERE
--   summoner side: while the window is up, re-ask when a fact is older than
--                  SM.STALE (the lib jitters and coalesces the answers)
SM.STALE = 30
SM.REASK = 15
SM.POP_AT = 2        -- this many at a stone pops the window on every Tools client

-- how many are standing at a known stone right now: facts from their WHERE,
-- me from my own position. Guesses count too when the client can see them.
function SM.StoneCount(db)
  local lib = SM.Lib()
  local near = db.near or SM.DEFAULT_NEAR
  local n = 0
  local py, px, _, pinst = UnitPosition("player")
  local zone = (GetRealZoneText and GetRealZoneText()) or ""
  local meAt = SM.NearStone(db, pinst, zone, px, py, near)
  if meAt then n = n + 1 end
  if lib then
    for _, p in pairs(lib:Peers()) do
      local w = p.where
      if w and not w.inInstance and SM.NearStone(db, w.mapId, w.zone, w.x, w.y, near) then n = n + 1 end
    end
  end
  return n, meAt
end

function SM.SelfWatch(db)
  local lib = SM.Lib()
  if not lib or not lib:Enabled() then return end
  local n, at = SM.StoneCount(db)
  at = at and true or false
  if SM.selfAtStone == nil then SM.selfAtStone = at
  elseif at ~= SM.selfAtStone then
    SM.selfAtStone = at
    lib:SendWhere(true)
  end
  -- Arn (8 Sep): two at the stone = the window opens for everyone, so the far
  -- ones can press "request a summon" without typing a thing
  -- (the window only with the tool on: switched off, it never comes up by itself - the WHERE above still goes out,
  -- it is the shared channel's voice, not the tool's)
  if n >= SM.POP_AT and (db.mode or "auto") == "auto" and SM.frame and SM.On() then
    if not SM.shown then SM.Refresh(db) end
    SM.seenAt = GetTime()
    SM.ApplyVisible(true)
    if not SM.popped then
      SM.popped = true
      SM.Log("request now", "good")
    end
  elseif SM.popped then
    SM.popped = false
    if SM.shown and (db.mode or "auto") == "auto" then
      SM.Log("no summons", "muted")
      -- let the linger run out in ~5 s instead of the full 8
      SM.seenAt = GetTime() - (db.linger or SM.DEFAULT_LINGER) + 5
    end
  end
end

function SM.Reask(db)
  local lib = SM.Lib()
  if not lib or not SM.shown then return end
  local now = GetTime()
  if (now - (SM.lastReask or 0)) < SM.REASK then return end
  local stale = false
  for _, p in pairs(lib:Peers()) do
    if p.where and (now - (p.where.at or 0)) > SM.STALE then stale = true break end
    if not p.where then stale = true break end
  end
  if stale then SM.lastReask = now lib:Ask() end
end

-- ---------------------------------------------------------------- the key
-- Arn's idea (8 Sep): stand at the stone, mouse on the window, spam Interact
-- With Target. While the target is NOT the top name, the key is overridden to
-- a hidden secure button that targets the top name (no park). The moment the
-- target IS the top name the override is dropped, so the next press is the
-- real interact - which next to a stone uses the stone. Then the top changes
-- (his offer lands, or you park him) and the override comes back.
function SM.KeyButton()
  if SM.keyBtn then return SM.keyBtn end
  local b = CreateFrame("Button", "BiSToolsSummonKey", UIParent, "SecureActionButtonTemplate")
  b:RegisterForClicks("AnyDown")
  b:SetAttribute("*type1", "target")
  b:SetScript("PostClick", function(self)
    SM.keyTargeted = self:GetAttribute("*unit1")
  end)
  SM.keyBtn = b
  return b
end

function SM.ArmKey(db)
  if InCombatLockdown() then return end
  local b = SM.KeyButton()
  local key = GetBindingKey and GetBindingKey("INTERACTTARGET")
  local top = SM.list and SM.list[1]
  local want = false
  if key and db.key ~= false and SM.frame and SM.shown and SM.frame:IsMouseOver()
     and top and top.unit and not top.inside and not top.here
     and not (UnitExists("target") and UnitIsUnit("target", top.unit)) then
    want = true
  end
  if want then
    if b:GetAttribute("*unit1") ~= top.unit then b:SetAttribute("*unit1", top.unit) end
    if SM.keyArmed ~= key then
      ClearOverrideBindings(b)
      SetOverrideBindingClick(b, true, key, "BiSToolsSummonKey")
      SM.keyArmed = key
    end
  elseif SM.keyArmed then
    ClearOverrideBindings(b)
    SM.keyArmed = nil
  end
end

-- ---------------------------------------------------------------- console
-- Arn (8 Sep): "prompt `BiS> _` blinking should be in the header and cycle
-- relevant messages: addon name, summoners at the stone, receiving summon,
-- requesting summon". The title FontString is a BiSTheme.Console: standing
-- slots rotate, SM.Log says an event over them, chat stays clean.
function SM.Log(text, colour)
  if SM.con then SM.con:Say(text, colour) else NS.Print("%s", text) end
end

-- the standing slots, in rotation order: name, at stone, asking, mine, incoming
function SM.PaintSlots()
  local c = SM.con
  if not c then return end
  local n = SM.stoneCount or 0
  c:Set("stone", n > 0 and (SM.TITLE_ICON .. n .. " at stone") or nil, "good")
  -- "N asking" is the summoner's slot: at the stone or in summoner mode. A random
  -- raid member far away does not need it (Arn, 8 Sep).
  local db = SM.db
  local asks, now = 0, GetTime()
  local summoner = db and (db.summoner or SM.MeAtStone(db))
  if summoner then
    for name in pairs(SM.requests) do if SM.Asked(name, now) then asks = asks + 1 end end
  end
  c:Set("asks", asks > 0 and (asks .. " asking") or nil, "gold")
  c:Set("mine", SM.myRequest and "requesting..." or nil, "gold")
  c:Set("offer", SM.nag.active and "summon incoming" or nil, "good")
end

function SM.PaintConsole()
  if SM.con then SM.con:Paint() end
end

-- one place computes the frame height: header + body + console + footer
function SM.Relayout()
  if not SM.frame then return end
  SM.frame:SetHeight(K.HEADER + (SM.bodyH or 1) + SM.FOOT_H)
end

-- ---------------------------------------------------------------- window
function SM.Build(db)
  if SM.frame then return SM.frame end
  local f = CreateFrame("Frame", "BiSToolsSummon", UIParent)
  SM.frame = f
  f:SetSize(SM.W, K.HEADER)
  f:SetFrameStrata("MEDIUM")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint(1)
    db.pos = { point or "CENTER", x or 0, y or 0, rel or point or "CENTER" }
    SM.seenAt = GetTime()
  end)
  K.tex(f, "BACKGROUND", "frame", K.BODY_A)
  K.border(f, "edge", 0.35)

  local head = CreateFrame("Frame", nil, f)
  head:SetPoint("TOPLEFT") head:SetPoint("TOPRIGHT")
  head:SetHeight(K.HEADER)
  K.tex(head, "BACKGROUND", "header", K.HEAD_A)
  local hair = head:CreateTexture(nil, "BORDER")
  hair:SetPoint("BOTTOMLEFT") hair:SetPoint("BOTTOMRIGHT") hair:SetHeight(1)
  do local r, g, b = K.color("edge") hair:SetColorTexture(r, g, b, 1) end
  -- the title is the prompt: "BiS> Summon_", cycling the state slots
  SM.title = K.fs(head, "", 8, "ink")
  SM.title:SetPoint("LEFT", head, "LEFT", 4, 0)
  -- header budget, left to right: 4 + prompt (<= W-56-8 = 106 px: "BiS> " + ~16
  -- characters + cursor) ... buttons from the right: x(12)@-3, ?(12)@-17,
  -- J(18)@-38 -> J's left edge sits 56 px from the right. Nothing else goes in
  -- the header. (No logo: the prompt is the brand. No pin button: Arn, 8 Sep -
  -- "confusing"; auto-open on summons covers it, /bist summon show|auto|hide is
  -- the manual way.)
  SM.con = BiSTheme.Console(SM.title, { width = SM.W - 56 - 8 })
  SM.con:Set("name", "Summon", "accent")
  SM.closeBtn = K.HeaderButton(head, -3, "x", "Close", "Auto mode brings it back on a summoning stone.",
    function() SM.SetMode(db, "auto") SM.ApplyVisible(false) end, "warn")
  SM.askBtn = K.HeaderButton(head, -17, "?", "Ask the raid", "Every BiS client answers with where it stands.",
    function() SM.Ask() end)
  SM.summonerBtn = K.HeaderButton(head, -38, "S", "Summoner mode - I am the summoner",
    "Window stays up and every request comes through like a raid warning, wherever you stand. /bist summon summoner",
    function() SM.SetSummoner(db, not db.summoner) end)
  SM.summonerBtn:SetSize(18, 12)
  head:SetScript("OnEnter", function() SM.seenAt = GetTime() end)
  -- the header is the drag handle: plain drag, no shift needed (rows need shift
  -- because a plain click on a row is the target action)
  head:EnableMouse(true)
  head:RegisterForDrag("LeftButton")
  head:SetScript("OnDragStart", function() if not InCombatLockdown() then f:StartMoving() end end)
  head:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local point, _, rel, x, y = f:GetPoint(1)
    db.pos = { point or "CENTER", x or 0, y or 0, rel or point or "CENTER" }
    SM.seenAt = GetTime()
  end)

  local body = CreateFrame("Frame", nil, f)
  body:SetPoint("TOPLEFT", head, "BOTTOMLEFT")
  body:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT")
  body:SetHeight(1)
  SM.body = body
  SM.empty = K.fs(body, "nobody needs a summon", 9, "muted")
  SM.empty:SetPoint("TOPLEFT", 6, -4)
  -- status line under the rows: "1 in" (the at-stone count lives in the title)
  SM.count = K.fs(body, "", 8, "muted")
  SM.count:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -6, 2)

  -- footer: the peer's one button. "request a summon" puts you on top of every
  -- summoner's list with "asks"; click again to take it back.
  -- footer budget, 170 wide: request 0..126 | all 126..170
  local foot = CreateFrame("Button", "BiSToolsSummonRequest", f)
  foot:SetPoint("BOTTOMLEFT")
  foot:SetSize(SM.W - SM.ALL_W, SM.FOOT_H)
  K.tex(foot, "BACKGROUND", "field", 0.9)
  foot.edge = K.border(foot, "edge", 1)
  foot.label = K.fs(foot, "request a summon", 9, "accent")
  foot.label:SetPoint("CENTER")
  foot:SetScript("OnClick", function() SM.Request(db, not SM.myRequest) end)
  foot:SetScript("OnEnter", function(self)
    SM.seenAt = GetTime()
    self.edge:set("accent", 1)
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine("Request a summon")
      GameTooltip:AddLine("Every summoner running BiSTools sees you on top of the list. Click again to cancel. Clears itself when an offer lands.", 1, 1, 1, true)
      GameTooltip:Show()
    end
  end)
  foot:SetScript("OnLeave", function(self) self.edge:set("edge", 1) if GameTooltip then GameTooltip:Hide() end end)
  SM.foot = foot
  SM.PaintRequest()
  -- "all": unroll the whole raid, inside and here included (Arn: in the raid,
  -- one button to see everyone regardless of where they are)
  local all = CreateFrame("Button", "BiSToolsSummonAll", f)
  all:SetPoint("BOTTOMRIGHT")
  all:SetSize(SM.ALL_W, SM.FOOT_H)
  K.tex(all, "BACKGROUND", "field", 0.9)
  all.edge = K.border(all, "edge", 1)
  all.label = K.fs(all, "all", 9, "muted")
  all.label:SetPoint("CENTER")
  all:SetScript("OnClick", function() SM.SetUnrolled(db, not SM.unrolled) end)
  all:SetScript("OnEnter", function(self)
    SM.seenAt = GetTime()
    self.edge:set("accent", 1)
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine("Everyone")
      GameTooltip:AddLine("Show the whole raid, inside and here included.", 1, 1, 1, true)
      GameTooltip:Show()
    end
  end)
  all:SetScript("OnLeave", function(self) self.edge:set(SM.unrolled and "accent" or "edge", 1) if GameTooltip then GameTooltip:Hide() end end)
  SM.allBtn = all

  local pos = db.pos
  f:SetPoint(pos[1], UIParent, pos[4] or pos[1], pos[2], pos[3])
  f:Hide()
  SM.shown = false
  SM.PaintPin(db)
  return f
end

--- ONE TIME, AT LOGIN: the old key's value into the new one, then the old key goes.
---
--- The mode was named after a person until 19 Sep 2026 - the repo went public and a guildmate's
--- name went with it. Renaming the setting means anyone who had it switched on would silently
--- lose it, so the value is carried: read `summoner`, write `summoner`, drop `summoner`. Runs once
--- because after it runs there is no `summoner` left to read.
function SM.Migrate(db)
  if type(db) ~= "table" then return false end
  if db.summoner == nil then return false end
  if db.summoner == nil then db.summoner = db.summoner and true or false end
  db.summoner = nil
  return true
end

function SM.SetSummoner(db, on)
  db.summoner = on and true or false
  SM.PaintPin(db)
  if on then SM.SetMode(db, "on") end
  NS.Print("summoner mode %s%s", db.summoner and T.text("gold", "on") or T.text("muted", "off"),
    db.summoner and " - you are the summoner; requests come through loud" or "")
end

function SM.PaintPin(db)
  if SM.summonerBtn then
    SM.summonerBtn.edge:set(db.summoner and "gold" or "edge", 1)
    local jr, jg, jb = K.color(db.summoner and "gold" or "muted")
    SM.summonerBtn.label:SetTextColor(jr, jg, jb, 1)
  end
end

-- a secure row: left-click targets, right-click parks, shift-drag moves
function SM.Row(i, db)
  local r = SM.rows[i]
  if r then return r end
  r = CreateFrame("Button", "BiSToolsSummonRow" .. i, SM.body, "SecureActionButtonTemplate")
  r:SetHeight(SM.ROW_H)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * SM.ROW_H)
  r:SetPoint("TOPRIGHT", 0, -(i - 1) * SM.ROW_H)
  r:RegisterForClicks("AnyDown")
  r:RegisterForDrag("LeftButton")
  r:SetAttribute("*type1", "target")
  -- shift is the drag handle; the modifier form is checked before "*", and an
  -- empty type resolves to no handler. Never a type2: right-click then does
  -- nothing secure and only our PostClick runs. That is the park.
  for _, prefix in ipairs({ "shift-", "ctrl-shift-", "alt-shift-", "alt-ctrl-shift-" }) do
    r:SetAttribute(prefix .. "type1", "")
  end
  r.bg = K.tex(r, "BACKGROUND", "surface", 0)
  r.name = K.fs(r, "", 9, "ink")
  r.name:SetPoint("LEFT", 6, 0)
  r.info = K.fs(r, "", 8, "ink2")
  r.info:SetPoint("RIGHT", -6, 0)
  -- Tried and buried (8 Sep): RunBinding("INTERACTTARGET") from PostClick ->
  -- ADDON_ACTION_FORBIDDEN. Interact With Target is hardware-only, like a cast.
  -- The click targets; the interact key stays the player's.
  r:SetScript("PostClick", function(self)
    if IsShiftKeyDown() then return end
    if self.pname then SM.Park(db, self.pname) end
  end)
  r:SetScript("OnDragStart", function()
    if not IsShiftKeyDown() or InCombatLockdown() then return end
    SM.frame:StartMoving()
  end)
  r:SetScript("OnDragStop", function()
    SM.frame:StopMovingOrSizing()
    local point, _, rel, x, y = SM.frame:GetPoint(1)
    db.pos = { point or "CENTER", x or 0, y or 0, rel or point or "CENTER" }
  end)
  r:SetScript("OnEnter", function(self)
    SM.seenAt = GetTime()
    local rr, g, b = K.color("sunken") self.bg:SetColorTexture(rr, g, b, 1)
    if GameTooltip and self.pname then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.pname)
      GameTooltip:AddLine(self.fact and "says so itself (BiS addon)" or "guessed from the roster - no BiS addon", 1, 1, 1, true)
      GameTooltip:AddLine("click: target   right-click: skip   shift-drag: move", 0.6, 0.6, 0.6, true)
      GameTooltip:Show()
    end
  end)
  r:SetScript("OnLeave", function(self)
    local rr, g, b = K.color("surface") self.bg:SetColorTexture(rr, g, b, 0)
    if GameTooltip then GameTooltip:Hide() end
  end)
  r:Hide()
  SM.rows[i] = r
  return r
end

function SM.PaintRows(db, list)
  local want = math.min(db.rows or SM.DEFAULT_ROWS, SM.MAX_ROWS)
  local atStone = SM.MeAtStone(db)
  -- far from the stone you are not summoning anyone: header, count, the
  -- request button. The list only unrolls on "all".
  local compact = (not atStone) and (not SM.unrolled)
  if compact then want = 0 end
  if InCombatLockdown() then SM.pending.rows = true return end
  SM.pending.rows = nil
  local shown = 0
  for i = 1, math.max(want, #SM.rows) do
    local r = SM.Row(i, db)
    local e = list[i]
    if i <= want and e then
      r.pname, r.fact = e.name, e.fact
      r:SetAttribute("unit", e.unit)
      r:SetAttribute("*unit1", e.unit)
      -- fact: plain name. guess: muted, with the question mark it deserves.
      r.name:SetText(e.fact and e.name or (e.name .. " ?"))
      local colour
      if e.inside or e.here then colour = "dim"
      elseif e.waiting then colour = "dim"
      elseif i == 1 then colour = "accent"
      elseif not e.fact then colour = "muted"
      elseif e.score >= SM.SCORE_OTHER_WORLD then colour = "warn"
      elseif e.score >= SM.SCORE_OTHER_ZONE then colour = "gold"
      else colour = "gold" end
      local cr, cg, cb = K.color(colour)
      r.name:SetTextColor(cr, cg, cb, 1)
      r.info:SetText(SM.InfoText(e, atStone))
      cr, cg, cb = K.color((e.waiting or e.inside or e.here) and "muted" or (e.asked and "gold") or "ink2")
      r.info:SetTextColor(cr, cg, cb, 1)
      r:Show()
      shown = shown + 1
    else
      r.pname = nil
      r:SetAttribute("unit", nil)
      r:SetAttribute("*unit1", nil)
      r:Hide()
    end
  end
  local h
  if shown == 0 and compact then
    -- compact: the header prompt already says "N at stone" (Arn, 8 Sep: "those
    -- messages should go on the header"); the body is a bare strip
    SM.empty:Hide()
    h = 4
  elseif shown == 0 then
    SM.empty:SetText("nobody needs a summon")
    SM.empty:Show()
    h = SM.ROW_H + 4
  else
    SM.empty:Hide()
    h = shown * SM.ROW_H + 4
  end
  local status = SM.count:GetText()
  if status and status ~= "" then h = h + SM.STATUS_H end
  SM.body:SetHeight(h)
  SM.bodyH = h
  SM.Relayout()
end

-- the at-stone slot, Innervate-style: green triangle + "2 at stone" while anyone
-- (me included) stands at a stone; the prompt cycles it with the addon name
SM.TITLE_ICON = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:11:11:0:0|t"
function SM.PaintTitle(n)
  SM.stoneCount = n
  SM.PaintSlots()
end

function SM.Refresh(db)
  if not SM.frame then return end
  local now = GetTime()
  local entries, me = SM.Gather()
  local list, inside, atStone = SM.Rank(entries, me, {
    near = db.near, ban = db.ban, allow = db.allow, tried = SM.tried, now = now, all = SM.unrolled,
  })
  SM.list, SM.inside, SM.atStone = list, inside, atStone
  local live = {}
  for _, e in ipairs(list) do live[e.name] = true end
  for name, until_ in pairs(SM.tried) do
    if not live[name] or until_ <= now then SM.tried[name] = nil end
  end
  SM.stoneCount = (SM.StoneCount(db))
  SM.PaintTitle(SM.stoneCount)
  local bits = {}
  if not SM.MeAtStone(db) and not SM.unrolled then
    -- compact: the header prompt carries the at-stone count, no status line
  else
    if inside > 0 then bits[#bits + 1] = inside .. " in" end
  end
  SM.count:SetText(#bits > 0 and table.concat(bits, " - ") or "")
  SM.PaintRows(db, list)
end

function SM.ApplyVisible(v)
  if not SM.frame then return end
  if v == SM.shown then return end
  if InCombatLockdown() then SM.pending.visible = v return end
  SM.pending.visible = nil
  SM.shown = v
  if v then SM.frame:Show() else SM.frame:Hide() end
end

function SM.SetMode(db, mode)
  db.mode = mode
  SM.PaintPin(db)
  if mode == "on" then SM.ApplyVisible(true) SM.Refresh(db) SM.Ask()
  elseif mode == "off" then SM.seenAt = nil SM.ApplyVisible(false)
  else SM.seenAt = nil SM.ApplyVisible(false) end
end

-- ask the raid where everyone is. Only when the window comes up, never on a
-- ticker: answers are jittered and coalesced in the lib, standing still is free.
function SM.Ask()
  local lib = SM.Lib()
  if lib and lib.Ask then lib:Ask() end
end

-- ---------------------------------------------------------------- stone watcher
function SM.LookingAtStone(db)
  if not GameTooltip or not GameTooltip:IsShown() then return false end
  if UnitExists("mouseover") then return false end
  -- the owner can be a frame the client locks away from addons: even the LOOKUP of its GetParent is refused, so
  -- the whole question goes in the pcall; one that will not say is not our window
  local okO, ours = pcall(function()
    local owner = GameTooltip.GetOwner and GameTooltip:GetOwner()
    return owner and SM.frame and (owner == SM.frame or (owner.GetParent and owner:GetParent() == SM.body)) or false
  end)
  if okO and ours then return false end
  local line = _G["GameTooltipTextLeft1"]
  local okT, text = pcall(function() return line and line:GetText() end)
  return SM.IsStoneText(okT and text or nil, db.stone)
end

function SM.Watch(db, dt)
  SM.elapsed = (SM.elapsed or 0) + dt
  if SM.elapsed < 0.1 then return end
  SM.elapsed = 0
  local mode = db.mode or "auto"
  if mode ~= "auto" and SM.LookingAtStone(db) then SM.LearnStone(db, true) SM.stoneSeen = GetTime() end
  if mode == "auto" then
    local stone = SM.LookingAtStone(db)
    if stone or (SM.frame and SM.frame:IsMouseOver()) then
      if stone then SM.LearnStone(db, true) SM.stoneSeen = GetTime() end
      if not SM.seenAt then SM.Refresh(db) SM.Ask() end
      SM.seenAt = GetTime()
    end
  end
  local want = SM.ShouldShow(mode, SM.seenAt, GetTime(), db.linger)
  if not want then SM.seenAt = nil end
  SM.ApplyVisible(want)
  SM.ArmKey(db)
  if SM.shown then SM.PaintConsole() end   -- rotates the slots, blinks the cursor
end

-- ---------------------------------------------------------------- the nag
-- Fires on the person BEING summoned. Since 1.0 it ANSWERS TO THE TOOL'S SWITCH (it used to outlive /bist off
-- summon, "the reward for installing and touching nothing" - and a new install now touches nothing and must hear
-- nothing: Arn's cousin, "what's making that noise"). Two switches: the summon tool, and /bist summon nag on|off.
SM.nag = {}
function SM.NagText()
  local lib = SM.Lib()
  local s = lib and lib.summon
  -- 2.5.6.69795 has these only at C_SummonInfo.* (BiSProbe, 16 Sep); the globals are the fallback
  local getWho = (C_SummonInfo and C_SummonInfo.GetSummonConfirmSummoner) or GetSummonConfirmSummoner
  local getArea = (C_SummonInfo and C_SummonInfo.GetSummonConfirmAreaName) or GetSummonConfirmAreaName
  local who = s and s.summoner ~= "" and s.summoner or (getWho and getWho()) or "someone"
  local area = s and s.area ~= "" and s.area or (getArea and getArea()) or ""
  return ("SUMMON from %s%s"):format(who, area ~= "" and (" to " .. area) or "")
end

function SM.NagOnce()
  local text = SM.NagText()
  NS.Alert(text)                                             -- our own line where the raid warning sits
  if PlaySound then PlaySound(8959, "Master") end          -- RAID_WARNING
  if K and K.Speak then K.Speak("Summon") end                -- FojjiCore pack / TTS / ping
end

function SM.NagStart(db)
  if db and db.nag == false then return end
  if not SM.On() then return end                             -- the summon tool is off: silent
  SM.nag.active = true
  SM.PaintSlots()
  SM.NagOnce()
  local lib = SM.Lib()
  local left = (lib and lib.summon and lib.summon.left) or SM.DEFAULT_RETRY
  local ends = GetTime() + left
  if SM.nag.ticker then SM.nag.ticker:Cancel() end
  SM.nag.ticker = C_Timer.NewTicker(SM.NAG_EVERY, function()
    local l = SM.Lib()
    local still = l and l.summon and l.summon.state == "OFFER"
    if not SM.nag.active or not still or GetTime() > ends or not SM.On() then return SM.NagStop() end
    SM.NagOnce()
  end)
end

function SM.NagStop()
  SM.nag.active = false
  SM.PaintSlots()
  if SM.nag.ticker then SM.nag.ticker:Cancel() SM.nag.ticker = nil end
end

-- peer-side freshness runs from load too, like the nag: it is part of the
-- client's voice, and /bist off summon only kills the window
SM.selfTicker = C_Timer.NewTicker(3, function()
  local db = NS.DB and NS.DB() and NS.DB().tools and NS.DB().tools.summon
  if db then SM.SelfWatch(db) end
end)

-- registered at load, on purpose: the nag outlives /bist off summon
SM.nagFrame = CreateFrame("Frame")
SM.nagFrame:RegisterEvent("CONFIRM_SUMMON")
SM.nagFrame:RegisterEvent("CANCEL_SUMMON")
SM.nagFrame:SetScript("OnEvent", function(_, ev)
  local db = NS.DB and NS.DB() and NS.DB().tools and NS.DB().tools.summon
  if ev == "CONFIRM_SUMMON" then
    -- the 2.5.x client fires this on bystanders too, with no summoner / area /
    -- clock (Arn, 10 Sep: "randomly if any other person gets a summon it says
    -- SUMMON by someone"). Not my summon: no nag, my request stands.
    local lib = SM.Lib()
    if lib and lib.HasPendingSummon and not lib:HasPendingSummon() then return end
    -- an offer landed: my request is answered
    if SM.myRequest then SM.Request(db, false) end
    -- the lib's own CONFIRM_SUMMON handler runs too; order between frames is
    -- not promised, so give it a beat before reading lib.summon
    C_Timer.After(0.2, function() SM.NagStart(db) end)
  else
    SM.NagStop()
  end
end)
-- the accept popup calls C_SummonInfo.ConfirmSummon on 2.5.6.69795; the global on older clients
if hooksecurefunc and C_SummonInfo and C_SummonInfo.ConfirmSummon then
  hooksecurefunc(C_SummonInfo, "ConfirmSummon", function() SM.NagStop() end)
elseif hooksecurefunc and type(_G.ConfirmSummon) == "function" then
  hooksecurefunc("ConfirmSummon", function() SM.NagStop() end)
end

-- ---------------------------------------------------------------- events
function SM.OnEvent(db, event)
  if event == "PLAYER_REGEN_ENABLED" then
    if SM.pending.visible ~= nil then SM.ApplyVisible(SM.pending.visible) end
    SM.Refresh(db)
  else
    SM.Refresh(db)
  end
end

function SM.Hook(db)
  SM.db = db
  SM.Build(db)
  SM.events:RegisterEvent("GROUP_ROSTER_UPDATE")
  SM.events:RegisterEvent("PLAYER_REGEN_ENABLED")
  if not SM.ticker then SM.ticker = C_Timer.NewTicker(2, function() if SM.shown then SM.Refresh(db) SM.Reask(db) end end) end
  SM.events:SetScript("OnUpdate", function(_, dt) SM.Watch(db, dt) end)
  local lib = SM.Lib()
  if lib and not SM.hooked then
    SM.hooked = true
    -- a peer's word lands: repaint now, not on the next 2s tick. NO pops the
    -- name straight back up, which is the bug that started all this.
    local function bump(name)
      if name then SM.tried[name] = nil end
      if SM.frame and SM.shown then SM.Refresh(db) end
    end
    lib:RegisterCallback("SUM", function(name, sum)
      bump(name) SM.requests[name] = nil
      if sum and sum.state == "OK" then SM.Log(name .. " accepted", "good") SM.LearnFromLanding(db, name)
      elseif sum and sum.state == "OFFER" then SM.Log(name .. " offered", "ink2")
      elseif not sum then SM.Log(name .. " declined", "warn") end
    end)
    lib:RegisterCallback("WHERE", function(name, where) SM.OnLandingWhere(db, name, where) end)
    lib:RegisterHandler("SUMMON", "REQ", function(sender, flag) SM.OnRequest(sender, flag) end)
    lib:RegisterHandler("SUMMON", "STONE", function(sender, map, zone, x, y) SM.OnStone(db, sender, map, zone, x, y) end)
    lib:RegisterCallback("WHERE", function() bump() end)
    lib:RegisterCallback("PEER", function() bump() end)
  end
  SM.Refresh(db)
  SM.ApplyVisible(db.mode == "on" or db.summoner)
end

function SM.Unhook()
  if SM.keyBtn and not InCombatLockdown() then ClearOverrideBindings(SM.keyBtn) SM.keyArmed = nil end
  SM.events:UnregisterAllEvents()
  SM.events:SetScript("OnUpdate", nil)
  if SM.ticker then SM.ticker:Cancel() SM.ticker = nil end
  SM.seenAt = nil
  if SM.frame and not InCombatLockdown() then SM.frame:Hide() SM.shown = false end
  SM.NagStop()                                     -- switched off mid-nag: quiet now
end

-- ---------------------------------------------------------------- slash
function SM.Slash(db, args)
  local raw = args:match("^%s*(.-)%s*$")
  local cmd, rest = raw:match("^(%S*)%s*(.-)$")
  cmd = cmd:lower()
  local lib = SM.Lib()
  if cmd == "" then
    if db.mode == "on" then SM.SetMode(db, "auto") NS.Print("summon: auto (stone mouseover)")
    else SM.SetMode(db, "on") NS.Print("summon: pinned") end
  elseif cmd == "show" or cmd == "on" then SM.SetMode(db, "on") NS.Print("summon: pinned")
  elseif cmd == "auto" then SM.SetMode(db, "auto") NS.Print("summon: auto (stone mouseover)")
  elseif cmd == "hide" then SM.SetMode(db, "off") NS.Print("summon: hidden")
  elseif cmd == "ask" then SM.Ask() NS.Print("asked the raid")
  elseif cmd == "me" then SM.Request(db, not SM.myRequest)
  elseif cmd == "key" then
    if rest:lower() == "on" then db.key = true elseif rest:lower() == "off" then db.key = false else db.key = not (db.key ~= false) end
    NS.Print("interact key over the window: %s (mouse on the window, press Interact With Target: targets the top name, press again: the stone)",
      db.key ~= false and T.text("good", "on") or T.text("warn", "off"))
  elseif cmd == "all" then SM.SetUnrolled(db, not SM.unrolled) NS.Print("summon list: %s", SM.unrolled and "everyone" or "who needs it")
  elseif cmd == "summoner" then
    if rest:lower() == "on" then SM.SetSummoner(db, true) elseif rest:lower() == "off" then SM.SetSummoner(db, false) else SM.SetSummoner(db, not db.summoner) end
  elseif cmd == "stones" then
    local n = 0
    for _, st in pairs(db.stones or {}) do n = n + 1 DEFAULT_CHAT_FRAME:AddMessage(("  %s  %.0f, %.0f"):format(T.text("accent", st.zone), st.x, st.y)) end
    NS.Print("%d stone(s) known", n)
  elseif cmd == "near" then db.near = tonumber(rest) or db.near SM.Refresh(db) NS.Print("near: %s y", T.text("accent", db.near or SM.DEFAULT_NEAR))
  elseif cmd == "linger" then db.linger = tonumber(rest) or db.linger NS.Print("linger: %s s", T.text("accent", db.linger or SM.DEFAULT_LINGER))
  elseif cmd == "retry" then db.retry = tonumber(rest) or db.retry NS.Print("guess park: %s s", T.text("accent", db.retry or SM.DEFAULT_RETRY))
  elseif cmd == "rows" then db.rows = math.min(tonumber(rest) or db.rows or SM.DEFAULT_ROWS, SM.MAX_ROWS) SM.Refresh(db) NS.Print("rows: %s", T.text("accent", db.rows))
  elseif cmd == "clear" then SM.Unpark(db) NS.Print("parked names released")
  elseif cmd == "reset" then db.pos = { "CENTER", 0, 0, "CENTER" } if SM.frame then SM.frame:ClearAllPoints() SM.frame:SetPoint("CENTER") end
  elseif cmd == "nag" then
    if rest:lower() == "off" then db.nag = false elseif rest:lower() == "on" then db.nag = true end
    NS.Print("summon nag: %s", db.nag == false and T.text("warn", "off") or T.text("good", "on"))
  elseif cmd == "stone" then
    if rest:lower() == "clear" then db.stone = nil return NS.Print("custom stone name cleared") end
    local line = _G["GameTooltipTextLeft1"]
    local okT, text = pcall(function() return GameTooltip and GameTooltip:IsShown() and line and line:GetText() end)
    text = okT and plain(text) or nil              -- hidden first: a secret line is never learned
    if type(text) == "string" and text ~= "" then db.stone = text NS.Print('stone name: "%s"', text)
    else NS.Print("hover the stone first, then /bist summon stone") end
  elseif cmd == "ban" or cmd == "unban" then
    local zone = rest ~= "" and rest or (GetRealZoneText and GetRealZoneText())
    if zone and zone ~= "" then
      db.ban, db.allow = db.ban or {}, db.allow or {}
      if cmd == "ban" then db.ban[zone:lower()] = zone db.allow[zone:lower()] = nil
      else db.ban[zone:lower()] = nil db.allow[zone:lower()] = zone end
      SM.Refresh(db)
      NS.Print('"%s" %s (guesses only - a BiS client says itself whether it is inside)', zone, cmd == "ban" and "banned" or "allowed")
    end
  elseif cmd == "peers" then
    if not lib then return NS.Print("no comm lib loaded") end
    NS.Print("comm %s, %d peer(s)", lib:Enabled() and T.text("good", "on") or T.text("warn", "off"), lib:Count())
    for name, p in pairs(lib:Peers()) do
      local w = p.where
      DEFAULT_CHAT_FRAME:AddMessage(("  %s  %s  %s"):format(T.text("accent", name),
        w and (w.inInstance and ("in " .. w.instName) or w.zone) or "?",
        p.summon and (p.summon.state) or ""))
    end
  elseif cmd == "testaccept" then
    -- live unknown: does ConfirmSummon() need a hardware event? A timer is the
    -- opposite of one. Run this with an offer pending and see if you land.
    C_Timer.After(1, function()
      local confirm = (C_SummonInfo and C_SummonInfo.ConfirmSummon) or ConfirmSummon
      if confirm then confirm() end
    end)
    NS.Print("calling ConfirmSummon() from a timer in 1 s")
  else
    NS.Print("/bist summon [me|all|key|summoner|stones|show|auto|hide|ask|near <y>|linger <s>|retry <s>|rows <n>|clear|reset|nag on|off|stone [clear]|ban|unban [zone]|peers]")
  end
end

NS.Registry:Register({
  name = "summon",
  slashWhenOff = true,   -- "/bist summon nag off" must work with the window tool off
  desc = "who still needs a summon, furthest first; click to target",
  usage = "/bist summon [show|auto|hide|...]",
  defaults = { mode = "auto", near = SM.DEFAULT_NEAR, linger = SM.DEFAULT_LINGER, retry = SM.DEFAULT_RETRY,
    rows = SM.DEFAULT_ROWS, pos = { "CENTER", 0, -120, "CENTER" }, ban = {}, allow = {}, nag = false, stone = nil,
    summoner = false, stones = {}, key = true },
  -- 1.0: a new install's nag (a warning, a sound and a voice every 20 s) waits to be switched on; an existing save
  -- keeps its own (frozen by Registry R:Forever10)
  quiet = { nag = false },
  OnInit = function(self, db)
    SM.Migrate(db)
    SM.events = CreateFrame("Frame")
    SM.events:SetScript("OnEvent", function(_, ev) SM.OnEvent(db, ev) end)
  end,
  OnLogin = function(self, db) SM.Hook(db) end,
  -- the Hub: pin the window open; recenter drags it to the middle
  IsOpen = function(self, db) return SM.shown and true or false end,
  OnClose = function(self, db) SM.SetMode(db, "auto") end,   -- back to showing itself at a stone
  OnOpen = function(self, db, recenter)
    SM.Build(db)
    if recenter and SM.frame then
      db.pos = { "CENTER", 0, -120, "CENTER" }
      SM.frame:ClearAllPoints() SM.frame:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
      if SM.frame.Raise then SM.frame:Raise() end
    end
    SM.SetMode(db, "on")
  end,
  options = {
    { kind = "seg", label = "window", help = "The summon list: auto - shows when you mouse over a summoning stone, then lingers; on - always shown; off - never.", values = { "auto", "on", "off" },
      get = function(db) return db.mode or "auto" end, set = function(db, v) SM.SetMode(db, v) end },
    { kind = "toggle", label = "nag me when summoned", help = "When a summon is waiting for you, keep reminding you until you accept or it runs out.", get = function(db) return db.nag ~= false end,
      set = function(db, on) db.nag = on and true or false end },
    { kind = "toggle", label = "summoner mode (I summon)", help = "You are the one clicking the stone: the list ranks who still needs a summon, top first.", get = function(db) return db.summoner and true or false end,
      set = function(db, on) SM.SetSummoner(db, on) end },
    { kind = "toggle", label = "interact key over window", help = "With the mouse on the summon list, your Interact With Target key targets the top name; press again for the stone.", get = function(db) return db.key ~= false end,
      set = function(db, on) db.key = on and true or false end },
    { kind = "step", label = "at the stone within", help = "Anyone this close to you counts as already at the stone and leaves the list.", min = 20, max = 200, step = 10,
      get = function(db) return db.near or SM.DEFAULT_NEAR end, set = function(db, v) db.near = v SM.Refresh(db) end,
      show = function(db) return (db.near or SM.DEFAULT_NEAR) .. " yd" end },
    { kind = "step", label = "rows", help = "How many names the summon list shows at once.", min = 1, max = SM.MAX_ROWS, step = 1,
      get = function(db) return db.rows or SM.DEFAULT_ROWS end, set = function(db, v) db.rows = v SM.Refresh(db) end,
      show = function(db) return tostring(db.rows or SM.DEFAULT_ROWS) end },
    { kind = "step", label = "linger after the stone", help = "In auto, how long the list stays after your mouse leaves the stone.", min = 2, max = 30, step = 2,
      get = function(db) return db.linger or SM.DEFAULT_LINGER end, set = function(db, v) db.linger = v end,
      show = function(db) return (db.linger or SM.DEFAULT_LINGER) .. " s" end },
  },
  OnEnable = function(self, db) SM.Hook(db) end,
  OnDisable = function(self, db) SM.Unhook() end,   -- window, key and nag. The shared lib keeps going.
  OnSlash = function(self, db, args) SM.Slash(db, args) end,
})
