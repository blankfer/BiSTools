-- BiSTools / Tools / Apps / Map.lua - the tool in the phone (dev/APPS.md). The see-through map itself lies over the game and can not
-- stand on the deck: here is where you are, where your group and your guild are, its quick menu, and the key that shows it.
local _, NS = ...
local DP, R = NS.DeckPages, NS.Registry
if not (DP and DP.App) then return end
local O = NS.Overlay
local SURE = 5

local function plain(v)
  if v == nil then return nil end
  if issecretvalue then
    local ok, s = pcall(issecretvalue, v)
    if not ok or s then return nil end
  end
  return v
end
local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if not ok then return nil end
  return plain(v)
end
local function at(x, y) return ("%.1f, %.1f"):format(x * 100, y * 100) end
local function mapName(id)
  local ok, info = pcall(function() return C_Map.GetMapInfo(id) end)
  if not ok or type(info) ~= "table" then return nil end
  local okN, name = pcall(function() return info.name end)
  name = okN and plain(name) or nil
  return type(name) == "string" and name ~= "" and name or nil
end

--- Your group and your guild, those on your map first: { name, here, right, tip }.
function O.DeckPeople()
  local out, had, here = {}, {}, O.MapID()
  for _, u in ipairs(O.GroupUnits()) do
    if ask(UnitIsUnit, u, "player") ~= true then
      local name = ask(GetUnitName, u, false) or ask(UnitName, u)
      if type(name) == "string" and name ~= "" then
        had[name:match("^(%S+)") or name] = true
        local x, y = O.Where(here, u)
        out[#out + 1] = { name = name, here = x and true or false, right = x and at(x, y) or "elsewhere", kind = "group" }
      end
    end
  end
  local lib = O.CommLib()
  for sender, s in pairs(lib and lib.Spots and lib:Spots() or {}) do
    local name = type(sender) == "string" and sender:match("^([^%-]+)")
    if name and not had[name:match("^(%S+)") or name] then
      local isHere = here ~= nil and s.map == here
      out[#out + 1] = { name = name, here = isHere, right = isHere and at(s.x, s.y) or mapName(s.map) or "elsewhere", kind = "guild" }
    end
  end
  table.sort(out, function(a, b)
    if a.here ~= b.here then return a.here end
    return a.name < b.name
  end)
  return out
end

local arm
DP.App.map = function(tool, db)
  local function showing() return O.frame ~= nil and O.frame:IsShown() and true or false end
  return {
    name = "Map",
    page = {
      tick = true,
      tour = { { text = "SHOW THE MAP lays the see-through map over your game. You play through it.",
        note = "Its tab, top left, drags it. Give it a key in Key Bindings, BiS Tools." } },
      title = function()
        local id = O.MapID()
        return id and mapName(id) or "Map"
      end,
      kicker = function() return O.PlaceName() end,
      tabs = function() return { "MAP", "PEOPLE" } end,
      boxes = function(tab)
        if tab == 2 then
          local list, near = O.DeckPeople(), 0
          for _, p in ipairs(list) do if p.here then near = near + 1 end end
          return { { "ON MAP", near, "good" }, { "SEEN", #list, "ink" }, { "MY SPOT", O.Sharing() and "ON" or "OFF", O.Sharing() and "good" or "dim" } }
        end
        local x, y = O.Where(O.MapID())
        return { { "X", x and ("%.1f"):format(x * 100) or "-", "gold" }, { "Y", y and ("%.1f"):format(y * 100) or "-", "gold" },
          { "MAP", showing() and "SHOWN" or "AWAY", showing() and "good" or "dim" } }
      end,
      rows = function(tab)
        local out = {}
        if tab == 2 then
          for i, p in ipairs(O.DeckPeople()) do
            -- (the colour pass, 22 Nov: who they are to you, under the name; on your map in green)
            out[i] = { mark = p.kind == "guild" and "g" or "+", text = p.name, right = p.right, ink = p.here and "good" or "dim", done = not p.here or nil,
              tint = p.here and (p.kind == "guild" and "good" or "accent") or nil,
              sub = (p.kind == "guild" and "guildmate sharing their spot" or "in your group") .. (p.here and ", on this map" or ""),
              tip = p.kind == "guild" and "A guildmate who shares their spot" or "In your group" }
          end
          return out
        end
        -- the quick menu of the map's own tab (its "All settings" line is the SETTINGS tab here)
        for _, r in ipairs(O.MenuRows()) do
          if r.kind == "check" then
            local is = r.get(db()) and true or false
            out[#out + 1] = { mark = is and "v" or "", text = r.label, right = is and "ON" or "OFF", ink = is and "good" or "dim",
              act = { word = "switch", fn = function() r.set(db(), not r.get(db())) end } }
          elseif r.kind == "step" then
            local function by(sign) r.set(db(), math.max(r.min, math.min(r.max, r.get(db()) + sign * r.step))) end
            out[#out + 1] = { text = r.label, right = r.get(db()) .. "%",
              less = { word = "-", fn = function() by(-1) end }, more = { word = "+", fn = function() by(1) end } }
          end
        end
        return out
      end,
      text = function(tab)
        if tab == 2 and #O.DeckPeople() == 0 then
          return "Nobody to show: no group, and no guildmate with a BiS addon is sharing their spot near you."
        end
      end,
      say = function(tab)
        if tab == 1 and not O.Where(O.MapID()) then return "Your position is hidden here." end
      end,
      big = function(tab)
        if tab ~= 1 then return nil end
        local on = showing()
        return { word = on and "HIDE THE MAP" or "SHOW THE MAP", peek = true, fn = function() O.Show(db(), not showing()) end }
      end,
      keys = function(tab)
        if tab == 2 then
          return { { word = O.Sharing() and "STOP SHARING MY SPOT" or "SHARE MY SPOT",
            tip = "Your guildmates with a BiS addon see where you are (one switch for every BiS addon)",
            fn = function() O.SetSharing(not O.Sharing()) end } }
        end
        local out = { { word = "TO ITS CORNER", peek = true, tip = "The map back at the top left", fn = function() tool.OnSlash(tool, db(), "reset") end } }
        if O.TrailOn(db()) then
          local sure = arm and GetTime() < arm
          out[2] = { word = sure and "SURE?" or "WIPE TRAIL", tip = "Press twice: the dotted trail on this map is gone", fn = function()
            if arm and GetTime() < arm then arm = nil tool.OnSlash(tool, db(), "clear") else arm = GetTime() + SURE end
          end }
        end
        return out
      end,
    },
  }
end
