-- BiSTools / Tools / Apps / Windfury.lua - the tool in the phone (dev/APPS.md).
-- LAMP = is Windfury on you, who could give it, who hears ASK; LOG = the asks sent and heard. In a fight the game hides the totem's
-- buff (Windfury.lua's head): the lamp itself is drawn by the client and stays on the screen. ASK and the totem are secure.
local _, NS = ...
local DP, R = NS.DeckPages, NS.Registry
if not (DP and DP.App) then return end

DP.App.windfury = function(_, db)
  local W, C, D = NS.WF, NS.Combo, BiSTheme.Deck
  local ID = "BiSTools:tool-windfury"

  local function plain(v) if v == nil or (issecretvalue and issecretvalue(v)) then return nil end return v end
  local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok then return plain(v) end
  end
  local function fighting() return InCombatLockdown and InCombatLockdown() and true or false end
  --- What is on you: { imbue, weapon, totem } - or nil: in a fight the game does not say.
  local function up()
    if fighting() then return nil end
    local im = C and C.ImbueNow and C.ImbueNow()
    local weapon = type(im) == "string" and im:find("Windfury", 1, true) and true or false
    return { imbue = im, weapon = weapon, totem = C and C.AuraUp and C.AuraUp("Windfury Totem") or false }
  end
  --- The shamans in your party: { unit, name, hears }.
  local function shamans()
    local out = {}
    for i = 1, 4 do
      local u = "party" .. i
      if ask(UnitExists, u) and W.ClassOf(u) == "SHAMAN" then out[#out + 1] = { unit = u, name = W.NameOf(u), hears = W.CanAsk(u) and true or false } end
    end
    return out
  end
  local function yes(v) return v and "YES" or "NO", v and "good" or "warn" end
  local function log() return db().log or {} end

  --- No Windfury, out of a fight, and somebody could change that? Alone as a shaman another imbue is your own choice.
  local function missing()
    local s = up()
    if not s or s.weapon or s.totem or not W.ShamanNear() then return false end
    if ask(IsResting) or ask(UnitIsDeadOrGhost, "player") then return false end
    return not (s.imbue and not W.ShamanUnit())
  end
  --- The button that does something about it: yours as a shaman, else ASK. Both secure.
  local function askKey()
    if W.IsShaman() then return W.KnowsWF() and { word = "TOTEM", spell = "Windfury Totem" } or nil end
    local u = W.ShamanUnit()
    return u and { word = "ASK", macro = "/target " .. u } or nil
  end
  local function lampRows()
    local out, s = {}, up()
    local function add(row) out[#out + 1] = row end
    local r, ink = yes(s and s.weapon)
    add({ pic = C and C.IconFor("Windfury Weapon"), mark = "-", text = "On your weapon", right = s and r or "?", ink = s and ink or "dim",
      tip = s and (s.imbue and s.imbue .. " is on your weapon" or "No imbue on your weapon") or "The lamp says it in a fight" })
    r, ink = yes(s and s.totem)
    add({ pic = C and C.IconFor("Windfury Totem"), mark = "-", text = "Totem on you", right = s and r or "?", ink = s and ink or "dim",
      tip = "A shaman's Windfury Totem, read out of a fight" })
    if W.IsShaman() then
      local knows = W.KnowsWF()
      add({ mark = "S", text = "You, a shaman", right = knows and "READY" or "NOT YET", ink = knows and "good" or "dim",
        tip = knows and "Your Windfury Totem button lights up when somebody asks" or "You do not know Windfury Totem yet" })
    end
    local sh = shamans()
    for _, x in ipairs(sh) do
      add({ mark = "S", text = x.name, right = x.hears and "HEARS" or "NO BIS", ink = x.hears and "good" or "dim",
        tip = x.hears and "Hears your ASK: their totem button lights up (with windfury switched on there)"
          or "No BiS Tools heard from them: nothing lights up when you ask" })
    end
    if not W.IsShaman() then
      if #sh == 0 then add({ mark = "S", text = "No shaman in your party", done = true }) end
      add({ mark = "A", text = "ASK aims at", right = sh[1] and sh[1].name or "nobody", ink = sh[1] and "ink2" or "dim", tip = "The first shaman in your party" })
      add({ mark = "A", text = "ASK key", right = db().key or "none", ink = db().key and "gold" or "dim",
        tip = "/bist wf key F puts it on F. Four presses, about two a second." })
    end
    add({ mark = "L", text = "The lamp", right = W.refused and "CANNOT" or "READY", ink = W.refused and "warn" or "good",
      tip = W.refused or "It shows by itself in a fight, with a shaman near" })
    return out
  end
  local function logRows()
    local out, l = {}, log()
    for i = #l, 1, -1 do
      local e = l[i]
      local at = date and type(e.at) == "number" and date("%H:%M", e.at) or ""
      local tip = ("%s target changes in %.1f s%s"):format(tostring(e.n or 0), tonumber(e.span) or 0, e.fight and ", in a fight" or "")
      if e.k == "sent" then
        out[#out + 1] = { mark = ">", text = at .. " you asked " .. tostring(e.to or "?"), right = (e.n or 0) .. " x",
          ink = (e.n or 0) >= W.NEED and "good" or "ink2", tip = tip }
      else
        out[#out + 1] = { mark = "<", text = at .. " " .. tostring(e.who or "?"), right = e.lit and "LIT" or e.notBis and "NO BIS" or ((e.n or 0) .. " x"),
          ink = e.lit and "gold" or "dim", done = not e.lit, tip = tip }
      end
    end
    return out
  end

  return {
    card = {
      tick = true,
      prio = function(out)
        if not R:Enabled("windfury") then return nil end
        if missing() then return 5 end
        return out and 2 or nil
      end,
      lines = function()
        local s, sh = up(), shamans()
        local who = sh[1] and sh[1].name or W.IsShaman() and "you" or "nobody"
        local list = { { "On your weapon", s and (yes(s.weapon)) or "?" }, { "Totem on you", s and (yes(s.totem)) or "?" }, { "Shaman", who } }
        if not s then return { "WINDFURY", "", "The lamp has it in a fight", "", "dim", list = list } end
        if s.weapon or s.totem then return { "WINDFURY", "", "Windfury is on you", s.totem and "TOTEM" or "WEAPON", "good", list = list } end
        return { "WINDFURY", "", "No Windfury", "NO", "warn", hot = missing(), list = list }
      end,
      buttons = function()
        local out = { { word = "OPEN", peek = true, fn = function() D.Open(ID) end } }
        out[#out + 1] = askKey()
        return out
      end,
    },
    page = {
      tick = true,
      tour = { { text = "Is Windfury on you, and who could give it.", note = "In a fight the lamp on your screen says it." },
        { text = "ASK lights a shaman's totem button.", note = "Both of you need BiS Tools with windfury on." } },
      tabs = function() return { "LAMP", "LOG" } end,
      boxes = function(tab)
        if tab == 1 then
          local s, n = up(), #shamans()
          local on = s and (s.weapon or s.totem)
          return { { "WINDFURY", s and (on and "ON" or "NO") or "?", s and (on and "good" or "warn") or "dim" },
            { "SHAMANS", n + (W.IsShaman() and 1 or 0), n > 0 and "good" or "ink" },
            { "ASK KEY", W.IsShaman() and "-" or db().key or "none", db().key and "gold" or "dim" } }
        end
        local sent, heard, lit = 0, 0, 0
        for _, e in ipairs(log()) do
          if e.k == "sent" then sent = sent + 1 else heard = heard + 1 end
          if e.lit then lit = lit + 1 end
        end
        if sent + heard == 0 then return {} end
        return { { "SENT", sent }, { "HEARD", heard }, { "LIT", lit, "gold" } }
      end,
      rows = function(tab) return tab == 1 and lampRows() or logRows() end,
      text = function(tab) return tab == 2 and #log() == 0 and "No ask yet. Press ASK in a fight, or get asked: it is written here." or nil end,
      say = function(tab)
        if tab == 2 then return #log() > 0 and ("The newest " .. W.KEEP .. " are kept") or nil end
        if W.refused then return "No lamp: " .. W.refused end
        return W.IsShaman() and "Your totem button comes up in a fight" or "ASK comes in a fight, beside the lamp"
      end,
      big = function(tab)
        if tab ~= 1 then return nil end
        return { word = "SHOW THE LAMP", tip = "For " .. W.TEST .. " s, out of a fight: drag it where you want it", peek = true, fn = function() W.Test() end }
      end,
      keys = function(tab)
        if tab ~= 1 then return {} end
        local out = { askKey() }
        if W.IsShaman() and C and C.Knows and C.Knows("Windfury Weapon") then out[#out + 1] = { word = "WEAPON", spell = "Windfury Weapon" } end
        return out
      end,
    },
  }
end
