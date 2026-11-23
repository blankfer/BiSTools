-- dev/apps/party.lua - your usual group in the phone (Tools/Apps/Party.lua)
return function(H)
  local NS, R, ok, W, Dk = H.NS, H.R, H.ok, H.W, H.Dk
  local P, db, d = NS.Party, R:DBFor(R:Get("party")), H.Page("party")
  local p, c = d.page, d.card
  local function press(b) Dk.Press(d, b)() W.now = W.now + 0.1 end
  local function later(s) W.now = W.now + (s or 6) end            -- (the long lists are looked at every 5 s)
  local function row(tab, name) for _, r in ipairs(p.rows(tab)) do if r.text == name then return r end end end
  local function key(tab, word) for _, k in ipairs(p.keys(tab)) do if k.word == word then return k end end end
  Dk.Store().toured = Dk.Store().toured or {}
  Dk.Store().toured[d.id] = true
  local G = { "IsInGroup", "IsInRaid", "UnitExists", "UnitIsUnit", "UnitIsGroupLeader", "UnitIsGroupAssistant", "GetUnitName", "UnitName", "C_PartyInfo", "IsInGuild", "GetNumGuildMembers",
    "GetGuildRosterInfo", "GuildControlGetNumRanks", "GuildControlGetRankName", "C_GuildInfo", "C_FriendList", "BNGetNumFriends", "issecretvalue", "GetNumGroupMembers" }
  local keep, kp = {}, {}
  for _, k in ipairs(G) do keep[k] = rawget(_G, k) end
  for _, k in ipairs({ "queue", "out", "held", "timer", "wave", "pending", "picked", "failed", "saidError", "lastError", "db", "run" }) do kp[k] = P[k] end
  local names, lastWith, word = db.names, db.lastWith, db.keyword
  local print0 = NS.Print
  NS.Print = function() end
  P.run = nil
  P.queue, P.out, P.held, P.timer, P.wave, P.pending, P.picked, P.db, db.names, db.lastWith, db.keyword = {}, {}, nil, nil, nil, nil, nil, db, {}, {}, nil

  -- a party of W.team, me the leader or not; the guild; the friends
  local team, leader, invited, kicked, left, raid = {}, true, {}, {}, 0, false
  _G.IsInGroup = function() return #team > 0 end
  _G.IsInRaid = function() return raid end
  _G.GetNumGroupMembers = function() return #team + 1 end
  _G.UnitExists = function(u) local i = tonumber(u:match("^party(%d)$")) return i ~= nil and team[i] ~= nil end
  _G.UnitIsUnit = function(a, b) return a == b end
  _G.UnitIsGroupLeader = function() return leader end
  _G.UnitIsGroupAssistant = function() return false end
  _G.UnitName = function(u) return u == "player" and "Me" or team[tonumber(u:match("^party(%d)$"))] end
  _G.GetUnitName = function(u) return _G.UnitName(u) end
  _G.C_PartyInfo = { InviteUnit = function(n) invited[#invited + 1] = n end, UninviteUnit = function(n) kicked[#kicked + 1] = n end, LeaveParty = function() left = left + 1 end,
    ConvertToRaid = function() raid = true end }
  local guild = { { "Anna Moon", "Officer", 1, true, "MAGE" }, { "Bert Sun", "Raider", 2, true, "PRIEST" }, { "Cora Star", "Raider", 2, false, "ROGUE" }, { "Dora Sky", "Raider", 2, true, "DRUID" } }
  local asked = 0
  _G.IsInGuild = function() return true end
  _G.GetNumGuildMembers = function() return #guild end
  _G.GetGuildRosterInfo = function(i) local m = guild[i] return m[1], m[2], m[3], 60, m[5]:lower(), "", "", "", m[4], 0, m[5] end
  _G.GuildControlGetNumRanks = function() return 0 end
  _G.C_GuildInfo = { GuildRoster = function() asked = asked + 1 end }
  local friends = { { name = "Fred Wind", connected = true, className = "Mage" }, { name = "Gina Rain", connected = false } }
  _G.C_FriendList = { GetNumFriends = function() return #friends end, GetFriendInfoByIndex = function(i) return friends[i] end }
  _G.BNGetNumFriends = nil
  later()

  local t = p.tabs()
  ok(t[1] == "LIST" and t[2] == "GUILD" and t[3] == "FRIENDS" and t[4] == "SETTINGS", "party: LIST, GUILD, FRIENDS, SETTINGS")
  ok(#p.rows(1) == 0 and p.text(1):find("empty") and p.big(1) == nil and not c.alive() and d.badge() == nil, "an empty list, alone: words, nothing to press")
  -- a name typed
  p.find(1).enter("Anna Moon")
  ok(db.names[1] == "Anna Moon" and p.say(1):find("is on your list"), "a name typed is on the list")
  p.find(1).enter("Anna Moon")
  ok(#db.names == 1 and p.say(1):find("already"), "twice: it says so")
  for _, n in ipairs({ "Bert Sun", "Cora Star", "Nobody Knows", "Fred Wind" }) do p.find(1).enter(n) end
  later()
  ok(row(1, "Anna Moon").right == "ONLINE" and row(1, "Cora Star").right == "OFFLINE" and row(1, "Nobody Knows").right == "?" and row(1, "Fred Wind").right == "ONLINE",
    "who is on, as far as the client says", row(1, "Cora Star").right)
  ok(p.boxes(1)[1][2] == "0 / 5" and p.boxes(1)[2][2] == 4 and p.boxes(1)[3][2] == 1, "with you, to ask, offline", p.boxes(1)[2][2])
  -- with me
  team = { "Anna Moon" }
  later()
  ok(row(1, "Anna Moon").right == "WITH YOU" and p.boxes(1)[1][2] == "1 / 5", "in the group: WITH YOU")
  -- one person
  press(row(1, "Bert Sun").act)
  ok(invited[1] == "Bert Sun" and row(1, "Bert Sun").right == "ASKED" and d.badge() == 1, "a click on a row asks that one", invited[1])
  ok(c.alive() and Dk.IsLive(d) and c.lines()[4] == "1 ASKED" and c.lines()[3] == "1 of 5 with you", "and a live card says so", c.lines()[3])
  ok(row(1, "Anna Moon").act == nil and row(1, "Cora Star").act == nil, "who is with you or offline cannot be pressed")
  -- the whole list: looked over first
  ok(p.big(1).word == "INVITE 2", "the rest: the big button", p.big(1).word)
  press(p.big(1))
  ok(#invited == 1 and p.tabs()[1] == "SEND" and d.tab == 1, "nothing goes out yet: the list to look over")
  ok(p.boxes(1)[1][2] == 2 and p.boxes(1)[2][2] == 1 and p.boxes(1)[3][2] == 1, "to send, asked, with you")
  ok(row(1, "Nobody Knows").side.word == "OUT" and row(1, "Bert Sun").right == "ASKED" and p.find(1) == nil, "OUT beside each, the asked one says so")
  ok(P.wave == nil and not (P.box and P.box:IsShown() and P.pending), "the old window's own wave is left alone")
  press(row(1, "Nobody Knows").side)
  ok(p.big(1).word == "SEND 1 INVITE", "one left out", p.big(1).word)
  press(p.big(1))
  ok(#invited == 2 and invited[2] == "Fred Wind" and not (P.run), "SEND asks the rest, without the old inviting box", invited[2])
  ok(p.big(1).word == "DONE", "nobody left to ask")
  W.now = W.now + P.OUT_FOR + 1
  ok(p.big(1).word:find("SEND 2"), "invites that ran out can be sent again", p.big(1).word)
  ok(not row(1, "Nobody Knows"), "who was left out stays out")
  press(key(1, "REFRESH"))
  ok(asked == 1, "REFRESH asks the game for the roster")
  press(key(1, "CANCEL"))
  ok(p.tabs()[1] == "LIST" and #invited == 2 and not c.alive(), "CANCEL: the list again, nobody asked, no card")
  -- take a name off
  press(key(1, "EDIT"))
  press(row(1, "Nobody Knows").side)
  ok(#db.names == 5 and row(1, "Nobody Knows").side.word == "SURE?", "REMOVE asks first")
  press(row(1, "Nobody Knows").side)
  ok(#db.names == 4 and not P.Has(db, "Nobody Knows"), "then does it")
  press(key(1, "DONE"))
  -- the guild's ranks
  ok(p.rows(2)[1].text == "Officer" and p.rows(2)[2].right == "2 ON" and p.big(2) == nil, "the ranks and who is on", p.rows(2)[2].right)
  press(p.rows(2)[2].act)
  ok(P.picked.raider and p.rows(2)[2].mark == "v" and p.big(2).word == "INVITE 1 RANK", "a click picks one")
  press(p.big(2))
  ok(p.tabs()[1] == "SEND" and d.tab == 1 and row(1, "Bert Sun") and row(1, "Dora Sky") and #invited == 2, "its people, to look over, class by class")
  ok(p.rows(1)[1].done and p.rows(1)[1].text:find("%(1%)"), "a heading for each class", p.rows(1)[1].text)
  press(p.big(1))
  ok(#invited == 4, "sent", #invited)
  press(p.big(1))
  press(key(2, "NONE"))
  ok(next(P.picked) == nil, "NONE: no rank picked")
  -- friends
  ok(#p.rows(3) == 1 and p.rows(3)[1].text == "Fred Wind" and p.rows(3)[1].side.word == "- LIST", "the friends who are on")
  press(p.rows(3)[1].side)
  ok(not P.Has(db, "Fred Wind") and p.rows(3)[1].side.word == "+ LIST", "off the list, on the list")
  press(p.rows(3)[1].side)
  press(p.rows(3)[1].act)
  ok(invited[#invited] == "Fred Wind" and p.rows(3)[1].right == "ASKED" and p.rows(3)[1].side == nil, "a click asks them")
  -- not the leader
  leader = false
  later(9)
  -- (Arn, 22 Nov: "in forever now we can suggest people to the leader to invite")
  for k in pairs(P.out) do P.out[k] = nil end
  local bert = row(1, "Bert Sun")
  ok(p.big(1) == nil and bert.verb == "SUGGEST" and p.say(1):find("SUGGEST asks the leader", 1, true), "not the leader: SUGGEST on each one, no big button, and it says so", p.say(1))
  local before = #invited
  press(bert.act)
  ok(#invited == before + 1 and invited[#invited] == "Bert Sun" and row(1, "Bert Sun").right == "SUGGESTED" and row(1, "Bert Sun").act == nil, "SUGGEST hands the name to the game's invite call: the leader is asked; said, and not twice")
  ok(key(1, "LEAVE") and not key(1, "DISBAND"), "LEAVE, not DISBAND")
  press(key(1, "LEAVE"))
  ok(left == 0 and key(1, "SURE?"), "LEAVE asks first")
  W.now = W.now + 6
  ok(key(1, "LEAVE"), "for five seconds")
  press(key(1, "LEAVE")) press(key(1, "SURE?"))
  ok(left == 1, "twice: you left")
  leader = true
  press(key(1, "DISBAND")) press(key(1, "SURE?"))
  ok(kicked[1] == "Anna Moon", "leading: everyone out")
  -- save
  team = { "Anna Moon", "Zoe New" }
  later()
  press(key(1, "SAVE"))
  ok(#db.names == 4, "SAVE over a list asks first")
  press(key(1, "SURE?"))
  ok(#db.names == 2 and db.names[2] == "Zoe New", "then the group is the list")
  db.names = {}
  later()
  ok(p.big(1).word == "SAVE MY GROUP", "an empty list in a group: the big button saves it")
  press(p.big(1))
  ok(#db.names == 2, "saved")
  -- more than a party holds
  for _, n in ipairs({ "Bert Sun", "Dora Sky", "Fred Wind" }) do P.Add(db, n) end
  P.out, invited, P.suggested = {}, {}, {}
  later()
  press(p.big(1)) press(p.big(1))
  ok(#invited == 2 and P.held and #P.held.names == 1 and row(1, "Fred Wind").right == "NEXT" and p.say(1), "past five: the rest wait for the raid", #invited)
  press(key(1, "CANCEL") or p.big(1))
  P.held = nil
  -- alone, no guild, no friends; hidden names
  raid = false
  team, guild, friends, db.names, P.out = {}, {}, {}, {}, {}
  later()
  ok(p.text(2) and p.text(3) and p.text(1) and not d.badge(), "nobody anywhere: every tab says what to do")
  local secret = setmetatable({}, { __eq = function() error("compared a secret") end, __concat = function() error("joined a secret") end })
  _G.issecretvalue = function(v) return rawequal(v, secret) end
  team, guild, friends = { secret, "Anna Moon" }, { { secret, secret, secret, secret, "MAGE" } }, { { name = secret, connected = secret } }
  _G.GetGuildRosterInfo = function() return secret, secret, secret, 60, secret, "", "", "", secret, 0, secret end
  _G.UnitIsGroupLeader = function() return secret end
  db.names = { "Anna Moon" }
  later()
  for i = 1, 4 do H.Paint("party", i) later() end
  ok(not d.errors and row(1, "Anna Moon").right == "WITH YOU", "hidden names: no error, the plain ones work", d.errors)

  Dk.EndLive(d)
  NS.Print = print0
  for _, k in ipairs(G) do _G[k] = keep[k] end
  for _, k in ipairs({ "queue", "out", "held", "timer", "wave", "pending", "picked", "failed", "saidError", "lastError", "db", "run" }) do P[k] = kp[k] end
  db.names, db.lastWith, db.keyword = names, lastWith, word
end
