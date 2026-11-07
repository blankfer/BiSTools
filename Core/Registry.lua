-- BiSTools / Core / Registry.lua
-- Every tool registers here. A tool is a table:
--   { name = "foo", desc = "one line", usage = "/bist foo [args]",
--     defaults = {...},            -- per-tool saved settings
--     OnInit = function(tool, db) end,   -- ADDON_LOADED, db is tool's sub-table
--     OnLogin = function(tool, db) end,  -- PLAYER_LOGIN
--     OnSlash = function(tool, db, args) end,
--     OnEnable / OnDisable = function(tool, db) end,  -- /bist on|off <name>
--     OnOpen = function(tool, db, recenter) end,  -- the Hub: show your window (recenter: to the middle)
--     IsOpen = function(tool, db) end,   OnClose = function(tool, db) end,  -- a window tool has both:
--                                  -- the Hub's click on an open one closes it (19 Oct)
--     options = { { kind = "toggle"|"seg"|"step"|"button", label, get(db), set(db, v),
--                   values (seg) | min, max, step, show(db) (step) | button, action(db) } },
--     slashWhenOff = true,    -- OnSlash still runs while the tool is off
--     quiet = { key = value },  -- 1.0: settings a NEW install gets quiet (see R:Forever10); quietIn = "recap"
--                               -- when they live in another tool's table
--     defaultOff = true }     -- PRE-1.0 ONLY: how a save from before 1.0 read a missing switch (a beta: off)
--
-- ON / OFF SINCE 1.0 (Arn, 7 Nov 2026: "start with everything off"). BiSToolsDB.enabled[name] is true or false,
-- written; a MISSING switch is OFF - so a new install, and a tool added in a later version, start off and the user
-- turns on what they want from the Hub. Before 1.0 nil meant ON (and SetEnabled stored nil for on), so the one-time
-- R:Forever10 writes every old save's switches out as they were before this rule reads them.
local _, NS = ...
local R = { tools = {}, order = {}, alias = {} }
NS.Registry = R

-- SHORT WORDS (Arn, 6 Nov 2026: "any thing more than 3 or 4 letters cut it down /bist processing"): every tool whose
-- name is longer than 4 letters answers to a word of 4 or fewer too. The long names keep working - a macro or a habit
-- never breaks - and the saved settings stay under the long name.
R.SHORT = { processing = "proc", disenchant = "de", recap = "rcap", rides = "ride", rivals = "riv", social = "soc",
            sounds = "snd", summon = "sum", threat = "thr", party = "pty" }

function R:Register(tool)
  assert(tool and tool.name, "BiSTools: tool needs a name")
  local key = tool.name:lower()
  if self.tools[key] then error("BiSTools: duplicate tool '" .. key .. "'") end
  self.tools[key] = tool
  self.order[#self.order + 1] = key
  tool.short = tool.short or R.SHORT[key]
  if tool.short then self.alias[tool.short:lower()] = key end
  return tool
end

--- The tool's own key for a long name or a short one ("proc" -> "processing").
function R:Key(name)
  if not name then return nil end
  local n = name:lower()
  return self.tools[n] and n or self.alias[n] or n
end

function R:Get(name)
  return name and self.tools[self:Key(name)]
end

function R:Enabled(name)
  local key = self:Key(name)
  return NS.DB().enabled[key] == true          -- written true, or off (missing = off since 1.0)
end

function R:SetEnabled(name, on)
  local key = self:Key(name)
  local was = self:Enabled(key)
  NS.DB().enabled[key] = on and true or false  -- always written: a missing key means off
  local tool = self.tools[key]
  if tool and was ~= (on and true or false) then
    local h = on and tool.OnEnable or tool.OnDisable
    if h then h(tool, self:DBFor(tool)) end
  end
end

--- THE 1.0 STAMP, once per saved table (Init's NS.OpenDB calls it at ADDON_LOADED, after every tool registered,
--- before any tool reads its table). Arn, 7 Nov 2026: new users start with everything off - "everybody that already
--- has the addons installed, I don't wanna change default settings that they have on".
---   isNew (the client handed back no table): every tool OFF, and each tool's `quiet` values written.
---   an existing save: FROZEN - every switch written as the old rule read it (nil = on, unless defaultOff), and every
---   `quiet` key that is nil written TRUE (nil read as on: `x ~= false`, or a default of true), so nothing it did
---   before changes. Then stamped (sv.forever10), so neither runs twice.
function R:Forever10(sv, isNew)
  if sv.forever10 then return false end
  sv.enabled = type(sv.enabled) == "table" and sv.enabled or {}
  sv.tools = type(sv.tools) == "table" and sv.tools or {}
  for _, key in ipairs(self.order) do
    local tool = self.tools[key]
    if isNew then
      sv.enabled[key] = false
    elseif sv.enabled[key] == nil then
      sv.enabled[key] = not tool.defaultOff
    else
      sv.enabled[key] = sv.enabled[key] and true or false
    end
    if tool.quiet then
      local home = (tool.quietIn or key):lower()
      sv.tools[home] = type(sv.tools[home]) == "table" and sv.tools[home] or {}
      local t = sv.tools[home]
      for k, v in pairs(tool.quiet) do
        if isNew then t[k] = v elseif t[k] == nil then t[k] = true end
      end
    end
  end
  sv.forever10 = true
  return true
end

function R:DBFor(tool)
  local all = NS.DB().tools
  local key = tool.name:lower()
  all[key] = all[key] or {}
  local db = all[key]
  if tool.defaults then
    for k, v in pairs(tool.defaults) do
      if db[k] == nil then db[k] = v end
    end
  end
  return db
end

function R:InitAll()
  for _, key in ipairs(self.order) do
    local tool = self.tools[key]
    if tool.OnInit then tool:OnInit(self:DBFor(tool)) end
  end
end

function R:Fire(handler, ...)
  for _, key in ipairs(self.order) do
    local tool = self.tools[key]
    if tool[handler] and self:Enabled(key) then
      tool[handler](tool, self:DBFor(tool), ...)
    end
  end
end

function R:Each()
  local i = 0
  return function()
    i = i + 1
    local key = self.order[i]
    if key then return key, self.tools[key] end
  end
end
