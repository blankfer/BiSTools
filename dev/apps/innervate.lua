-- Asking for Innervate, Power Infusion, Mana Tide (22 Nov 2026, Arn: "a druid only has to download bis tools not healing")
return function(H)
  local ok, A, R, Dk, W, DP, S = H.ok, H.NS.Asks, H.R, H.Dk, H.W, H.DP, H.S
  local keep = {}
  for _, k in ipairs({ "LibBiSComm", "IsInGroup", "IsInRaid", "UnitExists", "UnitPower", "UnitPowerMax", "UnitPowerType", "UnitClass", "InCombatLockdown", "GetServerTime", "InChatMessagingLockdown", "issecretvalue", "BiSHealingUtility" }) do keep[k] = _G[k] end
  local now, fighting, grouped = 1000, false, true
  local WHO = { party1 = "Frost Bolt", party2 = "Leaf Mend", party3 = "Holy Light" }
  local MANA = { party1 = 12, party2 = 80, party3 = 50 }
  local lib = { BISIN_ORDER = { "innervate", "pi", "tide" }, BISIN_MANA = { MAGE = true, DRUID = true, PRIEST = true, SHAMAN = true } }
  local st = { on = false, give = {}, ask = false, class = "DRUID", cd = {} }
  local said, reqs, askers, ready = {}, {}, {}, {}
  lib.FullName = function(u) return u == "player" and "Me Myself" or WHO[u] end
  lib.BisInState = function() return st end
  function lib:BisInMe() return { on = st.on, give = st.give, ask = st.ask, class = st.class } end
  function lib:BisInSet(on) st.on = on said[#said + 1] = "set " .. tostring(on) end
  function lib:BisInReady(k) local x = ready[k] or {} return x.n or 0, x.soon, x.who or {} end
  function lib:BisInAskers() return askers end
  function lib:BisInRequests(k) local o = {} for _, x in ipairs(reqs) do if x.spell == k and not x.claim and x.owner ~= "Me Myself" then o[#o + 1] = x end end return o end
  function lib:BisInRequest(id) for _, x in ipairs(reqs) do if x.id == id then return x end end end
  function lib:BisInAsk(k) reqs[#reqs + 1] = { id = "m" .. #reqs, owner = "Me Myself", spell = k } said[#said + 1] = "ask " .. k return reqs[#reqs].id end
  function lib:BisInCancel(id) for i = #reqs, 1, -1 do if reqs[i].id == id then table.remove(reqs, i) end end said[#said + 1] = "cancel " .. id end
  function lib:BisInClaim(id) local x = self:BisInRequest(id) if x then x.claim = { by = "Me Myself" } end said[#said + 1] = "claim " .. id end
  local heard
  function lib:RegisterCallback(what, fn) if what == "BISIN" then heard = fn end end
  _G.LibBiSComm = lib
  _G.IsInGroup = function() return grouped end
  _G.IsInRaid = function() return false end
  _G.UnitExists = function(u) return WHO[u] ~= nil end
  _G.UnitPower = function(u) return MANA[u] or 0 end
  _G.UnitPowerMax = function() return 100 end
  _G.UnitPowerType = function() return 0 end
  _G.UnitClass = function() return "Druid", "DRUID" end
  _G.InCombatLockdown = function() return fighting end
  _G.GetServerTime = function() return now end
  _G.InChatMessagingLockdown = nil
  _G.BiSHealingUtility = nil
  -- (the mock has no StatusBar: the client's takes numbers, also hidden ones)
  local cf = _G.CreateFrame
  _G.CreateFrame = function(kind, ...)
    local f = cf(kind, ...)
    if kind == "StatusBar" then
      f.SetStatusBarTexture = function() end
      f.SetStatusBarColor = function(_, r) if type(r) ~= "number" then error("SetStatusBarColor wants numbers") end end
      f.SetMinMaxValues = function(self, a, b) self.max = b end
      f.SetValue = function(self, v) self.value = v end
    end
    return f
  end
  local db = R:DBFor(R:Get("innervate"))
  local def = H.Page("innervate")
  local p = def.page
  local function row(tab, words) for _, r in ipairs(p.rows(tab)) do if r.text:find(words, 1, true) then return r end end end
  local function ev(e) A.events:GetScript("OnEvent")(A.events, e) end
  -- the switch tells the group
  R:SetEnabled("innervate", false)
  A.hooked = nil
  said = {}
  R:SetEnabled("innervate", true)
  ok(said[1] == "set true" and A.On() and heard, "switched on: the group is told, and it listens", said[1])
  -- alone
  grouped = false
  ok(p.text(1):find("Join a group") and #p.rows(1) == 0 and def.card.prio() == nil and A.Layout() == false, "alone: it says so, no bar, no card")
  grouped = true
  -- A DRUID
  st.give, st.ask = { innervate = true }, true
  ok(p.text(1):find("Nobody in your group has asking on"), "nobody opted in: said")
  ok(A.Layout() == false, "and no bar over nothing")
  askers = { { name = "Frost Bolt", class = "MAGE" }, { name = "Holy Light", class = "PRIEST" }, { name = "Gone Away", class = "MAGE" } }
  ok(A.Layout() == true and A.frame:IsShown() and #A.plan.askers == 2, "who may ask and is here: two faces on the bar")
  local f1 = A.frame.faces[1]
  ok(f1:GetAttribute("type1") == "spell" and f1:GetAttribute("spell1") == "Innervate" and f1:GetAttribute("unit") == "party1" and f1.name:GetText() == "Frost", "a face casts Innervate on its own person")
  ok(p.kicker() == "you give" and p.boxes(1)[1][2] == 0 and p.boxes(1)[2][2] == "Ready" and p.boxes(1)[3][2] == 2, "the app: nobody asks, yours is ready, two may ask")
  ok(row(1, "Frost Bolt").verb == "GIVE" and row(1, "Frost Bolt").act.unit == "party1" and row(1, "Frost Bolt").right == "12% mana" and Dk.IsSecure(row(1, "Frost Bolt").act), "anyone may be given it")
  ok(p.big(1) == nil and def.badge() == nil, "nobody asks: no big button")
  -- somebody asks
  reqs = { { id = "r1", owner = "Frost Bolt", spell = "innervate" } }
  heard(nil, "ask")
  ok(f1.req == "r1" and f1.ask:IsShown() and f1.alpha ~= 0.6, "asked: the face lights")
  local l = def.card.lines()
  ok(def.card.prio() == 9 and l[3] == "Frost asks" and l[4] == "12% mana" and l.hot and def.badge() == 1, "and the tile comes", l[3])
  local g = def.card.buttons()[1]
  ok(g.word == "GIVE IT" and g.spell == "Innervate" and g.unit == "party1", "its button gives it")
  ok(p.rows(1)[1].head and p.rows(1)[2].text == "Frost Bolt" and p.rows(1)[2].ink == "gold" and p.big(1).word == "GIVE: Frost", "the app has them on top")
  said = {}
  ok(g.ok() == true and said[1] == "claim r1", "the click claims it first: two druids never both cast", said[1])
  ok(def.card.prio() == nil, "claimed: the tile goes")
  -- a fight: nothing secure is touched, the faces still light
  reqs = { { id = "r2", owner = "Holy Light", spell = "innervate" } }
  ev("PLAYER_REGEN_DISABLED")
  fighting = true
  local fine, why = pcall(function() ev("GROUP_ROSTER_UPDATE") heard(nil, "roster") heard(nil, "ask") end)
  ok(fine and A.pending, "a fight: the layout waits", why)
  local f2 = A.frame.faces[2]
  ok(f2.req == "r2" and f2.ask:IsShown(), "and a face still lights")
  said = {} f2:GetScript("PreClick")(f2, "LeftButton") ok(said[1] == "claim r2", "its click claims")
  fighting = false ev("PLAYER_REGEN_ENABLED") ok(not A.pending, "after it: laid out")
  -- boxes, a class left off, cat form, the cooldown
  db.mode = "boxes" ok(A.Layout() and f1.pic.shown ~= false, "as boxes") db.mode = nil
  db.hide = { MAGE = true } ok(#A.Plan().askers == 1, "a class left off") db.hide = nil
  st.cd = { innervate = now + 95 }
  A.Layout() ok(A.frame.head:GetText():find("1:35", 1, true) and p.boxes(1)[2][2] == "1:35", "on cooldown: how long", A.frame.head:GetText())
  st.cd = {}
  -- BiS Healing's own window is up: one of them is enough
  _G.BiSHealingUtility = { IsShown = function() return true end }
  ok(A.Layout() == false and not A.frame:IsShown(), "BiS Healing's window is up: the bar steps back")
  _G.BiSHealingUtility = nil
  db.bar = false ok(A.Layout() == false, "the bar's switch") db.bar = nil
  -- A MAGE
  st.give, st.ask, askers, reqs = {}, true, {}, {}
  _G.UnitClass = function() return "Mage", "MAGE" end
  ok(p.text(1):find("Nobody here gives"), "nobody gives: said")
  ready = { innervate = { n = 1, who = { "Leaf Mend" } }, tide = { n = 0, soon = now + 70, who = { "Wave Rider" } } }
  ok(A.Layout() and A.frame.asks[1].word:GetText() == "ASK: INNERVATE" and A.frame.asks[1].say:GetText() == "Leaf ready" and A.frame.asks[2].say:GetText() == "1:10", "the bar: an ASK for each", A.frame.asks[1].say:GetText())
  ok(row(1, "Innervate").verb == "ASK" and row(1, "Mana Tide").right == "1:10" and p.big(1).word == "ASK FOR INNERVATE" and p.boxes(1)[1][2] == 1, "the app: the same")
  said = {} p.big(1).fn()
  ok(said[1] == "ask innervate" and row(1, "Innervate").verb == "TAKE BACK" and def.card.prio() == 6 and def.card.lines()[3] == "You asked", "asked")
  reqs[1].claim = { by = "Leaf Mend" } ok(row(1, "Innervate").right == "Leaf is answering", "answered: by whom")
  reqs[1].claim = nil
  _G.InChatMessagingLockdown = function() return true end
  ok(row(1, "Innervate").right == "goes out when the fight ends" and p.say():find("holds messages"), "in a fight it says the message waits")
  _G.InChatMessagingLockdown = nil
  p.big(1).fn() ok(#reqs == 0 and row(1, "Innervate").verb == "ASK", "again: taken back")
  A.frame.asks[1]:GetScript("OnClick")(A.frame.asks[1]) ok(#reqs == 1, "the bar's button asks too") A.Ask("innervate")
  ok(p.rows(2)[1].head and p.rows(2)[1].text == "INNERVATE" and p.rows(2)[2].text == "Leaf Mend", "WHO: who gives")
  -- A SHAMAN
  st.give, st.ask, ready = { tide = true }, true, {}
  reqs = { { id = "t1", owner = "Frost Bolt", spell = "tide" } }
  ok(A.Layout() and A.frame.tide:IsShown() and A.frame.tide.lit and A.frame.tide:GetAttribute("spell1") == "Mana Tide Totem" and A.frame.tide.say:GetText():find("Frost asks", 1, true), "Mana Tide lights with who asks")
  ok(row(1, "Frost asks for Mana Tide").verb == "DROP" and def.card.buttons()[1].word == "DROP IT", "and the app drops it")
  -- secrets
  local sec = {}
  _G.issecretvalue = function(v) return v == sec end
  _G.UnitPower = function() return sec end
  st.give, askers = { innervate = true }, { { name = "Frost Bolt", class = "MAGE" } }
  ok(pcall(p.rows, 1) and row(1, "Frost Bolt").right == nil and pcall(A.Paint), "hidden mana: no error, nothing said")
  _G.issecretvalue = keep.issecretvalue
  H.Paint("innervate", 1)
  -- off: the group is told, the bar goes
  said = {}
  R:SetEnabled("innervate", false)
  ok(said[1] == "set false" and not A.frame:IsShown() and def.card.prio() == nil, "off: told, gone")
  -- THE FIRST DAY: one card, once
  DP.helloIn = nil
  db.hello = nil
  _G.UnitClass = function() return "Druid", "DRUID" end
  ok(DP.InnervateHello() == true, "a druid: the card is there")
  local hi = Dk.defs["BiSTools:innervate-hello"]
  ok(hi.hidden and hi.card.prio() == 5 and hi.card.lines()[3]:find("Give your group Innervate", 1, true), "it asks once", hi.card.lines()[3])
  grouped = false ok(hi.card.prio() == nil, "not alone") grouped = true
  hi.card.buttons()[2].fn() ok(hi.card.prio() == nil and db.hello == false, "no thanks: never again")
  db.hello = nil
  BiSTheme.DECK_LOGIN = true
  hi.card.buttons()[1].fn() ok(R:Enabled("innervate") and hi.card.prio() == nil, "turn on: on, and gone")
  Dk.page = "home" Dk.Hide() Dk.Store().open = false
  Dk.defs["BiSTools:innervate-hello"] = nil
  DP.helloIn = nil
  _G.UnitClass = function() return "Warrior", "WARRIOR" end
  ok(DP.InnervateHello() == false, "a warrior: never")
  R:SetEnabled("innervate", false)
  db.hello, db.pos, A.asked, A.said, A.hooked = nil, nil, nil, nil, nil
  A.frame:Hide()
  _G.CreateFrame = cf
  for _, k in ipairs({ "LibBiSComm", "IsInGroup", "IsInRaid", "UnitExists", "UnitPower", "UnitPowerMax", "UnitPowerType", "UnitClass", "InCombatLockdown", "GetServerTime", "InChatMessagingLockdown", "issecretvalue", "BiSHealingUtility" }) do _G[k] = keep[k] end
end
