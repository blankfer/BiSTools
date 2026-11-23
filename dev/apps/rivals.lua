-- dev/apps/rivals.lua - rivals, pals and griefers in the phone (Tools/Apps/Rivals.lua)
return function(H)
  local NS, R, ok, W, Dk = H.NS, H.R, H.ok, H.W, H.Dk
  local RC, d = NS.Recap, H.Page("rivals")
  local db, p, c = RC.DB(), d.page, d.card
  local function press(b) Dk.Press(d, b)() end
  local function row(tab, name) for _, r in ipairs(p.rows(tab)) do if r.text == name then return r end end end
  local function key(tab, word) for _, k in ipairs(p.keys(tab)) do if k.word == word then return k end end end
  Dk.Store().toured = Dk.Store().toured or {}
  Dk.Store().toured[d.id] = true
  local LISTS = { "rivals", "pals", "griefers", "guildRivals", "surnames", "guildShow" }
  local G = { "UnitExists", "UnitIsPlayer", "UnitIsUnit", "GetUnitName", "UnitName", "UnitCanAttack", "UnitGUID", "UnitClass", "IsInGuild", "GetNumGuildMembers", "GetGuildRosterInfo",
    "C_FriendList", "ChatFrame_SendTell", "issecretvalue", "StaticPopup_Show", "StaticPopupDialogs", "C_GuildInfo" }
  local keep, kg, kr = {}, {}, { print = NS.Print, seen = RC.palSeenAt, gseen = RC.griefSeen, ingroup = RC.griefInGroup, send = RC.GuildAdd, del = RC.GuildDel }
  for _, k in ipairs(LISTS) do keep[k] = db[k] end
  for _, k in ipairs(G) do kg[k] = rawget(_G, k) end
  NS.Print = function() end
  db.rivals, db.pals, db.griefers, db.guildRivals, db.surnames, db.guildShow = {}, {}, {}, {}, {}, nil
  RC.palSeenAt, RC.griefSeen, RC.griefInGroup = {}, {}, {}
  _G.IsInGuild = function() return false end
  _G.C_FriendList = nil
  local tgt
  _G.UnitExists = function(u) return u == "target" and tgt ~= nil end
  _G.UnitIsPlayer = function(u) return u == "target" and tgt ~= nil and tgt.player ~= false end
  _G.UnitIsUnit = function(a, b) return a == b end
  _G.GetUnitName = function(u) if u == "target" then return tgt and tgt.name end end
  _G.UnitName = function(u) if u == "player" then return "Me" end return tgt and tgt.name end
  _G.UnitCanAttack = function() return tgt ~= nil and tgt.foe == true end
  _G.UnitGUID = function(u) return u == "target" and tgt and ("Player-" .. tgt.id) or "Player-1" end
  _G.UnitClass = function() return "Hunter", "HUNTER" end

  local t = p.tabs()
  ok(t[1] == "RIVALS" and t[2] == "PALS" and t[3] == "GRIEFERS" and t[4] == "SETTINGS", "rivals: RIVALS, PALS, GRIEFERS, SETTINGS")
  for i = 1, 3 do ok(#p.rows(i) == 0 and type(p.text(i)) == "string" and p.big(i).word == "ADD MY TARGET", "tab " .. i .. " empty: it says what to do") end
  ok(c.prio() == nil and not d.badge(), "nobody near: no card")
  -- the target
  press(p.big(1))
  ok(p.say(1):find("Target an enemy"), "no target: it says so", p.say(1))
  tgt = { name = "Hunting Moms", id = 7, foe = true }
  ok(p.big(1).word == "ADD Hunting Moms", "the big button names your target")
  press(p.big(1))
  ok(db.rivals["Hunting Moms"] and db.rivals["Hunting Moms"].active and row(1, "Hunting Moms").mark == ">", "an enemy added: a gold rival, looked at")
  press(p.big(1))
  ok(db.rivals["Hunting Moms"] and p.say(1):find("already"), "pressed again: still there (never switched off by it)")
  tgt = { name = "Kind Soul", id = 8, foe = false }
  press(p.big(1))
  ok(not db.rivals["Kind Soul"] and p.say(1):find("friendly"), "a friend is no rival")
  -- what is known
  db.rivals["Hunting Moms"].kills, db.rivals["Hunting Moms"].where, db.rivals["Hunting Moms"].seen = 3, "The Barrens", W.now - 40
  db.rivals["Old Foe"] = { class = "ROGUE", added = W.now - 90000, kills = 0, active = false }
  W.now = W.now + 7
  ok(p.boxes(1)[1][2] == 3 and p.boxes(1)[2][2] == "now" and p.say(1):find("Hunter") and p.say(1):find("The Barrens"), "kills, seen, class, where", p.say(1))
  press(row(1, "Old Foe").act)
  ok(p.boxes(1)[1][2] == 0 and p.boxes(1)[3][2] == "1d" and p.say(1):find("Old Foe: Rogue"), "a click on a row: what is known about them", p.say(1))
  ok(c.prio() == 8 and c.lines()[1] == "RIVAL NEAR" and c.lines()[3] == "Hunting Moms" and c.lines()[4] == "47s" and d.badge() == 1, "seen just now: a card by itself", c.lines()[4])
  db.rivals["Hunting Moms"].active = false
  ok(c.prio() == nil, "a silver rival is no news")
  press(row(1, "Hunting Moms").act)
  press(key(1, "GOLD"))
  ok(db.rivals["Hunting Moms"].active and key(1, "SILVER"), "GOLD / SILVER: the window's own switch")
  -- remove: two presses
  press(row(1, "Old Foe").side)
  ok(db.rivals["Old Foe"] and row(1, "Old Foe").side.word == "SURE?", "REMOVE asks first")
  W.now = W.now + 6
  ok(row(1, "Old Foe").side.word == "REMOVE", "for five seconds")
  press(row(1, "Old Foe").side) press(row(1, "Old Foe").side)
  ok(not db.rivals["Old Foe"], "twice: gone")
  -- the guild's rivals, surnames
  db.guildRivals["Amber Foe"] = { class = "MAGE", by = "Chain Healz", added = W.now }
  ok(row(1, "Amber Foe").mark == "+", "a guild rival")
  press(row(1, "Amber Foe").act)
  ok(p.say(1):find("from Chain Healz") and key(1, "MAKE MINE"), "who gave it")
  press(key(1, "MAKE MINE"))
  ok(db.rivals["Amber Foe"] and db.rivals["Amber Foe"].class == "MAGE", "MAKE MINE: on your own list")
  local f = p.find(1)
  f.set("foreverpvp")
  ok(#p.rows(1) == 0 and p.text(1) == "No rival is called that." and key(1, "CROWN"), "a search; one word can be crowned")
  press(key(1, "CROWN"))
  ok(db.surnames.foreverpvp == "Foreverpvp" and row(1, "All named Foreverpvp") and p.find(1).get() == "", "CROWN: everyone with that surname")
  press(row(1, "All named Foreverpvp").side) press(row(1, "All named Foreverpvp").side)
  ok(next(db.surnames) == nil, "and off again")
  p.find(1).set("hunt")
  ok(#p.rows(1) == 1, "the search finds by a part")
  p.find(1).enter("hunting moms")
  ok(db.rivals["Hunting Moms"] and p.find(1).get() == "", "enter on a rival there already: shown")
  p.find(1).enter("Never Seen")
  ok(not db.rivals["Never Seen"], "a rival is never added by a typed name (the tool has no such road)")
  p.find(1).set("")
  -- pals
  press(p.big(2))
  ok(db.pals["Kind Soul"] and db.pals["Kind Soul"].guid == "Player-8", "your friendly target: a pal")
  press(p.big(2))
  ok(db.pals["Kind Soul"] and p.say(2):find("already"), "never taken off by the same button")
  p.find(2).enter("nebeon nolightforu")
  ok(db.pals["Nebeon Nolightforu"] and row(2, "Nebeon Nolightforu"), "a typed name: a pal, as the game writes it")
  p.find(2).enter("Nebeon Nolightforu")
  p.find(2).enter("nebeon")
  ok(db.pals["Nebeon Nolightforu"], "typed again: still one")
  p.find(2).enter("x9!")
  ok(p.say(2) == "That is not a name.", "not a name: it says so")
  RC.palSeenAt["Kind Soul"] = W.now - 120
  press(row(2, "Kind Soul").act)
  ok(p.boxes(2)[1][2] == "?" and p.boxes(2)[2][2] == "2m", "online (not known), near 2 minutes ago", p.boxes(2)[2][2])
  local told
  _G.ChatFrame_SendTell = function(n) told = n end
  press(key(2, "WHISPER"))
  ok(told == "Kind Soul", "WHISPER")
  -- the guild, to pick pals from
  _G.IsInGuild = function() return true end
  _G.GetNumGuildMembers = function() return 2 end
  _G.C_GuildInfo = { GuildRoster = function() end }
  _G.GetGuildRosterInfo = function(i) return i == 1 and "Anna Moon" or "Kind Soul", "Raider", 2, 60, "Mage", "", "", "", true, 0, "MAGE" end
  W.now = W.now + 6
  ok(p.boxes(2)[1][2] == "YES", "a pal in the guild: online")
  press(key(2, "GUILD"))
  ok(#p.rows(2) == 2 and p.rows(2)[1].text == "Kind Soul" and p.rows(2)[1].side.word == "- PAL" and p.rows(2)[2].side.word == "+ PAL" and p.big(2) == nil, "GUILD: who is online, pals first")
  press(p.rows(2)[2].side)
  ok(db.pals["Anna Moon"], "+ PAL")
  press(key(2, "MY PALS"))
  press(row(2, "Anna Moon").side) press(row(2, "Anna Moon").side)
  ok(not db.pals["Anna Moon"], "a pal removed in two")
  -- griefers
  p.find(3).enter("ninja looter - took the belt")
  ok(db.griefers["Ninja Looter"] and db.griefers["Ninja Looter"].why == "took the belt" and p.say(3):find("took the belt"), "a griefer typed, with the why", p.say(3))
  _G.StaticPopupDialogs = {}
  local popped
  _G.StaticPopup_Show = function(which, name, _, data) popped = { which, name, data } end
  tgt = { name = "Bad Mage", id = 9, foe = false }
  press(p.big(3))
  ok(popped and popped[1] == "BISTOOLS_GRIEFER" and popped[2] == "Bad Mage" and popped[3].guid == "Player-9", "your target: the tool's own question, why")
  tgt = { name = "Foe Two", id = 10, foe = true }
  popped = nil
  press(p.big(3))
  ok(not popped and p.say(3):find("enemy"), "an enemy is a rival, not a griefer")
  press(key(3, "WHY"))
  ok(popped and popped[2] == "Ninja Looter", "WHY asks again for the one looked at")
  RC.griefSeen["Ninja Looter|near"] = W.now - 5
  db.rivals["Hunting Moms"].seen = W.now - 60
  ok(c.lines()[1] == "GRIEFER NEAR" and c.lines().list[1][1] == "took the belt", "a griefer near: the card, with the why", c.lines()[1])
  RC.griefInGroup["Ninja Looter"], RC.griefSeen["Ninja Looter|group"] = true, W.now
  ok(c.prio() == 9 and c.lines()[1] == "GRIEFER IN YOUR GROUP" and p.boxes(3)[1][2] == "YES", "in your group: the most urgent")
  W.now = W.now + 300
  ok(c.prio() == 4, "then it only stays there", c.prio())
  press(row(3, "Ninja Looter").side) press(row(3, "Ninja Looter").side)
  ok(next(db.griefers) == nil, "a griefer removed in two")
  RC.griefInGroup, RC.griefSeen = {}, {}
  -- a hidden target
  local secret = setmetatable({}, { __eq = function() error("compared a secret") end, __concat = function() error("joined a secret") end })
  _G.issecretvalue = function(v) return rawequal(v, secret) end
  tgt = { name = secret, id = 11, foe = true }
  for i = 1, 3 do
    ok(p.big(i).word == "ADD MY TARGET", "a hidden name: the button does not say it")
    press(p.big(i))
  end
  for i = 1, 4 do H.Paint("rivals", i) end
  ok(not d.errors, "no error handed to the deck", d.errors)
  R:SetEnabled("rivals", false)
  ok(c.prio() == nil and not d.badge(), "off: no card, no number")
  R:SetEnabled("rivals", true)

  NS.Print = kr.print
  RC.palSeenAt, RC.griefSeen, RC.griefInGroup = kr.seen, kr.gseen, kr.ingroup
  for _, k in ipairs(G) do _G[k] = kg[k] end
  for _, k in ipairs(LISTS) do db[k] = keep[k] end
end
