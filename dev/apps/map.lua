-- the see-through map's app (Tools/Apps/Map.lua)
return function(H)
  local NS, ok, R, Dk = H.NS, H.ok, H.R, H.Dk
  local O = NS.Overlay
  local tool = R:Get("map")
  local def = H.Page("map")
  local p = def.page
  local db = R:DBFor(tool)
  local CM = _G.C_Map
  local keep = { n = _G.GetNumGroupMembers, raid = _G.IsInRaid, gun = _G.GetUnitName, pos = CM.GetPlayerMapPosition, map = CM.GetMapInfo, best = CM.GetBestMapForUnit,
    lib = O.CommLib, is = _G.issecretvalue, iu = _G.UnitIsUnit, saved = {}, odb = O.db }
  for k, v in pairs(db) do keep.saved[k] = v end
  CM.GetBestMapForUnit = function() return 1411 end
  local spots = { player = { 0.451, 0.602 }, party1 = { 0.5, 0.25 } }
  CM.GetPlayerMapPosition = function(_, u) local s = spots[u] return s and { GetXY = function() return s[1], s[2] end } or nil end
  CM.GetMapInfo = function(id) return ({ [1411] = { name = "Durotar" }, [1412] = { name = "Mulgore" } })[id] end
  ok(p.title() == "Durotar" and p.boxes(1)[1][2] == "45.1" and p.boxes(1)[2][2] == "60.2", "map: where you are", p.title())
  -- the big key
  if O.frame then O.Show(db, false) end
  ok(p.big(1).word == "SHOW THE MAP" and p.boxes(1)[3][2] == "AWAY", "away: SHOW THE MAP")
  Dk.Press(def, p.big(1))()
  ok(O.frame:IsShown() and p.big(1).word == "HIDE THE MAP" and p.boxes(1)[3][2] == "SHOWN", "one press: it is shown")
  Dk.Press(def, p.big(1))()
  ok(not O.frame:IsShown(), "and away again")
  -- its quick menu
  local function by(text) for _, r in ipairs(p.rows(1)) do if r.text == text then return r end end end
  ok(#p.rows(1) == #O.MenuRows() - 1, "every line of its quick menu but the options one")
  db.group = nil
  ok(by("Show group").right == "ON", "a tick")
  by("Show group").act.fn()
  ok(db.group == false and by("Show group").right == "OFF", "flips the tool's own switch")
  db.size = 30
  by("Size").more.fn()
  ok(db.size == 40 and by("Size").right == "40%", "a step")
  by("Size").less.fn()
  by("Size").less.fn()
  ok(db.size == 30, "never under its least")
  db.pos = { 5, -5 }
  p.keys(1)[1].fn()
  ok(db.pos == nil, "TO ITS CORNER is /bist map reset")
  db.trail = false
  ok(#p.keys(1) == 1, "no trail: nothing to wipe")
  db.trail, db.trails = true, { ["1411"] = { { 0.1, 0.1 } } }
  p.keys(1)[2].fn()
  ok(p.keys(1)[2].word == "SURE?" and #db.trails["1411"] == 1, "WIPE TRAIL asks first")
  p.keys(1)[2].fn()
  ok(#db.trails["1411"] == 0, "twice: wiped")
  -- people
  _G.GetNumGroupMembers = function() return 1 end
  O.CommLib = function() return nil end
  ok(#p.rows(2) == 0 and p.text(2):find("Nobody to show", 1, true), "nobody: it says so")
  _G.GetNumGroupMembers = function() return 3 end
  _G.IsInRaid = function() return false end
  _G.UnitIsUnit = function() return false end
  _G.GetUnitName = function(u) return u == "party1" and "Chain Healz" or "Gnarly Gnar" end
  O.CommLib = function() return { Spots = function() return { ["Abby Smith"] = { map = 1412, x = 0.1, y = 0.2 }, ["Zed Law-Realm"] = { map = 1411, x = 0.3, y = 0.4 },
    ["Chain Healz"] = { map = 1411, x = 0.5, y = 0.25 } } end } end
  local r = p.rows(2)
  ok(#r == 4 and r[1].text == "Chain Healz" and r[1].right == "50.0, 25.0" and r[2].text == "Zed Law" and r[2].right == "30.0, 40.0", "your map first, nobody twice",
    tostring(r[1] and r[1].text) .. " " .. tostring(r[2] and r[2].text) .. " " .. #r)
  ok(r[3].text == "Abby Smith" and r[3].right == "Mulgore" and r[3].done and r[4].right == "elsewhere", "the others, by their map's name")
  ok(p.boxes(2)[1][2] == 2 and p.boxes(2)[2][2] == 4, "counted")
  local shared
  O.CommLib = function() return nil end
  local keepS, keepG = O.SetSharing, O.Sharing
  O.SetSharing, O.Sharing = function(on) shared = on end, function() return true end
  ok(p.keys(2)[1].word == "STOP SHARING MY SPOT", "what the key does now")
  p.keys(2)[1].fn()
  ok(shared == false, "the one switch for every BiS addon")
  O.SetSharing, O.Sharing = keepS, keepG
  H.Paint("map", 2)
  -- hidden: a name, a spot
  local secret = setmetatable({}, { __concat = function() error("secret") end, __mul = function() error("secret") end, __lt = function() error("secret") end, __index = function() error("secret") end })
  _G.issecretvalue = function(v) return rawequal(v, secret) end
  _G.GetUnitName = function() return secret end
  spots.player, spots.party1 = { secret, secret }, { secret, secret }
  ok(p.boxes(1)[1][2] == "-" and p.say(1):find("hidden", 1, true), "a hidden position is said")
  H.Paint("map", 1)
  H.Paint("map", 2)
  _G.GetNumGroupMembers, _G.IsInRaid, _G.GetUnitName, _G.issecretvalue, _G.UnitIsUnit = keep.n, keep.raid, keep.gun, keep.is, keep.iu
  CM.GetPlayerMapPosition, CM.GetMapInfo, CM.GetBestMapForUnit, O.CommLib = keep.pos, keep.map, keep.best, keep.lib
  for k in pairs(db) do db[k] = nil end
  for k, v in pairs(keep.saved) do db[k] = v end
  O.db = keep.odb
end
