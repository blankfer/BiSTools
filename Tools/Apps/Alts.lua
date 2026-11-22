-- BiSTools / Tools / Apps / Alts.lua - the tool in the phone (dev/APPS.md): your characters, the main, what it sends.
--
-- It only PICKS, as the window does (the copying is done on the PC, WoW closed). What would overwrite somebody's setup asks
-- twice: a new main, GETS COPIES for one that had its own setup or was the main, a thing switched on to be sent.
local _, NS = ...
local DP, R = NS.DeckPages, NS.Registry
if not (DP and DP.App) then return end
local A = NS.Alts
local D = BiSTheme and BiSTheme.Deck
local SURE = 5
local INK = { main = "accent", keep = "good", gets = "ink2" }
local ORDER = { "main", "keep", "gets" }
local SAYS = { main = "The others take its setup", keep = "Its own setup is never touched", gets = "It takes the main's setup when WoW closes" }

local open                                                -- the character whose page is open
local arm = {}
local function armed(id) return arm.id == id and GetTime() < arm.till end
local function twice(id, hurts, fn)
  return function()
    if not hurts or armed(id) then arm.id = nil fn() A.Paint() return end
    arm.id, arm.till = id, GetTime() + SURE
  end
end
local function go(name)
  open, arm.id = name, nil
  if D then D.skip = 0 end
end
local function class(e) return e and type(e.class) == "string" and e.class:lower() or "" end

local function charRows(name, d)
  local out = { { mark = "<", text = "Back", tip = "Back to your characters", act = { word = "back", peek = true, fn = function() go(nil) end } } }
  local now = A.Role(name, d)
  for _, role in ipairs(ORDER) do
    local id = role .. ":" .. name
    local is = role == now
    -- (a new main takes it from the old one; leaving MAIN leaves nobody to copy from; GETS COPIES writes over what it had)
    local hurts = not is and (role == "main" or role == "gets" or now == "main")
    out[#out + 1] = { mark = is and "v" or "", text = A.ROLE_WORD[role], right = is and "NOW" or armed(id) and "SURE?" or "PICK",
      ink = is and INK[role] or armed(id) and "warn" or "accent",
      tip = SAYS[role], act = not is and { word = "pick", fn = twice(id, hurts, function() A.SetRole(name, role) end) } or nil }
  end
  return out
end

DP.App.alts = function(tool, db)
  return {
    name = "Alts",
    page = {
      tick = true,
      tour = { { text = "Pick your main. When WoW closes, the others take its nameplates, layout and chat.", note = "KEEP MINE = that one is never touched." } },
      title = function() return open or "Main & alts" end,
      kicker = function()
        if not open then return "copies when WoW closes" end
        local e = A.Data().roster[open] or {}
        return ("level " .. tostring(e.level or "?") .. " " .. class(e))
      end,
      tabs = function() return { "ALTS", "SENDS" } end,
      boxes = function()
        local d = A.Data()
        local n = { main = 0, keep = 0, gets = 0 }
        local list = A.List(d)
        for _, e in ipairs(list) do n[e.role] = n[e.role] + 1 end
        local at = type(d.copied) == "table" and tonumber(d.copied.at)
        return { { "ALTS", #list, "ink" }, { "KEEP", n.keep, "good" }, { "COPIES", n.gets, "gold" },
          { "LAST", at and date and date("%d %b", at) or "-", "ink2" } }
      end,
      rows = function(tab)
        local d, out = A.Data(), {}
        if tab == 2 then
          for i, s in ipairs(A.SENDS) do
            local is = d.sends[s.key] == true
            local id = "send:" .. s.key
            out[i] = { mark = is and "v" or "", text = s.label, right = armed(id) and "SURE?" or is and "ON" or "OFF",
              ink = armed(id) and "warn" or is and "good" or "dim",
              tip = s.sub .. (is and "" or ". Switched on, it is written over on every character that gets copies."),
              act = { word = "switch", fn = twice(id, not is, function() A.SetSend(s.key, not is) end) } }
          end
          return out
        end
        if open and d.roster[open] then return charRows(open, d) end
        open = nil
        for i, e in ipairs(A.List(d)) do
          out[i] = { mark = e.level > 0 and tostring(e.level) or "", text = e.name, right = A.ROLE_WORD[e.role], ink = INK[e.role],
            tip = e.name .. (class(e) ~= "" and (", " .. class(e)) or "") .. ". Click: what it is",
            act = { word = "open", peek = true, fn = function() go(e.name) end } }
        end
        return out
      end,
      text = function(tab)
        local d = A.Data()
        if tab == 1 and next(d.roster) == nil then return "A character joins the list the first time you log it in." end
        if tab == 1 and not open and not d.main then return "Click your main and pick MAIN." end
        if tab == 2 then return "What the main sends. Keybinds and macros already match on both accounts." end
      end,
      say = function(tab)
        local d = A.Data()
        if tab == 2 or not d.main then return nil end
        return (A.Status(d):match("^(.-)%s%s%s") or A.Status(d))          -- (the last copy has its box)
      end,
    },
  }
end
