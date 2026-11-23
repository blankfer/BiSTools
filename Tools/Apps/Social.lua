-- BiSTools / Tools / Apps / Social.lua - the friendly emotes in the phone (dev/APPS.md). Its work is Tools/Social.lua's (NS.Social).
local _, NS = ...
local DP = NS.DeckPages
if not (DP and DP.App) then return end

local function plain(v)
  if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
  return v
end
local function now() return GetTime and plain(GetTime()) or 0 end
local function clock(s) s = math.max(0, math.floor(s)) return ("%d:%02d"):format(math.floor(s / 60), s % 60) end
local function ago(t)
  local s = math.max(0, now() - (t or 0))
  if s < 60 then return ("%ds"):format(math.floor(s)) end
  if s < 3600 then return ("%dm"):format(math.floor(s / 60)) end
  return ("%dh"):format(math.floor(s / 3600))
end
--- The tool's own answer in one word, for the right end of a row (the whole answer is under the mouse).
local SHORT = { { "groupmate", "GROUP" }, { "cooldown", "WAITING" }, { "in a fight", "IN A FIGHT" }, { "ten minutes", "TWICE" },
  { "did not say", "NO NAME" }, { "not a player", "NO PLAYER" }, { "complained", "REFUSED" } }
local function short(why)
  why = tostring(why or "")
  for _, s in ipairs(SHORT) do if why:find(s[1], 1, true) then return s[2], "dim" end end
  local emote = why:match("^(/%a+) %- thanked")
  if emote then return emote, "good" end
  return "LEFT OUT", "dim"
end

DP.App.social = function(_, db)
  local S = NS.Social
  local function thanks() return db().thanks == true end
  local function left() return S.next and math.max(0, S.next - now()) or 0 end
  local function count() local n = 0 for _ in pairs(S.thanked or {}) do n = n + 1 end return n end
  --- db.emotes is the tool's own pick of emotes (none = all of them).
  local function uses(e)
    local mine = db().emotes
    if type(mine) ~= "table" or #mine == 0 then return true end
    for _, x in ipairs(mine) do if x == e then return true end end
    return false
  end
  --- One in or out of the pick; the last one stays.
  local function switch(e)
    local out, had = {}, uses(e)
    for _, x in ipairs(S.EMOTES) do
      local want = uses(x)
      if x == e then want = not had end
      if want then out[#out + 1] = x end
    end
    if #out == 0 then return end
    db().emotes = #out < #S.EMOTES and out or nil
  end
  local function emoteRows()
    local out = {}
    for i, e in ipairs(S.EMOTES) do
      local yes = uses(e)
      out[i] = { mark = yes and "v" or "", text = "/" .. e:lower(), right = yes and "ON" or "OFF", ink = yes and "good" or "dim", done = not yes,
        tip = yes and "Click: leave it out" or "Click: use it again", act = { word = "switch", peek = true, fn = function() switch(e) end } }
    end
    return out
  end
  local function ruleRows()
    local d = db()
    return {
      { text = "Buffed by a stranger", right = "YES", ink = "good", tip = "Any player who is not with you, when the game says who it was" },
      { text = "Buffed by your group", right = d.groupToo and "YES" or "NO", ink = d.groupToo and "good" or "dim", tip = "Click: switch it",
        act = { word = "switch", peek = true, fn = function() d.groupToo = not d.groupToo end } },
      { text = "In a fight", right = "NEVER", ink = "dim", tip = "The game hides who buffed you then" },
      { text = "Wait between two", right = ("%d-%d min"):format(S.MIN_GAP / 60, S.MAX_GAP / 60), ink = "accent", tip = "A different wait every time" },
      { text = "Same player again", right = ("%d min"):format(S.SAME_GAP / 60), ink = "accent", tip = "Nobody is thanked twice before that" },
    }
  end
  local function recentRows()
    local out = {}
    for i, h in ipairs(S.history or {}) do
      local word, ink = short(h.why)
      local subw = (h.spell and (h.spell .. ", ") or "") .. ago(h.at) .. " ago"
      out[i] = { mark = ink == "good" and "v" or "", text = h.who or "Someone", right = word, ink = ink, done = ink ~= "good", sub = subw, tint = ink == "good" and "good" or nil,
        tip = (h.spell and (h.spell .. "\n") or "") .. tostring(h.why) .. "\n" .. ago(h.at) .. " ago" }
    end
    return out
  end
  return {
    page = {
      tick = true,
      tour = { { text = "Somebody buffs you: it thanks them with a friendly emote.", note = "Never in a fight, never twice in a row." },
        { text = "RECENT says who buffed you, and what it did or why not." } },
      kicker = function() return thanks() and "thanking for buffs" or "not thanking" end,
      tabs = function() return { "RECENT", "EMOTES", "RULES" } end,
      boxes = function()
        local l = left()
        return { { "THANKED", count(), "good" },
          { "NEXT", not thanks() and "OFF" or l > 0 and clock(l) or "READY", thanks() and (l > 0 and "gold" or "good") or "dim" },
          { "LAST", S.lastThanked and ago(S.lastThanked.at) or "-", "ink" } }
      end,
      rows = function(tab) return tab == 2 and emoteRows() or tab == 3 and ruleRows() or recentRows() end,
      text = function(tab)
        if tab ~= 1 or #(S.history or {}) > 0 then return nil end
        return thanks() and "Nobody has buffed you since you logged in. Who does comes here, with what it did."
          or "Not thanking. Press the big button: whoever buffs you gets a friendly emote."
      end,
      say = function()
        local t = S.lastThanked
        if t then return "Last: /" .. tostring(t.emote):lower() .. " " .. tostring(t.who) .. (t.err and " (the game complained)" or "") end
        return thanks() and "One of the emotes you left on, at random." or "It is off."
      end,
      big = function(tab)
        if not thanks() then return { word = "START THANKING", fn = function() db().thanks = true end } end
        return tab == 1 and { word = "STOP THANKING", fn = function() db().thanks = false end } or nil
      end,
    },
  }
end
