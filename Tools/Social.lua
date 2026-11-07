-- BiSTools / Tools / Social.lua
-- THE SOCIAL TOOL: small courtesies, so you do not have to type them (12 Oct 2026).
--
-- Arn: "when i get a buff from a friendly player i hate having to say /thanks /kiss /hug etc. can we track
-- who buffed us and it select a random friendly emote to auto emote them maybe with a 2-5 min cooldown ...
-- maybe its own social module we add on stuff later".
--
-- A buff lands on you: UNIT_AURA for "player" carries what was added and, when the game knows the caster
-- as a unit, sourceUnit. EllesmereUI's note on Forever: in restricted combat that payload can be wholly
-- SECRET - so this only ever works OUT OF COMBAT, and every field is asked before it is touched. Strangers
-- buff you between fights anyway. DoEmote is what Overlord and Olympus call on Forever; Overlord skips it
-- in combat, and so does this.
--
-- Not a spammer: a random 2-5 minutes between emotes, the same player never twice in ten, groupmates left
-- alone unless asked (in a dungeon a buff is routine). OFF until switched on: an addon that starts hugging
-- strangers the day it is installed is a surprise nobody asked for.
local _, NS = ...
local T, R = NS.T, NS.Registry

local S = { MIN_GAP = 120, MAX_GAP = 300, SAME_GAP = 600 }
NS.Social = S
S.EMOTES = { "THANK", "HUG", "KISS", "CHEER", "BOW", "SALUTE" }

local function hidden(v)
  if v == nil or not issecretvalue then return false end
  local ok, yes = pcall(issecretvalue, v)
  return (not ok) or yes == true
end
local function plain(v) if hidden(v) then return nil end return v end
local function field(t, k)
  local ok, v = pcall(function() return t[k] end)
  if not ok then return nil end
  return plain(v)
end

local function note(why, who)
  S.lastWhy, S.lastWho = why, who
  return nil
end

-- THE LAST FIVE (Arn, 21 Oct: "i just dont know why sometimes it misses a emote"): why only kept the
-- latest answer, and your own next buff wrote over it. Every buff from someone else now goes on a short
-- list - who, which buff, what was done or why not - newest first, for this session.
S.HISTORY = 5
S.history = {}
local function remember(why, who, spell)
  local now = GetTime and GetTime() or 0
  local top = S.history[1]
  -- a buff lands in pieces: a piece with nobody named, or the same answer again, is the same buff
  if top and now - top.at < 3 and (who == nil or (top.who == who and top.why == why)) then return end
  table.insert(S.history, 1, { who = who, why = why, spell = type(spell) == "string" and spell or nil, at = now })
  S.history[S.HISTORY + 1] = nil
end

--- Is this unit in your party or raid? A plain yes only.
local function grouped(unit)
  for _, fn in ipairs({ UnitInParty, UnitInRaid }) do
    if fn then
      local ok, v = pcall(fn, unit)
      v = ok and plain(v)
      if v and v ~= 0 then return true end
    end
  end
  return false
end

--- A buff landed: is it one to thank for, and who for? Answers the emote it did, or nil (S.lastWhy says why).
function S.OnBuffs(db, info)
  if not db.thanks then return note("off - /bist social on") end
  if type(info) ~= "table" or hidden(info) then return note("the game gave no details") end
  if InCombatLockdown and InCombatLockdown() then
    -- a player's buff landing mid-fight is a miss worth listing; added auras only (no client calls), and
    -- only a caster the game names plainly who isn't you
    local added = field(info, "addedAuras")
    if type(added) == "table" then
      for i = 1, #added do
        local a = plain(added[i])
        local src = type(a) == "table" and field(a, "isHelpful") == true and field(a, "sourceUnit")
        if type(src) == "string" and src ~= "player" then
          local ok, name = pcall(UnitName, src)
          name = ok and plain(name)
          if type(name) == "string" and name ~= "" then remember("in a fight - never then", name, field(a, "name")) end
        end
      end
    end
    return note("in a fight - never then")
  end
  local lock = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
  if lock then
    local ok, locked = pcall(lock)
    if not ok or hidden(locked) or locked then return note("the game is holding chat back") end
  end
  local now = GetTime and GetTime() or 0
  local list = {}
  local added = field(info, "addedAuras")
  if type(added) == "table" then
    for i = 1, #added do list[#list + 1] = added[i] end
  end
  -- A RECAST IS AN UPDATE, NOT AN ADD (Arn, 14 Oct: Blessing of Kings, and "nothing new on you"): a
  -- buff you already wore comes back as updatedAuraInstanceIDs. One back at its FULL duration was
  -- just cast on you - thanked like a new one; a timer merely ticking is not.
  local updated = field(info, "updatedAuraInstanceIDs")
  local get = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
  if type(updated) == "table" and get then
    for i = 1, #updated do
      local id = plain(updated[i])
      local ok, a = pcall(get, "player", id)
      if ok and type(a) == "table" and not hidden(a) then
        local dur, exp = field(a, "duration"), field(a, "expirationTime")
        if type(dur) == "number" and type(exp) == "number" and dur > 0 and exp - now >= dur - 3 then
          list[#list + 1] = a
        end
      end
    end
  end
  -- nothing landed: SAY NOTHING. A ticking timer used to write "nothing new on you" over the answer
  -- about the buff that DID land, seconds after it did.
  if #list == 0 then return nil end
  for i = 1, #list do
    local a = list[i]
    if type(a) == "table" and not hidden(a) then
      local helpful, src, spell = field(a, "isHelpful"), field(a, "sourceUnit"), field(a, "name")
      local function say(why, who) remember(why, who, spell) return note(why, who) end
      -- THE ONE UNKNOWN: does the game name a stranger who buffs you (a sourceUnit), or only someone
      -- you have targeted / see a nameplate for? /bist social why says which, in game.
      if helpful == true and type(src) ~= "string" then say("the game did not say who", nil) end
      if helpful == true and type(src) == "string" then
        local function yes(fn, ...) if not fn then return false end local ok, v = pcall(fn, ...) return ok and plain(v) == true end
        local name = plain(UnitName(src))
        if yes(UnitIsUnit, src, "player") then
          note("your own buff", nil)                       -- not listed: the list is other people's buffs
        elseif type(name) ~= "string" or name == "" then
          say("the game did not say who", nil)
        elseif not yes(UnitIsPlayer, src) then
          say("not a player (a pet or a creature)", name)
        elseif grouped(src) and not db.groupToo then
          say("a groupmate - switched off", name)
        elseif S.next and now < S.next then
          say(("the cooldown - %d s left"):format(math.floor(S.next - now + 0.5)), name)
        elseif S.thanked[name] and now - S.thanked[name] < S.SAME_GAP then
          say("thanked them less than ten minutes ago", name)
        else
          local list = (type(db.emotes) == "table" and #db.emotes > 0) and db.emotes or S.EMOTES
          local emote = list[math.random(#list)]
          -- THE COOLDOWN STARTS BEFORE THE EMOTE, WHATEVER THE GAME ANSWERS (Arn, 12 Oct: "You hug
          -- Mediumroar Dacraina." then "You thank Mediumroar Dacraina." two seconds apart - "it did it by
          -- itself so it needs a cooldown to not be spammy"). It was set only after DoEmote came back
          -- clean; an emote the game performs and THEN errors on left no cooldown, and the next piece of
          -- the same buff emoted again. Any attempt now costs the full gap and marks the player.
          S.thanked[name] = now
          S.next = now + S.MIN_GAP + math.random() * (S.MAX_GAP - S.MIN_GAP)
          -- kept apart from the last look: a buff lands in pieces, and a later piece with no caster
          -- named overwrote "thanked" with "did not say who" (Arn's paste, 12 Oct)
          S.lastThanked = { who = name, emote = emote, at = now }
          local ok, err = false, nil
          if DoEmote then ok, err = pcall(DoEmote, emote, name) end
          if not ok then
            S.lastThanked.err = tostring(err or "no DoEmote")
            say("/" .. emote:lower() .. " - the game complained: " .. tostring(err), name)
            return emote, name
          end
          say("/" .. emote:lower() .. " - thanked", name)
          return emote, name
        end
      end
    end
  end
  return nil
end

S.thanked = {}

function S.Why()
  NS.Print("social: thanks for buffs %s", T.text(S.db and S.db.thanks and "good" or "warn", S.db and S.db.thanks and "on" or "off"))
  local lt = S.lastThanked
  local now = GetTime and GetTime() or 0
  DEFAULT_CHAT_FRAME:AddMessage("  last thanked: " .. (lt and (T.text("ink", lt.who) .. T.text("muted",
    (" (/%s, %d s ago)"):format(lt.emote:lower(), math.floor(now - lt.at + 0.5)))) or T.text("muted", "nobody yet")))
  if #S.history == 0 then
    DEFAULT_CHAT_FRAME:AddMessage("  " .. T.text("muted", "no buffs from other players yet this session"))
  else
    DEFAULT_CHAT_FRAME:AddMessage(("  the last %d buffs from other players:"):format(#S.history))
    for _, h in ipairs(S.history) do
      local ago = now - h.at
      ago = ago < 90 and ("%d s ago"):format(math.floor(ago + 0.5)) or ("%d min ago"):format(math.floor(ago / 60 + 0.5))
      DEFAULT_CHAT_FRAME:AddMessage("    " .. T.text("ink", h.who or "someone") ..
        (h.spell and T.text("muted", " (" .. h.spell .. ")") or "") .. " - " .. h.why .. T.text("muted", ", " .. ago))
    end
  end
  local left = S.next and GetTime and (S.next - GetTime()) or 0
  if left > 0 then DEFAULT_CHAT_FRAME:AddMessage("  next emote possible in " .. math.floor(left + 0.5) .. " s") end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("UNIT_AURA")
ev:SetScript("OnEvent", function(_, _, unit, info)
  -- one string compare first: your own auras only, everyone else's change for free
  if hidden(unit) or unit ~= "player" then return end      -- hidden FIRST: even == is refused on a secret
  if not R:Enabled("social") then return end
  local db = R:DBFor(R:Get("social"))
  if not db.thanks then return end
  S.OnBuffs(db, info)
end)
S.events = ev

R:Register({
  name = "social",
  desc = "a friendly emote at whoever buffs you",
  usage = "/bist social [on | off | group | why]",
  defaults = { thanks = false },
  options = {
    { kind = "toggle", label = "emote when buffed", help = "When another player buffs you, out of combat, a random friendly emote at them (/thank, /hug...). At most one every 2-5 minutes.", get = function(db) return db.thanks == true end,
      set = function(db, on) db.thanks = on and true or false end },
    { kind = "toggle", label = "groupmates too", help = "Thank groupmates as well. Off by default: in a dungeon a buff is routine.", get = function(db) return db.groupToo == true end,
      set = function(db, on) db.groupToo = on and true or false end },
  },
  OnInit = function(_, db) S.db = db end,
  OnSlash = function(_, db, args)
    S.db = db
    if args == "on" or args == "off" then
      db.thanks = args == "on"
      return NS.Print("a friendly emote at whoever buffs you: %s", db.thanks and "on" or "off")
    elseif args == "group" then
      db.groupToo = not db.groupToo
      return NS.Print("groupmates %s", db.groupToo and "thanked too" or "left alone")
    end
    S.Why()
  end,
})
