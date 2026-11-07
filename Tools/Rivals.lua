-- BiSTools / Tools / Rivals.lua
-- RIVALS & PALS, a tool of their own (Arn, 14 Oct 2026: "we can make rivals and pals decouple from
-- recap now and be its own thing - can still rival in the recap screen but dont need to write the
-- command all the time").
--
-- The engine stays in Recap.lua (RC: the tracker, crosshairs, hearts, crowns, the crest, the target
-- button, the menus) and the DATA stays in recap's saved table - rivals, pals, surnames, guild rivals
-- are read and written there through RC.DB(), so a player's lists never move and cannot be lost.
-- What this file owns: the switch (R:Enabled("rivals") gates the whole tracker; "recap" now gates
-- only the death window), the settings, and the commands.
local _, NS = ...
local R = NS.Registry
local RC = NS.Recap

--- The settings live in recap's table (where they always were); this tool's own db stays empty.
local function D() return RC.DB() end

NS.Registry:Register({
  name = "rivals",
  title = "rivals & pals",
  desc = "rivals (enemies you hunt), pals (friends you find), surname crowns, guildmates",
  usage = "/bist rivals [rival | pal [name surname] | pals | surname <word> | forget <name> | key <key> | style <name> | why]",
  -- 1.0 (Arn: a new user must not wonder "what's making that noise"): a new install's guildmate crest, recruit
  -- crest and rival ping start off - each has its tick below. They live in recap's table, read as `~= false`;
  -- an existing save's untouched ones are frozen ON by Registry R:Forever10.
  quiet = { mates = false, recruits = false, sound = false },
  quietIn = "recap",
  options = {
    { kind = "toggle", label = "sound when a rival is near", rivalPreview = true, help = "A ping with the warning when a gold rival - or a kept surname - comes into sight.",
      get = function() return D().sound ~= false end,
      set = function(_, on) D().sound = on and true or false end },
    -- eight shapes do not fit one row of buttons: a stepper, the name shown, each step redrawn live
    { kind = "step", label = "crosshair", rivalPreview = true, help = "The crosshair's look on rivals and farm mobs: rails, L, aim, box, scope, drop, chevron, tee, or none.",
      min = 1, max = #RC.STYLES, step = 1,
      get = function() for i, s in ipairs(RC.STYLES) do if s == (D().style or "rails") then return i end end return 1 end,
      set = function(_, v)
        RC.SetStyle(D(), RC.STYLES[v] or "rails")
        if NS.BG and NS.BG.PaintPreview then NS.BG.PaintPreview() end     -- the preview, in the new shape
      end,
      show = function() return D().style or "rails" end },
    -- THE HINT (Arn: "a hint that says need nameplates on"): every mark hangs off a nameplate, and the
    -- game shows none for enemies until it is told to. The button tells it.
    { kind = "button", label = "needs nameplates on", help = "Crosshairs, crests, hearts and crowns sit on nameplates, so the game must show enemy (and friendly) plates. This turns them on.",
      button = "turn on", action = function()
        if InCombatLockdown and InCombatLockdown() then return NS.Print("not in a fight - try again after") end
        local set = (C_CVar and C_CVar.SetCVar) or SetCVar
        if set and pcall(set, "nameplateShowEnemies", "1") then NS.Print("enemy nameplates on") end
      end },
    { kind = "toggle", label = "pal nearby note", rivalPreview = true, help = "A small green line in chat when one of your pals comes into view, out of combat - once every ten minutes each, no sound.",
      get = function() return D().palNote ~= false end,
      set = function(_, on) D().palNote = on and true or false end },
    { kind = "toggle", label = "guild rivals (amber)", rivalPreview = true, help = "Rivals your guild shares wear an amber crosshair, and the guild hears when you see one.",
      get = function() return D().guildShow ~= false end,
      set = function(_, on)
        D().guildShow = on and true or false
        if not on then for unit, f in pairs(RC.marks) do if f.kind == "guild" then RC.UnmarkUnit(unit) end end end
        RC.PaintRivals()
      end },
    { kind = "toggle", label = "guildmates (crest, alone)", rivalPreview = true, help = "A small teal guild crest under guildmates you pass - only while you are solo, never in a group or battleground.",
      get = function() return D().mates ~= false end,
      set = function(_, on) D().mates = on and true or false if not on then RC.ClearMates() end end },
    { kind = "toggle", label = "recruits (gold crest)", rivalPreview = true, help = "A gold crest under somebody your guild is recruiting - from BiS> Nebbinator's shared list - and a line saying who is talking to them, so you can put in a good word.",
      get = function() return D().recruits ~= false end,
      set = function(_, on) D().recruits = on and true or false if not on then RC.ClearRecruits() end end },
    { kind = "toggle", label = "rival target button", help = "A button in the BiS> tools box that targets your gold rivals, even across the map.",
      get = function() return D().button ~= false end,
      set = function(_, on) D().button = on and true or false RC.ApplyButton(D()) end },
  },
  -- off: every mark down, the target button gone; the lists are kept
  OnDisable = function()
    for unit in pairs(RC.marks) do RC.UnmarkUnit(unit) end
    RC.ClearMates() RC.ClearPals() RC.ClearCrowns() RC.ClearRecruits()
    RC.ApplyButton(D())
  end,
  -- on again: the button back, and every plate on screen looked at once more
  OnEnable = function()
    RC.ApplyButton(D())
    for unit in pairs(RC.plates) do RC.SpotPal(D(), unit) RC.Spot(D(), unit) end
  end,
  OnLogin = function()
    RC.style = D().style
    RC.ApplyButton(D())
    RC.HookMenus(D())
    RC.HookGuild(D())
    RC.HookNebbinator()
  end,
  -- the same words the recap tool always took for these, so old macros keep working; no word = the list
  -- (the roll-out preview of these marks lives with the bg tool's: Battleground.lua B.AttachPreview,
  -- mode "rivals", painted by Recap.lua RC.PaintPreview)
  -- the hub's row, and /bist rivals with no word: the rivals & pals window (Arn, 14 Oct: "its own
  -- thing that can be pulled up"); /bist rivals list still prints them in chat
  OnOpen = function() RC.db = RC.db or D() RC.ToggleRivals(D(), true) end,
  IsOpen = function() return RC.rwin ~= nil and RC.rwin:IsShown() end,
  OnClose = function() RC.ToggleRivals(D(), false) end,
  OnSlash = function(_, _, args)
    args = args or ""
    if args == "" then RC.db = RC.db or D() return RC.ToggleRivals(D()) end
    if args == "list" then args = "rivals" end
    if args == "add" then args = "rival" end
    local recap = R:Get("recap")
    return recap.OnSlash(recap, D(), args)
  end,
})
