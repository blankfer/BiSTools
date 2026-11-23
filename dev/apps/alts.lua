-- main & alts in the phone (Tools/Apps/Alts.lua)
return function(H)
  local NS, ok, W = H.NS, H.ok, H.W
  local A = NS.Alts
  local def = H.Page("alts")
  local p = def.page
  local keep, keepDate = _G.BiSToolsAlts, rawget(_G, "date")
  _G.date = os.date
  _G.BiSToolsAlts = {}
  ok(#p.rows(1) == 0 and p.text(1):find("first time you log it in", 1, true), "alts: nobody yet, and it says how")
  H.Paint("alts", 1)
  local d = A.Data()
  d.roster = { ["Chainheal Ryangosling"] = { class = "SHAMAN", level = 31 }, ["Mail Ryangosling"] = { class = "ROGUE", level = 18 }, ["Gnarly Gnar"] = { class = "WARRIOR", level = 9 } }
  local r = p.rows(1)
  ok(#r == 3 and r[1].text == "Chainheal Ryangosling" and r[1].mark == "31" and r[1].right == "GETS COPIES" and p.text(1):find("pick MAIN", 1, true), "the characters, highest first; no main yet")
  -- one opened
  r[1].act.fn()
  r = p.rows(1)
  ok(p.title() == "Chainheal Ryangosling" and p.kicker() == "level 31 shaman" and #r == 4 and r[1].text == "Back" and r[2].text == "MAIN" and r[4].right == "NOW" and not r[4].act,
    "its page: Back, the three it can be, what it is now")
  r[2].act.fn()
  ok(d.main == nil and p.rows(1)[2].right == "SURE?", "a new main asks first")
  W.now = W.now + 6
  ok(p.rows(1)[2].right == "PICK", "five seconds later it has forgotten")
  p.rows(1)[2].act.fn()
  p.rows(1)[2].act.fn()
  ok(d.main == "Chainheal Ryangosling" and p.rows(1)[2].right == "NOW" and d.mainAt, "twice: the main, stamped by the tool's own setter")
  p.rows(1)[1].act.fn()
  ok(p.title() == "Main & alts" and p.rows(1)[1].right == "MAIN" and p.text(1) == nil, "Back: the list")
  ok(p.say(1) == "Copies to 2 characters when WoW closes.", "what happens next", p.say(1))
  -- KEEP MINE hurts nobody: one press; GETS COPIES writes over it: two
  local function char(name) for _, x in ipairs(p.rows(1)) do if x.text == name then return x end end end
  char("Gnarly Gnar").act.fn()
  p.rows(1)[3].act.fn()
  ok(d.keep["Gnarly Gnar"] == true, "KEEP MINE: one press")
  p.rows(1)[4].act.fn()
  ok(d.keep["Gnarly Gnar"] == true and p.rows(1)[4].right == "SURE?", "back to GETS COPIES asks first")
  p.rows(1)[4].act.fn()
  ok(d.keep["Gnarly Gnar"] == nil, "twice: it gets copies")
  p.rows(1)[3].act.fn()
  H.Paint("alts", 1)
  p.rows(1)[1].act.fn()
  -- the main stepping down asks too, whatever it becomes
  char("Chainheal Ryangosling").act.fn()
  p.rows(1)[3].act.fn()
  ok(d.main == "Chainheal Ryangosling", "the main to KEEP MINE: asks first (nobody left to copy from)")
  p.rows(1)[1].act.fn()
  local b = p.boxes(1)
  ok(b[1][2] == 3 and b[2][2] == 1 and b[3][2] == 1 and b[4][2] == "-", "the boxes")
  d.copied = { at = 1794669000, to = 1, names = {} }
  ok(p.boxes(1)[4][2] ~= "-" and not p.say(1):find("last copy", 1, true), "the last copy has its box")
  -- what the main sends
  local s = p.rows(2)
  ok(#s == #A.SENDS and s[1].right == "ON" and s[5].right == "OFF", "SENDS: the five, as they are set")
  s[1].act.fn()
  ok(d.sends.settings == false, "off: one press (nothing is written over)")
  s = p.rows(2)
  s[5].act.fn()
  ok(d.sends.addons == false and p.rows(2)[5].right == "SURE?", "on: asks first")
  p.rows(2)[5].act.fn()
  ok(d.sends.addons == true and d.sendsAt, "twice: on")
  H.Paint("alts", 2)
  -- a character gone while its page is open: the list
  char("Mail Ryangosling").act.fn()
  d.roster["Mail Ryangosling"] = nil
  ok(#p.rows(1) == 2 and p.title() == "Main & alts", "a character gone: the list again")
  _G.BiSToolsAlts, _G.date = keep, keepDate
end
