--[[
  BiSTools :: Tools/Party.lua - the `party` tool: your usual group, one click to invite them all, one
  to break it up.

  Arn, 15 Oct 2026, reading FojjiCore 3.3.8's party helper: "the saved list to invite is nice and a
  disband button" - and, asked where the list comes from, "its own list". Then: "when in a party or
  in a raid new option to add to party list ... when right click".

  - The list: `db.names`, your group's names (at most P.MAX). Filled by `/bist party save` (whoever
    you are grouped with now), `/bist party add|remove <name>`, or "Add to party list" (BiS section) on a
    party or raid member's right-click menu (outside instances: inside one an addon line breaks the
    game's menu - RC.MenuSafe).
  - Two buttons in the BiS> tools box (Box.lua):
      Invite   everyone on the list who is not with you yet (solo, or leading / assisting)
      Disband  leading: everyone out; otherwise you leave
    They show when the list means something now: solo with a list, or grouped with someone on it.
  - Nothing ticks: GROUP_ROSTER_UPDATE asks the box to look again, out of combat.
]]
local ADDON, NS = ...
local R = NS.Registry

local P = {}
NS.Party = P
P.MAX = 39                       -- a raid less you
P.PER_PUMP, P.PUMP_GAP = 4, 1.2  -- invites sent at once, and the wait before the next few

local function plain(v)
  if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
  return v
end

--- The name a list entry is compared by: the first name - no surname (Forever's "Darthsidiouz
--- Sithlord" is Darthsidiouz to the game), no realm, any case.
function P.Key(name)
  name = plain(name)
  if type(name) ~= "string" or name == "" then return nil end
  local first = name:match("^([^%s%-]+)")
  return first and first:lower() or nil
end

--- What an invite is sent to: the WHOLE name, surname and all (Arn, 15 Oct: "/invite Nebeon" did
--- nothing, and the game's own chat box completed it to "Nebeon Nolightforu" - Forever addresses a
--- player by first name and surname, as its mail does). The name exactly as the list keeps it.
function P.InviteName(name)
  return name
end

--- The short name, for the box's lines only (a surname wraps them).
function P.Short(name)
  return type(name) == "string" and (name:match("^(%S+)") or name) or name
end

function P.List(db)
  if type(db.names) ~= "table" then db.names = {} end
  return db.names
end

function P.Has(db, name)
  local k = P.Key(name)
  if not k then return false end
  for _, n in ipairs(P.List(db)) do if P.Key(n) == k then return true end end
  return false
end

--- Add a name; false (and why) when it is there already, the list is full, or it is no name.
function P.Add(db, name)
  name = plain(name)
  if not P.Key(name) then return false, "no name" end
  if P.Has(db, name) then return false, "already on the list" end
  local list = P.List(db)
  if #list >= P.MAX then return false, "the list is full" end
  list[#list + 1] = name
  return true
end

function P.Remove(db, name)
  local k, list = P.Key(name), P.List(db)
  for i = #list, 1, -1 do
    if P.Key(list[i]) == k then table.remove(list, i) return true end
  end
  return false
end

function P.Grouped() return (IsInGroup and IsInGroup()) and true or false end

function P.Leads()
  if not P.Grouped() then return true end
  local lead = UnitIsGroupLeader and plain(UnitIsGroupLeader("player"))
  local assist = IsInRaid and IsInRaid() and UnitIsGroupAssistant and plain(UnitIsGroupAssistant("player"))
  return lead == true or assist == true
end

--- Everyone grouped with you (not you): { unit, name, key }. A 40-man walk is 120 calls, so the
--- box walks it once and hands it to each question (the `members` argument below).
function P.Members()
  -- one walk per roster change: the event handler lends its walk to everything it calls (17 Oct)
  if P.__members then return P.__members end
  local out = {}
  if not P.Grouped() then return out end
  local raid = IsInRaid and IsInRaid()
  local n = raid and (GetNumGroupMembers and GetNumGroupMembers() or 0) or 4
  for i = 1, n do
    local unit = (raid and "raid" or "party") .. i
    if UnitExists(unit) and not UnitIsUnit(unit, "player") then
      local name = plain(GetUnitName and GetUnitName(unit, true) or UnitName(unit))
      local key = P.Key(name)
      if key then out[#out + 1] = { unit = unit, name = name, key = key } end
    end
  end
  return out
end

--- The names on the list who are not with you (never you).
function P.Missing(db, members)
  local here = { [P.Key(UnitName("player")) or "?"] = true }
  for _, m in ipairs(members or P.Members()) do here[m.key] = true end
  local out = {}
  for _, n in ipairs(P.List(db)) do
    if not here[P.Key(n) or "?"] then out[#out + 1] = n end
  end
  return out
end

--- Does anyone on the list share your group?
function P.WithListed(db, members)
  for _, m in ipairs(members or P.Members()) do if P.Has(db, m.name) then return true end end
  return false
end

--- Whoever you are grouped with now becomes the list. The number saved.
function P.SaveGroup(db)
  local members = P.Members()
  if #members == 0 then return 0 end
  db.names = {}
  for _, m in ipairs(members) do P.Add(db, m.name) end
  return #db.names
end

------------------------------------------------------------- invite / disband --

P.queue = {}
-- SAID, NOT SWALLOWED (Arn, 15 Oct: "i dont think it is sending any invites" - the box ran, the game
-- said nothing, and the pcall had eaten whatever went wrong). A refusal lands in the box's log and
-- once in chat, with the game's own words.
local function send(name)
  local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
  if not invite then P.Refused(name, "this client has no invite call") return end
  local ok, err = pcall(invite, P.InviteName(name))
  if not ok then P.Refused(name, err) return end
  local key = P.Key(name)
  if key then P.out[key] = (GetTime and GetTime()) or 0 end
end

--- SUGGEST TO THE LEADER (22 Nov 2026, Arn: "in forever now we can suggest people to the leader to invite"): in a group you do
--- not lead, the game's own invite call becomes a suggestion the leader is asked to confirm. One name at a time, never a burst,
--- never a raid conversion. true = handed to the game (UNVERIFIED live which words the leader sees).
P.suggested = {}
P.SUGGEST_FOR = 60
function P.Suggests() return P.Grouped() and not P.Leads() end
function P.Suggest(name)
  local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
  if not invite then P.Refused(name, "this client has no invite call") return false end
  local ok, err = pcall(invite, P.InviteName(name))
  if not ok then P.Refused(name, err) return false end
  local key = P.Key(name)
  if key then P.suggested[key] = (GetTime and GetTime()) or 0 end
  return true
end
function P.Suggested(name)
  local at = P.suggested[P.Key(name) or "?"]
  return at ~= nil and ((GetTime and GetTime()) or 0) - at < P.SUGGEST_FOR
end

function P.Refused(name, why)
  why = tostring(why or "?")
  repeat local n why, n = why:gsub("^[^%s]-:%d+: ", "") until n == 0      -- no "file.lua:12: " in front
  P.lastError = why
  P.failed = (P.failed or 0) + 1
  if P.run and P.box then P.Say(NS.T.text("warn", ("%s: the game refused (%s)"):format(P.Short(name) or "?", why))) end
  if not P.saidError then
    P.saidError = true
    NS.Print("party list: the game refused an invite - %s", why)
  end
end

--- A few at a time: a burst of invites is what gets a player's messages throttled.
function P.Pump()
  P.timer = nil
  local n = 0
  while #P.queue > 0 and n < P.PER_PUMP do
    send(table.remove(P.queue, 1))
    n = n + 1
  end
  if #P.queue > 0 and C_Timer and C_Timer.NewTimer then P.timer = C_Timer.NewTimer(P.PUMP_GAP, P.Pump) end
end

--- Invite everyone on the list who is not with you. More than a party holds: a party you lead
--- becomes a raid first (a party of five refuses the sixth).
function P.Invite(db)
  return P.InviteNames(db, P.Missing(db))
end

--- MORE THAN A PARTY HOLDS BECOMES A RAID BY ITSELF (Arn, 21 Oct: "auto turn the party into raid when
--- more than 5 people in the party or if the invited people will be more than 5"). The game counts the
--- invites still out: a party - or you alone - takes five, and the sixth is refused "party is full".
--- And a raid is made only from a party, so alone the first four go out, the rest WAIT (P.held), the
--- first one to join makes it a party, it becomes a raid (P.Held, on GROUP_ROSTER_UPDATE), and then
--- the rest go. Nobody joins in P.HOLD_FOR: the rest are dropped, and Invite again sends them.
--- The invites still out count too, and the game tells an addon nothing about them - so we count our
--- own (P.out): sent, not yet in the group, younger than P.OUT_FOR (an unanswered invite runs out).
P.PARTY, P.HOLD_FOR, P.OUT_FOR = 5, 120, 60
P.KEYWORDS = { "inv", "invite", "123" }      -- the whispered keyword's choices (PartyAuto.lua)
P.out = {}

function P.Out(members)
  local here = {}
  for _, m in ipairs(members or P.Members()) do here[m.key] = true end
  local now, n = (GetTime and GetTime()) or 0, 0
  for k, t in pairs(P.out) do
    if here[k] or now - t > P.OUT_FOR then P.out[k] = nil else n = n + 1 end
  end
  return n
end

function P.Convert()
  local convert = (C_PartyInfo and C_PartyInfo.ConvertToRaid) or ConvertToRaid
  if not convert then return end
  local ok, err = pcall(convert)
  if not ok then P.Refused("the raid", err) end
end

--- The names that wait for the raid, until it exists or P.HOLD_FOR runs out.
function P.Hold(names)
  if P.held then                                  -- more on top of who already waits: same wait
    for _, n in ipairs(names) do P.held.names[#P.held.names + 1] = n end
    NS.Print("party list: %d wait for the raid now", #P.held.names)
    return
  end
  local h = { names = names }
  P.held = h
  NS.Print("party list: %d more wait for the raid - they go out once someone joins (%s)", #names,
    table.concat(names, ", "))
  if C_Timer and C_Timer.After then
    C_Timer.After(P.HOLD_FOR, function()
      if P.held ~= h then return end
      P.held = nil
      NS.Print("party list: nobody joined - %d not invited (%s). Press Invite again.", #names, table.concat(names, ", "))
    end)
  end
end

--- A roster change: the party exists now - make it a raid; the raid exists - send who waited.
function P.Held()
  local h = P.held
  if not h or not P.Grouped() then return end
  if not (IsInRaid and IsInRaid()) then
    if P.Leads() then P.Convert() end
    return
  end
  P.held = nil
  for _, n in ipairs(h.names) do P.queue[#P.queue + 1] = n end
  if not P.timer then P.Pump() end
end

--- Invite these names (none of them with you already): the party list's, or a guild rank's. `quiet`:
--- no inviting show (a whispered keyword, PartyAuto.lua - nobody pressed anything).
function P.InviteNames(db, missing, quiet)
  if #missing == 0 then NS.Print("party list: everyone is already with you") return 0 end
  if not P.Leads() then NS.Print("party list: only the leader (or an assistant) can invite") return 0 end
  local members = P.Members()
  local with = #members + 1 + P.Out(members) + #P.queue      -- in the group, asked, about to be asked
  local now, later = missing, nil
  if not (IsInRaid and IsInRaid()) and with + #missing > P.PARTY then
    if P.Grouped() then P.Convert() end
    now, later = {}, {}
    for i, n in ipairs(missing) do
      if i <= P.PARTY - with then now[#now + 1] = n else later[#later + 1] = n end
    end
  end
  for _, n in ipairs(now) do P.queue[#P.queue + 1] = n end
  if quiet then
    -- said by the caller
  elseif db.show ~= false then P.Show(missing) else
    NS.Print("party list: inviting %d (%s)", #missing, table.concat(missing, ", "))
  end
  if later and #later > 0 then P.Hold(later) end
  if not P.timer then P.Pump() end
  return #missing
end

------------------------------------------------------------- the little show --
-- WATCH THE MACHINE WORK (Arn, 15 Oct: "a little progress bar of it inviting people ... the invites
-- are instant, its just a little flavor of seeing the machine do something" - and then: "not saying
-- stuff in actual chat, saying things on the window"). The SHAPE is the old Counter-Strike loading
-- box (his reference): a title, lines of text scrolling up as the machine talks to each player, a
-- sunken bar filling with chunky blocks, Cancel. The LOOK is ours (Arn: "i like our bis theme -
-- these pictures are just ideas we can do in the bis themes"): BiSTheme's surface, accent edge and
-- purple blocks, at the family's 1.43:1. Pure flavour: the invites have already gone. Nothing goes
-- to chat. OnUpdate only while it shows; Cancel or the end hides it. `db.show = false` skips it.
--- A BUTTON SAYS IT CAN BE CLICKED (Arn, 16 Oct, the confirm list: "these buttons need the hover
--- thing - can't tell if I'm about to be able to click"). A tint on ARTWORK, under the label's
--- OVERLAY, so the words stay sharp (BiS Guild learned the same: a HIGHLIGHT-layer tint draws OVER
--- text and washes it out). Wraps whatever OnEnter/OnLeave the button already has.
P.HOVER = 0.28
function P.Hover(b)
  if b.hover then return b end
  b.hover = NS.Farm.tex(b, "ARTWORK", "accent", P.HOVER)
  b.hover:Hide()
  local enter, leave = b:GetScript("OnEnter"), b:GetScript("OnLeave")
  b:SetScript("OnEnter", function(self, ...) self.hover:Show() if enter then return enter(self, ...) end end)
  b:SetScript("OnLeave", function(self, ...) self.hover:Hide() if leave then return leave(self, ...) end end)
  return b
end

P.BLOCKS, P.LOG_ROWS = 14, 3
P.W, P.H = 300, 210                          -- 1.43:1
P.SHOW_MIN, P.SHOW_PER, P.SHOW_MAX, P.LINGER = 1.4, 0.45, 4.0, 1.2
-- the note under the rule, one per run (Arn's second reference: "This server is VAC-secured.
-- Cheating will result in a permanent ban.")
P.NOTES = {
  "Note: this group is BiS-secured. Standing in fire will result in a permanent wipe.",
  "Note: loot is need before greed. Needing on everything will be remembered.",
  "Note: the tank sets the pace. Pulling for the tank will result in a repair bill.",
  "Note: this group is healer-secured. Not drinking will result in a long wait.",
}
-- each player gets an opening line and a closing one, so the text keeps moving
P.OPEN = {
  "Establishing network connection to %s...",
  "Resolving %s's realm...",
  "Pinging %s... %d ms",
  "Sending invite packet to %s...",
  "Negotiating loot rules with %s...",
  "Asking %s nicely...",
}
P.CLOSE = {
  "Handshake with %s: OK",
  "%s: invite delivered",
  "%s: packet received, 0 lost",
  "%s: connection stable",
}

function P.Line(list, i, name)
  local fmt = list[(i - 1) % #list + 1]
  if fmt:find("%%d") then return fmt:format(name, math.random(3, 60)) end
  return fmt:format(name)
end

--- The whole script of one run: the lines in order, the first one before any player.
function P.Script(names)
  local out = { "Contacting the party list..." }
  for i, n in ipairs(names) do
    n = P.Short(n)                         -- the first name, on screen only: a surname wraps the line
    out[#out + 1] = P.Line(P.OPEN, i + math.random(0, #P.OPEN - 1), n)
    out[#out + 1] = P.Line(P.CLOSE, i + math.random(0, #P.CLOSE - 1), n)
  end
  return out
end

function P.BuildShow()
  if P.box then return P.box end
  local K, T = NS.Farm, NS.T
  local f = CreateFrame("Frame", "BiSToolsPartyLoading", UIParent)
  P.box = f
  f:SetSize(P.W, P.H)
  -- WHERE YOU PUT IT (Arn, 15 Oct: "nice in the middle but would be nice to be able to move it"):
  -- dragged anywhere, kept in the party tool's settings; the middle until then
  local bp = P.db and P.db.boxPos
  if type(bp) == "table" and bp[1] then f:SetPoint(bp[1], UIParent, bp[4] or bp[1], bp[2] or 0, bp[3] or 0)
  else f:SetPoint("CENTER", UIParent, "CENTER", 0, 140) end
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint(1)
    if P.db then P.db.boxPos = { point or "CENTER", x or 0, y or 0, rel or point or "CENTER" } end
  end)
  f:SetFrameStrata("DIALOG")
  K.tex(f, "BACKGROUND", "surface", 0.97)
  f.edge = K.border(f, "accent", 0.8)
  f.title = K.fs(f, T.text("accent", "BiS>") .. " invite", 13, "ink")
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
  local inner = P.W - 24
  -- the working view (bars, log, note); the confirm view (P.BuildConfirm) takes its place
  local rv = CreateFrame("Frame", nil, f)
  rv:SetAllPoints(f)
  f.runView = rv
  local function bar(y, w)
    local b = CreateFrame("Frame", nil, rv)
    b:SetSize(w, 16)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 12, y)
    K.tex(b, "BACKGROUND", "sunken", 1)
    b.blocks = {}
    local step = (w - 6) / P.BLOCKS
    for i = 1, P.BLOCKS do
      local t = b:CreateTexture(nil, "ARTWORK")
      t:SetColorTexture(K.color("accent"))
      t:SetSize(step - 3, 10)
      t:SetPoint("LEFT", b, "LEFT", 3 + (i - 1) * step, 0)
      t:Hide()
      b.blocks[i] = t
    end
    return b
  end
  -- the whole run: what it is doing, and how far
  f.status = K.fs(rv, "", 11, "ink2")
  f.status:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -30)
  f.all = bar(-46, inner)
  f.blocks = f.all.blocks
  -- the player now: the machine talking to them (the newest line at the bottom), time left, a bar
  f.log = {}
  for i = 1, P.LOG_ROWS do
    local l = K.fs(rv, "", 11, i == P.LOG_ROWS and "ink2" or "muted")
    l:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -70 - (i - 1) * 14)
    l:SetWidth(inner)
    l:SetJustifyH("LEFT")
    l:SetWordWrap(false)                     -- one line each, never over the line below
    f.log[i] = l
  end
  f.left = K.fs(rv, "", 11, "muted")
  f.left:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -70 - P.LOG_ROWS * 14)
  f.one = bar(-88 - P.LOG_ROWS * 14, inner - 66)
  local cancel = CreateFrame("Button", nil, rv)
  cancel:SetSize(56, 16)
  cancel:SetPoint("LEFT", f.one, "RIGHT", 10, 0)
  K.tex(cancel, "BACKGROUND", "sunken", 1)
  K.border(cancel, "line2", 1)
  cancel.label = K.fs(cancel, "Cancel", 11, "ink2")
  cancel.label:SetPoint("CENTER", cancel, "CENTER", 0, 0)
  cancel:SetScript("OnClick", function() P.EndShow() end)
  P.Hover(cancel)
  f.cancel = cancel
  f.cancel = cancel
  -- a rule, and the note under it (the reference's "this server is VAC-secured")
  local rule = rv:CreateTexture(nil, "ARTWORK")
  rule:SetColorTexture(T.rgb("line2"))
  rule:SetSize(inner, 1)
  rule:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -114 - P.LOG_ROWS * 14)
  f.note = K.fs(rv, "", 11, "ink2")
  f.note:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -122 - P.LOG_ROWS * 14)
  f.note:SetWidth(inner)
  f.note:SetJustifyH("LEFT")
  P.BuildConfirm(f)
  f:SetScript("OnUpdate", function(_, dt) P.Step(dt) end)
  f:Hide()
  return f
end

------------------------------------------------------------- the confirm view --
-- LOOK BEFORE IT GOES (Arn, 15 Oct: "right now as soon as i click the rank the invites go out
-- instantly ... make it seem like its working, split into classes, and we can remove people that
-- are raiders but arent raiding"). A rank click plays the working view as "preparing" (P.Confirm),
-- then stops here: who would be invited, by class, an x on each; Send, or Cancel and nobody is.
P.CONF_COLS, P.CONF_ROWS, P.CONF_LINE = 3, 8, 14   -- 8: the 9th row sat under the hint line (17 Oct)
P.PREP_LEN = 1.6

function P.BuildConfirm(f)
  local K = NS.Farm
  local cv = CreateFrame("Frame", nil, f)
  cv:SetAllPoints(f)
  f.confirmView = cv
  cv.head = K.fs(cv, "", 11, "ink2")
  -- one line, cut with "..." past the edge (Arn's list, 17 Oct: three parts named ran to the border)
  cv.head:SetWidth(P.W - 24)
  cv.head:SetJustifyH("LEFT")
  cv.head:SetWordWrap(false)
  cv.head:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -30)
  local inner = P.W - 24
  local colW = inner / P.CONF_COLS
  cv.lines = {}
  for i = 1, P.CONF_COLS * P.CONF_ROWS do
    local col, row = math.floor((i - 1) / P.CONF_ROWS), (i - 1) % P.CONF_ROWS
    local l = CreateFrame("Frame", nil, cv)
    l:SetSize(colW - 4, P.CONF_LINE)
    l:SetPoint("TOPLEFT", f, "TOPLEFT", 12 + col * colW, -48 - row * P.CONF_LINE)
    l.text = K.fs(l, "", 10, "ink")
    l.text:SetPoint("LEFT", l, "LEFT", 0, 0)
    l.text:SetWidth(colW - 18)
    l.text:SetJustifyH("LEFT")
    l.text:SetWordWrap(false)
    l.x = CreateFrame("Button", nil, l)
    l.x:SetSize(12, 12)
    l.x:SetPoint("RIGHT", l, "RIGHT", 0, 0)
    l.x.label = K.fs(l.x, "x", 9, "warn")
    l.x.label:SetPoint("CENTER")
    l.x:SetScript("OnClick", function() if l.entry then P.Drop(l.entry) end end)
    -- the line an x would drop, lit while the mouse is on it (Arn: see the right row)
    l.hl = l:CreateTexture(nil, "BACKGROUND")
    l.hl:SetAllPoints(l)
    do local cr, cg, cb = K.color("accent") l.hl:SetColorTexture(cr, cg, cb, 0.18) end
    l.hl:Hide()
    l.x:SetScript("OnEnter", function() l.hl:Show() end)
    l.x:SetScript("OnLeave", function() l.hl:Hide() end)
    l:Hide()
    cv.lines[i] = l
  end
  cv.more = K.fs(cv, "", 9, "dim")
  cv.more:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 32)
  local function btn(label, w, colour, onClick)
    local b = CreateFrame("Button", nil, cv)
    b:SetSize(w, 18)
    K.tex(b, "BACKGROUND", "sunken", 1)
    b.edge = K.border(b, colour, 1)
    b.label = K.fs(b, label, 11, colour)
    b.label:SetPoint("CENTER")
    b:SetScript("OnClick", onClick)
    return P.Hover(b)
  end
  cv.send = btn("Send", 120, "good", function() P.SendPending() end)
  cv.send:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 8)
  cv.cancel = btn("Close", 70, "ink2", function() P.EndShow() end)
  cv.refresh = btn("Refresh", 70, "accent", function()
    local ask = (C_GuildInfo and C_GuildInfo.GuildRoster) or GuildRoster
    if ask then pcall(ask) end                 -- the roster answers with GUILD_ROSTER_UPDATE
    P.RefreshNow()
  end)
  cv.cancel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 8)
  cv.refresh:SetPoint("RIGHT", cv.cancel, "LEFT", -6, 0)
  cv:EnableMouseWheel(true)
  cv:SetScript("OnMouseWheel", function(_, delta)
    P.confOffset = math.max(0, (P.confOffset or 0) - delta * P.CONF_ROWS)
    P.PaintConfirm()
  end)
  cv:Hide()
end

--- A class's colour, or the family's ink.
local function classColour(file)
  local c = file and RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
  if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
  return NS.Farm.color("ink")
end

--- The lines: a heading per class (most first), then its players.
function P.ConfirmLines()
  local by, order = {}, {}
  for _, e in ipairs(P.pending or {}) do
    local k = e.classFile or e.class or "?"
    if not by[k] then by[k] = { file = e.classFile, class = e.class or k, list = {} } order[#order + 1] = by[k] end
    table.insert(by[k].list, e)
  end
  table.sort(order, function(a, b)
    if #a.list ~= #b.list then return #a.list > #b.list end
    return tostring(a.class) < tostring(b.class)
  end)
  local out = {}
  for _, g in ipairs(order) do
    out[#out + 1] = { head = true, text = ("%s (%d)"):format(g.class, #g.list), file = g.file }
    table.sort(g.list, function(a, b) return a.name < b.name end)
    for _, e in ipairs(g.list) do out[#out + 1] = { entry = e, text = P.Short(e.name), file = g.file } end
  end
  -- IN WAVES (Arn, 15 Oct: "the raid leader sends out invites in waves, so once someone is in the
  -- raid or party it should have another column of already in the raid"): last, dimmed, no x
  local here = P.pendingHere or {}
  if #here > 0 then
    out[#out + 1] = { head = true, here = true, text = ("Already with you (%d)"):format(#here) }
    local sorted = {}
    for _, e in ipairs(here) do sorted[#sorted + 1] = e end
    table.sort(sorted, function(a, b) return a.name < b.name end)
    for _, e in ipairs(sorted) do out[#out + 1] = { here = true, text = P.Short(e.name) } end
  end
  -- OFFLINE (17 Oct, the party list's check): last, dimmed, no x - the invite would only bounce
  local off = P.pendingOff or {}
  if #off > 0 then
    out[#out + 1] = { head = true, here = true, text = ("Offline (%d)"):format(#off) }
    local sorted = {}
    for _, e in ipairs(off) do sorted[#sorted + 1] = e end
    table.sort(sorted, function(a, b) return a.name < b.name end)
    for _, e in ipairs(sorted) do out[#out + 1] = { here = true, text = P.Short(e.name) } end
  end
  return out
end

function P.PaintConfirm()
  local f = P.box
  local cv = f and f.confirmView
  if not (cv and cv:IsShown()) then return end
  local lines, n = P.ConfirmLines(), #(P.pending or {})
  local fit = #cv.lines
  P.confOffset = math.min(P.confOffset or 0, math.max(0, #lines - fit))
  for i, l in ipairs(cv.lines) do
    local d = lines[i + P.confOffset]
    l.entry = d and d.entry
    if d then
      l.text:SetText(d.text)
      if d.here then l.text:SetTextColor(NS.Farm.color("dim")) else l.text:SetTextColor(classColour(d.file)) end
      if d.head or d.here then l.x:Hide() else l.x:Show() end
      l:Show()
    else
      l:Hide()
    end
  end
  if P.note and (GetTime and GetTime() or 0) < (P.noteUntil or 0) then
    cv.head:SetText(P.note)                         -- what the last Refresh changed (P.RefreshNow)
    cv.head:SetTextColor(NS.Farm.color("good"))
  else
    cv.head:SetText(("%d to invite: %s"):format(n, P.pendingLabel or "invites"))
    cv.head:SetTextColor(NS.Farm.color("ink2"))
  end
  local below = #lines - fit - P.confOffset
  cv.more:SetText(below > 0 and ("+%d more lines - scroll"):format(below) or (n > 0 and "x leaves someone out" or ""))
  cv.send.label:SetText(n > 0 and ("Send %d invite%s"):format(n, n == 1 and "" or "s") or "Nobody left")
end

--- One off the list (they are not raiding tonight).
function P.Drop(entry)
  if P.wave and entry and entry.name then P.wave.dropped[P.Key(entry.name) or "?"] = true end
  for i, e in ipairs(P.pending or {}) do
    if e == entry then table.remove(P.pending, i) break end
  end
  P.PaintConfirm()
end

function P.ShowConfirm()
  local f = P.BuildShow()
  f.runView:Hide()
  f.confirmView:Show()
  P.confOffset = 0
  f:Show()
  P.PaintConfirm()
end

--- Prepare, then confirm: the working view reads the roster, then the list waits for Send.
function P.Confirm(db, label, entries, inGroup, offline)
  if #entries == 0 then NS.Print("party list: everyone %s is already with you", label) return 0 end
  P.pendingHere, P.pendingOff = inGroup or {}, offline or {}
  P.pending, P.pendingLabel, P.pendingDb = entries, label, db
  if db.show == false then P.ShowConfirm() return #entries end
  local f = P.BuildShow()
  local counts, classes = {}, {}
  for _, e in ipairs(entries) do
    local c = e.class or "?"
    if not counts[c] then counts[c] = 0 classes[#classes + 1] = c end
    counts[c] = counts[c] + 1
  end
  local parts = {}
  for _, c in ipairs(classes) do parts[#parts + 1] = ("%d %s"):format(counts[c], c) end
  P.Show({})
  P.pending, P.pendingLabel, P.pendingDb = entries, label, db
  local script = { "Reading the guild roster...",
                   ("Found %d %s online"):format(#entries, label),
                   "Sorting by class: " .. table.concat(parts, ", "),
                   "Checking who is already with you..." }
  if offline and #offline > 0 then script[#script + 1] = ("%d offline - left out"):format(#offline) end
  script[#script + 1] = "Ready. Look it over."
  P.run = { prep = true, names = entries, t = 0, said = 0, len = P.PREP_LEN, script = script }
  f.status:SetText(("Preparing invites: %s..."):format(label))
  P.Step(0)
  return #entries
end

--- WHO IS ON, AS FAR AS THE CLIENT WILL SAY (Arn, 17 Oct: the party window's invite "sending the
--- invite right away ... i think we need to add the second screen of it doing the check to make sure
--- they are online"). Your guild roster, everyone in it, and your friends list: key -> { online,
--- class, classFile }. Somebody in neither is unknown - nil - and is invited on trust.
function P.Lookup()
  local out = {}
  if IsInGuild and IsInGuild() then
    local okN, n = pcall(GetNumGuildMembers)
    n = okN and plain(n) or 0
    for i = 1, (type(n) == "number" and n or 0) do
      local ok, name, _, _, _, class, _, _, _, online, _, classFile = pcall(GetGuildRosterInfo, i)
      name = ok and plain(name) or nil
      if type(name) == "string" then
        class, classFile, online = plain(class), plain(classFile), plain(online)
        out[P.Key(name) or "?"] = { online = online and true or false,
                                    class = type(class) == "string" and class or nil,
                                    classFile = type(classFile) == "string" and classFile or nil }
      end
    end
  end
  local FL = C_FriendList
  if FL and FL.GetNumFriends and FL.GetFriendInfoByIndex then
    local okN, n = pcall(FL.GetNumFriends)
    n = okN and plain(n) or 0
    for i = 1, (type(n) == "number" and n or 0) do
      local ok, f = pcall(FL.GetFriendInfoByIndex, i)
      local name = ok and type(f) == "table" and plain(f.name) or nil
      if type(name) == "string" and not out[P.Key(name) or "?"] then
        local class = plain(f.className)
        class = type(class) == "string" and class or nil
        -- a friend comes with the class's NAME only ("Mage"); the client's own table gives its file
        local file
        for _, t in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
          for k, v in pairs(t) do if v == class then file = k end end
        end
        out[P.Key(name) or "?"] = { online = plain(f.connected) and true or false, class = class, classFile = file }
      end
    end
  end
  return out
end

--- The party list, checked: its missing names to invite (by class where known), those offline,
--- and those on it who are with you already.
function P.PartyEntries(db)
  local who, entries, offline, with = P.Lookup(), {}, {}, {}
  for _, n in ipairs(P.Missing(db)) do
    local w = who[P.Key(n) or "?"]
    if w and w.online == false then
      offline[#offline + 1] = { name = n }
    else
      entries[#entries + 1] = { name = n, class = (w and w.class) or "Unknown", classFile = w and w.classFile }
    end
  end
  local here = {}
  for _, m in ipairs(P.Members()) do here[m.key] = true end
  for _, n in ipairs(P.List(db)) do if here[P.Key(n) or "?"] then with[#with + 1] = { name = n } end end
  return entries, offline, with
end

--- THE OPEN LIST IS ONE LIST (Arn, 17 Oct, the party list open and a rank invited from the guild
--- view: "add to it"). A wave holds what it was built from - your party list, any ranks - and is
--- rebuilt from all of it: nobody twice, the x'd kept out, the header naming every part.
function P.WaveList(w)
  local entries, inGroup, offline, seen = {}, {}, {}, {}
  local function add(list, e)
    local k = P.Key(e.name) or "?"
    if not seen[k] then seen[k] = true list[#list + 1] = e end
  end
  local parts = {}
  if w.party then
    local e, off, with = P.PartyEntries(w.db)
    for _, x in ipairs(with) do add(inGroup, x) end
    for _, x in ipairs(e) do add(entries, x) end
    for _, x in ipairs(off) do add(offline, x) end
    parts[#parts + 1] = "your party list"
  end
  if w.ranks and next(w.ranks) then
    local e, g, found, label = P.RankPeople(w.ranks)
    for _, x in ipairs(g) do add(inGroup, x) end
    for _, x in ipairs(e) do add(entries, x) end
    if found then parts[#parts + 1] = label end
  end
  return P.WithoutDropped(entries), inGroup, offline, #parts > 0 and table.concat(parts, " + ") or "invites"
end

--- Is a list open that more can be added to? The box up, with a wave in it.
function P.WaveOpen()
  return P.wave ~= nil and P.box ~= nil and P.box:IsShown() and true or false
end

--- Add to the open list: `grow(w)` changes what it holds; the list is rebuilt and says what came in.
function P.AddToWave(grow, what)
  local before = {}
  for _, e in ipairs(P.pending or {}) do before[P.Key(e.name) or "?"] = true end
  grow(P.wave)
  P.Regenerate()
  local new = 0
  for _, e in ipairs(P.pending or {}) do if not before[P.Key(e.name) or "?"] then new = new + 1 end end
  P.note = ("added %s: %s"):format(what, new > 0 and ("%d new"):format(new) or "nobody new")
  P.noteUntil = (GetTime and GetTime() or 0) + P.NOTE_FOR
  local cv = P.box and P.box.confirmView
  if cv and cv:IsShown() then
    P.PaintConfirm()
    P.Sweep()
    if C_Timer and C_Timer.After then C_Timer.After(P.NOTE_FOR + 0.05, function() P.PaintConfirm() end) end
  end
  return new
end

--- Start a list (or add to the open one): prepare, then wait for Send.
function P.StartWave(db, grow, what)
  if P.WaveOpen() then return P.AddToWave(grow, what) end
  P.wave = { db = db, dropped = {} }
  grow(P.wave)
  local entries, inGroup, offline, label = P.WaveList(P.wave)
  if #entries == 0 then
    P.wave = nil
    if #offline > 0 then
      local t = {}
      for _, e in ipairs(offline) do t[#t + 1] = e.name end
      NS.Print("party list: nobody missing is online (%d offline: %s)", #offline, table.concat(t, ", "))
    else
      NS.Print("party list: everyone in %s is already with you", what)
    end
    return 0
  end
  return P.Confirm(db, label, entries, inGroup, offline)
end

--- THE TOOLS-BOX BUTTON CONFIRMS TOO (Arn, 15 Oct: in open-world PvP, a stray click on it would
--- invite in the heat of battle): the party list's missing names, on the confirm list first. And
--- since 17 Oct the party window's invite button the same way, checked for who is online.
function P.ConfirmList(db)
  return P.StartWave(db, function(w) w.party = true end, "your party list")
end

--- Send: the names left go out, and the box plays the invites as usual.
function P.SendPending()
  local db, names = P.pendingDb or P.db, {}
  for _, e in ipairs(P.pending or {}) do names[#names + 1] = e.name end
  P.pending = nil
  if #names == 0 then
    if P.wave then P.Regenerate() else P.EndShow() end     -- a wave stays open with nobody to send
    return 0
  end
  local n = P.InviteNames(db, names)
  if db.show == false then P.EndShow() end
  return n
end

--- One more line at the bottom of the log; the rest move up one.
function P.Say(line)
  local f = P.box
  local shown = P.shown or {}
  shown[#shown + 1] = line
  while #shown > P.LOG_ROWS do table.remove(shown, 1) end
  P.shown = shown
  for i = 1, P.LOG_ROWS do f.log[i]:SetText(shown[i - (P.LOG_ROWS - #shown)] or "") end
end

--- Start it: the script spread over the run, the bar filling with the clock.
function P.Show(names)
  local f = P.BuildShow()
  f.runView:Show()
  f.confirmView:Hide()
  local script = P.Script(names)
  P.run = { names = names, script = script, t = 0, said = 0,
            len = math.min(P.SHOW_MAX, P.SHOW_MIN + P.SHOW_PER * #names) }
  P.shown, P.failed, P.saidError = {}, 0, nil
  for _, b in ipairs(f.all.blocks) do b:Hide() end
  for _, b in ipairs(f.one.blocks) do b:Hide() end
  for _, l in ipairs(f.log) do l:SetText("") end
  f.status:SetText(("Inviting your party list: %d player%s..."):format(#names, #names == 1 and "" or "s"))
  f.note:SetText(P.NOTES[math.random(1, #P.NOTES)])
  f:Show()
  P.Step(0)
end

function P.Step(dt)
  local run, f = P.run, P.box
  if not (run and f) then return end
  run.t = run.t + (dt or 0)
  if run.done then
    if run.t >= run.len + P.LINGER then
      if P.wave then
        P.run = nil
        P.ShowConfirm()
        P.Regenerate()
      else
        P.EndShow()
      end
    end
    return
  end
  local frac = math.min(1, run.t / run.len)
  local function fill(bar, x)
    local lit = math.floor(x * P.BLOCKS + 0.5)
    for i, b in ipairs(bar.blocks) do if i <= lit then b:Show() else b:Hide() end end
  end
  fill(f.all, frac)
  -- the player now: their share of the run, and the seconds left of the whole
  local n = math.max(1, #run.names)
  local seg = run.len / n
  fill(f.one, frac >= 1 and 1 or ((run.t % seg) / seg))
  local left = math.ceil(run.len - run.t)
  f.left:SetText(left > 0 and ("%d second%s remaining"):format(left, left == 1 and "" or "s") or "")
  local due = math.min(#run.script, 1 + math.floor(frac * (#run.script - 1) + 0.0001))
  while run.said < due do
    run.said = run.said + 1
    P.Say(run.script[run.said])
  end
  if frac >= 1 and run.prep then
    P.run = nil
    P.ShowConfirm()
    return
  end
  if frac >= 1 then
    run.done = true
    local n = #run.names
    local ok = n - (P.failed or 0)
    if (P.failed or 0) > 0 then
      P.Say(("Done. %d of %d invited."):format(ok, n))
    else
      P.Say(("Done. %d invite%s sent."):format(n, n == 1 and "" or "s"))
    end
    f.status:SetText("Inviting your party list: done.")
  end
end

-- WHAT THE GAME SAYS BACK (Arn, 15 Oct: "he is in a group, should also throw an error on here").
-- The invite's real answer comes as a system message; while the box is up, a failure lands in its
-- log in the warning colour, and the last line counts it. The game's own format strings, so the
-- client's language is the one matched.
P.REPLIES = {
  { "ERR_ALREADY_IN_GROUP_S", "%s is already in a group", true },
  { "ERR_BAD_PLAYER_NAME_S", "can't find %s (offline?)", true },
  { "ERR_INVITE_PLAYER_S", "%s: invite received", false },
  { "ERR_DECLINE_GROUP_S", "%s declined", true },              -- "Darthsidiouz Sithlord declines your group invitation."
}
local function pattern(fmt)
  if type(fmt) ~= "string" then return nil end
  local p = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)")
  return "^" .. p .. "$"
end
function P.Heard(msg)
  if not P.run or type(msg) ~= "string" or (issecretvalue and issecretvalue(msg)) then return false end
  for _, r in ipairs(P.REPLIES) do
    local pat = pattern(_G[r[1]])
    local who = pat and msg:match(pat)
    if who then
      who = P.Short(who)
      if r[3] then
        P.failed = (P.failed or 0) + 1
        P.Say(NS.T.text("warn", r[2]:format(who)))
      else
        P.Say(r[2]:format(who))
      end
      return true
    end
  end
  return false
end
do
  local heard = CreateFrame("Frame")
  heard:RegisterEvent("CHAT_MSG_SYSTEM")
  -- a protected call refused shows up as these, not as a Lua error
  heard:RegisterEvent("ADDON_ACTION_BLOCKED")
  heard:RegisterEvent("ADDON_ACTION_FORBIDDEN")
  heard:SetScript("OnEvent", function(_, event, msg, fn)
    if event == "CHAT_MSG_SYSTEM" then
      if P.run then P.Heard(msg) end
    elseif msg == ADDON and type(fn) == "string" and fn:lower():find("invite", 1, true) then
      P.Refused("", ("%s: %s is protected on this client"):format(event == "ADDON_ACTION_FORBIDDEN" and "forbidden" or "blocked", fn))
    end
  end)
  P.heard = heard
end

function P.EndShow()
  P.run, P.pending, P.wave = nil, nil, nil
  if P.box then P.box:Hide() end
end

--- Leading: everyone out. Otherwise: you leave.
function P.Disband()
  if not P.Grouped() then return false end
  local lead = UnitIsGroupLeader and plain(UnitIsGroupLeader("player"))
  if lead == true then
    local uninvite = (C_PartyInfo and C_PartyInfo.UninviteUnit) or UninviteUnit
    for _, m in ipairs(P.Members()) do if uninvite then pcall(uninvite, m.name) end end
    NS.Print("party list: group disbanded")
  else
    local leave = (C_PartyInfo and C_PartyInfo.LeaveParty) or LeaveParty
    if leave then pcall(leave) end
    NS.Print("party list: you left the group")
  end
  return true
end

--- The buttons' disband: shift-click only (Arn, 17 Oct: "shift click for this one too, might leave
--- by mistake"), like the invite button. A plain click only says how. The slash word stays as it is.
function P.ShiftDisband()
  if IsShiftKeyDown and IsShiftKeyDown() then return P.Disband() end
  NS.Print("party list: shift-click to disband or leave")
  return false
end

------------------------------------------------------------- the box buttons --

--- When the buttons mean something: solo with a list, or grouped with someone on it.
function P.ShowInvite(db, members)
  if not (db and R:Enabled("party")) or #P.List(db) == 0 then return false end
  -- never in a battleground or arena (Arn, 15 Oct: "a little risky in bg and open world pvp - in the
  -- heat of battle might accidentally send out invites")
  local RC = NS.Recap
  if RC and RC.InPvP and RC.InPvP() then return false end
  members = members or P.Members()
  if P.Grouped() and not P.WithListed(db, members) then return false end
  return P.Leads() and #P.Missing(db, members) > 0
end
function P.ShowDisband(db, members)
  if not (db and R:Enabled("party") and P.Grouped()) then return false end
  return P.WithListed(db, members) and true or false
end

local function button(name, icon, tip, sub, onClick)
  local K = NS.Farm
  local b = CreateFrame("Button", name, UIParent)
  b:SetSize(26, 26)
  b:SetFrameStrata("MEDIUM")
  b:RegisterForClicks("LeftButtonUp")
  K.tex(b, "BACKGROUND", "field", 0.95)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2) b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon:SetTexture(icon)
  b.edge = K.border(b, "accent", 1)
  b.boxed = true
  b:SetScript("OnClick", onClick)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(tip)
    GameTooltip:AddLine(type(sub) == "function" and sub() or sub, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  b:Hide()
  return b
end

P.GREEN, P.RED = { 0.35, 0.85, 0.45 }, { 0.90, 0.30, 0.30 }

function P.Buttons()
  if P.ibtn then return P.ibtn, P.dbtn end
  P.ibtn = button("BiSToolsPartyInvite", "Interface\\Icons\\INV_Letter_15", "Invite your party list",
    function() return "Shift-click to open your party list. " .. table.concat(P.Missing(P.db or {}), ", ") end,
    -- SHIFT-CLICK ONLY (Arn, 15 Oct: "shift click, i dont think any other button in bis now or bis
    -- tools use shift clicks so no mistakes"): a plain click in a fight does nothing but remind.
    -- It OPENS THE PARTY WINDOW (Arn: "shift left click should open this window") - invite, or a
    -- guild rank, from there.
    function()
      if IsShiftKeyDown and IsShiftKeyDown() then P.Toggle(P.db, true)
      else NS.Print("party list: shift-click the invite button to open your party list") end
    end)
  P.dbtn = button("BiSToolsPartyDisband", "Interface\\Icons\\Ability_Rogue_Sprint", "Disband",
    function()
      local lead = UnitIsGroupLeader and plain(UnitIsGroupLeader("player"))
      return "Shift-click: " .. (lead == true and "everyone out of the group." or "you leave the group (you are not the leader).")
    end,
    function() P.ShiftDisband() end)
  return P.ibtn, P.dbtn
end

------------------------------------------------------------- the window --
-- THE LIST, WHERE YOU CAN SEE IT (Arn, 15 Oct: "i dont see the party frame when i click the button
-- on the list" - the tools list opens a tool's window, and this tool had none). The farm window's
-- frame and header (the BiS> prompt, x to close), at the family's 1.43:1: the names in two columns
-- (green = with you now, x = off the list), a box to add one, and the four things you do with it.
P.WIN_W, P.WIN_H = 300, 210                  -- 1.43:1: five buttons, and rank names of any length
P.WIN_SCALE = 1.2
P.ROWS, P.ROW_H, P.HEADER = 9, 14, 16

local function button(parent, label, w, colour, onClick, tip)
  local F = NS.Farm
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, 16)
  F.tex(b, "BACKGROUND", "field", 0.95)
  b.edge = F.border(b, colour or "edge", 1)
  b.label = F.fs(b, label, 9, colour or "ink")
  b.label:SetPoint("CENTER")
  b:SetScript("OnClick", onClick)
  b:SetScript("OnEnter", function(self)
    b.edge:set("accent", 1)
    if GameTooltip and tip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(label)
      GameTooltip:AddLine(tip, 1, 1, 1, true)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function() b.edge:set(colour or "edge", 1) if GameTooltip then GameTooltip:Hide() end end)
  return P.Hover(b)                      -- the edge alone was too faint to see (Arn, 16 Oct)
end

function P.BuildWindow(db)
  if P.win then return P.win end
  local F = NS.Farm
  local f = CreateFrame("Frame", "BiSToolsParty", UIParent)
  P.win = f
  f:SetSize(P.WIN_W, P.WIN_H)
  f:SetScale(P.WIN_SCALE)                    -- Arn, 15 Oct: "20% bigger, same aspect ratio" - all of it grows
  f:SetFrameStrata("MEDIUM")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint(1)
    db.pos = { point or "CENTER", x or 0, y or 0, rel or point or "CENTER" }
  end)
  F.tex(f, "BACKGROUND", "frame", F.BODY_A)
  F.border(f, "edge", 0.35)
  local head = CreateFrame("Frame", nil, f)
  head:SetPoint("TOPLEFT") head:SetPoint("TOPRIGHT")
  head:SetHeight(P.HEADER)
  F.tex(head, "BACKGROUND", "header", F.HEAD_A)
  f.title = F.fs(head, "", 8, "ink")
  f.title:SetPoint("LEFT", head, "LEFT", 4, 0)
  f.con = BiSTheme.Console(f.title, { width = P.WIN_W - 17 - 8 })
  f.con:Set("name", "Party", "accent")
  local acc = 0
  f:SetScript("OnUpdate", function(_, dt)          -- the prompt's cursor; only while shown
    acc = acc + (dt or 0)
    if acc >= 0.1 then acc = 0 f.con:Paint() end
  end)
  f.closeBtn = F.HeaderButton(head, -3, "x", "Close", "/bist party reopens it.", function() f:Hide() end, "warn")
  -- WHOLE RANKS (Arn, 15 Oct: "the guild feature will be invite all raiders button etc"): g shows
  -- the guild's ranks with someone online; a click invites that whole rank. Single guildmates go on
  -- the list from the guild window's own right-click (P.GUILD_MENUS, behind its switch).

  -- the names: two columns of P.ROWS
  f.rows = {}
  local colW = (P.WIN_W - 12) / 2
  for i = 1, P.ROWS * 2 do
    local col, row = math.floor((i - 1) / P.ROWS), (i - 1) % P.ROWS
    local r = CreateFrame("Frame", nil, f)
    r:SetSize(colW - 4, P.ROW_H)
    r:SetPoint("TOPLEFT", f, "TOPLEFT", 6 + col * colW, -(P.HEADER + 4) - row * P.ROW_H)
    r.name = F.fs(r, "", 9, "ink")
    r.name:SetPoint("LEFT", r, "LEFT", 2, 0)
    r.x = CreateFrame("Button", nil, r)
    r.x:SetSize(12, 12)
    r.x:SetPoint("RIGHT", r, "RIGHT", -2, 0)
    r.x.label = F.fs(r.x, "x", 8, "warn")
    r.x.label:SetPoint("CENTER")
    r.x:SetScript("OnClick", function() if r.who then P.Remove(db, r.who) P.Changed() end end)
    -- in the guild view the whole row is the button: on the list, or off it
    r.pick = CreateFrame("Button", nil, r)
    r.pick:SetAllPoints(r)
    r.pick:SetScript("OnClick", function()
      -- a rank click PICKS it (Arn, 17 Oct: several ranks on a raid night); invite sends the picked
      if r.rank then
        if not r.empty then
          local k = r.rank:lower()
          P.picked = P.picked or {}
          P.picked[k] = (not P.picked[k]) or nil
          P.PaintWindow()
        end
        return
      end
      if not r.who then return end
      if P.Has(db, r.who) then P.Remove(db, r.who) else P.Add(db, r.who) end
      P.Changed()
    end)
    r.pick:Hide()
    -- WHICH ROW YOU ARE ON (Arn, 15 Oct: "that bis now window functionality that highlights, so we
    -- can see we are selecting the correct row"): a soft accent bar under the mouse - a rank you
    -- can click, or the name an x would take off. A dimmed rank does not light up.
    r.hl = r:CreateTexture(nil, "BACKGROUND")
    r.hl:SetAllPoints(r)
    do local cr, cg, cb = F.color("accent") r.hl:SetColorTexture(cr, cg, cb, 0.18) end
    r.hl:Hide()
    -- WITH YOU NOW: a faint green bar, since the name's own colour is its class (17 Oct)
    r.here = r:CreateTexture(nil, "BACKGROUND", nil, -1)
    r.here:SetAllPoints(r)
    do local cr, cg, cb = F.color("good") r.here:SetColorTexture(cr, cg, cb, 0.16) end
    r.here:Hide()
    local function lit(on) if on and not r.empty then r.hl:Show() else r.hl:Hide() end end
    r.pick:SetScript("OnEnter", function() lit(true) end)
    r.pick:SetScript("OnLeave", function() lit(false) end)
    r.x:SetScript("OnEnter", function() lit(true) end)
    r.x:SetScript("OnLeave", function() lit(false) end)
    -- the name under the mouse: when and where you last grouped (17 Oct)
    if r.EnableMouse then r:EnableMouse(true) end
    r:SetScript("OnEnter", function(self)
      if not (GameTooltip and self.last and self.who) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.who)
      local when = date and date("%d %b %H:%M", self.last.t) or tostring(self.last.t)
      GameTooltip:AddLine(("Last grouped %s ago - %s%s"):format(P.Ago(self.last.t) or "?", when,
        self.last.zone and (", " .. self.last.zone) or ""), 1, 1, 1, true)
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    r:Hide()
    f.rows[i] = r
  end
  f.more = F.fs(f, "", 8, "dim")
  f.more:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -(P.HEADER + 4) - P.ROWS * P.ROW_H)
  -- add a name
  local well = CreateFrame("Frame", nil, f)
  well:SetSize(P.WIN_W - 12, 16)
  well:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 6, 26)
  F.tex(well, "BACKGROUND", "field", 0.9)
  well.edge = F.border(well, "edge", 1)
  local eb = CreateFrame("EditBox", "BiSToolsPartyAdd", well)
  eb:SetAllPoints()
  eb:SetTextInsets(4, 4, 0, 0)
  eb:SetFont(STANDARD_TEXT_FONT, 9, "")
  eb:SetAutoFocus(false)
  eb:SetMaxLetters(48)
  local ph = F.fs(well, "add a name, Enter...", 9, "dim")
  ph:SetPoint("LEFT", 4, 0)
  eb:SetScript("OnEditFocusGained", function() ph:Hide() well.edge:set("accent", 1) end)
  eb:SetScript("OnEditFocusLost", function(self)
    well.edge:set("edge", 1)
    if (self:GetText() or "") == "" then ph:Show() end
  end)
  eb:SetScript("OnEnterPressed", function(self)
    local name = (self:GetText() or ""):match("^%s*(.-)%s*$")
    local ok, why = P.Add(db, name)
    if not ok and name ~= "" then NS.Print("party list: %s", tostring(why)) end
    self:SetText("")
    self:ClearFocus()
    P.Changed()
  end)
  eb:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
  f.add = eb
  -- what you do with the list
  -- along the bottom (Arn, 15 Oct: "from this window a button that shows all the guild ranks, i click
  -- the ranks and it sends out invites"): ranks swaps the names for the guild's ranks.
  -- NO CLEAR BUTTON (Arn, 17 Oct: "the clear button is too unforgiving ... i clicked it thinking it
  -- was going to just send me to the default start window and it deleted everyone"). The x on each
  -- name stays; emptying the whole list is `/bist party clear` or the options' button, words you mean.
  local acts = {
    { "save", "good", function() P.SaveGroup(db) P.Changed() end, "Save group: everyone you're grouped with now becomes the list." },
    -- the confirm list first (Arn, 17 Oct: "this button is sending the invite right away"): who is
    -- online, an x on each, then Send
    -- in the guild view it invites the picked ranks the same way
    { "invite", "good", function()
        if P.view == "guild" then
          -- nothing ticked: say so HERE, in the window (Arn, 17 Oct: "i click invite nothing happens")
          if not (P.picked and next(P.picked)) then
            P.nudgeUntil = (GetTime and GetTime() or 0) + 3
            P.PaintWindow()
            if C_Timer and C_Timer.After then C_Timer.After(3.05, function() P.PaintWindow() end) end
            return
          end
          P.InviteRanks(db, P.picked)
        else P.ConfirmList(db) end
      end,
      "Your list (or, in the guild view, the ranks you picked): check who is online, x anyone you don't want this time, then Send." },
    { "guild", "accent", function() P.view = (P.view == "guild") and "list" or "guild" P.PaintWindow() end,
      "Your guild's ranks: tick the ones you want, then invite. 'party' takes you back to your list." },
    { "friends", "accent", function() P.view = (P.view == "friends") and "list" or "friends" P.PaintWindow() end,
      "Your friends online (and Battle.net friends in this game): click one to put them on the list, again to take them off. 'party' takes you back." },
    { "disband", "warn", function() P.ShiftDisband() end, "Shift-click. Leading: everyone out. Otherwise: you leave." },
  }
  local bw = (P.WIN_W - 12 - 3 * (#acts - 1)) / #acts
  f.buttons = {}
  for i, a in ipairs(acts) do
    local b = button(f, a[1], bw, a[2], a[3], a[4])
    b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 6 + (i - 1) * (bw + 3), 6)
    f.buttons[a[1]] = b
  end
  f.guildBtn, f.friendsBtn = f.buttons.guild, f.buttons.friends
  f:Hide()
  return f
end

--- YOUR FRIENDS ONLINE, to pick from (Arn, 20 Oct, once the Friends list's right-click line had to go: "bummer
--- because it was an easy way to add a friend" - he picked a picker in our own window). Character friends
--- who are on, and Battle.net friends playing WoW on your side, by the character they're on: { name,
--- classFile }, by name. Only READS the friends list (as P.Lookup does) - Blizzard's list is never touched.
function P.FriendsOnline()
  local out, seen = {}, {}
  local function add(name, classFile)
    name = type(name) == "string" and name:gsub("%-.*$", "") or nil
    local k = name and P.Key(name)
    if not k or seen[k] or k == P.Key(UnitName("player")) then return end
    seen[k] = true
    out[#out + 1] = { name = name, classFile = classFile }
  end
  local function fileOf(className)
    for _, t in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
      for k, v in pairs(t) do if v == className then return k end end
    end
  end
  local FL = C_FriendList
  if FL and FL.GetNumFriends and FL.GetFriendInfoByIndex then
    local okN, n = pcall(FL.GetNumFriends)
    n = okN and plain(n) or 0
    for i = 1, (type(n) == "number" and n or 0) do
      local ok, f = pcall(FL.GetFriendInfoByIndex, i)
      if ok and type(f) == "table" and plain(f.connected) then add(plain(f.name), fileOf(plain(f.className))) end
    end
  end
  local BN = C_BattleNet
  if BNGetNumFriends and BN and BN.GetFriendAccountInfo then
    local okN, n = pcall(BNGetNumFriends)
    n = okN and plain(n) or 0
    local okM, mine = pcall(UnitFactionGroup, "player")
    mine = okM and plain(mine) or nil
    for i = 1, (type(n) == "number" and n or 0) do
      local ok, a = pcall(BN.GetFriendAccountInfo, i)
      local g = ok and type(a) == "table" and plain(a.gameAccountInfo) or nil
      if type(g) == "table" and plain(g.isOnline) and plain(g.clientProgram) == (BNET_CLIENT_WOW or "WoW") then
        local side = plain(g.factionName)
        if not (mine and type(side) == "string" and side ~= mine) then        -- the other side can't be invited
          add(plain(g.characterName), fileOf(plain(g.className)))
        end
      end
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

--- Your guildmates online now, not you: { name (no realm), rank, rankIndex }, by name.
function P.GuildOnline()
  local out = {}
  if not (IsInGuild and IsInGuild()) then return out end
  local okN, n = pcall(GetNumGuildMembers)
  n = okN and plain(n) or 0
  local me = P.Key(UnitName("player"))
  for i = 1, (type(n) == "number" and n or 0) do
    local ok, name, rank, rankIndex, _, class, _, _, _, online, _, classFile = pcall(GetGuildRosterInfo, i)
    if not ok then name = nil end
    class = plain(class)
    classFile = plain(classFile)
    name = plain(name)
    rank = plain(rank)
    rankIndex = plain(rankIndex)
    online = plain(online)
    if type(name) == "string" and online and P.Key(name) ~= me then
      out[#out + 1] = { name = (name:gsub("%-.*$", "")), rank = type(rank) == "string" and rank or nil,
                        rankIndex = tonumber(rankIndex) or 99,
                        class = type(class) == "string" and class or nil,
                        classFile = type(classFile) == "string" and classFile or nil }
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

--- WHOLE RANKS (Arn, 15 Oct: "invite all rank <raider> and it invites anyone that has raider
--- rank"): the ranks with someone online, highest first, and how many.
function P.Ranks(online)
  local by, out = {}, {}
  -- EVERY RANK, even with nobody else online (Arn, 15 Oct: "im an officer and it does not show that
  -- rank" - he was the only Officer on, and you are never counted): the guild's own ladder first
  local okN, nr = pcall(function() return GuildControlGetNumRanks and GuildControlGetNumRanks() end)
  nr = okN and plain(nr) or 0
  for i = 1, (type(nr) == "number" and nr or 0) do
    local okR, name = pcall(GuildControlGetRankName, i)
    name = okR and plain(name)
    if type(name) == "string" and name ~= "" and not by[name] then
      by[name] = { rank = name, index = i - 1, n = 0 }      -- the roster's rankIndex starts at 0
      out[#out + 1] = by[name]
    end
  end
  for _, m in ipairs(online or P.GuildOnline()) do
    if m.rank then
      local r = by[m.rank]
      if not r then r = { rank = m.rank, index = m.rankIndex, n = 0 } by[m.rank] = r out[#out + 1] = r end
      r.n = r.n + 1
    end
  end
  table.sort(out, function(a, b) return a.index < b.index end)
  return out
end

--- Everyone online with that rank (any case), not with you: invited, the show and all.
function P.InviteRank(db, rank)
  rank = (rank or ""):lower()
  -- a number is the rank's place in the list "/bist party rank" prints (Arn typed "rank 1")
  local nth = tonumber(rank)
  if nth then
    local r = P.Ranks()[nth]
    if not r then NS.Print("party list: no rank number %d online (/bist party rank lists them)", nth) return 0 end
    rank = r.rank:lower()
  end
  return P.InviteRanks(db, { [rank] = true })
end

--- SEVERAL RANKS AT ONCE (Arn, 17 Oct: "maybe we can select mutiple ranks raid night gm rank
--- selected officer and raiders"): `ranks` is a set of lower-case rank names. One wave, one list.
function P.InviteRanks(db, ranks)
  local keys, own = {}, {}
  for r in pairs(ranks or {}) do keys[#keys + 1] = r own[r] = true end   -- a copy: the window's picks move on
  ranks = own
  table.sort(keys)
  if #keys == 0 then NS.Print("party list: pick a rank first") return 0 end
  local entries, inGroup, found, label = P.RankPeople(ranks)
  if not found then NS.Print("party list: nobody online with the rank %s", table.concat(keys, ", ")) return 0 end
  if not P.Leads() then NS.Print("party list: only the leader (or an assistant) can invite") return 0 end
  -- A WAVE (Arn, 15 Oct: "the raid leader generates a list, sends out invites, can leave it open -
  -- it regenerates with new people that log on ... and can click invite again"): the list stays
  -- open across sends, rebuilt from the same ranks; whoever was x'd stays out for the session.
  -- And a list already open takes the ranks in (17 Oct, "add to it").
  return P.StartWave(db, function(w)
    w.ranks = w.ranks or {}
    for r in pairs(ranks) do w.ranks[r] = true end
  end, label)
end

--- Those ranks' people online: those to invite, those already with you, whether any, the label
--- ("<Officer> + <Raider>", highest rank first). `ranks` is one lower-case name or a set of them.
function P.RankPeople(ranks)
  if type(ranks) == "string" then ranks = { [ranks] = true } end
  local here = { [P.Key(UnitName("player")) or "?"] = true }
  for _, m in ipairs(P.Members()) do here[m.key] = true end
  local entries, inGroup, found, named = {}, {}, false, {}
  for _, m in ipairs(P.GuildOnline()) do
    if m.rank and ranks[m.rank:lower()] then
      found = true
      named[m.rank] = named[m.rank] or (m.rankIndex or 99)
      if not here[P.Key(m.name) or "?"] then entries[#entries + 1] = m else inGroup[#inGroup + 1] = m end
    end
  end
  local order = {}
  for r in pairs(named) do order[#order + 1] = r end
  table.sort(order, function(a, b) if named[a] ~= named[b] then return named[a] < named[b] end return a < b end)
  for i, r in ipairs(order) do order[i] = "<" .. r .. ">" end
  return entries, inGroup, found, found and table.concat(order, " + ") or nil
end

function P.WithoutDropped(entries)
  local d, out = P.wave and P.wave.dropped or {}, {}
  for _, e in ipairs(entries) do if not d[P.Key(e.name) or "?"] then out[#out + 1] = e end end
  return out
end

--- The wave's list again, from the roster as it is now (new logins in, joiners moved down).
function P.Regenerate()
  local w = P.wave
  if not w then return false end
  local entries, inGroup, offline, label = P.WaveList(w)
  P.pending, P.pendingHere, P.pendingOff, P.pendingLabel, P.pendingDb = entries, inGroup, offline, label, w.db
  P.PaintConfirm()
  return true
end

--- A LIST THAT IS NOT A WAVE, CHECKED AGAIN (16 Oct 2026): the party list's, or one another addon
--- handed in through BiSToolsAPI (BiS Guild's pasted roster). Refresh used to do nothing to these -
--- P.Regenerate only knows how to rebuild a rank. Whoever has joined you since moves down to "already
--- with you"; nobody new can appear, the list came from outside.
function P.Recheck()
  local here = { [P.Key(UnitName("player")) or "?"] = true }
  for _, m in ipairs(P.Members()) do here[m.key] = true end
  local keep, with = {}, P.pendingHere or {}
  for _, e in ipairs(P.pending or {}) do
    if here[P.Key(e.name) or "?"] then with[#with + 1] = e else keep[#keep + 1] = e end
  end
  P.pending, P.pendingHere = keep, with
  P.PaintConfirm()
end

--- REFRESH YOU CAN SEE (Arn, 16 Oct: "when I click refresh can it make some type of animation so we
--- know it actually did something"). The list redraws, then a sweep brings its lines back top to
--- bottom, the button says "Refresh..." while it runs, and the head says what changed for a few
--- seconds - "2 new, 1 joined you", or "no change", which is an answer too. Flavour like the inviting
--- box: the work is done before the sweep starts. OnUpdate only while the sweep runs.
P.SWEEP, P.SWEEP_STEP, P.NOTE_FOR = 0.6, 0.035, 3
function P.RefreshNow()
  local before, beforeHere = {}, {}
  for _, e in ipairs(P.pending or {}) do before[P.Key(e.name) or "?"] = true end
  for _, e in ipairs(P.pendingHere or {}) do beforeHere[P.Key(e.name) or "?"] = true end
  if not P.Regenerate() then P.Recheck() end
  local new, joined = 0, 0
  for _, e in ipairs(P.pending or {}) do if not before[P.Key(e.name) or "?"] then new = new + 1 end end
  for _, e in ipairs(P.pendingHere or {}) do if not beforeHere[P.Key(e.name) or "?"] then joined = joined + 1 end end
  local parts = {}
  if new > 0 then parts[#parts + 1] = ("%d new"):format(new) end
  if joined > 0 then parts[#parts + 1] = ("%d joined you"):format(joined) end
  P.note = "refreshed: " .. (#parts > 0 and table.concat(parts, ", ") or "no change")
  P.noteUntil = (GetTime and GetTime() or 0) + P.NOTE_FOR
  P.PaintConfirm()
  P.Sweep()
  -- and the head back to the list's own words once the note has been read
  if C_Timer and C_Timer.After then C_Timer.After(P.NOTE_FOR + 0.05, function() P.PaintConfirm() end) end
  return new, joined
end

function P.Sweep()
  local cv = P.box and P.box.confirmView
  if not cv then return end
  if not P.sweeper then
    P.sweeper = CreateFrame("Frame")
    P.sweeper:SetScript("OnUpdate", function(self, dt)
      self.t = self.t + (dt or 0)
      P.SweepStep(self.t)
      if self.t >= P.SWEEP then self:Hide() P.SweepStep(math.huge) end
    end)
  end
  P.sweeper.t = 0
  P.SweepStep(0)
  P.sweeper:Show()
end

--- The sweep at time t: line i fades in from i * P.SWEEP_STEP; the button's dots count up.
function P.SweepStep(t)
  local cv = P.box and P.box.confirmView
  if not cv then return end
  for i, l in ipairs(cv.lines) do
    local a = (t - (i - 1) * P.SWEEP_STEP) / 0.2
    l:SetAlpha(math.max(0, math.min(1, a)))
  end
  local done = t >= P.SWEEP
  cv.refresh.label:SetText(done and "Refresh" or ("Refresh" .. string.rep(".", 1 + math.floor(t / 0.15) % 3)))
end

--- Soon, not at once: roster and group events come in bursts.
function P.RegenerateSoon()
  if P.regenPending or not P.wave then return end
  P.regenPending = true
  local after = C_Timer and C_Timer.After
  if not after then P.regenPending = nil P.Regenerate() return end
  after(P.REGEN_GAP, function()
    P.regenPending = nil
    local cv = P.box and P.box.confirmView
    if cv and cv:IsShown() then P.Regenerate() end
  end)
end
P.REGEN_GAP = 1.5
do
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("GUILD_ROSTER_UPDATE")
  ev:RegisterEvent("GROUP_ROSTER_UPDATE")
  ev:SetScript("OnEvent", function()
    local cv = P.box and P.box.confirmView
    if P.wave and cv and cv:IsShown() then P.RegenerateSoon() end
  end)
  P.waveEvents = ev
end

--- Repaint: your list (with you now = green), or the guild to pick from (on the list = green, a tick).
function P.PaintWindow()
  local f, db = P.win, P.db
  if not (f and db and f:IsShown()) then return end
  local guild, friends = P.view == "guild", P.view == "friends"
  f.con:Set("name", guild and "Party: guild" or friends and "Party: friends" or "Party", "accent")
  -- party <-> guild: the button names where it takes you (Arn, 15 Oct: "this should say guild", then
  -- "this should be party, so switch from party/guild"); the friends button the same way
  f.guildBtn.label:SetText(guild and "party" or "guild")
  if f.friendsBtn then f.friendsBtn.label:SetText(friends and "party" or "friends") end
  local names, here = P.List(db), {}
  local entries
  -- THE LIST IN CLASS COLOURS (Arn, 17 Oct: "on the party window can it also determin class?"):
  -- from your group, your guild roster or your friends list - whoever knows; grey when offline
  local who = {}
  if guild then
    entries = {}
    for _, r in ipairs(P.Ranks()) do entries[#entries + 1] = { rank = r.rank, n = r.n } end
    names = entries
  elseif friends then
    names = P.FriendsOnline()
    for _, e in ipairs(names) do who[P.Key(e.name) or "?"] = { online = true, classFile = e.classFile } end
  else
    who = P.Lookup()
    for _, m in ipairs(P.Members()) do
      here[m.key] = true
      local file = UnitClass and plain(select(2, UnitClass(m.unit)))
      if type(file) == "string" then
        who[m.key] = who[m.key] or {}
        who[m.key].classFile, who[m.key].online = file, true
      end
    end
  end
  P.offset = 0
  -- the guild view is ONE full-width column (Arn, 15 Oct: rank names like "<Altezza's Bruhs>" ran
  -- into the second column); the list keeps two of short names
  local full = P.WIN_W - 12
  local colW = full / 2
  for i, r in ipairs(f.rows) do
    local slot = i
    if guild then slot = (i <= P.ROWS) and i or nil end
    r:SetWidth(guild and full - 4 or colW - 4)
    local e = slot and names[slot + (P.offset or 0)]
    local n = e and (type(e) == "table" and e.name or e) or nil
    r.who, r.rank, r.empty = n, guild and e and e.rank or nil, nil
    if e then
      if r.rank then
        r.empty = e.n == 0
        local picked = not r.empty and P.picked and P.picked[r.rank:lower()]
        r.name:SetText(r.empty and ("<%s>  nobody else online"):format(r.rank)
          or picked and ("%s <%s> (%d)"):format(NS.T.text("good", "+"), r.rank, e.n)
          or ("<%s> (%d)"):format(r.rank, e.n))
        r.name:SetTextColor(NS.Farm.color(r.empty and "dim" or picked and "good" or "accent"))
      else
        local on = (guild or friends) and P.Has(db, n)
        local k = P.Key(n) or "?"
        -- when you last grouped, after the name (not for who is with you now - the green bar says it)
        local last = not guild and not friends and not here[k] and type(db.lastWith) == "table" and db.lastWith[k] or nil
        local ago = last and P.Ago(last.t)
        r.last = last
        r.name:SetText(on and (n .. "  " .. NS.T.text("good", "+"))
          or ago and (n .. "  " .. NS.T.text("dim", ago)) or n)
        local w = who[k]
        local r_, g, b
        if guild then r_, g, b = NS.Farm.color(on and "good" or "ink")
        elseif w and w.online == false then r_, g, b = NS.Farm.color("dim")
        else r_, g, b = classColour(w and w.classFile) end
        r.name:SetTextColor(r_, g, b, 1)
      end
      if r.here then if not guild and not friends and not r.rank and here[P.Key(n) or "?"] then r.here:Show() else r.here:Hide() end end
      if guild or friends then r.x:Hide() r.pick:Show() else r.x:Show() r.pick:Hide() end
      r:Show()
    else
      r:Hide()
    end
  end
  local extra = #names - (guild and P.ROWS or #f.rows) - (P.offset or 0)
  if guild then
    local np = 0
    for _ in pairs(P.picked or {}) do np = np + 1 end
    f.more:SetText(#names == 0 and "nobody else in your guild is online"
      or np > 0 and ("%d rank%s picked - invite to check who"):format(np, np == 1 and "" or "s")
      or (GetTime and GetTime() or 0) < (P.nudgeUntil or 0) and NS.T.text("warn", "tick a rank first - click it, then invite")
      or "click ranks to pick them, then invite")
  elseif friends then
    f.more:SetText(#names == 0 and "none of your friends is online in this game"
      or (extra > 0 and ("+%d more - click one: + on the list, again: off"):format(extra)
      or "click a friend: + on the list, again: off"))
  else
    f.more:SetText(#names == 0 and "empty - save a group, add a name, or right-click a player"
      or (extra > 0 and ("+%d more (/bist party list)"):format(extra) or ""))
  end
end

--- The list changed: the window and the box look again.
function P.Changed()
  P.PaintWindow()
  if NS.Box and NS.Box.Refresh then NS.Box.Refresh() end
end

function P.Toggle(db, show, recenter)
  local f = P.BuildWindow(db)
  if show == nil then show = not f:IsShown() end
  if not show then f:Hide() return end
  f:ClearAllPoints()
  local p = db.pos
  if recenter or type(p) ~= "table" then f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  else f:SetPoint(p[1], UIParent, p[4] or p[1], p[2] or 0, p[3] or 0) end
  f:Show()
  P.PaintWindow()
end

------------------------------------------------------------- the right-click line --
-- "Add to party list", in the BiS section of a party or raid member's menu (Arn, 15 Oct). The game's own
-- Menu.ModifyMenu, as the rivals' lines are; never inside an instance (RC.MenuSafe).
P.MENUS = { "PARTY", "RAID_PLAYER", "RAID", "TARGET", "FOCUS", "PLAYER",
  -- FRIEND is a chat name's menu too. The Friends list's own menus are left alone (Arn's BugGrabber,
  -- 20 Oct: a line there tainted the list's refresh - SearchFriends refused; RC.FromFriendsList):
  -- a friend goes on the party list by /bist party add <name>, or from a chat name
  "FRIEND" }

local function field(ctx, k)
  local ok, v = pcall(function() return ctx[k] end)
  return ok and plain(v) or nil
end

function P.MenuLine(db, root, ctx, kind)
  if not (R:Enabled("party") and root and root.CreateButton) then return end
  local RC = NS.Recap
  if RC and RC.MenuSafe and not RC.MenuSafe() then return end
  if kind ~= "GUILD" and RC and RC.FromFriendsList and RC.FromFriendsList(ctx, kind) then return end   -- (see P.MENUS)
  local name
  if kind == "GUILD" then
    if not db.guildMenu then return end             -- switched off since: nothing until the /reload
    name = RC and RC.MenuName and RC.MenuName(ctx)
  elseif (RC and RC.FRIEND_MENUS and RC.FRIEND_MENUS[kind or ""]) or field(ctx, "bnetIDAccount") ~= nil then
    -- a friend: whoever it is (a Battle.net friend by the character they're playing in this game)
    name = RC and RC.FriendName and RC.FriendName(ctx)
  else
    -- ANY FRIENDLY PLAYER, not just your group (Arn, 15 Oct, right-clicking someone in Orgrimmar:
    -- "why cant i add them to the party list? is that only for people in the party?"). Not you,
    -- and not the other faction - you could not invite them anyway.
    local unit = field(ctx, "unit")
    if type(unit) ~= "string" then return end
    local okP, friendly = pcall(function()
      return UnitIsPlayer(unit) and UnitIsFriend("player", unit) and not UnitIsUnit(unit, "player")
    end)
    if not okP or plain(friendly) ~= true then return end
    name = plain(GetUnitName and GetUnitName(unit, true) or UnitName(unit))
  end
  if not P.Key(name) then return end
  local on = P.Has(db, name)
  if RC and RC.Section then RC.Section(root) elseif root.CreateDivider then root:CreateDivider() end
  root:CreateButton(on and "Remove from party list" or "Add to party list", function()
    if on then P.Remove(db, name) else P.Add(db, name) end
    NS.Print("party list: %s %s (%d on it)", name, on and "removed" or "added", #P.List(db))
    P.Changed()
  end)
end

-- THE GUILD WINDOW'S MENU (Arn, 15 Oct: "from the guild window to add them to the party list same
-- as from the friend list"). The one menu the family stays out of: Olympus found a line there left
-- promote / demote / remove refused for officers (RC.MenuAllowed). So it is a SWITCH, off by
-- default, and while off the menu is never even hooked; on, it hooks at once. Arn tests it once
-- (add someone, then promote or demote someone) - if Forever refuses, it stays off. Turning it
-- off takes a /reload to unhook.
P.GUILD_MENUS = { "COMMUNITIES_GUILD_MEMBER", "COMMUNITIES_WOW_MEMBER", "GUILD" }
function P.HookGuildMenus(db)
  if P.guildHooked or not db.guildMenu or not (Menu and type(Menu.ModifyMenu) == "function") then return false end
  P.guildHooked = true
  for _, kind in ipairs(P.GUILD_MENUS) do
    pcall(Menu.ModifyMenu, "MENU_UNIT_" .. kind, function(_, root, ctx) P.MenuLine(db, root, ctx, "GUILD") end)
  end
  return true
end

function P.HookMenus(db)
  if P.menusHooked or not (Menu and type(Menu.ModifyMenu) == "function") then return false end
  P.menusHooked = true
  for _, kind in ipairs(P.MENUS) do
    pcall(Menu.ModifyMenu, "MENU_UNIT_" .. kind, function(_, root, ctx) P.MenuLine(db, root, ctx, kind) end)
  end
  return true
end

------------------------------------------------------- when you last grouped --
-- (Arn, 17 Oct, with Blizzard's Recent Allies open: "maybe the list can add a little note of the
-- last time we were partied?") Our own record - the client's Recent Allies is unmeasured on Forever:
-- db.lastWith[key] = { t, zone } for everyone you group with, written at each group change, and
-- again for whoever just LEFT, so the time is when you parted. Event-only; nothing ticks. At most
-- P.LAST_MAX people, the longest-unseen dropped first.
P.LAST_MAX = 200

function P.NoteTogether(db)
  if type(db) ~= "table" then return 0 end
  db.lastWith = type(db.lastWith) == "table" and db.lastWith or {}
  local now = (time and time()) or 0
  local zone = GetRealZoneText and plain(GetRealZoneText())
  zone = type(zone) == "string" and zone ~= "" and zone or nil
  local cur, n = {}, 0
  for _, m in ipairs(P.Members()) do
    cur[m.key] = true
    db.lastWith[m.key] = { t = now, zone = zone }
    n = n + 1
  end
  for k in pairs(P.together or {}) do
    if not cur[k] and db.lastWith[k] then db.lastWith[k].t, db.lastWith[k].zone = now, zone or db.lastWith[k].zone end
  end
  P.together = cur
  local count, oldestK, oldestT = 0, nil, nil
  for k, v in pairs(db.lastWith) do
    count = count + 1
    if not oldestT or (v.t or 0) < oldestT then oldestK, oldestT = k, v.t or 0 end
  end
  if count > P.LAST_MAX and oldestK then db.lastWith[oldestK] = nil end
  return n
end

--- "now", "5m", "3h", "2d", "6w" - short enough to sit after a name.
function P.Ago(t, now)
  if type(t) ~= "number" then return nil end
  local s = math.max(0, (now or (time and time()) or 0) - t)
  if s < 60 then return "now" end
  if s < 3600 then return ("%dm"):format(math.floor(s / 60)) end
  if s < 86400 then return ("%dh"):format(math.floor(s / 3600)) end
  if s < 86400 * 28 then return ("%dd"):format(math.floor(s / 86400)) end
  return ("%dw"):format(math.floor(s / (86400 * 7)))
end

------------------------------------------------------------------ the tool --

local function refresh() P.Changed() end

local ev = CreateFrame("Frame")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:SetScript("OnEvent", function(_, event)
  -- logging out parts you from everyone: the group is still there to read, so write it as now
  if event == "PLAYER_LOGOUT" then
    local db = P.db
    if type(db) == "table" and type(db.lastWith) == "table" then
      local now = (time and time()) or 0
      for k in pairs(P.together or {}) do if db.lastWith[k] then db.lastWith[k].t = now end end
    end
    return
  end
  if P.held then P.Held() end
  -- ONE roster walk for the note and the redraw both (the 40-man budget: 150 asks)
  P.__members = P.Members()
  local ok, err = pcall(function()
    if R:Enabled("party") then P.NoteTogether(P.db) end
    refresh()
  end)
  P.__members = nil
  if not ok then error(err, 0) end
end)
P.events = ev

R:Register({
  name = "party",
  -- OFF until turned on (Arn, 15 Oct: "start with this option for the party in tools off so the BiS
  -- toolbox is not overwhelming")
  defaultOff = true,
  desc = "your usual group: invite them all, or disband, in one click",
  usage = "/bist party [save | add <name> | remove <name> | list | clear | invite | rank <rank> | keyword <word> | disband]",
  defaults = {},
  options = {
    { kind = "button", label = "save my group as the list", help = "Everyone you're grouped with now becomes your party list. The Invite button in the BiS> tools box then asks them all back in one click.",
      button = "save", action = function(db)
        local n = P.SaveGroup(db)
        NS.Print(n > 0 and ("party list: %d saved"):format(n) or "party list: you're not in a group - nobody to save")
        refresh()
      end },
    { kind = "toggle", label = "the inviting show", help = "When you press Invite, a little loading box fills up and talks you through it in chat. Just for fun: the invites go out at once either way.",
      get = function(db) return db.show ~= false end, set = function(db, on) db.show = on and true or false end },
    { kind = "toggle", label = "add from the guild window", help = "Puts 'Add to party list' on a guildmate's right-click in the guild window. TEST IT ONCE: the game may then refuse Promote / Demote / Remove for officers until a /reload. Off by default; turning it off needs a /reload.",
      get = function(db) return db.guildMenu == true end,
      set = function(db, on) db.guildMenu = on and true or false if on then P.HookGuildMenus(db) end end },
    -- the hands-off switches (Tools/PartyAuto.lua), all off until turned on
    { kind = "toggle", label = "accept invites from the guild", help = "A guildmate's party invite is accepted for you. Matched by who they really are, not just a first name.",
      get = function(db) return db.acceptGuild == true end, set = function(db, on) db.acceptGuild = on and true or nil end },
    { kind = "toggle", label = "accept invites from friends", help = "A friend's party invite - a character friend or a Battle.net friend - is accepted for you.",
      get = function(db) return db.acceptFriends == true end, set = function(db, on) db.acceptFriends = on and true or nil end },
    { kind = "toggle", label = "invite on a whispered keyword", help = "Whoever whispers you the keyword gets a party invite (you must lead, or be on your own). Past five, the party becomes a raid by itself.",
      get = function(db) return db.keyword == true end, set = function(db, on) db.keyword = on and true or nil end },
    { kind = "seg", label = "keyword", values = P.KEYWORDS,
      help = "The word to whisper. Any case; spaces around it don't matter. Another word: /bist party keyword <word>.",
      get = function(db) return P.Keyword(db) end, set = function(db, v) db.keywordText = v end },
    { kind = "seg", label = "keyword from", values = { "known", "anyone" },
      help = "Who the keyword works for: known - your guild and your friends only; anyone - whoever whispers it.",
      get = function(db) return db.keywordFrom == "anyone" and "anyone" or "known" end,
      set = function(db, v) db.keywordFrom = (v == "anyone") and "anyone" or nil end },
    { kind = "button", label = "clear the list", help = "Empty the party list.",
      button = "clear", action = function(db) db.names = {} NS.Print("party list: cleared") refresh() end },
  },
  OnInit = function(_, db) P.db = db end,
  OnOpen = function(_, db, recenter) P.db = db P.Toggle(db, true, recenter) end,
  IsOpen = function() return P.win ~= nil and P.win:IsShown() end,
  OnClose = function(_, db) P.Toggle(db, false) end,
  OnLogin = function(_, db) P.db = db P.HookMenus(db) P.HookGuildMenus(db) P.NoteTogether(db) refresh() end,
  OnSlash = function(_, db, args)
    P.db = db
    local verb, rest = (args or ""):match("^(%S*)%s*(.-)%s*$")
    verb = (verb or ""):lower()
    if verb == "save" then
      local n = P.SaveGroup(db)
      NS.Print(n > 0 and ("party list: %d saved"):format(n) or "party list: you're not in a group - nobody to save")
    elseif verb == "add" then
      local ok, why = P.Add(db, rest)
      NS.Print(ok and ("party list: %s added (%d on it)"):format(rest, #P.List(db)) or ("party list: " .. tostring(why)))
    elseif verb == "remove" then
      NS.Print(P.Remove(db, rest) and ("party list: %s removed"):format(rest) or ("party list: %s is not on it"):format(rest))
    elseif verb == "clear" then
      db.names = {}
      NS.Print("party list: cleared")
    elseif verb == "invite" then
      P.Invite(db)
    elseif verb == "rank" then
      if rest == "" then
        local ranks = {}
        for i, r in ipairs(P.Ranks()) do ranks[#ranks + 1] = ("%d. %s (%d)"):format(i, r.rank, r.n) end
        NS.Print("ranks online: %s - /bist party rank <name or number> invites them all", #ranks > 0 and table.concat(ranks, ", ") or "nobody")
      else
        P.InviteRank(db, rest)
      end
    elseif verb == "keyword" then
      local word = rest:match("^(%S+)")
      if word then db.keywordText = word:lower() end
      NS.Print("party: the keyword is \"%s\" - invite on it is %s", P.Keyword(db), db.keyword and "on" or "off (options)")
    elseif verb == "disband" then
      if not P.Disband() then NS.Print("party list: you're not in a group") end
    elseif verb == "" then
      P.Toggle(db)
    else
      local list = P.List(db)
      NS.Print("party list (%d): %s", #list, #list > 0 and table.concat(list, ", ") or "empty - /bist party save, or right-click a party member")
    end
    refresh()
  end,
})
