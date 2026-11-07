-- BiSTools / Core / Slash.lua
-- /bist              list tools
-- /bist <tool> ...   hand the rest to that tool
-- /bist on|off <tool>
local _, NS = ...
local T, R = NS.T, NS.Registry

local function List()
  NS.Print("v%s - tools:", NS.VERSION)
  for key, tool in R:Each() do
    local state = R:Enabled(key) and T.text("good", "on") or T.text("warn", "off")
    DEFAULT_CHAT_FRAME:AddMessage(("  %s %s%s - %s  %s"):format(
      state, T.text("accent", key), tool.short and T.text("gold", " (" .. tool.short .. ")") or "", tool.desc or "",
      T.text("muted", tool.usage or "")))
  end
  DEFAULT_CHAT_FRAME:AddMessage(T.text("muted", "  /bist on|off <tool> to toggle  |  /bist hub | options | minimap  (or the minimap button)"))
end

-- /bist since 0.4.0 (Arn, 6 Oct 2026: "let's make it consistent" - /bish is Healing, /bisg is
-- Guild). /bt stays as an alias so a macro or a habit from 0.3.x keeps working.
SLASH_BISTOOLS1 = "/bist"
SLASH_BISTOOLS2 = "/bistools"
SLASH_BISTOOLS3 = "/bt"
SlashCmdList.BISTOOLS = function(msg)
  msg = (msg or ""):match("^%s*(.-)%s*$")
  if msg == "" then return List() end
  local cmd, rest = msg:match("^(%S+)%s*(.-)$")
  cmd = cmd:lower()
  if cmd == "on" or cmd == "off" then
    local tool = R:Get(rest)
    if not tool then return NS.Print("no tool '%s'", rest) end
    R:SetEnabled(rest, cmd == "on")
    return NS.Print("%s %s", tool.name, cmd == "on" and T.text("good", "on") or T.text("warn", "off"))
  end
  if NS.HubSlash and NS.HubSlash(cmd) then return end
  -- SHORT WORDS for the lists (Arn, 14 Oct: rivals and pals "be its own thing ... dont need to write
  -- to command all the time"): /bist rival is /bist recap rival, and so on. They live in the recap
  -- tool still - its death cards add rivals - but nobody should have to know that to use them.
  -- since 14 Oct they are their own tool, "rivals": /bist rivals is the tool, the rest its words
  local short = { rival = "rival", pal = "pal", pals = "pals", surname = "surname" }
  if short[cmd] then
    rest = short[cmd] .. ((rest ~= "" and (" " .. rest)) or "")
    cmd = "rivals"
  end
  local tool = R:Get(cmd)
  if not tool then return NS.Print("no tool '%s' - /bist for the list", cmd) end
  -- a tool may keep its slash alive while off (summon: the nag switch must
  -- reach through, the nag is not the tool's window)
  if not R:Enabled(cmd) and not tool.slashWhenOff then return NS.Print("%s is off - /bist on %s", tool.name, cmd) end
  if not tool.OnSlash then return NS.Print("%s has no commands", tool.name) end
  tool:OnSlash(R:DBFor(tool), rest)
end
