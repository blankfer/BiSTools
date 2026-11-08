-- BiSTools / Tools / Pups.lua - THE PUP FINDER (6 Nov 2026), `/bist pups`.
--
-- Arn, 6 Nov: "sending the pups to find friends nearby, itll open a window and send out some dogs to find your nearest
-- pal and report on it. mostly fun fidget spinner to press while traveling" - "the fun part is watching the pup running
-- around a window looking for you friends" - "like a flight tower radar".
--
-- A RADAR SCOPE: you in the middle, north up, two range rings, a sweep going round. Your pals are blips. Three pups
-- (3D, the client's own creatures by npc id - BiS Shell's way) run out from the middle to a blip, sniff, run back and
-- REPORT: the pal joins the list on the right, nearest at the top. Then the next pal, until everyone is found.
--
-- WHERE A PAL IS - three kinds of answer, said apart:
--   * EXACT: a guildmate whose BiS addon shares their spot (LibBiSComm's SPOT, minor 12), or a groupmate on your map
--     (C_Map.GetPlayerMapPosition). Yards and a bearing ("240 YD NE"), a solid blip.
--   * A GUESS: the guild roster and the friends list only say a ZONE. Another zone on your continent: the middle of
--     that zone, "~2.3K W", a faint blip (on the rim when out of range). Your own zone: "IN ZONE", no blip - the pup
--     searches around for it.
--   * FAR: no map answer at all (another continent, an instance): the zone's name, no blip.
-- Distances across zones come from HereBeDragons (embedded, Libs/THIRD-PARTY.txt), its world yards: x grows WEST,
-- y grows NORTH (x = left - width * mapX). Without it, the same map still works by C_Map.GetMapWorldSize.
--
-- WHAT IT COSTS: nothing while closed - no ticker, no OnUpdate; the roster events only mark it stale. Open: one
-- OnUpdate at P.FPS, the sweep's lines and three pups moved; the pals read again every P.REGATHER s.
local _, NS = ...
local R = NS.Registry
local P = {}
NS.Pups = P

P.W, P.H = 343, 240              -- 1.43:1, the family's window shape
P.SCALE = 1.2                    -- every window: "so small cant read"
P.RAD = 100                      -- the scope's radius
P.RIM = 92                       -- a blip beyond the range sits on this ring
P.RANGES = { 100, 250, 500, 1000, 2500, 5000, 10000, 25000 }
P.RING_SEGS = 40
P.TRAIL, P.TRAIL_STEP = 8, 0.07  -- the beam and its fading tail (radians between lines)
P.SWEEP = 2 * math.pi / 3        -- one turn in 3 s
P.FPS = 30
P.MAX_PALS = 12
P.ROWS, P.ROW = 7, 15
P.REGATHER = 5
-- the pups: npc ids from BiS Shell's model list (dev/DEFENSE-MODELS.md, CONFIRMED): Prairie Wolf, Decrepit
-- Darkhound, Prairie Stalker
P.PUPS = { 2958, 1547, 2959 }
P.PUP_SZ, P.DROP = 34, 6         -- a pup's model box, and how far below its feet the box's bottom sits
P.RUN, P.WALK = 70, 22           -- px a second
P.ANIM = { stand = 0, walk = 4, run = 5 }
P.SNIFF = 1.0
P.LEGS = 2                       -- a search (no blip): this many runs about before coming back
P.ICON = "Interface\\Icons\\Ability_Hunter_Pet_Wolf"
P.ROUND = "Interface\\AddOns\\BiSTools\\Media\\Round"
P.GLOW = 0.35
P.SRC = { bis = "accent", group = "good", guild = "ink2", friend = "slate" }
P.SRC_WORD = { bis = "BiS addon - exact spot", group = "your group - exact spot", guild = "guild roster - zone only",
               friend = "friends list - zone only" }
P.DIRS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }

local TAU = 2 * math.pi
local function K() return NS.Farm end
local function rgb(name) return K().color(name) end
local function plain(v)
  if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
  return v
end
local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a = pcall(fn, ...)
  return ok and plain(a) or nil
end
local function fighting() return (InCombatLockdown and InCombatLockdown()) and true or false end

-- ------------------------------------------------------------------ the words (the suite drives these)

--- The name a pal is compared by: the first name, any case (Forever's "Name Surname" is Name to the game).
function P.Key(name)
  name = plain(name)
  if type(name) ~= "string" or name == "" then return nil end
  local first = name:match("^([^%s%-]+)")
  return first and first:lower() or nil
end

--- The name without its realm: "Name Surname-Realm" -> "Name Surname".
function P.Short(name)
  if type(name) ~= "string" then return nil end
  return name:match("^(.-)%-[^%-%s]+$") or name
end

--- A bearing in words, from yards east and north: "NE".
function P.Dir(east, north)
  local deg = math.deg(math.atan2(east, north)) % 360
  return P.DIRS[math.floor((deg + 22.5) / 45) % 8 + 1]
end

--- Yards, short: 240 -> "240", 2300 -> "2.3K".
function P.Yards(yd)
  yd = math.floor(yd + 0.5)
  if yd < 1000 then return tostring(yd) end
  return ("%.1fK"):format(yd / 1000)
end

--- What the list says about where a pal is.
function P.Where(e)
  if e.exact then return P.Yards(e.yd) .. " YD " .. P.Dir(e.east, e.north) end
  if e.guess then return "~" .. P.Yards(e.yd) .. " " .. P.Dir(e.east, e.north) end
  if e.same then return "IN ZONE" end
  if e.zone then return tostring(e.zone):upper() end
  return "SOMEWHERE"
end

function P.HBD() return LibStub and LibStub("HereBeDragons-2.0", true) or nil end

--- Yards east and north from one map spot to another, or nil (another continent, no map data).
function P.Offset(map, x, y, pm, px, py)
  if not (map and x and y and pm and px and py) then return nil end
  local H = P.HBD()
  if H and H.GetZoneDistance then
    local ok, d, dx, dy = pcall(H.GetZoneDistance, H, map, x, y, pm, px, py)
    if ok and type(d) == "number" and type(dx) == "number" and type(dy) == "number" then
      return -dx, dy                                  -- HereBeDragons' x grows west, its y north
    end
  end
  if pm == map and C_Map and C_Map.GetMapWorldSize then
    local ok, w, h = pcall(C_Map.GetMapWorldSize, map)
    if not ok then w, h = nil, nil end
    w, h = plain(w), plain(h)
    if type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
      return (px - x) * w, -(py - y) * h              -- a map's y grows south
    end
  end
  return nil
end

--- A zone's map id by its name (the roster's words), read once from HereBeDragons' map list; the biggest map wins
--- where two share a name.
function P.ZoneMap(name)
  if type(name) ~= "string" then return nil end
  if not P.zones then
    local H = P.HBD()
    if not (H and H.GetAllMapIDs and H.GetLocalizedMap) then return nil end
    local zones, size = {}, {}
    local ok, ids = pcall(H.GetAllMapIDs, H)
    for _, id in ipairs(ok and type(ids) == "table" and ids or {}) do
      local okN, n = pcall(H.GetLocalizedMap, H, id)
      local okS, w = pcall(H.GetZoneSize, H, id)
      w = okS and type(w) == "number" and w or 0
      if okN and type(n) == "string" and w > 0 and w > (size[n] or 0) then zones[n], size[n] = id, w end
    end
    P.zones = zones
  end
  return P.zones[name]
end

--- Where I am: map, x, y (nil inside an instance or with a hidden spot) and my zone's name.
function P.Me()
  local lib = NS.Comm and NS.Comm.Lib and NS.Comm.Lib()
  local map, x, y
  if lib and lib.MySpot then
    local ok, a, b, c = pcall(lib.MySpot, lib)
    if ok then map, x, y = a, b, c end
  end
  return { map = map, x = x, y = y, zone = ask(GetRealZoneText) }
end

local function classFileOf(className)
  for _, t in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
    for k, v in pairs(t) do if v == className then return k end end
  end
end

--- Everyone the pups could look for, online, not me: { key, name, srcs, classFile, map/mx/my or zone }.
--- Exact sources first, so a guildmate who also shares their spot is ONE pal with the spot.
function P.Pals()
  local out, by = {}, {}
  local meKey = P.Key(ask(GetUnitName, "player", false) or ask(UnitName, "player"))
  local function add(name, src, t)
    name = P.Short(plain(name))
    local k = P.Key(name)
    if not k or k == meKey then return end
    local e = by[k]
    if not e then
      e = { key = k, name = name, src = src, srcs = {} }
      by[k], out[#out + 1] = e, e
    end
    e.srcs[src] = true
    if t.classFile and not e.classFile then e.classFile = t.classFile end
    if t.map and t.x and t.y and not e.map then e.map, e.mx, e.my, e.src = t.map, t.x, t.y, src end
    if type(t.zone) == "string" and t.zone ~= "" and not e.zone then e.zone = t.zone end
  end
  -- 1. BiS addons' shared spots (the lib drops the stale ones)
  local lib = NS.Comm and NS.Comm.Lib and NS.Comm.Lib()
  if lib and lib.Spots then
    local ok, spots = pcall(lib.Spots, lib)
    for name, s in pairs(ok and type(spots) == "table" and spots or {}) do
      if type(s) == "table" then add(name, "bis", { map = s.map, x = s.x, y = s.y }) end
    end
  end
  -- 2. your group: a spot on your own map, else the raid roster's zone
  local me = P.here or P.Me()
  local n = ask(GetNumGroupMembers) or 0
  local raid = IsInRaid and IsInRaid() and true or false
  for i = 1, (type(n) == "number" and n or 0) do
    local unit = raid and ("raid" .. i) or (i < n and ("party" .. i) or nil)
    if unit and not (UnitIsUnit and UnitIsUnit(unit, "player")) then
      local name = ask(GetUnitName, unit, false) or ask(UnitName, unit)
      local t = {}
      if me.map and C_Map and C_Map.GetPlayerMapPosition then
        local ok, pos = pcall(C_Map.GetPlayerMapPosition, me.map, unit)
        if ok and type(pos) == "table" and pos.GetXY then
          local okXY, x, y = pcall(pos.GetXY, pos)
          if not okXY then x, y = nil, nil end
          x, y = plain(x), plain(y)
          if type(x) == "number" and type(y) == "number" and not (x == 0 and y == 0) then t.map, t.x, t.y = me.map, x, y end
        end
      end
      if raid and GetRaidRosterInfo then
        local ok, _, _, _, _, _, file, zone = pcall(GetRaidRosterInfo, i)
        if ok then t.zone, t.classFile = plain(zone), plain(file) end
      end
      if name then add(name, "group", t) end
    end
  end
  -- 3. the guild roster: online, a zone
  if IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo then
    local g = ask(GetNumGuildMembers) or 0
    for i = 1, (type(g) == "number" and g or 0) do
      local ok, name, _, _, _, _, zone, _, _, online, _, file = pcall(GetGuildRosterInfo, i)
      if ok and plain(online) then add(name, "guild", { zone = plain(zone), classFile = plain(file) }) end
    end
  end
  -- 4. friends: online, a zone
  local FL = C_FriendList
  if FL and FL.GetNumFriends and FL.GetFriendInfoByIndex then
    local f = ask(FL.GetNumFriends) or 0
    for i = 1, (type(f) == "number" and f or 0) do
      local ok, info = pcall(FL.GetFriendInfoByIndex, i)
      if ok and type(info) == "table" and plain(info.connected) then
        add(info.name, "friend", { zone = plain(info.area), classFile = classFileOf(plain(info.className)) })
      end
    end
  end
  return out
end

--- Where one pal sits from me: exact, a guess, my zone, or far. Fills e.east/north/yd and the sort key.
function P.Place(e, me)
  e.exact, e.guess, e.same, e.east, e.north, e.yd = nil, nil, nil, nil, nil, nil
  if me.map and e.map then
    local east, north = P.Offset(me.map, me.x, me.y, e.map, e.mx, e.my)
    if east then
      e.exact, e.east, e.north = true, east, north
      e.yd = math.sqrt(east * east + north * north)
      e.sortd = e.yd
      return e
    end
  end
  if e.zone and me.zone and e.zone == me.zone then
    e.same = true
    e.sortd = 1500                                    -- somewhere in my zone: after the close exact ones
    return e
  end
  local zid = me.map and P.ZoneMap(e.zone)
  if zid then
    local east, north = P.Offset(me.map, me.x, me.y, zid, 0.5, 0.5)
    if east then
      e.guess, e.east, e.north = true, east, north
      e.yd = math.sqrt(east * east + north * north)
      e.sortd = e.yd + 1500                           -- a zone's middle is a rough answer
      return e
    end
  end
  e.sortd = 1e9
  return e
end

--- The scope's range: the first step past the three nearest exact pals (the guesses when there are none).
function P.Range(list)
  local far, n = 0, 0
  for _, pass in ipairs({ "exact", "guess" }) do
    for _, e in ipairs(list) do
      if e[pass] and n < 3 then far, n = math.max(far, e.yd), n + 1 end
    end
    if n > 0 then break end
  end
  if n == 0 then return 500 end
  for _, r in ipairs(P.RANGES) do if r >= far * 1.15 then return r end end
  return P.RANGES[#P.RANGES]
end

--- A pal's spot on the scope (px right, py up, from the middle), on the rim when out of range; nil when unknown.
function P.ToScope(e, range)
  e.px, e.py, e.rim = nil, nil, nil
  if not (e.east and e.yd) then return nil end
  local r = e.yd / range * P.RAD
  if r > P.RIM then r, e.rim = P.RIM, true end
  if e.yd < 0.01 then e.px, e.py = 0, 0 return e end
  e.px, e.py = e.east / e.yd * r, e.north / e.yd * r
  return e
end

--- Read everyone again. Keeps what the pups already did to each pal (found, reported, taken) unless `fresh`.
function P.Gather(fresh)
  local old = {}
  for _, e in ipairs(P.list or {}) do old[e.key] = e end
  P.here = P.Me()
  local list = P.Pals()
  for _, e in ipairs(list) do
    P.Place(e, P.here)
    local o = old[e.key]
    if o and not fresh then e.found, e.reported, e.taken, e.lit = o.found, o.reported, o.taken, o.lit end
  end
  table.sort(list, function(a, b)
    if a.sortd ~= b.sortd then return a.sortd < b.sortd end
    return a.key < b.key
  end)
  while #list > P.MAX_PALS do table.remove(list) end
  P.range = P.Range(list)
  for _, e in ipairs(list) do P.ToScope(e, P.range) end
  -- a pup on its way keeps chasing the same pal (now the fresh copy of it)
  local byKey = {}
  for _, e in ipairs(list) do byKey[e.key] = e end
  for _, p in ipairs(P.pups or {}) do
    if p.job then
      local e = byKey[p.job.key]
      if e then e.taken = true end
      p.job = e or p.job
    end
  end
  P.list, P.since, P.stale = list, 0, nil
  return list
end

-- ------------------------------------------------------------------ the pups

--- A pup's body: the client's creature, asked again while it has not drawn (a creature the client never fetched draws
--- nothing the first time - BiS Shell's probe); three asks and it stays a paw icon.
function P.Dress(p)
  local m = p.m
  if not m then p.icon:Show() return end
  m:Show()                                            -- shown first: a hidden model may never load
  pcall(m.ClearModel, m)
  pcall(m.SetCreature, m, p.npc)
  if m.SetPortraitZoom then pcall(m.SetPortraitZoom, m, 0) end
  p.anim = nil
  P.Anim(p, p.moving and P.ANIM.run or P.ANIM.stand)
  if P.Drawn(m) then p.drawn, p.ask = true, nil p.icon:Hide() else p.drawn, p.ask = nil, 0.6 end
end

function P.Drawn(m)
  if not (m and m.GetModelFileID) then return false end
  local ok, file = pcall(m.GetModelFileID, m)
  file = ok and plain(file) or nil
  return type(file) == "number" and file > 0
end

function P.Anim(p, a)
  if p.anim == a or not p.m then return end
  p.anim = a
  pcall(p.m.SetAnimation, p.m, a)
end

--- Turn to run along (dx, dy) - right and UP on the scope (BiS Shell's V.Facing, tuned live).
function P.Face(p, dx, dy)
  if not p.m or (dx == 0 and dy == 0) then return end
  pcall(p.m.SetFacing, p.m, math.atan2(dx, -dy))
end

function P.Go(p, tx, ty, speed, state)
  p.tx, p.ty, p.speed, p.state, p.moving = tx, ty, speed, state, true
  P.Face(p, tx - p.x, ty - p.y)
  P.Anim(p, speed >= P.RUN and P.ANIM.run or P.ANIM.walk)
end

function P.Rest(p, wait)
  p.state, p.wait, p.moving = "idle", wait or (1.5 + math.random() * 2.5), nil
  P.Anim(p, P.ANIM.stand)
end

function P.Put(p)
  if p.m and p.drawn then
    p.m:ClearAllPoints()
    p.m:SetPoint("BOTTOM", P.frame.scope, "CENTER", p.x, p.y - P.DROP)
  else
    p.icon:ClearAllPoints()
    p.icon:SetPoint("CENTER", P.frame.scope, "CENTER", p.x, p.y)
  end
end

--- A spot somewhere out on the scope, `from`-`to` px out (toward `angle` when given, a little either side).
local function somewhere(from, to, angle)
  local a = angle and (angle + (math.random() - 0.5) * 0.6) or math.random() * TAU
  local r = from + math.random() * (to - from)
  return math.sin(a) * r, math.cos(a) * r
end

--- The next pal nobody is fetching, nearest first.
function P.NextJob()
  for _, e in ipairs(P.list or {}) do
    if not e.taken and not e.reported then return e end
  end
end

--- Send a pup for a pal (nil: a run about, nobody to find).
function P.Fetch(p, e)
  p.job = e
  if e then e.taken = true end
  if e and e.px then
    P.Go(p, e.px, e.py, P.RUN, "out")
  else
    p.legs = P.LEGS
    local angle = e and e.east and math.atan2(e.east, e.north) or nil
    local x, y = somewhere(45, 85, angle)
    P.Go(p, x, y, P.RUN, "search")
  end
end

--- A pup is back: what it found goes on the list, and it goes for the next one.
function P.Report(p)
  local e = p.job
  p.job = nil
  if e then
    e.reported, e.found, e.lit = true, true, 1
    P.say = ("PUP %d: %s  %s"):format(p.i, (e.name or "?"):upper(), P.Where(e))
  else
    P.say = ("PUP %d: NOBODY OUT THERE"):format(p.i)
  end
  P.Paint()
  local nextOne = P.NextJob()
  if nextOne then P.Fetch(p, nextOne) else P.Rest(p) end
end

--- One pup, one step.
function P.StepPup(p, dt)
  if p.ask then
    p.ask = p.ask - dt
    if p.ask <= 0 then
      if P.Drawn(p.m) then
        p.drawn, p.ask = true, nil
        p.icon:Hide()
        local a = p.anim p.anim = nil P.Anim(p, a or P.ANIM.stand)
      else
        p.tries = (p.tries or 0) + 1
        if p.tries >= 3 then p.ask = nil p.m:Hide() p.icon:Show()
        else P.Dress(p) end
      end
    end
  end
  if p.state == "idle" then
    p.wait = (p.wait or 0) - dt
    if p.wait <= 0 then
      local x, y = somewhere(4, 24)
      P.Go(p, x, y, P.WALK, "wander")
    end
  elseif p.state == "sniff" then
    p.wait = (p.wait or 0) - dt
    if p.wait <= 0 then
      if p.job then p.job.found, p.job.lit = true, 1 end
      local x, y = somewhere(0, 10)
      P.Go(p, x, y, P.RUN, "back")
    end
  elseif p.moving then
    if p.state == "out" and p.job and p.job.px then p.tx, p.ty = p.job.px, p.job.py end   -- a pal on the move
    local dx, dy = p.tx - p.x, p.ty - p.y
    local d = math.sqrt(dx * dx + dy * dy)
    local step = p.speed * dt
    if d <= step then
      p.x, p.y = p.tx, p.ty
      P.Arrive(p)
    else
      p.x, p.y = p.x + dx / d * step, p.y + dy / d * step
    end
  end
  P.Put(p)
end

function P.Arrive(p)
  local s = p.state
  if s == "wander" then
    P.Rest(p)
  elseif s == "out" then
    p.state, p.wait, p.moving = "sniff", P.SNIFF, nil
    P.Anim(p, P.ANIM.stand)
  elseif s == "search" then
    p.legs = (p.legs or 1) - 1
    if p.legs > 0 then
      local x, y = somewhere(35, 85)
      P.Go(p, x, y, P.RUN, "search")
    else
      p.state, p.wait, p.moving = "sniff", P.SNIFF, nil
      P.Anim(p, P.ANIM.stand)
    end
  elseif s == "back" then
    P.Report(p)
  end
end

--- SEND: read everyone fresh, every pup out after the nearest ones (or out for a run when there is nobody).
function P.Send()
  P.Gather(true)
  P.say = #P.list > 0 and ("%d PAL%s ONLINE - PUPS OUT"):format(#P.list, #P.list == 1 and "" or "S") or "NOBODY ONLINE - PUPS LOOKING ANYWAY"
  for _, p in ipairs(P.pups or {}) do
    local e = P.NextJob()
    if e or #P.list == 0 then P.Fetch(p, e) else P.Rest(p, 0.5) end
  end
  P.Paint()
end

--- A row's click: a pup runs to that pal again (the nearest idle one, else the first).
function P.FetchNow(e)
  if not e then return nil end
  local pick
  for _, p in ipairs(P.pups or {}) do
    if p.state == "idle" or p.state == "wander" then
      if not pick or (p.x * p.x + p.y * p.y) < (pick.x * pick.x + pick.y * pick.y) then pick = p end
    end
  end
  pick = pick or (P.pups and P.pups[1])
  if not pick then return nil end
  if pick.job and pick.job ~= e then pick.job.taken = nil end
  P.Fetch(pick, e)
  P.say = ("PUP %d: AFTER %s"):format(pick.i, (e.name or "?"):upper())
  P.Paint()
  return pick
end

-- ------------------------------------------------------------------ the scope, each frame

function P.PaintSweep()
  local f = P.frame
  for k, l in ipairs(f.sweep) do
    local a = P.angle - (k - 1) * P.TRAIL_STEP
    l:SetEndPoint("CENTER", f.scope, math.sin(a) * P.RAD, math.cos(a) * P.RAD)
  end
end

--- The blips: lit as the beam passes and fading after; a found pal gold with its name.
function P.PaintBlips()
  local f = P.frame
  local i = 0
  for _, e in ipairs(P.list or {}) do
    if e.px then
      i = i + 1
      local b = f.blips[i]
      if not b then break end
      local bearing = math.atan2(e.px, e.py) % TAU
      local behind = (P.angle - bearing) % TAU
      local glow = math.max(0, 1 - behind / 2.2)
      local base = e.guess and 0.25 or 0.4
      b.dot:ClearAllPoints()
      b.dot:SetPoint("CENTER", f.scope, "CENTER", e.px, e.py)
      b.dot:SetVertexColor(rgb(e.found and "gold" or (e.guess and "slate" or "accent")))
      b.dot:SetAlpha(math.min(1, base + glow * 0.75))
      b.dot:SetSize(e.guess and 5 or 7, e.guess and 5 or 7)
      b.dot:Show()
      if e.found then
        b.name:SetText((e.guess and "~" or "") .. ((e.name or ""):match("^(%S+)") or ""))
        b.name:ClearAllPoints()
        b.name:SetPoint("BOTTOM", b.dot, "TOP", 0, 1)
        b.name:SetAlpha(math.min(1, 0.55 + glow * 0.45))
        b.name:Show()
      else
        b.name:Hide()
      end
    end
  end
  for j = i + 1, #f.blips do f.blips[j].dot:Hide() f.blips[j].name:Hide() end
end

function P.Step(dt)
  local f = P.frame
  if not (f and f:IsShown()) then return end
  P.angle = ((P.angle or 0) + P.SWEEP * dt) % TAU
  P.since = (P.since or 0) + dt
  if P.stale or P.since >= P.REGATHER then P.Gather() P.Paint() end
  P.PaintSweep()
  P.PaintBlips()
  for _, p in ipairs(P.pups) do P.StepPup(p, dt) end
end

-- ------------------------------------------------------------------ the readout

local function classRGB(file)
  local c = file and RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
  if c then return c.r, c.g, c.b end
  return rgb("ink")
end

--- What the list shows: the pals the pups have reported, nearest first.
function P.Reported()
  local out = {}
  for _, e in ipairs(P.list or {}) do if e.reported then out[#out + 1] = e end end
  return out
end

function P.Paint()
  local f = P.frame
  if not f then return end
  local list = P.list or {}
  local done = P.Reported()
  local best = done[1]
  if best then
    f.near:SetText(best.name or "?")
    f.near:SetTextColor(classRGB(best.classFile))
    f.nearAt:SetText(P.Where(best))
  else
    f.near:SetText(#list > 0 and "SNIFFING..." or "NOBODY")
    f.near:SetTextColor(rgb("ink2"))
    f.nearAt:SetText(#list > 0 and "the pups are out" or "no pal online")
  end
  f.say:SetText(P.say or "")
  f.head:SetText(("FOUND %d / %d"):format(#done, #list))
  for i, r in ipairs(f.rows) do
    local e = done[i]
    r.entry = e
    if e then
      r.name:SetText(e.name or "?")
      r.name:SetTextColor(classRGB(e.classFile))
      r.at:SetText(P.Where(e))
      r.dot:SetVertexColor(rgb(P.SRC[e.src] or "ink2"))
      r:Show()
    else
      r:Hide()
    end
  end
  f.rng:SetText(("RNG %s YD"):format(P.Yards(P.range or 500)))
  f.half:SetText(P.Yards((P.range or 500) / 2))
  f.build:SetText(NS.Stamp())
end

-- ------------------------------------------------------------------ the window

--- Every clickable thing POPS under the mouse (the standing rule): a purple wash, a bar or edge, the label bright.
local function pop(b, label)
  b.wash = b.wash or K().tex(b, "BORDER", "accent", 0)
  b:SetScript("OnEnter", function(self)
    self.wash:SetAlpha(P.GLOW)
    if self.bar then self.bar:SetAlpha(1) end
    if self.edge and self.edge.set then self.edge:set("accent", 1) end
    if label then label:SetTextColor(rgb("ink")) end
    if self.tip then self.tip(self) end
  end)
  b:SetScript("OnLeave", function(self)
    self.wash:SetAlpha(0)
    if self.bar then self.bar:SetAlpha(0) end
    if self.edge and self.edge.set then self.edge:set("edge", 1) end
    if label then label:SetTextColor(rgb(self.ink or "ink2")) end
    if GameTooltip then GameTooltip:Hide() end
  end)
end
P.Pop = pop

local function textButton(parent, label, w, h, size, onclick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, h)
  K().tex(b, "BACKGROUND", "field", 0.9)
  b.edge = K().border(b, "edge", 1)
  b.label = K().fs(b, label, size or 9, "ink2")
  b.label:SetPoint("CENTER")
  b:SetScript("OnClick", onclick)
  pop(b, b.label)
  return b
end

local function line(parent, layer, colour, alpha, thick)
  local l = parent:CreateLine(nil, layer or "ARTWORK")
  l:SetThickness(thick or 1)
  l:SetTexture("Interface\\Buttons\\WHITE8X8")     -- a Line takes a texture and a tint (bislint line-paint)
  local r, g, b = rgb(colour)
  l:SetVertexColor(r, g, b, alpha or 1)
  return l
end

local function disc(parent, layer, size, colour, alpha)
  local t = parent:CreateTexture(nil, layer or "ARTWORK")
  t:SetTexture(P.ROUND)
  t:SetSize(size, size)
  t:SetVertexColor(rgb(colour))
  t:SetAlpha(alpha or 1)
  return t
end

function P.BuildScope(f)
  local sc = CreateFrame("Frame", nil, f)
  sc:SetSize(P.RAD * 2, P.RAD * 2)
  sc:SetPoint("TOPLEFT", 8, -26)
  f.scope = sc
  local face = disc(sc, "BACKGROUND", P.RAD * 2, "frame", 1)
  face:SetPoint("CENTER")
  -- the rings and the cross, drawn once
  for _, ring in ipairs({ { P.RAD, "line2", 1 }, { P.RAD / 2, "line", 0.9 } }) do
    local r = ring[1]
    for s = 0, P.RING_SEGS - 1 do
      local a1, a2 = s / P.RING_SEGS * TAU, (s + 1) / P.RING_SEGS * TAU
      local l = line(sc, "BORDER", ring[2], ring[3], 1)
      l:SetStartPoint("CENTER", sc, math.sin(a1) * r, math.cos(a1) * r)
      l:SetEndPoint("CENTER", sc, math.sin(a2) * r, math.cos(a2) * r)
    end
  end
  for _, c in ipairs({ { 0, P.RAD, 0, -P.RAD }, { -P.RAD, 0, P.RAD, 0 } }) do
    local l = line(sc, "BORDER", "line", 0.7, 1)
    l:SetStartPoint("CENTER", sc, c[1], c[2])
    l:SetEndPoint("CENTER", sc, c[3], c[4])
  end
  -- the beam and its tail
  f.sweep = {}
  for k = 1, P.TRAIL do
    local l = line(sc, "ARTWORK", "accent", (k == 1) and 0.95 or (0.45 * (1 - (k - 1) / P.TRAIL)), k == 1 and 2 or 3)
    l:SetStartPoint("CENTER", sc, 0, 0)
    l:SetEndPoint("CENTER", sc, 0, P.RAD)
    f.sweep[k] = l
  end
  -- you
  local me = disc(sc, "OVERLAY", 7, "gold", 1)
  me:SetPoint("CENTER")
  -- the blips
  f.blips = {}
  for i = 1, P.MAX_PALS do
    local dot = disc(sc, "OVERLAY", 7, "accent", 0)
    dot:Hide()
    local name = K().fs(sc, "", 7, "gold")
    name:Hide()
    f.blips[i] = { dot = dot, name = name }
  end
  -- the words on the glass
  local north = K().fs(sc, "N", 8, "dim")
  north:SetPoint("TOP", sc, "TOP", 0, -3)
  f.rng = K().fs(sc, "", 8, "ink2")
  f.rng:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 0, 2)
  f.half = K().fs(sc, "", 7, "dim")
  f.half:SetPoint("BOTTOMLEFT", sc, "CENTER", 3, P.RAD / 2 + 1)
  -- the pups
  P.pups = {}
  for i, npc in ipairs(P.PUPS) do
    local okM, m = pcall(CreateFrame, "DressUpModel", nil, sc)
    if okM and m then
      m:SetSize(P.PUP_SZ, P.PUP_SZ)
      if m.SetFrameLevel and sc.GetFrameLevel then
        local okL, lv = pcall(sc.GetFrameLevel, sc)
        if okL and type(lv) == "number" then m:SetFrameLevel(lv + 3) end
      end
    else
      m = nil
    end
    local icon = sc:CreateTexture(nil, "OVERLAY")
    icon:SetTexture(P.ICON)
    icon:SetSize(16, 16)
    icon:Hide()
    P.pups[i] = { i = i, npc = npc, m = m, icon = icon, x = (i - 2) * 10, y = -4, state = "idle", wait = i * 0.5 }
  end
  return sc
end

function P.Build()
  if P.frame then return P.frame end
  local k = K()
  local f = CreateFrame("Frame", "BiSToolsPups", UIParent)
  P.frame = f
  f:SetSize(P.W, P.H)
  f:SetPoint("CENTER", 0, 60)
  f:SetFrameStrata("DIALOG")
  f:SetScale(P.SCALE)
  if UISpecialFrames then table.insert(UISpecialFrames, "BiSToolsPups") end   -- Escape closes it
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetScript("OnMouseDown", function(self) if self.Raise then self:Raise() end end)
  k.tex(f, "BACKGROUND", "frame", 0.97)
  k.border(f, "edge", 1)
  f.title = k.fs(f, "BiS> PUPS   RADAR", 10, "accent")
  f.title:SetPoint("TOPLEFT", 8, -7)
  f.close = textButton(f, "x", 16, 14, 9, function() P.Toggle(false) end)
  f.close:SetPoint("TOPRIGHT", -4, -4)
  f.build = k.fs(f, "", 7, "dim")                    -- the fingerprint: faint, which copy this is
  f.build:SetJustifyH("RIGHT")
  f.build:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
  f.build:SetAlpha(0.6)
  P.BuildScope(f)
  -- the readout: the nearest, what the pups say, the found list, SEND
  local x0, w = 8 + P.RAD * 2 + 8, P.W - (8 + P.RAD * 2 + 8) - 8
  local lbl = k.fs(f, "NEAREST", 8, "dim")
  lbl:SetPoint("TOPLEFT", x0, -28)
  f.near = k.fs(f, "", 12, "ink")
  f.near:SetPoint("TOPLEFT", x0, -39)
  f.near:SetWidth(w)
  f.near:SetJustifyH("LEFT")
  f.near:SetWordWrap(false)
  f.nearAt = k.fs(f, "", 10, "gold")
  f.nearAt:SetPoint("TOPLEFT", x0, -55)
  f.nearAt:SetWidth(w)
  f.nearAt:SetJustifyH("LEFT")
  f.say = k.fs(f, "", 7, "ink2")
  f.say:SetPoint("TOPLEFT", x0, -70)
  f.say:SetWidth(w)
  f.say:SetJustifyH("LEFT")
  f.head = k.fs(f, "", 8, "dim")
  f.head:SetPoint("TOPLEFT", x0, -88)
  f.rows = {}
  for i = 1, P.ROWS do
    local r = CreateFrame("Button", nil, f)
    r:SetSize(w, P.ROW - 1)
    r:SetPoint("TOPLEFT", x0, -98 - (i - 1) * P.ROW)
    r.bar = r:CreateTexture(nil, "ARTWORK")
    r.bar:SetPoint("TOPLEFT")
    r.bar:SetPoint("BOTTOMLEFT")
    r.bar:SetWidth(2)
    r.bar:SetColorTexture(rgb("accent"))
    r.bar:SetAlpha(0)
    r.dot = disc(r, "ARTWORK", 5, "ink2", 1)
    r.dot:SetPoint("LEFT", 4, 0)
    r.name = k.fs(r, "", 8, "ink")
    r.name:SetPoint("LEFT", 12, 0)
    r.name:SetWidth(w - 12 - 50)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)                         -- one line: a long name is cut, never wrapped over the next row
    r.at = k.fs(r, "", 7, "ink2")
    r.at:SetPoint("RIGHT", -2, 0)
    r.at:SetWidth(50)
    r.at:SetJustifyH("RIGHT")
    r.at:SetWordWrap(false)
    r:SetScript("OnClick", function(self) P.FetchNow(self.entry) end)
    r.tip = function(self)
      local e = self.entry
      if not (e and GameTooltip) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(e.name or "?")
      GameTooltip:AddLine(P.Where(e) .. (e.zone and ("  -  " .. e.zone) or ""), 1, 1, 1)
      GameTooltip:AddLine(P.SRC_WORD[e.src] or "", 0.6, 0.6, 0.6)
      GameTooltip:AddLine("click: a pup runs to them again", 0.6, 0.6, 0.6)
      GameTooltip:Show()
    end
    pop(r)
    r:Hide()
    f.rows[i] = r
  end
  f.send = textButton(f, "SEND PUPS", w, 20, 10, function() P.Send() end)
  f.send:SetPoint("BOTTOMLEFT", x0, 14)
  f.send.ink = "ink"
  f.send.label:SetTextColor(rgb("ink"))
  f.help = k.fs(f, "click a pal: a pup runs to them   drag: move   esc: close", 7, "dim")
  f.help:SetPoint("BOTTOMLEFT", 8, 4)
  -- the clock: only while shown (the client runs no OnUpdate for a hidden frame)
  local acc = 0
  f:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + (elapsed or 0)
    if acc < 1 / P.FPS then return end
    local dt = math.min(acc, 0.25)
    acc = 0
    P.Step(dt)
  end)
  f:Hide()
  return f
end

function P.IsOpen() return P.frame ~= nil and P.frame:IsShown() end

--- Open: ask the game for a fresh roster and friends list, dress the pups, send them.
function P.Toggle(want)
  local f = P.Build()
  if want == nil then want = not f:IsShown() end
  if want then
    local GI = C_GuildInfo
    if GI and GI.GuildRoster then pcall(GI.GuildRoster) elseif GuildRoster then pcall(GuildRoster) end
    if C_FriendList and C_FriendList.ShowFriends then pcall(C_FriendList.ShowFriends) end
    f:Show()
    if f.Raise then f:Raise() end
    P.angle = P.angle or 0
    for _, p in ipairs(P.pups) do
      p.x, p.y = (p.i - 2) * 10, -4
      P.Dress(p)
      P.Put(p)
    end
    P.Send()
  else
    f:Hide()
  end
  return f:IsShown()
end

-- ------------------------------------------------------------------ the door: a button in the BiS> tools box

--- While you travel - on a flight or mounted, outside an instance, out of a fight. "Mostly fun ... while traveling".
function P.Travelling()
  local taxi = UnitOnTaxi and ask(UnitOnTaxi, "player")
  local mounted = IsMounted and ask(IsMounted)
  return (taxi or mounted) and true or false
end

function P.ShowBox()
  if not (R:Enabled("pups") and P.db and P.db.button ~= false) or fighting() then return false end
  if IsInInstance then
    local ok, inside = pcall(IsInInstance)
    if ok and plain(inside) then return false end
  end
  return P.Travelling()
end

function P.BoxButton()
  if P.box then return P.box end
  local k = K()
  local b = CreateFrame("Button", "BiSToolsPupsBox", UIParent)
  b:SetSize(26, 26)
  k.tex(b, "BACKGROUND", "field", 0.95)
  b.edge = k.border(b, "accent", 1)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon:SetTexture(P.ICON)
  b:SetScript("OnClick", function() P.Toggle() end)
  b.wash = k.tex(b, "BORDER", "accent", 0)
  b:SetScript("OnEnter", function(self)
    self.wash:SetAlpha(P.GLOW) self.edge:set("gold", 1)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("BiS> pups")
    GameTooltip:AddLine("Send the pups to find your nearest pal", 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function(self)
    self.wash:SetAlpha(0) self.edge:set("accent", 1)
    if GameTooltip then GameTooltip:Hide() end
  end)
  b:Hide()
  P.box = b
  return b
end

-- ------------------------------------------------------------------ events

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "PLAYER_MOUNT_DISPLAY_CHANGED",
                     "ZONE_CHANGED_NEW_AREA", "GUILD_ROSTER_UPDATE", "FRIENDLIST_UPDATE" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event)
  if not R:Enabled("pups") then return end
  if event == "GUILD_ROSTER_UPDATE" or event == "FRIENDLIST_UPDATE" then
    if P.IsOpen() then P.stale = true end            -- closed: nothing at all
    return
  end
  -- on or off a flight, a mount, a new zone: the box button follows (the box waits out a fight itself)
  local want = P.ShowBox()
  if want ~= P.boxShown then
    P.boxShown = want
    if NS.Box and NS.Box.Refresh then NS.Box.Refresh() end
  end
end)

R:Register({
  name = "pups",
  desc = "a radar toy: send the pups to find your nearest pal",
  usage = "/bist pups",
  -- new in 1.0.0: a save from before 1.0 never had it, so the 1.0 freeze must not write it ON (Arn, 8 Nov: his
  -- cousin's pups came up on). Every tool added from 1.0 on starts off anyway (a missing switch is off).
  defaultOff = true,
  defaults = { button = true },
  options = {
    { kind = "toggle", label = "button in the tools box while you travel",
      help = "On a flight or mounted, the BiS> tools box shows a pup button that opens the radar.",
      get = function(db) return db.button ~= false end,
      set = function(db, v) db.button = v and true or false if NS.Box and NS.Box.Refresh then NS.Box.Refresh() end end },
    { kind = "button", label = "the radar", button = "open",
      help = "Pups run out to every pal online and report who is nearest.",
      action = function(db) P.db = db P.Toggle(true) end },
  },
  OnInit = function(_, db) P.db = db end,
  OnOpen = function(_, db, recenter)
    P.db = db
    if recenter then
      if P.frame then P.frame:ClearAllPoints() P.frame:SetPoint("CENTER", 0, 60) end
      return
    end
    P.Toggle(true)
  end,
  IsOpen = function() return P.IsOpen() end,
  OnClose = function() P.Toggle(false) end,
  OnDisable = function() if P.frame then P.frame:Hide() end end,
  OnSlash = function(_, db)
    P.db = db
    P.Toggle()
  end,
})
