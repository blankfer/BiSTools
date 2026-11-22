-- BiSTools / Tools / Apps / Innervate.lua - asking and giving, in the phone (Tools/Innervate.lua has the bar for a fight).
local _, NS = ...
local DP, R, A = NS.DeckPages, NS.Registry, NS.Asks
if not (DP and DP.App and A) then return end
local D = BiSTheme and BiSTheme.Deck
local CLASS_WORD = { DRUID = "druid", PRIEST = "priest", SHAMAN = "shaman", MAGE = "mage", WARLOCK = "warlock", HUNTER = "hunter", PALADIN = "paladin" }

local function class()
  if type(UnitClass) ~= "function" then return nil end
  local ok, _, c = pcall(UnitClass, "player")
  if not ok or (issecretvalue and issecretvalue(c)) then return nil end
  return c
end
--- The secure button that gives it to them: claims their ask in the click, then casts.
local function give(x, spell, req, word)
  return { word = word or "GIVE", spell = A.SPELL[spell], unit = x.unit, peek = true, tip = A.SPELL[spell] .. " on " .. x.name,
    ok = function() A.Claim(req) return A.UnitOf(x.name) == x.unit end }
end
--- Who asks me for it now: { name, class, unit, id } in the order they asked.
local function asking(spell)
  local out = {}
  for _, r in ipairs(A.Requests(spell)) do
    local u = A.UnitOf(r.owner)
    out[#out + 1] = { name = r.owner, unit = u, id = r.id }
  end
  return out
end
local function mana(unit) local m = unit and A.Mana(unit) return m and (m .. "% mana") or nil end

DP.App.innervate = function(tool, db)
  local function dirty() if D then D.Dirty() end end
  return {
    name = "Innervate",
    art = "Interface\\Icons\\Spell_Nature_Lightning",
    badge = function()
      local n, plan = 0, A.Plan()
      if plan.give then n = n + #A.Requests(plan.give) end
      if plan.tide then n = n + #A.Requests("tide") end
      return n > 0 and n or nil
    end,
    card = {
      tick = true,
      prio = function(out)
        if not A.On() then return nil end
        local plan = A.Plan()
        if (plan.give and #A.Requests(plan.give) > 0) or (plan.tide and #A.Requests("tide") > 0) then return 9 end
        for _, k in ipairs(plan.asks) do local _, open = A.AskWords(k) if open then return 6 end end
        return out and A.Grouped() and 2 or nil
      end,
      lines = function()
        local plan = A.Plan()
        local spell = plan.give and #A.Requests(plan.give) > 0 and plan.give or plan.tide and #A.Requests("tide") > 0 and "tide" or nil
        if spell then
          local who = asking(spell)
          local x = who[1]
          local left, list = A.Mine(spell), {}
          list[1] = { "Yours", left > 0 and A.Clock(left) or "ready" }
          for i = 2, math.min(3, #who) do list[#list + 1] = { A.Short(who[i].name) .. " asks too", mana(who[i].unit) } end
          return { A.WORD[spell], "", A.Short(x.name) .. " asks", mana(x.unit) or "", "gold", hot = true, list = list }
        end
        for _, k in ipairs(plan.asks) do
          local w, open = A.AskWords(k)
          if open then return { A.WORD[k], "", "You asked", w == "asked" and "" or "", "gold", list = { { w } } } end
        end
        return { "INNERVATE", "", "Nobody asks", "", "ink2" }
      end,
      buttons = function()
        local plan, out = A.Plan(), {}
        if plan.give then
          local x = asking(plan.give)[1]
          if x and x.unit then out[1] = give(x, plan.give, x.id, "GIVE IT") end
        end
        if #out == 0 and plan.tide then
          local x = asking("tide")[1]
          if x then out[1] = { word = "DROP IT", spell = A.SPELL.tide, peek = true, ok = function() A.Claim(x.id) return true end } end
        end
        if #out == 0 then
          for _, k in ipairs(plan.asks) do
            local _, open = A.AskWords(k)
            if open then out[1] = { word = "TAKE IT BACK", peek = true, fn = function() A.Ask(k) end } break end
          end
        end
        out[#out + 1] = { word = "OPEN", peek = true, fn = function() D.Open("BiSTools:tool-innervate") end }
        return out
      end,
    },
    page = {
      tick = true,
      tour = { { text = "Everyone with mana can ASK. A druid, a priest or a shaman sees who asks, and one click gives it.", note = "Any BiS addon is enough to ask." },
        { text = "The bar on your screen is for fights: the phone's buttons go away then.", note = "SETTINGS switches it." } },
      kicker = function()
        local me = A.Me()
        return me and next(me.give or {}) and "you give" or "you ask"
      end,
      tabs = function() return { "NOW", "WHO" } end,
      boxes = function()
        local plan, out = A.Plan(), {}
        local spell = plan.give or (plan.tide and "tide")
        if spell then
          local left, n = A.Mine(spell), (plan.give and #A.Requests(plan.give) or 0) + (plan.tide and #A.Requests("tide") or 0)
          out[1] = { "ASKING", n, n > 0 and "gold" or "dim" }
          out[2] = { "YOURS", left > 0 and A.Clock(left) or "Ready", left > 0 and "ink2" or "good" }
          out[3] = { "MAY ASK", #plan.askers }
        end
        if #plan.asks > 0 and not spell then
          local ready, all = 0, 0
          for _, k in ipairs(plan.asks) do local n, _, g = A.Ready(k) ready, all = ready + n, all + #g end
          out[1], out[2] = { "READY", ready, ready > 0 and "good" or "dim" }, { "GIVERS", all }
        end
        return out
      end,
      text = function(tab)
        if not A.Grouped() then return "Join a group: who gives and who asks shows here." end
        local plan = A.Plan()
        if tab == 1 and not plan.give and not plan.tide and #plan.asks == 0 then return "Nobody here gives Innervate, Power Infusion or Mana Tide yet. They need a BiS addon with it on." end
        if tab == 1 and plan.give and #plan.askers == 0 and #plan.asks == 0 then return "Nobody in your group has asking on yet." end
      end,
      rows = function(tab)
        local plan, out = A.Plan(), {}
        if not A.Grouped() then return out end
        if tab == 2 then
          for _, k in ipairs(A.Order()) do
            local n, left, givers = A.Ready(k)
            if #givers > 0 then
              out[#out + 1] = { head = true, text = A.WORD[k], right = n > 0 and n .. " ready" or left and A.Clock(left) or "", ink = n > 0 and "good" or "ink2" }
              for _, name in ipairs(givers) do out[#out + 1] = { mark = "-", text = name } end
            end
          end
          if #plan.askers > 0 then
            out[#out + 1] = { head = true, text = "WHO MAY ASK YOU" }
            for _, x in ipairs(plan.askers) do out[#out + 1] = { mark = "-", text = x.name, right = CLASS_WORD[x.class] or "" } end
          end
          return out
        end
        if plan.give then
          local who, seen = asking(plan.give), {}
          if #who > 0 then out[#out + 1] = { head = true, text = "ASKING NOW" } end
          for _, x in ipairs(who) do
            seen[x.name] = true
            out[#out + 1] = { pic = A.ICON[plan.give], text = x.name, right = mana(x.unit), ink = "gold", verb = "GIVE", act = x.unit and give(x, plan.give, x.id) or nil }
          end
          local rest = {}
          for _, x in ipairs(plan.askers) do if not seen[x.name] then rest[#rest + 1] = x end end
          if #rest > 0 then out[#out + 1] = { head = true, text = "THE OTHERS" } end
          for _, x in ipairs(rest) do out[#out + 1] = { mark = "-", text = x.name, right = mana(x.unit), verb = "GIVE", act = give(x, plan.give, nil) } end
        end
        if plan.tide then
          local x = asking("tide")[1]
          out[#out + 1] = { pic = A.ICON.tide, text = x and (A.Short(x.name) .. " asks for Mana Tide") or "Mana Tide", ink = x and "gold" or nil, verb = "DROP",
            act = { word = "DROP", spell = A.SPELL.tide, peek = true, ok = function() if x then A.Claim(x.id) end return true end } }
        end
        for _, k in ipairs(plan.asks) do
          local w, open = A.AskWords(k)
          out[#out + 1] = { pic = A.ICON[k], text = A.NAME[k], right = w, ink = open and "gold" or "ink2", verb = open and "TAKE BACK" or "ASK", act = { word = "ask", peek = true, fn = function() A.Ask(k) end } }
        end
        return out
      end,
      say = function()
        if A.said then return A.said end
        return A.Locked() and "In a fight the game holds messages: an ask goes out after it." or nil
      end,
      big = function(tab)
        if tab ~= 1 or not A.Grouped() then return nil end
        local plan = A.Plan()
        if plan.give then
          local x = asking(plan.give)[1]
          if x and x.unit then return give(x, plan.give, x.id, "GIVE: " .. A.Short(x.name)) end
        end
        local k = plan.asks[1]
        if k and not plan.give then
          local _, open = A.AskWords(k)
          return { word = open and "TAKE IT BACK" or "ASK FOR " .. A.WORD[k], peek = true, fn = function() A.Ask(k) dirty() end }
        end
      end,
      keys = function()
        local up = db().bar ~= false
        return { { word = up and "HIDE THE BAR" or "SHOW THE BAR", peek = true, tip = "The bar on your screen, for fights", fn = function() db().bar = not up A.Layout() end } }
      end,
    },
  }
end

--- THE FIRST DAY, for who this is for (a druid or a mage needs BiS Tools alone): one live card, once a character.
function DP.InnervateHello()
  if not (D and D.Register) or DP.helloIn then return false end
  DP.helloIn = true
  local function mine() return R:Get("innervate") and R:DBFor(R:Get("innervate")) or {} end
  local function done() local d = mine() return d.hello ~= nil end
  local c = class()
  local lib = rawget(_G, "LibBiSComm")
  local gives, asks = A.GIVER[c or ""], lib and lib.BISIN_MANA and lib.BISIN_MANA[c or ""]
  if not (gives or asks) then return false end
  D.Register{
    owner = "BiSTools", key = "innervate-hello", name = "Innervate", hidden = true, order = 36,
    card = {
      prio = function() return not R:Enabled("innervate") and not done() and A.Grouped() and 5 or nil end,
      lines = function()
        return { "INNERVATE", "", gives and ("Give your group " .. A.NAME[gives] .. "?") or "Ask for Innervate with a click?", "", "ink2",
          list = { { gives and "They ask, they light up, you click" or "Your druids see you light up" } } }
      end,
      buttons = function()
        return { { word = "TURN ON", peek = true, fn = function() mine().hello = true R:SetEnabled("innervate", true) D.Open("BiSTools:tool-innervate") end },
          { word = "NO THANKS", peek = true, fn = function() mine().hello = false end } }
      end,
    },
  }
  return true
end
