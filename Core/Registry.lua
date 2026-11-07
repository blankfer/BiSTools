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
--     slashWhenOff = true }   -- OnSlash still runs while the tool is off
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
  local en = NS.DB().enabled[key]
  -- a tool marked defaultOff (a beta: Arn, 13 Oct, the threat tool "in releases, off") is off until
  -- someone turns it on; every other tool is on until someone turns it off
  if en == nil then
    local t = self.tools[key]
    return not (t and t.defaultOff)
  end
  return en
end

function R:SetEnabled(name, on)
  local key = self:Key(name)
  local was = self:Enabled(key)
  -- not "on and nil or false": that is false both ways (Lua's and/or with nil)
  -- on = "nothing saved" for a normal tool; a defaultOff tool must REMEMBER it was turned on
  local t = self.tools[key]
  if on then NS.DB().enabled[key] = (t and t.defaultOff) and true or nil else NS.DB().enabled[key] = false end
  local tool = self.tools[key]
  if tool and was ~= (on and true or false) then
    local h = on and tool.OnEnable or tool.OnDisable
    if h then h(tool, self:DBFor(tool)) end
  end
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
