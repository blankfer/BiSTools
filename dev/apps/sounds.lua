-- dev/apps/sounds.lua - the sound explorer in the phone (Tools/Apps/Sounds.lua)
return function(H)
  local NS, R, ok, W, Dk = H.NS, H.R, H.ok, H.W, H.Dk
  local X, db, d = NS.Sounds, R:DBFor(R:Get("sounds")), H.Page("sounds")
  local p, c = d.page, d.card
  local function press(b) Dk.Press(d, b)() end
  Dk.Store().toured = Dk.Store().toured or {}
  Dk.Store().toured[d.id] = true
  local keep = { kits = rawget(_G, "SOUNDKIT"), ps = _G.PlaySound, psf = _G.PlaySoundFile, st = _G.StopSound, cs = rawget(_G, "C_Sound"), is = _G.issecretvalue,
    favs = db.favs, files = db.files, all = X.all, last = X.last, handle = X.handle, filter = X.filter, typed = X.typed, said = NS.Print }
  local played, stopped, on = {}, {}, true
  _G.PlaySound = function(kit, ch) if type(kit) ~= "number" then error("PlaySound wants a kit id", 2) end played[#played + 1] = kit .. ch return true, 70 + #played end
  _G.PlaySoundFile = function(f, ch) played[#played + 1] = f .. ch return true, 70 + #played end
  _G.StopSound = function(h) stopped[#stopped + 1] = h end
  _G.C_Sound = { IsPlaying = function(h) if type(h) ~= "number" then error("bad handle", 2) end return on end }
  _G.SOUNDKIT = { IG_MAINMENU_OPTION = 856, TELL_MESSAGE = 3081, UI_BELL_TOLL = 1234 }
  for i = 1, 3000 do _G.SOUNDKIT["ZZ_" .. i] = 20000 + i end
  X.all, X.last, X.handle, X.filter, X.typed, db.favs, db.files = nil, nil, nil, "old words", nil, {}, {}
  NS.Print = function() end

  local tabs = p.tabs()
  ok(tabs[1] == "ALL" and tabs[2] == "STARS" and tabs[3] == "MINE" and tabs[4] == "SETTINGS", "sounds: ALL, STARS, MINE, SETTINGS")
  local rows = p.rows(1)
  ok(#rows > 3000 and p.rows(1) == rows, "the whole list, made once", #rows)
  ok(not c.alive() and p.say(1):find("Click a row") and #p.keys(1) == 0, "nothing heard: no live card, no AGAIN")
  local f = p.find(1)
  f.set("bell toll")
  rows = p.rows(1)
  ok(#rows == 1 and rows[1].text == "Ui bell toll" and rows[1].tip:find("UI_BELL_TOLL"), "the search takes words with a space", rows[1] and rows[1].text)
  ok(X.filter == "old words", "the old window keeps its own search")
  press(rows[1].act)
  ok(played[1] == "1234SFX" and X.last == 1234, "a click on a row plays it")
  ok(p.rows(1)[1].mark == ">" and p.say(1) == "PLAYING: Ui bell toll  1234", "it wears the mark, the line says PLAYING", p.say(1))
  ok(c.alive() and c.prio() == 5 and c.lines()[3] == "Ui bell toll" and c.lines()[4] == "PLAYING" and Dk.IsLive(d), "a live card with its name")
  ok(c.buttons()[1].word == "STOP" and c.buttons()[2].word == "AGAIN", "STOP and AGAIN on it")
  on = false
  ok(p.say(1):find("Last heard") and c.lines()[4] == "" and c.buttons()[1].word == "AGAIN", "over by itself: last heard, AGAIN alone")
  on = true
  local big = p.big(1)
  ok(big.word == "STOP", "STOP is the big one")
  press(big)
  ok(stopped[#stopped] == 71 and X.handle == nil and p.say(1):find("Last heard"), "and stops it")
  press(p.keys(1)[1])
  ok(played[#played] == "1234SFX", "AGAIN")
  -- stars
  f.set("")
  ok(#p.rows(2) == 0 and p.text(2):find("No stars yet"), "no star yet: the words say how", p.text(2))
  f.set("")
  ok(p.rows(1)[1].side.word == "STAR", "a side key to star")
  f.set("tell")
  press(p.rows(1)[1].side)
  ok(db.favs[3081] == "TELL_MESSAGE" and p.rows(1)[1].side.word == "UNSTAR" and p.rows(1)[1].mark == "*", "starred: kept by its own name")
  f.set("")
  ok(#p.rows(2) == 1 and p.rows(2)[1].text == "Tell message", "and on STARS")
  press(p.rows(2)[1].side)
  ok(db.favs[3081] == nil and #p.rows(2) == 0, "unstarred there")
  -- a number
  f.set("99999")
  ok(#p.rows(1) == 1 and p.rows(1)[1].text == "Sound 99999", "a number the game has no name for is a row")
  f.enter("99999")
  ok(played[#played] == "99999SFX" and c.lines()[3] == "Sound 99999", "enter plays it")
  press(p.rows(1)[1].side)
  ok(db.favs[99999] == "id 99999" , "and it can be starred")
  f.set("")
  ok(#p.rows(2) == 1, "(it is on STARS too)")
  f.set("nothing like this")
  ok(#p.rows(1) == 0 and p.text(1):find("Nothing is called"), "nothing found: words, no rows")
  f.set("")
  -- my own files
  ok(p.text(3):find("Your own .ogg"), "no file yet: how")
  local m = p.find(3)
  m.set("BiSHealing\\Media\\click.ogg")
  ok(m.get() == "BiSHealing\\Media\\click.ogg", "typed")
  m.enter("BiSHealing\\Media\\click.ogg")
  ok(db.files[1] == "BiSHealing\\Media\\click.ogg" and played[#played] == "Interface\\AddOns\\BiSHealing\\Media\\click.oggSFX" and m.get() == "", "enter: added and played, the line empty")
  ok(p.rows(3)[1].text == "click.ogg" and p.rows(3)[1].mark == ">" and c.lines()[3] == "click.ogg", "a row with the file's name")
  press(p.rows(3)[1].side)
  ok(p.rows(3)[1].side.word == "SURE?" and #db.files == 1, "forget asks first")
  W.now = W.now + 6
  ok(p.rows(3)[1].side.word == "FORGET", "for five seconds")
  press(p.rows(3)[1].side) press(p.rows(3)[1].side)
  ok(#db.files == 0 and #p.rows(3) == 0, "twice: forgotten")
  -- a secret answer
  local secret = setmetatable({}, { __eq = function() error("compared a secret") end })
  _G.issecretvalue = function(v) return v == nil and false or rawequal(v, secret) end
  _G.C_Sound.IsPlaying = function() return secret end
  press(p.keys(1)[1])
  ok(p.say(1):find("PLAYING"), "a secret answer: no error, playing until STOP")
  _G.C_Sound = nil
  ok(p.say(1):find("PLAYING"), "a client without the call: the same")
  _G.issecretvalue = keep.is
  for t = 1, 4 do H.Paint("sounds", t) end
  ok(not d.errors, "no error handed to the deck", d.errors)
  Dk.EndLive(d)
  NS.Print = keep.said
  _G.SOUNDKIT, _G.PlaySound, _G.PlaySoundFile, _G.StopSound, _G.C_Sound = keep.kits, keep.ps, keep.psf, keep.st, keep.cs
  X.all, X.last, X.handle, X.filter, X.typed, db.favs, db.files = keep.all, keep.last, keep.handle, keep.filter, keep.typed, keep.favs, keep.files
end
