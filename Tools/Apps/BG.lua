-- BiSTools / Tools / Apps / BG.lua - the tool in the phone (dev/APPS.md): who is marked in a battleground and why, and everybody
-- it remembers. It reads what the tool read (NS.BG.read, healers, killer, mvps, marks, known); the presses are its own commands.
local _, NS = ...
local DP, R = NS.DeckPages, NS.Registry
if not (DP and DP.App) then return end
local B = NS.BG
local D = BiSTheme and BiSTheme.Deck
local SURE = 5
local WHY = { healer = "healer", killer = "killer", mvp = "ours" }

local arm = {}                                            -- { id, till }: what was pressed once
--- A button that asks first: "SURE?" for five seconds, the second press does it.
local function twice(id, word, tip, fn)
  local sure = arm.id == id and GetTime() < arm.till
  return { word = sure and "SURE?" or word, tip = tip, fn = function()
    if arm.id == id and GetTime() < arm.till then arm.id = nil fn()
    else arm.id, arm.till = id, GetTime() + SURE end
  end }
end

--- { row, ... } of who is marked now, and how many marks stand on plates.
function B.DeckMarked()
  local out, had = {}, {}
  if not B.On() then return out, 0 end
  local r = B.read or {}
  for i, s in ipairs(r.heals or {}) do
    if i > B.TOP_HEALERS then break end
    if s.name then
      had[s.name] = true
      out[#out + 1] = { mark = tostring(i), text = s.name, right = s.heal and (s.heal .. " healed") or "healer " .. i, ink = "good", tint = s.class or "good",
        sub = "their healer number " .. i .. (s.class and (", " .. s.class:lower()) or ""),
        tip = s.name .. ": number " .. i .. " on their side by healing done" }
    end
  end
  local k = B.killer
  if k and k.name then
    had[k.name] = true
    out[#out + 1] = { mark = "x", text = k.name, right = k.kb and (k.kb .. " kills") or "top killer", ink = "warn", tint = "warn", sub = "their top killer",
      tip = k.name .. ": the most killing blows on their side" }
  end
  local names = {}
  for name in pairs(B.mvps or {}) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    had[name] = true
    out[#out + 1] = { mark = "v", text = name, right = "our " .. B.mvps[name], ink = "gold", tint = "gold", sub = "our side's best " .. B.mvps[name], tip = name .. ": our side's best " .. B.mvps[name] }
  end
  -- on a plate in sight, from an earlier battleground
  local plates, units = 0, {}
  for u in pairs(B.marks) do units[#units + 1] = u end
  table.sort(units)
  for _, u in ipairs(units) do
    plates = plates + 1
    local f = B.marks[u]
    local name = B.PlateName(u)
    if f.remembered and not (name and had[name]) then
      out[#out + 1] = { mark = "?", text = name or "someone", right = (WHY[f.kind] or "") .. ", known", ink = "dim",
        tip = "Remembered from an earlier battleground" }
    end
  end
  return out, plates
end

local find = ""
local function known()
  local list, h, k = {}, 0, 0
  for name, rec in pairs(B.Known()) do
    if (rec.healer or 0) > 0 then h = h + 1 end
    if (rec.killer or 0) > 0 then k = k + 1 end
    if find == "" or name:lower():find(find:lower(), 1, true) then list[#list + 1] = { name = name, rec = rec } end
  end
  table.sort(list, function(a, b)
    local x, y = a.rec.last or 0, b.rec.last or 0
    if x ~= y then return x > y end
    return a.name < b.name
  end)
  return list, h, k
end

DP.App.bg = function(tool, db)
  local function press(words) tool.OnSlash(tool, db(), words) end
  local function times(n, word) return n .. " " .. word .. (n == 1 and "" or "s") end
  return {
    name = "BG",
    badge = function() return B.On() and #(B.DeckMarked()) or nil end,
    card = {
      tick = true,
      prio = function()
        if not B.On() then return nil end
        return (B.killer or (B.read and B.read.heals and B.read.heals[1])) and 5 or nil
      end,
      lines = function()
        local rows, list = B.DeckMarked(), {}
        for i = 1, math.min(3, #rows) do list[i] = { rows[i].text, rows[i].right } end
        return { "BG", "", B.killer and B.killer.name or "their healers", B.killer and "killer" or "", "warn", list = list }
      end,
      buttons = function() return { { word = "MARK NOW", fn = function() B.Mark() end } } end,
    },
    page = {
      tick = true,
      tour = { { text = "In a battleground: their top three healers and their top killer, read off the scoreboard and marked.",
        note = "KNOWN has everybody it remembers from earlier ones." } },
      tabs = function() return { "MARKED", "KNOWN" } end,
      kicker = function() return B.On() and "in a battleground" or "not in a battleground" end,
      find = function(tab)
        if tab ~= 2 then return nil end
        return { hint = "a name", get = function() return find end, set = function(words) find = words or "" end }
      end,
      boxes = function(tab)
        if tab == 2 then
          local list, h, k = known()
          if #list == 0 and h + k == 0 then return {} end
          return { { "KNOWN", #list, "ink" }, { "HEALERS", h, "good" }, { "KILLERS", k, "warn" } }
        end
        if not B.On() then return {} end
        local _, plates = B.DeckMarked()
        return { { "ENEMIES", B.read and B.read.enemies or 0, "ink" }, { "HEALERS", math.min(B.TOP_HEALERS, #(B.read and B.read.heals or {})), "good" },
          { "IN SIGHT", plates, "gold" } }
      end,
      rows = function(tab)
        if tab == 1 then return (B.DeckMarked()) end
        local out = {}
        for i, e in ipairs((known())) do
          local rec = e.rec
          local h, k = rec.healer or 0, rec.killer or 0
          local why = (h > 0 and times(h, "heal") or "") .. (h > 0 and k > 0 and ", " or "") .. (k > 0 and times(k, "kill") or "")
          out[i] = { mark = k > 0 and "x" or "+", text = e.name .. (why ~= "" and "  " .. why or ""), tint = k > 0 and "warn" or "good",
            sub = rec.last and date and ("last seen " .. date("%d %b", rec.last)) or nil, right = k > 0 and "KILLER" or "HEALER", ink = k > 0 and "warn" or "good",
            tip = e.name .. ": a top healer in " .. times(h, "battleground") .. ", the top killer in " .. times(k, "battleground")
              .. (rec.last and date and (", last seen " .. date("%d %b", rec.last)) or ""),
            side = twice("forget:" .. e.name, "FORGET", "Press twice: not remembered any more", function() press("forget " .. e.name) end) }
        end
        return out
      end,
      text = function(tab)
        if tab == 2 then
          if next(B.Known()) == nil then return "Nobody yet: the top healers and the top killer of each battleground are remembered for 30 days." end
          return #(known()) == 0 and "Nobody by that name." or nil
        end
        if not B.On() then
          return "You are not in a battleground. Inside one, their best healers and their top killer are marked by themselves, and listed here."
        end
        if #(B.DeckMarked()) > 0 then return nil end
        local why = B.read and B.read.note
        return why and (why:sub(1, 1):upper() .. why:sub(2) .. ".") or "Nothing read yet: the scoreboard is asked every ten seconds."
      end,
      say = function(tab) return tab == 1 and B.On() and B.read and B.read.byOrder and "Read by the scoreboard's order: the numbers are hidden." or nil end,
      big = function(tab)
        return tab == 1 and B.On() and { word = "MARK NOW", tip = "Reads the scoreboard now and marks them", fn = function() B.Mark() end } or nil
      end,
      keys = function(tab)
        if tab == 2 then
          if next(B.Known()) == nil then return {} end
          return { twice("clear", "CLEAR ALL", "Press twice: everybody forgotten", function() press("clear") end) }
        end
        if not B.On() then return {} end
        local macro, n = B.TargetMacro()
        if n == 0 then return {} end
        -- (targeting is the game's own macro: it lights up with the deck's secure buttons)
        return { { word = "TARGET", macro = macro } }
      end,
    },
  }
end
